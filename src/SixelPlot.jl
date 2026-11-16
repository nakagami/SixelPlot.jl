module SixelPlot

using ColorTypes
using FixedPointNumbers
using PNGFiles
using Plots

export sixel, show_sixel, output_sixel, sixel_string
export SixelDisplay, enable_sixel, disable_sixel
export SixelBackend

include("terminal.jl")
include("quantize.jl")
include("sixel.jl")

# ------------------------------------------------------------------------------
# Sixel Display
# ------------------------------------------------------------------------------

"""
    SixelDisplay(io::IO=stdout)

An `AbstractDisplay` that renders Plots.jl figures and image matrices
directly to a Sixel-capable terminal.
"""
struct SixelDisplay <: AbstractDisplay
    io::IO
end

SixelDisplay() = SixelDisplay(stdout)

const _sixel_display = Ref{Union{SixelDisplay, Nothing}}(nothing)
const _prev_gkswstype = Ref{Union{String, Nothing}}(nothing)
const _gkswstype_was_set = Ref{Bool}(false)

"""
    enable_sixel(io::IO=stdout)

Enable Sixel display in the current Julia session by pushing `SixelDisplay`
onto the display stack.
"""
function enable_sixel(io::IO=stdout)
    if !_gkswstype_was_set[]
        _prev_gkswstype[] = get(ENV, "GKSwstype", nothing)
        _gkswstype_was_set[] = true
    end
    ENV["GKSwstype"] = "nul"
    if isdefined(Plots, :GR) && isdefined(Plots.GR, :emergencyclosegks)
        Plots.GR.emergencyclosegks()
    end

    d = _sixel_display[]
    if d !== nothing
        try
            Base.Multimedia.popdisplay(d)
        catch
        end
    end
    new_d = SixelDisplay(io)
    Base.Multimedia.pushdisplay(new_d)
    _sixel_display[] = new_d
    return new_d
end

"""
    disable_sixel()

Disable Sixel display by removing `SixelDisplay` from the display stack.
"""
function disable_sixel()
    d = _sixel_display[]
    if d !== nothing
        try
            Base.Multimedia.popdisplay(d)
        catch
        end
        _sixel_display[] = nothing
    end
    if _gkswstype_was_set[]
        if _prev_gkswstype[] === nothing
            delete!(ENV, "GKSwstype")
        else
            ENV["GKSwstype"] = _prev_gkswstype[]
        end
        _prev_gkswstype[] = nothing
        _gkswstype_was_set[] = false
        if isdefined(Plots, :GR) && isdefined(Plots.GR, :emergencyclosegks)
            Plots.GR.emergencyclosegks()
        end
    end
    return nothing
end

function _render_png(plt::Plots.Plot)
    buf = IOBuffer()
    withenv("GKSwstype" => "nul") do
        show(buf, MIME("image/png"), plt)
    end
    seekstart(buf)
    return PNGFiles.load(buf)
end

# Display hook for Plots.Plot
function Base.display(d::SixelDisplay, plt::Plots.Plot)
    if _sixel_display[] === d && !(plt.backend isa Plots.GRBackend)
        throw(MethodError(display, (d, plt)))
    end
    img = _render_png(plt)
    output_sixel(d.io, img)
    return nothing
end

# Display hook for raw images
function Base.display(d::SixelDisplay, img::AbstractMatrix{<:Colorant})
    output_sixel(d.io, img)
    return nothing
end

"""
    show_sixel([io::IO,] plt::Plots.Plot)
    show_sixel([io::IO,] img::AbstractMatrix{<:Colorant})

Render a plot or image as Sixel graphics to `io` (defaults to `stdout`).
"""
function show_sixel(io::IO, plt::Plots.Plot)
    img = _render_png(plt)
    output_sixel(io, img)
    return nothing
end

show_sixel(plt::Plots.Plot) = show_sixel(stdout, plt)
show_sixel(io::IO, img::AbstractMatrix{<:Colorant}) = output_sixel(io, img)
show_sixel(img::AbstractMatrix{<:Colorant}) = output_sixel(stdout, img)

# ------------------------------------------------------------------------------
# Plots.jl Backend registration and activation
# ------------------------------------------------------------------------------

struct SixelBackend <: Plots.AbstractBackend end

Plots.backend_name(::SixelBackend) = :sixel
Plots.backend_package_name(::SixelBackend) = :SixelPlot

# Delegate capability queries to GRBackend
for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    @eval begin
        Plots.$f1(::SixelBackend, x) = Plots.$f1(Plots.GRBackend(), x)
        Plots.$f2(::SixelBackend) = Plots.$f2(Plots.GRBackend())
    end
end

Plots._initialize_backend(::SixelBackend) = nothing

function register_backend!()
    if !(:sixel in Plots._backends)
        push!(Plots._backends, :sixel)
        Plots._backendType[:sixel] = SixelBackend
        Plots._backendSymbol[SixelBackend] = :sixel
        Plots._backend_packages[:sixel] = :SixelPlot
    end
    if isdefined(Plots, :_savemap)
        Plots._savemap["six"] = save_sixel
        Plots._savemap["sixel"] = save_sixel
    end
end

"""
    sixel(; kw...)

Activate the Sixel backend for Plots.jl.
Automatically adjusts plot size to terminal dimensions (if `size` is not specified in `kw`).
"""
function sixel(; kw...)
    register_backend!()

    # Ensure underlying rasterizer (GR) is initialized headlessly
    if !_gkswstype_was_set[]
        _prev_gkswstype[] = get(ENV, "GKSwstype", nothing)
        _gkswstype_was_set[] = true
    end
    ENV["GKSwstype"] = "nul"
    if isdefined(Plots, :GR) && isdefined(Plots.GR, :emergencyclosegks)
        Plots.GR.emergencyclosegks()
    end
    Plots.gr()

    # Determine plot dimensions
    sz = terminal_plot_size(stdout)
    plot_kw = haskey(kw, :size) ? kw : merge((size = sz,), kw)
    Plots.default(; reset = false, plot_kw...)

    # Enable Sixel display
    enable_sixel()

    return SixelBackend()
end

# Save Sixel output to file
function save_sixel(plt::Plots.Plot, fn::AbstractString)
    img = _render_png(plt)
    open(fn, "w") do f
        output_sixel(f, img)
    end
    return fn
end

function __init__()
    register_backend!()
end

end # module SixelPlot
