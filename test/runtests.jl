using PrecompileSignatures
using Test

const P = PrecompileSignatures

module M
    a(x::Int) = x
    b(x::Any) = x
    b(x::Union{Float64,Float32}) = b(x)
end

@test P._module_functions(M) == [M.a, M.b]

@test P._unpack_union!(Union{Float64, Int64, String, Symbol}) == [Float64, Int64, String, Symbol]

sig = Tuple{M.a, Union{Int, Float64}, Union{Float32, String}}
expected = Set([
          (Int64, Float32),
          (Int64, String),
          (Float64, Float32),
          (Float64, String)
      ])
@test PrecompileSignatures._split_union(sig) == expected

sig = Tuple{M.a, Union{Int, AbstractString}, Union{Float32, String}}
expected = Set([
    (Int64, Float32),
    (Int64, String)
])
@test PrecompileSignatures._split_union(sig) == expected

@test Set(P._directives_datatypes(sig, true)) == Set([
    Tuple{M.a, Int64, Float32},
    Tuple{M.a, Int64, String}
])
@test isempty(P._directives_datatypes(sig, false))
@test P._directives_datatypes(Tuple{M.a, Int}, true) == [Tuple{M.a, Int}]

@test Set(precompile_signatures(M)) == Set([
    Tuple{typeof(Main.M.a), Int64},
    Tuple{typeof(Main.M.b), Float64},
    Tuple{typeof(Main.M.b), Float32}
])
