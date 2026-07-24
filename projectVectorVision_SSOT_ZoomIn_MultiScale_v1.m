%% projectVectorVision - SSOT Zoom-In MultiScale Salience v1
% High-resolution zoom-in analysis from verified SSOT only.
%
% Input:
%   jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%
% Target dataset:
%   /n_5_composite_field_1000x1000/data
%
% Purpose:
%   Re-read the peak salience region at higher resolution,
%   compute projection + temporal + acceleration + multiscale EMA salience,
%   and export candidate physical windows for later iPad/iPhone sensor testing.
%
% Version:
%   A = computational-temporal model.
%   Not a physical spacetime proof.

clc; clear; close all;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf(' projectVectorVision - SSOT Zoom-In MultiScale Salience v1\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% 0) CONFIG

cfg = struct();

% Run from /MATLAB Drive/modelTRAINING
cfg.workdir = '';

cfg.ssot_file = 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
cfg.expected_sha256 = '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';

cfg.dataset_path = '/n_5_composite_field_1000x1000/data';

% Known from previous verified run
cfg.total_original_samples = 1000000;
cfg.feature_dim = 5;
cfg.previous_downsample_T = 2000;

cfg.previous_peak_index = 1572;
cfg.previous_salience_window_downsample = [1552 1591];

% Add padding around the detected window for stronger local context
cfg.pad_original_samples = 10000;

% Salience weights
cfg.alpha = 0.35;   % projection alignment
cfg.beta  = 0.25;   % speed / temporal change
cfg.delta = 0.25;   % multiscale dynamics
cfg.gamma = 0.15;   % EMA feedback memory

cfg.lambda = 0.88;  % EMA memory factor
cfg.eps = 1e-9;

% Multi-scale windows in samples
cfg.ms_windows = [5 25 101 501];

% Peak extraction
cfg.top_k_peaks = 12;
cfg.min_peak_distance = 250;

cfg.save_outputs = true;
cfg.make_plots = true;

%% 1) WORKDIR

if ~isempty(cfg.workdir)
    cd(cfg.workdir);
end

fprintf('[1/9] Working directory:\n%s\n\n', pwd);

assert(isfile(cfg.ssot_file), 'SSOT file not found: %s', cfg.ssot_file);

%% 2) HASH CHECK

fprintf('[2/9] Verifying SSOT SHA-256...\n');

actual_hash = compute_sha256(cfg.ssot_file);

fprintf('Expected: %s\n', cfg.expected_sha256);
fprintf('Actual  : %s\n', actual_hash);

assert(strcmpi(actual_hash, cfg.expected_sha256), ...
    'HASH MISMATCH. Stop. Do not continue.');

fprintf('HASH MATCH — SSOT verified.\n\n');

%% 3) MAP DOWNSAMPLED WINDOW BACK TO ORIGINAL SAMPLE SPACE

fprintf('[3/9] Mapping previous salience window to original samples...\n');

source_idx = round(linspace(1, cfg.total_original_samples, cfg.previous_downsample_T));

core_start = source_idx(cfg.previous_salience_window_downsample(1));
core_end   = source_idx(cfg.previous_salience_window_downsample(2));
peak_orig  = source_idx(cfg.previous_peak_index);

read_start = max(1, core_start - cfg.pad_original_samples);
read_end   = min(cfg.total_original_samples, core_end + cfg.pad_original_samples);
read_count = read_end - read_start + 1;

fprintf('Previous peak index        : %d\n', cfg.previous_peak_index);
fprintf('Mapped original peak sample: %d\n', peak_orig);
fprintf('Core original window       : %d → %d\n', core_start, core_end);
fprintf('Padded read window         : %d → %d\n', read_start, read_end);
fprintf('Read count                 : %d samples\n\n', read_count);

%% 4) READ HIGH-RES CHUNK FROM H5

fprintf('[4/9] Reading high-resolution H5 chunk...\n');

% Dataset shape is expected as [5 x 1000000].
raw_chunk = h5read( ...
    cfg.ssot_file, ...
    cfg.dataset_path, ...
    [1, read_start], ...
    [cfg.feature_dim, read_count]);

M = double(raw_chunk)';   % rows=time, cols=features
M(~isfinite(M)) = 0;

T = size(M, 1);
F = size(M, 2);

source_sample = (read_start:read_end)';

fprintf('Temporal matrix size: %d x %d\n\n', T, F);

%% 5) BUILD HIGH-RES TEMPORAL FEATURES

fprintf('[5/9] Building temporal state vectors...\n');

% Computational time
t_step = (0:T-1)';
t_clock = t_step;
dt = [1; diff(t_clock)];

% Normalized original sample coordinate
tau = normalize_01(source_sample);

% Normalize raw features
Z = zscore_safe(M);

% First derivative: feature velocity
dZ = zeros(T, F);
for i = 2:T
    dZ(i,:) = (Z(i,:) - Z(i-1,:)) ./ max(dt(i), cfg.eps);
end

speed = sqrt(sum(dZ.^2, 2));

% Second derivative: acceleration of feature motion
accel = zeros(T, 1);
for i = 2:T
    accel(i) = (speed(i) - speed(i-1)) ./ max(dt(i), cfg.eps);
end

% Third derivative: jerk
jerk = zeros(T, 1);
for i = 2:T
    jerk(i) = (accel(i) - accel(i-1)) ./ max(dt(i), cfg.eps);
end

% Multi-scale moving RMS of speed and acceleration
MS = [];
ms_names = {};

for w = cfg.ms_windows
    speed_rms = moving_rms(speed, w);
    accel_rms = moving_rms(abs(accel), w);

    MS = [MS, normalize_01(speed_rms), normalize_01(accel_rms)]; %#ok<AGROW>
    ms_names{end+1} = sprintf('speed_rms_%d', w); %#ok<AGROW>
    ms_names{end+1} = sprintf('accel_rms_%d', w); %#ok<AGROW>
end

% Main state vector:
% [time coordinate, normalized H5 features, speed, acceleration, jerk, multiscale features]
V = [ ...
    tau, ...
    Z, ...
    normalize_01(speed), ...
    normalize_01(abs(accel)), ...
    normalize_01(abs(jerk)), ...
    MS];

fprintf('State vector V size: %d x %d\n\n', size(V,1), size(V,2));

%% 6) DEFINE TARGET VECTOR u FROM PREVIOUS PEAK LOCATION

fprintf('[6/9] Defining local target vector u from peak region...\n');

peak_local = peak_orig - read_start + 1;
peak_local = max(1, min(T, peak_local));

target_radius = 50;
a = max(1, peak_local - target_radius);
b = min(T, peak_local + target_radius);

u = mean(V(a:b, :), 1);

if norm(u) < cfg.eps
    u = mean(V, 1);
end

if norm(u) < cfg.eps
    u = zeros(1, size(V,2));
    u(1) = 1;
end

u = u ./ (norm(u) + cfg.eps);

fprintf('Peak local index: %d\n', peak_local);
fprintf('Target region   : %d → %d local samples\n\n', a, b);

%% 7) COMPUTE MULTISCALE SALIENCE

fprintf('[7/9] Computing high-resolution salience...\n');

S_projection_raw = abs((V * u') ./ (dot(u, u) + cfg.eps));
S_projection = normalize_01(S_projection_raw);

S_speed = normalize_01(speed);
S_accel = normalize_01(abs(accel));
S_jerk  = normalize_01(abs(jerk));

S_temporal = normalize_01( ...
    0.50 * S_speed + ...
    0.35 * S_accel + ...
    0.15 * S_jerk);

S_multiscale = normalize_01(mean(MS, 2));

S_combined_raw = zeros(T, 1);
S_memory_raw = zeros(T, 1);

S_star = 0;

for i = 1:T
    S_i = ...
        cfg.alpha * S_projection(i) + ...
        cfg.beta  * S_temporal(i) + ...
        cfg.delta * S_multiscale(i) + ...
        cfg.gamma * S_star;

    S_combined_raw(i) = S_i;

    S_star = cfg.lambda * S_star + (1 - cfg.lambda) * S_i;
    S_memory_raw(i) = S_star;
end

S_combined = normalize_01(S_combined_raw);
S_memory = normalize_01(S_memory_raw);

[peak_value, peak_i] = max(S_combined);
peak_source_sample = source_sample(peak_i);

fprintf('High-res peak local index     : %d\n', peak_i);
fprintf('High-res peak original sample : %d\n', peak_source_sample);
fprintf('High-res peak value           : %.6f\n\n', peak_value);

%% 8) EXTRACT TOP LOCAL PEAKS

fprintf('[8/9] Extracting top local candidate peaks...\n');

peaks_table = top_local_peaks( ...
    S_combined, ...
    source_sample, ...
    cfg.top_k_peaks, ...
    cfg.min_peak_distance);

disp(peaks_table);

%% 9) SAVE OUTPUTS

fprintf('[9/9] Saving outputs...\n');

timestamp_tag = datestr(now, 'yyyymmdd_HHMMSS');
out_prefix = ['projectVectorVision_zoomIn_' timestamp_tag];

results = table( ...
    source_sample, ...
    t_step, ...
    tau, ...
    speed, ...
    accel, ...
    jerk, ...
    S_projection, ...
    S_temporal, ...
    S_multiscale, ...
    S_memory, ...
    S_combined, ...
    'VariableNames', { ...
    'source_sample', ...
    't_step', ...
    'tau', ...
    'speed', ...
    'accel', ...
    'jerk', ...
    'S_projection_norm', ...
    'S_temporal_norm', ...
    'S_multiscale_norm', ...
    'S_memory_norm', ...
    'S_combined_norm'});

if cfg.save_outputs
    csv_file = [out_prefix '_highres_salience.csv'];
    peaks_file = [out_prefix '_top_peaks.csv'];
    json_file = [out_prefix '_summary.json'];
    mat_file = [out_prefix '_workspace.mat'];

    writetable(results, csv_file);
    writetable(peaks_table, peaks_file);

    summary = struct();
    summary.project = 'projectVectorVision';
    summary.version = 'SSOT Zoom-In MultiScale Salience v1';
    summary.model_type = 'Version A computational-temporal';
    summary.runtime_timestamp = datestr(now, 30);
    summary.working_directory = pwd;
    summary.ssot_file = cfg.ssot_file;
    summary.ssot_sha256 = actual_hash;
    summary.dataset_path = cfg.dataset_path;

    summary.previous_downsample_peak_index = cfg.previous_peak_index;
    summary.previous_window_downsample = cfg.previous_salience_window_downsample;

    summary.core_original_window = [core_start, core_end];
    summary.padded_read_window = [read_start, read_end];
    summary.read_count = read_count;

    summary.highres_peak_local_index = peak_i;
    summary.highres_peak_original_sample = peak_source_sample;
    summary.highres_peak_value = peak_value;

    summary.alpha = cfg.alpha;
    summary.beta = cfg.beta;
    summary.delta = cfg.delta;
    summary.gamma = cfg.gamma;
    summary.lambda = cfg.lambda;
    summary.ms_windows = cfg.ms_windows;

    summary.output_csv = csv_file;
    summary.output_peaks_csv = peaks_file;
    summary.output_mat = mat_file;

    txt = jsonencode(summary);

    fid = fopen(json_file, 'w');
    fwrite(fid, txt, 'char');
    fclose(fid);

    save(mat_file, ...
        'cfg', ...
        'M', 'Z', 'V', 'u', ...
        'source_sample', 't_step', 'tau', ...
        'speed', 'accel', 'jerk', ...
        'S_projection', 'S_temporal', 'S_multiscale', 'S_memory', 'S_combined', ...
        'peaks_table', 'results', 'summary');

    fprintf('Saved:\n');
    fprintf('  %s\n', csv_file);
    fprintf('  %s\n', peaks_file);
    fprintf('  %s\n', json_file);
    fprintf('  %s\n', mat_file);
end

%% 10) PLOTS

if cfg.make_plots
    figure('Color', 'w', 'Position', [80 80 1300 850]);
    tiledlayout(4,1, 'Padding','compact', 'TileSpacing','compact');

    nexttile;
    plot(source_sample, S_projection, 'LineWidth', 1.1); hold on;
    plot(source_sample, S_temporal, 'LineWidth', 1.1);
    plot(source_sample, S_multiscale, 'LineWidth', 1.1);
    plot(source_sample, S_memory, 'LineWidth', 1.3);
    plot(source_sample, S_combined, 'k', 'LineWidth', 1.8);
    xline(peak_source_sample, '--k', 'Peak');
    grid on;
    title('High-Resolution Zoom-In Salience');
    xlabel('Original sample index');
    ylabel('normalized');
    legend({'Projection','Temporal','MultiScale','Memory','Combined'}, 'Location','best');

    nexttile;
    plot(source_sample, speed, 'LineWidth', 1.2); hold on;
    xline(peak_source_sample, '--k', 'Peak');
    grid on;
    title('Feature-Space Speed');
    xlabel('Original sample index');
    ylabel('speed');

    nexttile;
    plot(source_sample, accel, 'LineWidth', 1.2); hold on;
    xline(peak_source_sample, '--k', 'Peak');
    grid on;
    title('Feature-Space Acceleration');
    xlabel('Original sample index');
    ylabel('accel');

    nexttile;
    cols = min(5, size(Z,2));
    plot(source_sample, Z(:,1:cols), 'LineWidth', 1.0); hold on;
    xline(peak_source_sample, '--k', 'Peak');
    grid on;
    title('Normalized Source Features');
    xlabel('Original sample index');
    ylabel('z-score');
    legend(compose('Z_%d', 1:cols), 'Location','best');
end

fprintf('\nDone.\n');
fprintf('High-res peak original sample: %d\n', peak_source_sample);
fprintf('Peak value: %.6f\n', peak_value);
fprintf('\nNext physical schema, later:\n');
fprintf('timestamp_mono_sec,x,y,z,confidence,device,session_id\n');

%% ========================= LOCAL FUNCTIONS ==============================

function hash = compute_sha256(file)
    [status, out] = system(sprintf('sha256sum "%s"', file));

    if status ~= 0
        [status, out] = system(sprintf('shasum -a 256 "%s"', file));
    end

    if status ~= 0
        error('Unable to compute SHA-256.');
    end

    token = regexp(lower(out), '^[0-9a-f]{64}', 'match', 'once');

    if isempty(token)
        error('Could not parse SHA-256 output.');
    end

    hash = token;
end

function Y = normalize_01(X)
    X = double(X);
    X(~isfinite(X)) = 0;

    xmin = min(X(:));
    xmax = max(X(:));

    if abs(xmax - xmin) < eps
        Y = zeros(size(X));
    else
        Y = (X - xmin) ./ (xmax - xmin);
    end
end

function Z = zscore_safe(M)
    M = double(M);
    M(~isfinite(M)) = 0;

    mu = mean(M, 1, 'omitnan');
    sigma = std(M, 0, 1, 'omitnan');

    sigma(sigma < eps) = 1;

    Z = (M - mu) ./ sigma;
    Z(~isfinite(Z)) = 0;
end

function y = moving_rms(x, w)
    x = double(x(:));
    w = max(1, round(w));

    kernel = ones(w, 1) ./ w;
    y = sqrt(conv(x.^2, kernel, 'same'));
    y(~isfinite(y)) = 0;
end

function tbl = top_local_peaks(S, source_sample, topK, minDist)
    S = double(S(:));
    source_sample = source_sample(:);

    if numel(S) < 3
        tbl = table();
        return;
    end

    candidates = find(S(2:end-1) > S(1:end-2) & S(2:end-1) >= S(3:end)) + 1;

    if isempty(candidates)
        [~, idx] = max(S);
        candidates = idx;
    end

    [~, order] = sort(S(candidates), 'descend');
    candidates = candidates(order);

    selected = [];

    for k = 1:numel(candidates)
        c = candidates(k);

        if isempty(selected) || all(abs(c - selected) >= minDist)
            selected(end+1) = c; %#ok<AGROW>
        end

        if numel(selected) >= topK
            break;
        end
    end

    selected = selected(:);

    local_index = selected;
    original_sample = source_sample(selected);
    salience_value = S(selected);

    left_bound = max(1, selected - minDist);
    right_bound = min(numel(S), selected + minDist);

    original_left = source_sample(left_bound);
    original_right = source_sample(right_bound);

    tbl = table( ...
        local_index, ...
        original_sample, ...
        salience_value, ...
        original_left, ...
        original_right, ...
        'VariableNames', { ...
        'local_index', ...
        'original_sample', ...
        'S_combined_norm', ...
        'candidate_window_start', ...
        'candidate_window_end'});
end