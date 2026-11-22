// SPDX-License-Identifier: MPL-2.0
#ifndef TIMBRE_DSP_H
#define TIMBRE_DSP_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TIMBRE_MAX_BANDS 32
#define TIMBRE_SPECTRUM_BINS 128

typedef enum {
    TIMBRE_FILTER_BYPASS = 0,
    TIMBRE_FILTER_PEAK = 1,
    TIMBRE_FILTER_LOW_SHELF = 2,
    TIMBRE_FILTER_HIGH_SHELF = 3,
    TIMBRE_FILTER_LOW_PASS = 4,
    TIMBRE_FILTER_HIGH_PASS = 5,
    TIMBRE_FILTER_BAND_PASS = 6,
    TIMBRE_FILTER_NOTCH = 7,
    TIMBRE_FILTER_ALL_PASS = 8
} timbre_filter_type_t;

typedef enum {
    TIMBRE_DESIGN_VICANEK = 0,
    TIMBRE_DESIGN_RBJ = 1
} timbre_design_method_t;

typedef enum {
    TIMBRE_LAYER_CORRECTION = 0,
    TIMBRE_LAYER_TASTE = 1,
    TIMBRE_LAYER_SOURCE = 2,
    TIMBRE_LAYER_ALL = 255
} timbre_eq_layer_t;

typedef enum {
    TIMBRE_AB_MODE_FULL = 0,            // Correction + Taste + Source
    TIMBRE_AB_MODE_CORRECTION_ONLY = 1, // Correction + Source (no Taste)
    TIMBRE_AB_MODE_BYPASS_EQUAL_LATENCY = 2 // Equal-latency flat reference inside active tap (C-04)
} timbre_ab_mode_t;

typedef struct {
    timbre_filter_type_t type;
    timbre_design_method_t design;
    timbre_eq_layer_t layer;
    double freq_hz;
    double gain_db;
    double q;
    bool enabled;
} timbre_band_t;

typedef struct {
    double sample_rate;
    uint32_t max_frames;
    double limiter_ceiling_dbtp; // e.g., -0.3 wired, -1.0 BT AAC (C-03)
    bool limiter_enabled;
    double phase_margin_db;      // e.g., 0.5 dB headroom margin over H_total(f)
    bool crossfeed_enabled;
    double crossfeed_cutoff_hz;  // default 700 Hz
    double crossfeed_feed_db;    // default 4.5 dB
    uint32_t dither_bits;        // 0 = off (Float32), 16 or 24 = TPDF
    double delay_ms;             // 0..250 ms multi-output phase/latency alignment
} timbre_dsp_config_t;

typedef struct {
    double preamp_db;
    double true_peak_l_dbtp;
    double true_peak_r_dbtp;
    double lufs_momentary;
    double limiter_gr_db;
    bool limiter_active;
    uint64_t clip_prevented_count;
    uint64_t process_ns_last;
    uint64_t total_frames_processed;
    uint64_t zero_buffer_streak;
} timbre_dsp_metrics_t;

typedef struct timbre_dsp_engine timbre_dsp_engine_t;

timbre_dsp_config_t timbre_dsp_default_config(double sample_rate, uint32_t max_frames);

timbre_dsp_engine_t* timbre_dsp_create(timbre_dsp_config_t config);
void timbre_dsp_destroy(timbre_dsp_engine_t* engine);

// Non-RT thread: parameters reach the audio thread through a wait-free triple buffer, so a
// writer can never overwrite the slot the audio thread is reading, however fast it publishes.
// Prefer timbre_dsp_update (one publish for config + bands) over the two calls below.
void timbre_dsp_update(timbre_dsp_engine_t* engine, timbre_dsp_config_t config, const timbre_band_t* bands, uint32_t count);
void timbre_dsp_update_config(timbre_dsp_engine_t* engine, timbre_dsp_config_t config);
void timbre_dsp_set_bands(timbre_dsp_engine_t* engine, const timbre_band_t* bands, uint32_t count);
void timbre_dsp_set_output_gain(timbre_dsp_engine_t* engine, double linear_gain);
void timbre_dsp_set_ab_mode(timbre_dsp_engine_t* engine, timbre_ab_mode_t mode);

// Computes exact combined magnitude (dB) and phase (rad) for plotting & metrology.
void timbre_dsp_eval_response(
    const timbre_band_t* bands,
    uint32_t count,
    double sample_rate,
    const double* freqs_hz,
    uint32_t num_freqs,
    double* out_mag_db,
    double* out_phase_rad,
    timbre_eq_layer_t layer_filter_mask_mode, // -1 for all layers, or specific layer
    double* out_recommended_preamp_db,
    double phase_margin_db
);

// RT Audio Thread ONLY: zero heap allocations, zero locks, Float64 internal math.
void timbre_dsp_process_interleaved_f32(
    timbre_dsp_engine_t* engine,
    const float* input,
    float* output,
    uint32_t frame_count
);

// Any channel layout: reads L/R with a stride (interleaved N channels, or planar with stride 1)
// and writes L/R with a stride. out_r == NULL writes a mono mix (L+R)/2 into out_l.
void timbre_dsp_process_strided_f32(
    timbre_dsp_engine_t* engine,
    const float* in_l,
    const float* in_r,
    uint32_t in_stride,
    float* out_l,
    float* out_r,
    uint32_t out_stride,
    uint32_t frame_count
);

void timbre_dsp_process_planar_f32(
    timbre_dsp_engine_t* engine,
    const float* in_l,
    const float* in_r,
    float* out_l,
    float* out_r,
    uint32_t frame_count
);

// Non-RT thread: lock-free telemetry & spectrum snapshots.
timbre_dsp_metrics_t timbre_dsp_get_metrics(const timbre_dsp_engine_t* engine);
void timbre_dsp_copy_spectrum(const timbre_dsp_engine_t* engine, float* out_bins_db, uint32_t max_bins);

// Standalone helper for single-biquad analytical verification (E-06).
void timbre_dsp_compute_biquad(
    timbre_band_t band,
    double sample_rate,
    double out_b[3],
    double out_a[3]
);

#ifdef __cplusplus
}
#endif

#endif // TIMBRE_DSP_H
