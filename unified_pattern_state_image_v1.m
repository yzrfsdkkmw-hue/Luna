%% unified_pattern_state_image_v1
% Unify all PatternBranches outputs into one direction-sensitive image.
%
% Source folder:
% /MATLAB Drive/modelTRAINING/PatternBranches_20260709_004635
%
% Main idea:
% - Read all branch folders and their frames
% - Build one unified image
% - Reweight branches by directionAngleDeg
% - Save one output image that changes when directionAngleDeg changes

clear; clc; close all;

%% =========================
% 0. FIXED INPUT / OUTPUT
% =========================

PROJECT_NAME = 'unified_pattern_state_image_v1';

ROOT_DIR = fullfile('/MATLAB Drive', 'modelTRAINING', 'PatternBranches_20260709_004635');
INDEX_CSV = fullfile(ROOT_DIR, '1111_master_branch_index.csv');
REPORT_JSON = fullfile(ROOT_DIR, '2222_master_branch_report.json');

if ~exist(ROOT_DIR, 'dir')
    error('PatternBranches folder not found: %s', ROOT_DIR);
end

if ~isfile(INDEX_CSV)
    error('Master index not found: %s', INDEX_CSV);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
OUT_DIR = fullfile(ROOT_DIR, ['UnifiedPatternState_' timestamp]);

if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

fprintf('\n=== %s ===\n', PROJECT_NAME);
fprintf('Input root:\n%s\n\n', ROOT_DIR);
fprintf('Output folder:\n%s\n\n', OUT_DIR);

%% =========================
% 1. USER CONTROL
% =========================
% Change this value and run again.
% Example: 0, 30, 60, 90, 120, 180, 240, 300

directionAngleDeg = 90;

% Temporal emphasis:
% 0   = equal over time
% +1  = later frames stronger
% -1  = earlier frames stronger
timeBias = 0.35;

% Branch direction sharpness:
% higher = more selective
directionSharpness = 3.5;

% Final image size
OUT_SIZE = [1024 1024];

% How much each source contributes
W.final_image      = 0.34;
W.frame_history    = 0.34;
W.temporal_delta   = 0.16;
W.motion_energy    = 0.16;

%% =========================
% 2. READ BRANCH INDEX
% =========================

T = readtable(INDEX_CSV, 'TextType', 'string');

nBranches = height(T);
if nBranches < 1
    error('No branches found in master index.');
end

fprintf('Branches found: %d\n', nBranches);

% Normalize probabilities from CSV
baseProb = double(T.probability);
baseProb(~isfinite(baseProb)) = 0;

if sum(baseProb) <= 0
    baseProb = ones(size(baseProb)) / numel(baseProb);
else
    baseProb = baseProb / sum(baseProb);
end

branchNames = strings(nBranches, 1);
branchDirs  = strings(nBranches, 1);
branchAngles = zeros(nBranches, 1);

for i = 1:nBranches
    branchNames(i) = string(T.branch_name(i));
    [branchAngles(i), branchDirs(i)] = map_branch_to_angle(branchNames(i));
end

%% =========================
% 3. READ EACH BRANCH
% =========================

branchData = struct( ...
    'branch_id', {}, ...
    'branch_name', {}, ...
    'folder', {}, ...
    'base_probability', {}, ...
    'direction_angle_deg', {}, ...
    'direction_label', {}, ...
    'direction_affinity', {}, ...
    'combined_weight', {}, ...
    'final_img', {}, ...
    'history_img', {}, ...
    'temporal_delta_img', {}, ...
    'motion_energy_img', {} ...
);

for i = 1:nBranches

    bFolder = char(T.folder(i));
    if ~exist(bFolder, 'dir')
        error('Branch folder missing: %s', bFolder);
    end

    finalPath  = fullfile(bFolder, 'final_VectorVision.png');
    deltaPath  = fullfile(bFolder, 'temporal_delta_map.png');
    motionPath = fullfile(bFolder, 'motion_energy_map.png');
    frameDir   = fullfile(bFolder, 'frames');

    if ~isfile(finalPath)
        error('Missing final image: %s', finalPath);
    end
    if ~isfile(deltaPath)
        error('Missing temporal delta image: %s', deltaPath);
    end
    if ~isfile(motionPath)
        error('Missing motion energy image: %s', motionPath);
    end
    if ~exist(frameDir, 'dir')
        error('Missing frames folder: %s', frameDir);
    end

    finalImg  = read_rgb_image(finalPath, OUT_SIZE);
    deltaImg  = read_gray_as_rgb(deltaPath, OUT_SIZE);
    motionImg = read_gray_as_rgb(motionPath, OUT_SIZE);
    histImg   = build_history_image(frameDir, OUT_SIZE, timeBias);

    aff = directional_affinity(directionAngleDeg, branchAngles(i), directionSharpness);
    combinedWeight = baseProb(i) * aff;

    branchData(i).branch_id = i;
    branchData(i).branch_name = branchNames(i);
    branchData(i).folder = string(bFolder);
    branchData(i).base_probability = baseProb(i);
    branchData(i).direction_angle_deg = branchAngles(i);
    branchData(i).direction_label = branchDirs(i);
    branchData(i).direction_affinity = aff;
    branchData(i).combined_weight = combinedWeight;
    branchData(i).final_img = finalImg;
    branchData(i).history_img = histImg;
    branchData(i).temporal_delta_img = deltaImg;
    branchData(i).motion_energy_img = motionImg;
end

%% =========================
% 4. RENORMALIZE DIRECTIONAL WEIGHTS
% =========================

combinedWeights = [branchData.combined_weight];
combinedWeights(~isfinite(combinedWeights)) = 0;

if sum(combinedWeights) <= 0
    combinedWeights = ones(size(combinedWeights)) / numel(combinedWeights);
else
    combinedWeights = combinedWeights / sum(combinedWeights);
end

for i = 1:nBranches
    branchData(i).combined_weight = combinedWeights(i);
end

%% =========================
% 5. BUILD UNIFIED IMAGE
% =========================

unifiedFinal   = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);
unifiedHistory = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);
unifiedDelta   = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);
unifiedMotion  = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);

for i = 1:nBranches
    w = branchData(i).combined_weight;

    unifiedFinal   = unifiedFinal   + w .* branchData(i).final_img;
    unifiedHistory = unifiedHistory + w .* branchData(i).history_img;
    unifiedDelta   = unifiedDelta   + w .* branchData(i).temporal_delta_img;
    unifiedMotion  = unifiedMotion  + w .* branchData(i).motion_energy_img;
end

unifiedBase = ...
    W.final_image   .* unifiedFinal + ...
    W.frame_history .* unifiedHistory + ...
    W.temporal_delta .* unifiedDelta + ...
    W.motion_energy .* unifiedMotion;

unifiedBase = normalize01_rgb(unifiedBase);

% Direction-coded modulation layer
dirLayer = build_direction_layer(OUT_SIZE, directionAngleDeg);

% Blend direction layer into unified image
unifiedState = normalize01_rgb(0.82 .* unifiedBase + 0.18 .* dirLayer);

%% =========================
% 6. SAVE OUTPUTS
% =========================

imwrite(unifiedFinal,   fullfile(OUT_DIR, '0100_unified_final_only.png'));
imwrite(unifiedHistory, fullfile(OUT_DIR, '0200_unified_history_only.png'));
imwrite(unifiedDelta,   fullfile(OUT_DIR, '0300_unified_temporal_delta_only.png'));
imwrite(unifiedMotion,  fullfile(OUT_DIR, '0400_unified_motion_energy_only.png'));
imwrite(unifiedState,   fullfile(OUT_DIR, '1111_unified_pattern_state_image.png'));

write_branch_weights_csv(fullfile(OUT_DIR, '2222_branch_direction_weights.csv'), branchData);

summary = struct();
summary.project = PROJECT_NAME;
summary.root_dir = ROOT_DIR;
summary.output_dir = OUT_DIR;
summary.directionAngleDeg = directionAngleDeg;
summary.timeBias = timeBias;
summary.directionSharpness = directionSharpness;
summary.branch_count = nBranches;
summary.statement = 'The image is a unified state image computed from branches and reweighted by directionAngleDeg.';
summary.branches = strip_images_from_branchdata(branchData);

write_json(fullfile(OUT_DIR, '3333_unified_pattern_state_report.json'), summary);

fprintf('\nDONE.\n');
fprintf('Unified pattern state image created.\n\n');
fprintf('Main image:\n%s\n', fullfile(OUT_DIR, '1111_unified_pattern_state_image.png'));
fprintf('Weights table:\n%s\n', fullfile(OUT_DIR, '2222_branch_direction_weights.csv'));
fprintf('Folder:\n%s\n', OUT_DIR);

%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function [angleDeg, label] = map_branch_to_angle(name)

    s = lower(char(name));

    if contains(s, 'high_coherence')
        angleDeg = 0;
        label = "coherence_axis";
    elseif contains(s, 'radial_expansion')
        angleDeg = 45;
        label = "radial_axis";
    elseif contains(s, 'symmetry_lock')
        angleDeg = 90;
        label = "symmetry_axis";
    elseif contains(s, 'spiral_time')
        angleDeg = 135;
        label = "spiral_axis";
    elseif contains(s, 'gradient_follow')
        angleDeg = 180;
        label = "gradient_axis";
    elseif contains(s, 'noise_escape')
        angleDeg = 225;
        label = "escape_axis";
    elseif contains(s, 'center_convergence')
        angleDeg = 270;
        label = "center_axis";
    elseif contains(s, 'balanced_future_option')
        angleDeg = 315;
        label = "balanced_axis";
    else
        angleDeg = 0;
        label = "default_axis";
    end
end

function a = directional_affinity(queryAngleDeg, branchAngleDeg, sharpness)

    d = angdiff_deg(queryAngleDeg, branchAngleDeg);
    a = exp(sharpness * cosd(d));

    if ~isfinite(a)
        a = 0;
    end
end

function d = angdiff_deg(a, b)
    d = mod((a - b) + 180, 360) - 180;
end

function I = read_rgb_image(path, outSize)

    A = imread(path);
    A = double(A);

    if max(A(:)) > 1
        A = A ./ 255;
    end

    if size(A,3) == 1
        A = repmat(A, 1, 1, 3);
    end

    I = resize2_rgb(A, outSize);
    I = normalize01_rgb(I);
end

function I = read_gray_as_rgb(path, outSize)

    A = imread(path);
    A = double(A);

    if max(A(:)) > 1
        A = A ./ 255;
    end

    if size(A,3) > 1
        A = rgb2gray_local(A);
    end

    A = resize2(A, outSize);
    A = normalize01(A);
    I = repmat(A, 1, 1, 3);
end

function H = build_history_image(frameDir, outSize, timeBias)

    files = dir(fullfile(frameDir, 'frame_*.png'));

    if isempty(files)
        error('No frames found in %s', frameDir);
    end

    names = natsort_simple({files.name});
    n = numel(names);

    H = zeros(outSize(1), outSize(2), 3);

    t = linspace(0, 1, n);

    if timeBias > 0
        w = exp(3*timeBias*t);
    elseif timeBias < 0
        w = exp(3*abs(timeBias)*(1-t));
    else
        w = ones(1, n);
    end

    w = w ./ sum(w);

    for k = 1:n
        img = read_rgb_image(fullfile(frameDir, names{k}), outSize);
        H = H + w(k) .* img;
    end

    H = normalize01_rgb(H);
end

function D = build_direction_layer(outSize, directionAngleDeg)

    [x, y] = meshgrid(linspace(-1,1,outSize(2)), linspace(-1,1,outSize(1)));
    theta = atan2d(y, x);
    r = sqrt(x.^2 + y.^2);

    align = cosd(theta - directionAngleDeg);
    align = normalize01(align);

    ring = 0.5 + 0.5 * sin(8*pi*r - deg2rad(directionAngleDeg));
    ring = normalize01(ring);

    hue = normalize01((theta + 180) / 360);
    sat = normalize01(0.30 + 0.40*align + 0.30*ring);
    val = normalize01(0.18 + 0.52*align + 0.30*(1-r));

    D = hsv2rgb(cat(3, hue, sat, val));
    D = normalize01_rgb(D);
end

function out = strip_images_from_branchdata(branchData)

    out = struct( ...
        'branch_id', {}, ...
        'branch_name', {}, ...
        'folder', {}, ...
        'base_probability', {}, ...
        'direction_angle_deg', {}, ...
        'direction_label', {}, ...
        'direction_affinity', {}, ...
        'combined_weight', {} ...
    );

    for i = 1:numel(branchData)
        out(i).branch_id = branchData(i).branch_id;
        out(i).branch_name = branchData(i).branch_name;
        out(i).folder = branchData(i).folder;
        out(i).base_probability = branchData(i).base_probability;
        out(i).direction_angle_deg = branchData(i).direction_angle_deg;
        out(i).direction_label = branchData(i).direction_label;
        out(i).direction_affinity = branchData(i).direction_affinity;
        out(i).combined_weight = branchData(i).combined_weight;
    end
end

function write_branch_weights_csv(path, branchData)

    fid = fopen(path, 'w');
    fprintf(fid, 'branch_id,branch_name,base_probability,direction_angle_deg,direction_label,direction_affinity,combined_weight,folder\n');

    for i = 1:numel(branchData)
        fprintf(fid, '%d,"%s",%.17g,%.17g,"%s",%.17g,%.17g,"%s"\n', ...
            branchData(i).branch_id, ...
            char(branchData(i).branch_name), ...
            branchData(i).base_probability, ...
            branchData(i).direction_angle_deg, ...
            char(branchData(i).direction_label), ...
            branchData(i).direction_affinity, ...
            branchData(i).combined_weight, ...
            char(branchData(i).folder));
    end

    fclose(fid);
end

function C = rgb2gray_local(A)

    if size(A,3) == 1
        C = A;
        return;
    end

    C = 0.2989*A(:,:,1) + 0.5870*A(:,:,2) + 0.1140*A(:,:,3);
end

function namesOut = natsort_simple(namesIn)

    nums = zeros(numel(namesIn), 1);

    for i = 1:numel(namesIn)
        token = regexp(namesIn{i}, 'frame_(\d+)\.png', 'tokens', 'once');
        if isempty(token)
            nums(i) = i;
        else
            nums(i) = str2double(token{1});
        end
    end

    [~, idx] = sort(nums);
    namesOut = namesIn(idx);
end

function B = resize2_rgb(A, outSize)

    B = zeros(outSize(1), outSize(2), size(A,3));

    for c = 1:size(A,3)
        B(:,:,c) = resize2(A(:,:,c), outSize);
    end

    B = min(max(B, 0), 1);
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

function Y = normalize01(X)

    X = double(X);
    vals = X(isfinite(X));

    if isempty(vals)
        Y = zeros(size(X));
        return;
    end

    mn = min(vals);
    mx = max(vals);

    if ~isfinite(mn) || ~isfinite(mx) || abs(mx - mn) < eps
        Y = zeros(size(X));
        return;
    end

    Y = (X - mn) ./ (mx - mn);
    Y(~isfinite(Y)) = 0;
    Y = min(max(Y, 0), 1);
end

function Y = normalize01_rgb(X)

    Y = zeros(size(X));
    for c = 1:size(X,3)
        Y(:,:,c) = normalize01(X(:,:,c));
    end
    Y = min(max(Y, 0), 1);
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