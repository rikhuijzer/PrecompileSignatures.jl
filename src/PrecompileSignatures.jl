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

_all_concrete(type::DataType)::Bool = isconcretetype(type)
_all_concrete(types)::Bool = all(isconcretetype.(types))

_pairs(@nospecialize(args...)) = vcat(Base.product(args...)...)

function _unpack_union!(x::Union; out=DataType[])
    push!(out, x.a)
    return _unpack_union!(x.b; out)
end
_unpack_union!(x; out=DataType[]) = push!(out, x)

"""
    _split_union(sig::DataType) -> Set{Tuple}

Return multiple `Tuple`s containing only concrete types for each combination of concrete types that can be found.
"""
function _split_union(sig::DataType)::Set{Tuple}
    method, types... = sig.parameters
    pairs = _pairs(_unpack_union!.(types)...)
    filter!(_all_concrete, pairs)
    return Set(pairs)
end

"""
Return precompile directives datatypes for signature `sig`.
Each returned `DataType` is ready to be passed to `precompile`.
"""
function _directives_datatypes(sig::DataType, split_union::Bool)::Vector{DataType}
    method, types... = sig.parameters
    _all_concrete(types) && return [sig]
    concrete_argument_types = split_union ?
        _split_union(sig) :
        Tuple(types...)
    @show concrete_argument_types
    return [Tuple{method, types...} for types in concrete_argument_types]
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
