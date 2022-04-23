#
# Run via `julia --project=perf perf/benchmark.jl`.
#
using BenchmarkTools: @benchmark
using Pluto: Pluto
using Profile: Profile, @profile
using ProfileSVG: ProfileSVG
using PrecompileSignatures: precompilables
using SnoopCompile: @snoopi_deep, flamegraph

println("@snoopi_deep precompilables(Pluto):")
let
    tinf = @snoopi_deep precompilables(Pluto)
    @show tinf
    fg = flamegraph(tinf)
    path = joinpath(@__DIR__, "compile.svg")
    ProfileSVG.save(path, fg)
    println("Compilation flamegraph saved at $path")
    println()
end

println("@profile precompilables(Pluto):")
let
    @profile precompilables(Pluto)
    data = Profile.fetch()
    fg = flamegraph(data)
    path = joinpath(@__DIR__, "profile.svg")
    ProfileSVG.save(path, fg)
    println("Profile flamegraph saved at $path")
    println()
end
