import Nemo.isone, Nemo.divexact, Base.copy
export divexact!, gcd_into!, coprime_base, coprime_base_insert

function isone(a::Integer)
  return a==1
end

function divexact{T <: Integer}(a::T, b::T)
  return div(a, b)::T
end

function divexact!(a::fmpz, b::fmpz)
  ccall((:fmpz_divexact, :libflint), Void, 
          (Ptr{fmpz}, Ptr{fmpz}, Ptr{fmpz}), &a, &a, &b)
  return a
end

function gcd_into!(a::fmpz, b::fmpz, c::fmpz)
  ccall((:fmpz_gcd, :libflint), Void, 
          (Ptr{fmpz}, Ptr{fmpz}, Ptr{fmpz}), &a, &b, &c)
  return a
end

function gcd_into!{T <: Integer}(a::T, b::T, c::T)
  return gcd(b, c)::T
end

function copy(a::fmpz) 
  return deepcopy(a)
end

#for larger lists much better than Bill's (Nemo's) prod function

function my_prod!(a::AbstractArray{fmpz, 1})
  n = length(a)
  while n>1
    for i = 1:div(n,2)
      mul!(a[i], a[2*i-1], a[2*i])
    end
    if isodd(n)
      m = div(n,2)+1
      a[m] = a[n]
      n = m
    else
      n = div(n,2)
    end
  end
  return a[1]
end

function my_prod(a::AbstractArray{fmpz, 1})
  b = Array(fmpz, 0)
  for i=1:div(length(a), 2)
    push!(b, a[2*i-1]* a[2*i])
  end
  if isodd(length(a))
    push!(b, a[end])
  end
  return my_prod!(b)
end



#coprime base Bach/ Schallit/ ???

function pair_bach{E}(a::E, b::E)
  if isone(a)
    if isone(b)
      return Array(E, 0)
    else
      return [b]
    end
  end
  if isone(b)
    return [a]
  end

  n = [a, b]
  i = 1
  while i < length(n)
    g = gcd(n[i], n[i+1])
    if isone(g)
      i += 1
    else
      n[i] = divexact!(n[i], g)
      n[i+1] = divexact!(n[i+1], g)
      insert!(n, i+1, g)
      if isone(n[i+2])
        deleteat!(n, i+2)
      end
      if isone(n[i])
        deleteat!(n, i)
      end
    end
  end

  return n
end

function augment_bach{E}(S::Array{E, 1}, m::E)
  T = Array(E, 0)
  i = 1
  while i <= length(S) && !isone(m)
    if !isone(S[i])
      Ts = pair_bach(m, S[i])
      T = vcat(T, sub(Ts, 2:length(Ts)))
      m = Ts[1]
    end
    i += 1
  end
  if i <= length(S)
    T = vcat(T, sub(S, i:length(S)))
  end
  if !isone(m) 
    push!(T, m)
  end
  return T
end


function coprime_base_bach{E}(a::Array{E, 1}) #T need to support GCDs
  if length(a) < 2
    return a
  end

  T = pair_bach(abs(a[1]), abs(a[2]))
  j = 3
  while j <= length(a)
    T = augment_bach(T, abs(a[j]))
    j += 1
  end
  return T
end
   
# Bernstein: coprime bases
# ppio(a,b) = (c,n) where v_p(c) = v_p(a) if v_p(b) !=0, 0 otherwise
#                         c*n = a
# or c = gcd(a, b^infty)

function ppio{E}(a::E, b::E) 
  c = gcd(a, b)
  n = div(a, c)
  m = c
  g = gcd(c, n)
  while g != 1
    c = c*g
    n = div(n, g)
    g = gcd(c, n)
  end
  return (c, n)
end

#Note: Bernstein needs bigints, either Integer or fmpz 
#      well, polys are also OK, small integers are not.

# could/ should be optimsed using divexact! and gcd_into!
# probably should also be combined with ppio somewhere

function ppgle{E}(a::E, b::E)
  n = gcd(a,b)
  r = divexact(a, n)
  m = n
  g = gcd(r, n)
  while !isone(g)
    r *= g
    n = divexact(n, g)
    g = gcd(r, n)
  end
  return m, r, n
end

function pair_bernstein{E}(a::E, b::E)
  T = Array(E, 0)
  if isone(b)
    if isone(a)
      return T
    else
      return push!(T, a)
    end
  end
  if isone(a)
    return push!(T, b)
  end

  a,r = Hecke.ppio(a,b)
  if !isone(r)
    push!(T, r)
  end
  g,h,c = ppgle(a, b)
  c0 = c
  r = c0
  k = 1
  while !isone(h)
    g,h,c = ppgle(h, g^2)
    d = gcd(c, b)
    if isone(d)
      push!(T, c)
      continue
    end
    r *= d
    n = d^(2^(k-1))
    T = vcat(T, pair_bernstein(divexact(c, n), d))
    k += 1
  end
  T = vcat(T, pair_bernstein(divexact(b, r), c0))
  return T
end

function split_bernstein{T}(a::T, P::Hecke.node{T})
  b = Hecke.ppio(a, P.content)[1]
  if !isdefined(P, :left)
    if !isdefined(P, :right)
      return [(P.content, b)]
    else
      return split_bernstein(b, P.right)
    end
  else
    if !isdefined(P, :right)
      return split_bernstein(b, P.left)
    else
      return vcat(split_bernstein(b, P.left), split_bernstein(b, P.right))
    end
  end
end

function split_bernstein{T}(a::T, P::Array{T, 1})
  if length(P) == 0
    return P
  end
  F = FactorBase(P, check = false)
  b = Hecke.ppio(a, F.prod)[1]
  if length(P)==1
    return [(P[1], b)]
  end
  return vcat(split_bernstein(b, F.ptree.left), split_bernstein(b, F.ptree.right))
end

function augment_bernstein{E}(P::Array{E, 1}, b::E)
  T = Array(E, 0)
  if length(P) == 0
    if isone(b)
      return T
    else
      return push!(T, b)
    end
  end
  F = FactorBase(P, check = false)
  a,r = Hecke.ppio(b, F.prod)
  if ! isone(r)
    push!(T, r)
  end
  S = split_bernstein(a, F.ptree)
  for X in S 
    T = vcat(T, pair_bach(X[1], X[2]))
  end
  return T
end

function merge_bernstein{E}(P::Array{E, 1}, Q::Array{E, 1})
  m = length(Q)
  b = nbits(m)
  S = P
  i = 0
  while i<=b
    R = prod(sub(Q, find(x -> x & (2^i) ==0, 1:length(Q))))
    T = augment_bernstein(S, R)
    R = prod(sub(Q, find(x -> x & (2^i) !=0, 1:length(Q))))
    S = augment_bernstein(T, R)
    i += 1
  end
  return S
end


function coprime_base_bernstein{E}(S::Array{E, 1})
  if length(S)<2
    return S
  end
  P1 = coprime_base_bernstein([S[i] for i=1:div(length(S), 2)])
  P2 = coprime_base_bernstein([S[i] for i=(div(length(S), 2)+1):length(S)])
  return merge_bernstein(P1, P2)
end

function augment_steel{E}(S::Array{E, 1}, a::E, start::Int = 1)
  i = start
  if isone(a)
    return S
  end
  
  g = E(0)

  while i<=length(S) && !isone(a) 
    g = gcd_into!(g, S[i], a)
    if isone(g)
      i += 1
      continue
    end
    si = divexact(S[i], g)
    a = divexact(a, g)
    if isone(si) # g = S[i] and S[i] | a
      continue
    end
    S[i] = si
    if isone(a) # g = a and a | S[i]
      a = copy(g)
      continue
    end
    augment_steel(S, copy(g), i)
    continue
  end
  if !isone(a)
    push!(S, a)
  end

  return S;
end

function coprime_base_steel{E}(S::Array{E, 1})
  T = Array(E, 1)
  T[1] = S[1]
  for i=2:length(S)
    augment_steel(T, S[i])
  end
  return T
end

##implemented 
# Bernstein: asymptotically fastest, linear in the total input size
#   pointless for small ints as it requires intermediate numbers to be
#   huge
# Bach/Shallit/???: not too bad, source Epure's Masters thesis
#   can operate on Int types as no intermediate is larger than the input
# Steel: a misnomer: similar to Magma, basically implements a memory
#   optimised version of Bach
#   faster than Magma on 
# > I := [Random(1, 10000) * Random(1, 10000) : x in [1..10000]];
# > time c := CoprimeBasis(I);
# julia> I = [fmpz(rand(1:10000))*rand(1:10000) for i in 1:10000];
# 
# experimentally, unless the input is enormous, Steel wins
# on smallish input Bach is better than Bernstein, on larger this
# changes
# 
# needs
# isone, gcd_into!, divexact!, copy
# (some more for Bernstein: FactorBase, gcd, divexact)

doc"""
***
    coprime_base{E}(S::Array{E, 1}) -> Array{E, 1}

> Returns a coprime base for S, ie. the resulting array contains pairwise coprime objects that multiplicatively generate the same set as the input array.
"""
coprime_base = coprime_base_steel

doc"""
***
    coprime_base_insert{E}(S::Array{E, 1}, a::E) -> Array{E, 1}

> Given a coprime array S, insert a new element, ie. find a coprime base for push(S, a)
"""
coprime_base_insert = augment_steel


