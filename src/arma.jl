#=

@authors: John Stachurski
Date: Thu Aug 21 11:09:30 EST 2014

Provides functions for working with and visualizing scalar ARMA processes.
Ported from Python module quantecon.arma, which was written by Doc-Jin Jang,
Jerry Choi, Thomas Sargent and John Stachurski


References
----------

http://quant-econ.net/arma.html

An example of usage is

using QuantEcon
phi = 0.5
theta = [0.0, -0.8]
sigma = 1.0
lp = ARMA(phi, theta, sigma)
require(joinpath(Pkg.dir("QuantEcon"), "examples", "arma_plots.jl"))
quad_plot(lp)

=#

type ARMA
    phi::Vector      # AR parameters phi_1, ..., phi_p
    theta::Vector    # MA parameters theta_1, ..., theta_q
    p::Integer       # Number of AR coefficients
    q::Integer       # Number of MA coefficients
    sigma::Real      # Variance of white noise
    ma_poly::Vector  # MA polynomial --- filtering representatoin
    ar_poly::Vector  # AR polynomial --- filtering representation
end

# constructors to coerce phi/theta to vectors
ARMA(phi::Real, theta::Real=0.0, sigma::Real=1.0) = ARMA([phi], [theta], sigma)
ARMA(phi::Real, theta::Vector=[0.0], sigma::Real=1.0) = ARMA([phi], theta, sigma)
ARMA(phi::Vector, theta::Real=0.0, sigma::Real=1.0) = ARMA(phi, theta, sigma)

function ARMA(phi::Vector, theta::Vector=[0.0], sigma::Real=1.0)
    # == Record dimensions == #
    p = length(phi)
    q = length(theta)

    # == Build filtering representation of polynomials == #
    ma_poly = [1.0, theta]
    ar_poly = [1.0, -phi]
    return ARMA(phi, theta, p, q, sigma, ma_poly, ar_poly)
end

function spectral_density(arma::ARMA; res=1200, two_pi=true)
    # Compute the spectral density associated with ARMA process arma
    wmax = two_pi ? 2pi : pi
    w = linspace(0, wmax, res)
    tf = TFFilter(reverse(arma.ma_poly), reverse(arma.ar_poly))
    h = freqz(tf, w)
    spect = arma.sigma^2 * abs(h).^2
    return w, spect
end

function autocovariance(arma::ARMA; num_autocov=16)
    # Compute the autocovariance function associated with ARMA process arma
    # Computation is via the spectral density and inverse FFT
    (w, spect) = spectral_density(arma)
    acov = real(Base.ifft(spect))
    # num_autocov should be <= len(acov) / 2
    return acov[1:num_autocov]
end

function impulse_response(arma::ARMA; impulse_length=30)
    # Compute the impulse response function associated with ARMA process arma
    err_msg = "Impulse length must be greater than number of AR coefficients"
    @assert impulse_length >= arma.p err_msg
    # == Pad theta with zeros at the end == #
    theta = [arma.theta, zeros(impulse_length - arma.q)]
    psi_zero = 1.0
    psi = Array(Float64, impulse_length)
    for j = 1:impulse_length
        psi[j] = theta[j]
        for i = 1:min(j, arma.p)
            psi[j] += arma.phi[i] * (j-i > 0 ? psi[j-i] : psi_zero)
        end
    end
    return [psi_zero, psi[1:end-1]]
end

function simulation(arma::ARMA; ts_length=90, impulse_length=30)
    # Simulate the ARMA process arma assuing Gaussian shocks
    J = impulse_length
    T = ts_length
    psi = impulse_response(arma, impulse_length=impulse_length)
    epsilon = arma.sigma * randn(T + J)
    X = Array(Float64, T)
    for t=1:T
        X[t] = dot(epsilon[t:J+t-1], psi)
    end
    return X
end
