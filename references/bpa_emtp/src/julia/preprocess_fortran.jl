#!/usr/bin/env julia

# VAX/VMS Fortran compatibility preprocessor for the BPA EMTP source.
# This keeps the legacy solver buildable with modern gfortran without editing
# the original fixed-form source files in place.

const DECODE_BUFS = Dict(
    "ABUFF" => "CHABUF",
    "DATE1" => "CHDAT1",
    "TCLOCK" => "CHTCLK",
    "BUS1" => "CHBUS1",
    "BUS2" => "CHBUS2",
    "BUS3" => "CHBUS3",
    "BUS4" => "CHBUS4",
    "BUS5" => "CHBUS5",
    "BUS6" => "CHBUS6",
    "FILNAM" => "FILN20",
    "FILEN" => "CHFILEN",
    "TEXTA" => "CHTXTA",
    "A" => "CHA",
    "ATIM" => "CHATIM",
)

const A6_REAL_VARS = Set([
    "BUS1", "BUS2", "BUS3", "BUS4", "BUS5", "BUS6",
    "TEXT1", "TEXT2", "TEXT3", "TEXT4", "TEXT5", "TEXT6",
    "TEXT7", "TEXT8", "TEXT9", "TEXT10", "TEXT11", "TEXT12",
    "TEXT13", "TEXT14", "TEXT15", "TEXT16", "TEXT17",
    "TEXTA5", "TEXTA6", "ALNM1", "ALNM2", "ALNODE",
])

const A6_CHAR_TARGETS = Dict(
    "BUS1" => "CBA1(1:6)",
    "BUS2" => "CBA2(1:6)",
    "BUS3" => "CBA3(1:6)",
    "BUS4" => "CBA4(1:6)",
    "BUS5" => "CBA5(1:6)",
    "BUS6" => "CBA6(1:6)",
)

const DECODE_RE = Regex(raw"(?i)(\s*\d*\s*)DECODE\s*\(\s*(\d+)\s*,\s*([^,]+?)\s*,\s*([A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?)\s*\)")
const ENCODE_RE = Regex(raw"(?i)(\s*\d*\s*)ENCODE\s*\(\s*(\d+)\s*,\s*([^,]+?)\s*,\s*([A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?)\s*\)")


function replace_matches(text::String, regex::Regex, f::Function)
    out = IOBuffer()
    pos = 1
    for m in eachmatch(regex, text)
        start = m.offset
        stop = m.offset + ncodeunits(m.match) - 1
        if start > pos
            write(out, SubString(text, pos, start - 1))
        end
        write(out, f(m))
        pos = stop + 1
    end
    if pos <= ncodeunits(text)
        write(out, SubString(text, pos, ncodeunits(text)))
    end
    return String(take!(out))
end

replace_matches(f::Function, text::String, regex::Regex) = replace_matches(text, regex, f)


function strip_parens(expr::AbstractString)
    return strip(replace(String(expr), r"\(.*\)" => ""))
end


function buf_to_char(buf_expr::AbstractString)
    expr = strip(String(buf_expr))
    base = uppercase(strip_parens(expr))
    char_var = get(DECODE_BUFS, base, nothing)
    char_var === nothing && return nothing

    m = match(r"^[A-Za-z_][A-Za-z0-9_]*\(([^)]*)\)", expr)
    if m !== nothing
        idx_expr = strip(m.captures[1])
        if base in ("FILEN", "TEXTA")
            return idx_expr == "1" ? char_var : "$(char_var)($(idx_expr):$(idx_expr))"
        elseif base == "A"
            idx = tryparse(Int, idx_expr)
            idx === nothing && return char_var
            start = (idx - 1) * 8 + 1
            return "$(char_var)($(start):$(start + 3))"
        else
            idx = tryparse(Int, idx_expr)
            idx === nothing && return char_var
            if idx > 1
                start = (idx - 1) * 8 + 1
                return "$(char_var)($(start):)"
            end
        end
    end
    return char_var
end


function a6_initializers(label_sp::AbstractString, var_text::AbstractString)
    found = String[]
    for m in eachmatch(r"\b[A-Za-z_][A-Za-z0-9_]*\b", String(var_text))
        upper = uppercase(m.match)
        if upper in A6_REAL_VARS && !(upper in found)
            push!(found, upper)
        end
    end

    isempty(found) && return String[], String(label_sp)

    lines = String[]
    for (index, var) in enumerate(found)
        prefix = index == 1 ? String(label_sp) : "      "
        char_var = get(A6_CHAR_TARGETS, var, nothing)
        if char_var === nothing
            push!(lines, "$(prefix)$(var) = BLANK")
        else
            push!(lines, "$(prefix)$(split(char_var, "(")[1]) = '        '")
        end
    end
    read_label = all(c -> isspace(c) || isdigit(c), String(label_sp)) && occursin(r"\d", String(label_sp)) ? "      " : String(label_sp)
    return lines, read_label
end


function rewrite_a6_read_targets(var_text::AbstractString)
    return replace_matches(String(var_text), r"\b[A-Za-z_][A-Za-z0-9_]*\b") do m
        get(A6_CHAR_TARGETS, uppercase(m.match), m.match)
    end
end


function rewrite_a6_comparisons(line::String)
    line = replace_matches(line, r"(?i)\bBUS([1-6])\s*\.\s*(EQ|NE)\s*\.\s*BUS\s*\(([^)]*)\)") do m
        "CBA$(m.captures[1]) .$(uppercase(m.captures[2])). CBUS($(m.captures[3]))"
    end
    line = replace_matches(line, r"(?i)\bBUS\s*\(([^)]*)\)\s*\.\s*(EQ|NE)\s*\.\s*BUS([1-6])\b") do m
        "CBUS($(m.captures[1])) .$(uppercase(m.captures[2])). CBA$(m.captures[3])"
    end
    line = replace_matches(line, r"(?i)\bBUS([1-6])\s*\.\s*(EQ|NE)\s*\.\s*TEXVEC\s*\(([^)]*)\)") do m
        "CBA$(m.captures[1]) .$(uppercase(m.captures[2])). CTEXVEC($(m.captures[3]))"
    end
    line = replace_matches(line, r"(?i)\bTEXVEC\s*\(([^)]*)\)\s*\.\s*(EQ|NE)\s*\.\s*BUS([1-6])\b") do m
        "CTEXVEC($(m.captures[1])) .$(uppercase(m.captures[2])). CBA$(m.captures[3])"
    end
    return line
end


function preprocess_line(line::String; rewrite_comparisons::Bool = true)
    line = replace(line, r"(?i)(INCLUDE\s*'[A-Za-z0-9_.]+)[;/][^']*'" => s"\1'")

    line = replace(line, r"(?i)\bTYPE\s*=\s*'([^']*)'" => s"STATUS='\1'")
    line = replace(line, r"(?i)\bNAME\s*=" => "FILE=")
    line = replace(line, r"(?i),\s*READONLY\b" => "")
    line = replace(line, r"(?i)\bREADONLY\s*,\s*" => "")
    line = replace(line, r"(?i),?\s*CARRIAGECONTROL\s*=\s*'[^']*'" => "")
    line = replace(line, r"(?i),?\s*DISP\s*=\s*'[^']*'" => "")
    line = replace(line, r"(?i),?\s*DISPOSE\s*=\s*'[^']*'" => "")

    if occursin(r"(?i)\b(?:OPEN|CLOSE)\s*\(", line)
        line = replace(line, r",\s*\)" => ")")
    end

    if occursin(r"(?i)\bOPEN\s*\(", line) &&
       occursin(r"(?i)STATUS\s*=\s*'NEW'", line) &&
       !occursin(r"(?i)\bFILE\s*=", line)
        line = replace(line, r"(?i)STATUS\s*=\s*'NEW'" => "STATUS='SCRATCH'")
    end

    line = replace(line, r"%LOC\s*\(" => "LOC(")
    line = replace(line, r"(?i)SYS\$GETJPI\s*\([^)]*\)" => ".TRUE.")
    line = replace(line, r"(?i)\bSUBROUTINE\s+SPLIT\b" => "SUBROUTINE EMTPSPL")
    line = replace(line, r"(?i)\bCALL\s+SPLIT\b" => "CALL EMTPSPL")
    line = replace(line, r"\(\s*\(\s*(\([^()]*\))\s*,\s*(\([^()]*\))\s*\)\s*,\s*(([A-Za-z]\w*)\s*=\s*[^)]+)\)" => s"(\1,\2,\3)")

    rewrite_comparisons && (line = rewrite_a6_comparisons(line))

    is_continuation = ncodeunits(line) > 5 && !(line[6] in (' ', '0', '\t'))
    if !is_continuation
        m = match(DECODE_RE, line)
        if m !== nothing && m.offset == 1
            label_sp = m.captures[1]
            fmt = strip(m.captures[3])
            buf = strip(m.captures[4])
            rest_start = m.offset + ncodeunits(m.match)
            rest = rest_start <= ncodeunits(line) ? SubString(line, rest_start, ncodeunits(line)) : ""
            char_var = buf_to_char(buf)
            if char_var !== nothing
                init_lines, read_label = a6_initializers(label_sp, rest)
                read_rest = rewrite_a6_read_targets(rest)
                return join(vcat(init_lines, ["$(read_label)READ($(char_var), $(fmt))$(read_rest)"]), "\n")
            end
            return "$(label_sp)! DECODE->READ: unknown buffer $(buf)\n$(label_sp)READ($(buf), $(fmt))$(rest)"
        end

        m = match(ENCODE_RE, line)
        if m !== nothing && m.offset == 1
            label_sp = m.captures[1]
            fmt = strip(m.captures[3])
            buf = strip(m.captures[4])
            rest_start = m.offset + ncodeunits(m.match)
            rest = rest_start <= ncodeunits(line) ? SubString(line, rest_start, ncodeunits(line)) : ""
            char_var = buf_to_char(buf)
            if char_var !== nothing
                return "$(label_sp)WRITE($(char_var), $(fmt))$(rest)"
            end
            return "$(label_sp)! ENCODE->WRITE: unknown buffer $(buf)\n$(label_sp)WRITE($(buf), $(fmt))$(rest)"
        end
    end

    return line
end


function fix_orphaned_continuations(lines::Vector{String})
    result = copy(lines)
    for i in eachindex(result)
        line = result[i]
        if ncodeunits(line) > 5 && !(line[6] in (' ', '0', '\n', '\r'))
            stmt = rstrip(SubString(line, 7, ncodeunits(line)))
            if occursin(r"^[\s,]*\)\s*$", stmt)
                j = i - 1
                while j >= 1 && startswith(lstrip(result[j]), "!")
                    j -= 1
                end
                if j >= 1
                    result[j] = replace(rstrip(result[j], '\n'), r",\s*$" => "") * "\n"
                end
            end
        end
    end
    return result
end


function statement_indices(lines::Vector{String}, i::Int)
    indices = [i]
    text = lines[i]
    j = i + 1
    while count(==('('), text) > count(==(')'), text) && j <= length(lines)
        push!(indices, j)
        text *= lines[j]
        j += 1
    end
    return indices, text, j
end


function fix_multiline_open_status(lines::Vector{String})
    result = copy(lines)
    i = 1
    while i <= length(result)
        if !occursin(r"(?i)\bOPEN\s*\(", result[i])
            i += 1
            continue
        end
        indices, text, j = statement_indices(result, i)
        if occursin(r"(?i)\bFILE\s*=", text)
            for idx in indices
                result[idx] = replace(result[idx], r"(?i)STATUS\s*=\s*'NEW'" => "STATUS='REPLACE'")
                result[idx] = replace(result[idx], r"(?i)STATUS\s*=\s*'SCRATCH'" => "STATUS='REPLACE'")
            end
        end
        i = max(j, i + 1)
    end
    return result
end


function first72(raw::AbstractString)
    s = replace(String(raw), r"[\r\n]+$" => "")
    return ncodeunits(s) <= 72 ? s : SubString(s, 1, 72) |> String
end


function process_file(src_path::String, dst_path::String)
    lines = readlines(src_path, keep = true)
    rewrite_comparisons = !endswith(uppercase(src_path), "OVER29.FOR")
    out = String[]
    for raw in lines
        transformed = preprocess_line(first72(raw); rewrite_comparisons = rewrite_comparisons)
        push!(out, transformed * "\n")
    end
    out = fix_orphaned_continuations(out)
    out = fix_multiline_open_status(out)
    mkpath(dirname(dst_path))
    open(dst_path, "w") do io
        for line in out
            write(io, line)
        end
    end
end


const BLKCOM_EXTRAS = """
C     *** Character equivalents for DECODE->READ conversion (Linux port) ***
      CHARACTER*160 CHABUF
      CHARACTER*16  CHDAT1, CHTCLK
      CHARACTER*8   CHBUS1, CHBUS2, CHBUS3, CHBUS4, CHBUS5, CHBUS6
      CHARACTER*8   CBA1, CBA2, CBA3, CBA4, CBA5, CBA6
      EQUIVALENCE (CHABUF, ABUFF(1))
      EQUIVALENCE (CHDAT1, DATE1(1))
      EQUIVALENCE (CHTCLK, TCLOCK(1))
      EQUIVALENCE (CHBUS1, BUS1)
      EQUIVALENCE (CHBUS2, BUS2)
      EQUIVALENCE (CHBUS3, BUS3)
      EQUIVALENCE (CHBUS4, BUS4)
      EQUIVALENCE (CHBUS5, BUS5)
      EQUIVALENCE (CHBUS6, BUS6)
      EQUIVALENCE (CBA1, BUS1)
      EQUIVALENCE (CBA2, BUS2)
      EQUIVALENCE (CBA3, BUS3)
      EQUIVALENCE (CBA4, BUS4)
      EQUIVALENCE (CBA5, BUS5)
      EQUIVALENCE (CBA6, BUS6)
"""

const LABCOM_EXTRAS = """
C     *** Character views of A6 name arrays for Linux port comparisons ***
      CHARACTER*8   CBUS(3002)
      CHARACTER*8   CTEXVEC(4000)
      EQUIVALENCE (CBUS(1), BUS(1))
      EQUIVALENCE (CTEXVEC(1), TEXVEC(1))
"""


function append_text(path::String, text::String)
    open(path, "a") do io
        write(io, text)
    end
end


function patch_installation_helpers(path::String)
    content = read(path, String)
    content = replace(content, r"(?i)(      REAL\*8\s+A\(2\)[^\n]*\n)" => s"\1      CHARACTER*16 CHA\n")
    content = replace(content, r"(?i)\bCALL\s+IDATE\s*\(" => "CALL EMTPID(")
    content = replace(content, r"(?i)\bCALL\s+TIME\s*\(" => "CALL EMTPTM(")
    content = replace(content, r"(?i)(      CALL\s+(?:EMTPTM|EMTPID)\s*\([^\n]*\n)" => s"\1      CHA = '                '\n")
    content = replace(content, r"(?i)(      WRITE\(CHA\(9:12\),[^\n]*\n)" => s"\1      A(1) = TRANSFER(CHA(1:8), A(1))\n      A(2) = TRANSFER(CHA(9:16), A(2))\n")
    content = replace(content, r"(?i)(      BYTE\s+FILEN\(25\)[^\n]*\n)" => s"\1      CHARACTER*25 CHFILEN\n      EQUIVALENCE (CHFILEN, FILEN(1))\n")
    content = replace(content, r"(?i)\bFILE\s*=\s*FILEN\b" => "FILE=CHFILEN")
    content = replace(content, r"(?i)OPEN\s*\(\s*UNIT\s*=\s*([^,\)]+),\s*STATUS\s*=\s*'REPLACE',\s*FORM\s*=\s*'([^']+)',\s*FILE\s*=\s*CHFILEN\s*\)" => s"OPEN (UNIT=\1,STATUS='REPLACE',FORM='\2',FILE=CHFILEN)")
    content = replace(content, r"(?i)OPEN\s*\(\s*UNIT\s*=\s*([^,\)]+),\s*STATUS\s*=\s*'OLD',\s*FORM\s*=\s*'([^']+)',\s*FILE\s*=\s*CHFILEN\s*\)" => s"OPEN (UNIT=\1,STATUS='OLD',FORM='\2',FILE=CHFILEN)")
    content = replace(content, r"(?i)OPEN\s*\(\s*UNIT\s*=\s*([^,\)]+),\s*STATUS\s*=\s*'OLD',\s*FILE\s*=\s*CHFILEN\s*\)" => s"OPEN (UNIT=\1,STATUS='OLD',FILE=CHFILEN)")
    content = replace(content, r"(?i)(      INCLUDE\s+'LABCOM\.FOR'[^\n]*\n)" => s"\1      REAL*8 LPAREN\n      DATA LPAREN /1H(/\n", count = 1)
    content = replace(content, r"(?i)(IF\s*\(\s*TEXCOL\(K\)\s*\.EQ\.\s*)1H\(\s*\)" => s"\1LPAREN )")
    content = replace(content, r"(?i)(      LOGICAL\*1\s+TEXTA\(30\),\s*TEXTB[^\n]*\n)" => s"\1      CHARACTER*30 CHTXTA\n      EQUIVALENCE (CHTXTA, TEXTA(1))\n")
    content = replace(content, r"(?i)(      DIMENSION ATIM\(2\)[^\n]*\n)" => s"\1      CHARACTER*16 CHATIM\n")
    content = replace(content, r"(?i)(      READ\(CHATIM,\s*4286\))" => s"      CHATIM = TRANSFER(ATIM, CHATIM)\n\1")
    write(path, content)
end


function patch_dataftn(path::String)
    content = read(path, String)
    content = replace(content, r"(?i)[ \t]*DATA\s*\(isto\(i\)\s*,\s*i\s*=\s*525\s*,\s*799\)\s*/\s*275\*888888888\s*/[^\n]*" =>
        "      DATA (isto(i),i=525,607) /  83*888888888 /\n" *
        "      DATA (isto(i),i=609,746) / 138*888888888 /\n" *
        "      DATA (isto(i),i=749,758) /  10*888888888 /\n" *
        "      DATA (isto(i),i=772,777) /   6*888888888 /\n" *
        "      DATA (isto(i),i=783,799) /  17*888888888 /")
    write(path, content)
end


function source_flags(base::AbstractString)
    flags = String[]
    base == "BLKCOM.FOR" && push!(flags, "--blkcom")
    base == "LABCOM.FOR" && push!(flags, "--labcom")
    base == "MAIN00.FOR" && push!(flags, "--main00")
    base == "OVER1.FOR" && push!(flags, "--over1")
    base == "DATA.FTN" && push!(flags, "--dataftn")
    return flags
end


function apply_flags(dst::String, flags)
    flagset = Set(flags)
    "--blkcom" in flagset && append_text(dst, BLKCOM_EXTRAS)
    "--labcom" in flagset && append_text(dst, LABCOM_EXTRAS)
    "--main00" in flagset && patch_installation_helpers(dst)
    "--over1" in flagset && patch_installation_helpers(dst)
    "--dataftn" in flagset && patch_dataftn(dst)
end


function process_tree(src_dir::String, dst_dir::String)
    mkpath(dst_dir)
    files = String[]
    for ext in ("*.FOR", "*.FTN", "*.INS", "*.SRT")
        append!(files, sort(glob(joinpath(src_dir, ext))))
    end
    for src in files
        base = basename(src)
        dst = joinpath(dst_dir, base)
        process_file(src, dst)
        apply_flags(dst, source_flags(base))
    end
end


function glob(pattern::AbstractString)
    dir = dirname(pattern)
    suffix = replace(basename(pattern), "*" => "")
    return [joinpath(dir, name) for name in readdir(dir) if endswith(name, suffix)]
end


function fixed_statement_payload(raw::AbstractString)
    line = first72(raw)
    isempty(strip(line)) && return nothing
    first_char = line[1]
    first_char in ('C', 'c', '*', '!') && return nothing
    line = replace(line, r"!.*$" => "")
    isempty(strip(line)) && return nothing
    is_continuation = ncodeunits(line) > 5 && !(line[6] in (' ', '0', '\t'))
    payload = ncodeunits(line) > 6 ? SubString(line, 7, ncodeunits(line)) : line
    return is_continuation, String(payload)
end


function fortran_statements(path::String)
    statements = NamedTuple{(:text, :line), Tuple{String, Int}}[]
    current = IOBuffer()
    current_line = 0
    open(path, "r") do io
        for (line_no, raw) in enumerate(eachline(io))
            parsed = fixed_statement_payload(raw)
            parsed === nothing && continue
            is_continuation, payload = parsed
            if is_continuation
                current_line == 0 && (current_line = line_no)
                write(current, " ")
                write(current, strip(payload))
            else
                if position(current) > 0
                    push!(statements, (text = strip(String(take!(current))), line = current_line))
                end
                current_line = line_no
                write(current, strip(payload))
            end
        end
    end
    if position(current) > 0
        push!(statements, (text = strip(String(take!(current))), line = current_line))
    end
    return statements
end


function split_top_level(text::AbstractString)
    parts = String[]
    depth = 0
    start = 1
    s = String(text)
    for (idx, char) in pairs(s)
        if char == '('
            depth += 1
        elseif char == ')'
            depth = max(depth - 1, 0)
        elseif char == ',' && depth == 0
            push!(parts, strip(SubString(s, start, idx - 1)))
            start = idx + 1
        end
    end
    push!(parts, strip(SubString(s, start, ncodeunits(s))))
    return filter(!isempty, parts)
end


function parse_dims(text::Union{Nothing, AbstractString})
    text === nothing && return String[]
    return [replace(strip(part), r"\s+" => "") for part in split_top_level(text)]
end


function numeric_dim(dim::AbstractString)
    m = match(r"^\d+$", strip(dim))
    m === nothing && return nothing
    return parse(Int, m.match)
end


function element_count(dims::Vector{String})
    isempty(dims) && return 1
    total = 1
    for dim in dims
        value = numeric_dim(dim)
        value === nothing && return nothing
        total *= value
    end
    return total
end


function parse_var_spec(spec::AbstractString)
    cleaned = replace(strip(String(spec)), r"\s+" => "")
    m = match(r"^([A-Za-z][A-Za-z0-9_]*)(?:\((.*)\))?(?:\*(\d+))?$", cleaned)
    m === nothing && error("Cannot parse Fortran variable spec: $(spec)")
    name = uppercase(m.captures[1])
    dims = parse_dims(m.captures[2])
    char_len = m.captures[3] === nothing ? nothing : parse(Int, m.captures[3])
    return name, dims, char_len
end


function declared_type_info(statement::AbstractString)
    text = strip(String(statement))
    m = match(r"(?i)^(INTEGER|REAL|LOGICAL|CHARACTER)\s*(?:\*\s*(\d+))?\s+(.+)$", text)
    m === nothing && return nothing
    keyword = uppercase(m.captures[1])
    explicit_size = m.captures[2] === nothing ? nothing : parse(Int, m.captures[2])
    rest = m.captures[3]
    keyword == "CHARACTER" && explicit_size === nothing && (explicit_size = 1)
    keyword == "REAL" && explicit_size === nothing && (explicit_size = 8)
    keyword == "INTEGER" && explicit_size === nothing && (explicit_size = 4)
    keyword == "LOGICAL" && explicit_size === nothing && (explicit_size = 4)
    kind = lowercase(keyword)
    return kind, explicit_size, split_top_level(rest)
end


function implicit_type_info(name::AbstractString)
    first = uppercase(String(name))[1]
    if first in 'I':'N'
        return Dict(
            "kind" => "integer",
            "fortran_type" => "INTEGER*4",
            "element_bytes" => 4,
            "character_length" => nothing,
            "declaration" => "implicit_emtp_policy",
        )
    end
    return Dict(
        "kind" => "real",
        "fortran_type" => "REAL*8",
        "element_bytes" => 8,
        "character_length" => nothing,
        "declaration" => "implicit_emtp_policy",
    )
end


function julia_eltype_hint(kind::AbstractString, element_bytes::Integer)
    if kind == "real"
        return element_bytes == 4 ? "Float32" : "Float64"
    elseif kind == "integer"
        return element_bytes == 8 ? "Int64" : "Int32"
    elseif kind == "logical"
        return "Bool"
    elseif kind == "character"
        return "UInt8"
    end
    return "Any"
end


function julia_preallocation_hints(kind::AbstractString, element_bytes::Integer, count)
    eltype = julia_eltype_hint(kind, element_bytes)
    if count === nothing
        return Dict{String, Any}(
            "julia_eltype_hint" => eltype,
            "julia_container_hint" => "Vector{$(eltype)}",
            "preallocation_hint" => "dynamic_size_preallocated_vector",
            "static_array_eligible" => false,
        )
    elseif count == 1
        return Dict{String, Any}(
            "julia_eltype_hint" => eltype,
            "julia_container_hint" => eltype,
            "preallocation_hint" => "scalar",
            "static_array_eligible" => false,
        )
    end

    static_eligible = kind in ("real", "integer", "logical") && count <= 16
    container = static_eligible ? "StaticArrays.SVector{$(count),$(eltype)}" : "Vector{$(eltype)}"
    return Dict{String, Any}(
        "julia_eltype_hint" => eltype,
        "julia_container_hint" => container,
        "preallocation_hint" => static_eligible ? "static_small_fixed" : "preallocated_vector",
        "static_array_eligible" => static_eligible,
    )
end


function apply_dimension_statement!(declarations::Dict{String, Dict{String, Any}}, statement::AbstractString)
    m = match(r"(?i)^DIMENSION\s+(.+)$", strip(String(statement)))
    m === nothing && return
    for spec in split_top_level(m.captures[1])
        name, dims, _ = parse_var_spec(spec)
        info = get!(declarations, name) do
            implicit_type_info(name)
        end
        info["dimensions"] = dims
    end
end


function collect_declarations(statements)
    declarations = Dict{String, Dict{String, Any}}()
    for statement in statements
        parsed = declared_type_info(statement.text)
        parsed === nothing && continue
        kind, size, variables = parsed
        for spec in variables
            name, dims, char_len = parse_var_spec(spec)
            element_bytes = kind == "character" ? something(char_len, size) : size
            type_label = kind == "character" ? "CHARACTER*$(element_bytes)" : "$(uppercase(kind))*$(element_bytes)"
            declarations[name] = Dict{String, Any}(
                "kind" => kind,
                "fortran_type" => type_label,
                "element_bytes" => element_bytes,
                "character_length" => kind == "character" ? element_bytes : nothing,
                "dimensions" => dims,
                "declaration" => "explicit",
            )
        end
    end
    for statement in statements
        apply_dimension_statement!(declarations, statement.text)
    end
    return declarations
end


function common_statement_payload(statement::AbstractString)
    text = strip(String(statement))
    m = match(r"(?i)^COMMON\b\s*(.*)$", text)
    m === nothing && return nothing
    rest = strip(m.captures[1])
    if startswith(rest, "/")
        close_index = findnext('/', rest, 2)
        close_index === nothing && error("Malformed COMMON statement: $(statement)")
        block = uppercase(strip(SubString(rest, 2, close_index - 1)))
        block = replace(block, r"\s+" => "")
        variables = strip(SubString(rest, close_index + 1, ncodeunits(rest)))
        return isempty(block) ? "__BLANK__" : block, variables
    end
    return "__BLANK__", rest
end


function declared_common_map(src_dir::String)
    ins_files = sort(glob(joinpath(src_dir, "*.INS")))
    blocks = Dict{String, Dict{String, Any}}()
    block_order = String[]
    files = String[]
    warnings = String[]

    for path in ins_files
        rel = basename(path)
        push!(files, rel)
        statements = fortran_statements(path)
        declarations = collect_declarations(statements)
        for statement in statements
            parsed = common_statement_payload(statement.text)
            parsed === nothing && continue
            block_name, var_text = parsed
            block = get!(blocks, block_name) do
                push!(block_order, block_name)
                Dict{String, Any}(
                    "name" => block_name,
                    "source_files" => String[],
                    "byte_size" => 0,
                    "variables" => Vector{Dict{String, Any}}(),
                )
            end
            rel in block["source_files"] || push!(block["source_files"], rel)
            offset = block["byte_size"]
            offset_known = offset !== nothing
            for spec in split_top_level(var_text)
                name, common_dims, _ = parse_var_spec(spec)
                info = get(declarations, name, implicit_type_info(name))
                dims = isempty(common_dims) ? get(info, "dimensions", String[]) : common_dims
                dims = Vector{String}(dims)
                count = element_count(dims)
                elem_bytes = info["element_bytes"]
                byte_size = count === nothing ? nothing : count * elem_bytes
                if byte_size === nothing
                    push!(warnings, "$(rel):$(statement.line): nonnumeric dimension for $(name); subsequent byte offsets in $(block_name) are unknown")
                end
                hints = julia_preallocation_hints(info["kind"], elem_bytes, count)
                var_record = Dict{String, Any}(
                    "name" => name,
                    "common_block" => block_name,
                    "source_file" => rel,
                    "source_line" => statement.line,
                    "fortran_type" => info["fortran_type"],
                    "kind" => info["kind"],
                    "element_bytes" => elem_bytes,
                    "character_length" => info["character_length"],
                    "dimensions" => dims,
                    "element_count" => count,
                    "byte_offset" => offset_known ? offset : nothing,
                    "byte_size" => byte_size,
                    "declaration" => info["declaration"],
                    "julia_eltype_hint" => hints["julia_eltype_hint"],
                    "julia_container_hint" => hints["julia_container_hint"],
                    "preallocation_hint" => hints["preallocation_hint"],
                    "static_array_eligible" => hints["static_array_eligible"],
                )
                push!(block["variables"], var_record)
                if offset_known && byte_size !== nothing
                    offset += byte_size
                    block["byte_size"] = offset
                else
                    offset_known = false
                    block["byte_size"] = nothing
                end
            end
        end
    end

    return Dict{String, Any}(
        "schema" => "aimora.fortran_common_map.v1",
        "source" => Dict{String, Any}(
            "directory" => src_dir,
            "files" => files,
            "scope" => "*.INS",
        ),
        "layout_policy" => "declared COMMON order with EMTP implicit policy REAL*8(A-H,O-Z), INTEGER*4(I-N)",
        "common_blocks" => [blocks[name] for name in block_order],
        "warnings" => warnings,
    )
end


function json_write(io::IO, value)
    if value === nothing
        write(io, "null")
    elseif value isa AbstractString
        write(io, "\"")
        write(io, replace(String(value), "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t"))
        write(io, "\"")
    elseif value isa Bool
        write(io, value ? "true" : "false")
    elseif value isa Integer || value isa AbstractFloat
        write(io, string(value))
    elseif value isa AbstractVector
        write(io, "[")
        for (index, item) in enumerate(value)
            index > 1 && write(io, ",")
            json_write(io, item)
        end
        write(io, "]")
    elseif value isa AbstractDict
        write(io, "{")
        keys_sorted = sort(collect(keys(value)); by = string)
        for (index, key) in enumerate(keys_sorted)
            index > 1 && write(io, ",")
            json_write(io, string(key))
            write(io, ":")
            json_write(io, value[key])
        end
        write(io, "}")
    else
        error("Unsupported JSON value: $(typeof(value))")
    end
end


function write_json(path::String, value)
    mkpath(dirname(path))
    open(path, "w") do io
        json_write(io, value)
        write(io, "\n")
    end
end


function write_common_map(src_dir::String, dst_path::String)
    write_json(dst_path, declared_common_map(src_dir))
end


function main(args::Vector{String})
    if length(args) == 3 && args[1] == "--batch"
        process_tree(args[2], args[3])
        return 0
    end

    if length(args) == 3 && args[1] == "--common-map"
        write_common_map(args[2], args[3])
        return 0
    end

    if length(args) < 2
        println(stderr, "Usage: preprocess_fortran.jl src dst [--blkcom] [--labcom] [--main00] [--over1] [--dataftn]")
        println(stderr, "   or: preprocess_fortran.jl --batch src_dir dst_dir")
        println(stderr, "   or: preprocess_fortran.jl --common-map src_dir dst_json")
        return 1
    end

    src, dst = args[1], args[2]
    flags = args[3:end]
    process_file(src, dst)
    apply_flags(dst, flags)
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
