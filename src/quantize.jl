# Color quantization via Median Cut algorithm for SixelPlot.jl

struct ColorBox
    colors::Vector{RGB{N0f8}}
    counts::Vector{Int}
end

function box_extent(box::ColorBox)
    rmin, rmax = 1.0, 0.0
    gmin, gmax = 1.0, 0.0
    bmin, bmax = 1.0, 0.0
    for c in box.colors
        r, g, b = Float64(red(c)), Float64(green(c)), Float64(blue(c))
        rmin = min(rmin, r); rmax = max(rmax, r)
        gmin = min(gmin, g); gmax = max(gmax, g)
        bmin = min(bmin, b); bmax = max(bmax, b)
    end
    dr = rmax - rmin
    dg = gmax - gmin
    db = bmax - bmin
    max_d = max(dr, dg, db)
    axis = max_d == dr ? 1 : (max_d == dg ? 2 : 3)
    return max_d, axis
end

"""
    median_cut(unique_colors, color_counts, max_colors)

Quantize a set of colors to at most `max_colors` using median cut.
Returns `(palette, color_map)`.
"""
function median_cut(unique_colors::Vector{RGB{N0f8}}, color_counts::Dict{RGB{N0f8}, Int}, max_colors::Int)
    if length(unique_colors) <= max_colors
        palette = unique_colors
        color_map = Dict{RGB{N0f8}, Int}(c => i - 1 for (i, c) in enumerate(palette))
        return palette, color_map
    end

    boxes = [ColorBox(unique_colors, [color_counts[c] for c in unique_colors])]
    while length(boxes) < max_colors
        best_idx = 0
        best_extent = -1.0
        best_axis = 1
        for (i, box) in enumerate(boxes)
            if length(box.colors) > 1
                ext, axis = box_extent(box)
                if ext > best_extent
                    best_extent = ext
                    best_axis = axis
                    best_idx = i
                end
            end
        end
        if best_idx == 0 || best_extent <= 0.0
            break
        end

        box = boxes[best_idx]
        sort_key = if best_axis == 1
            c -> red(c)
        elseif best_axis == 2
            c -> green(c)
        else
            c -> blue(c)
        end
        p = sortperm(box.colors, by=sort_key)
        scolors = box.colors[p]
        scounts = box.counts[p]

        total = sum(scounts)
        cum = 0
        split_idx = 1
        for i in 1:length(scounts)-1
            cum += scounts[i]
            if cum >= total / 2
                split_idx = i
                break
            end
        end

        b1 = ColorBox(scolors[1:split_idx], scounts[1:split_idx])
        b2 = ColorBox(scolors[split_idx+1:end], scounts[split_idx+1:end])
        boxes[best_idx] = b1
        push!(boxes, b2)
    end

    palette = Vector{RGB{N0f8}}()
    color_map = Dict{RGB{N0f8}, Int}()
    for (i, box) in enumerate(boxes)
        total_w = sum(box.counts)
        r_sum = sum(Float64(red(c)) * w for (c, w) in zip(box.colors, box.counts))
        g_sum = sum(Float64(green(c)) * w for (c, w) in zip(box.colors, box.counts))
        b_sum = sum(Float64(blue(c)) * w for (c, w) in zip(box.colors, box.counts))
        avg_c = RGB{N0f8}(r_sum / total_w, g_sum / total_w, b_sum / total_w)
        push!(palette, avg_c)
        idx = i - 1
        for c in box.colors
            color_map[c] = idx
        end
    end
    return palette, color_map
end

function nearest_color_index(c::RGB{N0f8}, palette::Vector{RGB{N0f8}})
    best_dist = Inf
    best_idx = 0
    cr, cg, cb = Float64(red(c)), Float64(green(c)), Float64(blue(c))
    for (i, p) in enumerate(palette)
        pr, pg, pb = Float64(red(p)), Float64(green(p)), Float64(blue(p))
        dist = (cr - pr)^2 + (cg - pg)^2 + (cb - pb)^2
        if dist < best_dist
            best_dist = dist
            best_idx = i - 1
        end
    end
    return best_idx
end
