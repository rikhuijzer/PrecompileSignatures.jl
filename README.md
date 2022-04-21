# PrecompileSignatures.jl

This package reads all method signatures in a package and generates precompile directives for any concrete signature that it can find.
Essentially, this is a brute force way to reduce the time to first X.

In essence, it allows package maintainers to generate precompile directives via specifying concrete argument types in method signatures.
For example, for the function
```julia
function f(x::Int, y::Float64)
    return x
end
```

this package will generate

```julia
precompile(f, (Int, Float64))
```

To not restrict methods too much, this package will also create that `precompile` directive for the following signature:

```julia
function f(x::Union{Int,Any}, y::Float64)
    return x
end
```
