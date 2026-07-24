%% projectVectorVision - TimeKernel v1
% Purpose:
%   Convert SSOT Zoom-In salience output into temporal phase, period,
%   dominant frequency, and executable time schedule.
%
% Input files expected in current folder:
%   projectVectorVision_zoomIn_*_summary.json
%   projectVectorVision_zoomIn_*_top_peaks.csv
%   projectVectorVision_zoomIn_*_highres_salience.csv
%
% Output:
%   projectVectorVision_timeKernel_*_phase_schedule.csv
%   projectVectorVision_timeKernel_*_frequency_report.csv
%   projectVectorVision_timeKernel_*_summary.json
%   projectVectorVision_timeKernel_*_workspace.mat
%
% This is a computational TimeKernel.
% It does not claim physical spacetime proof.
% It extracts temporal structure from verified SSOT-derived salience.

clc; clear; close all;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf(' projectVectorVision - TimeKernel v1\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% 0) CONFIG

cfg = struct();

cfg.workdir = '';  % keep empty if already inside /MATLAB Drive/modelTRAINING

cfg.expected_ssot_hash = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';

cfg.physical_duration_sec = 30.0;      % mapping window to executable time
cfg.sensor_rate_hz = 60.0;             % iPhone/iPad target sensor cadence
cfg.min_autocorr_lag = 25;             % ignore tiny lags
cfg.max_autocorr_lag = 8000;           % search period range in source samples
cfg.peak_salience_threshold = 0.92;    % high-res salience threshold
cfg.min_peak_distance = 250;           % samples
cfg.gaussian_width_samples = 80;       % for pulse train
cfg.make_plots = true;
cfg.save_outputs = true;

if ~isempty(cfg.workdir)
    cd(cfg.workdir);
end

fprintf('[1/8] Working directory:\n%s\n\n', pwd);

%% 1) FIND LATEST ZOOM-IN FILES

fprintf('[2/8] Finding latest Zoom-In files...\n');

summary_file = find_latest_file('projectVectorVision_zoomIn_*_summary.json');
peaks_file   = find_latest_file('projectVectorVision_zoomIn_*_top_peaks.csv');
highres_file = find_latest_file('projectVectorVision_zoomIn_*_highres_salience.csv');

fprintf('Summary file : %s\n', summary_file);
fprintf('Peaks file   : %s\n', peaks_file);
fprintf('Highres file : %s\n\n', highres_file);

assert(isfile(summary_file), 'Missing summary JSON.');
assert(isfile(peaks_file),   'Missing top peaks CSV.');
assert(isfile(highres_file), 'Missing high-res salience CSV.');

%% 2) LOAD SUMMARY AND VERIFY SSOT IDENTITY

fprintf('[3/8] Loading summary and verifying SSOT identity...\n');

summary_txt = fileread(summary_file);
zoom_summary = jsondecode(summary_txt);

if isfield(zoom_summary, 'ssot_sha256')
    fprintf('Zoom-In SSOT hash: %s\n', zoom_summary.ssot_sha256);
    assert(strcmpi(zoom_summary.ssot_sha256, cfg.expected_ssot_hash), ...
        'SSOT hash mismatch in Zoom-In summary. Stop.');
else
    error('summary JSON does not contain ssot_sha256.');
end

fprintf('SSOT identity verified from Zoom-In summary.\n\n');

%% 3) LOAD HIGH-RES SALIENCE + TOP PEAKS

fprintf('[4/8] Loading salience and peak tables...\n');

H = readtable(highres_file);
P = readtable(peaks_file);

required_H = {'source_sample','S_combined_norm'};
for k = 1:numel(required_H)
    assert(any(strcmp(H.Properties.VariableNames, required_H{k})), ...
        'Highres file missing column: %s', required_H{k});
end

required_P = {'original_sample','S_combined_norm'};
for k = 1:numel(required_P)
    assert(any(strcmp(P.Properties.VariableNames, required_P{k})), ...
        'Peaks file missing column: %s', required_P{k});
end

source_sample = double(H.source_sample(:));
S = double(H.S_combined_norm(:));
S(~isfinite(S)) = 0;
S = normalize_01(S);

fprintf('High-res rows: %d\n', numel(S));
fprintf('Top peaks    : %d\n\n', height(P));

%% 4) EXTRACT HIGH-RES PEAKS FROM FULL SIGNAL

fprintf('[5/8] Extracting dense high-res peaks...\n');

dense_peaks_idx = local_peaks_thresholded( ...
    S, ...
    cfg.peak_salience_threshold, ...
    cfg.min_peak_distance);

if numel(dense_peaks_idx) < 3
    fprintf('Warning: too few threshold peaks. Falling back to top_peaks.csv.\n');
    [~, loc] = ismember(double(P.original_sample(:)), source_sample);
    dense_peaks_idx = loc(loc > 0);
end

dense_peaks_idx = dense_peaks_idx(:);
dense_peak_samples = source_sample(dense_peaks_idx);
dense_peak_values = S(dense_peaks_idx);

[dense_peak_samples, ord] = sort(dense_peak_samples);
dense_peaks_idx = dense_peaks_idx(ord);
dense_peak_values = dense_peak_values(ord);

interval_samples = diff(dense_peak_samples);

fprintf('Dense peaks found: %d\n', numel(dense_peak_samples));
fprintf('First peak sample: %d\n', dense_peak_samples(1));
fprintf('Last peak sample : %d\n\n', dense_peak_samples(end));

%% 5) AUTOCORRELATION PERIOD EXTRACTION

fprintf('[6/8] Computing autocorrelation and dominant period...\n');

y = S(:);
y = y - mean(y);
y = y ./ (std(y) + eps);

% Autocorrelation using convolution, no toolbox dependency
acf_full = conv(y, flipud(y), 'full');
mid = ceil(numel(acf_full)/2);
acf = acf_full(mid:end);
acf = acf ./ max(abs(acf) + eps);

lags = (0:numel(acf)-1)';

max_lag = min(cfg.max_autocorr_lag, numel(acf)-1);
search_lags = (cfg.min_autocorr_lag:max_lag)';

[~, best_rel] = max(acf(search_lags + 1));
dominant_period_samples = search_lags(best_rel);

fprintf('Dominant autocorr period: %d samples\n', dominant_period_samples);

% Interval statistics from dense peaks
if ~isempty(interval_samples)
    median_interval = median(interval_samples);
    mean_interval = mean(interval_samples);
    std_interval = std(interval_samples);
else
    median_interval = NaN;
    mean_interval = NaN;
    std_interval = NaN;
end

fprintf('Median peak interval     : %.3f samples\n', median_interval);
fprintf('Mean peak interval       : %.3f samples\n', mean_interval);
fprintf('STD peak interval        : %.3f samples\n\n', std_interval);

%% 6) MAP SOURCE SAMPLE DOMAIN TO EXECUTABLE TIME

fprintf('[7/8] Building executable time schedule...\n');

sample_start = min(source_sample);
sample_end   = max(source_sample);
sample_span  = sample_end - sample_start;

sample_to_sec = cfg.physical_duration_sec / sample_span;

target_time_sec = (dense_peak_samples - sample_start) * sample_to_sec;

dominant_period_sec = dominant_period_samples * sample_to_sec;
dominant_frequency_hz = 1 / max(dominant_period_sec, eps);

median_interval_sec = median_interval * sample_to_sec;
median_frequency_hz = 1 / max(median_interval_sec, eps);

phase_rad = mod( ...
    2*pi * (dense_peak_samples - dense_peak_samples(1)) ./ max(dominant_period_samples, eps), ...
    2*pi);

cycle_id = floor((dense_peak_samples - dense_peak_samples(1)) ./ max(dominant_period_samples, eps));

next_interval_samples = [diff(dense_peak_samples); NaN];
next_interval_sec = next_interval_samples * sample_to_sec;

peak_order = (1:numel(dense_peak_samples))';

phase_schedule = table( ...
    peak_order, ...
    dense_peak_samples, ...
    target_time_sec, ...
    phase_rad, ...
    cycle_id, ...
    dense_peak_values, ...
    next_interval_samples, ...
    next_interval_sec, ...
    'VariableNames', { ...
    'peak_order', ...
    'source_sample', ...
    'target_time_sec', ...
    'phase_rad', ...
    'cycle_id', ...
    'salience_value', ...
    'next_interval_samples', ...
    'next_interval_sec'});

frequency_report = table( ...
    dominant_period_samples, ...
    dominant_period_sec, ...
    dominant_frequency_hz, ...
    median_interval, ...
    median_interval_sec, ...
    median_frequency_hz, ...
    mean_interval, ...
    std_interval, ...
    sample_start, ...
    sample_end, ...
    cfg.physical_duration_sec, ...
    cfg.sensor_rate_hz, ...
    'VariableNames', { ...
    'dominant_period_samples', ...
    'dominant_period_sec', ...
    'dominant_frequency_hz', ...
    'median_peak_interval_samples', ...
    'median_peak_interval_sec', ...
    'median_peak_frequency_hz', ...
    'mean_peak_interval_samples', ...
    'std_peak_interval_samples', ...
    'sample_start', ...
    'sample_end', ...
    'mapped_duration_sec', ...
    'sensor_rate_hz'});

disp(frequency_report);
fprintf('\nFirst 20 scheduled events:\n');
disp(phase_schedule(1:min(20,height(phase_schedule)), :));

%% 7) BUILD PULSE TRAIN FOR REPLAY

fprintf('[8/8] Building TimeKernel pulse train...\n');

N = numel(source_sample);
pulse_train = zeros(N,1);

for k = 1:numel(dense_peaks_idx)
    center = dense_peaks_idx(k);
    amp = dense_peak_values(k);

    left = max(1, center - 4*cfg.gaussian_width_samples);
    right = min(N, center + 4*cfg.gaussian_width_samples);
    idx = (left:right)';

    pulse_train(idx) = pulse_train(idx) + ...
        amp * exp(-0.5 * ((idx - center) ./ cfg.gaussian_width_samples).^2);
end

pulse_train = normalize_01(pulse_train);

% Synthetic executable time axis at requested sensor rate
exec_t = (0:1/cfg.sensor_rate_hz:cfg.physical_duration_sec)';
exec_signal = interp1( ...
    linspace(0, cfg.physical_duration_sec, N)', ...
    pulse_train, ...
    exec_t, ...
    'linear', ...
    0);

exec_signal = normalize_01(exec_signal);

%% 8) SAVE OUTPUTS

timestamp_tag = datestr(now, 'yyyymmdd_HHMMSS');
out_prefix = ['projectVectorVision_timeKernel_' timestamp_tag];

if cfg.save_outputs
    schedule_file = [out_prefix '_phase_schedule.csv'];
    freq_file     = [out_prefix '_frequency_report.csv'];
    replay_file   = [out_prefix '_replay_signal.csv'];
    json_file     = [out_prefix '_summary.json'];
    mat_file      = [out_prefix '_workspace.mat'];

    writetable(phase_schedule, schedule_file);
    writetable(frequency_report, freq_file);

    replay_table = table( ...
        exec_t, ...
        exec_signal, ...
        'VariableNames', {'time_sec','timekernel_signal'});
    writetable(replay_table, replay_file);

    tk_summary = struct();
    tk_summary.project = 'projectVectorVision';
    tk_summary.version = 'TimeKernel v1';
    tk_summary.model_type = 'Computational temporal phase/frequency extraction';
    tk_summary.runtime_timestamp = datestr(now, 30);
    tk_summary.source_zoom_summary = summary_file;
    tk_summary.source_top_peaks = peaks_file;
    tk_summary.source_highres_salience = highres_file;
    tk_summary.ssot_sha256 = zoom_summary.ssot_sha256;
    tk_summary.dataset_path = zoom_summary.dataset_path;
    tk_summary.highres_peak_original_sample = zoom_summary.highres_peak_original_sample;
    tk_summary.sample_start = sample_start;
    tk_summary.sample_end = sample_end;
    tk_summary.dense_peaks_found = numel(dense_peak_samples);
    tk_summary.dominant_period_samples = dominant_period_samples;
    tk_summary.dominant_period_sec = dominant_period_sec;
    tk_summary.dominant_frequency_hz = dominant_frequency_hz;
    tk_summary.median_peak_interval_samples = median_interval;
    tk_summary.median_peak_interval_sec = median_interval_sec;
    tk_summary.median_peak_frequency_hz = median_frequency_hz;
    tk_summary.mapped_duration_sec = cfg.physical_duration_sec;
    tk_summary.sensor_rate_hz = cfg.sensor_rate_hz;
    tk_summary.output_phase_schedule_csv = schedule_file;
    tk_summary.output_frequency_report_csv = freq_file;
    tk_summary.output_replay_signal_csv = replay_file;
    tk_summary.output_workspace_mat = mat_file;

    fid = fopen(json_file, 'w');
    fwrite(fid, jsonencode(tk_summary), 'char');
    fclose(fid);

    save(mat_file, ...
        'cfg', ...
        'zoom_summary', ...
        'H', 'P', ...
        'source_sample', 'S', ...
        'dense_peaks_idx', 'dense_peak_samples', 'dense_peak_values', ...
        'interval_samples', ...
        'acf', 'lags', ...
        'dominant_period_samples', ...
        'dominant_period_sec', ...
        'dominant_frequency_hz', ...
        'phase_schedule', ...
        'frequency_report', ...
        'pulse_train', ...
        'exec_t', ...
        'exec_signal', ...
        'tk_summary');

    fprintf('\nSaved:\n');
    fprintf('  %s\n', schedule_file);
    fprintf('  %s\n', freq_file);
    fprintf('  %s\n', replay_file);
    fprintf('  %s\n', json_file);
    fprintf('  %s\n', mat_file);
end

%% 9) PLOTS

if cfg.make_plots
    figure('Color','w','Position',[80 80 1350 850]);
    tiledlayout(4,1,'Padding','compact','TileSpacing','compact');

    nexttile;
    plot(source_sample, S, 'k', 'LineWidth', 1.1); hold on;
    scatter(dense_peak_samples, dense_peak_values, 18, 'filled');
    grid on;
    title('TimeKernel Source Salience + Extracted Peaks');
    xlabel('source sample');
    ylabel('S combined');

    nexttile;
    plot(lags(1:max_lag), acf(1:max_lag), 'LineWidth', 1.2); hold on;
    xline(dominant_period_samples, '--k', 'dominant period');
    grid on;
    title('Autocorrelation Period Search');
    xlabel('lag samples');
    ylabel('autocorrelation');

    nexttile;
    stem(interval_samples, 'filled');
    grid on;
    title('Peak-to-Peak Intervals');
    xlabel('peak interval index');
    ylabel('Δ samples');

    nexttile;
    plot(exec_t, exec_signal, 'LineWidth', 1.3);
    grid on;
    title('Executable TimeKernel Replay Signal');
    xlabel('time seconds');
    ylabel('normalized pulse');
end

fprintf('\nTimeKernel complete.\n');
fprintf('Dominant period: %d source samples\n', dominant_period_samples);
fprintf('Mapped period  : %.6f seconds\n', dominant_period_sec);
fprintf('Frequency      : %.6f Hz\n', dominant_frequency_hz);
fprintf('\nGenerated executable schedule and replay signal.\n');

%% ========================= LOCAL FUNCTIONS ==============================

function file = find_latest_file(pattern)
    d = dir(pattern);

    if isempty(d)
        error('No file found for pattern: %s', pattern);
    end

    [~, idx] = max([d.datenum]);
    file = d(idx).name;
end

function y = normalize_01(x)
    x = double(x);
    x(~isfinite(x)) = 0;

    mn = min(x(:));
    mx = max(x(:));

    if abs(mx - mn) < eps
        y = zeros(size(x));
    else
        y = (x - mn) ./ (mx - mn);
    end
end

function idx = local_peaks_thresholded(S, threshold, minDist)
    S = double(S(:));
    N = numel(S);

    raw = find(S(2:N-1) > S(1:N-2) & S(2:N-1) >= S(3:N)) + 1;
    raw = raw(S(raw) >= threshold);

    if isempty(raw)
        idx = [];
        return;
    end

    [~, order] = sort(S(raw), 'descend');
    raw = raw(order);

    selected = [];

    for k = 1:numel(raw)
        candidate = raw(k);

        if isempty(selected) || all(abs(candidate - selected) >= minDist)
            selected(end+1) = candidate; %#ok<AGROW>
        end
    end

    selected = sort(selected(:));
    idx = selected;
end