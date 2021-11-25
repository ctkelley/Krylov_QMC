"""
gmres_test.jl

Tests the linear GMRES code, X_gmres. 

This is for CI only. Nothing to see here. Move along.
"""

function gmres_test()
    pass3 = test3x3()
    passint = test_integop(40)
    passint_rs = test_integop_restart(40)
    passr1 = testR1()
    passorth = orth_test()
    passqr = qr_test()
    passgm = pass3 && passint && passr1 && passint_rs
    return passgm
end

"""
test3x3()

Do the nasty problem in Float64 or Float32. When you orthogonalize in Float32,
the iteration thinks it's ok and is wrong. 
"""
function test3x3()
    A = [0.001 0 0; 0 0.0011 0; 0 0 1.e4];
    V = zeros(3, 10);
    V32= zeros(Float32,3, 10);
    b = [1.0; 1.0; 1.0];
    x0 = zeros(3);
#    x0 = ones(3);
    eta = 1.e-10
    passgm = true
    rightsize = [10, 6, 5, 4]
    rightsize32 = [10, 7, 7, 3]
    Methods = ("cgs1", "mgs1", "mgs2", "cgs2")
    TestC = (false, true, true, true)
    i = 1
    tol=1.e-10
    tol32=1.e-7
    lhistpass=true
    ididpass=true
    locpass=true
    for orth in Methods
        gout = X_gmres(x0, b, atv, V, tol; pdata = A, orth = orth)
        resnorm = norm(A * gout.sol - b)
# If I don't have separate kl_stores then the gout.sol is overwritten.
# I will fix this at some point. For now, only the nonlinear solvers really
# use kl_store.
        gout32 = X_gmres(x0, b, atv, V32, tol32; pdata = A, orth = orth)
        ithist = gout.reshist
        ithist32 = gout32.reshist
        lhist = length(ithist)
        lhist32 = length(ithist32)
        lhistpass = lhistpass && (lhist == rightsize[i])
        lhistpass = lhistpass && (lhist32 == rightsize32[i])
        ididpass = ididpass && (gout.idid == TestC[i])
        ididpass = ididpass && (gout32.idid == TestC[i])
        resnormx = norm(A * gout.sol - b)
        resnorm32 = norm(A * gout32.sol - b)
        locpass = (resnorm < 1.e-8) && (resnorm32 > .1)
c=A\b
println(lhistpass,"  ",ididpass,"  ",locpass)
println(resnorm,"  ",resnorm32,"  ",resnormx,"  ",norm(c-gout.sol))
# For the Float32 computation, the iteration terminates with success, but
# the real residual is bad. 
println(lhistpass,"  ",ididpass,"  ",locpass)
        locpass || println(
            "failure at orth = ",
            orth,
            ", lhist = ",
            lhist,
            ", Res norm = ",
            resnorm,
        )
        passgm = passgm && locpass && lhistpass && ididpass
        i += 1
    end
    #    return (pass = passgm, RH = R)
    return passgm
end

function testR1()
    A = Float64.([1 2 3 4 5])
    E = A' * A
    A = I + E
    b = ones(5)
    x0 = zeros(5)
    V = zeros(5, 4)
    gout = X_gmres(x0, b, atv, V, 1.e-7; pdata = A)
    lhist = length(gout.reshist)
    nerr = norm(A * gout.sol - b, Inf)
    pass = (lhist == 3) && (nerr < 1.e-14)
    pass || println("Rank one test fails")
    return pass
end

function test_integop(n)
    pdata = integopinit(n)
    f = pdata.f
    ue = pdata.xe
    u0 = zeros(size(f))
    V = zeros(n, 20)
    Methods = ("cgs1", "mgs1", "mgs2", "cgs2")
    pass = true
#
# run through the orthogonalizers
#
    for orth in Methods
        goutinteg = X_gmres(u0, f, integop, V, 1.e-10; pdata = pdata, orth = orth)
        errn = norm(goutinteg.sol - ue, Inf)
        rhist = goutinteg.reshist
        lhist = length(rhist)
        rred = rhist[4] ./ rhist[1]
        lpass = (errn < 1.e-14) && (rred < 1.e-14) && (lhist == 4)
        lpass || println("Failure with orth = ", orth)
        pass = pass && lpass
    end
#
#  force a failure
#
    failout=X_gmres(u0, f, integop, V, 1.e-10; pdata = pdata, lmaxit=2);
    pass = pass && ~failout.idid
    pass || println("Integral operator test fails.")
    return pass
end


#
# Test integral equation with restarted GMRES
#
function test_integop_restart(n)
    pdata = integopinit(n)
    f = pdata.f
    ue = pdata.xe
    u0 = zeros(size(f))
    V = zeros(n, 3); V32 = zeros(Float32, n, 3)
    gout = X_gmres(u0, f, integop, V, 1.e-10; pdata = pdata, lmaxit=20);
    gout32 = X_gmres(u0, f, integop, V32, 1.e-10; pdata = pdata, lmaxit=20);
    dhist=norm(gout.reshist-gout32.reshist,Inf);
    lhist=length(gout.reshist)
    gerr=norm(gout.sol-pdata.xe,Inf)
    g32err=norm(gout32.sol-pdata.xe,Inf)
    histpass = dhist < 2.e-7
    histpass || println("restart history wrong size = ",dhist)
    errpass = (gerr < 1.e-10) && (g32err < 1.e-10)
    errpass || println("restart error too large")
    lenpass = (lhist == 6)
    lenpass || println("restart history wrong length")
    return histpass && errpass && lenpass
end

    


function atv(x, A)
    return A * x
end


function integop(u, pdata)
    K = pdata.K
#    f = pdata.f
    return u - K * u
end

function integopinit(n)
    h = 1 / n
    X = collect(0.5*h:h:1.0-0.5*h)
    K = [ker(x, y) for x in X, y in X]
    #    K = zeros(n, n)
    #    for j = 1:n
    #        for i = 1:n
    #            K[i, j] = ker(x[i], x[j])
    #        end
    #    end
    K .*= h
    #    sol = exp.(x) .* log.(2.0 * x .+ 1.0)
    #    sol = usol.(X)
    sol = [usol(x) for x in X]
    f = sol - K * sol
    pdata = (K = K, xe = sol, f = f)
    return pdata
end

function usol(x)
    return exp.(x) .* log.(2.0 * x .+ 1.0)
end

function ker(x, y)
    ker = 0.1 * sin(x + exp(y))
end


"""
orth_test()

Used for CI to make sure the orthogonalizers do what I expect.
"""
function orth_test()
    A = collect(0.01:0.01:0.25)
    A = reshape(A, 5, 5)
    A = I - A
    B = Float32.(A)
    C = Float16.(A)
    pass64 = qr_test(A, 4.e-16)
    pass32 = qr_test(B, 2.e-7)
    pass16 = qr_test(C, 2.e-3)
    return pass64 && pass32 && pass16
end


function qr_test(A = rand(3, 3), tol = 1.e-13)
    OM = ("mgs1", "mgs2", "cgs1", "cgs2")
    T = eltype(A)
    passqr = true
    for orth in OM
        C = copy(A)
        (Q, R) = qrctk!(C, orth)
        fres = norm(Q * R - A, Inf) / norm(A, Inf)
        ores = norm(Q' * Q - I, Inf)
        npass = fres + ores
        #println(eltype(Q)," ",eltype(R),"  ",typeof(npass)," ",
        #        orth, "   ", npass)
        pass = (npass < tol)
        pass || println(
            "qr_test fails with precision = ",
            T,
            ", method = ",
            orth,
            "error = ",
            npass,
        )
        passqr = passqr && pass
    end
    passqr
end


function qrctk!(A, orth = "cgs2")
    T = typeof(A[1, 1])
    (m, n) = size(A)
    R = zeros(T, n, n)
    @views R[1, 1] = norm(A[:, 1])
    @views A[:, 1] /= R[1, 1]
    @views for k = 2:n
        hv = vec(R[1:k, k])
        Qkm = view(A, :, 1:k-1)
        vv = vec(A[:, k])
        Orthogonalize!(Qkm, hv, vv, orth)
    end
    return (Q = A, R = R)
end
