module PrecompileSignatures

export precompile_signatures

is_function(x) = x isa Function

function _module_functions(M::Module)
    allnames = names(M; all=true)
    filter!(x -> !(x in [:eval, :include]), allnames)
    properties = getproperty.(Ref(M), allnames)
    functions = filter(is_function, properties)
    return functions
end

function precompile_signatures(M::Module)
    functions = _module_functions(M)
end

end # module
