using Test
using BinaryWrappers
import lib4ti2_jll

function run_4ti2(dir::String, tool::String, example::String; wrapper=false)
    mktempdir() do tmp
        cp(dir, joinpath(tmp, example))
        tmpexample = joinpath(tmp, example, example)
        # at least one output file should be named in the outputname file
        outfile = readchomp(joinpath(tmp, example, "outputname"))
        chomp(outfile)

        if wrapper
            @test success(pipeline(`$tool $tmpexample`,devnull, devnull))
        else
            jlltool = getfield(lib4ti2_jll,Symbol(tool))
            if typeof(jlltool) == String
               # shell script wont work like this
               @test_broken success(pipeline(`$(jlltool()) $tmpexample`, devnull, devnull))
               return nothing
            else
               @test success(pipeline(`$(jlltool()) $tmpexample`, devnull, devnull))
            end
        end
        return readchomp(joinpath(tmp, example, outfile))
    end
end

@testset "lib4ti2 examples" begin
    binpath = @generate_wrappers(lib4ti2_jll)
    ENV["PATH"] = binpath * ":" * ENV["PATH"]

    @test isfile(joinpath(binpath, "circuits"))
    @test isfile(joinpath(binpath, "graver"))
    @test isfile(joinpath(binpath, "groebner"))
    @test isfile(joinpath(binpath, "hilbert"))
    @test isfile(joinpath(binpath, "zsolve"))

    path = joinpath(@__DIR__, "examples", "4ti2")


    for tool in readdir(path)
        for example in readdir(joinpath(path, tool))
            dir = joinpath(path, tool, example)

            @testset "$tool: $example" begin
                jllout = run_4ti2(dir, tool, example)
                wrapperout = run_4ti2(dir, tool, example; wrapper=true)
                if jllout != nothing && wrapperout != nothing
                    @test jllout == wrapperout
                end
            end
        end
    end
end
