module BinaryWrappers

export @generate_wrappers

using Scratch 
using JLLWrappers

const wrapper_key = "binarywrappers_v$(VERSION.major).$(VERSION.minor)"

# use @generate_wrappers instead to automatically deduce the calling module
function generate_wrappers(m::Module, caller::Union{Module, Base.UUID, Nothing})
    # we generate wrappers per minor julia version
    # the scratch will belong to the jll which the wrappers are generated for
    # and the usage is tied to the module calling the `@generate` macro.
    target = get_scratch!(m, wrapper_key, caller)
     
    binpath(name) = joinpath(target, "bin", name)
    mkpath(binpath(""))

    bindir = joinpath(getproperty(m, :artifact_dir), "bin")
    sourcebinary = joinpath(bindir,"\$(basename \$0)")
    libpath = getproperty(m, :LIBPATH)[]

    wrapper = """
        #!/bin/sh
        # Since we cannot run these binaries through the usual julia commands we need
        # this wrapper that sets up the correct library paths.
        export $(JLLWrappers.LIBPATH_env)="$(libpath)"
        exec $(sourcebinary) "\$@"
        """

    # For shell scripts we use `source` (.) instead of exec to avoid macOS stripping
    # the LIBPATH. This means \$0 will point to our wrapper.
    # For 4ti2 this means that its own wrapper scripts will call our wrapper for the
    # binaries, so strictly speaking adjusting the LIBPATH here is not necessary.
    scriptwrapper = """
        # We cannot run shell scripts directly as macOS will remove
        # DYLD_FALLBACK_LIBRARY_PATH for any subshells.
        # So we source the original script instead.
        export $(JLLWrappers.LIBPATH_env)="$(libpath)"
        . $(sourcebinary) "\$@"
        """

    # POSIX compatible shells
    shellre = r"^#!/bin/(ba|da|z|k)?sh"

    for bin in readdir(bindir)
        if isfile(joinpath(bindir, bin))
            (tmpfile, tmpio) = mktemp(binpath(""),cleanup=false)
            # shell scripts use a different wrapper because macOS...
            m = match(shellre, String(read(joinpath(bindir, bin), 11)))
            if m != nothing
                write(tmpio, m.match * "\n" * scriptwrapper)
            else
                write(tmpio, wrapper)
            end
            close(tmpio)
            chmod(tmpfile, 0o755)
            # using mv would introduce some race conditions due to concurrent deletes
            Base.Filesystem.rename(tmpfile, binpath(bin))
        end
    end
    return binpath("")
end

# this behaves slightly different than the @get_scratch! function:
# it will associate the scratch to the module passed as argument
# and use the calling module for the scratch usage (for gc)
macro generate_wrappers(m::Symbol)
    uuid = Base.PkgId(__module__).uuid
    return quote
        generate_wrappers($(esc(m)), $(esc(uuid)))
    end
end

end
