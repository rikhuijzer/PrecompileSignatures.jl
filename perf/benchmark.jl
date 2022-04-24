#
# Run via `julia --startup-file=no --project=perf perf/benchmark.jl`.
#
using BenchmarkTools: @benchmark
using MethodAnalysis: methodinstances
using Pluto: Pluto
using Profile: Profile, @profile
using ProfileSVG: ProfileSVG
using PrecompileSignatures: PrecompileSignatures, precompile_directives
using SnoopCompile: @snoopr, @snoopi_deep, flamegraph, invalidation_trees, uinvalidated, staleinstances

@show VERSION

mi_before = methodinstances(PrecompileSignatures)

if true
    println("Check for invalidations:")
    invalidations = @snoopr precompile_directives(Pluto)
    @show length(uinvalidated(invalidations))
    trees = invalidation_trees(invalidations)
    display(trees)
    println()
end

if false
    println("Check tinf:")
    tinf = @snoopi_deep precompile_directives(Pluto)
    @show tinf
    fg = flamegraph(tinf)
    path = joinpath(@__DIR__, "compile.svg")
    ProfileSVG.save(path, fg)
    println("Compilation flamegraph saved at $path")
    println()
end

if false
    println("@profile precompile_directives(Pluto):")
    @profile precompile_directives(Pluto)
    data = Profile.fetch()
    fg = flamegraph(data)
    path = joinpath(@__DIR__, "profile.svg")
    ProfileSVG.save(path, fg)
    println("Profile flamegraph saved at $path")
    println()
end

# Check for over-specializations.
println("New methodinstances created when running PrecompileSignatures:")
mi = methodinstances(PrecompileSignatures)
new_mi = filter(!in(mi_before), mi)
display(new_mi)
