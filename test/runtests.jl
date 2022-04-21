using Test

module M

a(x::Int) = x

b(x::Union{Int,Any}) = x

end # module

@test PrecompileSignatures._module_functions(M) == [M.a, M.b]

directives = precompile_signatures(M)

