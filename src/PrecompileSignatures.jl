module PrecompileSignatures

using Documenter.Utilities: submodules

export precompile_signatures

is_function(x) = x isa Function

"Return all functions defined in module `M`."
function _module_functions(M::Module)::Vector{Function}
    allnames = names(M; all=true)
    filter!(x -> !(x in [:eval, :include]), allnames)
    properties = getproperty.(Ref(M), allnames)
    functions = filter(is_function, properties)
    return functions
end

"Return all method signatures for function `f`."
function _signatures(f::Function)::Vector{DataType}
    return [m.sig for m in methods(f)]
end

_all_concrete(type::DataType) = isconcretetype(type)
_all_concrete(types::Vector{DataType}) = isconcretetype.(types)

"Return precompile directives for signature `sig`."
function _directives(sig::DataType, split_union::Bool)
    method, types = sig.parameters
    _all_concrete(types) && return sig
    method
    types
end

const SPLIT_UNION_DEFAULT = true

"""
    precompile_signatures(
        M::Module;
        split_union::Bool=$SPLIT_UNION_DEFAULT
    ) -> Vector{Expr}

Return a vector of precompile directives for module `M`.

Keyword arguments:

- `split_union`:
    Whether to split union types.
    For example, whether to generate two precompile directives when the type is `Union{Int,Float64}.
"""
function precompile_signatures(
        M::Module;
        split_union::Bool=SPLIT_UNION_DEFAULT
    )
    functions = _module_functions(M)
    signatures = _signatures.(functions)
end

end # module
