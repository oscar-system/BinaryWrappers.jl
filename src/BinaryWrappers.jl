module BinaryWrappers

export @generate_wrappers

using Scratch 
using JLLWrappers

const wrapper_key = "binarywrappers_v$(VERSION.major).$(VERSION.minor)"

# use @generate instead to automatically deduce the calling module
function generate_wrappers(m::Module, caller::Union{Module,Nothing})
    # we generate wrappers per minor julia version
    # the scratch will belong to the jll which the wrappers are generated for
    # and the usage is tied to the module calling the `@generate` macro.
    target = get_scratch!(m, wrapper_key, caller)
     
    binpath(name) = joinpath(target, "bin", name)
    mkpath(binpath(""))

    bindir = joinpath(getproperty(m, :artifact_dir), "bin")
    sourcebinary = joinpath(bindir,"\$(basename \$0)")
    libpath = getproperty(m, :LIBPATH)[]

    wrapper = binpath("binary_wrapper")
    write(wrapper, """
        #!/bin/sh
        # Since we cannot run these binaries through the usual julia commands we need
        # this wrapper that sets up the correct library paths.
        export $(JLLWrappers.LIBPATH_env)="$(libpath)"
        exec $(sourcebinary) "\$@"
        """)

    scriptwrapper = binpath("script_wrapper")
    chmod(wrapper, 0o755)
    # For shell scripts we use `source` (.) instead of exec to avoid macOS stripping
    # the LIBPATH. But this means \$0 will still point to the symlink in our wrapper 
    # directory. 
    # So we do not need to adjust any library paths here.
    write(scriptwrapper, """
        #!/bin/sh
        # We cannot run shell scripts directly as macOS will remove
        # DYLD_FALLBACK_LIBRARY_PATH for any subshells.
        export $(JLLWrappers.LIBPATH_env)="$(libpath)"
        . $(sourcebinary) "\$@"
        """)
    chmod(scriptwrapper, 0o755)

    shellre = r"^#!/bin/(ba|da|z|c|tc)?sh"

    for bin in readdir(bindir)
        if isfile(joinpath(bindir, bin)) && !islink(binpath(bin))
            # shell scripts use a different wrapper because macOS...
            if occursin(shellre, String(read(joinpath(bindir, bin), 10)))
                symlink(basename(scriptwrapper), binpath(bin))
            else
                symlink(basename(wrapper), binpath(bin))
            end
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
