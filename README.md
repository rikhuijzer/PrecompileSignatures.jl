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

## How dow does this package relate to SnoopCompile?

Like this package, [SnoopCompile.jl](https://github.com/timholy/SnoopCompile.jl) can also generate precompile directives.
Where this package does it by reading code and signatures, SnoopCompile runs code to find directives.
Because SnoopCompile runs the code, it can find much more directives.
However, the problem with running code is that it takes long.
For example, to generate a lot of precompile directives in [Pluto.jl](https://github.com/fonsp/Pluto.jl), we could run all tests.
This takes about 20 minutes.
Conversely, this package takes about 20 seconds to generate directives for all modules in Pluto.
In practise, this means that this package can re-generate the directives with each start of the package whereas SnoopCompile's directives have to be cached, that is, stored in the repository.

## Further notes

Unfortunately, in many cases, inference will run all over again even after some method has been "precompiled".
For more information about this, see https://github.com/JuliaLang/julia/issues/38951#issuecomment-749153888 and the related discussions.
