%% projectVectorVision - SSOT Temporal Salience Engine (Version A)
% Runs ONLY from the verified Source of Truth (SSOT)
% Working folder: drive/modelTRAINING
%
% Outputs:
%   - *_salience_results.csv
%   - *_summary.json
%   - *_workspace.mat
%
% Notes:
%   - This is Version A (computational-temporal model)
%   - No hard claim of physical spacetime inference
%   - If auto-selected dataset is not ideal, set cfg.dataset_path manually

clc; clear; close all;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf(' projectVectorVision - SSOT Temporal Salience Engine v1.0\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% 0) CONFIG
cfg = struct();

% Working directory
cfg.workdir = '';   % set '' if already inside the folder

% Canonical files
cfg.ssot_file = 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
cfg.expected_sha256 = '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';

cfg.aux_files = { ...
    'calibration_set_v1.md', ...
    'matlab_h5_clean_facts.json', ...
    'matlab_h5_inventory.csv', ...
    'matlab_h5_training_clean.jsonl', ...
    'matlab_h5_training_clean.md'};

% Dataset selection
cfg.dataset_path = '';      % leave empty for auto-selection
cfg.max_elements_read = 5e6;
cfg.max_time_points = 2000; % downsample in time if larger

% Salience weights
cfg.alpha = 0.45;   % projection weight
cfg.beta  = 0.35;   % temporal-change weight
cfg.gamma = 0.20;   % feedback-memory contribution
cfg.lambda = 0.85;  % EMA memory factor
cfg.eps = 1e-9;

% Output
cfg.make_plots = true;
cfg.save_outputs = true;

%% 1) MOVE TO WORKDIR
if ~isempty(cfg.workdir)
    if isfolder(cfg.workdir)
        cd(cfg.workdir);
    else
        error('Working folder not found: %s', cfg.workdir);
    end
end

fprintf('[0/8] Working directory:\n%s\n\n', pwd);

%% 2) CHECK REQUIRED FILES
fprintf('[1/8] Checking required files...\n');

assert(isfile(cfg.ssot_file), 'SSOT file not found: %s', cfg.ssot_file);

missing_aux = {};
for k = 1:numel(cfg.aux_files)
    if ~isfile(cfg.aux_files{k})
        missing_aux{end+1} = cfg.aux_files{k}; %#ok<AGROW>
    end
end

if isempty(missing_aux)
    fprintf('  All auxiliary files found.\n');
else
    fprintf('  Warning: Some auxiliary files are missing:\n');
    for k = 1:numel(missing_aux)
        fprintf('    - %s\n', missing_aux{k});
    end
end
fprintf('\n');

%% 3) VERIFY HASH
fprintf('[2/8] Verifying SHA-256 of SSOT...\n');
actual_hash = compute_sha256(cfg.ssot_file);
fprintf('  Expected: %s\n', cfg.expected_sha256);
fprintf('  Actual  : %s\n', actual_hash);

assert(strcmpi(actual_hash, cfg.expected_sha256), ...
    'SHA-256 mismatch. Stop here.');

fprintf('  HASH MATCH — SSOT verified.\n\n');

%% 4) INSPECT H5 STRUCTURE
fprintf('[3/8] Inspecting H5 structure...\n');

info = h5info(cfg.ssot_file);
datasets = collect_h5_datasets(info, '');

if isempty(datasets)
    error('No datasets found in H5.');
end

ds_table = struct2table(datasets);
ds_table = sortrows(ds_table, 'NumElements', 'descend');

fprintf('  Found %d datasets.\n', height(ds_table));
disp(ds_table(:, {'Path','DatatypeClass','DimsStr','NumElements'}));

%% 5) SELECT DATASET
fprintf('[4/8] Selecting numeric dataset...\n');

if isempty(cfg.dataset_path)
    selected = auto_select_dataset(cfg.ssot_file, datasets, cfg.max_elements_read);
    if isempty(selected)
        error(['Auto-selection failed. Please set cfg.dataset_path manually ', ...
               'to a numeric dataset path inside the H5.']);
    end
    cfg.dataset_path = selected.Path;
    fprintf('  Auto-selected dataset: %s\n', cfg.dataset_path);
else
    fprintf('  Using manual dataset: %s\n', cfg.dataset_path);
end
fprintf('\n');

%% 6) READ DATASET
fprintf('[5/8] Reading selected dataset...\n');

raw = h5read(cfg.ssot_file, cfg.dataset_path);

if ~isnumeric(raw) && ~islogical(raw)
    error('Selected dataset is not numeric/logical: %s', cfg.dataset_path);
end

raw = double(raw);

[M, meta_tm] = to_temporal_matrix(raw, cfg.max_time_points);

fprintf('  Temporal matrix created.\n');
fprintf('  Rows (time steps): %d\n', size(M,1));
fprintf('  Cols (features)  : %d\n', size(M,2));
fprintf('  Orientation      : %s\n\n', meta_tm.orientation);

%% 7) BUILD TEMPORAL STATE (VERSION A)
fprintf('[6/8] Computing temporal salience...\n');

T = size(M,1);
F = size(M,2);

% Step index / normalized time
t_step = (0:T-1)';
t_clock = t_step;                  % Version A default: step-based time
dt = [1; diff(t_clock)];
tau = normalize_01(t_step);

% Clean and normalize feature matrix
M = fillmissing(M, 'constant', 0);
Z = zscore_safe(M);                % T x F

% Temporal derivatives
dZ = zeros(T, F);
for i = 2:T
    dZ(i,:) = (Z(i,:) - Z(i-1,:)) ./ max(dt(i), cfg.eps);
end

speed = sqrt(sum(dZ.^2, 2));

% Build state vector V_i = [tau, Z_i, dt, speed]
V = [tau, Z, dt, speed];

% Target vector u (Version A heuristic): mean state direction
u = mean(V, 1);
u_norm = norm(u);
if u_norm < cfg.eps
    u = zeros(1, size(V,2));
    u(1) = 1;
else
    u = u / u_norm;
end

% Raw salience components
S_projection_raw = zeros(T,1);
S_temporal_raw   = speed;
S_combined_raw   = zeros(T,1);
S_memory_raw     = zeros(T,1);

S_star = 0;

for i = 1:T
    v_i = V(i,:);
    
    % A) Projection salience
    a_i = dot(v_i, u) / (dot(u, u) + cfg.eps);
    S_projection_raw(i) = abs(a_i);
end

% Normalize components before combining
S_projection = normalize_01(S_projection_raw);
S_temporal   = normalize_01(S_temporal_raw);

% Combine with EMA memory loop
for i = 1:T
    S_i = cfg.alpha * S_projection(i) + ...
          cfg.beta  * S_temporal(i)   + ...
          cfg.gamma * S_star;

    S_combined_raw(i) = S_i;

    S_star = cfg.lambda * S_star + (1 - cfg.lambda) * S_i;
    S_memory_raw(i) = S_star;
end

S_combined = normalize_01(S_combined_raw);
S_memory   = normalize_01(S_memory_raw);

% Summary metrics
[peak_salience, peak_idx] = max(S_combined);
mean_salience = mean(S_combined);
mean_speed = mean(speed);

fprintf('  Peak salience index : %d\n', peak_idx);
fprintf('  Peak salience value : %.6f\n', peak_salience);
fprintf('  Mean salience       : %.6f\n', mean_salience);
fprintf('  Mean speed          : %.6f\n\n', mean_speed);

%% 8) SAVE RESULTS
fprintf('[7/8] Saving outputs...\n');

timestamp_tag = datestr(now, 'yyyymmdd_HHMMSS');
out_prefix = ['projectVectorVision_run_' timestamp_tag];

results = table( ...
    (1:T)', ...
    t_step, ...
    t_clock, ...
    tau, ...
    dt, ...
    speed, ...
    S_projection_raw, ...
    S_projection, ...
    S_temporal_raw, ...
    S_temporal, ...
    S_combined_raw, ...
    S_combined, ...
    S_memory_raw, ...
    S_memory, ...
    'VariableNames', { ...
    'index', ...
    't_step', ...
    't_clock', ...
    'tau', ...
    'dt', ...
    'speed', ...
    'S_projection_raw', ...
    'S_projection_norm', ...
    'S_temporal_raw', ...
    'S_temporal_norm', ...
    'S_combined_raw', ...
    'S_combined_norm', ...
    'S_memory_raw', ...
    'S_memory_norm'});

if cfg.save_outputs
    csv_file = [out_prefix '_salience_results.csv'];
    mat_file = [out_prefix '_workspace.mat'];
    json_file = [out_prefix '_summary.json'];

    writetable(results, csv_file);

    summary = struct();
    summary.project = 'projectVectorVision';
    summary.version = 'Version A - SSOT Temporal Salience Engine';
    summary.runtime_timestamp = datestr(now, 30);
    summary.working_directory = pwd;
    summary.ssot_file = cfg.ssot_file;
    summary.ssot_sha256 = actual_hash;
    summary.dataset_path = cfg.dataset_path;
    summary.dataset_dims = size(raw);
    summary.temporal_matrix_size = size(M);
    summary.temporal_matrix_orientation = meta_tm.orientation;
    summary.num_time_steps = T;
    summary.num_features = F;
    summary.alpha = cfg.alpha;
    summary.beta = cfg.beta;
    summary.gamma = cfg.gamma;
    summary.lambda = cfg.lambda;
    summary.peak_salience_index = peak_idx;
    summary.peak_salience_value = peak_salience;
    summary.mean_salience = mean_salience;
    summary.mean_speed = mean_speed;
    summary.aux_files_present = setdiff(cfg.aux_files, missing_aux);
    summary.aux_files_missing = missing_aux;

    json_text = jsonencode(summary);
    fid = fopen(json_file, 'w');
    fwrite(fid, json_text, 'char');
    fclose(fid);

    save(mat_file, ...
        'cfg', 'info', 'datasets', 'ds_table', ...
        'raw', 'M', 'meta_tm', ...
        'V', 'u', ...
        't_step', 't_clock', 'dt', 'tau', ...
        'speed', ...
        'S_projection_raw', 'S_projection', ...
        'S_temporal_raw', 'S_temporal', ...
        'S_combined_raw', 'S_combined', ...
        'S_memory_raw', 'S_memory', ...
        'results', 'summary');

    fprintf('  Saved:\n');
    fprintf('    - %s\n', csv_file);
    fprintf('    - %s\n', json_file);
    fprintf('    - %s\n', mat_file);
end
fprintf('\n');

%% 9) PLOTS
fprintf('[8/8] Rendering plots...\n');

if cfg.make_plots
    figure('Color', 'w', 'Position', [100 100 1200 760]);

    tiledlayout(3,1, 'Padding','compact', 'TileSpacing','compact');

    % Plot 1: salience curves
    nexttile;
    plot(t_step, S_projection, 'LineWidth', 1.2); hold on;
    plot(t_step, S_temporal,   'LineWidth', 1.2);
    plot(t_step, S_memory,     'LineWidth', 1.4);
    plot(t_step, S_combined,   'k', 'LineWidth', 1.8);
    grid on;
    xlabel('t step');
    ylabel('normalized value');
    title('Salience Components');
    legend({'Projection','Temporal','Memory (EMA)','Combined'}, 'Location','best');

    % Plot 2: speed
    nexttile;
    plot(t_step, speed, 'LineWidth', 1.3);
    grid on;
    xlabel('t step');
    ylabel('speed');
    title('Temporal Change / Speed');

    % Plot 3: first 3 normalized features or first feature
    nexttile;
    cols_to_show = min(3, size(Z,2));
    plot(t_step, Z(:,1:cols_to_show), 'LineWidth', 1.1);
    grid on;
    xlabel('t step');
    ylabel('z-scored feature');
    title('First Normalized Features');
    legend(compose('Z_%d', 1:cols_to_show), 'Location','best');
end

fprintf('\nDone.\n');
fprintf('Selected dataset: %s\n', cfg.dataset_path);
fprintf('Peak salience at index %d with value %.6f\n', peak_idx, peak_salience);

%% ========================= LOCAL FUNCTIONS ==============================

function hash = compute_sha256(file)
    cmd1 = sprintf('sha256sum "%s"', file);
    [status, out] = system(cmd1);

    if status ~= 0
        cmd2 = sprintf('shasum -a 256 "%s"', file);
        [status, out] = system(cmd2);
    end

    if status ~= 0
        error('Unable to compute SHA-256 using system tools.');
    end

    token = regexp(lower(out), '^[0-9a-f]{64}', 'match', 'once');
    if isempty(token)
        error('Could not parse SHA-256 output.');
    end
    hash = token;
end

function datasets = collect_h5_datasets(groupInfo, prefix)
    if nargin < 2
        prefix = '';
    end

    datasets = struct('Path', {}, 'DatatypeClass', {}, 'Dims', {}, 'DimsStr', {}, 'NumElements', {});

    % Datasets in current group
    for i = 1:numel(groupInfo.Datasets)
        ds = groupInfo.Datasets(i);

        if isempty(prefix)
            dsPath = ['/' ds.Name];
        else
            dsPath = [prefix '/' ds.Name];
        end

        dims = ds.Dataspace.Size;
        if isempty(dims)
            dims = 1;
        end

        entry.Path = dsPath;
        entry.DatatypeClass = ds.Datatype.Class;
        entry.Dims = dims;
        entry.DimsStr = mat2str(dims);
        entry.NumElements = prod(double(dims));

        datasets(end+1) = entry; %#ok<AGROW>
    end

    % Recurse into subgroups
    for j = 1:numel(groupInfo.Groups)
        sub = groupInfo.Groups(j);
        subPrefix = sub.Name; % already full path in HDF5
        subDatasets = collect_h5_datasets(sub, subPrefix);
        if ~isempty(subDatasets)
            datasets = [datasets, subDatasets]; %#ok<AGROW>
        end
    end
end

function selected = auto_select_dataset(h5file, datasets, maxElems)
    selected = [];
    if isempty(datasets)
        return;
    end

    % Prefer numeric datasets with reasonable size, more than 1 element
    candidateIdx = [];
    for i = 1:numel(datasets)
        cls = lower(string(datasets(i).DatatypeClass));
        n = datasets(i).NumElements;
        dims = datasets(i).Dims;

        isNumericType = any(strcmp(cls, ...
            ["h5t_float","h5t_integer","h5t_bitfield","h5t_enum"])) || ...
            contains(cls, "float") || contains(cls, "integer");

        if isNumericType && n > 1 && n <= maxElems && all(dims > 0)
            candidateIdx(end+1) = i; %#ok<AGROW>
        end
    end

    if isempty(candidateIdx)
        return;
    end

    % Sort by size descending
    sizes = arrayfun(@(x) datasets(x).NumElements, candidateIdx);
    [~, order] = sort(sizes, 'descend');
    candidateIdx = candidateIdx(order);

    % Try reading until one works and yields usable matrix
    for k = 1:numel(candidateIdx)
        i = candidateIdx(k);
        try
            raw = h5read(h5file, datasets(i).Path);
            if isnumeric(raw) || islogical(raw)
                raw = double(raw);
                A = squeeze(raw);
                if numel(A) > 1
                    selected = datasets(i);
                    return;
                end
            end
        catch
            % keep trying
        end
    end
end

function [M, meta] = to_temporal_matrix(raw, maxTimePoints)
    A = squeeze(raw);
    meta = struct();

    if isvector(A)
        M = A(:);
        meta.orientation = 'vector -> column (time x 1)';

    elseif ismatrix(A)
        [r, c] = size(A);

        % Heuristic: time should be the longer axis
        if r >= c
            M = A;
            meta.orientation = '2D matrix kept as rows=time';
        else
            M = A';
            meta.orientation = '2D matrix transposed so rows=time';
        end

    else
        sz = size(A);

        % Heuristic: largest dimension = time
        [~, tDim] = max(sz);

        perm = [tDim, setdiff(1:ndims(A), tDim, 'stable')];
        Aperm = permute(A, perm);

        M = reshape(Aperm, sz(tDim), []);
        meta.orientation = sprintf('N-D array flattened with dim %d as time', tDim);
    end

    M = double(M);
    M(~isfinite(M)) = 0;

    % Downsample time dimension if too large
    T = size(M,1);
    if T > maxTimePoints
        idx = round(linspace(1, T, maxTimePoints));
        M = M(idx,:);
        meta.orientation = [meta.orientation, ' | downsampled in time'];
    end
end

function Y = normalize_01(X)
    xmin = min(X(:));
    xmax = max(X(:));
    if abs(xmax - xmin) < eps
        Y = zeros(size(X));
    else
        Y = (X - xmin) ./ (xmax - xmin);
    end
end

function Z = zscore_safe(M)
    mu = mean(M, 1, 'omitnan');
    sigma = std(M, 0, 1, 'omitnan');
    sigma(sigma < eps) = 1;
    Z = (M - mu) ./ sigma;
    Z(~isfinite(Z)) = 0;
end