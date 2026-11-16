# Sixel encoder for SixelPlot.jl
# Reference: pyplotsixel (https://github.com/nakagami/pyplotsixel)

"""
    output_sixel(io::IO, img::AbstractMatrix{<:Colorant})

Convert an image matrix to Sixel format and write to `io`.
Supports RGB and RGBA images with transparency handling.
"""
function output_sixel(io::IO, img::AbstractMatrix{<:Colorant})
    height, width = size(img)
    if height == 0 || width == 0
        return
    end

    has_alpha = eltype(img) <: TransparentColor ||
                (isabstracttype(eltype(img)) && any(px -> px isa TransparentColor, img))
    transparent_idx = -1

    rgb_data = Matrix{RGB{N0f8}}(undef, height, width)
    alpha_mask = fill(false, height, width)

    if has_alpha
        for x in 1:width, y in 1:height
            px = img[y, x]
            a = Float64(alpha(px))
            if a == 0.0
                alpha_mask[y, x] = true
                rgb_data[y, x] = RGB{N0f8}(0, 0, 0)
            else
                # Alpha compositing with black background
                r = Float64(red(px)) * a
                g = Float64(green(px)) * a
                b = Float64(blue(px)) * a
                rgb_data[y, x] = RGB{N0f8}(r, g, b)
            end
        end
        transparent_idx = 255
        max_colors = 255
    else
        for x in 1:width, y in 1:height
            rgb_data[y, x] = RGB{N0f8}(img[y, x])
        end
        max_colors = 256
    end

    # Collect opaque pixels
    opaque_colors = [rgb_data[y, x] for x in 1:width, y in 1:height if !alpha_mask[y, x]]
    if isempty(opaque_colors)
        return
    end

    # Color frequency
    color_counts = Dict{RGB{N0f8}, Int}()
    for c in opaque_colors
        color_counts[c] = get(color_counts, c, 0) + 1
    end
    unique_c = collect(keys(color_counts))

    palette, color_map = median_cut(unique_c, color_counts, max_colors)

    # Build indexed image
    indexed = Matrix{Int}(undef, height, width)
    for x in 1:width, y in 1:height
        if alpha_mask[y, x]
            indexed[y, x] = transparent_idx
        else
            c = rgb_data[y, x]
            indexed[y, x] = get(color_map, c) do
                nearest_color_index(c, palette)
            end
        end
    end

    # Sixel Header
    print(io, "\eP7;1;75q\"1;1;", width, ";", height)

    # Sixel Palette definitions
    used_colors = Set{Int}(indexed)
    for i in sort(collect(used_colors))
        if i == transparent_idx
            continue
        end
        c = palette[i + 1]
        r_pct = round(Int, Float64(red(c)) * 100)
        g_pct = round(Int, Float64(green(c)) * 100)
        b_pct = round(Int, Float64(blue(c)) * 100)
        print(io, "#", i, ";2;", r_pct, ";", g_pct, ";", b_pct)
    end

    # Sixel Body (bands of 6 vertical pixels)
    for y in 1:6:height
        h_band = min(6, height - y + 1)
        band_colors = Set{Int}()
        for dy in 0:h_band-1, x in 1:width
            col = indexed[y + dy, x]
            if col != transparent_idx
                push!(band_colors, col)
            end
        end

        for col in sort(collect(band_colors))
            print(io, "#", col)
            prev_six = -1
            run_len = 0
            for x in 1:width
                six = 0
                for dy in 0:h_band-1
                    if indexed[y + dy, x] == col
                        six |= (1 << dy)
                    end
                end
                if six == prev_six
                    run_len += 1
                else
                    if run_len > 0
                        if run_len < 4
                            print(io, Char(0x3f + prev_six)^run_len)
                        else
                            print(io, "!", run_len, Char(0x3f + prev_six))
                        end
                    end
                    prev_six = six
                    run_len = 1
                end
            end
            if run_len > 0
                if run_len < 4
                    print(io, Char(0x3f + prev_six)^run_len)
                else
                    print(io, "!", run_len, Char(0x3f + prev_six))
                end
            end
            print(io, "\$")
        end
        print(io, "-")
    end

    # Terminate Sixel
    print(io, "\e\\\n")
    flush(io)
    return nothing
end

output_sixel(img::AbstractMatrix{<:Colorant}) = output_sixel(stdout, img)

"""
    sixel_string(img::AbstractMatrix{<:Colorant})

Return Sixel escape sequence as a string for the given image matrix.
"""
function sixel_string(img::AbstractMatrix{<:Colorant})
    io = IOBuffer()
    output_sixel(io, img)
    return String(take!(io))
end
