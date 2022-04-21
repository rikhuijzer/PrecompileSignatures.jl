using PrecompileSignatures
using Test

const P = PrecompileSignatures

module M
    a(x::Int) = x
    b(x::Union{Int,Any}) = x
end

@test P._module_functions(M) == [M.a, M.b]

@test P._unpack_union!(Union{Float64, Int64, String, Symbol}) == [Float64, Int64, String, Symbol]

# @test P._directives_datatypes(Tuple{M.a, Int}, true) == Tuple{M.a, Int}

directives = precompile_signatures(M)

