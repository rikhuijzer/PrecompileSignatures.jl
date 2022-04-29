module PrecompileSignatures

using Documenter.Utilities: submodules
using Scratch: get_scratch!

export precompilables, precompile_directives, write_directives, @precompile_module

function _is_macro(f::Function)
    text = sprint(show, MIME"text/plain"(), f)
    return contains(text, "macro with")
end

_is_function(x::Any) = x isa Function
_in_module(f::Function, M::Module) = typeof(f).name.module == M
_is_interesting(x::Any, M::Module) = _is_function(x) && !_is_macro(x) && _in_module(x, M)

"Return all functions defined in module `M`."
function _module_functions(M::Module)::Vector{Function}
    allnames = names(M; all=true)
    out = Function[]
    for name in allnames
        if !(name in [:eval, :include, :_precompile_])
            try
                x = getproperty(M, name)
                if _is_interesting(x, M)
                    push!(out, x)
                end
            catch
                # Caused by method ambiguities or exports without a associated function.
                continue
            end
        end
    end
    return out
end

_all_concrete(type::DataType)::Bool = isconcretetype(type)
_all_concrete(types)::Bool = all(map(isconcretetype, types))

"""
    _product(args)

Return the Cartesian product of a multiple vectors.

This method is created to avoid `Base.product(args...)` because that one returns tuples which require lots of specializations.
Thanks to https://stackoverflow.com/questions/533905.
"""
function _product(args)
    if !isempty(args)
        prod = []
        for item in args[end]
            for items in _product(args[1:end-1])
                combined = []
                for item in items
                    push!(combined, item)
                end
                push!(combined, item)
                push!(prod, combined)
            end
        end
        return prod
        # return [[items; item] for items in _product(args[1:end-1]) for item in args[end]]
    else
        # Make sure that this is iterable or the inner loop doesn't run.
        return [[]]
    end
end

# With loop: @btime PrecompileSignatures._pairs([1:200, 1:10, 1:10]) takes 690.020 μs.
# With vcat: @btime PrecompileSignatures._pairs([1:200, 1:10, 1:10]) takes 1.193 ms.
function _pairs(args)
    prod = _product(args)
    # Using a loop instead of vcat(prod...) to avoid many specializations of vcat.
    out = Vector[]
    for element in prod
        # Using a vector instead of tuples to avoid specializations further on.
        datatypes = Any[]
        for x in element
            push!(datatypes, x)
        end
        push!(out, datatypes)
    end
    return out
end

function _unpack_union!(x::Union; out=Any[])
    push!(out, x.a)
    return _unpack_union!(x.b; out)
end
function _unpack_union!(x::Any; out=Any[])
    push!(out, x)
end

function _split_unions_barrier(@nospecialize pairs)
    filtered = Vector[]
    for datatypes in pairs
        if _all_concrete(datatypes)
            push!(filtered, datatypes)
        end
    end
    return Set(filtered)
end

"Return converted type after applying `type_conversions`."
function _convert_type(type::Any, type_conversions::Dict{DataType,DataType})
    if isconcretetype(type)
        return type
    end
    out = haskey(type_conversions, type) ? type_conversions[type] : type
    return out
end

"""
    _split_unions(sig::DataType) -> Set

Return multiple `Tuple`s containing only concrete types for each combination of concrete types that can be found.
"""
function _split_unions(sig::DataType, type_conversions::Dict{DataType,DataType})::Set
    method, types... = sig.parameters
    concrete_types = Any[]
    for type in types
        unpacked = _unpack_union!(type)::Vector{Any}
        converted_types = Any[]
        for type in unpacked
            converted = _convert_type(type, type_conversions)
            if isconcretetype(converted)
                push!(converted_types, converted)
            end
        end
        push!(concrete_types, converted_types)
    end
    pairs = _pairs(concrete_types)
    return _split_unions_barrier(pairs)
end

const SUBMODULES_DEFAULT = true
const SPLIT_UNIONS_DEFAULT = true
const TYPE_CONVERSIONS_DEFAULT = Dict{DataType,DataType}(AbstractString => String)
const DEFAULT_WRITE_HEADER = """
    # This file is machine-generated by PrecompileSignatures.jl.
    # Editing it directly is not advised.\n
    """

"""
    Config(
        submodules::Bool=$SUBMODULES_DEFAULT,
        split_unions::Bool=$SPLIT_UNIONS_DEFAULT,
        type_conversions::Dict{DataType,DataType}=$TYPE_CONVERSIONS_DEFAULT,
        header::String=\$DEFAULT_WRITE_HEADER
    )

Configuration for generating precompile directives.

Keyword arguments:

- `split_unions`:
    Whether to split union types.
    For example, whether to generate two precompile directives for `f(x::Union{Int,Float64})`.
- `abstracttype_conversions`:
    Mapping of conversions from on type to another.
    For example, for all method signatures containing and argument of type `AbstractString`, you can decide to add a precompile directive for `String` for that type.
- `header`:
    Header used when writing the directives to a file.
    Defaults to:
    $DEFAULT_WRITE_HEADER
"""
@Base.kwdef struct Config
    submodules::Bool=SUBMODULES_DEFAULT
    split_unions::Bool=SPLIT_UNIONS_DEFAULT
    type_conversions::Dict{DataType,DataType}=TYPE_CONVERSIONS_DEFAULT
    header::String=DEFAULT_WRITE_HEADER
end

"""
Return precompile directives datatypes for signature `sig`.
Each returned `DataType` is ready to be passed to `precompile`.
"""
function _directives_datatypes(sig::DataType, config::Config)::Vector{DataType}
    method, types... = sig.parameters
    _all_concrete(types) && return [sig]
    if config.split_unions
        concrete_argument_types = _split_unions(sig, config.type_conversions)
        return DataType[Tuple{method, types...} for types in concrete_argument_types]
    else
        return DataType[]
    end
end

"Return all method signatures for function `f`."
function _signatures(f::Function)::Vector{DataType}
    out = DataType[]
    for method in methods(f)
        sig = method.sig
        # Ignoring parametric types for now.
        if !(sig isa UnionAll)
            push!(out, sig)
        end
    end
    return out
end

function _all_submodules(M::Vector{Module})::Vector{Module}
    out = Module[]
    for m in M
        S = submodules(m)
        for s in S
            push!(out, s)
        end
    end
    return out
end

"""
    precompilables(M::Vector{Module}, config::Config=Config()) -> Vector{DataType}
    precompilables(M::Module, config::Config=Config()) -> Vector{DataType}

Return a vector of precompile directives for module `M`.

"""
function precompilables(M::Vector{Module}, config::Config=Config())::Vector{DataType}
    if config.submodules
        M = _all_submodules(M)
    end
    out = DataType[]
    types = map(M) do mod
        functions = _module_functions(mod)
        for func in functions
            signatures = _signatures(func)
            for sig in signatures
                directives_types = _directives_datatypes(sig, config)
                for datatype in directives_types
                    push!(out, datatype)
                end
            end
        end
    end
    return out
end

function precompilables(M::Module, config::Config=Config())::Vector{DataType}
    return precompilables([M], config)
end

"""
    _precompile(argt::Type)

Compile the given `argt` such as `Tuple{typeof(sum), Vector{Int}}`.
This function is called by the generated directives.
"""
function _precompile(@nospecialize(argt::Type))
    # Not calling `precompile` since that specializes on types before #43990 (Julia ≤ 1.8).
    ret = ccall(:jl_compile_hint, Int32, (Any,), argt) != 0
    return ret
end

"""
    write_directives(path::AbstractString, types::Vector{DataType}, config::Config=Config())
    write_directives(path::AbstractString, M::AbstractVector{Module}, config::Config=Config())

Write precompile directives to file.
"""
function write_directives(
        path::AbstractString,
        types::Vector{DataType},
        config::Config=Config()
    )::String
    directives = ["    _precompile($t)" for t in types]
    joined = string(config.header, join(directives, '\n'))
    text = """
        $(config.header)
        using PrecompileSignatures: PrecompileSignatures

        let
            _precompile = PrecompileSignatures._precompile

            $joined
        end
        """
    write(path, text)
    return text
end
function write_directives(
        path::AbstractString,
        M::AbstractVector{Module},
        config::Config=Config()
    )::String
    types = precompilables(M, config)
    return write_directives(path, types, config)
end
write_directives(path, M::Module, config=Config()) = write_directives(path, [M], config)

function _precompile_path(M::Module)
    dir = get_scratch!(M, string(M))
    mkpath(dir)
    return joinpath(dir, "_precompile.jl")
end

"""
    precompile_directives(M::Module, config::Config=Config())::String

Return the path to a file containing generated `precompile` directives.

!!! note
    This package needs to write the signatures to a file and then include that.
    Evaluating the directives directly via `eval` will cause "incremental compilation fatally broken" errors.
    Calling `include` in this package also doesn't work.
"""
function precompile_directives(M::Module, config::Config=Config())::String
    # This has to be wrapped in a try-catch to avoid other packages to fail completely.
    try
        path = _precompile_path(M)
        types = precompilables(M, config)
        write_directives(path, types, config)
        return path
    catch e
        @warn "Generating precompile directives failed" exception=(e, catch_backtrace())
        # Write empty file so that `include(precompile_directives(...))` succeeds.
        path, _ = mktemp()
        write(path, "")
        return path
    end
end

macro precompile_module(M::Symbol)
    esc(quote
        if ccall(:jl_generating_output, Cint, ()) == 1
            try
                include($precompile_directives($M))
            catch e
                msg = "Generating and including the `precompile` directives failed"
                @warn msg exception=(e, catch_backtrace())
            end
        end
    end)
end

# Include generated `precompile` directives for this module.
@precompile_module(PrecompileSignatures)

end # module
