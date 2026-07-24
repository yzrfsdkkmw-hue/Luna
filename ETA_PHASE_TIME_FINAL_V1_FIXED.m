%% ETA_PHASE_TIME_FINAL_V1
% Final Eta Phase / time-motion reader.
%
% Purpose:
% Use the summary Eta Phase image as the visual anchor and produce one
% final focused set of images:
%   - eta phase base
%   - structural corridor
%   - motion/time frames
%   - motion energy
%   - final focus map
%
% IMPORTANT:
% - Pixel-only analysis. This script does not read or trust PNG metadata.
% - It does not modify H5 or previous outputs.
% - It writes a single final output folder.
%
% Expected optional files in the current folder:
%   eta_phase_summary.png   OR   Eta-Phase - qnt.png
%   matlab.csv              optional numeric constants

clear; clc; close all;

%% 0) Setup

outDir = "9999_FINAL_ETA_PHASE_TIME";
if ~exist(outDir, "dir")
    mkdir(outDir);
end

nFrames = 96;
nStripFrames = 12;
rng(777, "twister");

fprintf("ETA_PHASE_TIME_FINAL_V1\n");
fprintf("=======================\n\n");

%% 1) Read image, pixels only

imgPath = findInputImage();

fprintf("Input image: %s\n", imgPath);

[A, RGB, alphaMask] = readImagePixelsOnly(imgPath);

[H, W, ~] = size(RGB);
fprintf("Image size: %d x %d\n\n", H, W);

%% 2) Read optional numeric constants

csvPath = "matlab.csv";
K = readNumericConstants(csvPath);

fprintf("Numeric constants loaded:\n");
fprintf("  roots        = %.6f\n", K.roots);
fprintf("  projections  = %.6f\n", K.projections);
fprintf("  heptad       = %.6f\n", K.heptad);
fprintf("  pcount       = %.6f\n", K.pcount);
fprintf("  waves        = %.6f\n", K.waves);
fprintf("  circles      = %.6f\n", K.circles);
fprintf("  zeta         = %.6f\n", K.zeta);
fprintf("  edge_mean    = %.6f\n", K.edge_mean);
fprintf("  grand_mean   = %.6f\n\n", K.grand_mean);

%% 3) Build coordinate system and circular field mask

fprintf("Building coordinate fields...\n");

[x, y] = meshgrid(linspace(-1,1,W), linspace(-1,1,H));
r = sqrt(x.^2 + y.^2);
theta = atan2(y,x);

gray = rgb2gray(RGB);
gray = normalize01Safe(gray);

sat = getSaturation(RGB);
hue = getHue(RGB);

% Circular mask: prefer alpha if present, otherwise detect non-black circle
bodyMask = alphaMask;
if mean(bodyMask(:)) < 0.05
    bodyMask = gray > quantile(gray(:), 0.04);
end
bodyMask = conv2(double(bodyMask), ones(9), "same") > 0;
bodyMask = bodyMask & (r < 1.02);

% Inner disk avoids the outer hard black border
innerMask = bodyMask & (r < 0.985);

%% 4) Pixel-derived channels

fprintf("Building pixel-derived channels...\n");

% Color signatures. These are not interpreted as semantic labels;
% they are just pixel-color channels.
cyanMap   = normalize01Safe(0.50 * RGB(:,:,2) + 0.50 * RGB(:,:,3) - 0.35 * RGB(:,:,1));
greenMap  = normalize01Safe(RGB(:,:,2) - 0.35 * RGB(:,:,1) - 0.20 * RGB(:,:,3));
purpleMap = normalize01Safe(0.55 * RGB(:,:,1) + 0.75 * RGB(:,:,3) - 0.45 * RGB(:,:,2));
brightMap = normalize01Safe(gray .* (0.45 + 0.55 * sat));

% Source smoothing and high frequency
S_low = imgaussfilt(gray, 7);
S_high = normalize01Safe(gray - imgaussfilt(gray, 20));

% Gradient / ridge / coherence
[Gx, Gy] = gradient(S_low);
Gmag = normalize01Safe(sqrt(Gx.^2 + Gy.^2));

L = normalize01Safe(abs(del2(S_low)));
Hess = hessianMagnitude(S_low);
Coherence = structureCoherence(S_low);

% Edges from multiple color/ridge channels
edgeA = edge(normalize01Safe(gray), "canny");
edgeB = edge(normalize01Safe(cyanMap), "canny");
edgeC = edge(normalize01Safe(purpleMap), "canny");
edgeD = edge(normalize01Safe(Gmag), "canny");

EdgeUnion = double(edgeA | edgeB | edgeC | edgeD);
EdgeSoft = normalize01Safe(imgaussfilt(EdgeUnion, 1.2));

% Diamond / radial / angular carriers
diamondCarrier = normalize01Safe(1 - abs(abs(x) + abs(y) - 0.82));
radialCarrier  = normalize01Safe(cos(2*pi*(K.projections + 1) * r + K.edge_mean * 10));
angularCarrier = normalize01Safe(cos(round(max(3,K.heptad)) * theta + K.grand_mean * 2*pi));
waveCarrier    = normalize01Safe(cos(2*pi*(K.waves/10) * r - K.zeta * theta / 10));

%% 5) Eta phase base

fprintf("Building eta phase base...\n");

etaPhaseBase = normalize01Safe( ...
    0.18 * cyanMap + ...
    0.16 * purpleMap + ...
    0.12 * greenMap + ...
    0.12 * S_high + ...
    0.12 * Coherence + ...
    0.10 * Gmag + ...
    0.08 * diamondCarrier + ...
    0.07 * angularCarrier + ...
    0.05 * waveCarrier );

etaPhaseBase(~innerMask) = 0;

%% 6) Final structural corridor
% This is the final non-metaphorical focus map:
% "Where do phase, ridge, edge, and color salience overlap?"

fprintf("Building final focus/corridor maps...\n");

structureCorridor = normalize01Safe( ...
    0.22 * etaPhaseBase + ...
    0.18 * Gmag + ...
    0.16 * Coherence + ...
    0.14 * L + ...
    0.12 * Hess + ...
    0.10 * EdgeSoft + ...
    0.08 * brightMap );

structureCorridor(~innerMask) = 0;

candidateScore = normalize01Safe( ...
    structureCorridor .* ...
    (0.55 + 0.45 * etaPhaseBase) .* ...
    (0.55 + 0.45 * EdgeSoft) .* ...
    (0.55 + 0.45 * Coherence) );

candidateScore(~innerMask) = 0;

thr = quantile(candidateScore(innerMask), 0.992);
candidateMask = candidateScore >= thr;
candidateMask = conv2(double(candidateMask), ones(3), "same") >= 2;
candidateMask = candidateMask & innerMask;

%% 7) Time-moving Eta Phase frames

fprintf("Generating eta time frames: %d frames...\n", nFrames);

frames = zeros(H, W, nFrames);
phaseFrames = zeros(H, W, nFrames);

% Phase constants from CSV, used only as numeric harmonics.
omega1 = 2*pi * max(0.25, K.edge_mean * 7);
omega2 = 2*pi * max(0.35, K.grand_mean);
h1 = max(3, round(K.heptad));
h2 = max(4, round(K.pcount));
h3 = max(5, round(K.projections + 2));

for t = 1:nFrames
    tau = (t-1) / max(1,nFrames-1);
    phi = 2*pi*tau;

    movingPhase = normalize01Safe( ...
        0.28 * cos(h1*theta + omega1*tau + 5*r) + ...
        0.22 * sin(h2*theta - omega2*tau + 7*r) + ...
        0.18 * cos(h3*pi*r - phi) + ...
        0.16 * radialCarrier + ...
        0.16 * angularCarrier );

    pulse = normalize01Safe( ...
        0.45 * movingPhase + ...
        0.25 * etaPhaseBase + ...
        0.18 * structureCorridor + ...
        0.12 * brightMap );

    frame = normalize01Safe( ...
        0.42 * S_low + ...
        0.16 * S_high + ...
        0.17 * etaPhaseBase + ...
        0.14 * pulse + ...
        0.11 * structureCorridor );

    frame(~innerMask) = 0;

    frames(:,:,t) = normalize01Safe(frame);
    phaseFrames(:,:,t) = movingPhase;

    if mod(t, 16) == 0 || t == nFrames
        fprintf("  frame %d / %d\n", t, nFrames);
    end
end

%% 8) Motion energy and final image

fprintf("Building motion energy and final image...\n");

motionEnergy = zeros(H,W);
for t = 2:nFrames
    motionEnergy = motionEnergy + abs(frames(:,:,t) - frames(:,:,t-1));
end
motionEnergy = normalize01Safe(motionEnergy);
motionEnergy(~innerMask) = 0;

phaseEnergy = normalize01Safe(std(phaseFrames, 0, 3));
phaseEnergy(~innerMask) = 0;

finalEtaTime = normalize01Safe( ...
    0.34 * mean(frames,3) + ...
    0.20 * etaPhaseBase + ...
    0.18 * structureCorridor + ...
    0.14 * motionEnergy + ...
    0.10 * phaseEnergy + ...
    0.04 * candidateScore );

finalEtaTime(~innerMask) = 0;

overlay = makeOverlayRGB(finalEtaTime, candidateMask, candidateScore);

%% 9) Candidate table

fprintf("Extracting final candidates...\n");

candidateTable = extractCandidateTable(candidateMask, candidateScore, structureCorridor, etaPhaseBase, motionEnergy, phaseEnergy);

%% 10) Save images

fprintf("Saving final outputs...\n");

safeImwrite(gray,              fullfile(outDir, "1111_SOURCE_GRAY.png"));
safeImwrite(etaPhaseBase,      fullfile(outDir, "2222_ETA_PHASE_BASE.png"));
safeImwrite(structureCorridor, fullfile(outDir, "3333_STRUCTURE_CORRIDOR.png"));
safeImwrite(motionEnergy,      fullfile(outDir, "4444_MOTION_ENERGY.png"));
safeImwrite(phaseEnergy,       fullfile(outDir, "5555_PHASE_ENERGY.png"));
safeImwrite(candidateScore,    fullfile(outDir, "6666_CANDIDATE_SCORE.png"));
safeImwrite(finalEtaTime,      fullfile(outDir, "7777_FINAL_ETA_TIME.png"));
safeImwrite(double(candidateMask), fullfile(outDir, "8888_CANDIDATE_MASK.png"));
imwrite(overlay,              fullfile(outDir, "0000_OVERLAY_FINAL.png"));

% obvious copies
safeImwrite(finalEtaTime,      fullfile(outDir, "111111111.png"));
safeImwrite(structureCorridor, fullfile(outDir, "222222222.png"));
safeImwrite(candidateScore,    fullfile(outDir, "333333333.png"));

writetable(candidateTable, fullfile(outDir, "1111_candidates.csv"));

%% 11) Save frame strip

fprintf("Creating frame strip...\n");

idx = round(linspace(1,nFrames,nStripFrames));

fig = figure("Visible","off","Color","w","Position",[60 60 2200 520]);
for k = 1:nStripFrames
    subplot(2, nStripFrames/2, k);
    safeShow(frames(:,:,idx(k)));
    title(sprintf("t%02d", idx(k)));
end
sgtitle("Final Eta Phase moving frames");
safeExportFigure(fig, fullfile(outDir, "9998_FRAME_STRIP.png"));
close(fig);

%% 12) Save animated GIF

fprintf("Saving animated GIF...\n");

gifPath = fullfile(outDir, "9999_ETA_PHASE_TIME.gif");
for t = 1:nFrames
    I = normalize01Safe(frames(:,:,t));
    RGBgif = ind2rgb(gray2ind(I, 256), parula(256));
    RGBgif(~repmat(innerMask,[1 1 3])) = 0;

    [Aind, map] = rgb2ind(RGBgif, 256);

    if t == 1
        imwrite(Aind, map, gifPath, "gif", "LoopCount", Inf, "DelayTime", 0.045);
    else
        imwrite(Aind, map, gifPath, "gif", "WriteMode", "append", "DelayTime", 0.045);
    end
end

%% 13) Contact sheet

fprintf("Creating contact sheet...\n");

fig = figure("Visible","off","Color","w","Position",[60 60 2200 1100]);

subplot(2,5,1); imshow(RGB); title("Input pixels only");
subplot(2,5,2); safeShow(etaPhaseBase); title("Eta phase base");
subplot(2,5,3); safeShow(structureCorridor); title("Structure corridor");
subplot(2,5,4); safeShow(motionEnergy); title("Motion energy");
subplot(2,5,5); safeShow(phaseEnergy); title("Phase energy");

subplot(2,5,6); safeShow(candidateScore); title("Candidate score");
subplot(2,5,7); safeShow(double(candidateMask)); title("Candidate mask");
subplot(2,5,8); imshow(overlay); title("Final overlay");
subplot(2,5,9); safeShow(finalEtaTime); title("Final Eta-Time");
subplot(2,5,10); safeShow(EdgeSoft); title("Edges / contours");

sgtitle("ETA PHASE TIME FINAL V1 — pixel-only, no metadata");

safeExportFigure(fig, fullfile(outDir, "0000_CONTACT_SHEET.png"));
close(fig);

%% 14) Metrics and report

fprintf("Writing metrics/report...\n");

metrics = struct();
metrics.image_height = H;
metrics.image_width = W;
metrics.source_eta_corr = safeCorr(gray, etaPhaseBase);
metrics.final_source_corr = safeCorr(finalEtaTime, gray);
metrics.final_eta_corr = safeCorr(finalEtaTime, etaPhaseBase);
metrics.final_corridor_corr = safeCorr(finalEtaTime, structureCorridor);
metrics.final_motion_corr = safeCorr(finalEtaTime, motionEnergy);
metrics.candidate_density = mean(candidateMask(:));
metrics.candidate_count = height(candidateTable);
metrics.max_candidate_score = max(candidateScore(:));
metrics.mean_candidate_score_inside_mask = mean(candidateScore(candidateMask), "omitnan");

metricNames = string(fieldnames(metrics));
metricValues = zeros(numel(metricNames),1);
for k = 1:numel(metricNames)
    metricValues(k) = metrics.(metricNames(k));
end
metricTable = table(metricNames, metricValues, "VariableNames", {"metric","value"});
writetable(metricTable, fullfile(outDir, "1111_metrics.csv"));

fid = fopen(fullfile(outDir, "1111_report.txt"), "w");
fprintf(fid, "ETA_PHASE_TIME_FINAL_V1\n");
fprintf(fid, "=======================\n\n");
fprintf(fid, "Input image: %s\n", imgPath);
fprintf(fid, "Pixel-only analysis. PNG metadata was not used.\n\n");
fprintf(fid, "Core outputs:\n");
fprintf(fid, "- 2222_ETA_PHASE_BASE.png\n");
fprintf(fid, "- 3333_STRUCTURE_CORRIDOR.png\n");
fprintf(fid, "- 4444_MOTION_ENERGY.png\n");
fprintf(fid, "- 6666_CANDIDATE_SCORE.png\n");
fprintf(fid, "- 7777_FINAL_ETA_TIME.png\n");
fprintf(fid, "- 9999_ETA_PHASE_TIME.gif\n\n");
fprintf(fid, "Meaning:\n");
fprintf(fid, "This run does not open a new search loop. It focuses the work on eta phase and time-moving structure.\n");
fprintf(fid, "The candidate table marks where the final eta/time/corridor maps overlap most strongly.\n\n");
fprintf(fid, "Metrics:\n");
for k = 1:numel(metricNames)
    fprintf(fid, "%-36s %.8f\n", metricNames(k), metricValues(k));
end
fprintf(fid, "\nTop candidates:\n");
maxRows = min(20, height(candidateTable));
for r0 = 1:maxRows
    fprintf(fid, "#%-3d x=%8.2f y=%8.2f area=%8.0f mean_score=%.6f max_score=%.6f\n", ...
        candidateTable.rank(r0), candidateTable.centroid_x(r0), candidateTable.centroid_y(r0), ...
        candidateTable.area(r0), candidateTable.mean_score(r0), candidateTable.max_score(r0));
end
fclose(fid);

%% 15) Zip

try
    zip("9999_FINAL_ETA_PHASE_TIME.zip", outDir);
catch
    warning("Could not create ZIP automatically.");
end

%% 16) Command Window summary

fprintf("\nDONE: ETA_PHASE_TIME_FINAL_V1\n");
fprintf("Outputs written to: %s\n\n", outDir);

fprintf("FINAL SUMMARY\n");
fprintf("-------------\n");
fprintf("final_source_corr:        %.6f\n", metrics.final_source_corr);
fprintf("final_eta_corr:           %.6f\n", metrics.final_eta_corr);
fprintf("final_corridor_corr:      %.6f\n", metrics.final_corridor_corr);
fprintf("final_motion_corr:        %.6f\n", metrics.final_motion_corr);
fprintf("candidate_density:        %.8f\n", metrics.candidate_density);
fprintf("candidate_count:          %d\n\n", metrics.candidate_count);

fprintf("MOST IMPORTANT FILES\n");
fprintf("--------------------\n");
fprintf("%s/0000_CONTACT_SHEET.png\n", outDir);
fprintf("%s/7777_FINAL_ETA_TIME.png\n", outDir);
fprintf("%s/9999_ETA_PHASE_TIME.gif\n", outDir);
fprintf("%s/1111_candidates.csv\n", outDir);
fprintf("9999_FINAL_ETA_PHASE_TIME.zip\n");

%% =========================
% Helper functions
% =========================

function path = findInputImage()

    candidates = {
        "eta_phase_summary.png"
        "Eta-Phase - qnt.png"
        "neutral_matlab_image_006423(1).png"
        "neutral_matlab_image_006423.png"
    };

    for i = 1:numel(candidates)
        if exist(candidates{i}, "file")
            path = candidates{i};
            return;
        end
    end

    files = dir("*.png");
    if isempty(files)
        error("No input PNG found. Put the image in this folder as eta_phase_summary.png");
    end

    % Choose the largest PNG by file size, but avoid previous output folders.
    [~, idx] = max([files.bytes]);
    path = files(idx).name;
end

function [A, RGB, alphaMask] = readImagePixelsOnly(path)

    [A, ~, alpha] = imread(path);

    if ndims(A) == 2
        RGB = repmat(im2double(A), [1 1 3]);
    else
        RGB = im2double(A(:,:,1:3));
    end

    if isempty(alpha)
        alphaMask = true(size(RGB,1), size(RGB,2));
    else
        alphaMask = im2double(alpha) > 0.05;
    end
end

function K = readNumericConstants(csvPath)

    K = struct();
    K.roots = 240;
    K.projections = 7;
    K.heptad = 7;
    K.pcount = 6;
    K.waves = 30;
    K.circles = 430;
    K.zeta = 20;
    K.euler_density = -0.083258;
    K.edge_mean = 0.139635;
    K.grand_mean = 0.440804;

    if ~exist(csvPath, "file")
        return;
    end

    try
        T = readtable(csvPath);
        if ~all(ismember(["key","value"], string(T.Properties.VariableNames)))
            return;
        end

        for i = 1:height(T)
            key = string(T.key(i));
            val = double(T.value(i));

            if ~isfinite(val)
                continue;
            end

            switch key
                case "e8_lens_root_count"
                    K.roots = val;
                case "e8_lens_projection_count"
                    K.projections = val;
                case "klein_heptad_terms"
                    K.heptad = val;
                case "padic_prime_count"
                    K.pcount = val;
                case "h3_wave_count"
                    K.waves = val;
                case "apollonian_circle_count"
                    K.circles = val;
                case "zeta_zero_count"
                    K.zeta = val;
                case "lens_euler_density"
                    K.euler_density = val;
                case "lens_edge_mean"
                    K.edge_mean = val;
                case "lens_grand_mean"
                    K.grand_mean = val;
            end
        end
    catch
        % keep defaults
    end
end

function s = getSaturation(RGB)
    HSV = rgb2hsv(RGB);
    s = normalize01Safe(HSV(:,:,2));
end

function h = getHue(RGB)
    HSV = rgb2hsv(RGB);
    h = normalize01Safe(HSV(:,:,1));
end

function H = hessianMagnitude(I)
    I = normalize01Safe(I);
    [Gx, Gy] = gradient(I);
    [Gxx, Gxy] = gradient(Gx);
    [Gyx, Gyy] = gradient(Gy);
    H = normalize01Safe(sqrt(Gxx.^2 + Gxy.^2 + Gyx.^2 + Gyy.^2) + abs(Gxx.*Gyy - Gxy.*Gyx));
end

function C = structureCoherence(I)
    I = normalize01Safe(I);
    [Gx, Gy] = gradient(I);
    sigmaJ = 4;
    J11 = imgaussfilt(Gx.^2, sigmaJ);
    J22 = imgaussfilt(Gy.^2, sigmaJ);
    J12 = imgaussfilt(Gx.*Gy, sigmaJ);
    tr = J11 + J22;
    detTerm = sqrt(max((J11-J22).^2 + 4*J12.^2, 0));
    lambda1 = 0.5 * (tr + detTerm);
    lambda2 = 0.5 * (tr - detTerm);
    C = normalize01Safe((lambda1-lambda2) ./ (lambda1+lambda2+eps));
end

function T = extractCandidateTable(mask, score, corridor, eta, motion, phaseEnergy)

    CC = bwconncomp(logical(mask), 8);

    if CC.NumObjects == 0
        T = table([], [], [], [], [], [], [], [], [], ...
            'VariableNames', {'rank','centroid_x','centroid_y','area','mean_score','max_score','mean_corridor','mean_eta','mean_motion'});
        return;
    end

    props = regionprops(CC, score, 'Area', 'Centroid', 'PixelIdxList');

    n = numel(props);
    rank = (1:n)';
    centroid_x = zeros(n,1);
    centroid_y = zeros(n,1);
    area = zeros(n,1);
    mean_score = zeros(n,1);
    max_score = zeros(n,1);
    mean_corridor = zeros(n,1);
    mean_eta = zeros(n,1);
    mean_motion = zeros(n,1);
    mean_phase_energy = zeros(n,1);
    combined = zeros(n,1);

    for i = 1:n
        idx = props(i).PixelIdxList;
        centroid_x(i) = props(i).Centroid(1);
        centroid_y(i) = props(i).Centroid(2);
        area(i) = props(i).Area;
        mean_score(i) = mean(score(idx), "omitnan");
        max_score(i) = max(score(idx));
        mean_corridor(i) = mean(corridor(idx), "omitnan");
        mean_eta(i) = mean(eta(idx), "omitnan");
        mean_motion(i) = mean(motion(idx), "omitnan");
        mean_phase_energy(i) = mean(phaseEnergy(idx), "omitnan");
    end

    combined = 0.34 * normalizeVector01(mean_score) + ...
               0.22 * normalizeVector01(area) + ...
               0.16 * normalizeVector01(mean_corridor) + ...
               0.14 * normalizeVector01(mean_eta) + ...
               0.14 * normalizeVector01(mean_motion);

    [~, ord] = sort(combined, "descend");

    T = table(rank, centroid_x, centroid_y, area, mean_score, max_score, ...
        mean_corridor, mean_eta, mean_motion, mean_phase_energy, combined, ...
        'VariableNames', {'rank','centroid_x','centroid_y','area','mean_score','max_score', ...
        'mean_corridor','mean_eta','mean_motion','mean_phase_energy','combined_rank_score'});

    T = T(ord,:);
    T.rank = (1:height(T))';
end

function RGB = makeOverlayRGB(base, mask, score)
    base = normalize01Safe(base);
    score = normalize01Safe(score);
    mask = double(mask);

    RGB = zeros([size(base),3]);
    RGB(:,:,1) = base .* 0.55 + 0.90 * mask + 0.30 * score;
    RGB(:,:,2) = base .* 0.90 + 0.25 * score;
    RGB(:,:,3) = base .* 0.80 + 0.15 * score;
    RGB = max(0, min(1, RGB));
end

function y = normalizeVector01(x)
    x = double(x);
    finiteMask = isfinite(x);
    if ~any(finiteMask(:))
        y = zeros(size(x));
        return;
    end
    xmin = min(x(finiteMask));
    xmax = max(x(finiteMask));
    if abs(xmax - xmin) < eps
        y = zeros(size(x));
    else
        y = (x - xmin) ./ (xmax - xmin);
    end
    y(~isfinite(y)) = 0;
    y = max(0, min(1,y));
end

function y = normalize01Safe(x)
    x = double(x);
    finiteMask = isfinite(x);
    if ~any(finiteMask(:))
        y = zeros(size(x));
        return;
    end
    xmin = min(x(finiteMask));
    xmax = max(x(finiteMask));
    if abs(xmax - xmin) < eps
        y = zeros(size(x));
    else
        y = (x - xmin) ./ (xmax - xmin);
    end
    y(~isfinite(y)) = 0;
    y = max(0, min(1,y));
end

function safeImwrite(I, path)
    I = normalize01Safe(I);
    imwrite(I, path);
end

function safeShow(I)
    I = normalize01Safe(I);
    imshow(I, [0 1]);
end

function c = safeCorr(A, B)
    A = double(A(:));
    B = double(B(:));
    ok = isfinite(A) & isfinite(B);
    A = A(ok);
    B = B(ok);
    if isempty(A) || isempty(B)
        c = NaN;
        return;
    end
    A = A - mean(A);
    B = B - mean(B);
    denom = sqrt(sum(A.^2) * sum(B.^2));
    if denom < eps
        c = NaN;
    else
        c = sum(A.*B) / denom;
    end
end

function safeExportFigure(fig, path)
    try
        exportgraphics(fig, path, "Resolution", 200);
    catch
        saveas(fig, path);
    end
end
