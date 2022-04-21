using PrecompileSignatures
using Test

const P = PrecompileSignatures

module M
    a(x::Int) = x
    b(x::Union{Int,Any}) = x
end

@test P._module_functions(M) == [M.a, M.b]

@test P._unpack_union!(Union{Float64, Int64, String, Symbol}) == [Float64, Int64, String, Symbol]

f(a, b) = 3

sig = Tuple{f, Union{Int, Float64}, Union{Float32, String}}
expected = Set([
          (Int64, Float32),
          (Int64, String),
          (Float64, Float32),
          (Float64, String)
      ])
@test PrecompileSignatures._split_union(sig) == expected

sig = Tuple{f, Union{Int, AbstractString}, Union{Float32, String}}
expected = Set([
    (Int64, Float32),
    (Int64, String)
])
@test PrecompileSignatures._split_union(sig) == expected

# @test P._directives_datatypes(Tuple{M.a, Int}, true) == Tuple{M.a, Int}
#

directives = precompile_signatures(M)

