#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

reference_lexical_absolute_path() {
    local input="$1"
    local candidate component joined
    local -a components=()
    local -a normalized=()
    case "$input" in
        /*) candidate="$input" ;;
        *) candidate="$PWD/$input" ;;
    esac
    IFS='/' read -r -a components <<< "$candidate"
    for component in "${components[@]}"; do
        case "$component" in
            ''|.) ;;
            ..)
                if [ "${#normalized[@]}" -gt 0 ]; then
                    unset "normalized[$((${#normalized[@]} - 1))]"
                fi
                ;;
            *) normalized+=("$component") ;;
        esac
    done
    if [ "${#normalized[@]}" -eq 0 ]; then
        printf '/\n'
    else
        printf -v joined '/%s' "${normalized[@]}"
        printf '%s\n' "$joined"
    fi
}

reference_realpath_allow_missing() {
    local normalized probe suffix component base
    normalized="$(reference_lexical_absolute_path "$1")"
    if realpath "$normalized" >/dev/null 2>&1; then
        realpath "$normalized"
        return
    fi
    probe="$normalized"
    suffix=""
    while [ ! -e "$probe" ] && [ "$probe" != "/" ]; do
        component="${probe##*/}"
        suffix="/$component$suffix"
        probe="${probe%/*}"
        [ -n "$probe" ] || probe="/"
    done
    if [ -d "$probe" ]; then
        base="$(cd "$probe" && pwd -P)"
    else
        base="$(cd "$(dirname "$probe")" && pwd -P)/$(basename "$probe")"
    fi
    printf '%s%s\n' "$base" "$suffix"
}

reference_link_legacy_executable() {
    local compiler="$1"
    local argument
    local -a filtered_arguments=()
    shift
    if [ "$(uname -s)" = "Darwin" ]; then
        for argument in "$@"; do
            case "$argument" in
                */BLOCKDSPY.o) ;;
                *) filtered_arguments+=("$argument") ;;
            esac
        done
        "$compiler" "${filtered_arguments[@]}"
    else
        "$compiler" "$@" -Wl,--allow-multiple-definition
    fi
}

SRC="$ROOT/src/fortran"
BUILD_INPUT="${EMTP_BUILD_DIR:-$ROOT/build}"
case "$BUILD_INPUT" in
    /*) BUILD="$BUILD_INPUT" ;;
    *) BUILD="$ROOT/$BUILD_INPUT" ;;
esac
BUILD="$(reference_realpath_allow_missing "$BUILD")"
case "$BUILD" in
    "$ROOT/build"|"$ROOT/runs/"*) ;;
    *)
        echo "ERROR: EMTP_BUILD_DIR must resolve to $ROOT/build or a directory below $ROOT/runs." >&2
        exit 2
        ;;
esac
PREPROCESS="$ROOT/src/julia/preprocess_fortran.jl"

find_julia() {
    if [ -n "${JULIA:-}" ] && command -v "$JULIA" >/dev/null 2>&1; then
        command -v "$JULIA"
    elif command -v julia >/dev/null 2>&1; then
        command -v julia
    elif [ -x "$HOME/.juliaup/bin/julia" ]; then
        printf '%s\n' "$HOME/.juliaup/bin/julia"
    else
        return 1
    fi
}

JULIA_BIN="$(find_julia)" || {
    echo "ERROR: Julia not found. Install Julia or run with JULIA=/path/to/julia." >&2
    exit 1
}

command -v gfortran >/dev/null 2>&1 || {
    echo "ERROR: gfortran not found." >&2
    exit 1
}

[ -d "$SRC" ] || {
    echo "ERROR: Fortran source directory not found: $SRC" >&2
    exit 1
}

echo "=== BPA EMTP legacy Fortran build ==="
echo "Fortran source: $SRC"
echo "Julia tool:     $JULIA_BIN"
echo "Compiler:       $(gfortran --version | head -1)"
echo "Build dir:      $BUILD"
echo

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "--- Preprocessing VAX/VMS Fortran ---"
"$JULIA_BIN" "$PREPROCESS" --batch "$SRC" "$BUILD"
if [ -n "${EMTP_COMMON_MAP:-}" ]; then
    echo "--- Writing COMMON map ---"
    "$JULIA_BIN" "$PREPROCESS" --common-map "$SRC" "$EMTP_COMMON_MAP"
fi

echo "--- Applying legacy Fortran portability patches ---"
"$JULIA_BIN" --startup-file=no - \
    "$BUILD/MAIN00.FOR" "$BUILD/CALCOM.FOR" <<'JULIA'
path, calcom_path = ARGS
text = read(path, String)
start_marker = "      SUBROUTINE FRENUM ( TEXT1, N3, D1 )"
end_marker = "\n      SUBROUTINE  PACKA1"
start_range = findfirst(start_marker, text)
start_range === nothing && error("FRENUM start marker missing in $path")
end_range = findnext(end_marker, text, last(start_range))
end_range === nothing && error("FRENUM end marker missing in $path")
replacement = raw"""      SUBROUTINE FRENUM ( TEXT1, N3, D1 )
      IMPLICIT REAL*8 (A-H, O-Z) ,
     1      INTEGER*4 (I-N)
C     Portable equivalent of the VAX DECODE-based free-field numeric
C     conversion.  The source tree stays unchanged; this build-copy patch
C     keeps compiled oracle decks with $VINTAGE free-field arguments runnable
C     under gfortran.
      REAL*8        TEXT1(1), BLANK
      REAL*8        DCHAR
      CHARACTER*30  TEXTA
      CHARACTER*8   CCHAR
      EQUIVALENCE (DCHAR, CCHAR)
      DATA  BLANK   /  6H          /
      TEXTA = '                              '
      N9 = 30
      N4 = N3 + 1
      DO 4718  I=1, N3
      N4 = N4 - 1
      IF ( TEXT1(N4)  .EQ.  BLANK )   GO TO 4718
      IF ( N9  .GE.  1 )   GO TO 4711
      WRITE (6, 4706)
 4706 FORMAT ( /, 34H ERROR STOP IN "FRENUM". THERE ARE,
     1            33H 33 OR MORE CHARACTERS IN A FREE-,
     2            33H FORMAT NUMBER ON LAST DATA CARD.   )
      CALL STOPTP
 4711 DCHAR = TEXT1(N4)
      TEXTA(N9:N9) = CCHAR(1:1)
      N9 = N9 - 1
 4718 CONTINUE
      IF ( N9  .EQ.  30 )   GO TO 4728
      READ (TEXTA, 4732)  D1
 4732 FORMAT ( E30.0 )
      RETURN
 4728 D1 = 0.0
      RETURN
      END                                                               M28. 278
"""
patched = text[begin:first(start_range)-1] * replacement * text[first(end_range)+1:end]
write(path, patched)
if Sys.isapple()
    calcom = read(calcom_path, String)
    axis_entry = "      ENTRY AXIS\n"
    occursin(axis_entry, calcom) || error("CALCOM AXIS entry missing in $calcom_path")
    write(calcom_path, replace(calcom, axis_entry => ""; count = 1))
end
JULIA

EMTP_TIME44_DELAY_S="${EMTP_TIME44_DELAY_S:-0}"
if [ "$EMTP_TIME44_DELAY_S" != "0" ]; then
    [[ "$EMTP_TIME44_DELAY_S" =~ ^[1-9][0-9]*$ ]] || {
        echo "ERROR: EMTP_TIME44_DELAY_S must be a non-negative integer." >&2
        exit 2
    }
    "$JULIA_BIN" --startup-file=no - "$BUILD/MAIN00.FOR" "$EMTP_TIME44_DELAY_S" <<'JULIA'
path, delay_text = ARGS
text = read(path, String)
needle = if occursin("      CALL EMTPTM( CHAR(1) )", text)
    "      CALL EMTPTM( CHAR(1) )"
elseif occursin("      CALL TIME ( CHAR(1) )", text)
    "      CALL TIME ( CHAR(1) )"
else
    error("TIME44 wall-clock query missing in $path")
end
replacement = "      CALL SLEEP (" * delay_text * ")\n" * needle
write(path, replace(text, needle => replacement; count = 1))
JULIA
fi

"$JULIA_BIN" --startup-file=no - "$BUILD/OVER5.FOR" <<'JULIA'
path = only(ARGS)
text = read(path, String)
old =
    rpad("      READ(CHABUF, 17246) TDPUM, TQPUM, TDPPUM, TQPPUM,", 65) * "\n" *
    rpad("     1 X0UM, RNUM, XNUM, NETRUM", 72) * "\n"
new = raw"""      READ(CHABUF, 17246) TDPUM, TQPUM, TDPPUM, TQPPUM,
     1 X0UM, RNUM, XNUM
C     The Linux card cache retains 72 columns, while VAX DECODE named an
C     optional I10 field through column 80.  Read the surviving two-column
C     prefix independently; blank remains the documented zero default.
      NETRUM = 0
      IF (CHABUF(71:72) .NE. '  ')
     1 READ(CHABUF(71:72), *) NETRUM
"""
occursin(old, text) || error("UMDATB mixed manufacturer-card read missing in $path")
write(path, replace(text, old => new; count = 1))
JULIA

"$JULIA_BIN" --startup-file=no - "$BUILD/OVER10.FOR" <<'JULIA'
path = only(ARGS)
text = read(path, String)
old = "10HREAL POWER  3X"
new = "10HREAL POWER, 3X"
length(findall(old, text)) == 1 ||
    error("FXSOUR final-report FORMAT portability target missing or duplicated in $path")
write(path, replace(text, old => new; count = 1))
JULIA

echo "--- Creating include symlinks ---"
for f in "$BUILD"/*.FOR "$BUILD"/*.INS "$BUILD"/*.FTN; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    lower="$(echo "$base" | tr '[:upper:]' '[:lower:]')"
    [ "$lower" != "$base" ] && [ ! -e "$BUILD/$lower" ] && ln -sf "$base" "$BUILD/$lower"
done
[ ! -e "$BUILD/labcom.INS" ] && ln -sf LABCOM.INS "$BUILD/labcom.INS" || true
[ ! -e "$BUILD/TACSTO.INS" ] && ln -sf TACSTO.INS "$BUILD/TACSTO.INS" || true

FC="${FC:-gfortran}"
if [ "${EMTP_DEBUG_BUILD:-0}" = "1" ]; then
    OPT_FLAGS="-g -O0"
else
    OPT_FLAGS="-O2"
fi
FFLAGS="-ffixed-form -ffixed-line-length-72 -fno-automatic -fallow-argument-mismatch -fdec -w $OPT_FLAGS -I$BUILD"

SOURCES=(
    AIMORA_TAPE.FOR
    NEWMODS.FOR
    BUILD1.FTN  BUILD2.FTN  CALC.FTN    CALSTO.FTN  COMB.FTN
    DATA.FTN    ELEC.FTN    ERRSTP.FTN  INIT.FTN    PMODL.FTN
    PSTMT.FTN   PTACS.FTN   PUSE.FTN    PUTIL1.FTN  PUTIL2.FTN
    STEP.FTN    SYNSTP.FTN  NTACS1.FTN  NTACS1A.FTN NTACS1B.FTN
    NTACS2.FTN  NTACS3.FTN  TREAD.FTN   USE1.FTN    USE2.FTN
    XPR1.FTN    XPR2.FTN    XREF1.FTN   XREF2.FTN
    MAIN00.FOR  MAIN10.FOR
    OVER1.FOR   OVER2.FOR   OVER5.FOR   OVER6.FOR   OVER7.FOR
    OVER8.FOR   OVER9.FOR   OVER10.FOR  OVER11.FOR  OVER12.FOR
    OVER13.FOR  OVER14.FOR  OVER15.FOR  OVER16.FOR  OVER20.FOR
    OVER29.FOR  OVER31.FOR  OVER39.FOR  OVER41.FOR  OVER42.FOR
    OVER44.FOR  OVER45.FOR  OVER47.FOR  OVER51.FOR  OVER52.FOR
    OVER53.FOR  OVER54.FOR  OVER55.FOR
    DATAIN.FOR  INLMFS.FOR  BLOCKDSPY.FOR  CALCOM.FOR
    PORTABLE.FOR
)

echo "--- Compiling ---"
failed=()
objects=()
for src in "${SOURCES[@]}"; do
    obj="${src%.*}.o"
    source_flags="$FFLAGS"
    if [ "$(uname -s)" = "Darwin" ] && [ "$src" = "OVER8.FOR" ]; then
        # GCC 16 misoptimizes legacy aliasing in OVER8 on Apple ARM64 and
        # leaves the compiled reference spinning before time stepping.
        source_flags="$source_flags -O0"
    fi
    printf "  %-20s -> %s ... " "$src" "$obj"
    if "$FC" $source_flags -c "$BUILD/$src" -o "$BUILD/$obj" 2>"$BUILD/${src}.err"; then
        echo "OK"
        objects+=("$BUILD/$obj")
    else
        echo "FAILED"
        failed+=("$src")
    fi
done

if [ "${#failed[@]}" -gt 0 ]; then
    echo
    echo "ERROR: ${#failed[@]} source file(s) failed to compile:" >&2
    for f in "${failed[@]}"; do
        echo "  - $f" >&2
        head -20 "$BUILD/${f}.err" >&2
    done
    exit 1
fi

echo "--- Linking ---"
reference_link_legacy_executable "$FC" -o "$BUILD/emtp" "${objects[@]}"

echo
echo "Built: $BUILD/emtp"
