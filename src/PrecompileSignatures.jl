module PrecompileSignatures

using Documenter.Utilities: submodules
using Scratch: get_scratch!

export precompilables, precompile_directives, write_directives

include("precompilables.jl")

# Include generated `precompile` directives.
if ccall(:jl_generating_output, Cint, ()) == 1
    include(precompile_directives(PrecompileSignatures))
end

end # module
