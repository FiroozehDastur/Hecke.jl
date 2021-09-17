@testset "NumField/NfAbs/NfAbs" begin
  cyclo_expl = function(n, m)
    Fn, zn = CyclotomicField(n)
    Fnm, znm = CyclotomicField(n*m)
    x = zn
    x_up = Hecke.force_coerce_cyclo(Fnm, x)
    x_down = Hecke.force_coerce_cyclo(Fn, x_up)
    return (x, x_up, x_down)
  end

  res = cyclo_expl(3, 4)
  @test (res[1]^3, res[2]^3) == (1, 1)

  res = cyclo_expl(3, 2)
  z6 = gen(parent(res[2]))
  # Test that z3 is mapped to z6^2
  @test z6^2 == res[2]
end

@testset "Splitting Field" begin

  Qx, x = PolynomialRing(FlintQQ, "x")
  f = x^3-2
  K = splitting_field(f)
  @test typeof(K) == AnticNumberField
  K1 = number_field([x^3-2, x^2+x+1])[1]
  K1abs = simple_extension(K1)[1]
  @test isisomorphic(K, K1abs)[1]
  K, R = splitting_field(f, do_roots = true)
  for r in R
    @test iszero(f(r))
  end

  K, a = number_field(x^2+1)
  Kt, t = PolynomialRing(K, "t")
  g = t^4-2
  L = splitting_field(g)
  @test typeof(L) == Hecke.NfRel{nf_elem}
  @test absolute_degree(L) == 8
end