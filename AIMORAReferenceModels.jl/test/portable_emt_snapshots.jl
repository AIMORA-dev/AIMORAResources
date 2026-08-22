using SHA

@testset "independent portable EMT canonical bytes" begin
    project_signature = bytes2hex(sha256("independent project"))
    model_signature = bytes2hex(sha256("independent model"))
    topology_signature = bytes2hex(sha256("independent topology"))
    settings_signature = bytes2hex(sha256("independent settings"))
    metadata = IndependentPortableMetadata(
        :portable_public_reference,
        project_signature,
        model_signature,
        topology_signature,
        settings_signature,
        Int128(3) // Int128(10_000),
        3,
        ["emt.fixed_step", "emt.portable_snapshot"],
        "AIMORA-authored independent portable reference";
        writer_version = "independent-test",
        creator_platform = "independent-test-platform",
    )
    voltage = independent_portable_array(
        Float64[1.0, -0.25];
        unit = "V",
        axes = ["node"],
    )
    section = IndependentPortableSection(
        "reference.accepted_state",
        1,
        0,
        :public,
        IndependentPortableRecord(
            "aimora.reference.accepted_state.v1",
            Pair{String,Any}[
                "accepted_step" => 3,
                "represented_time_s" => Int128(3) // Int128(10_000),
                "voltage" => voltage,
            ],
        ),
    )
    snapshot = IndependentPortableSnapshot(metadata, [section])
    bytes = independent_portable_snapshot_bytes(snapshot)
    restored = independent_decode_portable_snapshot(bytes)
    @test independent_portable_snapshot_bytes(restored) == bytes
    @test restored.metadata.project_signature_sha256 == project_signature
    @test restored.metadata.represented_time_s == Int128(3) // Int128(10_000)
    restored_record = only(restored.sections).value
    @test independent_portable_array_values(Dict(restored_record.fields)["voltage"]) ==
        Float64[1.0, -0.25]

    corrupted = copy(bytes)
    corrupted[end - 40] ⊻= 0x01
    @test_throws ArgumentError independent_decode_portable_snapshot(corrupted)
    @test_throws ArgumentError independent_decode_portable_snapshot(
        bytes;
        maximum_bytes = 16,
    )
end
