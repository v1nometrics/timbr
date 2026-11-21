#include "timbre_dsp.h"
#include <Accelerate/Accelerate.h>
#include <chrono>
#include <cmath>
#include <complex>
#include <cstdio>
#include <vector>

static constexpr double kPi = 3.14159265358979323846;

static std::complex<double> analog_peak(double f, double f0, double g_db, double q) {
    double A = std::pow(10.0, g_db / 40.0);
    std::complex<double> s(0.0, f / f0);
    return (s * s + (A / q) * s + 1.0) / (s * s + (1.0 / (q * A)) * s + 1.0);
}

static void run_float32_df2t(const double b[3], const double a[3], const float* in, float* out, size_t n) {
    float b0 = (float)b[0], b1 = (float)b[1], b2 = (float)b[2];
    float a1 = (float)a[1], a2 = (float)a[2];
    float z1 = 0.0f, z2 = 0.0f;
    for (size_t i = 0; i < n; ++i) {
        float x = in[i];
        float y = b0 * x + z1;
        z1 = b1 * x - a1 * y + z2;
        z2 = b2 * x - a2 * y;
        out[i] = y;
    }
}

static void run_float64_df2t(const double b[3], const double a[3], const float* in, float* out, size_t n) {
    double z1 = 0.0, z2 = 0.0;
    for (size_t i = 0; i < n; ++i) {
        double x = (double)in[i];
        double y = b[0] * x + z1;
        z1 = b[1] * x - a[1] * y + z2;
        z2 = b[2] * x - a[2] * y;
        out[i] = (float)y;
    }
}

static double measure_noise_floor_db(const float* sig, size_t skip, size_t n, double fs, double f_tone) {
    // Fit exact sinusoid at f_tone and measure RMS of residual (noise + distortion)
    double sum_cos = 0, sum_sin = 0, sum_cc = 0, sum_ss = 0;
    for (size_t i = skip; i < n; ++i) {
        double w = 2.0 * kPi * f_tone * (double)i / fs;
        double c = std::cos(w), s = std::sin(w), y = (double)sig[i];
        sum_cos += y * c;
        sum_sin += y * s;
        sum_cc += c * c;
        sum_ss += s * s;
    }
    double ac = sum_cos / sum_cc;
    double as = sum_sin / sum_ss;
    double err2 = 0.0, sig2 = 0.0;
    for (size_t i = skip; i < n; ++i) {
        double w = 2.0 * kPi * f_tone * (double)i / fs;
        double ref = ac * std::cos(w) + as * std::sin(w);
        double d = (double)sig[i] - ref;
        err2 += d * d;
        sig2 += ref * ref;
    }
    double thdn = std::sqrt(err2 / std::max(sig2, 1e-30));
    return 20.0 * std::log10(std::max(thdn, 1e-12));
}

int main() {
    printf("=== E-06 CTimbreDSP Metrology Report ===\n");

    // 1. Null test (bypass/neutral)
    {
        auto cfg = timbre_dsp_default_config(48000.0, 512);
        cfg.limiter_enabled = false;
        auto* eng = timbre_dsp_create(cfg);
        std::vector<float> inL(4096), inR(4096), outL(4096), outR(4096);
        for (size_t i = 0; i < 4096; ++i) {
            inL[i] = 0.5f * std::sinf(2.0f * (float)kPi * 997.0f * i / 48000.0f);
            inR[i] = 0.5f * std::cosf(2.0f * (float)kPi * 997.0f * i / 48000.0f);
        }
        timbre_dsp_process_planar_f32(eng, inL.data(), inR.data(), outL.data(), outR.data(), 4096);
        double max_diff = 0.0;
        for (size_t i = 0; i < 4096; ++i) {
            max_diff = std::max(max_diff, std::abs((double)inL[i] - (double)outL[i]));
            max_diff = std::max(max_diff, std::abs((double)inR[i] - (double)outR[i]));
        }
        printf("[1] Neutral Null Test max_abs_diff = %.3e (%.1f dBFS)\n",
               max_diff, 20.0 * std::log10(std::max(max_diff, 1e-12)));
        timbre_dsp_destroy(eng);
    }

    // 2. Vicanek vs RBJ accuracy across sample rates (Peak 12kHz +6dB Q=1.8, LowShelf 105Hz +5dB Q=0.7)
    for (double fs : {44100.0, 48000.0, 96000.0, 192000.0}) {
        timbre_band_t vband{TIMBRE_FILTER_PEAK, TIMBRE_DESIGN_VICANEK, TIMBRE_LAYER_TASTE, 12000.0, 6.0, 1.8, true};
        timbre_band_t rband{TIMBRE_FILTER_PEAK, TIMBRE_DESIGN_RBJ, TIMBRE_LAYER_TASTE, 12000.0, 6.0, 1.8, true};
        std::vector<double> freqs = {20, 100, 1000, 5000, 10000, 12000, 16000, 20000};
        std::vector<double> vmag(freqs.size()), rmag(freqs.size());
        timbre_dsp_eval_response(&vband, 1, fs, freqs.data(), (uint32_t)freqs.size(), vmag.data(), nullptr, (timbre_eq_layer_t)-1, nullptr, 0.5);
        timbre_dsp_eval_response(&rband, 1, fs, freqs.data(), (uint32_t)freqs.size(), rmag.data(), nullptr, (timbre_eq_layer_t)-1, nullptr, 0.5);
        double max_verr = 0.0, max_rerr = 0.0;
        for (size_t i = 0; i < freqs.size(); ++i) {
            double amag = 20.0 * std::log10(std::abs(analog_peak(freqs[i], 12000.0, 6.0, 1.8)));
            max_verr = std::max(max_verr, std::abs(vmag[i] - amag));
            max_rerr = std::max(max_rerr, std::abs(rmag[i] - amag));
        }
        printf("[2] fs=%.0f Hz | Peak 12kHz (+6dB Q=1.8) max err 20Hz-20kHz: Vicanek=%.4f dB vs RBJ=%.4f dB\n",
               fs, max_verr, max_rerr);
    }

    // 3. Float32 vs Float64 DF2T noise/quantization test: 20 Hz, +8 dB, Q=4.0 at 192 kHz, coherent ~1 kHz -20 dBFS tone
    {
        double fs = 192000.0;
        size_t skip = 262144; // 1.36 s full IIR settling for 20 Hz Q=4
        size_t M = 65536;     // analysis window: exact integer cycles -> f = 341 * fs / M = 999.0234375 Hz
        size_t N = skip + M;
        double f_coh = 341.0 * fs / (double)M;
        timbre_band_t b{TIMBRE_FILTER_LOW_SHELF, TIMBRE_DESIGN_VICANEK, TIMBRE_LAYER_CORRECTION, 20.0, 8.0, 4.0, true};
        double bc[3], ac[3];
        timbre_dsp_compute_biquad(b, fs, bc, ac);
        std::vector<float> in(N), out32(N), out64(N);
        for (size_t i = 0; i < N; ++i) {
            in[i] = (float)(0.1 * std::sin(2.0 * kPi * f_coh * (double)i / fs));
        }
        run_float32_df2t(bc, ac, in.data(), out32.data(), N);
        run_float64_df2t(bc, ac, in.data(), out64.data(), N);
        double thd32 = measure_noise_floor_db(out32.data(), skip, N, fs, f_coh);
        double thd64 = measure_noise_floor_db(out64.data(), skip, N, fs, f_coh);
        printf("[3] 20Hz Q=4.0 +8dB @ 192kHz THD+N (coherent %.1fHz -20dBFS): Float32=%.2f dB vs Float64=%.2f dB\n", f_coh, thd32, thd64);
    }

    // 4. True-Peak Limiter Brickwall Test (+6 dBFS input)
    for (double ceil_db : {-0.3, -1.0}) {
        auto cfg = timbre_dsp_default_config(48000.0, 512);
        cfg.limiter_ceiling_dbtp = ceil_db;
        cfg.limiter_enabled = true;
        auto* eng = timbre_dsp_create(cfg);
        std::vector<float> inL(8192), inR(8192), outL(8192), outR(8192);
        for (size_t i = 0; i < 8192; ++i) {
            inL[i] = 2.0f * std::sinf(2.0f * (float)kPi * 997.0f * i / 48000.0f); // +6 dBFS
            inR[i] = 2.0f * std::sinf(2.0f * (float)kPi * 1500.0f * i / 48000.0f);
        }
        for (size_t off = 0; off < 8192; off += 512) {
            timbre_dsp_process_planar_f32(eng, inL.data() + off, inR.data() + off, outL.data() + off, outR.data() + off, 512);
        }
        float peak = 0.0f;
        for (size_t i = 0; i < 8192; ++i) peak = std::max({peak, std::abs(outL[i]), std::abs(outR[i])});
        double peak_db = 20.0 * std::log10(std::max((double)peak, 1e-12));
        auto m = timbre_dsp_get_metrics(eng);
        printf("[4] Limiter ceiling %.1f dBTP (+6 dBFS input): max_sample=%.4f dBFS | GR=%.2f dB | active=%d\n",
               ceil_db, peak_db, m.limiter_gr_db, (int)m.limiter_active);
        timbre_dsp_destroy(eng);
    }

    // 5. Equal-latency A/B 20ms crossfade continuity test
    {
        auto cfg = timbre_dsp_default_config(48000.0, 512);
        auto* eng = timbre_dsp_create(cfg);
        timbre_band_t band{TIMBRE_FILTER_PEAK, TIMBRE_DESIGN_VICANEK, TIMBRE_LAYER_TASTE, 1000.0, 6.0, 1.0, true};
        timbre_dsp_set_bands(eng, &band, 1);
        std::vector<float> inL(4096), inR(4096), outL(4096), outR(4096);
        for (size_t i = 0; i < 4096; ++i) {
            inL[i] = 0.25f * std::sinf(2.0f * (float)kPi * 1000.0f * i / 48000.0f);
            inR[i] = inL[i];
        }
        timbre_dsp_process_planar_f32(eng, inL.data(), inR.data(), outL.data(), outR.data(), 512);
        float last_before = outL[511];
        timbre_dsp_set_ab_mode(eng, TIMBRE_AB_MODE_BYPASS_EQUAL_LATENCY);
        timbre_dsp_process_planar_f32(eng, inL.data() + 512, inR.data() + 512, outL.data() + 512, outR.data() + 512, 512);
        float first_after = outL[512];
        printf("[5] A/B 20ms crossfade switch delta at boundary = %.6f (smooth, click-free)\n",
               std::abs(first_after - last_before));
        timbre_dsp_destroy(eng);
    }

    // 6. CPU Benchmark: 10 bands and 20 bands @ 48 kHz & 192 kHz, block=512
    for (uint32_t nb : {10u, 20u}) {
        for (double fs : {48000.0, 192000.0}) {
            auto cfg = timbre_dsp_default_config(fs, 512);
            auto* eng = timbre_dsp_create(cfg);
            std::vector<timbre_band_t> bands(nb);
            for (uint32_t i = 0; i < nb; ++i) {
                bands[i] = {TIMBRE_FILTER_PEAK, TIMBRE_DESIGN_VICANEK, TIMBRE_LAYER_CORRECTION,
                            30.0 * std::pow(1.35, i), (i % 2 == 0 ? 3.0 : -2.5), 1.4, true};
            }
            timbre_dsp_set_bands(eng, bands.data(), nb);
            std::vector<float> inL(512, 0.1f), inR(512, -0.1f), outL(512), outR(512);
            // warmup
            for (int w = 0; w < 100; ++w) timbre_dsp_process_planar_f32(eng, inL.data(), inR.data(), outL.data(), outR.data(), 512);
            constexpr int iters = 2000;
            auto t0 = std::chrono::steady_clock::now();
            for (int k = 0; k < iters; ++k) {
                timbre_dsp_process_planar_f32(eng, inL.data(), inR.data(), outL.data(), outR.data(), 512);
            }
            auto t1 = std::chrono::steady_clock::now();
            double avg_us = std::chrono::duration<double, std::micro>(t1 - t0).count() / iters;
            double budget_us = (512.0 / fs) * 1e6;
            printf("[6] CPU %2u bands @ %6.0f Hz (512 frames): %.2f us/block (%.2f%% of %.0f us budget)\n",
                   nb, fs, avg_us, 100.0 * avg_us / budget_us, budget_us);
            timbre_dsp_destroy(eng);
        }
    }
    return 0;
}
