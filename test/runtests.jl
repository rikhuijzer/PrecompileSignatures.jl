using Pluto: PlutoRunner
using PrecompileSignatures
using Test

const P = PrecompileSignatures
const Config = P.Config

module M
    a(x::Int) = x
    b(x::Any) = x
    b(x::Union{Float64,Float32}) = b(x)
    c(x::T) where {T<:AbstractString} = x
end

@test P._module_functions(M) == [M.a, M.b, M.c]

@test P._unpack_union!(Union{Float64, Int64, String, Symbol}) == [Float64, Int64, String, Symbol]

PrecompileSignatures._pairs([[1, 2], [3, 4]]) == [
    [1, 3],
    [2, 3],
    [1, 4],
    [2, 4]
]

PrecompileSignatures._pairs([[1, 2], [3], [5, 6]]) == [
    [1, 3, 5],
    [2, 3, 5],
    [1, 3, 6],
    [2, 3, 6]
]

args = [[Float64], [Float32, String]]
expected = Any[Any[Float64, Float32], Any[Float64, String]]
@test PrecompileSignatures._pairs(args) == expected

type_conversions = P.TYPE_CONVERSIONS_DEFAULT
sig = Tuple{M.a, Union{Int, Float64}, Union{Float32, String}}
expected = Set(Any[
        Any[Int64, Float32],
        Any[Int64, String],
        Any[Float64, Float32],
        Any[Float64, String]
    ])
@test PrecompileSignatures._split_unions(sig, type_conversions) == expected

sig = Tuple{M.a, Union{Symbol, Number}, Union{Float32, String}}
expected = Set([
    [Symbol, Float32],
    [Symbol, String]
])
@test PrecompileSignatures._split_unions(sig, type_conversions) == expected

sig = Tuple{M.a, Union{AbstractString, Int}, Union{Float32, Symbol}}
expected = Set([
    [String, Float32],
    [String, Symbol],
    [Int64, Float32],
    [Int64, Symbol]
])
@test PrecompileSignatures._split_unions(sig, type_conversions) == expected

expected = Set([
    [Int64, Float32],
    [Int64, Symbol]
])
type_conversions = Dict{DataType,DataType}()
@test PrecompileSignatures._split_unions(sig, type_conversions) == expected

sig = Tuple{M.a, Union{String, Number}, Union{Float32, String}}
@test Set(P._directives_datatypes(sig, Config())) == Set([
    Tuple{M.a, String, Float32},
    Tuple{M.a, String, String}
])
@test isempty(P._directives_datatypes(sig, Config(; split_unions=false)))
@test P._directives_datatypes(Tuple{M.a, Int}, Config()) == [Tuple{M.a, Int}]

@test Set(precompilables(M)) == Set([
    Tuple{typeof(Main.M.a), Int64},
    Tuple{typeof(Main.M.b), Float64},
    Tuple{typeof(Main.M.b), Float32}
])

types = precompilables(PlutoRunner)
@test 40 < length(types)
@test all(precompile.(types))

mktemp() do path, io
    types = precompilables(M)
    text = write_directives(path, types)
    @test contains(text, "machine-generated")
    @test contains(text, "precompile(Tuple{typeof(Main.M.a), Int64})")
end

try
    1 + "foo"
catch
    error = P._error_text()
    @test contains(error, "no method matching")
    @test contains(error, "Stacktrace:\n")
end


