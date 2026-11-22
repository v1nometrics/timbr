// SPDX-License-Identifier: MPL-2.0
#include "timbre_dsp.h"

#include <Accelerate/Accelerate.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <complex>
#include <cstring>
#include <mutex>
#include <vector>

namespace {

constexpr double kPi = 3.1415926535897932384626433832795;
constexpr double kTwoPi = 2.0 * kPi;
constexpr size_t kFftSize = 1024;
constexpr size_t kHalfFft = kFftSize / 2;

inline double db_to_lin(double db) noexcept {
    return std::pow(10.0, db * 0.05);
}

inline double lin_to_db(double lin) noexcept {
    return 20.0 * std::log10(std::max(lin, 1e-12));
}

struct BiquadCoeffs {
    double b0{1.0}, b1{0.0}, b2{0.0};
    double a1{0.0}, a2{0.0};
};

struct BiquadState {
    double z1{0.0}, z2{0.0};
    void reset() noexcept { z1 = 0.0; z2 = 0.0; }
    inline double tick(double x, const BiquadCoeffs& c) noexcept {
        // Direct Form II Transposed in Float64 (lowest numerical noise for IIR)
        const double y = c.b0 * x + z1;
        z1 = c.b1 * x - c.a1 * y + z2;
        z2 = c.b2 * x - c.a2 * y;
        return y;
    }
};

void compute_pole_pair(double w, double qv, double& a1, double& a2) noexcept {
    const double u = 1.0 / (2.0 * std::max(qv, 1e-4));
    const double env = std::exp(-u * w);
    if (u <= 1.0) {
        a1 = -2.0 * env * std::cos(w * std::sqrt(1.0 - u * u));
    } else {
        a1 = -2.0 * env * std::cosh(w * std::sqrt(u * u - 1.0));
    }
    a2 = std::exp(-2.0 * u * w);
}

BiquadCoeffs make_rbj(const timbre_band_t& band, double fs) noexcept {
    const double f0 = std::clamp(band.freq_hz, 5.0, fs * 0.495);
    const double q = std::clamp(band.q, 0.05, 32.0);
    const double w0 = kTwoPi * f0 / fs;
    const double cosw = std::cos(w0);
    const double sinw = std::sin(w0);
    const double A = std::pow(10.0, band.gain_db / 40.0);
    const double alpha = sinw / (2.0 * q);

    double b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0;
    switch (band.type) {
    case TIMBRE_FILTER_PEAK:
        b0 = 1.0 + alpha * A;
        b1 = -2.0 * cosw;
        b2 = 1.0 - alpha * A;
        a0 = 1.0 + alpha / A;
        a1 = -2.0 * cosw;
        a2 = 1.0 - alpha / A;
        break;
    case TIMBRE_FILTER_LOW_SHELF: {
        const double sq = 2.0 * std::sqrt(A) * alpha;
        b0 = A * ((A + 1.0) - (A - 1.0) * cosw + sq);
        b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosw);
        b2 = A * ((A + 1.0) - (A - 1.0) * cosw - sq);
        a0 = (A + 1.0) + (A - 1.0) * cosw + sq;
        a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosw);
        a2 = (A + 1.0) + (A - 1.0) * cosw - sq;
        break;
    }
    case TIMBRE_FILTER_HIGH_SHELF: {
        const double sq = 2.0 * std::sqrt(A) * alpha;
        b0 = A * ((A + 1.0) + (A - 1.0) * cosw + sq);
        b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosw);
        b2 = A * ((A + 1.0) + (A - 1.0) * cosw - sq);
        a0 = (A + 1.0) - (A - 1.0) * cosw + sq;
        a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosw);
        a2 = (A + 1.0) - (A - 1.0) * cosw - sq;
        break;
    }
    case TIMBRE_FILTER_LOW_PASS:
        b0 = (1.0 - cosw) * 0.5;
        b1 = 1.0 - cosw;
        b2 = b0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosw;
        a2 = 1.0 - alpha;
        break;
    case TIMBRE_FILTER_HIGH_PASS:
        b0 = (1.0 + cosw) * 0.5;
        b1 = -(1.0 + cosw);
        b2 = b0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosw;
        a2 = 1.0 - alpha;
        break;
    case TIMBRE_FILTER_BAND_PASS:
        b0 = alpha;
        b1 = 0.0;
        b2 = -alpha;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosw;
        a2 = 1.0 - alpha;
        break;
    case TIMBRE_FILTER_NOTCH:
        b0 = 1.0;
        b1 = -2.0 * cosw;
        b2 = 1.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosw;
        a2 = 1.0 - alpha;
        break;
    case TIMBRE_FILTER_ALL_PASS:
        b0 = 1.0 - alpha;
        b1 = -2.0 * cosw;
        b2 = 1.0 + alpha;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosw;
        a2 = 1.0 - alpha;
        break;
    case TIMBRE_FILTER_BYPASS:
    default:
        return {};
    }
    const double inv_a0 = 1.0 / a0;
    return {b0 * inv_a0, b1 * inv_a0, b2 * inv_a0, a1 * inv_a0, a2 * inv_a0};
}

BiquadCoeffs make_vicanek(const timbre_band_t& band, double fs) noexcept {
    if (!band.enabled || band.type == TIMBRE_FILTER_BYPASS) return {};
    if (band.type != TIMBRE_FILTER_PEAK &&
        band.type != TIMBRE_FILTER_LOW_SHELF &&
        band.type != TIMBRE_FILTER_HIGH_SHELF) {
        return make_rbj(band, fs);
    }
    if (std::abs(band.gain_db) < 1e-6) return {};

    const double f0 = std::clamp(band.freq_hz, 5.0, fs * 0.485);
    const double q = std::clamp(band.q, 0.1, 24.0);
    const bool is_cut = (band.gain_db < 0.0);
    const double g_pos_db = std::abs(band.gain_db);
    const double G = std::pow(10.0, g_pos_db / 20.0);
    const double A = std::sqrt(G);
    const double w0 = kTwoPi * f0 / fs;

    double a1 = 0.0, a2 = 0.0;
    double g_dc = 1.0;
    double g_nyq = 1.0;
    double g_w0_sq = G * G;
    const double om_nyq = (0.5 * fs) / f0;

    if (band.type == TIMBRE_FILTER_PEAK) {
        compute_pole_pair(w0, q * A, a1, a2);
        g_dc = 1.0;
        const double num = (1.0 - om_nyq * om_nyq) * (1.0 - om_nyq * om_nyq) +
                           (A * om_nyq / q) * (A * om_nyq / q);
        const double den = (1.0 - om_nyq * om_nyq) * (1.0 - om_nyq * om_nyq) +
                           (om_nyq / (q * A)) * (om_nyq / (q * A));
        g_nyq = std::sqrt(num / std::max(den, 1e-18));
        g_w0_sq = G * G;
    } else if (band.type == TIMBRE_FILTER_LOW_SHELF) {
        const double wp = w0 / std::sqrt(A);
        compute_pole_pair(wp, q, a1, a2);
        g_dc = G;
        const std::complex<double> jom(0.0, om_nyq);
        const double s2 = -om_nyq * om_nyq;
        const double mid = std::sqrt(A) / q;
        const std::complex<double> H = A * (s2 + mid * jom + A) / (A * s2 + mid * jom + 1.0);
        g_nyq = std::abs(H);
        g_w0_sq = G; // sqrt(G)^2
    } else { // HIGH_SHELF
        const double wp = std::min(w0 * std::sqrt(A), kPi * 0.98);
        compute_pole_pair(wp, q, a1, a2);
        g_dc = 1.0;
        const std::complex<double> jom(0.0, om_nyq);
        const double s2 = -om_nyq * om_nyq;
        const double mid = std::sqrt(A) / q;
        const std::complex<double> H = A * (A * s2 + mid * jom + 1.0) / (s2 + mid * jom + A);
        g_nyq = std::abs(H);
        g_w0_sq = G;
    }

    const double sin_half = std::sin(0.5 * w0);
    const double phi0 = sin_half * sin_half;
    const double phi1 = 1.0 - phi0;
    const double phi2 = std::max(4.0 * phi0 * phi1, 1e-18);

    const double A0 = (1.0 + a1 + a2) * (1.0 + a1 + a2);
    const double A1 = (1.0 - a1 + a2) * (1.0 - a1 + a2);
    const double A2 = -4.0 * a2;

    const double B0 = A0 * g_dc * g_dc;
    const double B1 = A1 * g_nyq * g_nyq;
    const double R1 = (A0 * phi1 + A1 * phi0 + A2 * phi2) * g_w0_sq;
    const double B2 = (R1 - B0 * phi1 - B1 * phi0) / phi2;

    const double sB0 = std::sqrt(std::max(B0, 0.0));
    const double sB1 = std::sqrt(std::max(B1, 0.0));
    const double W = 0.5 * (sB0 + sB1);
    const double disc = std::max(0.0, W * W + B2);
    const double b0 = std::max(0.5 * (W + std::sqrt(disc)), 1e-12);
    const double b1 = 0.5 * (sB0 - sB1);
    const double b2 = -B2 / (4.0 * b0);

    if (!is_cut) {
        return {b0, b1, b2, a1, a2};
    } else {
        // Exact analytical inverse: swap numerator & denominator for cut stability/symmetry.
        const double inv = 1.0 / b0;
        return {1.0 * inv, a1 * inv, a2 * inv, b1 * inv, b2 * inv};
    }
}

BiquadCoeffs compute_coeffs(const timbre_band_t& band, double fs) noexcept {
    if (!band.enabled || band.type == TIMBRE_FILTER_BYPASS) return {};
    if (band.design == TIMBRE_DESIGN_RBJ) return make_rbj(band, fs);
    return make_vicanek(band, fs);
}

std::complex<double> eval_biquad_z(const BiquadCoeffs& c, double w) noexcept {
    const std::complex<double> z1 = std::polar(1.0, -w);
    const std::complex<double> z2 = z1 * z1;
    return (c.b0 + c.b1 * z1 + c.b2 * z2) / (1.0 + c.a1 * z1 + c.a2 * z2);
}

struct ParameterSlot {
    timbre_dsp_config_t config{};
    std::array<timbre_band_t, TIMBRE_MAX_BANDS> raw_bands{};
    std::array<BiquadCoeffs, TIMBRE_MAX_BANDS> coeffs{};
    uint32_t band_count{0};
    double preamp_db{0.0};
    double preamp_linear{1.0};
    double crossfeed_alpha{0.0};
    double crossfeed_low_b0{1.0}, crossfeed_low_b1{0.0}, crossfeed_low_a1{0.0};
    double crossfeed_feed_lin{0.0};
};

// ITU-R BS.1770 K-weighting biquad pair for 48 kHz + generalized bilinear for arbitrary fs.
struct KWeighting {
    BiquadCoeffs shelf{};
    BiquadCoeffs hp{};
    BiquadState s1l, s2l, s1r, s2r;

    void configure(double fs) noexcept {
        // Stage 1: +4 dB high-shelf at ~1681.97 Hz
        timbre_band_t b1{};
        b1.type = TIMBRE_FILTER_HIGH_SHELF;
        b1.design = TIMBRE_DESIGN_RBJ;
        b1.freq_hz = 1681.974450955533;
        b1.gain_db = 3.999843853973347;
        b1.q = 0.7071752369554196;
        b1.enabled = true;
        shelf = make_rbj(b1, fs);

        // Stage 2: 2nd-order Butterworth high-pass at 38.135 Hz
        timbre_band_t b2{};
        b2.type = TIMBRE_FILTER_HIGH_PASS;
        b2.design = TIMBRE_DESIGN_RBJ;
        b2.freq_hz = 38.13547087602444;
        b2.q = 0.5003270373238773;
        b2.enabled = true;
        hp = make_rbj(b2, fs);
    }

    inline void process(double& l, double& r) noexcept {
        l = s1l.tick(l, shelf);
        l = s2l.tick(l, hp);
        r = s1r.tick(r, shelf);
        r = s2r.tick(r, hp);
    }
};

// Fast 4x cubic Catmull-Rom inter-sample peak detector + lookahead smooth gain limiter.
class TruePeakLimiter {
public:
    void prepare(double fs) noexcept {
        fs_ = fs;
        lookahead_samples_ = std::max<size_t>(16, std::min<size_t>(kMaxLookahead, static_cast<size_t>(fs * 0.0015))); // 1.5 ms
        release_coeff_ = std::exp(-1.0 / (fs * 0.080)); // 80 ms smooth release
        attack_coeff_ = std::exp(-1.0 / (fs * 0.0005)); // 0.5 ms fast attack inside lookahead
        reset();
    }

    void reset() noexcept {
        buf_l_.fill(0.0);
        buf_r_.fill(0.0);
        peak_hist_.fill(0.0);
        write_idx_ = 0;
        env_gr_ = 1.0;
        prev_l_.fill(0.0);
        prev_r_.fill(0.0);
    }

    // Estimates 4x oversampled true peak over [x[-3], x[-2], x[-1], x[0]]
    static inline double catmull_peak4(const std::array<double, 4>& s) noexcept {
        const double y0 = s[0], y1 = s[1], y2 = s[2], y3 = s[3];
        double max_p = std::max(std::abs(y1), std::abs(y2));
        for (int k = 1; k <= 3; ++k) {
            const double t = 0.25 * k;
            const double t2 = t * t;
            const double t3 = t2 * t;
            const double v = 0.5 * (
                (2.0 * y1) +
                (-y0 + y2) * t +
                (2.0 * y0 - 5.0 * y1 + 4.0 * y2 - y3) * t2 +
                (-y0 + 3.0 * y1 - 3.0 * y2 + y3) * t3
            );
            max_p = std::max(max_p, std::abs(v));
        }
        return max_p;
    }

    inline void process_sample(double in_l, double in_r, double ceiling_lin, bool enabled,
                               double& out_l, double& out_r, double& out_tp_l, double& out_tp_r,
                               double& out_gr_lin, bool& clipped) noexcept {
        prev_l_[0] = prev_l_[1]; prev_l_[1] = prev_l_[2]; prev_l_[2] = prev_l_[3]; prev_l_[3] = in_l;
        prev_r_[0] = prev_r_[1]; prev_r_[1] = prev_r_[2]; prev_r_[2] = prev_r_[3]; prev_r_[3] = in_r;

        const double tp_l = catmull_peak4(prev_l_);
        const double tp_r = catmull_peak4(prev_r_);
        out_tp_l = tp_l;
        out_tp_r = tp_r;

        if (!enabled) {
            out_l = in_l;
            out_r = in_r;
            out_gr_lin = 1.0;
            clipped = false;
            return;
        }

        const size_t read_idx = (write_idx_ + kMaxLookahead - lookahead_samples_) % kMaxLookahead;
        const double delayed_l = buf_l_[read_idx];
        const double delayed_r = buf_r_[read_idx];
        buf_l_[write_idx_] = in_l;
        buf_r_[write_idx_] = in_r;

        const double tp_in = std::max(tp_l, tp_r);
        peak_hist_[write_idx_] = tp_in;
        write_idx_ = (write_idx_ + 1) % kMaxLookahead;

        // Lookahead max over window
        double win_max = tp_in;
        for (size_t i = 0; i < lookahead_samples_; ++i) {
            const size_t idx = (read_idx + i) % kMaxLookahead;
            win_max = std::max(win_max, peak_hist_[idx]);
        }

        const double target_gr = (win_max > ceiling_lin && win_max > 1e-12)
                                     ? (ceiling_lin / win_max)
                                     : 1.0;
        if (target_gr < env_gr_) {
            env_gr_ = attack_coeff_ * env_gr_ + (1.0 - attack_coeff_) * target_gr;
            if (env_gr_ * win_max > ceiling_lin) {
                env_gr_ = ceiling_lin / win_max; // Hard true-peak safety guarantee
            }
        } else {
            env_gr_ = release_coeff_ * env_gr_ + (1.0 - release_coeff_) * target_gr;
        }

        double y_l = delayed_l * env_gr_;
        double y_r = delayed_r * env_gr_;

        // Final brickwall clamp on delayed sample to mathematically forbid any > ceiling overshoot
        const double m = std::max(std::abs(y_l), std::abs(y_r));
        if (m > ceiling_lin) {
            const double scale = ceiling_lin / m;
            y_l *= scale;
            y_r *= scale;
            clipped = true;
        } else {
            clipped = (target_gr < 0.9999);
        }

        out_l = y_l;
        out_r = y_r;
        out_gr_lin = env_gr_;
    }

private:
    static constexpr size_t kMaxLookahead = 256;
    double fs_{48000.0};
    size_t lookahead_samples_{72};
    double attack_coeff_{0.9};
    double release_coeff_{0.999};
    double env_gr_{1.0};
    std::array<double, kMaxLookahead> buf_l_{};
    std::array<double, kMaxLookahead> buf_r_{};
    std::array<double, kMaxLookahead> peak_hist_{};
    std::array<double, 4> prev_l_{};
    std::array<double, 4> prev_r_{};
    size_t write_idx_{0};
};

inline uint32_t xorshift32(uint32_t& state) noexcept {
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

inline double tpdf_noise(uint32_t& rng) noexcept {
    const double u1 = static_cast<double>(xorshift32(rng)) / 4294967296.0;
    const double u2 = static_cast<double>(xorshift32(rng)) / 4294967296.0;
    return (u1 - u2);
}

} // namespace

struct timbre_dsp_engine {
    // Wait-free triple buffer: the writer only touches slots[writer_idx], the audio thread only
    // slots[reader_idx]; `middle` hands the newest published slot over (kDirty = not yet taken).
    static constexpr int kDirty = 4;
    std::array<ParameterSlot, 3> slots{};
    std::atomic<int> middle{2};
    int reader_idx{0};                 // audio thread only
    int writer_idx{1};                 // writers only (under writer_mutex)
    std::mutex writer_mutex;           // serialises control-thread writers; never taken on the audio thread
    timbre_dsp_config_t writer_config{};
    std::array<timbre_band_t, TIMBRE_MAX_BANDS> writer_bands{};
    uint32_t writer_band_count{0};
    std::atomic<double> target_output_gain{1.0};
    std::atomic<int> ab_mode{TIMBRE_AB_MODE_FULL};

    // Audio-thread exclusive state (never touched outside RT process)
    std::array<BiquadState, TIMBRE_MAX_BANDS> st_l{};
    std::array<BiquadState, TIMBRE_MAX_BANDS> st_r{};
    std::array<BiquadState, TIMBRE_MAX_BANDS> st_corr_l{};
    std::array<BiquadState, TIMBRE_MAX_BANDS> st_corr_r{};
    TruePeakLimiter limiter{};
    KWeighting kweight{};

    double current_gain{1.0};
    double ab_mix_full{1.0};
    double ab_mix_corr{0.0};
    double crossfeed_z1_l{0.0}, crossfeed_z1_r{0.0};
    uint32_t rng_l{0x12345678u};
    uint32_t rng_r{0x87654321u};

    // Pre-allocated RT delay line for multi-output ms alignment (zero RT alloc)
    static constexpr size_t kMaxDelaySamples = 49152;
    std::vector<double> delay_ring_l;
    std::vector<double> delay_ring_r;
    size_t delay_write_idx{0};

    // BS.1770 400ms momentary window energy accumulator
    std::vector<double> k_energy_ring;
    size_t k_energy_idx{0};
    double k_energy_sum{0.0};

    // FFT spectrum ring (lock-free, RT writes, UI reads)
    FFTSetup fft_setup{nullptr};
    std::array<float, kFftSize> fft_ring{};
    size_t fft_write_idx{0};
    uint32_t fft_frames_accum{0};
    std::array<float, kFftSize> fft_window{};
    std::array<float, kFftSize> fft_scratch_in{};
    std::array<float, kHalfFft> fft_real{};
    std::array<float, kHalfFft> fft_imag{};
    std::array<std::atomic<float>, TIMBRE_SPECTRUM_BINS> spectrum_bins{};

    // Lock-free telemetry atomics
    std::atomic<double> metric_preamp_db{0.0};
    std::atomic<double> metric_tp_l{0.0};
    std::atomic<double> metric_tp_r{0.0};
    std::atomic<double> metric_lufs{-120.0};
    std::atomic<double> metric_gr_db{0.0};
    std::atomic<bool> metric_limiter_active{false};
    std::atomic<uint64_t> metric_clip_count{0};
    std::atomic<uint64_t> metric_last_ns{0};
    std::atomic<uint64_t> metric_frames_total{0};
    std::atomic<uint64_t> metric_zero_streak{0};
};

namespace {

double compute_auto_preamp_db(const std::array<timbre_band_t, TIMBRE_MAX_BANDS>& bands,
                              uint32_t count, double fs, double phase_margin_db) noexcept {
    if (count == 0) return 0.0;
    // Sweep 256 log frequencies 20 Hz .. 20 kHz to find peak of combined magnitude H_total(f)
    double max_mag_db = 0.0;
    constexpr int kSweep = 256;
    const double f_min = 20.0;
    const double f_max = std::min(20000.0, fs * 0.49);
    const double ratio = std::pow(f_max / f_min, 1.0 / (kSweep - 1));
    std::array<BiquadCoeffs, TIMBRE_MAX_BANDS> coeffs{};
    for (uint32_t i = 0; i < count; ++i) {
        coeffs[i] = compute_coeffs(bands[i], fs);
    }
    double f = f_min;
    for (int s = 0; s < kSweep; ++s) {
        const double w = kTwoPi * f / fs;
        std::complex<double> H(1.0, 0.0);
        for (uint32_t i = 0; i < count; ++i) {
            if (bands[i].enabled && bands[i].type != TIMBRE_FILTER_BYPASS) {
                H *= eval_biquad_z(coeffs[i], w);
            }
        }
        const double mag_db = lin_to_db(std::abs(H));
        if (mag_db > max_mag_db) max_mag_db = mag_db;
        f *= ratio;
    }
    return (max_mag_db > 0.0) ? -(max_mag_db + std::max(0.0, phase_margin_db)) : 0.0;
}

void populate_slot(ParameterSlot& slot, const timbre_dsp_config_t& cfg,
                   const timbre_band_t* bands, uint32_t count) noexcept {
    slot.config = cfg;
    slot.band_count = std::min<uint32_t>(count, TIMBRE_MAX_BANDS);
    for (uint32_t i = 0; i < slot.band_count; ++i) {
        slot.raw_bands[i] = bands[i];
        slot.coeffs[i] = compute_coeffs(bands[i], cfg.sample_rate);
    }
    slot.preamp_db = compute_auto_preamp_db(slot.raw_bands, slot.band_count, cfg.sample_rate, cfg.phase_margin_db);
    slot.preamp_linear = db_to_lin(slot.preamp_db);

    // Crossfeed 1-pole low-pass RC approximation (bs2b inspired)
    const double wc = kTwoPi * std::clamp(cfg.crossfeed_cutoff_hz, 200.0, 2000.0) / cfg.sample_rate;
    const double k = wc / (1.0 + wc);
    slot.crossfeed_low_b0 = k;
    slot.crossfeed_low_b1 = 0.0;
    slot.crossfeed_low_a1 = 1.0 - k;
    slot.crossfeed_feed_lin = cfg.crossfeed_enabled ? db_to_lin(-std::abs(cfg.crossfeed_feed_db)) : 0.0;
}

} // namespace

extern "C" {

timbre_dsp_config_t timbre_dsp_default_config(double sample_rate, uint32_t max_frames) {
    timbre_dsp_config_t c{};
    c.sample_rate = (sample_rate > 1000.0) ? sample_rate : 48000.0;
    c.max_frames = (max_frames > 0) ? max_frames : 512;
    c.limiter_ceiling_dbtp = -0.3;
    c.limiter_enabled = true;
    c.phase_margin_db = 0.5;
    c.crossfeed_enabled = false;
    c.crossfeed_cutoff_hz = 700.0;
    c.crossfeed_feed_db = 4.5;
    c.dither_bits = 0;
    c.delay_ms = 0.0;
    return c;
}

timbre_dsp_engine_t* timbre_dsp_create(timbre_dsp_config_t config) {
    auto* eng = new timbre_dsp_engine();
    if (config.sample_rate <= 1000.0) config.sample_rate = 48000.0;
    for (auto& s : eng->slots) populate_slot(s, config, nullptr, 0);
    eng->writer_config = config;
    eng->limiter.prepare(config.sample_rate);
    eng->kweight.configure(config.sample_rate);

    eng->delay_ring_l.assign(timbre_dsp_engine::kMaxDelaySamples, 0.0);
    eng->delay_ring_r.assign(timbre_dsp_engine::kMaxDelaySamples, 0.0);
    const size_t k_win_samples = std::max<size_t>(1, static_cast<size_t>(config.sample_rate * 0.4));
    eng->k_energy_ring.assign(k_win_samples, 0.0);

    eng->fft_setup = vDSP_create_fftsetup(10, FFT_RADIX2); // 2^10 = 1024
    vDSP_hann_window(eng->fft_window.data(), kFftSize, vDSP_HANN_NORM);
    for (auto& b : eng->spectrum_bins) b.store(-120.0f, std::memory_order_relaxed);
    return eng;
}

void timbre_dsp_destroy(timbre_dsp_engine_t* engine) {
    if (!engine) return;
    if (engine->fft_setup) vDSP_destroy_fftsetup(engine->fft_setup);
    delete engine;
}

namespace {
// Caller holds writer_mutex.
void publish_locked(timbre_dsp_engine_t* engine) noexcept {
    ParameterSlot& s = engine->slots[engine->writer_idx];
    populate_slot(s, engine->writer_config, engine->writer_bands.data(), engine->writer_band_count);
    engine->metric_preamp_db.store(s.preamp_db, std::memory_order_relaxed);
    engine->writer_idx = engine->middle.exchange(engine->writer_idx | timbre_dsp_engine::kDirty, std::memory_order_acq_rel) & 3;
}

void copy_bands_locked(timbre_dsp_engine_t* engine, const timbre_band_t* bands, uint32_t count) noexcept {
    engine->writer_band_count = bands ? std::min<uint32_t>(count, TIMBRE_MAX_BANDS) : 0;
    for (uint32_t i = 0; i < engine->writer_band_count; ++i) engine->writer_bands[i] = bands[i];
}
} // namespace

void timbre_dsp_update(timbre_dsp_engine_t* engine, timbre_dsp_config_t config, const timbre_band_t* bands, uint32_t count) {
    if (!engine) return;
    std::lock_guard<std::mutex> g(engine->writer_mutex);
    engine->writer_config = config;
    copy_bands_locked(engine, bands, count);
    publish_locked(engine);
}

void timbre_dsp_update_config(timbre_dsp_engine_t* engine, timbre_dsp_config_t config) {
    if (!engine) return;
    std::lock_guard<std::mutex> g(engine->writer_mutex);
    engine->writer_config = config;
    publish_locked(engine);
}

void timbre_dsp_set_bands(timbre_dsp_engine_t* engine, const timbre_band_t* bands, uint32_t count) {
    if (!engine) return;
    std::lock_guard<std::mutex> g(engine->writer_mutex);
    copy_bands_locked(engine, bands, count);
    publish_locked(engine);
}

void timbre_dsp_set_output_gain(timbre_dsp_engine_t* engine, double linear_gain) {
    if (!engine) return;
    engine->target_output_gain.store(std::clamp(linear_gain, 0.0, 4.0), std::memory_order_relaxed);
}

void timbre_dsp_set_ab_mode(timbre_dsp_engine_t* engine, timbre_ab_mode_t mode) {
    if (!engine) return;
    engine->ab_mode.store(static_cast<int>(mode), std::memory_order_relaxed);
}

void timbre_dsp_eval_response(
    const timbre_band_t* bands,
    uint32_t count,
    double sample_rate,
    const double* freqs_hz,
    uint32_t num_freqs,
    double* out_mag_db,
    double* out_phase_rad,
    timbre_eq_layer_t layer_filter_mask_mode,
    double* out_recommended_preamp_db,
    double phase_margin_db
) {
    if (!freqs_hz || !out_mag_db || num_freqs == 0) return;
    std::array<timbre_band_t, TIMBRE_MAX_BANDS> arr{};
    const uint32_t n = std::min<uint32_t>(count, TIMBRE_MAX_BANDS);
    std::array<BiquadCoeffs, TIMBRE_MAX_BANDS> coeffs{};
    for (uint32_t i = 0; i < n; ++i) {
        arr[i] = bands[i];
        coeffs[i] = compute_coeffs(arr[i], sample_rate);
    }
    if (out_recommended_preamp_db) {
        *out_recommended_preamp_db = compute_auto_preamp_db(arr, n, sample_rate, phase_margin_db);
    }
    for (uint32_t f_i = 0; f_i < num_freqs; ++f_i) {
        const double w = kTwoPi * freqs_hz[f_i] / sample_rate;
        std::complex<double> H(1.0, 0.0);
        for (uint32_t i = 0; i < n; ++i) {
            if (!arr[i].enabled || arr[i].type == TIMBRE_FILTER_BYPASS) continue;
            if (layer_filter_mask_mode != TIMBRE_LAYER_ALL && arr[i].layer != layer_filter_mask_mode) continue;
            H *= eval_biquad_z(coeffs[i], w);
        }
        out_mag_db[f_i] = lin_to_db(std::abs(H));
        if (out_phase_rad) out_phase_rad[f_i] = std::arg(H);
    }
}

void timbre_dsp_compute_biquad(
    timbre_band_t band,
    double sample_rate,
    double out_b[3],
    double out_a[3]
) {
    const BiquadCoeffs c = compute_coeffs(band, sample_rate);
    out_b[0] = c.b0; out_b[1] = c.b1; out_b[2] = c.b2;
    out_a[0] = 1.0;  out_a[1] = c.a1; out_a[2] = c.a2;
}

void timbre_dsp_process_planar_f32(
    timbre_dsp_engine_t* engine,
    const float* in_l,
    const float* in_r,
    float* out_l,
    float* out_r,
    uint32_t frame_count
) {
    if (!engine || !in_l || !in_r || !out_l || !out_r || frame_count == 0) return;

    const auto t0 = std::chrono::steady_clock::now();
    if (engine->middle.load(std::memory_order_acquire) & timbre_dsp_engine::kDirty) {
        engine->reader_idx = engine->middle.exchange(engine->reader_idx, std::memory_order_acq_rel) & 3;
    }
    const ParameterSlot& slot = engine->slots[engine->reader_idx];
    const double fs = slot.config.sample_rate;
    const double gain_target = engine->target_output_gain.load(std::memory_order_relaxed);
    const double gain_alpha = 1.0 - std::exp(-1.0 / (fs * 0.010)); // 10 ms de-zippering
    const double ab_alpha = 1.0 - std::exp(-1.0 / (fs * 0.020));   // 20 ms A/B crossfade (C-04)

    const int mode = engine->ab_mode.load(std::memory_order_relaxed);
    const double target_full = (mode == TIMBRE_AB_MODE_FULL) ? 1.0 : 0.0;
    const double target_corr = (mode == TIMBRE_AB_MODE_CORRECTION_ONLY) ? 1.0 : 0.0;
    const double ceiling_lin = db_to_lin(slot.config.limiter_ceiling_dbtp);
    const size_t delay_samples = std::min<size_t>(
        timbre_dsp_engine::kMaxDelaySamples - 1,
        static_cast<size_t>(std::max(0.0, std::clamp(slot.config.delay_ms, 0.0, 250.0) * fs / 1000.0 + 0.5))
    );

    double max_tp_l = 0.0, max_tp_r = 0.0, min_gr = 1.0;
    double max_in_abs = 0.0;
    bool any_clip = false;
    uint64_t clip_events = 0;

    for (uint32_t i = 0; i < frame_count; ++i) {
        engine->current_gain += gain_alpha * (gain_target - engine->current_gain);
        engine->ab_mix_full += ab_alpha * (target_full - engine->ab_mix_full);
        engine->ab_mix_corr += ab_alpha * (target_corr - engine->ab_mix_corr);
        const double ab_mix_bypass = std::max(0.0, 1.0 - engine->ab_mix_full - engine->ab_mix_corr);

        const double dry_l = static_cast<double>(in_l[i]);
        const double dry_r = static_cast<double>(in_r[i]);
        max_in_abs = std::max(max_in_abs, std::max(std::abs(dry_l), std::abs(dry_r)));

        // Full chain (Correction + Taste + Source)
        double full_l = dry_l * slot.preamp_linear;
        double full_r = dry_r * slot.preamp_linear;
        double corr_l = dry_l * slot.preamp_linear;
        double corr_r = dry_r * slot.preamp_linear;

        for (uint32_t b = 0; b < slot.band_count; ++b) {
            const auto& band = slot.raw_bands[b];
            if (!band.enabled || band.type == TIMBRE_FILTER_BYPASS) continue;
            const auto& c = slot.coeffs[b];
            full_l = engine->st_l[b].tick(full_l, c);
            full_r = engine->st_r[b].tick(full_r, c);
            if (band.layer != TIMBRE_LAYER_TASTE) {
                corr_l = engine->st_corr_l[b].tick(corr_l, c);
                corr_r = engine->st_corr_r[b].tick(corr_r, c);
            }
        }

        double sig_l = full_l * engine->ab_mix_full + corr_l * engine->ab_mix_corr + dry_l * ab_mix_bypass;
        double sig_r = full_r * engine->ab_mix_full + corr_r * engine->ab_mix_corr + dry_r * ab_mix_bypass;

        // Opt-in Crossfeed (bs2b-style)
        if (slot.config.crossfeed_enabled && slot.crossfeed_feed_lin > 0.0) {
            const double lp_l = slot.crossfeed_low_b0 * sig_l + slot.crossfeed_low_a1 * engine->crossfeed_z1_l;
            const double lp_r = slot.crossfeed_low_b0 * sig_r + slot.crossfeed_low_a1 * engine->crossfeed_z1_r;
            engine->crossfeed_z1_l = lp_l;
            engine->crossfeed_z1_r = lp_r;
            const double nl = sig_l + lp_r * slot.crossfeed_feed_lin;
            const double nr = sig_r + lp_l * slot.crossfeed_feed_lin;
            sig_l = nl;
            sig_r = nr;
        }

        sig_l *= engine->current_gain;
        sig_r *= engine->current_gain;

        // True-Peak Protection Limiter
        double lim_l = sig_l, lim_r = sig_r, tp_l = 0.0, tp_r = 0.0, gr = 1.0;
        bool clipped = false;
        engine->limiter.process_sample(sig_l, sig_r, ceiling_lin, slot.config.limiter_enabled,
                                       lim_l, lim_r, tp_l, tp_r, gr, clipped);
        max_tp_l = std::max(max_tp_l, tp_l);
        max_tp_r = std::max(max_tp_r, tp_r);
        min_gr = std::min(min_gr, gr);
        if (clipped) { any_clip = true; ++clip_events; }

        // Optional multi-output ms alignment delay line (zero RT alloc)
        if (delay_samples > 0 && !engine->delay_ring_l.empty()) {
            const size_t cap = engine->delay_ring_l.size();
            const size_t w = engine->delay_write_idx;
            engine->delay_ring_l[w] = lim_l;
            engine->delay_ring_r[w] = lim_r;
            const size_t r = (w + cap - delay_samples) % cap;
            lim_l = engine->delay_ring_l[r];
            lim_r = engine->delay_ring_r[r];
            engine->delay_write_idx = (w + 1) % cap;
        }

        // Optional TPDF Dither (Wannamaker)
        if (slot.config.dither_bits == 16 || slot.config.dither_bits == 24) {
            const double lsb = 1.0 / static_cast<double>(1ull << (slot.config.dither_bits - 1));
            lim_l = std::round((lim_l + tpdf_noise(engine->rng_l) * lsb) / lsb) * lsb;
            lim_r = std::round((lim_r + tpdf_noise(engine->rng_r) * lsb) / lsb) * lsb;
        }

        out_l[i] = static_cast<float>(lim_l);
        out_r[i] = static_cast<float>(lim_r);

        // BS.1770 K-weighted momentary loudness (400 ms ring)
        double kl = lim_l, kr = lim_r;
        engine->kweight.process(kl, kr);
        const double e_inst = 0.5 * (kl * kl + kr * kr);
        const size_t rsize = engine->k_energy_ring.size();
        engine->k_energy_sum -= engine->k_energy_ring[engine->k_energy_idx];
        engine->k_energy_ring[engine->k_energy_idx] = e_inst;
        engine->k_energy_sum += e_inst;
        engine->k_energy_idx = (engine->k_energy_idx + 1) % rsize;

        // Spectrum ring write (mono mid)
        engine->fft_ring[engine->fft_write_idx] = 0.5f * (out_l[i] + out_r[i]);
        engine->fft_write_idx = (engine->fft_write_idx + 1) % kFftSize;
    }

    // Throttle visual FFT computation to ~60 Hz (at least fs/60 frames) so RT CPU stays <0.5% even at 192 kHz.
    engine->fft_frames_accum += frame_count;
    const uint32_t fft_stride = std::max<uint32_t>(512, static_cast<uint32_t>(fs / 60.0));
    if (engine->fft_setup && engine->fft_frames_accum >= fft_stride) {
        engine->fft_frames_accum = 0;
        for (size_t k = 0; k < kFftSize; ++k) {
            const size_t idx = (engine->fft_write_idx + k) % kFftSize;
            engine->fft_scratch_in[k] = engine->fft_ring[idx] * engine->fft_window[k];
        }
        DSPSplitComplex split{engine->fft_real.data(), engine->fft_imag.data()};
        vDSP_ctoz(reinterpret_cast<const DSPComplex*>(engine->fft_scratch_in.data()), 2, &split, 1, kHalfFft);
        vDSP_fft_zrip(engine->fft_setup, &split, 1, 10, FFT_FORWARD);
        // Log-bin downsampling into 128 visual bins (20 Hz .. 20 kHz)
        const double f_min = 20.0, f_max = std::min(20000.0, fs * 0.49);
        const double r = std::pow(f_max / f_min, 1.0 / (TIMBRE_SPECTRUM_BINS - 1));
        double f = f_min;
        for (uint32_t b = 0; b < TIMBRE_SPECTRUM_BINS; ++b) {
            const size_t bin = std::clamp<size_t>(static_cast<size_t>(f * kFftSize / fs), 1, kHalfFft - 1);
            const float re = engine->fft_real[bin];
            const float im = engine->fft_imag[bin];
            const float mag = std::sqrt(re * re + im * im) / static_cast<float>(kFftSize);
            const float db = 20.0f * std::log10(std::max(mag, 1e-6f));
            engine->spectrum_bins[b].store(db, std::memory_order_relaxed);
            f *= r;
        }
    }

    const double mean_e = std::max(engine->k_energy_sum / static_cast<double>(engine->k_energy_ring.size()), 1e-12);
    const double lufs = -0.691 + 10.0 * std::log10(mean_e * 2.0); // stereo sum L+R

    const auto t1 = std::chrono::steady_clock::now();
    const uint64_t ns = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count());

    engine->metric_tp_l.store(lin_to_db(max_tp_l), std::memory_order_relaxed);
    engine->metric_tp_r.store(lin_to_db(max_tp_r), std::memory_order_relaxed);
    engine->metric_lufs.store(lufs, std::memory_order_relaxed);
    engine->metric_gr_db.store(lin_to_db(min_gr), std::memory_order_relaxed);
    engine->metric_limiter_active.store(any_clip || min_gr < 0.999, std::memory_order_relaxed);
    if (clip_events > 0) engine->metric_clip_count.fetch_add(clip_events, std::memory_order_relaxed);
    engine->metric_last_ns.store(ns, std::memory_order_relaxed);
    engine->metric_frames_total.fetch_add(frame_count, std::memory_order_relaxed);
    if (max_in_abs == 0.0) { engine->metric_zero_streak.fetch_add(1, std::memory_order_relaxed); }
    else { engine->metric_zero_streak.store(0, std::memory_order_relaxed); }
}

void timbre_dsp_process_interleaved_f32(
    timbre_dsp_engine_t* engine,
    const float* input,
    float* output,
    uint32_t frame_count
) {
    if (!engine || !input || !output || frame_count == 0) return;
    // Fixed stack deinterleave in chunks of 256 frames (zero heap allocation!)
    std::array<float, 256> in_l{}, in_r{}, out_l{}, out_r{};
    uint32_t offset = 0;
    while (offset < frame_count) {
        const uint32_t chunk = std::min<uint32_t>(256, frame_count - offset);
        for (uint32_t i = 0; i < chunk; ++i) {
            in_l[i] = input[(offset + i) * 2];
            in_r[i] = input[(offset + i) * 2 + 1];
        }
        timbre_dsp_process_planar_f32(engine, in_l.data(), in_r.data(), out_l.data(), out_r.data(), chunk);
        for (uint32_t i = 0; i < chunk; ++i) {
            output[(offset + i) * 2] = out_l[i];
            output[(offset + i) * 2 + 1] = out_r[i];
        }
        offset += chunk;
    }
}

void timbre_dsp_process_strided_f32(
    timbre_dsp_engine_t* engine,
    const float* in_l,
    const float* in_r,
    uint32_t in_stride,
    float* out_l,
    float* out_r,
    uint32_t out_stride,
    uint32_t frame_count
) {
    if (!engine || !in_l || !in_r || !out_l || frame_count == 0) return;
    if (in_stride == 0) in_stride = 1;
    if (out_stride == 0) out_stride = 1;
    std::array<float, 256> a_l{}, a_r{}, b_l{}, b_r{};
    uint32_t offset = 0;
    while (offset < frame_count) {
        const uint32_t chunk = std::min<uint32_t>(256, frame_count - offset);
        for (uint32_t i = 0; i < chunk; ++i) {
            const size_t k = static_cast<size_t>(offset + i) * in_stride;
            a_l[i] = in_l[k];
            a_r[i] = in_r[k];
        }
        timbre_dsp_process_planar_f32(engine, a_l.data(), a_r.data(), b_l.data(), b_r.data(), chunk);
        for (uint32_t i = 0; i < chunk; ++i) {
            const size_t k = static_cast<size_t>(offset + i) * out_stride;
            if (out_r) {
                out_l[k] = b_l[i];
                out_r[k] = b_r[i];
            } else {
                out_l[k] = 0.5f * (b_l[i] + b_r[i]);
            }
        }
        offset += chunk;
    }
}

timbre_dsp_metrics_t timbre_dsp_get_metrics(const timbre_dsp_engine_t* engine) {
    timbre_dsp_metrics_t m{};
    if (!engine) return m;
    m.preamp_db = engine->metric_preamp_db.load(std::memory_order_relaxed);
    m.true_peak_l_dbtp = engine->metric_tp_l.load(std::memory_order_relaxed);
    m.true_peak_r_dbtp = engine->metric_tp_r.load(std::memory_order_relaxed);
    m.lufs_momentary = engine->metric_lufs.load(std::memory_order_relaxed);
    m.limiter_gr_db = engine->metric_gr_db.load(std::memory_order_relaxed);
    m.limiter_active = engine->metric_limiter_active.load(std::memory_order_relaxed);
    m.clip_prevented_count = engine->metric_clip_count.load(std::memory_order_relaxed);
    m.process_ns_last = engine->metric_last_ns.load(std::memory_order_relaxed);
    m.total_frames_processed = engine->metric_frames_total.load(std::memory_order_relaxed);
    m.zero_buffer_streak = engine->metric_zero_streak.load(std::memory_order_relaxed);
    return m;
}

void timbre_dsp_copy_spectrum(const timbre_dsp_engine_t* engine, float* out_bins_db, uint32_t max_bins) {
    if (!engine || !out_bins_db) return;
    const uint32_t n = std::min<uint32_t>(max_bins, TIMBRE_SPECTRUM_BINS);
    for (uint32_t i = 0; i < n; ++i) {
        out_bins_db[i] = engine->spectrum_bins[i].load(std::memory_order_relaxed);
    }
}

} // extern "C"
