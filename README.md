# SixelPlot.jl

[Sixel Graphics](https://en.wikipedia.org/wiki/Sixel) backend for [Plots.jl](https://github.com/JuliaPlots/Plots.jl).
Render plots directly inside Sixel-capable terminal emulators (e.g. mlterm, xterm, WezTerm, foot, iTerm2, mintty, Rlogin).

Inspired by [pyplotsixel](https://github.com/nakagami/pyplotsixel).

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/nakagami/SixelPlot.jl")
```

## Usage

```julia
using Plots
using SixelPlot

# Activate Sixel backend
sixel()

# Standard Plots.jl usage - automatically displayed in your terminal!
plot(sin, -π, π, title="Sine Wave")
```

### Manual display and file export

```julia
p = plot([1, 2, 3], [4, 5, 6])

# Explicitly output Sixel to terminal or IO stream
show_sixel(p)

# Save to a Sixel file (.six / .sixel)
savefig(p, "output.sixel")
```

### Displaying Images

You can also display arbitrary Julia image matrices (such as arrays of `RGB` or `RGBA` colors) directly as Sixel:

```julia
using SixelPlot, ColorTypes

img = [RGB(1, 0, 0) RGB(0, 1, 0); RGB(0, 0, 1) RGB(1, 1, 0)]
show_sixel(img)
```

## Features

- **Pure Julia Sixel Encoder**: Fast encoding with run-length compression (RLE).
- **Color Quantization**: Median Cut color quantization supporting up to 256 colors.
- **Transparency Support**: 1-bit alpha transparency (terminal background shows through transparent pixels).
- **Terminal Auto-Sizing**: Queries terminal pixel dimensions via `ioctl` (`TIOCGWINSZ`) with character-cell size fallback.
- **Seamless Plots.jl Integration**: Integrates via `sixel()`, `SixelBackend`, and `SixelDisplay`.

