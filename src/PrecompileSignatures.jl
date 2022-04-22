module PrecompileSignatures

using Documenter.Utilities: submodules

export precompilables, write_directives

include("precompilables.jl")

"""
Returns the path to some extra precompile_directives.
This code runs during the precompilation phase.
"""
function _precompile_directives()
    path = joinpath(pkgdir(PrecompileSignatures), "src", "precompile.jl")
    if true # !isfile(path)
        types = precompilables(PrecompileSignatures)
        write_directives(path, types)
    end
    return path
end
include(_precompile_directives())

@show ccall(:jl_generating_output, Cint, ())

end # module
