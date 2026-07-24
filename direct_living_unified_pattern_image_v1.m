%% direct_living_unified_pattern_image_v1
% PatternBranches -> ONE direct living-style unified image
%
% Input:
% /MATLAB Drive/modelTRAINING/PatternBranches_20260709_004635
%
% Output:
% one vivid direction-sensitive image + small metadata files

clear; clc; close all;

%% =========================
% 0. PATHS
% ==========================

PROJECT_NAME = 'direct_living_unified_pattern_image_v1';

ROOT_DIR = fullfile('/MATLAB Drive','modelTRAINING','PatternBranches_20260709_004635');
INDEX_CSV = fullfile(ROOT_DIR,'1111_master_branch_index.csv');

if ~exist(ROOT_DIR,'dir')
    error('ROOT_DIR not found: %s', ROOT_DIR);
end

if ~isfile(INDEX_CSV)
    error('Master index CSV not found: %s', INDEX_CSV);
end

timestamp = datestr(now,'yyyymmdd_HHMMSS');
OUT_DIR = fullfile(ROOT_DIR, ['DirectLivingUnified_' timestamp]);

if ~exist(OUT_DIR,'dir')
    mkdir(OUT_DIR);
end

fprintf('\n=== %s ===\n', PROJECT_NAME);
fprintf('Input:\n%s\n\n', ROOT_DIR);
fprintf('Output:\n%s\n\n', OUT_DIR);

%% =========================
% 1. CONTROL
% ==========================

% Change this angle and run again.
% Pixels will change according to this direction.
directionAngleDeg = 90;

OUT_SIZE = [1024 1024];

% Direct vivid image controls
timeBias          = 0.55;
directionSharpness = 4.25;

W.final_image    = 0.30;
W.frame_history  = 0.28;
W.temporal_delta = 0.20;
W.motion_energy  = 0.22;

% Stronger living color controls
saturationBoost  = 1.85;
valueBoost       = 1.22;
contrastBoost    = 1.35;
glowStrength     = 0.32;
edgeStrength     = 0.22;
directionStrength = 0.30;
pulsePhase       = 0.37;

%% =========================
% 2. READ INDEX
% ==========================

T = readtable(INDEX_CSV, 'TextType', 'string');

nBranches = height(T);
if nBranches < 1
    error('No branches found.');
end

baseProb = double(T.probability);
baseProb(~isfinite(baseProb)) = 0;

if sum(baseProb) <= 0
    baseProb = ones(size(baseProb)) ./ numel(baseProb);
else
    baseProb = baseProb ./ sum(baseProb);
end

branchNames = strings(nBranches,1);
branchAngles = zeros(nBranches,1);
branchLabels = strings(nBranches,1);

for i = 1:nBranches
    branchNames(i) = string(T.branch_name(i));
    [branchAngles(i), branchLabels(i)] = map_branch_to_angle(branchNames(i));
end

%% =========================
% 3. READ BRANCH DATA
% ==========================

combinedWeights = zeros(nBranches,1);

branchFinal   = cell(nBranches,1);
branchHistory = cell(nBranches,1);
branchDelta   = cell(nBranches,1);
branchMotion  = cell(nBranches,1);

for i = 1:nBranches

    branchFolder = char(T.folder(i));

    finalPath  = fullfile(branchFolder, 'final_VectorVision.png');
    deltaPath  = fullfile(branchFolder, 'temporal_delta_map.png');
    motionPath = fullfile(branchFolder, 'motion_energy_map.png');
    frameDir   = fullfile(branchFolder, 'frames');

    if ~isfile(finalPath)
        error('Missing final image: %s', finalPath);
    end

    if ~isfile(deltaPath)
        error('Missing temporal delta map: %s', deltaPath);
    end

    if ~isfile(motionPath)
        error('Missing motion energy map: %s', motionPath);
    end

    if ~exist(frameDir,'dir')
        error('Missing frames folder: %s', frameDir);
    end

    branchFinal{i}   = read_rgb_image(finalPath, OUT_SIZE);
    branchDelta{i}   = read_gray_as_rgb(deltaPath, OUT_SIZE);
    branchMotion{i}  = read_gray_as_rgb(motionPath, OUT_SIZE);
    branchHistory{i} = build_history_image(frameDir, OUT_SIZE, timeBias);

    affinity = directional_affinity(directionAngleDeg, branchAngles(i), directionSharpness);
    combinedWeights(i) = baseProb(i) * affinity;
end

if sum(combinedWeights) <= 0
    combinedWeights = ones(size(combinedWeights)) ./ numel(combinedWeights);
else
    combinedWeights = combinedWeights ./ sum(combinedWeights);
end

%% =========================
% 4. UNIFY BRANCHES
% ==========================

unifiedFinal   = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);
unifiedHistory = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);
unifiedDelta   = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);
unifiedMotion  = zeros(OUT_SIZE(1), OUT_SIZE(2), 3);

for i = 1:nBranches
    w = combinedWeights(i);

    unifiedFinal   = unifiedFinal   + w .* branchFinal{i};
    unifiedHistory = unifiedHistory + w .* branchHistory{i};
    unifiedDelta   = unifiedDelta   + w .* branchDelta{i};
    unifiedMotion  = unifiedMotion  + w .* branchMotion{i};
end

unifiedBase = ...
    W.final_image    .* unifiedFinal + ...
    W.frame_history  .* unifiedHistory + ...
    W.temporal_delta .* unifiedDelta + ...
    W.motion_energy  .* unifiedMotion;

unifiedBase = normalize01_rgb(unifiedBase);

%% =========================
% 5. DIRECT LIVING IMAGE
% ==========================

directionLayer = build_direction_layer(OUT_SIZE, directionAngleDeg, pulsePhase);
edgeLayer = edge_rgb(unifiedBase);
glowLayer = gaussian_blur_rgb(unifiedBase, 5.0);

living = ...
    (1.00 - directionStrength) .* unifiedBase + ...
    directionStrength .* directionLayer;

living = normalize01_rgb(living);

living = living + glowStrength .* glowLayer;
living = living + edgeStrength .* edgeLayer;

living = normalize01_rgb(living);

living = vivid_color(living, saturationBoost, valueBoost, contrastBoost);

%% =========================
% 6. SAVE
% ==========================

mainImagePath = fullfile(OUT_DIR, '1111_direct_living_unified_pattern_image.png');
weightsPath   = fullfile(OUT_DIR, '2222_direction_weights.csv');
reportPath    = fullfile(OUT_DIR, '3333_direct_living_unified_report.json');

imwrite(living, mainImagePath);

write_weights_csv(weightsPath, T, branchNames, branchLabels, branchAngles, baseProb, combinedWeights);

report = struct();
report.project = PROJECT_NAME;
report.root_dir = ROOT_DIR;
report.output_dir = OUT_DIR;
report.main_image = mainImagePath;
report.directionAngleDeg = directionAngleDeg;
report.timeBias = timeBias;
report.directionSharpness = directionSharpness;
report.saturationBoost = saturationBoost;
report.valueBoost = valueBoost;
report.contrastBoost = contrastBoost;
report.glowStrength = glowStrength;
report.edgeStrength = edgeStrength;
report.directionStrength = directionStrength;
report.pulsePhase = pulsePhase;
report.branch_count = nBranches;

write_json(reportPath, report);

fprintf('\nDONE.\n');
fprintf('Direct living unified image created.\n\n');
fprintf('Main image:\n%s\n', mainImagePath);
fprintf('Weights:\n%s\n', weightsPath);
fprintf('Report:\n%s\n', reportPath);
fprintf('Folder:\n%s\n', OUT_DIR);

%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function [angleDeg, label] = map_branch_to_angle(name)

    s = lower(char(name));

    if ~isempty(strfind(s, 'high_coherence'))
        angleDeg = 0;
        label = "coherence_axis";
    elseif ~isempty(strfind(s, 'radial_expansion'))
        angleDeg = 45;
        label = "radial_axis";
    elseif ~isempty(strfind(s, 'symmetry_lock'))
        angleDeg = 90;
        label = "symmetry_axis";
    elseif ~isempty(strfind(s, 'spiral_time'))
        angleDeg = 135;
        label = "spiral_axis";
    elseif ~isempty(strfind(s, 'gradient_follow'))
        angleDeg = 180;
        label = "gradient_axis";
    elseif ~isempty(strfind(s, 'noise_escape'))
        angleDeg = 225;
        label = "escape_axis";
    elseif ~isempty(strfind(s, 'center_convergence'))
        angleDeg = 270;
        label = "center_axis";
    elseif ~isempty(strfind(s, 'balanced_future_option'))
        angleDeg = 315;
        label = "balanced_axis";
    else
        angleDeg = 0;
        label = "default_axis";
    end
end

function a = directional_affinity(queryAngleDeg, branchAngleDeg, sharpness)

    d = mod((queryAngleDeg - branchAngleDeg) + 180, 360) - 180;
    a = exp(sharpness * cosd(d));

    if ~isfinite(a)
        a = 0;
    end
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
        error('No frames found in: %s', frameDir);
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

function D = build_direction_layer(outSize, directionAngleDeg, pulsePhase)

    [x, y] = meshgrid(linspace(-1,1,outSize(2)), linspace(-1,1,outSize(1)));

    theta = atan2d(y, x);
    r = sqrt(x.^2 + y.^2);

    align = cosd(theta - directionAngleDeg);
    align = normalize01(align);

    wave1 = sin(10*pi*r + deg2rad(directionAngleDeg) + 2*pi*pulsePhase);
    wave2 = cosd(6*theta - 2*directionAngleDeg);

    wave = normalize01(0.55*wave1 + 0.45*wave2);

    hue = normalize01((theta + 180) ./ 360 + 0.18*wave);
    sat = normalize01(0.38 + 0.42*align + 0.30*wave);
    val = normalize01(0.20 + 0.48*align + 0.32*(1-r) + 0.25*wave);

    D = hsv2rgb(cat(3, hue, sat, val));
    D = normalize01_rgb(D);
end

function E = edge_rgb(I)

    G = rgb2gray_local(I);
    [Gx, Gy] = gradient(G);
    E0 = sqrt(Gx.^2 + Gy.^2);
    E0 = normalize01(E0);

    E = repmat(E0, 1, 1, 3);
end

function B = gaussian_blur_rgb(A, sigma)

    B = zeros(size(A));

    for c = 1:size(A,3)
        B(:,:,c) = gaussian_blur2(A(:,:,c), sigma);
    end

    B = normalize01_rgb(B);
end

function V = vivid_color(I, satBoost, valBoost, contrastBoost)

    I = normalize01_rgb(I);

    HSV = rgb2hsv(I);

    H = HSV(:,:,1);
    S = HSV(:,:,2);
    Vv = HSV(:,:,3);

    S = min(S .* satBoost, 1);
    Vv = min(Vv .* valBoost, 1);

    RGB = hsv2rgb(cat(3, H, S, Vv));
    RGB = normalize01_rgb(RGB);

    RGB = (RGB - 0.5) .* contrastBoost + 0.5;
    RGB = min(max(RGB, 0), 1);

    V = RGB;
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

function write_weights_csv(path, T, branchNames, branchLabels, branchAngles, baseProb, combinedWeights)

    fid = fopen(path, 'w');
    fprintf(fid, 'branch_id,branch_name,direction_label,direction_angle_deg,base_probability,combined_weight,folder\n');

    for i = 1:numel(branchNames)
        fprintf(fid, '%d,"%s","%s",%.17g,%.17g,%.17g,"%s"\n', ...
            i, ...
            char(branchNames(i)), ...
            char(branchLabels(i)), ...
            branchAngles(i), ...
            baseProb(i), ...
            combinedWeights(i), ...
            char(T.folder(i)));
    end

    fclose(fid);
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