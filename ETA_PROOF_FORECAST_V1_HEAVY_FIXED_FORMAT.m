%% ETA_PROOF_FORECAST_V1_HEAVY_FIXED_FORMAT
% Vertical MATLAB script. Paste into a NEW SCRIPT / .m file, not Command Window.
% Reads H5 + optional TimeKernel and writes proof-forecast eta images.

clear; clc; close all;

%% 0) Setup
outDir = "1111_ETA_PROOF_FORECAST_V1";
if ~exist(outDir, "dir")
    mkdir(outDir);
end

preferredH5 = "jsonhotel_unified_001_002_SAFE_20260628_181406.h5";
preferredDataset = "/n_5_composite_field_1000x1000/data";

timeZipName = "time.zip";
timeFolderName = "time";
phaseCsvName = "projectVectorVision_timeKernel_20260706_222533_phase_schedule.csv";
summaryJsonName = "projectVectorVision_timeKernel_20260706_222533_summary.json";

targetSize = [1000 1000];

ridgeScales = [2 4 8 16 32];
nNullControls = 36;
nBootstrap = 120;
topQuantile = 0.985;

rng(240, "twister");

fprintf("ETA_PROOF_FORECAST_V1_HEAVY_FIXED_FORMAT\n");
fprintf("========================================\n\n");

%% 1) Read H5 source
fprintf("Reading H5 source...\n");
[S, h5Used, datasetUsed] = readSourceFromH5(preferredH5, preferredDataset, targetSize);
fprintf("H5 file: %s\n", h5Used);
fprintf("Dataset: %s\n\n", datasetUsed);

%% 2) Read optional TimeKernel
fprintf("Reading optional TimeKernel...\n");

hasTime = false;
T = table();

if ~exist(timeFolderName, "dir") && exist(timeZipName, "file")
    fprintf("Extracting %s ...\n", timeZipName);
    unzip(timeZipName);
end

phaseCsvPath = fullfile(timeFolderName, phaseCsvName);
summaryJsonPath = fullfile(timeFolderName, summaryJsonName);

if exist(phaseCsvPath, "file")
    T = readtable(phaseCsvPath);
    T = sanitizePhaseTable(T);
    hasTime = true;

    if exist(summaryJsonPath, "file")
        summaryStruct = jsondecode(fileread(summaryJsonPath)); %#ok<NASGU>
    end

    fprintf("TimeKernel loaded: %d peaks\n\n", height(T));
else
    fprintf("No TimeKernel found. Continuing with source-only eta fields.\n\n");
end

%% 3) Build source fields
fprintf("Building source fields...\n");
F = buildSourceFields(S);

%% 4) Build eta maps
fprintf("Building eta maps...\n");
if hasTime
    TM = buildTimeMaps(S, T);
else
    TM = buildFallbackEtaMaps(S, F);
end

%% 5) Multiscale ridge evidence
fprintf("Computing multiscale ridge evidence...\n");
[Ridge, HessianMax, RidgeScaleMap] = multiscaleRidgeEvidence(F.S_low, ridgeScales); %#ok<ASGLU>

%% 6) Primary evidence map
fprintf("Building primary evidence map...\n");

Evidence = normalize01Safe( ...
    0.18 * F.Gmag + ...
    0.18 * F.coherenceMap + ...
    0.16 * Ridge + ...
    0.14 * HessianMax + ...
    0.12 * TM.anchorMap + ...
    0.10 * TM.phaseEnergy + ...
    0.08 * F.S_high + ...
    0.04 * TM.intervalMap );

%% 7) Bootstrap stability map
fprintf("Running bootstrap stability: %d iterations...\n", nBootstrap);

channels = cat(3, ...
    F.Gmag, ...
    F.coherenceMap, ...
    Ridge, ...
    HessianMax, ...
    TM.anchorMap, ...
    TM.phaseEnergy, ...
    TM.intervalMap, ...
    F.S_high, ...
    F.laplacianMap, ...
    F.taylorField);

Stability = zeros(size(S));

for b = 1:nBootstrap
    w = rand(1, size(channels, 3));
    w = w ./ sum(w);

    M = zeros(size(S));
    for c = 1:size(channels, 3)
        M = M + w(c) * channels(:,:,c);
    end

    M = normalize01Safe(imgaussfilt(M, randRange(0.4, 2.2)));
    thr = quantile(M(:), topQuantile);
    mask = M >= thr;

    maskSoft = conv2(double(mask), ones(3), "same") > 0;
    Stability = Stability + double(maskSoft);

    if mod(b, 20) == 0
        fprintf("  bootstrap %d / %d\n", b, nBootstrap);
    end
end

Stability = normalize01Safe(Stability);

%% 8) Null controls
fprintf("Running null controls: %d controls...\n", nNullControls);

nullMean = zeros(size(S));
nullSq = zeros(size(S));

for n = 1:nNullControls
    Snull = makeBlockShuffle(S, 50);
    Fn = buildSourceFields(Snull);

    [Rn, Hn, ~] = multiscaleRidgeEvidence(Fn.S_low, ridgeScales);

    En = normalize01Safe( ...
        0.28 * Fn.Gmag + ...
        0.24 * Fn.coherenceMap + ...
        0.24 * Rn + ...
        0.16 * Hn + ...
        0.08 * Fn.S_high );

    nullMean = nullMean + En;
    nullSq = nullSq + En.^2;

    if mod(n, 6) == 0
        fprintf("  null %d / %d\n", n, nNullControls);
    end
end

nullMean = nullMean ./ nNullControls;
nullVar = max(nullSq ./ nNullControls - nullMean.^2, 0);
nullStd = sqrt(nullVar + 1e-9);

NullZ = (Evidence - nullMean) ./ nullStd;
NullSurprise = normalize01Safe(max(NullZ, 0));

%% 9) Proof corridor and candidate map
fprintf("Building proof forecast map...\n");

ProofCorridor = normalize01Safe( ...
    0.34 * Evidence + ...
    0.30 * Stability + ...
    0.22 * NullSurprise + ...
    0.08 * TM.anchorMap + ...
    0.06 * Ridge );

CandidateScore = normalize01Safe( ...
    ProofCorridor .* ...
    (0.65 + 0.35 * Ridge) .* ...
    (0.65 + 0.35 * Stability) );

candidateThreshold = quantile(CandidateScore(:), 0.992);
CandidateMask = CandidateScore >= candidateThreshold;

CandidateMask = conv2(double(CandidateMask), ones(3), "same") >= 2;
CandidateMask = CandidateMask > 0;

%% 10) Unified eta proof image
fprintf("Creating unified eta-proof image...\n");

UnifiedEtaProof = normalize01Safe( ...
    0.34 * F.S_low + ...
    0.12 * F.S_high + ...
    0.16 * TM.timeEta + ...
    0.16 * ProofCorridor + ...
    0.10 * Stability + ...
    0.08 * NullSurprise + ...
    0.04 * Ridge );

UnifiedEtaProof = normalize01Safe(imgaussfilt(UnifiedEtaProof, 0.7));
Overlay = makeOverlayRGB(UnifiedEtaProof, CandidateMask, ProofCorridor);

%% 11) Candidate extraction
fprintf("Extracting candidate components...\n");
candidateTable = extractCandidateTable(CandidateMask, CandidateScore, ProofCorridor, Stability, NullSurprise, Ridge);

%% 12) Save outputs
fprintf("Saving outputs...\n");

safeImwrite(S,              fullfile(outDir, "1111_SOURCE.png"));
safeImwrite(TM.timeEta,      fullfile(outDir, "2222_TIME_ETA.png"));
safeImwrite(Evidence,        fullfile(outDir, "3333_EVIDENCE.png"));
safeImwrite(Ridge,           fullfile(outDir, "4444_RIDGE.png"));
safeImwrite(Stability,       fullfile(outDir, "5555_STABILITY.png"));
safeImwrite(NullSurprise,    fullfile(outDir, "6666_NULL_SURPRISE.png"));
safeImwrite(ProofCorridor,   fullfile(outDir, "7777_PROOF_CORRIDOR.png"));
safeImwrite(CandidateScore,  fullfile(outDir, "8888_CANDIDATE_SCORE.png"));
safeImwrite(UnifiedEtaProof, fullfile(outDir, "9999_UNIFIED_ETA_PROOF.png"));
imwrite(Overlay,             fullfile(outDir, "0000_OVERLAY_CANDIDATES.png"));

safeImwrite(UnifiedEtaProof, fullfile(outDir, "111111111.png"));
safeImwrite(ProofCorridor,   fullfile(outDir, "222222222.png"));
safeImwrite(CandidateScore,  fullfile(outDir, "333333333.png"));

writetable(candidateTable, fullfile(outDir, "1111_candidates.csv"));

%% 13) Contact sheet
fprintf("Creating contact sheet...\n");

fig = figure("Color", "w", "Position", [60 60 2100 1100]);

subplot(2,5,1);
safeShow(S);
title("Source H5");

subplot(2,5,2);
safeShow(TM.timeEta);
title("Time / Eta");

subplot(2,5,3);
safeShow(Evidence);
title("Evidence");

subplot(2,5,4);
safeShow(Ridge);
title("Multiscale Ridge");

subplot(2,5,5);
safeShow(Stability);
title("Bootstrap Stability");

subplot(2,5,6);
safeShow(NullSurprise);
title("Null Surprise");

subplot(2,5,7);
safeShow(ProofCorridor);
title("Proof Corridor");

subplot(2,5,8);
safeShow(CandidateScore);
title("Candidate Score");

subplot(2,5,9);
imshow(Overlay);
title("Overlay Candidates");

subplot(2,5,10);
safeShow(UnifiedEtaProof);
title("Unified Eta Proof");

sgtitle("ETA PROOF FORECAST V1 HEAVY — source + eta + stability + null controls");
safeExportFigure(fig, fullfile(outDir, "0000_CONTACT_SHEET.png"));
close(fig);

%% 14) Metrics
fprintf("Computing metrics...\n");

metrics = struct();

metrics.source_retention_corr = safeCorr(UnifiedEtaProof, S);
metrics.evidence_vs_source_corr = safeCorr(Evidence, S);
metrics.proof_vs_evidence_corr = safeCorr(ProofCorridor, Evidence);
metrics.proof_vs_stability_corr = safeCorr(ProofCorridor, Stability);
metrics.proof_vs_nullsurprise_corr = safeCorr(ProofCorridor, NullSurprise);
metrics.proof_vs_ridge_corr = safeCorr(ProofCorridor, Ridge);
metrics.candidate_density = mean(CandidateMask(:));
metrics.mean_candidate_score = mean(CandidateScore(CandidateMask), "omitnan");
metrics.max_candidate_score = max(CandidateScore(:));
metrics.mean_null_z_positive = mean(NullZ(NullZ > 0), "omitnan");
metrics.max_null_z = max(NullZ(:));
metrics.bootstrap_survival_mean = mean(Stability(:));
metrics.bootstrap_survival_max = max(Stability(:));
metrics.top_candidate_count = height(candidateTable);

metricNames = string(fieldnames(metrics));
metricValues = zeros(numel(metricNames), 1);

for k = 1:numel(metricNames)
    metricValues(k) = metrics.(metricNames(k));
end

metricTable = table(metricNames, metricValues, ...
    "VariableNames", {"metric","value"});

writetable(metricTable, fullfile(outDir, "1111_metrics.csv"));

%% 15) Report
fprintf("Writing report...\n");

fid = fopen(fullfile(outDir, "1111_report.txt"), "w");

fprintf(fid, "ETA_PROOF_FORECAST_V1_HEAVY_FIXED_FORMAT\n");
fprintf(fid, "========================================\n\n");

fprintf(fid, "Purpose:\n");
fprintf(fid, "This run does not prove the structure directly.\n");
fprintf(fid, "It creates a proof-forecast map: where to test proof first.\n\n");

fprintf(fid, "H5 file: %s\n", h5Used);
fprintf(fid, "Dataset: %s\n\n", datasetUsed);

fprintf(fid, "Settings:\n");
fprintf(fid, "ridgeScales: ");
fprintf(fid, "%g ", ridgeScales);
fprintf(fid, "\n");
fprintf(fid, "nNullControls: %d\n", nNullControls);
fprintf(fid, "nBootstrap: %d\n", nBootstrap);
fprintf(fid, "topQuantile: %.5f\n", topQuantile);
fprintf(fid, "hasTimeKernel: %d\n\n", hasTime);

fprintf(fid, "Top-line metrics:\n");
for k = 1:numel(metricNames)
    fprintf(fid, "%-32s %.8f\n", char(metricNames(k)), metricValues(k));
end

fprintf(fid, "\nTop candidates:\n");
maxRows = min(20, height(candidateTable));

for r = 1:maxRows
    fprintf(fid, ...
        "#%-3d centroid_x=%8.2f centroid_y=%8.2f area=%8.0f mean_score=%.6f max_score=%.6f mean_stability=%.6f mean_nullsurprise=%.6f\n", ...
        r, ...
        candidateTable.centroid_x(r), ...
        candidateTable.centroid_y(r), ...
        candidateTable.area(r), ...
        candidateTable.mean_score(r), ...
        candidateTable.max_score(r), ...
        candidateTable.mean_stability(r), ...
        candidateTable.mean_nullsurprise(r));
end

fprintf(fid, "\nInterpretation:\n");
fprintf(fid, "- Strong regions are places where evidence, stability, ridge structure, and null-surprise overlap.\n");
fprintf(fid, "- A real proof direction should start from top candidate corridors, not from visual interpretation alone.\n");
fprintf(fid, "- Next test: reproduce this map, run controls, and compare candidate locations across runs.\n");

fclose(fid);

%% 16) Command Window summary
fprintf("\nDONE: ETA_PROOF_FORECAST_V1_HEAVY_FIXED_FORMAT\n");
fprintf("Outputs written to: %s\n\n", outDir);

fprintf("TOP-LINE METRICS\n");
fprintf("----------------\n");
fprintf("source_retention_corr:       %.6f\n", metrics.source_retention_corr);
fprintf("proof_vs_evidence_corr:      %.6f\n", metrics.proof_vs_evidence_corr);
fprintf("proof_vs_stability_corr:     %.6f\n", metrics.proof_vs_stability_corr);
fprintf("proof_vs_nullsurprise_corr:  %.6f\n", metrics.proof_vs_nullsurprise_corr);
fprintf("proof_vs_ridge_corr:         %.6f\n", metrics.proof_vs_ridge_corr);
fprintf("candidate_density:           %.8f\n", metrics.candidate_density);
fprintf("top_candidate_count:         %d\n\n", metrics.top_candidate_count);

fprintf("MOST IMPORTANT FILES\n");
fprintf("--------------------\n");
fprintf("%s/9999_UNIFIED_ETA_PROOF.png\n", outDir);
fprintf("%s/7777_PROOF_CORRIDOR.png\n", outDir);
fprintf("%s/8888_CANDIDATE_SCORE.png\n", outDir);
fprintf("%s/0000_OVERLAY_CANDIDATES.png\n", outDir);
fprintf("%s/0000_CONTACT_SHEET.png\n", outDir);
fprintf("%s/1111_report.txt\n", outDir);
fprintf("%s/1111_candidates.csv\n", outDir);

%% =========================
% Helper functions
% =========================

function [S, h5Used, datasetUsed] = readSourceFromH5(preferredH5, preferredDataset, targetSize)

    h5Files = dir("*.h5");

    if isempty(h5Files)
        error("No .h5 file found in current folder.");
    end

    idx = find(strcmp({h5Files.name}, preferredH5), 1);

    if isempty(idx)
        h5File = h5Files(1).name;
    else
        h5File = h5Files(idx).name;
    end

    raw = h5read(h5File, preferredDataset);
    raw = double(raw);

    if ndims(raw) > 2
        raw = raw(:,:,1);
    end

    S = normalize01Safe(raw);
    S = imresize(S, targetSize);

    h5Used = char(h5File);
    datasetUsed = char(preferredDataset);
end

function T = sanitizePhaseTable(T)

    required = {
        'source_sample'
        'target_time_sec'
        'phase_rad'
        'cycle_id'
        'salience_value'
        'next_interval_sec'
    };

    for i = 1:numel(required)
        if ~ismember(required{i}, T.Properties.VariableNames)
            error("Missing required CSV column: %s", required{i});
        end
    end

    for i = 1:numel(T.Properties.VariableNames)
        name = T.Properties.VariableNames{i};
        if isnumeric(T.(name))
            T.(name) = double(T.(name));
        end
    end

    T.source_sample(~isfinite(T.source_sample)) = 1;
    T.target_time_sec(~isfinite(T.target_time_sec)) = 0;
    T.phase_rad(~isfinite(T.phase_rad)) = 0;
    T.cycle_id(~isfinite(T.cycle_id)) = 0;

    if all(~isfinite(T.salience_value))
        T.salience_value(:) = 1;
    else
        medSal = median(T.salience_value(isfinite(T.salience_value)));
        T.salience_value(~isfinite(T.salience_value)) = medSal;
    end

    finiteIntervals = T.next_interval_sec(isfinite(T.next_interval_sec) & T.next_interval_sec > 0);

    if isempty(finiteIntervals)
        fillInterval = 1;
    else
        fillInterval = median(finiteIntervals);
    end

    bad = ~isfinite(T.next_interval_sec) | T.next_interval_sec <= 0;
    T.next_interval_sec(bad) = fillInterval;
end

function F = buildSourceFields(S)

    S = normalize01Safe(S);

    F.S_low = imgaussfilt(S, 8);

    S_high = S - imgaussfilt(S, 18);
    F.S_high = normalize01Safe(S_high);

    [Gx, Gy] = gradient(F.S_low);
    F.Gmag = normalize01Safe(sqrt(Gx.^2 + Gy.^2));

    L = del2(F.S_low);
    F.laplacianMap = normalize01Safe(abs(L));

    Icum = cumsum(cumsum(F.S_low, 1), 2);
    F.integralMap = normalize01Safe(Icum);

    [H, W] = size(S);
    [x, y] = meshgrid(linspace(-1, 1, W), linspace(-1, 1, H));

    r = sqrt(x.^2 + y.^2);
    theta = atan2(y, x);

    F.limitField = normalize01Safe(exp(-7 * r.^2));
    F.derivativeField = normalize01Safe(cos(6 * theta) .* exp(-1.5 * r.^2));
    F.taylorField = normalize01Safe(1 - 1.8*r.^2 + 0.9*r.^4 - 0.18*r.^6);

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
end

function TM = buildTimeMaps(S, T)

    [H, W] = size(S);

    anchorMap = zeros(H, W);
    phaseCos = zeros(H, W);
    phaseSin = zeros(H, W);
    intervalMap = zeros(H, W);
    cycleMap = zeros(H, W);
    salienceMap = zeros(H, W);

    sal = normalizeVector01(T.salience_value);
    intervals = normalizeVector01(T.next_interval_sec);
    cycles = normalizeVector01(T.cycle_id);

    sigmaList = [8 18 34];

    for k = 1:height(T)

        idx = round(T.source_sample(k));
        idx = max(1, min(H*W, idx));

        [r0, c0] = ind2sub([H, W], idx);

        local = zeros(H, W);

        for s = 1:numel(sigmaList)
            local = local + gaussian2d(H, W, r0, c0, sigmaList(s)) / numel(sigmaList);
        end

        local = normalize01Safe(local);
        w = sal(k);

        anchorMap = anchorMap + w * local;
        phaseCos = phaseCos + w * cos(T.phase_rad(k)) * local;
        phaseSin = phaseSin + w * sin(T.phase_rad(k)) * local;
        intervalMap = intervalMap + w * intervals(k) * local;
        cycleMap = cycleMap + w * cycles(k) * local;
        salienceMap = salienceMap + w * local;
    end

    TM.anchorMap = normalize01Safe(anchorMap);
    TM.phaseCos = normalize01Safe(0.5 + 0.5 * normalizeSignedSafe(phaseCos));
    TM.phaseSin = normalize01Safe(0.5 + 0.5 * normalizeSignedSafe(phaseSin));
    TM.intervalMap = normalize01Safe(intervalMap);
    TM.cycleMap = normalize01Safe(cycleMap);
    TM.salienceMap = normalize01Safe(salienceMap);
    TM.phaseEnergy = normalize01Safe(abs(TM.phaseCos - 0.5) + abs(TM.phaseSin - 0.5));

    TM.timeEta = normalize01Safe( ...
        0.28 * TM.anchorMap + ...
        0.20 * TM.phaseEnergy + ...
        0.16 * TM.intervalMap + ...
        0.12 * TM.cycleMap + ...
        0.12 * TM.salienceMap + ...
        0.12 * normalize01Safe(S - imgaussfilt(S, 18)) );
end

function TM = buildFallbackEtaMaps(S, F)

    [H, W] = size(S);
    [x, y] = meshgrid(linspace(-1,1,W), linspace(-1,1,H));

    r = sqrt(x.^2 + y.^2);
    theta = atan2(y,x);

    TM.anchorMap = normalize01Safe(exp(-6*r.^2));
    TM.phaseCos = normalize01Safe(cos(12*theta + 8*r));
    TM.phaseSin = normalize01Safe(sin(12*theta - 8*r));
    TM.phaseEnergy = normalize01Safe(abs(TM.phaseCos - 0.5) + abs(TM.phaseSin - 0.5));
    TM.intervalMap = normalize01Safe(sin(20*pi*r).^2);
    TM.cycleMap = normalize01Safe(cos(8*theta).^2);
    TM.salienceMap = F.Gmag;

    TM.timeEta = normalize01Safe( ...
        0.24 * TM.anchorMap + ...
        0.24 * TM.phaseEnergy + ...
        0.18 * TM.intervalMap + ...
        0.18 * F.S_high + ...
        0.16 * F.coherenceMap );
end

function [Ridge, HessianMax, ScaleMap] = multiscaleRidgeEvidence(I, scales)

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

    [Ridge, idx] = max(RidgeStack, [], 3);
    HessianMax = max(HessStack, [], 3);

    ScaleMap = zeros(H, W);

    for s = 1:numel(scales)
        ScaleMap(idx == s) = scales(s);
    end

    ScaleMap = normalize01Safe(ScaleMap);
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

function T = extractCandidateTable(mask, score, proof, stability, nullsurprise, ridge)

    CC = bwconncomp(mask, 8);

    if CC.NumObjects == 0
        T = table([], [], [], [], [], [], [], [], [], [], [], ...
            'VariableNames', {'rank','centroid_x','centroid_y','area','mean_score','max_score','mean_stability','mean_nullsurprise','mean_ridge','mean_proof','combined_rank_score'});
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
    mean_stability = zeros(n,1);
    mean_nullsurprise = zeros(n,1);
    mean_ridge = zeros(n,1);
    mean_proof = zeros(n,1);

    for i = 1:n
        idx = props(i).PixelIdxList;

        centroid_x(i) = props(i).Centroid(1);
        centroid_y(i) = props(i).Centroid(2);
        area(i) = props(i).Area;
        mean_score(i) = mean(score(idx));
        max_score(i) = max(score(idx));
        mean_stability(i) = mean(stability(idx));
        mean_nullsurprise(i) = mean(nullsurprise(idx));
        mean_ridge(i) = mean(ridge(idx));
        mean_proof(i) = mean(proof(idx));
    end

    combined = ...
        0.30 * normalizeVector01(area) + ...
        0.25 * normalizeVector01(mean_score) + ...
        0.20 * normalizeVector01(mean_stability) + ...
        0.15 * normalizeVector01(mean_nullsurprise) + ...
        0.10 * normalizeVector01(mean_ridge);

    [~, ord] = sort(combined, 'descend');

    T = table( ...
        rank, ...
        centroid_x, centroid_y, area, ...
        mean_score, max_score, ...
        mean_stability, mean_nullsurprise, ...
        mean_ridge, mean_proof, combined, ...
        'VariableNames', { ...
        'rank','centroid_x','centroid_y','area', ...
        'mean_score','max_score', ...
        'mean_stability','mean_nullsurprise', ...
        'mean_ridge','mean_proof','combined_rank_score'});

    T = T(ord,:);
    T.rank = (1:height(T))';
end

function RGB = makeOverlayRGB(base, mask, score)

    base = normalize01Safe(base);
    score = normalize01Safe(score);

    RGB = zeros([size(base), 3]);

    RGB(:,:,1) = base + 0.85 * double(mask) + 0.35 * score;
    RGB(:,:,2) = base .* 0.85 + 0.25 * score;
    RGB(:,:,3) = base .* 0.65;

    RGB = normalize01SafeRGB(RGB);
end

function G = gaussian2d(H, W, r0, c0, sigmaPx)

    [X, Y] = meshgrid(1:W, 1:H);
    G = exp(-((Y-r0).^2 + (X-c0).^2) / (2*sigmaPx^2));
    G = normalize01Safe(G);
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

function y = normalizeSignedSafe(x)

    x = double(x);
    x(~isfinite(x)) = 0;

    m = max(abs(x(:)));

    if m < eps
        y = zeros(size(x));
    else
        y = x ./ m;
    end

    y = max(-1, min(1, y));
end

function RGB = normalize01SafeRGB(RGB)

    RGB = double(RGB);
    RGB(~isfinite(RGB)) = 0;
    RGB = max(0, min(1, RGB));
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
        c = sum(A .* B) / denom;
    end
end

function x = randRange(a, b)

    x = a + (b-a) * rand();
end

function safeExportFigure(fig, path)

    try
        exportgraphics(fig, path, "Resolution", 200);
    catch
        saveas(fig, path);
    end
end
