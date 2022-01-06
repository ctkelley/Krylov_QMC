"""
mg_example()

Am I getting this right?
"""
function mg_example()
Nx=40; LB=0.0; RB=5.0;
geometry = "Slab"
generator = "Sobol"
G=12
N=2^8
qmc_data = multiGroup_init(geometry, generator, N, LB, RB, Nx, G)
exact=qmc_data.true_flux
mxv_data = SamInitMV(qmc_data)
gmsol=Solver_Compare(mxv_data; plabel="$G group problem")
println(size(exact))
println(size(gmsol))
println(norm(exact-gmsol,Inf))
end

