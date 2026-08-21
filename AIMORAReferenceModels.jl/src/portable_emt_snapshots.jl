using Unicode

const _INDEPENDENT_PORTABLE_MAGIC = collect(codeunits("AIMORA-PORTABLE-EMT"))
const _INDEPENDENT_PORTABLE_MAJOR = UInt16(1)
const _INDEPENDENT_PORTABLE_MINOR = UInt16(1)
const _INDEPENDENT_PORTABLE_DIGEST_BYTES = 32

const _INDEPENDENT_NULL = UInt8(0)
const _INDEPENDENT_FALSE = UInt8(1)
const _INDEPENDENT_TRUE = UInt8(2)
const _INDEPENDENT_SIGNED = UInt8(3)
const _INDEPENDENT_UNSIGNED = UInt8(4)
const _INDEPENDENT_FLOAT64 = UInt8(5)
const _INDEPENDENT_TEXT = UInt8(6)
const _INDEPENDENT_BYTES = UInt8(7)
const _INDEPENDENT_SEQUENCE = UInt8(8)
const _INDEPENDENT_RECORD = UInt8(9)
const _INDEPENDENT_ARRAY = UInt8(10)
const _INDEPENDENT_RATIONAL = UInt8(11)

function _independent_portable_identity(value::AbstractString, label::AbstractString)
    identity = String(value)
    occursin(r"^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$", identity) ||
        throw(ArgumentError("$label is not a stable lowercase identity"))
    return identity
end

function _independent_portable_text(value::AbstractString, label::AbstractString)
    text = String(value)
    Unicode.normalize(text, :NFC) == text || throw(ArgumentError(
        "$label is not normalized UTF-8 text",
    ))
    return text
end

function _independent_portable_digest(value::AbstractString, label::AbstractString)
    digest = String(value)
    occursin(r"^[0-9a-f]{64}$", digest) || throw(ArgumentError(
        "$label is not a lowercase SHA-256 identity",
    ))
    return digest
end

function _independent_write_unsigned(io::IO, value::T) where {T<:Unsigned}
    for byte_index in 0:(sizeof(T) - 1)
        write(io, UInt8((value >> (8 * byte_index)) & T(0xff)))
    end
    return nothing
end

function _independent_read_unsigned(io::IO, ::Type{T}) where {T<:Unsigned}
    value = zero(T)
    for byte_index in 0:(sizeof(T) - 1)
        eof(io) && throw(ArgumentError("independent portable integer is truncated"))
        value |= T(read(io, UInt8)) << (8 * byte_index)
    end
    return value
end

struct IndependentPortableArray
    element_kind::Symbol
    shape::Vector{Int}
    unit::String
    axes::Vector{String}
    bytes::Vector{UInt8}

    function IndependentPortableArray(
        element_kind::Symbol,
        shape::AbstractVector{<:Integer},
        unit::AbstractString,
        axes::AbstractVector{<:AbstractString},
        bytes::AbstractVector{UInt8},
    )
        element_kind in (:float64, :int64, :uint64) || throw(ArgumentError(
            "independent portable array element kind is unsupported",
        ))
        dimensions = Int[dimension for dimension in shape]
        all(dimension -> dimension >= 0, dimensions) || throw(ArgumentError(
            "independent portable array shape must be nonnegative",
        ))
        axis_names = String[
            _independent_portable_identity(axis, "independent portable array axis")
            for axis in axes
        ]
        length(axis_names) == length(dimensions) || throw(ArgumentError(
            "independent portable array axis count must equal rank",
        ))
        element_count = isempty(dimensions) ? 1 : prod(dimensions; init = 1)
        length(bytes) == 8 * element_count || throw(ArgumentError(
            "independent portable array payload does not match its shape",
        ))
        if element_kind == :float64
            io = IOBuffer(bytes)
            for _ in 1:element_count
                isfinite(reinterpret(Float64, _independent_read_unsigned(io, UInt64))) ||
                    throw(ArgumentError("independent portable array is nonfinite"))
            end
        end
        return new(
            element_kind,
            dimensions,
            _independent_portable_text(unit, "independent portable array unit"),
            axis_names,
            Vector{UInt8}(bytes),
        )
    end
end

function independent_portable_array(
    values::AbstractArray{T};
    unit::AbstractString,
    axes::AbstractVector{<:AbstractString},
) where {T<:Union{Float64,Int64,UInt64}}
    io = IOBuffer()
    for value in values
        encoded = T === Float64 ? reinterpret(UInt64, value) :
            T === Int64 ? reinterpret(UInt64, value) : value
        _independent_write_unsigned(io, encoded)
    end
    kind = T === Float64 ? :float64 : T === Int64 ? :int64 : :uint64
    return IndependentPortableArray(kind, collect(size(values)), unit, axes, take!(io))
end

function independent_portable_array_values(array::IndependentPortableArray)
    io = IOBuffer(array.bytes)
    count = isempty(array.shape) ? 1 : prod(array.shape; init = 1)
    values = if array.element_kind == :float64
        Float64[reinterpret(Float64, _independent_read_unsigned(io, UInt64)) for _ in 1:count]
    elseif array.element_kind == :int64
        Int64[reinterpret(Int64, _independent_read_unsigned(io, UInt64)) for _ in 1:count]
    else
        UInt64[_independent_read_unsigned(io, UInt64) for _ in 1:count]
    end
    return reshape(values, Tuple(array.shape))
end

struct IndependentPortableRecord
    schema_id::String
    fields::Vector{Pair{String,Any}}

    function IndependentPortableRecord(
        schema_id::AbstractString,
        fields::AbstractVector{<:Pair},
    )
        normalized = Pair{String,Any}[
            _independent_portable_identity(String(first(field)), "independent portable field") =>
                last(field)
            for field in fields
        ]
        sort!(normalized; by = first)
        length(unique(first.(normalized))) == length(normalized) || throw(ArgumentError(
            "independent portable record repeats a field",
        ))
        return new(
            _independent_portable_identity(schema_id, "independent portable schema"),
            normalized,
        )
    end
end

struct IndependentPortableMetadata
    profile::Symbol
    project_signature_sha256::String
    model_signature_sha256::String
    topology_signature_sha256::String
    settings_signature_sha256::String
    represented_time_s::Rational{Int128}
    accepted_step::Int64
    capabilities::Vector{String}
    provenance::String
    writer_version::String
    creator_platform::String
    numeric_profile::String
    compression::String
    minimum_reader_version::String

    function IndependentPortableMetadata(
        profile::Symbol,
        project_signature_sha256::AbstractString,
        model_signature_sha256::AbstractString,
        topology_signature_sha256::AbstractString,
        settings_signature_sha256::AbstractString,
        represented_time_s::Rational,
        accepted_step::Integer,
        capabilities::AbstractVector{<:AbstractString},
        provenance::AbstractString;
        writer_version::AbstractString="AIMORAReferenceModels.jl/0.1.0",
        creator_platform::AbstractString="independent-reference",
        numeric_profile::AbstractString="ieee754_binary64_finite_preserve_signed_zero",
        compression::AbstractString="none",
        minimum_reader_version::AbstractString="1.0",
    )
        profile in (:portable_full, :portable_public_reference) || throw(ArgumentError(
            "independent portable profile is unsupported",
        ))
        0 <= accepted_step <= typemax(Int64) || throw(ArgumentError(
            "independent portable accepted step is invalid",
        ))
        time = Rational{Int128}(represented_time_s)
        capability_ids = sort!(unique(String[
            _independent_portable_identity(value, "independent portable capability")
            for value in capabilities
        ]))
        return new(
            profile,
            _independent_portable_digest(project_signature_sha256, "project signature"),
            _independent_portable_digest(model_signature_sha256, "model signature"),
            _independent_portable_digest(topology_signature_sha256, "topology signature"),
            _independent_portable_digest(settings_signature_sha256, "settings signature"),
            time,
            Int64(accepted_step),
            capability_ids,
            _independent_portable_text(provenance, "independent portable provenance"),
            _independent_portable_text(writer_version, "independent portable writer version"),
            _independent_portable_text(creator_platform, "independent portable creator platform"),
            String(numeric_profile),
            String(compression),
            String(minimum_reader_version),
        )
    end
end

struct IndependentPortableSection
    identity::String
    version_major::UInt16
    version_minor::UInt16
    visibility::Symbol
    value::Any

    function IndependentPortableSection(
        identity::AbstractString,
        version_major::Integer,
        version_minor::Integer,
        visibility::Symbol,
        value,
    )
        visibility in (:public, :private_reconstructible) || throw(ArgumentError(
            "independent portable section visibility is unsupported",
        ))
        return new(
            _independent_portable_identity(identity, "independent portable section"),
            UInt16(version_major),
            UInt16(version_minor),
            visibility,
            value,
        )
    end
end

struct IndependentPortableSnapshot
    metadata::IndependentPortableMetadata
    sections::Vector{IndependentPortableSection}

    function IndependentPortableSnapshot(
        metadata::IndependentPortableMetadata,
        sections::AbstractVector{IndependentPortableSection},
    )
        normalized = sort!(collect(sections); by = section -> section.identity)
        isempty(normalized) && throw(ArgumentError("independent portable snapshot is empty"))
        length(unique(getfield.(normalized, :identity))) == length(normalized) ||
            throw(ArgumentError("independent portable snapshot repeats a section"))
        metadata.profile == :portable_public_reference &&
            any(section -> section.visibility != :public, normalized) &&
            throw(ArgumentError("independent public snapshot contains private state"))
        return new(metadata, normalized)
    end
end

function _independent_write_string(io::IO, value::AbstractString)
    bytes = codeunits(value)
    length(bytes) <= typemax(UInt32) || throw(ArgumentError(
        "independent portable text is too large",
    ))
    _independent_write_unsigned(io, UInt32(length(bytes)))
    write(io, bytes)
    return nothing
end

function _independent_write_value(io::IO, value)
    if value === nothing
        write(io, _INDEPENDENT_NULL)
    elseif value === false
        write(io, _INDEPENDENT_FALSE)
    elseif value === true
        write(io, _INDEPENDENT_TRUE)
    elseif value isa Signed
        write(io, _INDEPENDENT_SIGNED)
        _independent_write_unsigned(io, reinterpret(UInt64, Int64(value)))
    elseif value isa Unsigned
        write(io, _INDEPENDENT_UNSIGNED)
        _independent_write_unsigned(io, UInt64(value))
    elseif value isa AbstractFloat
        isfinite(value) || throw(ArgumentError("independent portable float is nonfinite"))
        write(io, _INDEPENDENT_FLOAT64)
        _independent_write_unsigned(io, reinterpret(UInt64, Float64(value)))
    elseif value isa AbstractString
        write(io, _INDEPENDENT_TEXT)
        _independent_write_string(io, _independent_portable_text(value, "independent portable value"))
    elseif value isa AbstractVector{UInt8}
        write(io, _INDEPENDENT_BYTES)
        _independent_write_unsigned(io, UInt64(length(value)))
        write(io, value)
    elseif value isa Rational
        numerator_value = Int128(numerator(value))
        denominator_value = Int128(denominator(value))
        write(io, _INDEPENDENT_RATIONAL)
        _independent_write_unsigned(io, reinterpret(UInt128, numerator_value))
        _independent_write_unsigned(io, UInt128(denominator_value))
    elseif value isa IndependentPortableArray
        write(io, _INDEPENDENT_ARRAY)
        _independent_write_string(io, String(value.element_kind))
        _independent_write_unsigned(io, UInt32(length(value.shape)))
        for dimension in value.shape
            _independent_write_unsigned(io, UInt64(dimension))
        end
        _independent_write_string(io, value.unit)
        for axis in value.axes
            _independent_write_string(io, axis)
        end
        _independent_write_unsigned(io, UInt64(length(value.bytes)))
        write(io, value.bytes)
    elseif value isa IndependentPortableRecord
        write(io, _INDEPENDENT_RECORD)
        _independent_write_string(io, value.schema_id)
        _independent_write_unsigned(io, UInt32(length(value.fields)))
        for field in value.fields
            _independent_write_string(io, first(field))
            _independent_write_value(io, last(field))
        end
    elseif value isa AbstractVector || value isa Tuple
        write(io, _INDEPENDENT_SEQUENCE)
        _independent_write_unsigned(io, UInt64(length(value)))
        for item in value
            _independent_write_value(io, item)
        end
    else
        throw(ArgumentError("independent portable value kind is unsupported"))
    end
    return nothing
end

function _independent_value_bytes(value)
    io = IOBuffer()
    _independent_write_value(io, value)
    return take!(io)
end

function _independent_metadata_record(metadata::IndependentPortableMetadata)
    return IndependentPortableRecord(
        "aimora.snapshot.metadata.v1",
        Pair{String,Any}[
            "accepted_step" => metadata.accepted_step,
            "capabilities" => metadata.capabilities,
            "compression" => metadata.compression,
            "creator_platform" => metadata.creator_platform,
            "minimum_reader_version" => metadata.minimum_reader_version,
            "model_signature_sha256" => metadata.model_signature_sha256,
            "numeric_profile" => metadata.numeric_profile,
            "profile" => String(metadata.profile),
            "project_signature_sha256" => metadata.project_signature_sha256,
            "provenance" => metadata.provenance,
            "represented_time_s" => metadata.represented_time_s,
            "settings_signature_sha256" => metadata.settings_signature_sha256,
            "topology_signature_sha256" => metadata.topology_signature_sha256,
            "writer_version" => metadata.writer_version,
        ],
    )
end

function _independent_section_digest(section::IndependentPortableSection, payload)
    io = IOBuffer()
    _independent_write_string(io, section.identity)
    _independent_write_unsigned(io, section.version_major)
    _independent_write_unsigned(io, section.version_minor)
    write(io, section.visibility == :public ? UInt8(0) : UInt8(1))
    _independent_write_unsigned(io, UInt64(length(payload)))
    write(io, payload)
    return sha256(take!(io))
end

function independent_portable_snapshot_bytes(snapshot::IndependentPortableSnapshot)
    body = IOBuffer()
    write(body, _INDEPENDENT_PORTABLE_MAGIC)
    _independent_write_unsigned(body, _INDEPENDENT_PORTABLE_MAJOR)
    _independent_write_unsigned(body, _INDEPENDENT_PORTABLE_MINOR)
    metadata_bytes = _independent_value_bytes(_independent_metadata_record(snapshot.metadata))
    _independent_write_unsigned(body, UInt64(length(metadata_bytes)))
    write(body, sha256(metadata_bytes))
    write(body, metadata_bytes)
    _independent_write_unsigned(body, UInt32(length(snapshot.sections)))
    for section in snapshot.sections
        _independent_write_string(body, section.identity)
        _independent_write_unsigned(body, section.version_major)
        _independent_write_unsigned(body, section.version_minor)
        write(body, section.visibility == :public ? UInt8(0) : UInt8(1))
        payload = _independent_value_bytes(section.value)
        _independent_write_unsigned(body, UInt64(length(payload)))
        write(body, _independent_section_digest(section, payload))
        write(body, payload)
    end
    body_bytes = take!(body)
    return vcat(body_bytes, sha256(body_bytes))
end

function _independent_read_exact(io::IO, count::Integer, label::AbstractString)
    bytes = read(io, Int(count))
    length(bytes) == count || throw(ArgumentError("$label is truncated"))
    return bytes
end

function _independent_read_string(io::IO, label::AbstractString; maximum_bytes::Int)
    count = Int(_independent_read_unsigned(io, UInt32))
    count <= maximum_bytes || throw(ArgumentError("$label exceeds its limit"))
    bytes = _independent_read_exact(io, count, label)
    isvalid(String, bytes) || throw(ArgumentError("$label is not UTF-8"))
    return _independent_portable_text(String(bytes), label)
end

function _independent_read_value(io::IO; maximum_bytes::Int, depth::Int=0)
    depth <= 64 || throw(ArgumentError("independent portable nesting is excessive"))
    eof(io) && throw(ArgumentError("independent portable value is truncated"))
    tag = read(io, UInt8)
    tag == _INDEPENDENT_NULL && return nothing
    tag == _INDEPENDENT_FALSE && return false
    tag == _INDEPENDENT_TRUE && return true
    tag == _INDEPENDENT_SIGNED && return reinterpret(Int64, _independent_read_unsigned(io, UInt64))
    tag == _INDEPENDENT_UNSIGNED && return _independent_read_unsigned(io, UInt64)
    if tag == _INDEPENDENT_FLOAT64
        value = reinterpret(Float64, _independent_read_unsigned(io, UInt64))
        isfinite(value) || throw(ArgumentError("independent portable float is nonfinite"))
        return value
    elseif tag == _INDEPENDENT_TEXT
        return _independent_read_string(io, "independent portable text"; maximum_bytes)
    elseif tag == _INDEPENDENT_BYTES
        count = Int(_independent_read_unsigned(io, UInt64))
        count <= maximum_bytes || throw(ArgumentError("independent portable bytes exceed limit"))
        return _independent_read_exact(io, count, "independent portable bytes")
    elseif tag == _INDEPENDENT_RATIONAL
        numerator_value = reinterpret(Int128, _independent_read_unsigned(io, UInt128))
        denominator_value = _independent_read_unsigned(io, UInt128)
        0 < denominator_value <= UInt128(typemax(Int128)) || throw(ArgumentError(
            "independent portable rational denominator is invalid",
        ))
        return numerator_value // Int128(denominator_value)
    elseif tag == _INDEPENDENT_SEQUENCE
        count = Int(_independent_read_unsigned(io, UInt64))
        count <= maximum_bytes || throw(ArgumentError("independent portable sequence exceeds limit"))
        return Any[
            _independent_read_value(io; maximum_bytes, depth = depth + 1)
            for _ in 1:count
        ]
    elseif tag == _INDEPENDENT_RECORD
        schema = _independent_read_string(io, "independent portable schema"; maximum_bytes)
        count = Int(_independent_read_unsigned(io, UInt32))
        fields = Pair{String,Any}[]
        for _ in 1:count
            name = _independent_read_string(io, "independent portable field"; maximum_bytes)
            push!(fields, name => _independent_read_value(io; maximum_bytes, depth = depth + 1))
        end
        record = IndependentPortableRecord(schema, fields)
        first.(record.fields) == first.(fields) || throw(ArgumentError(
            "independent portable record is not canonical",
        ))
        return record
    elseif tag == _INDEPENDENT_ARRAY
        kind_text = _independent_read_string(io, "independent portable array kind"; maximum_bytes=32)
        kind = kind_text == "float64" ? :float64 : kind_text == "int64" ? :int64 :
            kind_text == "uint64" ? :uint64 : throw(ArgumentError(
                "independent portable array kind is unsupported",
            ))
        rank = Int(_independent_read_unsigned(io, UInt32))
        rank <= 32 || throw(ArgumentError("independent portable array rank is excessive"))
        shape = Int[Int(_independent_read_unsigned(io, UInt64)) for _ in 1:rank]
        unit = _independent_read_string(io, "independent portable array unit"; maximum_bytes=1024)
        axes = String[
            _independent_read_string(io, "independent portable array axis"; maximum_bytes=1024)
            for _ in 1:rank
        ]
        count = Int(_independent_read_unsigned(io, UInt64))
        count <= maximum_bytes || throw(ArgumentError("independent portable array exceeds limit"))
        return IndependentPortableArray(
            kind,
            shape,
            unit,
            axes,
            _independent_read_exact(io, count, "independent portable array"),
        )
    end
    throw(ArgumentError("independent portable value tag is unsupported"))
end

function _independent_metadata(record::IndependentPortableRecord)
    fields = Dict(record.fields)
    return IndependentPortableMetadata(
        Symbol(fields["profile"]),
        fields["project_signature_sha256"],
        fields["model_signature_sha256"],
        fields["topology_signature_sha256"],
        fields["settings_signature_sha256"],
        fields["represented_time_s"],
        fields["accepted_step"],
        String[value for value in fields["capabilities"]],
        fields["provenance"];
        writer_version = fields["writer_version"],
        creator_platform = fields["creator_platform"],
        numeric_profile = get(fields, "numeric_profile", "ieee754_binary64_finite_preserve_signed_zero"),
        compression = get(fields, "compression", "none"),
        minimum_reader_version = get(fields, "minimum_reader_version", "1.0"),
    )
end

function independent_decode_portable_snapshot(
    bytes::AbstractVector{UInt8};
    maximum_bytes::Int=64 * 1024 * 1024,
)
    length(bytes) <= maximum_bytes || throw(ArgumentError("independent portable file exceeds limit"))
    minimum_length = length(_INDEPENDENT_PORTABLE_MAGIC) + 2 * sizeof(UInt16) +
        sizeof(UInt64) + _INDEPENDENT_PORTABLE_DIGEST_BYTES + sizeof(UInt32) +
        _INDEPENDENT_PORTABLE_DIGEST_BYTES
    length(bytes) >= minimum_length || throw(ArgumentError("independent portable file is truncated"))
    body = @view bytes[1:(end - _INDEPENDENT_PORTABLE_DIGEST_BYTES)]
    digest = @view bytes[(end - _INDEPENDENT_PORTABLE_DIGEST_BYTES + 1):end]
    sha256(body) == digest || throw(ArgumentError("independent portable envelope digest failed"))
    io = IOBuffer(body)
    _independent_read_exact(io, length(_INDEPENDENT_PORTABLE_MAGIC), "independent portable magic") ==
        _INDEPENDENT_PORTABLE_MAGIC || throw(ArgumentError("independent portable magic is wrong"))
    major = _independent_read_unsigned(io, UInt16)
    minor = _independent_read_unsigned(io, UInt16)
    major == _INDEPENDENT_PORTABLE_MAJOR || throw(ArgumentError("independent portable major is unsupported"))
    minor <= _INDEPENDENT_PORTABLE_MINOR || throw(ArgumentError("independent portable minor is unsupported"))
    metadata_length = Int(_independent_read_unsigned(io, UInt64))
    metadata_length <= maximum_bytes || throw(ArgumentError("independent portable metadata exceeds limit"))
    metadata_digest = _independent_read_exact(io, 32, "independent portable metadata digest")
    metadata_bytes = _independent_read_exact(io, metadata_length, "independent portable metadata")
    sha256(metadata_bytes) == metadata_digest || throw(ArgumentError("independent portable metadata digest failed"))
    metadata_io = IOBuffer(metadata_bytes)
    metadata_record = _independent_read_value(metadata_io; maximum_bytes)
    eof(metadata_io) || throw(ArgumentError("independent portable metadata trails"))
    metadata_record isa IndependentPortableRecord || throw(ArgumentError("independent portable metadata is not a record"))
    metadata = _independent_metadata(metadata_record)
    section_count = Int(_independent_read_unsigned(io, UInt32))
    section_count > 0 || throw(ArgumentError("independent portable snapshot has no sections"))
    sections = IndependentPortableSection[]
    previous_identity = ""
    for _ in 1:section_count
        identity = _independent_read_string(io, "independent portable section"; maximum_bytes=1024)
        isempty(previous_identity) || previous_identity < identity || throw(ArgumentError(
            "independent portable sections are not canonical",
        ))
        previous_identity = identity
        version_major = _independent_read_unsigned(io, UInt16)
        version_minor = _independent_read_unsigned(io, UInt16)
        visibility_code = read(io, UInt8)
        visibility = visibility_code == 0 ? :public : visibility_code == 1 ?
            :private_reconstructible : throw(ArgumentError(
                "independent portable section visibility is invalid",
            ))
        payload_length = Int(_independent_read_unsigned(io, UInt64))
        payload_length <= maximum_bytes || throw(ArgumentError("independent portable payload exceeds limit"))
        payload_digest = _independent_read_exact(io, 32, "independent portable section digest")
        payload = _independent_read_exact(io, payload_length, "independent portable section payload")
        provisional = IndependentPortableSection(
            identity,
            version_major,
            version_minor,
            visibility,
            nothing,
        )
        _independent_section_digest(provisional, payload) == payload_digest ||
            throw(ArgumentError("independent portable section digest failed"))
        payload_io = IOBuffer(payload)
        value = _independent_read_value(payload_io; maximum_bytes)
        eof(payload_io) || throw(ArgumentError("independent portable section trails"))
        push!(sections, IndependentPortableSection(
            identity,
            version_major,
            version_minor,
            visibility,
            value,
        ))
    end
    eof(io) || throw(ArgumentError("independent portable envelope trails"))
    return IndependentPortableSnapshot(metadata, sections)
end
