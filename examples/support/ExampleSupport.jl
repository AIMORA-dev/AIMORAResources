module ExampleSupport

using Printf
using AIMORA.DeckParser: parse_deck_lines

export artifact_directory,
       parse_example_deck,
       portable_input_path,
       write_key_value_summary,
       write_matrix_csv,
       write_series_csv,
       write_waveform_svg

const COLORS = (
    "#2563eb",
    "#dc2626",
    "#059669",
    "#7c3aed",
    "#d97706",
    "#0891b2",
    "#be123c",
    "#4f46e5",
)

const PACKAGE_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

"""Return a stable package-relative label for an example input file."""
function portable_input_path(path::AbstractString)
    full_path = abspath(path)
    relative_path = relpath(full_path, PACKAGE_ROOT)
    if relative_path == ".." ||
       startswith(relative_path, "../") ||
       startswith(relative_path, "..\\")
        return basename(full_path)
    end
    return replace(relative_path, '\\' => '/')
end

"""Parse an example deck without embedding the checkout location in results."""
function parse_example_deck(path::AbstractString)
    full_path = abspath(path)
    return parse_deck_lines(
        readlines(full_path);
        source = portable_input_path(full_path),
        source_path = full_path,
    )
end

function artifact_directory(args, default_path::AbstractString)
    path = isempty(args) ? String(default_path) : String(first(args))
    mkpath(path)
    return abspath(path)
end

function _checked_series(
    x::AbstractVector{<:Real},
    series::AbstractVector{<:Pair},
)
    isempty(x) && throw(ArgumentError("waveform x values must not be empty"))
    isempty(series) && throw(ArgumentError("at least one waveform series is required"))
    x_values = Float64.(x)
    all(isfinite, x_values) || throw(ArgumentError("waveform x values must be finite"))
    output = Pair{String,Vector{Float64}}[]
    for (label, values) in series
        length(values) == length(x_values) ||
            throw(ArgumentError("waveform series $(label) length does not match x"))
        y_values = Float64.(values)
        all(isfinite, y_values) ||
            throw(ArgumentError("waveform series $(label) contains a non-finite value"))
        push!(output, String(label) => y_values)
    end
    return x_values, output
end

function write_series_csv(
    path::AbstractString,
    x_name::AbstractString,
    x::AbstractVector{<:Real},
    series::AbstractVector{<:Pair},
)
    x_values, checked = _checked_series(x, series)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join((String(x_name), (first(item) for item in checked)...), ","))
        for index in eachindex(x_values)
            @printf(io, "%.12g", x_values[index])
            for (_, values) in checked
                @printf(io, ",%.12g", values[index])
            end
            println(io)
        end
    end
    return abspath(path)
end

function write_matrix_csv(
    path::AbstractString,
    matrix::AbstractMatrix{<:Number};
    row_prefix::AbstractString = "row",
    column_prefix::AbstractString = "column",
)
    mkpath(dirname(path))
    open(path, "w") do io
        println(
            io,
            join(
                ("row", ("$(column_prefix)_$(index)" for index in axes(matrix, 2))...),
                ",",
            ),
        )
        for row in axes(matrix, 1)
            print(io, "$(row_prefix)_$(row)")
            for column in axes(matrix, 2)
                value = matrix[row, column]
                if value isa Real
                    @printf(io, ",%.12g", Float64(value))
                else
                    @printf(io, ",%.12g%+.12gim", real(value), imag(value))
                end
            end
            println(io)
        end
    end
    return abspath(path)
end

function write_key_value_summary(
    path::AbstractString,
    title::AbstractString,
    values,
)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# ", title)
        println(io)
        for (key, value) in pairs(values)
            println(io, "- `", key, "`: ", value)
        end
    end
    return abspath(path)
end

function _xml_escape(value::AbstractString)
    return replace(
        String(value),
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&apos;",
    )
end

function _plot_range(values::AbstractVector{Float64})
    lower = minimum(values)
    upper = maximum(values)
    if upper == lower
        padding = max(abs(upper), 1.0) * 0.05
        return lower - padding, upper + padding
    end
    padding = 0.05 * (upper - lower)
    return lower - padding, upper + padding
end

function _polyline_points(
    x::AbstractVector{Float64},
    y::AbstractVector{Float64},
    x_min::Float64,
    x_max::Float64,
    y_min::Float64,
    y_max::Float64,
    left::Float64,
    top::Float64,
    width::Float64,
    height::Float64,
)
    x_scale = width / (x_max - x_min)
    y_scale = height / (y_max - y_min)
    points = String[]
    sizehint!(points, length(x))
    for index in eachindex(x, y)
        px = left + (x[index] - x_min) * x_scale
        py = top + height - (y[index] - y_min) * y_scale
        push!(points, @sprintf("%.3f,%.3f", px, py))
    end
    return join(points, " ")
end

function write_waveform_svg(
    path::AbstractString,
    x::AbstractVector{<:Real},
    series::AbstractVector{<:Pair};
    title::AbstractString,
    x_label::AbstractString = "time (s)",
    y_label::AbstractString = "value",
)
    x_values, checked = _checked_series(x, series)
    all_y = reduce(vcat, (last(item) for item in checked))
    x_min, x_max = _plot_range(x_values)
    y_min, y_max = _plot_range(all_y)
    canvas_width = 960.0
    canvas_height = 560.0
    left = 92.0
    top = 70.0
    plot_width = 700.0
    plot_height = 400.0

    mkpath(dirname(path))
    open(path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="960" height="560" viewBox="0 0 960 560">""")
        println(io, """<rect width="960" height="560" fill="#ffffff"/>""")
        println(io, """<text x="480" y="34" text-anchor="middle" font-family="sans-serif" font-size="22" fill="#111827">$(_xml_escape(title))</text>""")
        println(io, """<rect x="$left" y="$top" width="$plot_width" height="$plot_height" fill="#f8fafc" stroke="#cbd5e1"/>""")
        for fraction in 0.0:0.25:1.0
            grid_y = top + fraction * plot_height
            value = y_max - fraction * (y_max - y_min)
            println(io, """<line x1="$left" y1="$grid_y" x2="$(left + plot_width)" y2="$grid_y" stroke="#e2e8f0"/>""")
            println(io, """<text x="$(left - 10)" y="$(grid_y + 4)" text-anchor="end" font-family="monospace" font-size="12" fill="#475569">$(@sprintf("%.4g", value))</text>""")
        end
        for fraction in 0.0:0.25:1.0
            grid_x = left + fraction * plot_width
            value = x_min + fraction * (x_max - x_min)
            println(io, """<line x1="$grid_x" y1="$top" x2="$grid_x" y2="$(top + plot_height)" stroke="#e2e8f0"/>""")
            println(io, """<text x="$grid_x" y="$(top + plot_height + 22)" text-anchor="middle" font-family="monospace" font-size="12" fill="#475569">$(@sprintf("%.4g", value))</text>""")
        end
        for (index, (_, values)) in enumerate(checked)
            color = COLORS[mod1(index, length(COLORS))]
            points = _polyline_points(
                x_values,
                values,
                x_min,
                x_max,
                y_min,
                y_max,
                left,
                top,
                plot_width,
                plot_height,
            )
            println(io, """<polyline points="$points" fill="none" stroke="$color" stroke-width="2"/>""")
        end
        println(io, """<text x="$(left + plot_width / 2)" y="535" text-anchor="middle" font-family="sans-serif" font-size="14" fill="#334155">$(_xml_escape(x_label))</text>""")
        println(io, """<text x="24" y="$(top + plot_height / 2)" text-anchor="middle" transform="rotate(-90 24 $(top + plot_height / 2))" font-family="sans-serif" font-size="14" fill="#334155">$(_xml_escape(y_label))</text>""")
        legend_x = left + plot_width + 24
        for (index, (label, _)) in enumerate(checked)
            color = COLORS[mod1(index, length(COLORS))]
            legend_y = top + 20 * index
            println(io, """<line x1="$legend_x" y1="$legend_y" x2="$(legend_x + 20)" y2="$legend_y" stroke="$color" stroke-width="3"/>""")
            println(io, """<text x="$(legend_x + 28)" y="$(legend_y + 4)" font-family="sans-serif" font-size="12" fill="#334155">$(_xml_escape(label))</text>""")
        end
        println(io, "</svg>")
    end
    return abspath(path)
end

end
