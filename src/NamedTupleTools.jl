"""
     NamedTupleTools

This module provides some useful NamedTuple tooling.

see [`namedtuple`](@ref), [`isprototype`](@ref),
    [`fieldnames`](@ref), [`fieldtypes`](@ref), [`fieldvalues`](@ref)
    [`delete`](@ref), [`merge`](@ref)
"""
module NamedTupleTools

export @namedtuple,
       namedtuple, isprototype, prototype,
       propertynames, fieldnames, fieldvalues, fieldtypes,
       merge,
       split,
       delete,
       select,
       ntfromstruct, structfromnt,
       @structfromnt

import Base: propertynames, fieldnames, valtype, values, merge, split

if isdefined(Base, :fieldtypes)
     import Base: fieldtypes
else
     export fieldtypes
end

# accept comma delimited values
NamedTuple{T}(xs...) where {T} = NamedTuple{T}(xs)

propertynames(nt::NamedTuple{N,T}) where {N,T} = N   # correct
fieldnames(nt::NamedTuple{N,T}) where {N,T} = N      # deprecate

"""
    fieldvalues

obtain values assigned to fields of a struct type
(in field order)
"""
function fieldvalues(x::T) where {T}
     !isstructtype(T) && throw(ArgumentError("$(T) is not a struct type"))
     
     return ((getfield(x, name) for name in fieldnames(T))...,)
end

"""
    fieldtypes( namedtuple )
    fieldtypes( typeof(namedtuple) )

Retrieve the values' types as a tuple.

see: [`valtype`](@ref)
"""
fieldtypes(x::NamedTuple{N,S}) where {N,S} = (S.parameters...,)
fieldtypes(::Type{NamedTuple{N,S}}) where {N,S<:Tuple} = (S.parameters...,)

"""
    valtype( namedtuple )

valtype(::Type{NamedTuple{N,S}}) where {N,S} = S
Retrieve the values' types as a typeof(tuple).

see: [`fieldtypes`](@ref)
"""
valtype(x::NamedTuple{N,S}}) where {N,S} = S
valtype(::Type{NamedTuple{N,S}}) where {N,S} = S

"""
    untuple( Tuple{_} )

Retrieve the types that are internal to the `Tuple` as a (_).
"""
untuple(::Type{T}) where {T<:Tuple} = (T.parameters...,)


"""
    retuple( (_) )

Generate a `Tuple` with the given internal types as a `Tuple{_}`.
"""
retuple(x::Tuple) = Tuple{x...,}


namedtuple(x::NamedTuple) = x
namedtuple(x::DataType) = ntfromstruct(x)

function ntfromstruct(x::T) where {T}
     !isstructtype(T) && throw(ArgumentError("$(T) is not a struct type"))
     names = fieldnames(T)
     values = fieldvalues(x)
     return NamedTuple{names}(values)
end

# an instance of type S, a Struct
function structfromnt(::Type{S}, x::NT) where {S, N, T, NT<:NamedTuple{N,T}}
     names = N
     values = fieldvalues(x)
     if fieldnames(S) != names
          throw(ErrorException("fields in ($S) do not match ($x)"))
     end
     return S(values...,)
end

# the Struct itself
function structfromnt(structname::Union{Symbol, String}, nt::NamedTuple{N,T}) where {N,T}
    sname = Symbol(structname)
    names = N
    types = untuple(T)
    tostruct = Meta.parse(NamedTupleTools.struct_from(sname, names, types))
    eval(tostruct) # generate Struct
    return nothing
end

macro structfromnt(sname, nt)
    :( eval(structfromnt($(esc(sname)), $(esc(nt)))) )
end

# Expr part from Fredrik Ekre   
struct_from(structname, names, types) = 
	"Expr(:struct,
		false,
		Expr(:curly,
			 :$structname
		),
		Expr(:block,
			map((x,y) -> Expr(:(::), x, y), $names, $types)...
		)
	)"
	
structfrom(structname, names, types) = eval(eval(Meta.parse(struct_from(structname, names, types))))

"""
    namedtuple(namesforvalues, valuesfornames)
"""

# from kristoffer.carlsson

@inline function namedtuple(namesforvalues::NTuple{N,Symbol}, valuesfornames) where {N}
    N == length(valuesfornames) || throw(ErrorException("lengths must match"))
    return (; zip(namesforvalues, valuesfornames)...,)
end

@inline function namedtuple(namesforvalues::Vector{Symbol}, valuesfornames)
    length(namesforvalues) == length(valuesfornames) || throw(ErrorException("lengths must match"))
     return (; zip(namesforvalues, valuesfornames)...,)
end

namedtuple(namesforvalues::Vector{S}, valuesfornames) where {N,S<:AbstractString} =
    namedtuple(Symbol.(namesforvalues), valuesfornames)

namedtuple(namesforvalues::NTuple{N,S}, valuesfornames) where {N,S<:AbstractString} =
    namedtuple(Symbol.(namesforvalues), valuesfornames)


"""
    namedtuple(  name1, name2, ..  )
    namedtuple( (name1, name2, ..) )
    namedtuple(  namedtuple )

Generate a NamedTuple prototype by specifying or obtaining the fieldnames.
The prototype is applied to fieldvalues, giving a completed NamedTuple.

# Example

julia> ntprototype = namedtuple( :a, :b, :c )

NamedTuple{(:a, :b, :c),T} where T<:Tuple

julia> nt123 = ntprototype(1, 2, 3)

(a = 1, b = 2, c = 3)

julia> ntAb3 = ntprototype("A", "b", 3)

(a = "A", b = "b", c = 3)

see: [`isprototype`](@ref)
"""
namedtuple(names::NTuple{N,Symbol}) where {N} = NamedTuple{names}
namedtuple(names::Vararg{Symbol}) = NamedTuple{names}
namedtuple(names::NTuple{N,String}) where {N}  = namedtuple(Symbol.(names))
namedtuple(names::Vararg{String}) = namedtuple(Symbol.(names))
namedtuple(names::T) where {T<:AbstractVector{Symbol}} = namedtuple(names...,)
namedtuple(names::T) where {T<:AbstractVector{String}} = namedtuple(Symbol.(names))

# namedtuple(nt::T) where {N,V,T<:NamedTuple{N,V}} = NamedTuple{N}
# for speed
namedtuple(nm1::T) where T<:Symbol = NamedTuple{(nm1,)}
namedtuple(nm1::T, nm2::T) where T<:Symbol = NamedTuple{(nm1,nm2)}
namedtuple(nm1::T, nm2::T, nm3::T) where T<:Symbol = NamedTuple{(nm1,nm2,nm3)}
namedtuple(nm1::T, nm2::T, nm3::T, nm4::T) where T<:Symbol = NamedTuple{(nm1,nm2,nm3,nm4)}
namedtuple(nm1::T, nm2::T, nm3::T, nm4::T, nm5::T) where T<:Symbol =
    NamedTuple{(nm1,nm2,nm3,nm4,nm5)}
namedtuple(nm1::T, nm2::T, nm3::T, nm4::T, nm5::T, nm6::T) where T<:Symbol =
    NamedTuple{(nm1,nm2,nm3,nm4,nm5,nm6)}
namedtuple(nm1::T, nm2::T, nm3::T, nm4::T, nm5::T, nm6::T, nm7::T) where T<:Symbol =
    NamedTuple{(nm1,nm2,nm3,nm4,nm5,nm6,nm7)}
namedtuple(nm1::T, nm2::T, nm3::T, nm4::T, nm5::T, nm6::T, nm7::T, nm8::T) where T<:Symbol =
    NamedTuple{(nm1,nm2,nm3,nm4,nm5,nm6,nm7,nm8)}
namedtuple(nm1::T, nm2::T, nm3::T, nm4::T, nm5::T, nm6::T, nm7::T, nm8::T, nm9::T) where T<:Symbol =
    NamedTuple{(nm1,nm2,nm3,nm4,nm5,nm6,nm7,nm8,nm9)}
namedtuple(nm1::T, nm2::T, nm3::T, nm4::T, nm5::T, nm6::T, nm7::T, nm8::T, nm9::T, nm10::T) where T<:Symbol =
    NamedTuple{(nm1,nm2,nm3,nm4,nm5,nm6,nm7,nm8,nm9,nm10)}

"""
    prototype(namedtuple)
    prototype(typeof(namedtuple))

provides the prototype `NamedTuple{names, T} where T<:Tuple`
    - `names` is a tuple of symbols
"""
prototype(::NamedTuple{A,B}) where {A,B} = NamedTuple{A}
prototype(::Type{NamedTuple{A,B}}) where {A,B} = NamedTuple{A}

"""
    isprototype( ntprototype )
    isprototype( namedtuple  )

Predicate that identifies NamedTuple prototypes.

see: [`namedtuple`](@ref)
"""
isprototype(::Type{T}) where {T<:NamedTuple} = eltype(T) === Any
isprototype(nt::T) where {T<:NamedTuple} = false
isprototype(::Type{UnionAll}) = false

"""
   delete(namedtuple, symbol(s)|Tuple)
   delete(ntprototype, symbol(s)|Tuple)
   
Generate a namedtuple [ntprototype] from the first arg omitting fields present in the second arg.

see: [`merge`](@ref)
"""
delete(a::NamedTuple, b::Symbol) = Base.structdiff(a, namedtuple(b))
delete(a::NamedTuple, b::NTuple{N,Symbol}) where {N} = Base.structdiff(a, namedtuple(b))
delete(a::NamedTuple, bs::Vararg{Symbol}) = Base.structdiff(a, namedtuple(bs))

delete(::Type{T}, b::Symbol) where {S,T<:NamedTuple{S}} = namedtuple((Base.setdiff(S,(b,))...,))
delete(::Type{T}, b::NTuple{N,Symbol}) where {S,N,T<:NamedTuple{S}} = namedtuple((Base.setdiff(S,b)...,))
delete(::Type{T}, bs::Vararg{Symbol}) where {S,N,T<:NamedTuple{S}} = namedtuple((Base.setdiff(S,bs)...,))

"""
   select(namedtuple, symbol(s)|Tuple)
   select(ntprototype, symbol(s)|Tuple)
   
Generate a namedtuple [ntprototype] from the first arg, including only fields present in the second arg.

see: [`merge`](@ref)
"""
select(nt::NamedTuple, k::Symbol) = nt[k]
select(nt::NamedTuple, k::NamedTuple) = select(nt, keys(k))
select(nt::NamedTuple, ks) = namedtuple(ks)(((nt[k] for k in ks)...,))


"""
    merge(namedtuple1, namedtuple2)
    merge(nt1, nt2, nt3, ..)

Generate a namedtuple with all fieldnames and values of namedtuple2
    and every fieldname of namedtuple1 that does not occur in namedtuple2
    along with their values.

see: [`delete!`](@ref)
"""
merge(::Type{T1}, ::Type{T2}) where {N1,N2,T1<:NamedTuple{N1},T2<:NamedTuple{N2}} =
    namedtuple((unique((N1..., N2...,))...,))
merge(::Type{T1}, ::Type{T2}, ::Type{T3}) where {N1,N2,N3,T1<:NamedTuple{N1},T2<:NamedTuple{N2},T3<:NamedTuple{N3}} =
    namedtuple((unique((N1..., N2..., N3...,))...,))
merge(::Type{T1}, ::Type{T2}, ::Type{T3}, ::Type{T4}) where {N1,N2,N3,N4,T1<:NamedTuple{N1},T2<:NamedTuple{N2},T3<:NamedTuple{N3},T4<:NamedTuple{N4}} =
    namedtuple((unique((N1..., N2..., N3..., N4...,))...,))
merge(::Type{T1}, ::Type{T2}, ::Type{T3}, ::Type{T4}, ::Type{T5}) where {N1,N2,N3,N4,N5,T1<:NamedTuple{N1},T2<:NamedTuple{N2},T3<:NamedTuple{N3},T4<:NamedTuple{N4},T5<:NamedTuple{N5}} =
    namedtuple((unique((N1..., N2..., N3..., N4..., N5...,))...,))
merge(::Type{T1}, ::Type{T2}, ::Type{T3}, ::Type{T4}, ::Type{T5}, ::Type{T6}) where {N1,N2,N3,N4,N5,N6,T1<:NamedTuple{N1},T2<:NamedTuple{N2},T3<:NamedTuple{N3},T4<:NamedTuple{N4},T5<:NamedTuple{N5},T6<:NamedTuple{N6}} =
    namedtuple((unique((N1..., N2..., N3..., N4..., N5..., N6...,))...,))
merge(::Type{T1}, ::Type{T2}, ::Type{T3}, ::Type{T4}, ::Type{T5}, ::Type{T6}, ::Type{T7}) where {N1,N2,N3,N4,N5,N6,N7,T1<:NamedTuple{N1},T2<:NamedTuple{N2},T3<:NamedTuple{N3},T4<:NamedTuple{N4},T5<:NamedTuple{N5},T6<:NamedTuple{N6},T7<:NamedTuple{N7}} =
    namedtuple((unique((N1..., N2..., N3..., N4..., N5..., N6...,N7...))...,))

# merge(nt1::T1, nt2::T2) where {T1<:NamedTuple, T2<:NamedTuple} is already defined

merge(a::NamedTuple{an}, b::NamedTuple{bn}, c::NamedTuple{cn}) where {an, bn, cn} =
    reduce(merge,(a, b, c))
merge(a::NamedTuple{an}, b::NamedTuple{bn}, c::NamedTuple{cn}, d::NamedTuple{dn}) where {an, bn, cn, dn} =
    reduce(merge,(a, b, c, d))
merge(a::NamedTuple{an}, b::NamedTuple{bn}, c::NamedTuple{cn}, d::NamedTuple{dn}, e::NamedTuple{en}) where {an, bn, cn, dn, en} =
    reduce(merge,(a, b, c, d, e))
merge(a::NamedTuple{an}, b::NamedTuple{bn}, c::NamedTuple{cn}, d::NamedTuple{dn}, e::NamedTuple{en}, f::NamedTuple{fn}) where {an, bn, cn, dn, en, fn} =
    reduce(merge,(a, b, c, d, e, f))
merge(a::NamedTuple{an}, b::NamedTuple{bn}, c::NamedTuple{cn}, d::NamedTuple{dn}, e::NamedTuple{en}, f::NamedTuple{fn}, g::NamedTuple{gn}) where {an, bn, cn, dn, en, fn, gn} =
    reduce(merge,(a, b, c, d, e, f, g))

"""
    split(namedtuple, symbol(s)|Tuple)

Generate two namedtuples, the first with only the fields in the second arg, the
second with all but the fields in the second arg, such that
`merge(split(nt, ks)...) == nt` when `ks` contains the first fields of `nt`.
"""
split(nt::NamedTuple, ks::Symbol) = split(nt, (ks,))
split(nt::NamedTuple, ks) = select(nt, ks), delete(nt, ks)


#=  interconvert: NamedTuple <--> Dict =#

uniontype(nt::NamedTuple) = Union{typeof.(values(nt))...,}	

"""
    gather_(x::Iterable)

Collect the elements of x into a Tuple, in their iterated order. 
"""
@inline gather_(x::T) where {T} = (collect(x)...,)

namedtuple(d::T) where {T<:AbstractDict{Symbol,V}} where {V} =
    NamedTuple{gather_(keys(d)), NTuple{length(d), V}}(gather_(values(d)))
namedtuple(d::T) where {T<:AbstractDict{S,V}} where {S<:AbstractString, V} =
    NamedTuple{Symbol.(gather_(keys(d))), NTuple{length(d), V}}(gather_(values(d)))
namedtuple(d::T) where {T<:AbstractDict{Symbol,Any}} =
    NamedTuple{gather_(keys(d)), Tuple{typeof.(values(d))...}}(gather_(values(d)))
namedtuple(d::T) where {T<:AbstractDict{S,Any}} where {S<:AbstractString} =
    NamedTuple{Symbol.(gather_(keys(d))), Tuple{typeof.(values(d))...}}(gather_(values(d)))

# use: dict = convert(Dict, nt)
#=
   for Dict{Symbol,Any}: 
   Base.convert(::Type{Dict}, x::NT) where {N, NT<:NamedTuple{N}} = 
       Dict([sym=>val for (sym,val) in zip(fieldnames(x), fieldvalues(x))])
=#
Base.convert(::Type{D}, x::NT) where {D<:AbstractDict, N, NT<:NamedTuple{N}} = 
    D{Symbol, uniontype(x)}([sym=>val for (sym,val) in zip(fieldnames(x), fieldvalues(x))])

dictionary(nt::NamedTuple) = convert(Dict, nt) # deprecated

# from PR by pdeffebach (Vector of Pairs becomes NamedTuple)
namedtuple(v::Vector{<:Pair{<:Symbol}}) = namedtuple([p[1] for p in v]...)([p[2] for p in v]...)
# with names as strings
namedtuple(v::Vector{<:Pair{<:String}}) = namedtuple([p[1] for p in v]...)([p[2] for p in v]...)

# NamedTuple becomes a Vector of Pairs 
Base.convert(::Type{Vector{Pair}}, nt::NamedTuple) =  map(kv->Pair(first(kv), last(kv)), zip(keys(nt), values(nt)))

# from Sebastian Pfitzner (on Slack)
macro namedtuple(vars...)
   args = Any[]
   for v in vars
       if Meta.isexpr(v, :(=)) || Meta.isexpr(v, :...)
           push!(args, esc(v))
       else
           push!(args, Expr(:(=), esc(v), esc(v)))
       end
   end
   expr = Expr(:tuple, Expr(:parameters, args...))
   return expr
end



end # module NamedTupleTools
