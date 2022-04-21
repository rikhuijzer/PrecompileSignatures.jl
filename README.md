# PrecompileSignatures.jl

This package reads all method signatures in a package and generates precompile directives for any concrete signature that it can find.
This is a brute force way to reduce the time to first X.

In essence, it allows package maintainers to generate precompile directives via specifying concrete argument types in method signatures.
For example, for the function
```julia
function f(x::Int, y::Float64)
    return x
end
```

this package will generate

```julia
precompile(Tuple{typeof(f), Int, Float64})
```

This package will also create that `precompile` directive for `(Int, Float64)` and `(Float32, Float64)` from the following method definitions:

```julia
function f(x, y)
    return x
end
f(x::Union{Int,Float32}, y::Float64}) = f(x)
```

This splitting of union types can be disabled by setting `split_union=false`.

**Note**

Unfortunately, writing

```julia
function f(x::Union{Float64,Float32,Any}, y::Float64})
    return x
end
```

doesn't generate `precompile` directives for `Float64` and `Float32` on `x` because the signature is simplified to `Any` by Julia's internals:

```julia
julia> z(x::Union{Int,Any}) = x;

julia> only(methods(z)).sig
Tuple{typeof(z), Any}
```

In other words, this package cannot easily extract all types mentioned in the union in this case.
