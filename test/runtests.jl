using Test
using SixelPlot
using Plots
using ColorTypes
using FixedPointNumbers

@testset "SixelPlot.jl Tests" begin
    @testset "Terminal Size" begin
        sz = SixelPlot.terminal_plot_size()
        @test sz isa Tuple{Int, Int}
        @test sz[1] > 0
        @test sz[2] > 0

        sz_buf = SixelPlot.terminal_plot_size(IOBuffer())
        @test sz_buf isa Tuple{Int, Int}
        @test sz_buf[1] > 0
        @test sz_buf[2] > 0
    end

    @testset "Quantization (Median Cut)" begin
        # 4 colors
        c4 = [RGB{N0f8}(1, 0, 0), RGB{N0f8}(0, 1, 0), RGB{N0f8}(0, 0, 1), RGB{N0f8}(1, 1, 1)]
        counts = Dict(c => 10 for c in c4)
        palette, cmap = SixelPlot.median_cut(c4, counts, 256)
        @test length(palette) == 4
        @test length(cmap) == 4

        # Many gradient colors
        colors = [RGB{N0f8}(i / 300, (300 - i) / 300, 0.5) for i in 1:300]
        cnts = Dict(c => 1 for c in colors)
        pal, cm = SixelPlot.median_cut(colors, cnts, 16)
        @test length(pal) <= 16
        @test length(cm) == length(unique(colors))
    end

    @testset "Sixel Encoding (RGB)" begin
        img = [RGB{N0f8}(1, 0, 0) RGB{N0f8}(0, 1, 0);
               RGB{N0f8}(0, 0, 1) RGB{N0f8}(1, 1, 0)]
        str = sixel_string(img)
        @test startswith(str, "\eP7;1;75q\"1;1;2;2")
        @test endswith(str, "\e\\\n")
        @test occursin("#", str)
        @test occursin("-", str)
    end

    @testset "Sixel Encoding (RGBA with transparency)" begin
        img = [RGBA{N0f8}(1, 0, 0, 1) RGBA{N0f8}(0, 0, 0, 0);
               RGBA{N0f8}(0, 0, 0, 0) RGBA{N0f8}(0, 0, 1, 1)]
        str = sixel_string(img)
        @test startswith(str, "\eP7;1;75q\"1;1;2;2")
        @test endswith(str, "\e\\\n")
        # Palette definition for 255 (transparent) should not be emitted
        @test !occursin("#255;2;", str)

        # Abstract element type matrix (Matrix{Colorant}) with transparency
        img_abs = Colorant[RGBA{N0f8}(1, 0, 0, 1) RGBA{N0f8}(0, 0, 0, 0);
                           RGB{N0f8}(0, 1, 0)     RGBA{N0f8}(0, 0, 1, 1)]
        str_abs = sixel_string(img_abs)
        @test startswith(str_abs, "\eP7;1;75q\"1;1;2;2")
        @test !occursin("#255;2;", str_abs)
    end

    @testset "Plots.jl Backend Integration" begin
        # Activate sixel backend
        be = sixel()
        @test be isa SixelBackend
        @test :sixel in Plots.backends()

        p = plot(sin, -π, π, size=(120, 80), title="Test Sixel")
        @test p isa Plots.Plot

        # Heatmap (> 256 colors quantization)
        hm = heatmap(rand(20, 20), size=(120, 80))
        io_hm = IOBuffer()
        show_sixel(io_hm, hm)
        out_hm = String(take!(io_hm))
        @test startswith(out_hm, "\eP7;1;75q\"1;1;120;80")
        @test endswith(out_hm, "\e\\\n")

        io = IOBuffer()
        show_sixel(io, p)
        out = String(take!(io))
        @test startswith(out, "\eP7;1;75q\"1;1;120;80")
        @test endswith(out, "\e\\\n")

        # Display via SixelDisplay
        io_disp = IOBuffer()
        d = SixelDisplay(io_disp)
        display(d, p)
        out_disp = String(take!(io_disp))
        @test startswith(out_disp, "\eP7;1;75q\"1;1;120;80")

        # Raw image display via SixelDisplay
        img = [RGB{N0f8}(1, 1, 1) RGB{N0f8}(0, 0, 0)]
        io_img = IOBuffer()
        d_img = SixelDisplay(io_img)
        display(d_img, img)
        out_img = String(take!(io_img))
        @test startswith(out_img, "\eP7;1;75q\"1;1;2;1")

        # Save to file
        tmp = tempname() * ".six"
        SixelPlot.save_sixel(p, tmp)
        @test isfile(tmp)
        content = read(tmp, String)
        @test startswith(content, "\eP7;1;75q\"1;1;120;80")
        rm(tmp)

        # savefig integration
        tmp2 = tempname() * ".sixel"
        savefig(p, tmp2)
        @test isfile(tmp2)
        content2 = read(tmp2, String)
        @test startswith(content2, "\eP7;1;75q\"1;1;120;80")
        rm(tmp2)

        disable_sixel()
    end
end
