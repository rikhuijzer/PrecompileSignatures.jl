#
# Run via `julia --startup-file=no --project=perf perf/benchmark.jl`.
#
using AbstractTrees: print_tree
using BenchmarkTools: @benchmark, @btime
using Cthulhu: ascend
using MethodAnalysis: methodinstances
using Pluto: Pluto
using Profile: Profile, @profile
using ProfileSVG: ProfileSVG
using PrecompileSignatures: PrecompileSignatures, precompile_directives
using SnoopCompile: @snoopr, @snoopi_deep, flamegraph, inclusive, inference_triggers, invalidation_trees, uinvalidated, staleinstances

warmup(x) = x
@time @eval warmup(1)

@show VERSION

mi_before = methodinstances(PrecompileSignatures)

if false
    println("Check for invalidations:")
    invalidations = @snoopr precompile_directives(Pluto)
    @show length(uinvalidated(invalidations))
    trees = invalidation_trees(invalidations)
    display(trees)
    println()
end

tinf = if true
    println("Check tinf:")
    tinf = @snoopi_deep precompile_directives(Pluto)
    @show tinf
    fg = flamegraph(tinf)
    path = joinpath(@__DIR__, "compile.svg")
    ProfileSVG.save(path, fg)
    println("Compilation flamegraph saved at $path")
    println()
    tinf
else
    nothing
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

if false
    println("New methodinstances created inside `PrecompileSignatures` during execution:")
    mi = methodinstances(PrecompileSignatures)
    new_mi = filter(!in(mi_before), mi)
    display(new_mi)
end

if true
    println("New methodinstances created everywhere during execution:")
    sorted_children = sort(tinf.children; by=inclusive, rev=false)
    display(sorted_children)
    # Displaying the total again since that's useful.
    println()
    display(tinf)
    @btime precompile_directives(Pluto)
end

# Don't do print_tree(tinf). It's too much.
# To go really in depth use `ascend(itrigs)` after figuring out how to do it XD.
# Doing ascend(itrigs[n]) works but is too inconvenient.
# itrigs = inference_triggers(tinf)
# ascend(itrigs)

