# Terminal size detection for SixelPlot.jl
# Inspired by pyplotsixel (https://github.com/nakagami/pyplotsixel)

"""
    get_terminal_size_pixels(io::IO=stdout)

Detect terminal window size in pixels via `ioctl` (TIOCGWINSZ).
Returns `(width, height)` in pixels, or `nothing` if unavailable.
"""
function get_terminal_size_pixels(io::IO=stdout)
    if !Sys.isunix()
        return nothing
    end

    TIOCGWINSZ = Sys.isapple() ? 0x40087468 : 0x5413

    # Try file descriptors: io, stdout (1), stdin (0), stderr (2)
    fds = Int[]
    if io isa Base.TTY && isdefined(io, :handle) && io.handle != C_NULL
        fd_ref = Ref{Cint}(0)
        ret = ccall(:uv_fileno, Cint, (Ptr{Cvoid}, Ptr{Cint}), io.handle, fd_ref)
        if ret == 0
            push!(fds, Int(fd_ref[]))
        end
    elseif io isa IOStream
        push!(fds, Int(Base.fd(io)))
    end
    for fd in (1, 0, 2)
        fd in fds || push!(fds, fd)
    end

    for fd in fds
        ws = Ref{NTuple{4, UInt16}}((0, 0, 0, 0))
        ret = ccall(:ioctl, Cint, (Cint, Culong, Ptr{Cvoid}), fd, TIOCGWINSZ, ws)
        if ret == 0
            row, col, xpixel, ypixel = ws[]
            if xpixel > 0 && ypixel > 0
                return (Int(xpixel), max(1, Int(ypixel) - 60))
            end
        end
    end

    # Fallback to /dev/tty if accessible
    if ispath("/dev/tty")
        try
            open("/dev/tty") do tty
                ws = Ref{NTuple{4, UInt16}}((0, 0, 0, 0))
                ret = ccall(:ioctl, Cint, (Cint, Culong, Ptr{Cvoid}), Base.fd(tty), TIOCGWINSZ, ws)
                if ret == 0
                    row, col, xpixel, ypixel = ws[]
                    if xpixel > 0 && ypixel > 0
                        return (Int(xpixel), max(1, Int(ypixel) - 60))
                    end
                end
            end
        catch
        end
    end

    return nothing
end

"""
    terminal_plot_size(io::IO=stdout; dpi=100)

Return estimated `(width, height)` in pixels for plotting in the terminal.
If pixel size cannot be determined via ioctl, estimates size based on column and line count.
"""
function terminal_plot_size(io::IO=stdout; dpi=100)
    res = get_terminal_size_pixels(io)
    if res !== nothing
        return res
    end

    lines, cols = displaysize(io)
    width = cols * 10
    height = max(1, lines - 3) * 20
    return (width, height)
end
