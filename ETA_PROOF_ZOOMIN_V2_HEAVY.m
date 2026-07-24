%% ETA_PROOF_ZOOMIN_V2_HEAVY
% Local zoom-in proof forecast around top candidates from:
% 1111_ETA_PROOF_FORECAST_V1/1111_candidates.csv
%
% Purpose:
% Take the proof-forecast map and inspect the top candidate regions locally:
% - crop around candidates
% - measure cross-channel agreement
% - bootstrap local stability
% - compare against random windows
% - produce focused images and numeric reports
%
% SAFE:
% - reads previous forecast outputs only
% - writes new output folder only
% - does not modify H5 or previous outputs

clear; clc; close all;

%% 0) Setup

prevDir = "1111_ETA_PROOF_FORECAST_V1";
outDir  = "2222_ETA_PROOF_ZOOMIN_V2";

if ~exist(prevDir, "dir")
    error("Missing previous folder: %s. Run ETA_PROOF_FORECAST_V1 first.", prevDir);
end

if ~exist(outDir, "dir")
    mkdir(outDir);
end

candidateCsv = fullfile(prevDir, "1111_candidates.csv");

if ~exist(candidateCsv, "file")
    error("Missing candidates CSV: %s", candidateCsv);
end

topK = 3;
cropRadius = 180;

nLocalBootstrap = 260;
nRandomWindows  = 420;

topQuantileCore = 0.985;
topQuantileNull = 0.990;

rng(337, "twister");

fprintf("ETA_PROOF_ZOOMIN_V2_HEAVY\n");
fprintf("=========================\n\n");

%% 1) Read previous maps

fprintf("Reading previous proof-forecast maps...\n");

M = struct();

M.source        = readGray(fullfile(prevDir, "1111_SOURCE.png"));
M.timeEta       = readGray(fullfile(prevDir, "2222_TIME_ETA.png"));
M.evidence      = readGray(fullfile(prevDir, "3333_EVIDENCE.png"));
M.ridge         = readGray(fullfile(prevDir, "4444_RIDGE.png"));
M.stability     = readGray(fullfile(prevDir, "5555_STABILITY.png"));
M.nullSurprise  = readGray(fullfile(prevDir, "6666_NULL_SURPRISE.png"));
M.proofCorridor = readGray(fullfile(prevDir, "7777_PROOF_CORRIDOR.png"));
M.candidateScore = readGray(fullfile(prevDir, "8888_CANDIDATE_SCORE.png"));
M.unified       = readGray(fullfile(prevDir, "9999_UNIFIED_ETA_PROOF.png"));

[H, W] = size(M.source);

fprintf("Map size: %d x %d\n\n", H, W);

%% 2) Read candidates

C = readtable(candidateCsv);

if isempty(C)
    error("Candidate table is empty.");
end

topK = min(topK, height(C));

fprintf("Candidates available: %d\n", height(C));
fprintf("Using top K: %d\n\n", topK);

%% 3) Global channels

globalChannels = cat(3, ...
    M.timeEta, ...
    M.evidence, ...
    M.ridge, ...
    M.stability, ...
    M.nullSurprise, ...
    M.proofCorridor, ...
    M.candidateScore);

globalAgreement = normalize01Safe( ...
    0.14 * M.timeEta + ...
    0.17 * M.evidence + ...
    0.17 * M.ridge + ...
    0.17 * M.stability + ...
    0.17 * M.nullSurprise + ...
    0.18 * M.candidateScore);

safeImwrite(globalAgreement, fullfile(outDir, "0000_GLOBAL_AGREEMENT.png"));

%% 4) Prepare summary containers

summaryRows = [];

allCandidateMontage = cell(topK, 1);

%% 5) Process each top candidate

for i = 1:topK

    cx = C.centroid_x(i);
    cy = C.centroid_y(i);

    fprintf("Processing candidate %d / %d at x=%.2f y=%.2f\n", i, topK, cx, cy);

    candDir = fullfile(outDir, sprintf("candidate_%02d_x%04d_y%04d", i, round(cx), round(cy)));

    if ~exist(candDir, "dir")
        mkdir(candDir);
    end

    % Crop all maps
    crop = struct();

    [crop.source, rows, cols] = cropAround(M.source, cx, cy, cropRadius);
    crop.timeEta       = cropUsingRowsCols(M.timeEta, rows, cols);
    crop.evidence      = cropUsingRowsCols(M.evidence, rows, cols);
    crop.ridge         = cropUsingRowsCols(M.ridge, rows, cols);
    crop.stability     = cropUsingRowsCols(M.stability, rows, cols);
    crop.nullSurprise  = cropUsingRowsCols(M.nullSurprise, rows, cols);
    crop.proofCorridor = cropUsingRowsCols(M.proofCorridor, rows, cols);
    crop.candidateScore = cropUsingRowsCols(M.candidateScore, rows, cols);
    crop.unified       = cropUsingRowsCols(M.unified, rows, cols);
    crop.agreement     = cropUsingRowsCols(globalAgreement, rows, cols);

    % Local weighted channels
    localChannels = cat(3, ...
        crop.timeEta, ...
        crop.evidence, ...
        crop.ridge, ...
        crop.stability, ...
        crop.nullSurprise, ...
        crop.proofCorridor, ...
        crop.candidateScore, ...
        crop.agreement);

    % Local bootstrap survival
    localSurvival = zeros(size(crop.source));

    for b = 1:nLocalBootstrap

        w = rand(1, size(localChannels,3));
        w = w ./ sum(w);

        L = zeros(size(crop.source));

        for ch = 1:size(localChannels,3)
            L = L + w(ch) * localChannels(:,:,ch);
        end

        L = normalize01Safe(imgaussfilt(L, randRange(0.25, 1.75)));

        thr = quantile(L(:), topQuantileCore);
        mask = L >= thr;

        % small soft expansion
        mask = conv2(double(mask), ones(3), "same") > 0;

        localSurvival = localSurvival + double(mask);
    end

    localSurvival = normalize01Safe(localSurvival);

    % Core mask from candidate score + local survival + agreement
    coreScore = normalize01Safe( ...
        0.42 * crop.candidateScore + ...
        0.25 * localSurvival + ...
        0.18 * crop.agreement + ...
        0.15 * crop.ridge);

    coreThr = quantile(coreScore(:), topQuantileCore);
    coreMask = coreScore >= coreThr;

    % require some support from survival or ridge
    supportMask = (localSurvival > quantile(localSurvival(:), 0.75)) | ...
                  (crop.ridge > quantile(crop.ridge(:), 0.80));

    coreMask = coreMask & supportMask;
    coreMask = conv2(double(coreMask), ones(3), "same") >= 2;
    coreMask = coreMask > 0;

    % Extract local structure properties
    props = localStructureStats(coreMask, coreScore, localSurvival, crop.ridge, crop.nullSurprise);

    % Random-window null comparison
    obsTopMean = topMean(crop.candidateScore, topQuantileNull);
    obsAgreementTopMean = topMean(crop.agreement, topQuantileNull);
    obsSurvivalTopMean = topMean(localSurvival, topQuantileNull);

    nullTop = zeros(nRandomWindows, 1);
    nullAgree = zeros(nRandomWindows, 1);
    nullStable = zeros(nRandomWindows, 1);

    hCrop = numel(rows);
    wCrop = numel(cols);

    for n = 1:nRandomWindows

        r1 = randi([1, max(1, H - hCrop + 1)]);
        c1 = randi([1, max(1, W - wCrop + 1)]);

        rr = r1:(r1+hCrop-1);
        cc = c1:(c1+wCrop-1);

        randScore = M.candidateScore(rr, cc);
        randAgree = globalAgreement(rr, cc);
        randStable = M.stability(rr, cc);

        nullTop(n) = topMean(randScore, topQuantileNull);
        nullAgree(n) = topMean(randAgree, topQuantileNull);
        nullStable(n) = topMean(randStable, topQuantileNull);
    end

    pScore = empiricalP(obsTopMean, nullTop);
    pAgree = empiricalP(obsAgreementTopMean, nullAgree);
    pStable = empiricalP(obsSurvivalTopMean, nullStable);

    combinedP = min(1, 3 * min([pScore, pAgree, pStable])); % conservative simple Bonferroni-like

    % Overlay
    overlay = makeOverlayRGB(crop.unified, coreMask, coreScore);

    % Save candidate images
    safeImwrite(crop.source,         fullfile(candDir, "1111_source_crop.png"));
    safeImwrite(crop.timeEta,        fullfile(candDir, "2222_time_eta_crop.png"));
    safeImwrite(crop.evidence,       fullfile(candDir, "3333_evidence_crop.png"));
    safeImwrite(crop.ridge,          fullfile(candDir, "4444_ridge_crop.png"));
    safeImwrite(crop.stability,      fullfile(candDir, "5555_global_stability_crop.png"));
    safeImwrite(crop.nullSurprise,   fullfile(candDir, "6666_null_surprise_crop.png"));
    safeImwrite(crop.proofCorridor,  fullfile(candDir, "7777_proof_corridor_crop.png"));
    safeImwrite(crop.candidateScore, fullfile(candDir, "8888_candidate_score_crop.png"));
    safeImwrite(crop.unified,        fullfile(candDir, "9999_unified_crop.png"));
    safeImwrite(crop.agreement,      fullfile(candDir, "1010_cross_channel_agreement.png"));
    safeImwrite(localSurvival,       fullfile(candDir, "2020_local_bootstrap_survival.png"));
    safeImwrite(coreScore,           fullfile(candDir, "3030_local_core_score.png"));
    safeImwrite(double(coreMask),    fullfile(candDir, "4040_local_core_mask.png"));
    imwrite(overlay,                 fullfile(candDir, "0000_local_overlay.png"));

    % Local contact sheet
    fig = figure("Color", "w", "Position", [60 60 2100 1100]);

    subplot(2,5,1); safeShow(crop.source); title("Source crop");
    subplot(2,5,2); safeShow(crop.timeEta); title("Time/Eta crop");
    subplot(2,5,3); safeShow(crop.evidence); title("Evidence crop");
    subplot(2,5,4); safeShow(crop.ridge); title("Ridge crop");
    subplot(2,5,5); safeShow(crop.nullSurprise); title("Null surprise crop");

    subplot(2,5,6); safeShow(crop.candidateScore); title("Candidate score");
    subplot(2,5,7); safeShow(crop.agreement); title("Cross-channel agreement");
    subplot(2,5,8); safeShow(localSurvival); title("Local bootstrap survival");
    subplot(2,5,9); safeShow(double(coreMask)); title("Local core mask");
    subplot(2,5,10); imshow(overlay); title("Overlay");

    sgtitle(sprintf("ETA ZOOM-IN V2 — Candidate %d | x=%.2f y=%.2f", i, cx, cy));

    safeExportFigure(fig, fullfile(candDir, "0000_LOCAL_CONTACT_SHEET.png"));
    close(fig);

    allCandidateMontage{i} = overlay;

    % Report for candidate
    fid = fopen(fullfile(candDir, "1111_local_report.txt"), "w");

    fprintf(fid, "ETA_PROOF_ZOOMIN_V2_HEAVY — Candidate %d\n", i);
    fprintf(fid, "========================================\n\n");

    fprintf(fid, "Candidate location:\n");
    fprintf(fid, "centroid_x: %.4f\n", cx);
    fprintf(fid, "centroid_y: %.4f\n", cy);
    fprintf(fid, "crop rows: %d:%d\n", rows(1), rows(end));
    fprintf(fid, "crop cols: %d:%d\n\n", cols(1), cols(end));

    fprintf(fid, "Observed local scores:\n");
    fprintf(fid, "obsTopMean_candidateScore: %.8f\n", obsTopMean);
    fprintf(fid, "obsTopMean_agreement:      %.8f\n", obsAgreementTopMean);
    fprintf(fid, "obsTopMean_survival:       %.8f\n\n", obsSurvivalTopMean);

    fprintf(fid, "Random-window p-values:\n");
    fprintf(fid, "pScore:                    %.8f\n", pScore);
    fprintf(fid, "pAgreement:                %.8f\n", pAgree);
    fprintf(fid, "pSurvival:                 %.8f\n", pStable);
    fprintf(fid, "combinedP_simple:          %.8f\n\n", combinedP);

    fprintf(fid, "Local structure stats:\n");
    fprintf(fid, "core_density:              %.8f\n", props.core_density);
    fprintf(fid, "component_count:           %d\n", props.component_count);
    fprintf(fid, "largest_component_area:    %.8f\n", props.largest_component_area);
    fprintf(fid, "component_dominance:       %.8f\n", props.component_dominance);
    fprintf(fid, "anisotropy:                %.8f\n", props.anisotropy);
    fprintf(fid, "orientation_deg:           %.8f\n", props.orientation_deg);
    fprintf(fid, "mean_core_score:           %.8f\n", props.mean_core_score);
    fprintf(fid, "mean_core_survival:        %.8f\n", props.mean_core_survival);
    fprintf(fid, "mean_core_ridge:           %.8f\n", props.mean_core_ridge);
    fprintf(fid, "mean_core_nullsurprise:    %.8f\n", props.mean_core_nullsurprise);

    fclose(fid);

    % Append to global summary
    summaryRows = [summaryRows; ...
        i, cx, cy, ...
        C.area(i), C.mean_score(i), C.max_score(i), ...
        C.mean_stability(i), C.mean_nullsurprise(i), ...
        obsTopMean, obsAgreementTopMean, obsSurvivalTopMean, ...
        pScore, pAgree, pStable, combinedP, ...
        props.core_density, props.component_count, props.largest_component_area, ...
        props.component_dominance, props.anisotropy, props.orientation_deg, ...
        props.mean_core_score, props.mean_core_survival, props.mean_core_ridge, props.mean_core_nullsurprise];

    fprintf("  done candidate %d | pScore=%.4g | pAgree=%.4g | pStable=%.4g | anisotropy=%.4f\n", ...
        i, pScore, pAgree, pStable, props.anisotropy);
end

%% 6) Save global summary table

summaryTable = varNames 

    'rank'; 'centroid_x'; 'centroid_y'; ...
    'global_area'; 'global_mean_score'; 'global_max_score'; ...
    'global_mean_stability'; 'global_mean_nullsurprise'; ...
    'obs_top_candidate_score'; 'obs_top_agreement'; 'obs_top_survival'; ...
    'p_score_vs_random'; 'p_agreement_vs_random'; 'p_survival_vs_random'; 'combined_p_simple'; ...
    'core_density'; 'component_count'; 'largest_component_area'; ...
    'component_dominance'; 'anisotropy'; 'orientation_deg'; ...
    'mean_core_score'; 'mean_core_survival'; 'mean_core_ridge'; 'mean_core_nullsurprise'; ...
    
%% 7) Combined montage of overlays

fprintf("\nCreating combined candidate montage...\n");

fig = figure("Color", "w", "Position", [80 80 520*topK 560]);

fori = 1:topK
    subplot(1, topK, i);
    imshow(allCandidateMontage{i});
    title(sprintf("Candidate %d", i));


sgtitle("ETA PROOF ZOOM-IN V2 — Top candidates local overlays");

safeExportFigure(fig, fullfile(outDir, "0000_TOP_CANDIDATES_MONTAGE.png"));
close(fig);

%% 8) Final report

fid = fopen(fullfile(outDir, "1111_ZOOMIN_REPORT.txt"), "w");

fprintf(fid, "ETA_PROOF_ZOOMIN_V2_HEAVY\n");
fprintf(fid, "=========================\n\n");

fprintf(fid, "Previous folder: %s\n", prevDir);
fprintf(fid, "Output folder:   %s\n", outDir);
fprintf(fid, "TopK:            %d\n", topK);
fprintf(fid, "cropRadius:      %d\n", cropRadius);
fprintf(fid, "nLocalBootstrap: %d\n", nLocalBootstrap);
fprintf(fid, "nRandomWindows:  %d\n\n", nRandomWindows);

fprintf(fid, "Summary:\n\n");

fori = 1:height(summaryTable);
    fprintf(fid, ...
        "#%d | x=%.2f y=%.2f | pScore=%.6g pAgree=%.6g pStable=%.6g | anisotropy=%.4f | dominance=%.4f | orientation=%.2f deg\n", ...
        summaryTable.rank(i), ...
        summaryTable.centroid_x(i), ...
        summaryTable.centroid_y(i), ...
        summaryTable.p_score_vs_random(i), ...
        summaryTable.p_agreement_vs_random(i), ...
        summaryTable.p_survival_vs_random(i), ...
        summaryTable.anisotropy(i), ...
        summaryTable.component_dominance(i), ...
        summaryTable.orientation_deg(i));
        %% 8. Save CSV report

        T = table(string(names(:)), values(:), string(notes(:)), ...
        'VariableNames', {'metric', 'value', 'note'});


fprintf(fid, "\nInterpretation rule:\n");
fprintf(fid, "- A strong candidate should have low random-window p-values, high anisotropy, and high component dominance.\n");
fprintf(fid, "- This still does not prove the structure. It tells us where proof should focus next.\n");

fclose(fid);

%% 9) ZIP for easy download


    zip("2222_ETA_PROOF_ZOOMIN_V2.zip", outDir);

    warning("Could not create ZIP automatically.");


%% 10) Command Window summary

fprintf("\nDONE: ETA_PROOF_ZOOMIN_V2_HEAVY\n");
fprintf("Outputs written to: %s\n\n", outDir);

fprintf("TOP-LINE ZOOM-IN SUMMARY\n");
fprintf("------------------------\n");

fori = 1:height(summaryTable)
    fprintf("#%d | x=%.2f y=%.2f | pScore=%.6g | pAgree=%.6g | pStable=%.6g | anisotropy=%.4f | dominance=%.4f\n", ...
        summaryTable.rank(i), ...
        summaryTable.centroid_x(i), ...
        summaryTable.centroid_y(i), ...
        summaryTable.p_score_vs_random(i), ...
        summaryTable.p_agreement_vs_random(i), ...
        summaryTable.p_survival_vs_random(i), ...
        summaryTable.anisotropy(i), ...
        summaryTable.component_dominance(i));


fprintf("\nMOST IMPORTANT FILES\n");
fprintf("--------------------\n");
fprintf("%s/0000_TOP_CANDIDATES_MONTAGE.png\n", outDir);
fprintf("%s/1111_ZOOMIN_SUMMARY.csv\n", outDir);
fprintf("%s/1111_ZOOMIN_REPORT.txt\n", outDir);
fprintf("2222_ETA_PROOF_ZOOMIN_V2.zip\n");

%% =========================
% Helper functions
% =========================

function I = readGray(path)
    if ~exist(path, "file")
        error("Missing required map: %s", path);
    end

    I = imread(path);

    if ndims(I) == 3
        I = rgb2gray(I);
    end

    I = im2double(I);
    I = normalize01Safe(I);
end

function [C, rows, cols] = cropAround(A, cx, cy, radius)
    [H, W] = size(A);

    c0 = round(cx);
    r0 = round(cy);

    rows = max(1, r0-radius):min(H, r0+radius);
    cols = max(1, c0-radius):min(W, c0+radius);

    C = A(rows, cols);
end

function C = cropUsingRowsCols(A, rows, cols)
    C = A(rows, cols);
end

function props = localStructureStats(mask, coreScore, survival, ridge, nullSurprise)

    mask = logical(mask);

    props = struct();

    props.core_density = mean(mask(:));

    if ~any(mask(:))
        props.component_count = 0;
        props.largest_component_area = 0;
        props.component_dominance = 0;
        props.anisotropy = 0;
        props.orientation_deg = NaN;
        props.mean_core_score = NaN;
        props.mean_core_survival = NaN;
        props.mean_core_ridge = NaN;
        props.mean_core_nullsurprise = NaN;
        return;
    end

    CC = bwconncomp(mask, 8);
    props.component_count = CC.NumObjects;

    areas = cellfun(@numel, CC.PixelIdxList);

    if isempty(areas)
        props.largest_component_area = 0;
        props.component_dominance = 0;
    else
        props.largest_component_area = max(areas);
        props.component_dominance = max(areas) / max(sum(areas), eps);
    end

    [yy, xx] = find(mask);

    if numel(xx) < 3
        props.anisotropy = 0;
        props.orientation_deg = NaN;
    else
        X = [xx(:), yy(:)];
        X = X - mean(X, 1);

        C = cov(X);

        if any(~isfinite(C(:)))
            props.anisotropy = 0;
            props.orientation_deg = NaN;
        else
            [V, D] = eig(C);
            d = diag(D);
            [dSorted, ord] = sort(d, "descend");

            if dSorted(1) <= eps
                props.anisotropy = 0;
            else
                props.anisotropy = max(0, 1 - dSorted(2) / dSorted(1));
            end

            v = V(:, ord(1));
            props.orientation_deg = atan2d(v(2), v(1));
        end
    end

    props.mean_core_score = mean(coreScore(mask), "omitnan");
    props.mean_core_survival = mean(survival(mask), "omitnan");
    props.mean_core_ridge = mean(ridge(mask), "omitnan");
    props.mean_core_nullsurprise = mean(nullSurprise(mask), "omitnan");
end

function m = topMean(A, q)
    A = double(A);
    A = A(isfinite(A));

    if isempty(A)
        m = NaN;
        return;
    end

    thr = quantile(A(:), q);
    vals = A(A >= thr);

    if isempty(vals)
        m = NaN;
    else
        m = mean(vals);
    end
end

function p = empiricalP(obs, nullVals)

    nullVals = nullVals(isfinite(nullVals));

    if isempty(nullVals) || ~isfinite(obs)
        p = NaN;
        return;
    end

    p = (1 + sum(nullVals >= obs)) / (numel(nullVals) + 1);
end

function RGB = makeOverlayRGB(base, mask, score)

    base = normalize01Safe(base);
    score = normalize01Safe(score);
    mask = double(mask);

    RGB = zeros([size(base), 3]);

    RGB(:,:,1) = base .* 0.70 + 0.95 * mask + 0.35 * score;
    RGB(:,:,2) = base .* 0.85 + 0.25 * score;
    RGB(:,:,3) = base .* 0.65;

    RGB = max(0, min(1, RGB));
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

function safeImwrite(I, path)
    I = normalize01Safe(I);
    imwrite(I, path);
end

function safeShow(I)
    I = normalize01Safe(I);
    imshow(I, [0 1]);
end

function x = randRange(a, b)
    x = a + (b - a) * rand();
end

function safeExportFigure(fig, path)
    try
        exportgraphics(fig, path, "Resolution", 200);
    catch
        saveas(fig, path);
    end
end