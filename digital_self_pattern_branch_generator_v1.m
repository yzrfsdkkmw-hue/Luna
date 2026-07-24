%% digital_self_pattern_branch_generator_v1_FINAL
% H5 SSOT -> Pattern Field -> Probability Branch Folders -> Frames
%
% Source of truth:
% /MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5

clear; clc; close all;

%% =========================
%  0. FIXED PATHS
% ==========================

PROJECT_NAME = 'digital_self_pattern_branch_generator_v1_FINAL';

H5_FILE = 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
H5_PATH = fullfile('/MATLAB Drive', 'modelTRAINING', H5_FILE);

if ~isfile(H5_PATH)
    error('SSOT H5 not found: %s', H5_PATH);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');

OUT_ROOT = fullfile('/MATLAB Drive', 'modelTRAINING', ...
    ['PatternBranches_' timestamp]);

if ~exist(OUT_ROOT, 'dir')
    mkdir(OUT_ROOT);
end

fprintf('\n=== %s ===\n', PROJECT_NAME);
fprintf('H5 SSOT:\n%s\n\n', H5_PATH);
fprintf('Output root:\n%s\n\n', OUT_ROOT);

%% =========================
%  1. CONFIG
% ==========================

OUT_SIZE = [1024 1024];

T = 48;
SAVE_EVERY = 4;

EPS0 = 1e-12;

NUM_BRANCHES = 8;

branches = make_branch_config();

%% =========================
%  2. READ H5 + BUILD FIELD
% ==========================

info = h5info(H5_PATH);
allDatasets = list_numeric_h5_datasets(info);

if isempty(allDatasets)
    error('No numeric datasets found inside H5.');
end

selected = select_ssot_datasets(allDatasets);

fprintf('Numeric datasets found: %d\n', numel(allDatasets));
fprintf('Selected datasets:\n');

for k = 1:numel(selected)
    fprintf('  %02d | %s | size=%s | score=%.3f\n', ...
        k, selected(k).path, size_to_string(selected(k).size), selected(k).score);
end

write_dataset_selection_csv(fullfile(OUT_ROOT, '0000_h5_dataset_selection.csv'), selected);

maps = cell(1, numel(selected));

for k = 1:numel(selected)
    raw = h5read(H5_PATH, selected(k).path);
    maps{k} = numeric_to_map(raw, OUT_SIZE);
end

F0 = combine_maps(maps);
F0 = normalize01(F0);

P0 = structure_layer(F0);

[H, Wd] = size(F0);
[x, y] = meshgrid(linspace(-1, 1, Wd), linspace(-1, 1, H));

r = sqrt(x.^2 + y.^2);
theta = atan2(y, x);

rNorm = normalize01(r);
thetaNorm = normalize01(theta + pi);

[Fx0, Fy0] = gradient(F0);
gradMag0 = normalize01(sqrt(Fx0.^2 + Fy0.^2));

metric = 1 ./ (EPS0 + 0.20 + 0.45 .* P0 + 0.35 .* gradMag0);
metric = normalize01(metric);

geoPotential = normalize01( ...
    0.45 .* F0 + ...
    0.30 .* P0 + ...
    0.15 .* (1 - rNorm) + ...
    0.10 .* thetaNorm ...
);

[Vx, Vy] = gradient(geoPotential);
vmag = sqrt(Vx.^2 + Vy.^2) + EPS0;

Vx = Vx ./ vmag;
Vy = Vy ./ vmag;

Vx(~isfinite(Vx)) = 0;
Vy(~isfinite(Vy)) = 0;

imwrite(F0, fullfile(OUT_ROOT, '0100_base_ssot_field.png'));
imwrite(P0, fullfile(OUT_ROOT, '0200_structure_layer.png'));
imwrite(metric, fullfile(OUT_ROOT, '0300_geodesic_metric.png'));

baseRGB = render_rgb(F0, Vx, Vy, metric, thetaNorm, rNorm);
imwrite(baseRGB, fullfile(OUT_ROOT, '0400_base_VectorVision_seed.png'));

%% =========================
%  3. RUN BRANCHES
% ==========================

branchMetrics = struct( ...
    'branch_id', {}, ...
    'branch_name', {}, ...
    'folder', {}, ...
    'coherence', {}, ...
    'symmetry', {}, ...
    'stability', {}, ...
    'structure_preservation', {}, ...
    'motion_energy', {}, ...
    'noise_penalty', {}, ...
    'raw_probability_score', {}, ...
    'probability', {}, ...
    'rank', {} ...
);

for b = 1:NUM_BRANCHES

    cfg = branches(b);

    branchFolderName = sprintf('option_%03d_%s', b, cfg.name);
    branchDir = fullfile(OUT_ROOT, branchFolderName);
    frameDir = fullfile(branchDir, 'frames');

    if ~exist(branchDir, 'dir'); mkdir(branchDir); end
    if ~exist(frameDir, 'dir'); mkdir(frameDir); end

    fprintf('\nRunning branch %02d/%02d: %s\n', b, NUM_BRANCHES, cfg.name);

    [finalF, metrics, trace] = run_branch( ...
        F0, P0, metric, Vx, Vy, x, y, rNorm, theta, thetaNorm, ...
        cfg, T, SAVE_EVERY, frameDir);

    finalRGB = render_rgb(finalF, Vx, Vy, metric, thetaNorm, rNorm);

    imwrite(finalF, fullfile(branchDir, 'final_scalar.png'));
    imwrite(finalRGB, fullfile(branchDir, 'final_VectorVision.png'));
    imwrite(trace.temporal_delta_map, fullfile(branchDir, 'temporal_delta_map.png'));
    imwrite(trace.motion_energy_map, fullfile(branchDir, 'motion_energy_map.png'));

    branchReport = struct();
    branchReport.branch_id = b;
    branchReport.branch_name = cfg.name;
    branchReport.config = cfg;
    branchReport.metrics = metrics;
    branchReport.folder = branchDir;

    write_json(fullfile(branchDir, 'branch_metrics.json'), branchReport);

    branchMetrics(end+1).branch_id = b; %#ok<AGROW>
    branchMetrics(end).branch_name = cfg.name;
    branchMetrics(end).folder = branchDir;
    branchMetrics(end).coherence = metrics.coherence;
    branchMetrics(end).symmetry = metrics.symmetry;
    branchMetrics(end).stability = metrics.stability;
    branchMetrics(end).structure_preservation = metrics.structure_preservation;
    branchMetrics(end).motion_energy = metrics.motion_energy;
    branchMetrics(end).noise_penalty = metrics.noise_penalty;
    branchMetrics(end).raw_probability_score = metrics.raw_probability_score;
    branchMetrics(end).probability = 0;
    branchMetrics(end).rank = 0;
end

%% =========================
%  4. NORMALIZE PROBABILITIES
% ==========================

scores = [branchMetrics.raw_probability_score];
scores(~isfinite(scores)) = 0;
scores = max(scores, 0);

if sum(scores) <= 0
    probs = ones(size(scores)) ./ numel(scores);
else
    probs = scores ./ sum(scores);
end

[~, order] = sort(probs, 'descend');
ranks = zeros(size(order));

for i = 1:numel(order)
    ranks(order(i)) = i;
end

for i = 1:numel(branchMetrics)
    branchMetrics(i).probability = probs(i);
    branchMetrics(i).rank = ranks(i);
end

write_master_index_csv(fullfile(OUT_ROOT, '1111_master_branch_index.csv'), branchMetrics);

masterReport = struct();
masterReport.project = PROJECT_NAME;
masterReport.h5_path = H5_PATH;
masterReport.h5_sha256 = sha256_file_safe(H5_PATH);
masterReport.output_root = OUT_ROOT;
masterReport.field_height = H;
masterReport.field_width = Wd;
masterReport.time_steps = T;
masterReport.save_every = SAVE_EVERY;
masterReport.branch_count = NUM_BRANCHES;
masterReport.branches = branchMetrics;
masterReport.statement = ...
    'Branches are computational probability options, not physical future predictions.';

write_json(fullfile(OUT_ROOT, '2222_master_branch_report.json'), masterReport);

%% =========================
%  5. CONTACT SHEET
% ==========================

make_contact_sheet(OUT_ROOT, branchMetrics);

fprintf('\nDONE.\n');
fprintf('Pattern branches created.\n');
fprintf('Root folder:\n%s\n', OUT_ROOT);
fprintf('Main index:\n%s\n', fullfile(OUT_ROOT, '1111_master_branch_index.csv'));

%% ============================================================
%  LOCAL FUNCTIONS
% ============================================================

function branches = make_branch_config()

    branches = struct( ...
        'name', {}, ...
        'symmetry', {}, ...
        'smooth', {}, ...
        'flow', {}, ...
        'radial', {}, ...
        'spiral', {}, ...
        'noise', {}, ...
        'preserve', {}, ...
        'direction_mode', {}, ...
        'seed', {} ...
    );

    branches(1) = branch('high_coherence',         0.18, 0.18, 0.14, 0.10, 0.00, 0.00, 0.60, 'base',     101);
    branches(2) = branch('radial_expansion',       0.14, 0.13, 0.18, 0.28, 0.00, 0.01, 0.54, 'radial',   102);
    branches(3) = branch('symmetry_lock',          0.32, 0.14, 0.10, 0.08, 0.00, 0.00, 0.58, 'base',     103);
    branches(4) = branch('spiral_time',            0.14, 0.12, 0.16, 0.10, 0.30, 0.01, 0.55, 'spiral',   104);
    branches(5) = branch('gradient_follow',        0.10, 0.10, 0.30, 0.06, 0.00, 0.01, 0.54, 'gradient', 105);
    branches(6) = branch('noise_escape',           0.08, 0.08, 0.20, 0.06, 0.05, 0.06, 0.52, 'escape',   106);
    branches(7) = branch('center_convergence',     0.16, 0.16, 0.16, 0.30, 0.00, 0.01, 0.56, 'center',   107);
    branches(8) = branch('balanced_future_option', 0.20, 0.14, 0.16, 0.14, 0.10, 0.02, 0.58, 'mixed',    108);
end

function b = branch(name, symmetry, smooth, flow, radial, spiral, noise, preserve, direction_mode, seed)

    b.name = name;
    b.symmetry = symmetry;
    b.smooth = smooth;
    b.flow = flow;
    b.radial = radial;
    b.spiral = spiral;
    b.noise = noise;
    b.preserve = preserve;
    b.direction_mode = direction_mode;
    b.seed = seed;
end

function [F, metrics, trace] = run_branch( ...
    F0, P0, metric, Vx, Vy, x, y, rNorm, theta, thetaNorm, ...
    cfg, T, SAVE_EVERY, frameDir)

    rng(cfg.seed);

    F = F0;
    Fprev = F0;

    [Vbx, Vby] = branch_vector_field(Vx, Vy, F0, x, y, cfg.direction_mode);

    temporalAccum = zeros(size(F0));
    motionAccum = zeros(size(F0));

    for t = 0:T

        tau = t / max(T, 1);

        if mod(t, SAVE_EVERY) == 0 || t == 0 || t == T
            RGB = render_rgb(F, Vbx, Vby, metric, thetaNorm, rNorm);
            imwrite(RGB, fullfile(frameDir, sprintf('frame_%03d.png', t)));
        end

        if t == T
            break;
        end

        S = symmetry_field(F);
        Hs = gaussian_blur2(F, 1.0 + 2.0*tau);

        [Fx, Fy] = gradient(F);
        flowPush = Vbx .* Fx + Vby .* Fy;
        flowField = normalize01(F + 0.20 .* flowPush .* (0.35 + metric));

        radialWave = exp(-2.2 .* rNorm) .* ...
            (0.50 + 0.50 .* sin(2*pi*tau + theta).^2);

        spiralWave = normalize01( ...
            0.5 + 0.5 .* sin(8*theta + 5*pi*tau - 6*rNorm) ...
        );

        radialField = normalize01((1 - radialWave).*F + radialWave.*flowField);
        spiralField = normalize01((1 - spiralWave).*F + spiralWave.*flowField);

        N = gaussian_blur2(randn(size(F)), 1.25);
        N = normalize01(N);

        Fnext = ...
            cfg.preserve .* F0 + ...
            cfg.symmetry .* S + ...
            cfg.smooth   .* Hs + ...
            cfg.flow     .* flowField + ...
            cfg.radial   .* radialField + ...
            cfg.spiral   .* spiralField + ...
            cfg.noise    .* N;

        weightSum = cfg.preserve + cfg.symmetry + cfg.smooth + ...
                    cfg.flow + cfg.radial + cfg.spiral + cfg.noise;

        Fnext = Fnext ./ max(weightSum, eps);
        Fnext = normalize01(Fnext);

        temporalDelta = abs(Fnext - Fprev);
        temporalAccum = temporalAccum + temporalDelta;
        motionAccum = motionAccum + abs(flowPush);

        Fprev = F;
        F = Fnext;
    end

    finalStructure = structure_layer(F);

    coherence = 1 - nanmean_local(abs(finalStructure(:) - P0(:)));
    coherence = clamp01(coherence);

    symmetryScore = symmetry_score(F);

    stability = 1 - nanmean_local(abs(F(:) - Fprev(:)));
    stability = clamp01(stability);

    structurePreservation = 1 - nanmean_local(abs(F(:) - F0(:)));
    structurePreservation = clamp01(structurePreservation);

    motionAccumNorm = normalize01(motionAccum);
    motionEnergy = clamp01(nanmean_local(motionAccumNorm(:)));

    Fblur = gaussian_blur2(F, 2.0);
    noisePenalty = clamp01(nanmean_local(abs(F(:) - Fblur(:))));

    rawScore = ...
        0.30 * coherence + ...
        0.22 * symmetryScore + ...
        0.22 * stability + ...
        0.18 * structurePreservation + ...
        0.08 * motionEnergy - ...
        0.10 * noisePenalty;

    metrics = struct();
    metrics.coherence = coherence;
    metrics.symmetry = symmetryScore;
    metrics.stability = stability;
    metrics.structure_preservation = structurePreservation;
    metrics.motion_energy = motionEnergy;
    metrics.noise_penalty = noisePenalty;
    metrics.raw_probability_score = max(rawScore, 0);

    trace = struct();
    trace.temporal_delta_map = normalize01(temporalAccum);
    trace.motion_energy_map = normalize01(motionAccum);
end

function [Vbx, Vby] = branch_vector_field(Vx, Vy, F0, x, y, mode)

    [Gx, Gy] = gradient(F0);
    [Gx, Gy] = normalize_vec(Gx, Gy);

    [Rx, Ry] = normalize_vec(x, y);
    [Cx, Cy] = normalize_vec(-x, -y);

    Sx = -y;
    Sy = x;
    [Sx, Sy] = normalize_vec(Sx, Sy);

    switch lower(mode)
        case 'base'
            Vbx = Vx;
            Vby = Vy;

        case 'radial'
            Vbx = 0.55*Vx + 0.45*Rx;
            Vby = 0.55*Vy + 0.45*Ry;

        case 'spiral'
            Vbx = 0.50*Vx + 0.50*Sx;
            Vby = 0.50*Vy + 0.50*Sy;

        case 'gradient'
            Vbx = 0.45*Vx + 0.55*Gx;
            Vby = 0.45*Vy + 0.55*Gy;

        case 'escape'
            Vbx = 0.35*Vx + 0.35*Rx + 0.30*Gx;
            Vby = 0.35*Vy + 0.35*Ry + 0.30*Gy;

        case 'center'
            Vbx = 0.50*Vx + 0.50*Cx;
            Vby = 0.50*Vy + 0.50*Cy;

        otherwise
            Vbx = 0.45*Vx + 0.25*Gx + 0.15*Rx + 0.15*Sx;
            Vby = 0.45*Vy + 0.25*Gy + 0.15*Ry + 0.15*Sy;
    end

    [Vbx, Vby] = normalize_vec(Vbx, Vby);
end

function datasets = list_numeric_h5_datasets(info)

    datasets = struct('path', {}, 'size', {}, 'rank', {}, 'numel', {}, 'class', {}, 'score', {});
    datasets = walk_group(info, datasets);
end

function datasets = walk_group(groupInfo, datasets)

    for i = 1:numel(groupInfo.Datasets)
        ds = groupInfo.Datasets(i);
        dsPath = h5_join(groupInfo.Name, ds.Name);

        dsSize = double(ds.Dataspace.Size);
        if isempty(dsSize)
            dsSize = 1;
        end

        dsClass = 'UNKNOWN';
        try
            dsClass = char(ds.Datatype.Class);
        catch
            dsClass = 'UNKNOWN';
        end

        dsClassUpper = upper(dsClass);

        isNumeric = ~isempty(strfind(dsClassUpper, 'FLOAT')) || ...
                    ~isempty(strfind(dsClassUpper, 'INTEGER')) || ...
                    ~isempty(strfind(dsClassUpper, 'FIXED'));

        n = prod(dsSize);

        if isNumeric && n >= 16 && n <= 2e7
            rec.path = dsPath;
            rec.size = dsSize;
            rec.rank = numel(dsSize);
            rec.numel = n;
            rec.class = dsClass;
            rec.score = 0;
            datasets(end+1) = rec; %#ok<AGROW>
        end
    end

    for g = 1:numel(groupInfo.Groups)
        datasets = walk_group(groupInfo.Groups(g), datasets);
    end
end

function selected = select_ssot_datasets(datasets)

    for k = 1:numel(datasets)
        p = lower(char(datasets(k).path));

        sz = double(datasets(k).size);
        rankVal = double(datasets(k).rank);
        n = double(datasets(k).numel);

        score = 0;

        if rankVal >= 2
            score = score + 10;
        end

        if any(sz >= 128)
            score = score + 4;
        end

        if n >= 1e5
            score = score + 3;
        end

        keywords = { ...
            'field','map','data','image','pattern','composite', ...
            'matrix','surface','grid','n_5','1000','projection', ...
            'vector','eta','phase','time','sample','roi' ...
        };

        for j = 1:numel(keywords)
            if ~isempty(strfind(p, keywords{j})) %#ok<STREMP>
                score = score + 1.25;
            end
        end

        negativeKeywords = {'label','name','index'};

        for j = 1:numel(negativeKeywords)
            if ~isempty(strfind(p, negativeKeywords{j})) %#ok<STREMP>
                score = score - 2;
            end
        end

        datasets(k).score = score;
    end

    scores = [datasets.score];
    [~, idx] = sort(scores, 'descend');

    selected = datasets(idx(1:min(8, numel(idx))));
end

function M = numeric_to_map(raw, outSize)

    A = raw;

    if ~isnumeric(A) && ~islogical(A)
        error('Dataset is not numeric after h5read.');
    end

    A = double(A);

    if ~isreal(A)
        A = abs(A);
    end

    A = squeeze(A);

    if isvector(A)
        v = A(:);
        n = floor(sqrt(numel(v)));

        if n < 4
            M = zeros(outSize);
            return;
        end

        v = v(1:n*n);
        A = reshape(v, n, n);

    elseif ndims(A) > 2
        sz = size(A);
        A = reshape(A, sz(1), sz(2), []);
        A = nanmean_local(A, 3);
    end

    A(~isfinite(A)) = 0;
    A = normalize01(A);

    M = resize2(A, outSize);
    M = normalize01(M);
end

function F = combine_maps(maps)

    F = zeros(size(maps{1}));
    wsum = 0;

    for k = 1:numel(maps)
        M = normalize01(maps{k});
        [Mx, My] = gradient(M);
        energy = nanmean_local(sqrt(Mx.^2 + My.^2));
        w = 1 + energy;
        F = F + w .* M;
        wsum = wsum + w;
    end

    F = F ./ max(wsum, eps);
    F = normalize01(F);
end

function P = structure_layer(F)

    [Fx, Fy] = gradient(F);
    G = sqrt(Fx.^2 + Fy.^2);

    L = del2(F);
    L = abs(L);

    P = normalize01(0.65 .* normalize01(G) + 0.35 .* normalize01(L));
    P = gaussian_blur2(P, 0.75);
    P = normalize01(P);
end

function S = symmetry_field(F)

    A = F;

    S1 = 0.25 .* (A + fliplr(A) + flipud(A) + rot90(A,2));

    if size(A,1) == size(A,2)
        D1 = A.';
        D2 = fliplr(flipud(A.'));
        S2 = 0.5 .* (D1 + D2);
        S = 0.70 .* S1 + 0.30 .* S2;
    else
        S = S1;
    end

    S = normalize01(S);
end

function score = symmetry_score(F)

    A = normalize01(F);

    A_lr = fliplr(A);
    A_ud = flipud(A);
    A_r2 = rot90(A, 2);

    e1 = nanmean_local(abs(A(:) - A_lr(:)));
    e2 = nanmean_local(abs(A(:) - A_ud(:)));
    e3 = nanmean_local(abs(A(:) - A_r2(:)));

    score = clamp01(1 - mean([e1 e2 e3]));
end

function RGB = render_rgb(F, Vx, Vy, metric, thetaNorm, rNorm)

    F = normalize01(F);
    M = normalize01(metric);
    V = normalize01(sqrt(Vx.^2 + Vy.^2));

    hue = normalize01(0.62 .* thetaNorm + 0.20 .* F + 0.18 .* M);
    sat = normalize01(0.35 + 0.45 .* M + 0.20 .* V);
    val = normalize01(0.20 + 0.62 .* F + 0.18 .* (1-rNorm));

    RGB = hsv2rgb(cat(3, hue, sat, val));

    grayLayer = repmat(F, 1, 1, 3);
    RGB = normalize01(0.72 .* RGB + 0.28 .* grayLayer);
end

function [ux, uy] = normalize_vec(x, y)

    mag = sqrt(x.^2 + y.^2);
    mag(mag < eps) = 1;

    ux = x ./ mag;
    uy = y ./ mag;

    ux(~isfinite(ux)) = 0;
    uy(~isfinite(uy)) = 0;
end

function B = resize2(A, outSize)

    if exist('imresize', 'file') == 2
        B = imresize(A, outSize, 'bilinear');
        return;
    end

    [h, w] = size(A);

    if h < 2 || w < 2
        B = zeros(outSize);
        return;
    end

    [x, y] = meshgrid(1:w, 1:h);
    [xq, yq] = meshgrid(linspace(1,w,outSize(2)), linspace(1,h,outSize(1)));

    B = interp2(x, y, A, xq, yq, 'linear', 0);
end

function B = gaussian_blur2(A, sigma)

    sigma = max(double(sigma), 0.01);

    if exist('imgaussfilt', 'file') == 2
        B = imgaussfilt(A, sigma);
        return;
    end

    radius = max(1, ceil(3*sigma));
    x = -radius:radius;

    g = exp(-(x.^2) ./ (2*sigma^2));
    g = g ./ sum(g);

    B = conv2(conv2(A, g, 'same'), g.', 'same');
end

function Y = normalize01(X)

    X = double(X);
    finiteVals = X(isfinite(X));

    if isempty(finiteVals)
        Y = zeros(size(X));
        return;
    end

    mn = min(finiteVals);
    mx = max(finiteVals);

    if ~isfinite(mn) || ~isfinite(mx) || abs(mx-mn) < eps
        Y = zeros(size(X));
        return;
    end

    Y = (X - mn) ./ (mx - mn);
    Y(~isfinite(Y)) = 0;
    Y = min(max(Y, 0), 1);
end

function v = clamp01(v)

    v = min(max(v, 0), 1);
end

function p = h5_join(parent, child)

    parent = char(parent);
    child = char(child);

    if strcmp(parent, '/')
        p = ['/' child];
    else
        p = [parent '/' child];
    end
end

function write_json(path, data)

    try
        txt = jsonencode(data, 'PrettyPrint', true);
    catch
        txt = jsonencode(data);
    end

    fid = fopen(path, 'w');
    fprintf(fid, '%s', txt);
    fclose(fid);
end

function write_dataset_selection_csv(path, selected)

    fid = fopen(path, 'w');
    fprintf(fid, 'rank,path,size,numel,class,score\n');

    for k = 1:numel(selected)
        fprintf(fid, '%d,"%s","%s",%.0f,"%s",%.6f\n', ...
            selected(k).rank, ...
            selected(k).path, ...
            size_to_string(selected(k).size), ...
            selected(k).numel, ...
            selected(k).class, ...
            selected(k).score);
    end

    fclose(fid);
end

function write_master_index_csv(path, rows)

    fid = fopen(path, 'w');
    fprintf(fid, 'rank,branch_id,branch_name,probability,raw_probability_score,coherence,symmetry,stability,structure_preservation,motion_energy,noise_penalty,folder\n');

    for k = 1:numel(rows)
        fprintf(fid, '%d,%d,"%s",%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,"%s"\n', ...
            rows(k).rank, ...
            rows(k).branch_id, ...
            rows(k).branch_name, ...
            rows(k).probability, ...
            rows(k).raw_probability_score, ...
            rows(k).coherence, ...
            rows(k).symmetry, ...
            rows(k).stability, ...
            rows(k).structure_preservation, ...
            rows(k).motion_energy, ...
            rows(k).noise_penalty, ...
            rows(k).folder);
    end

    fclose(fid);
end

function make_contact_sheet(rootDir, branchMetrics)

    n = numel(branchMetrics);
    thumbSize = [256 256];

    cols = 4;
    rows = ceil(n / cols);

    sheet = zeros(rows*thumbSize(1), cols*thumbSize(2), 3);

    for k = 1:n
        imgPath = fullfile(branchMetrics(k).folder, 'final_VectorVision.png');

        if isfile(imgPath)
            Iraw = imread(imgPath);
            I = double(Iraw);

            if max(I(:)) > 1
                I = I ./ 255;
            end

            if size(I,3) == 1
                I = repmat(I, 1, 1, 3);
            end

            I = resize2_rgb(I, thumbSize);
        else
            I = zeros(thumbSize(1), thumbSize(2), 3);
        end

        rr = floor((k-1)/cols) + 1;
        cc = mod(k-1, cols) + 1;

        r1 = (rr-1)*thumbSize(1) + 1;
        r2 = rr*thumbSize(1);

        c1 = (cc-1)*thumbSize(2) + 1;
        c2 = cc*thumbSize(2);

        sheet(r1:r2, c1:c2, :) = I;
    end

    imwrite(sheet, fullfile(rootDir, '3333_branch_contact_sheet.png'));
end

function B = resize2_rgb(A, outSize)

    B = zeros(outSize(1), outSize(2), size(A,3));

    for c = 1:size(A,3)
        B(:,:,c) = resize2(A(:,:,c), outSize);
    end

    B = min(max(B, 0), 1);
end

function h = sha256_file_safe(path)

    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        fis = java.io.FileInputStream(java.io.File(path));
        buffer = zeros(1, 8192, 'uint8');

        while true
            n = fis.read(buffer, 0, numel(buffer));
            if n == -1
                break;
            end
            md.update(buffer(1:n));
        end

        fis.close();

        hash = typecast(md.digest(), 'uint8');
        h = lower(reshape(dec2hex(hash).', 1, []));

    catch
        h = 'SHA256_UNAVAILABLE';
    end
end

function m = nanmean_local(X, dim)

    if nargin < 2
        x = X(:);
        x = x(isfinite(x));
        if isempty(x)
            m = NaN;
        else
            m = mean(x);
        end
        return;
    end

    mask = isfinite(X);
    X2 = X;
    X2(~mask) = 0;

    count = sum(mask, dim);
    total = sum(X2, dim);

    m = total ./ max(count, 1);
    m(count == 0) = NaN;
end

function s = size_to_string(sz)

    if isempty(sz)
        s = '[]';
        return;
    end

    parts = cell(1, numel(sz));

    for i = 1:numel(sz)
        parts{i} = num2str(sz(i));
    end

    s = ['[' strjoin(parts, 'x') ']'];
end