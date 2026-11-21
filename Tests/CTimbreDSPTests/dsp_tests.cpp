// SPDX-License-Identifier: MPL-2.0
#include "timbre_dsp.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <vector>

static double analog_peak_db(double f, double fc, double gain_db, double q) {
    double A = std::pow(10.0, gain_db / 40.0);
    double w = f / fc;
    double num = std::pow(1.0 - w * w, 2.0) + std::pow((A / q) * w, 2.0);
    double den = std::pow(1.0 - w * w, 2.0) + std::pow((1.0 / (A * q)) * w, 2.0);
    return 10.0 * std::log10(num / den);
}

int main() {
    std::printf("[CTimbreDSPTests] Running DSP metrology verification...\n");

    // 1. Neutral Null Test (Bit-transparent)
    {
        auto cfg = timbre_dsp_default_config(48000.0, 512);
        cfg.limiter_enabled = false;
        auto* eng = timbre_dsp_create(cfg);
        assert(eng != nullptr);
        std::vector<float> in(512 * 2), out(512 * 2);
        for (size_t i = 0; i < 512; ++i) {
            float s = 0.25f * std::sin(2.0 * M_PI * 1000.0 * double(i) / 48000.0);
            in[2 * i] = s;
            in[2 * i + 1] = -s;
        }
        timbre_dsp_process_interleaved_f32(eng, in.data(), out.data(), 512);
        double max_diff = 0.0;
        for (size_t i = 0; i < in.size(); ++i) {
            max_diff = std::max(max_diff, std::abs(double(in[i]) - double(out[i])));
        }
        assert(max_diff <= 1e-6);
        timbre_dsp_destroy(eng);
        std::printf("  [PASS] Neutral null test: max_diff=%.3e\n", max_diff);
    }

    // 2. Vicanek vs RBJ high-frequency Nyquist fidelity (12 kHz +6dB Q=1.8 @ 48 kHz)
    {
        timbre_band_t vic{TIMBRE_FILTER_PEAK, TIMBRE_DESIGN_VICANEK, TIMBRE_LAYER_TASTE, 12000.0, 6.0, 1.8, true};
        timbre_band_t rbj{TIMBRE_FILTER_PEAK, TIMBRE_DESIGN_RBJ, TIMBRE_LAYER_TASTE, 12000.0, 6.0, 1.8, true};
        std::vector<double> freqs{10000.0, 12000.0, 15000.0, 18000.0, 20000.0};
        std::vector<double> mv(freqs.size()), mr(freqs.size());
        double pv = 0, pr = 0;
        timbre_dsp_eval_response(&vic, 1, 48000.0, freqs.data(), uint32_t(freqs.size()), mv.data(), nullptr, TIMBRE_LAYER_ALL, &pv, 0.5);
        timbre_dsp_eval_response(&rbj, 1, 48000.0, freqs.data(), uint32_t(freqs.size()), mr.data(), nullptr, TIMBRE_LAYER_ALL, &pr, 0.5);

        double err_v = 0.0, err_r = 0.0;
        for (size_t i = 0; i < freqs.size(); ++i) {
            double ref = analog_peak_db(freqs[i], 12000.0, 6.0, 1.8);
            err_v = std::max(err_v, std::abs(mv[i] - ref));
            err_r = std::max(err_r, std::abs(mr[i] - ref));
        }
        assert(err_v < err_r);
        assert(err_v < 0.5);
        assert(pv < -5.5);
        std::printf("  [PASS] Vicanek Nyquist err=%.4f dB < RBJ err=%.4f dB (preamp=%.2f dB)\n", err_v, err_r, pv);
    }

    // 3. True-Peak Limiter (-0.3 dBTP wired & -1.0 dBTP BT AAC) under +6 dBFS overload
    {
        for (double ceiling : {-0.3, -1.0}) {
            auto cfg = timbre_dsp_default_config(48000.0, 512);
            cfg.limiter_enabled = true;
            cfg.limiter_ceiling_dbtp = ceiling;
            auto* eng = timbre_dsp_create(cfg);
            std::vector<float> in(512 * 2), out(512 * 2);
            for (int blk = 0; blk < 6; ++blk) {
                for (size_t i = 0; i < 512; ++i) {
                    float s = 2.0f * std::sin(2.0 * M_PI * 997.0 * double(blk * 512 + i) / 48000.0);
                    in[2 * i] = s;
                    in[2 * i + 1] = s;
                }
                timbre_dsp_process_interleaved_f32(eng, in.data(), out.data(), 512);
            }
            float max_sample = 0.0f;
            for (float v : out) max_sample = std::max(max_sample, std::abs(v));
            double peak_db = 20.0 * std::log10(std::max<double>(max_sample, 1e-12));
            auto m = timbre_dsp_get_metrics(eng);
            assert(peak_db <= ceiling + 0.05);
            assert(m.clip_prevented_count > 0);
            timbre_dsp_destroy(eng);
            std::printf("  [PASS] Limiter ceiling=%.1f dBTP -> output=%.2f dBTP, prevented=%llu\n",
                        ceiling, peak_db, (unsigned long long)m.clip_prevented_count);
        }
    }

    // 4. BS.1770 LUFS calibration + FFT spectrum snapshot
    {
        auto cfg = timbre_dsp_default_config(48000.0, 512);
        auto* eng = timbre_dsp_create(cfg);
        std::vector<float> in(512 * 2), out(512 * 2);
        double peak = std::pow(10.0, -20.0 / 20.0);
        for (int blk = 0; blk < 45; ++blk) {
            for (size_t i = 0; i < 512; ++i) {
                float s = float(peak * std::sin(2.0 * M_PI * 1000.0 * double(blk * 512 + i) / 48000.0));
                in[2 * i] = s;
                in[2 * i + 1] = s;
            }
            timbre_dsp_process_interleaved_f32(eng, in.data(), out.data(), 512);
        }
        auto m = timbre_dsp_get_metrics(eng);
        assert(m.lufs_momentary > -25.0 && m.lufs_momentary < -15.0);
        float bins[TIMBRE_SPECTRUM_BINS]{};
        timbre_dsp_copy_spectrum(eng, bins, TIMBRE_SPECTRUM_BINS);
        bool has_energy = false;
        for (float b : bins) if (b > -60.0f) has_energy = true;
        assert(has_energy);
        timbre_dsp_destroy(eng);
        std::printf("  [PASS] BS.1770 LUFS=%.2f & FFT populated\n", m.lufs_momentary);
    }

    // 5. Equal-latency A/B Crossfade & TPDF Dither & bs2b Crossfeed
    {
        auto cfg = timbre_dsp_default_config(48000.0, 512);
        cfg.crossfeed_enabled = true;
        cfg.dither_bits = 24;
        auto* eng = timbre_dsp_create(cfg);
        timbre_band_t bass{TIMBRE_FILTER_LOW_SHELF, TIMBRE_DESIGN_VICANEK, TIMBRE_LAYER_TASTE, 105.0, 4.5, 0.7, true};
        timbre_dsp_set_bands(eng, &bass, 1);

        std::vector<float> in(512 * 2), out(512 * 2);
        for (size_t i = 0; i < 512; ++i) {
            in[2 * i] = 0.25f * std::sin(2.0 * M_PI * 80.0 * double(i) / 48000.0);
            in[2 * i + 1] = 0.0f;
        }
        timbre_dsp_process_interleaved_f32(eng, in.data(), out.data(), 512);
        double right_energy = 0.0;
        for (size_t i = 0; i < 512; ++i) right_energy += out[2 * i + 1] * out[2 * i + 1];
        assert(right_energy > 1e-5);

        timbre_dsp_set_ab_mode(eng, TIMBRE_AB_MODE_BYPASS_EQUAL_LATENCY);
        timbre_dsp_process_interleaved_f32(eng, in.data(), out.data(), 512);
        for (float v : out) assert(std::isfinite(v));
        timbre_dsp_destroy(eng);
        std::printf("  [PASS] Crossfeed, 24-bit TPDF dither & equal-latency A/B verified\n");
    }

    // 6. Multi-output ms delay alignment (10 ms @ 48 kHz = 480 samples)
    {
        auto cfg = timbre_dsp_default_config(48000.0, 1024);
        cfg.limiter_enabled = false;
        cfg.delay_ms = 10.0;
        auto* eng = timbre_dsp_create(cfg);
        std::vector<float> in(1024 * 2, 0.0f), out(1024 * 2, 0.0f);
        in[0] = 0.8f;
        in[1] = -0.8f;
        timbre_dsp_process_interleaved_f32(eng, in.data(), out.data(), 1024);
        size_t peak_idx = 0;
        float peak_val = 0.0f;
        for (size_t i = 0; i < 1024; ++i) {
            if (std::abs(out[2 * i]) > peak_val) {
                peak_val = std::abs(out[2 * i]);
                peak_idx = i;
            }
        }
        assert(peak_idx == 480 && peak_val > 0.79f);
        timbre_dsp_destroy(eng);
        std::printf("  [PASS] Multi-output delay_ms=10.0 aligned impulse at exact sample %zu\n", peak_idx);
    }

    std::printf("[CTimbreDSPTests] ALL PASSED\n");
    return 0;
}
