
#TODO: Update citation.

# The root finding algorithm in this file is based off of Panayi's algorithm,
# a description of which can be found here:  "krasner.pdf".

@doc Markdown.doc"""
    number_of_roots(K, f)
Given an eisenstein extension `K` and a polynomial $f \in K[x]$, return the number of roots of `f` defined over `K`.
"""
function number_of_roots(f::Hecke.Generic.Poly{<:NALocalFieldElem})

    K = base_ring(f)
    k, mp_struct = ResidueField(K)

    # Unpack the map structure to get the maps to/from the residue field.
    res  = mp_struct.f
    lift = mp_struct.g
    
    x = gen(parent(f))
    pi = uniformizer(K)
    C = [fprimitive_part(f)]
    m = 0

    while !isempty(C)
        c = pop!(C)        
        cp = map_coeffs(res, c)
        Rfp = parent(cp)
        rts = roots(cp)
        
        for rt in rts
            
            h = fprimitive_part( c(pi*x + lift(rt)) )
            hp = map_coeffs(res, h)
            
            if degree(hp) == 1
                m += 1
            elseif degree(hp) > 1
                push!(C, h)        
            end
        end

        if length(C) >= degree(f)
            error("Number of computed factors has exceeded the degree.")
        end
    end
    return m
end

function number_of_roots(f::Hecke.Generic.Poly{<:NALocalFieldElem}, K::NALocalField)
    return number_of_roots(change_base_ring(K,f))
end

############################################################

my_setprecision!(f,N) = f

# Should use a precision access function rather than a "__.N".

#XXX: valuation(Q(0)) == 0 !!!!!
function newton_lift(f::Hecke.Generic.Poly{T}, r::T) where T<:NALocalFieldElem

    # The many setprecision! calls are likely not valid for an approximately defined
    # polynomial.

    r.N = 1 # TODO: should be removed.
    
    K = parent(r)
    #n = K.prec_max
    n = 100
    
    i = n
    chain = [n]
    while i>2
        i = div(i+1, 2)
        push!(chain, i)
    end
    df  = derivative(f)
    fK  = change_base_ring(K,f)
    dfK = change_base_ring(K,df)

    @assert r.N == 1          # Ensure the residue is well-defined.
    df_at_r_inverse = K(r)    # Cache and update the values of 1/dfK(r)
    df_at_r_inverse.N = 1
    df_at_r_inverse = inv(my_setprecision!(dfK, 1)(df_at_r_inverse))
    
    #s = fK(r)

    for current_precision in reverse(chain)
        
        r.N               = current_precision
        df_at_r_inverse.N = current_precision
        #K.prec_max = r.N
        my_setprecision!(fK, r.N)
        my_setprecision!(dfK, r.N)        
        r = r - fK(r) * df_at_r_inverse
        #if r.N >= n
        #    K.prec_max = n
        #    return r
        #end

        # Update the value of the derivative.
        df_at_r_inverse = df_at_r_inverse*(2-dfK(r)*df_at_r_inverse)
    end

    return r
end

#XXX: valuation(Q(0)) == 0 !!!!!

# TODO: This function has some mutation issues...
function newton_lift(f::fmpz_poly, r::NALocalFieldElem)
  Q = parent(r)
  n = Q.prec_max
  i = n
  chain = [n]
  while i>2
    i = div(i+1, 2)
    push!(chain, i)
  end
  fs = derivative(f)
  qf = change_base_ring(Q, f, cached = false)
  qfs = change_base_ring(Q, fs, cached = false)
  o = Q(r)
  o.N = 1
  s = qf(r)
    
  setprecision!(qfs, 1)
  o = inv(qfs(o))
  @assert r.N == 1
  for p = reverse(chain)
    r.N = p
    o.N = p
    Q.prec_max = r.N
    setprecision!(qf, r.N)
    setprecision!(qfs, r.N)
    r = r - qf(r)*o
    if precision(r) >= n
      Q.prec_max = n
      return r
    end
    o = o*(2-qfs(r)*o)
  end
end


# TODO: XXX: f is assumed to be "square-free".
function integral_roots(f::Hecke.Generic.Poly{<:Hecke.NALocalFieldElem})

    K = base_ring(parent(f))
    k, mp_struct = ResidueField(K)

    # Unpack the map structure to get the maps to/from the residue field.
    res  = mp_struct.f
    lift = mp_struct.g

    x = gen(parent(f))
    pi = uniformizer(K)
    roots_type = elem_type(K)
    
    fprim = fprimitive_part(f)
    fp = map_coeffs(res, fprim)

    rts = roots(fp)
    
    if length(rts)==0
        # There are no roots in the padic unit disk        
        return roots_type[]
        
    elseif degree(fp) == 1
        # There is exactly one root, which can be Hensel lifted
        rr = lift(rts[1])
        return [newton_lift(fprim,rr)]

    else
        # There are multiple roots in the unit disk. Zoom in on each.
        roots_out = roots_type[]
        for beta in rts
            beta_lift = lift(beta)
            roots_near_beta = integral_roots( fprim(pi*x + beta_lift) )
            roots_out = vcat(roots_out, [pi*r + beta_lift for r in roots_near_beta] )
        end
        
        return roots_out
    end
    error("Etwas hat scheif gelaufen.")
end

import Hecke.roots
function roots(f::Hecke.Generic.Poly{<:Hecke.NALocalFieldElem})
    K = base_ring(parent(f))
    pi = uniformizer(K)
    x = gen(parent(f))
    
    Ov_roots   = integral_roots(f,K)
    outside_Ov_roots = integral_roots(reverse(f)(pi*x), K)
    filter!(r->r!=K(0), outside_Ov_roots)
    return vcat(Ov_roots, [inv(rt) for rt in outside_Ov_roots])
end

function roots(f, K::Hecke.Field)
    return roots(change_base_ring(K,f))
end

function integral_roots(f, K::Hecke.Field)
    return integral_roots(change_base_ring(K,f))
end