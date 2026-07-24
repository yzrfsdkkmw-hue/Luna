%% ETA_QNT_SUMMARY_PROOF_READER_V1_HEAVY
% Pixel-only analyzer for the summary Eta/QNT image.
%
% Goal:
% Turn the summary image into proof-direction maps:
% - source field mask
% - salience / ridge / diamond-ray evidence
% - bootstrap stability
% - null-control surprise
% - candidate score and overlay
%
% SAFE:
% - reads image only
% - ignores metadata as evidence
% - writes outputs to new folder only
%
% Run from the folder that contains: Eta-Phase - qnt.png

clear; clc; close all;

%% 0) Setup

inputImage = "Eta-Phase - qnt.png";
outDir = "3333_ETA_QNT_SUMMARY_READER_V1";

if ~exist(outDir, "dir")
    mkdir(outDir);
end

% Heavy controls
maxSide = 2048;          % keeps full resolution for 2048 images; lower to 1400 if MATLAB is slow
nBootstrap = 180;
nNullControls = 32;
blockSize = 64;
topQuantile = 0.992;
ridgeScales = [2 4 8 16 32];
rng(777, "twister");

fprintf("ETA_QNT_SUMMARY_PROOF_READER_V1_HEAVY\n");
fprintf("=====================================\n\n");

%% 1) Locate input image

if ~exist(inputImage, "file")
    candidates = [dir("*qnt*.png"); dir("*Eta*.png"); dir("*.png")];
    if isempty(candidates)
        error("Could not find input PNG. Put 'Eta-Phase - qnt.png' in this folder.");
    end
    inputImage = string(candidates(1).name);
end

fprintf("Reading image: %s\n", inputImage);

[RGB, Alpha, originalSize] = readRGBAlpha(inputImage);

fprintf("Original size: %d x %d\n", originalSize(1), originalSize(2));

[RGB, Alpha] = resizeToMaxSide(RGB, Alpha, maxSide);
[H, W, ~] = size(RGB);

fprintf("Working size: %d x %d\n\n", H, W);

%% 2) Basic pixel fields

fprintf("Building pixel fields...\n");

R = RGB(:,:,1);
G = RGB(:,:,2);
B = RGB(:,:,3);

Gray = normalize01Safe(0.299*R + 0.587*G + 0.114*B);
HSV = rgb2hsv(RGB);
Hue = HSV(:,:,1);
Sat = HSV(:,:,2);
Val = HSV(:,:,3);

% Cyan / magenta / green emphasis, from pixels only
CyanEnergy    = normalize01Safe(min(G, B) - R);
MagentaEnergy = normalize01Safe(min(R, B) - G);
GreenEnergy   = normalize01Safe(G - 0.5*(R+B));
ChromaEnergy  = normalize01Safe(0.45*CyanEnergy + 0.30*GreenEnergy + 0.25*MagentaEnergy);

% Approximate circular field mask from image geometry + luminance/chroma support
[X, Y] = meshgrid(1:W, 1:H);
cx0 = (W + 1) / 2;
cy0 = (H + 1) / 2;
rr = sqrt((X - cx0).^2 + (Y - cy0).^2);
rNorm = rr ./ (0.5 * min(H,W));

circlePrior = rNorm <= 0.965;
fieldSupport = normalize01Safe(0.45*Val + 0.35*Sat + 0.20*ChromaEnergy);
fieldMask = circlePrior & (fieldSupport > quantile(fieldSupport(:), 0.08));
fieldMask = conv2(double(fieldMask), ones(5), "same") > 4;
fieldMask = fieldMask & circlePrior;

%% 3) Source-derived structure fields

fprintf("Computing structure fields...\n");

F = buildSourceFields(Gray, fieldMask);

%% 4) Summary-specific geometry fields: circle, diamond, rays

fprintf("Computing circle / diamond / ray evidence...\n");

% Circle boundary evidence
circleBoundary = normalize01Safe(exp(-((rNorm - 0.94).^2) / (2*0.012^2)));
circleBoundary = normalize01Safe(circleBoundary .* (0.45 + 0.55*F.Gmag));

% Center diamond prior from geometry; it does NOT prove anything, just tests visible diamond alignment
x = (X - cx0) ./ (0.5*W);
y = (Y - cy0) ./ (0.5*H);
diamondLevel = abs(x) + abs(y);
diamondBand1 = exp(-((diamondLevel - 0.52).^2) / (2*0.025^2));
diamondBand2 = exp(-((diamondLevel - 0.82).^2) / (2*0.030^2));
diamondPrior = normalize01Safe(0.65*diamondBand1 + 0.35*diamondBand2);

% Orientation evidence: diagonal/ray-like structures
orient = F.orientationMap;
diag45  = abs(cos(2*(orient - pi/4)));
diag135 = abs(cos(2*(orient + pi/4)));
diagEvidence = normalize01Safe(max(diag45, diag135) .* F.coherenceMap .* (0.35 + 0.65*F.Gmag));

% Bright line / ray score: linear coherence + chroma + gradient
RayEvidence = normalize01Safe( ...
    0.30 * diagEvidence + ...
    0.22 * F.coherenceMap + ...
    0.20 * F.Gmag + ...
    0.16 * ChromaEnergy + ...
    0.12 * circleBoundary );

DiamondRayEvidence = normalize01Safe( ...
    0.34 * RayEvidence + ...
    0.24 * diamondPrior .* (0.45 + 0.55*F.Gmag) + ...
    0.18 * circleBoundary + ...
    0.14 * F.ridgeMap + ...
    0.10 * ChromaEnergy );

%% 5) Primary evidence map

fprintf("Building primary evidence map...\n");

Evidence = normalize01Safe( ...
    0.16 * F.Gmag + ...
    0.14 * F.coherenceMap + ...
    0.14 * F.ridgeMap + ...
    0.13 * DiamondRayEvidence + ...
    0.12 * ChromaEnergy + ...
    0.11 * F.laplacianMap + ...
    0.09 * circleBoundary + ...
    0.07 * F.S_high + ...
    0.04 * double(fieldMask) );

%% 6) Bootstrap stability

fprintf("Running bootstrap stability: %d iterations...\n", nBootstrap);

channels = cat(3, ...
    F.Gmag, ...
    F.coherenceMap, ...
    F.ridgeMap, ...
    F.hessianMap, ...
    ChromaEnergy, ...
    RayEvidence, ...
    DiamondRayEvidence, ...
    circleBoundary, ...
    F.laplacianMap, ...
    F.S_high, ...
    double(fieldMask));

Stability = zeros(H, W);

for b = 1:nBootstrap
    w = rand(1, size(channels,3));
    w = w ./ sum(w);

    M = zeros(H, W);
    for c = 1:size(channels,3)
        M = M + w(c) * channels(:,:,c);
    end

    M = normalize01Safe(imgaussfilt(M, randRange(0.35, 2.1)));
    M(~fieldMask) = 0;

    thr = quantile(M(fieldMask), topQuantile);
    mask = M >= thr;
    mask = conv2(double(mask), ones(3), "same") > 0;

    Stability = Stability + double(mask);

    if mod(b, 30) == 0
        fprintf("  bootstrap %d / %d\n", b, nBootstrap);
    end
end

Stability = normalize01Safe(Stability);

%% 7) Null controls: block shuffle

fprintf("Running null controls: %d controls...\n", nNullControls);

nullMean = zeros(H, W);
nullSq = zeros(H, W);

for n = 1:nNullControls
    GrayNull = makeBlockShuffle(Gray, blockSize);
    Fn = buildSourceFields(GrayNull, fieldMask);

    En = normalize01Safe( ...
        0.28 * Fn.Gmag + ...
        0.24 * Fn.coherenceMap + ...
        0.24 * Fn.ridgeMap + ...
        0.16 * Fn.hessianMap + ...
        0.08 * Fn.S_high );

    En(~fieldMask) = 0;
    nullMean = nullMean + En;
    nullSq = nullSq + En.^2;

    if mod(n, 8) == 0
        fprintf("  null %d / %d\n", n, nNullControls);
    end
end

nullMean = nullMean ./ nNullControls;
nullVar = max(nullSq ./ nNullControls - nullMean.^2, 0);
nullStd = sqrt(nullVar + 1e-9);

NullZ = (Evidence - nullMean) ./ nullStd;
NullSurprise = normalize01Safe(max(NullZ, 0));
NullSurprise(~fieldMask) = 0;

%% 8) Forecast / candidate score

fprintf("Building forecast maps...\n");

ProofCorridor = normalize01Safe( ...
    0.27 * Evidence + ...
    0.25 * Stability + ...
    0.20 * NullSurprise + ...
    0.16 * DiamondRayEvidence + ...
    0.08 * F.ridgeMap + ...
    0.04 * circleBoundary );
ProofCorridor(~fieldMask) = 0;

CandidateScore = normalize01Safe(ProofCorridor .* (0.55 + 0.45*Stability) .* (0.55 + 0.45*F.ridgeMap));
CandidateScore(~fieldMask) = 0;

candidateThreshold = quantile(CandidateScore(fieldMask), 0.994);
CandidateMask = CandidateScore >= candidateThreshold;
CandidateMask = conv2(double(CandidateMask), ones(3), "same") >= 2;
CandidateMask = CandidateMask & fieldMask;

UnifiedForecast = normalize01Safe( ...
    0.30 * F.S_low + ...
    0.16 * F.S_high + ...
    0.16 * ChromaEnergy + ...
    0.15 * ProofCorridor + ...
    0.11 * DiamondRayEvidence + ...
    0.08 * Stability + ...
    0.04 * NullSurprise );
UnifiedForecast(~fieldMask) = UnifiedForecast(~fieldMask) * 0.30;
UnifiedForecast = normalize01Safe(imgaussfilt(UnifiedForecast, 0.65));

Overlay = makeOverlayRGB(UnifiedForecast, CandidateMask, CandidateScore);

%% 9) Extract candidates

fprintf("Extracting candidate table...\n");

candidateTable = extractCandidateTable(CandidateMask, CandidateScore, ProofCorridor, Stability, NullSurprise, F.ridgeMap, DiamondRayEvidence);

%% 10) Save outputs

fprintf("Saving outputs...\n");

safeImwrite(rgb2graySafe(RGB),       fullfile(outDir, "1111_SOURCE_GRAY.png"));
imwrite(RGB,                         fullfile(outDir, "1112_SOURCE_RGB.png"));
safeImwrite(double(fieldMask),       fullfile(outDir, "2222_FIELD_MASK.png"));
safeImwrite(ChromaEnergy,            fullfile(outDir, "3333_CHROMA_ENERGY.png"));
safeImwrite(F.Gmag,                  fullfile(outDir, "4444_GRADIENT.png"));
safeImwrite(F.ridgeMap,              fullfile(outDir, "5555_RIDGE.png"));
safeImwrite(DiamondRayEvidence,      fullfile(outDir, "6666_DIAMOND_RAY_EVIDENCE.png"));
safeImwrite(Stability,               fullfile(outDir, "7777_BOOTSTRAP_STABILITY.png"));
safeImwrite(NullSurprise,            fullfile(outDir, "8888_NULL_SURPRISE.png"));
safeImwrite(ProofCorridor,           fullfile(outDir, "9998_PROOF_CORRIDOR.png"));
safeImwrite(CandidateScore,          fullfile(outDir, "9999_CANDIDATE_SCORE.png"));
safeImwrite(UnifiedForecast,         fullfile(outDir, "111111111.png"));
safeImwrite(ProofCorridor,           fullfile(outDir, "222222222.png"));
safeImwrite(CandidateScore,          fullfile(outDir, "333333333.png"));
imwrite(Overlay,                     fullfile(outDir, "0000_OVERLAY_CANDIDATES.png"));

writetable(candidateTable, fullfile(outDir, "1111_candidates.csv"));

%% 11) Contact sheet

fprintf("Creating contact sheet...\n");

fig = figure("Visible", "off", "Color", "w", "Position", [60 60 2300 1200]);

subplot(2,5,1); imshow(RGB); title("Source RGB");
subplot(2,5,2); safeShow(double(fieldMask)); title("Field mask");
subplot(2,5,3); safeShow(ChromaEnergy); title("Chroma energy");
subplot(2,5,4); safeShow(F.ridgeMap); title("Ridge");
subplot(2,5,5); safeShow(DiamondRayEvidence); title("Diamond / ray evidence");
subplot(2,5,6); safeShow(Stability); title("Bootstrap stability");
subplot(2,5,7); safeShow(NullSurprise); title("Null surprise");
subplot(2,5,8); safeShow(ProofCorridor); title("Proof corridor");
subplot(2,5,9); safeShow(CandidateScore); title("Candidate score");
subplot(2,5,10); imshow(Overlay); title("Overlay candidates");

sgtitle("ETA QNT SUMMARY READER V1 — pixel-only proof forecast");
safeExportFigure(fig, fullfile(outDir, "0000_CONTACT_SHEET.png"));
close(fig);

%% 12) Metrics + report

fprintf("Computing metrics...\n");

metrics = struct();
metrics.source_size_h = H;
metrics.source_size_w = W;
metrics.field_mask_density = mean(fieldMask(:));
metrics.source_retention_corr = safeCorr(UnifiedForecast, Gray);
metrics.proof_vs_evidence_corr = safeCorr(ProofCorridor, Evidence);
metrics.proof_vs_stability_corr = safeCorr(ProofCorridor, Stability);
metrics.proof_vs_nullsurprise_corr = safeCorr(ProofCorridor, NullSurprise);
metrics.proof_vs_ridge_corr = safeCorr(ProofCorridor, F.ridgeMap);
metrics.proof_vs_diamondray_corr = safeCorr(ProofCorridor, DiamondRayEvidence);
metrics.candidate_density = mean(CandidateMask(:));
metrics.top_candidate_count = height(candidateTable);
metrics.max_candidate_score = max(CandidateScore(:));
metrics.mean_candidate_score = meanNoNan(CandidateScore(CandidateMask));
metrics.max_null_z = max(NullZ(:));
metrics.mean_positive_null_z = meanNoNan(NullZ(NullZ > 0));

metricNames = fieldnames(metrics);
metricValues = zeros(numel(metricNames), 1);
for k = 1:numel(metricNames)
    metricValues(k) = metrics.(metricNames{k});
end
metricTable = table(string(metricNames), metricValues, 'VariableNames', {'metric','value'});
writetable(metricTable, fullfile(outDir, "1111_metrics.csv"));

fid = fopen(fullfile(outDir, "1111_report.txt"), "w");
fprintf(fid, "ETA_QNT_SUMMARY_PROOF_READER_V1_HEAVY\n");
fprintf(fid, "=====================================\n\n");
fprintf(fid, "Input image: %s\n", inputImage);
fprintf(fid, "Original size: %d x %d\n", originalSize(1), originalSize(2));
fprintf(fid, "Working size: %d x %d\n\n", H, W);
fprintf(fid, "This is a pixel-only analysis. Metadata is not used as proof evidence.\n\n");

fprintf(fid, "Settings:\n");
fprintf(fid, "nBootstrap: %d\n", nBootstrap);
fprintf(fid, "nNullControls: %d\n", nNullControls);
fprintf(fid, "topQuantile: %.6f\n", topQuantile);
fprintf(fid, "blockSize: %d\n\n", blockSize);

fprintf(fid, "Metrics:\n");
for k = 1:numel(metricNames)
    fprintf(fid, "%-34s %.8f\n", metricNames{k}, metricValues(k));
end

fprintf(fid, "\nTop candidates:\n");
maxRows = min(20, height(candidateTable));
for r = 1:maxRows
    fprintf(fid, "#%-3d x=%8.2f y=%8.2f area=%8.0f mean_score=%.6f max_score=%.6f stability=%.6f nullsurprise=%.6f diamondray=%.6f\n", ...
        candidateTable.rank(r), ...
        candidateTable.centroid_x(r), ...
        candidateTable.centroid_y(r), ...
        candidateTable.area(r), ...
        candidateTable.mean_score(r), ...
        candidateTable.max_score(r), ...
        candidateTable.mean_stability(r), ...
        candidateTable.mean_nullsurprise(r), ...
        candidateTable.mean_diamondray(r));
end

fprintf(fid, "\nInterpretation:\n");
fprintf(fid, "- Strong candidates are regions where pixel evidence, ridge structure, stability, and null-surprise overlap.\n");
fprintf(fid, "- This does not prove the final theorem. It tells us where proof-search should focus next.\n");
fprintf(fid, "- Next step: zoom into the top candidates and test repeatability under parameter changes.\n");
fclose(fid);

%% 13) Zip for download

try
    zip("3333_ETA_QNT_SUMMARY_READER_V1.zip", outDir);
catch
    warning("Could not create ZIP automatically.");
end

%% 14) Command Window summary

fprintf("\nDONE: ETA_QNT_SUMMARY_PROOF_READER_V1_HEAVY\n");
fprintf("Outputs written to: %s\n\n", outDir);

fprintf("TOP-LINE METRICS\n");
fprintf("----------------\n");
fprintf("source_retention_corr:       %.6f\n", metrics.source_retention_corr);
fprintf("proof_vs_evidence_corr:      %.6f\n", metrics.proof_vs_evidence_corr);
fprintf("proof_vs_stability_corr:     %.6f\n", metrics.proof_vs_stability_corr);
fprintf("proof_vs_nullsurprise_corr:  %.6f\n", metrics.proof_vs_nullsurprise_corr);
fprintf("proof_vs_ridge_corr:         %.6f\n", metrics.proof_vs_ridge_corr);
fprintf("proof_vs_diamondray_corr:    %.6f\n", metrics.proof_vs_diamondray_corr);
fprintf("candidate_density:           %.8f\n", metrics.candidate_density);
fprintf("top_candidate_count:         %d\n\n", metrics.top_candidate_count);

fprintf("MOST IMPORTANT FILES\n");
fprintf("--------------------\n");
fprintf("%s/0000_CONTACT_SHEET.png\n", outDir);
fprintf("%s/0000_OVERLAY_CANDIDATES.png\n", outDir);
fprintf("%s/111111111.png\n", outDir);
fprintf("%s/9998_PROOF_CORRIDOR.png\n", outDir);
fprintf("%s/9999_CANDIDATE_SCORE.png\n", outDir);
fprintf("%s/1111_candidates.csv\n", outDir);
fprintf("3333_ETA_QNT_SUMMARY_READER_V1.zip\n");

%% =========================
% Helper functions
% =========================

function [RGB, Alpha, originalSize] = readRGBAlpha(path)
    try
        [A, ~, Alpha] = imread(path);
    catch
        A = imread(path);
        Alpha = [];
    end

    if isempty(Alpha)
        Alpha = ones(size(A,1), size(A,2));
    else
        Alpha = im2double(Alpha);
    end

    if ndims(A) == 2
        A = repmat(A, [1 1 3]);
    end

    if size(A,3) > 3
        A = A(:,:,1:3);
    end

    RGB = im2double(A);
    originalSize = [size(RGB,1), size(RGB,2)];
end

function [RGB2, Alpha2] = resizeToMaxSide(RGB, Alpha, maxSide)
    [H, W, ~] = size(RGB);
    s = min(1, maxSide / max(H,W));

    if s < 1
        RGB2 = imresize(RGB, s);
        Alpha2 = imresize(Alpha, s);
    else
        RGB2 = RGB;
        Alpha2 = Alpha;
    end
end

function I = rgb2graySafe(RGB)
    I = normalize01Safe(0.299*RGB(:,:,1) + 0.587*RGB(:,:,2) + 0.114*RGB(:,:,3));
end

function F = buildSourceFields(I, mask)
    I = normalize01Safe(I);
    I(~mask) = I(~mask) * 0.25;

    F.S_low = imgaussfilt(I, 6);
    F.S_high = normalize01Safe(I - imgaussfilt(I, 18));

    [Gx, Gy] = gradient(F.S_low);
    F.Gmag = normalize01Safe(sqrt(Gx.^2 + Gy.^2));

    L = del2(F.S_low);
    F.laplacianMap = normalize01Safe(abs(L));

    % Structure tensor coherence + orientation
    sigmaJ = 4;
    J11 = imgaussfilt(Gx.^2, sigmaJ);
    J22 = imgaussfilt(Gy.^2, sigmaJ);
    J12 = imgaussfilt(Gx .* Gy, sigmaJ);

    tr = J11 + J22;
    detTerm = sqrt(max((J11 - J22).^2 + 4 * J12.^2, 0));
    lambda1 = 0.5 * (tr + detTerm);
    lambda2 = 0.5 * (tr - detTerm);

    coherence = (lambda1 - lambda2) ./ (lambda1 + lambda2 + eps);
    F.coherenceMap = normalize01Safe(coherence);
    F.orientationMap = 0.5 * atan2(2*J12, J11 - J22);

    [Ridge, Hessian] = multiscaleRidgeEvidence(F.S_low, [2 4 8 16 32]);
    F.ridgeMap = Ridge;
    F.hessianMap = Hessian;

    F.Gmag(~mask) = 0;
    F.coherenceMap(~mask) = 0;
    F.ridgeMap(~mask) = 0;
    F.hessianMap(~mask) = 0;
    F.laplacianMap(~mask) = 0;
end

function [Ridge, HessianMax] = multiscaleRidgeEvidence(I, scales)
    I = normalize01Safe(I);
    [H, W] = size(I);

    RidgeStack = zeros(H, W, numel(scales));
    HessStack = zeros(H, W, numel(scales));

    for s = 1:numel(scales)
        sigma = scales(s);
        G = imgaussfilt(I, sigma);

        [Gx, Gy] = gradient(G);
        [Gxx, Gxy] = gradient(Gx);
        [Gyx, Gyy] = gradient(Gy);

        Hmag = sqrt(Gxx.^2 + Gxy.^2 + Gyx.^2 + Gyy.^2);
        Hdet = abs(Gxx .* Gyy - Gxy .* Gyx);

        ridgeRaw = normalize01Safe(Hmag .* (1 + Hdet));
        ridgeRaw = normalize01Safe(ridgeRaw .* (0.5 + 0.5 * normalize01Safe(abs(del2(G)))));

        RidgeStack(:,:,s) = ridgeRaw;
        HessStack(:,:,s) = normalize01Safe(Hmag + Hdet);
    end

    Ridge = max(RidgeStack, [], 3);
    HessianMax = max(HessStack, [], 3);
end

function S2 = makeBlockShuffle(S, blockSize)
    S = normalize01Safe(S);
    [H, W] = size(S);
    S2 = zeros(H, W);

    rows = 1:blockSize:H;
    cols = 1:blockSize:W;
    blocks = {};

    for r = rows
        for c = cols
            rr = r:min(r+blockSize-1,H);
            cc = c:min(c+blockSize-1,W);
            blocks{end+1} = S(rr,cc); %#ok<AGROW>
        end
    end

    order = randperm(numel(blocks));
    q = 1;

    for r = rows
        for c = cols
            rr = r:min(r+blockSize-1,H);
            cc = c:min(c+blockSize-1,W);

            B = blocks{order(q)};
            B = imresize(B, [numel(rr), numel(cc)]);

            if rand < 0.5
                B = fliplr(B);
            end
            if rand < 0.5
                B = flipud(B);
            end

            S2(rr,cc) = B;
            q = q + 1;
        end
    end

    S2 = normalize01Safe(S2);
end

function T = extractCandidateTable(mask, score, proof, stability, nullsurprise, ridge, diamondray)
    mask = logical(mask);
    CC = bwconncomp(mask, 8);

    if CC.NumObjects == 0
        T = table([], [], [], [], [], [], [], [], [], [], [], ...
            'VariableNames', {'rank','centroid_x','centroid_y','area','mean_score','max_score','mean_stability','mean_nullsurprise','mean_ridge','mean_diamondray','combined_rank_score'});
        return;
    end

    props = regionprops(CC, score, 'Area', 'Centroid', 'PixelIdxList');
    n = numel(props);

    centroid_x = zeros(n,1);
    centroid_y = zeros(n,1);
    area = zeros(n,1);
    mean_score = zeros(n,1);
    max_score = zeros(n,1);
    mean_stability = zeros(n,1);
    mean_nullsurprise = zeros(n,1);
    mean_ridge = zeros(n,1);
    mean_diamondray = zeros(n,1);
    mean_proof = zeros(n,1);

    for i = 1:n
        idx = props(i).PixelIdxList;
        centroid_x(i) = props(i).Centroid(1);
        centroid_y(i) = props(i).Centroid(2);
        area(i) = props(i).Area;
        mean_score(i) = meanNoNan(score(idx));
        max_score(i) = max(score(idx));
        mean_stability(i) = meanNoNan(stability(idx));
        mean_nullsurprise(i) = meanNoNan(nullsurprise(idx));
        mean_ridge(i) = meanNoNan(ridge(idx));
        mean_diamondray(i) = meanNoNan(diamondray(idx));
        mean_proof(i) = meanNoNan(proof(idx));
    end

    combined = normalize01Vector( ...
        0.22 * normalize01Vector(area) + ...
        0.20 * normalize01Vector(mean_score) + ...
        0.18 * normalize01Vector(mean_stability) + ...
        0.16 * normalize01Vector(mean_nullsurprise) + ...
        0.14 * normalize01Vector(mean_ridge) + ...
        0.10 * normalize01Vector(mean_diamondray));

    [~, ord] = sort(combined, 'descend');

    rank = (1:n)';
    T = table(rank, centroid_x, centroid_y, area, mean_score, max_score, mean_stability, mean_nullsurprise, mean_ridge, mean_diamondray, mean_proof, combined, ...
        'VariableNames', {'rank','centroid_x','centroid_y','area','mean_score','max_score','mean_stability','mean_nullsurprise','mean_ridge','mean_diamondray','mean_proof','combined_rank_score'});

    T = T(ord,:);
    T.rank = (1:height(T))';
end

function RGB = makeOverlayRGB(base, mask, score)
    base = normalize01Safe(base);
    score = normalize01Safe(score);
    mask = double(mask);

    RGB = zeros([size(base), 3]);
    RGB(:,:,1) = base .* 0.55 + 0.95*mask + 0.45*score;
    RGB(:,:,2) = base .* 0.85 + 0.25*score;
    RGB(:,:,3) = base .* 0.95;
    RGB = max(0, min(1, RGB));
end

function y = normalize01Vector(x)
    x = double(x);
    ok = isfinite(x);
    if ~any(ok)
        y = zeros(size(x));
        return;
    end
    xmin = min(x(ok));
    xmax = max(x(ok));
    if abs(xmax-xmin) < eps
        y = zeros(size(x));
    else
        y = (x - xmin) ./ (xmax - xmin);
    end
    y(~isfinite(y)) = 0;
    y = max(0, min(1, y));
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
    y = max(0, min(1, y));
end

function m = meanNoNan(x)
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = mean(x);
    end
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
        c = sum(A .* B) / denom;
    end
end

function x = randRange(a,b)
    x = a + (b-a)*rand();
end

function safeImwrite(I, path)
    I = normalize01Safe(I);
    imwrite(I, path);
end

function safeShow(I)
    I = normalize01Safe(I);
    imshow(I, [0 1]);
end

function safeExportFigure(fig, path)
    try
        exportgraphics(fig, path, "Resolution", 200);
    catch
        saveas(fig, path);
    end
end
