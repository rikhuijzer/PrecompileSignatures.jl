module PrecompileSignatures

using Documenter.Utilities: submodules

export precompilables, precompile_signatures, write_directives

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

if ccall(:jl_generating_output, Cint, ()) == 1
    precompile_signatures(PrecompileSignatures)
end

end # module
