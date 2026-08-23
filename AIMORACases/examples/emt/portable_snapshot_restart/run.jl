#!/usr/bin/env julia

using SHA

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using .ExampleSupport

const SNAPSHOTS = AIMORA.PortableSnapshots
const TIMESTEP_S = 100.0e-6
const CAPTURE_STEP_COUNT = 3
const FINAL_STEP_COUNT = 6
const CASE_DECK = joinpath(@__DIR__, "portable_snapshot_restart.deck")

stable_signature(text::AbstractString) = bytes2hex(sha256(String(text)))

function portable_snapshot_signatures()
    deck_identity = bytes2hex(sha256(read(CASE_DECK)))
    return (
        project=stable_signature("AIMORA portable snapshot public case\n$deck_identity"),
        model=stable_signature("Bergeron line, resistor, source, switch, output\n$deck_identity"),
        settings=stable_signature("fixed_step=$(TIMESTEP_S);capture=$(CAPTURE_STEP_COUNT)"),
    )
end

function prepared_study(parsed, step_count::Int)
    step_count > 0 || throw(ArgumentError("portable snapshot step count must be positive"))
    return AIMORA.EMTStudy.prepare_emt_study(
        parsed;
        dt_s=TIMESTEP_S,
        t_end_s=step_count * TIMESTEP_S,
    )
end

function public_reference_snapshot()
    metadata = SNAPSHOTS.PortableSnapshotMetadata(
        :portable_public_reference,
        stable_signature("portable public-reference project"),
        stable_signature("portable public-reference model"),
        stable_signature("portable public-reference topology"),
        stable_signature("portable public-reference settings"),
        Int128(3) // Int128(10_000),
        3,
        ["emt.fixed_step", "emt.portable_snapshot"],
        "AIMORA-authored public accepted-state reference";
        writer_version="AIMORACases.jl/0.1.0",
        creator_platform="aimora-public-case",
    )
    voltage = SNAPSHOTS.portable_snapshot_array(
        Float64[1.0, -0.25];
        unit="V",
        axes=["node"],
    )
    record = SNAPSHOTS.PortableSnapshotRecord(
        "aimora.reference.accepted_state.v1",
        Pair{String,Any}[
            "accepted_step" => 3,
            "represented_time_s" => Int128(3) // Int128(10_000),
            "voltage" => voltage,
        ],
    )
    return SNAPSHOTS.PortableEMTSnapshot(
        metadata,
        [SNAPSHOTS.PortableSnapshotSection(
            "reference.accepted_state",
            1,
            0,
            :public,
            record,
        )],
    )
end

function portable_failure_code(operation)
    try
        operation()
    catch error
        error isa SNAPSHOTS.PortableSnapshotFailure || rethrow()
        return error.code
    end
    return :not_refused
end

function main()
    output_directory = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    parsed = parse_example_deck(CASE_DECK)
    AIMORA.DeckParser.assert_deck_valid!(parsed)
    signatures = portable_snapshot_signatures()

    split_prepared = prepared_study(parsed, CAPTURE_STEP_COUNT)
    split_workspace = AIMORA.EMTStudy.EMTStudyWorkspace(split_prepared)
    AIMORA.EMTStudy.evaluate_emt_study!(split_workspace)
    capture_inventory = AIMORA.EMTStudy.portable_emt_state_inventory(split_workspace)

    full_path = joinpath(output_directory, "portable_full.aimora-snapshot")
    full_descriptor = AIMORA.EMTStudy.write_portable_emt_workspace_snapshot(
        full_path,
        split_workspace;
        project_signature_sha256=signatures.project,
        model_signature_sha256=signatures.model,
        settings_signature_sha256=signatures.settings,
        provenance="AIMORA-authored portable snapshot/restart public case",
    )
    inspected = SNAPSHOTS.inspect_portable_emt_snapshot(full_path)
    repeated_path = joinpath(output_directory, ".portable_full_repeated.aimora-snapshot")
    repeated_descriptor = AIMORA.EMTStudy.write_portable_emt_workspace_snapshot(
        repeated_path,
        split_workspace;
        project_signature_sha256=signatures.project,
        model_signature_sha256=signatures.model,
        settings_signature_sha256=signatures.settings,
        provenance="AIMORA-authored portable snapshot/restart public case",
    )
    deterministic_bytes = read(full_path) == read(repeated_path)
    rm(repeated_path; force=true)

    restored = AIMORA.EMTStudy.read_portable_emt_workspace_snapshot(
        full_path,
        split_prepared;
        project_signature_sha256=signatures.project,
        model_signature_sha256=signatures.model,
        settings_signature_sha256=signatures.settings,
    )
    full_workspace = AIMORA.EMTStudy.EMTStudyWorkspace(
        prepared_study(parsed, FINAL_STEP_COUNT),
    )
    full_trace = AIMORA.EMTStudy.evaluate_emt_study!(full_workspace)
    restart_request = AIMORA.DeckParser.parse_emt_restart_request([
        "START AGAIN",
        lpad("9999", 8),
    ])
    resumed = AIMORA.EMTStudy.restart_emt_study!(
        restored.workspace,
        restart_request;
        additional_time_s=(FINAL_STEP_COUNT - CAPTURE_STEP_COUNT) * TIMESTEP_S,
    )
    exact_time = resumed.trace.time_s == full_trace.time_s
    exact_voltage = resumed.trace.voltage_pu == full_trace.voltage_pu
    exact_output = resumed.trace.output_pu == full_trace.output_pu

    corrupted_path = joinpath(output_directory, ".portable_corrupted.aimora-snapshot")
    corrupted = read(full_path)
    corrupted[end - 40] = xor(corrupted[end - 40], UInt8(0x01))
    write(corrupted_path, corrupted)
    corruption_failure = portable_failure_code(
        () -> SNAPSHOTS.inspect_portable_emt_snapshot(corrupted_path),
    )
    rm(corrupted_path; force=true)
    before_identity = AIMORA.EMTStudy.portable_emt_state_inventory(
        split_workspace,
    ).signature_sha256
    identity_failure = portable_failure_code(() ->
        AIMORA.EMTStudy.read_portable_emt_workspace_snapshot(
            full_path,
            split_prepared;
            project_signature_sha256=signatures.project,
            model_signature_sha256=stable_signature("changed public-case model"),
            settings_signature_sha256=signatures.settings,
        )
    )
    after_identity = AIMORA.EMTStudy.portable_emt_state_inventory(
        split_workspace,
    ).signature_sha256

    public_path = joinpath(output_directory, "portable_public_reference.aimora-snapshot")
    public_descriptor = SNAPSHOTS.write_portable_emt_snapshot(
        public_path,
        public_reference_snapshot(),
    )
    public_decoded = SNAPSHOTS.read_portable_emt_snapshot(public_path)
    public_solver_free_readable =
        public_decoded.metadata.profile == :portable_public_reference &&
        all(section -> section.visibility == :public, public_decoded.sections)

    trace_csv = write_series_csv(
        joinpath(output_directory, "portable_snapshot_restart.csv"),
        "time_s",
        full_trace.time_s,
        Pair{String,Vector{Float64}}[
            "uninterrupted_voltage_pu" => vec(full_trace.voltage_pu[1, :]),
            "resumed_voltage_pu" => vec(resumed.trace.voltage_pu[1, :]),
        ],
    )
    trace_svg = write_waveform_svg(
        joinpath(output_directory, "portable_snapshot_restart.svg"),
        full_trace.time_s,
        Pair{String,Vector{Float64}}[
            "uninterrupted" => vec(full_trace.voltage_pu[1, :]),
            "split/restarted" => vec(resumed.trace.voltage_pu[1, :]),
        ];
        title="Portable Snapshot Split/Uninterrupted EMT Replay",
        y_label="voltage (pu)",
    )
    summary = write_key_value_summary(
        joinpath(output_directory, "summary.md"),
        "Portable EMT Snapshot and Exact Restart",
        (
            profile=inspected.metadata.profile,
            schema="$(inspected.schema_major).$(inspected.schema_minor)",
            section_identities=join(getfield.(inspected.sections, :identity), ","),
            section_visibilities=join(string.(getfield.(inspected.sections, :visibility)), ","),
            accepted_step=inspected.metadata.accepted_step,
            represented_time_s=Float64(inspected.metadata.represented_time_s),
            public_state_fields=length(capture_inventory.fields),
            public_state_scalars=capture_inventory.scalar_count,
            canonical_bytes=full_descriptor.canonical_bytes,
            content_sha256=full_descriptor.content_sha256,
            deterministic_bytes,
            deterministic_descriptor=repeated_descriptor.content_sha256 ==
                full_descriptor.content_sha256,
            exact_time,
            exact_voltage,
            exact_output,
            checkpoint_state_error=resumed.checkpoint_state_error,
            public_reference_bytes=public_descriptor.canonical_bytes,
            public_reference_sha256=public_descriptor.content_sha256,
            public_solver_free_readable,
            corruption_failure,
            identity_failure,
            identity_refusal_atomic=before_identity == after_identity,
            private_solver_required_for_reconstruction=true,
            unsupported="ATP/PSCAD restart compatibility, live migration, encryption, signatures, FMI/SSP/HELICS, DASSL, GPU state, hard-real-time/HIL, hostile-input safety, certification, and unexecuted operating systems",
        ),
    )

    deterministic_bytes || error("repeated portable capture changed canonical bytes")
    exact_time && exact_voltage && exact_output || error(
        "portable split continuation differs from uninterrupted execution",
    )
    resumed.checkpoint_state_error == 0.0 || error(
        "portable restart changed checkpoint state",
    )
    public_solver_free_readable || error("public reference snapshot is not public-only")
    corruption_failure == :integrity || error("corrupt portable bytes were not refused")
    identity_failure == :model_mismatch || error("changed model identity was not refused")
    before_identity == after_identity || error("identity refusal mutated the source workspace")

    println("Portable full snapshot: ", full_path)
    println("Portable public reference: ", public_path)
    println("Trace CSV: ", trace_csv)
    println("Trace SVG: ", trace_svg)
    println("Summary: ", summary)
end

main()
