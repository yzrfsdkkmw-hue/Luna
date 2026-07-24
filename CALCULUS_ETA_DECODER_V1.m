%% CALCULUS_ETA_DECODER_V1
% Decoder / metrics for CALCULUS_ETA_TRIAL_V1
%
% Goal:
% Check whether the generated "Unified calculus eta" image still preserves
% SSOT structure while carrying measurable Calculus-1 signatures.
%
% SAFE:
% - Does not modify H5
% - Does not modify prior images
% - Writes only decoder outputs and reports

clear; clc; close all;

%% 0. Paths

trialDir = "CALCULUS_ETA_TRIAL_V1";
outDir   = "CALCULUS_ETA_DECODER_V1";

if ~exist(trialDir, "dir")
    error("Missing folder: CALCULUS_ETA_TRIAL_V1. Run CALCULUS_ETA_TRIAL_V1 first.");
end

if ~exist(outDir, "dir")
    mkdir(outDir);
end

srcPath     = fullfile(trialDir, "01_source_field.png");
etaPath     = fullfile(trialDir, "02_eta_carrier.png");
atomsPath   = fullfile(trialDir, "03_calculus_atoms.png");
unifiedPath = fullfile(trialDir, "04_unified_calculus_eta.png");

requiredFiles = [srcPath, etaPath, atomsPath, unifiedPath];

for k = 1:numel(requiredFiles)
    if ~exist(requiredFiles(k), "file")
        error("Missing required image: %s", requiredFiles(k));
    end
end

fprintf("Reading trial images...\n");

S_png     = readGrayImage(srcPath);
Eta_png   = readGrayImage(etaPath);
Atoms_png = readGrayImage(atomsPath);
U         = readGrayImage(unifiedPath);

targetSize = size(U);

S_png     = imresize(S_png, targetSize);
Eta_png   = imresize(Eta_png, targetSize);
Atoms_png = imresize(Atoms_png, targetSize);

%% 1. Optional H5 verification

fprintf("Looking for H5 source truth...\n");

preferredH5 = "jsonhotel_unified_001_002_SAFE_20260628_181406.h5";
preferredDataset = "/n_5_composite_field_1000x1000/data";

h5Files = dir("*.h5");
h5Used = "";
datasetUsed = "";
h5Available = false;
S_h5 = [];

if ~isempty(h5Files)
    idx = find(strcmp({h5Files.name}, preferredH5), 1);

    if isempty(idx)
        h5File = h5Files(1).name;
    else
        h5File = h5Files(idx).name;
    end

    try
        raw = h5read(h5File, preferredDataset);
        raw = double(raw);

        if ndims(raw) > 2
            raw = raw(:,:,1);
        end

        S_h5 = mat2gray(raw);
        S_h5 = imresize(S_h5, targetSize);

        h5Used = h5File;
        datasetUsed = preferredDataset;
        h5Available = true;

        fprintf("H5 verified: %s\n", h5Used);
        fprintf("Dataset: %s\n", datasetUsed);

    catch ME
        fprintf("H5 found, but preferred dataset could not be read.\n");
        fprintf("Reason: %s\n", ME.message);
    end
else
    fprintf("No H5 found in current folder. Decoder will use PNG source field only.\n");
end

if h5Available
    S = S_h5;
else
    S = S_png;
end

%% 2. Rebuild expected calculus fields from source

fprintf("Rebuilding expected calculus fields from source...\n");

F = buildCalculusFields(S);

%% 3. Remove dominant source component from unified image

% We do not want source similarity to dominate the decoding.
% So we fit the source-like component and analyze the residual.
fprintf("Projecting out source-like base component...\n");

X = [
    ones(numel(S), 1), ...
    F.S_low(:), ...
    F.S_high(:)
];

beta = X \ U(:);
baseFit = reshape(X * beta, size(U));

R_raw = U - baseFit;
R_vis = mat2gray(R_raw);

imwrite(R_vis, fullfile(outDir, "01_decoded_residual.png"));
imwrite(mat2gray(baseFit), fullfile(outDir, "02_source_base_fit.png"));
imwrite(F.etaCarrier, fullfile(outDir, "03_expected_eta_carrier.png"));
imwrite(F.calculusAtoms, fullfile(outDir, "04_expected_calculus_atoms.png"));

%% 4. Core measurements

fprintf("Computing metrics...\n");

names = {};
values = [];
notes = {};

addMetric("source_retention_corr", safeCorr(U, S), ...
    "Correlation between unified image and H5/source field.");

addMetric("source_png_vs_h5_corr", conditionalCorr(S_png, S, h5Available), ...
    "If H5 was found: correlation between PNG source and H5 source.");

mseVal = mean((U(:) - S(:)).^2);
psnrVal = 10 * log10(1 / max(mseVal, eps));

addMetric("source_mse", mseVal, ...
    "Mean squared difference between unified image and source.");

addMetric("source_psnr", psnrVal, ...
    "PSNR-like similarity score. Higher means more source preservation.");

addMetric("residual_energy_ratio", std(R_raw(:)) / max(std(U(:)), eps), ...
    "How much non-source encoded signal remains after removing source base.");

%% 5. Calculus signature decoding from residual

etaCorr        = abs(safeCorr(R_raw, F.etaCarrier));
atomsCorr      = abs(safeCorr(R_raw, F.calculusAtoms));
limitCorr      = abs(safeCorr(R_raw, F.limitField));
derivativeCorr = abs(safeCorr(R_raw, F.derivativeField));
gradientCorr   = abs(safeCorr(R_raw, F.Gmag));
integralCorr   = abs(safeCorr(R_raw, F.Icum));
laplaceCorr    = abs(safeCorr(R_raw, F.L));
taylorCorr     = abs(safeCorr(R_raw, F.taylorField));
riemannCorr    = abs(safeCorr(R_raw, F.riemannField));

addMetric("eta_carrier_abs_corr", etaCorr, ...
    "Decoded presence of expected eta carrier in residual.");

addMetric("calculus_atoms_abs_corr", atomsCorr, ...
    "Decoded presence of combined calculus atoms in residual.");

addMetric("limit_abs_corr", limitCorr, ...
    "Limit/convergence field signature.");

addMetric("derivative_phase_abs_corr", derivativeCorr, ...
    "Directional derivative-like phase signature.");

addMetric("gradient_abs_corr", gradientCorr, ...
    "Gradient / local change signature.");

addMetric("integral_abs_corr", integralCorr, ...
    "Integral / accumulation signature.");

addMetric("laplacian_abs_corr", laplaceCorr, ...
    "Concavity / second derivative signature.");

addMetric("taylor_abs_corr", taylorCorr, ...
    "Taylor / local polynomial approximation signature.");

addMetric("riemann_abs_corr", riemannCorr, ...
    "Riemann grid / partition signature.");

%% 6. Shape / perceptual structure metrics

[H, W] = size(U);
[x, y] = meshgrid(linspace(-1, 1, W), linspace(-1, 1, H));
r = sqrt(x.^2 + y.^2);

centerMask = r < 0.14;
outerMask  = r > 0.35 & r < 0.80;

centerEnergy = mean(abs(R_raw(centerMask)));
outerEnergy  = mean(abs(R_raw(outerMask)));
centerRatio  = centerEnergy / max(outerEnergy, eps);
centerScore  = centerRatio / (1 + centerRatio);

addMetric("center_convergence_score", centerScore, ...
    "Residual energy concentration near center; proxy for limit/convergence.");

gridMask = F.riemannField > 0.55;
gridEnergy = mean(abs(R_raw(gridMask)));
nonGridEnergy = mean(abs(R_raw(~gridMask)));
gridRatio = gridEnergy / max(nonGridEnergy, eps);
gridScore = gridRatio / (1 + gridRatio);

addMetric("riemann_grid_contrast_score", gridScore, ...
    "Residual energy on expected Riemann grid lines.");

radialTaylorScore = radialProfileCorr(R_raw, F.taylorField, r, 80);

addMetric("radial_taylor_profile_corr", abs(radialTaylorScore), ...
    "Correlation between radial residual profile and Taylor-like profile.");

symLR = safeCorr(U, fliplr(U));
symUD = safeCorr(U, flipud(U));

if H == W
    symD1 = safeCorr(U, U');
    symD2 = safeCorr(U, rot90(U, 2)');
else
    symD1 = NaN;
    symD2 = NaN;
end

addMetric("symmetry_left_right_corr", symLR, ...
    "Left-right visual symmetry.");

addMetric("symmetry_up_down_corr", symUD, ...
    "Up-down visual symmetry.");

addMetric("symmetry_main_diagonal_corr", symD1, ...
    "Main diagonal symmetry, only valid for square image.");

addMetric("symmetry_anti_diagonal_corr", symD2, ...
    "Anti-diagonal symmetry, only valid for square image.");

%% 7. Summary scores

decodeVector = [
    etaCorr
    atomsCorr
    limitCorr
    derivativeCorr
    gradientCorr
    integralCorr
    laplaceCorr
    taylorCorr
    riemannCorr
    abs(radialTaylorScore)
];

decodeMean = mean(decodeVector, "omitnan");

sourceCorr = safeCorr(U, S);
sourceScore01 = max(0, min(1, (sourceCorr + 1) / 2));

symVector = [
    max(0, min(1, (symLR + 1) / 2))
    max(0, min(1, (symUD + 1) / 2))
];

symMean = mean(symVector, "omitnan");

overallScore = 0.50 * decodeMean + 0.35 * sourceScore01 + 0.15 * symMean;

addMetric("decode_presence_mean", decodeMean, ...
    "Mean decoded calculus/eta signature presence.");

addMetric("source_retention_score_01", sourceScore01, ...
    "Source retention mapped to 0..1.");

addMetric("symmetry_mean_score_01", symMean, ...
    "Mean symmetry score mapped to 0..1.");

addMetric("overall_experimental_score", overallScore, ...
    "Combined score: decoding + source preservation + symmetry.");

%% 8. Save CSV report

T = table(string(names(:)), values(:), string(notes(:)), ...
    'VariableNames', {'metric', 'value', 'note'});

csvPath = fullfile(outDir, "decoder_metrics.csv");
writetable(T, csvPath);

%% 9. Save text report

reportPath = fullfile(outDir, "decoder_report.txt");
fid = fopen(reportPath, "w");

fprintf(fid, "CALCULUS_ETA_DECODER_V1\n");
fprintf(fid, "=======================\n\n");

fprintf(fid, "Trial folder: %s\n", trialDir);
fprintf(fid, "Output folder: %s\n\n", outDir);

if h5Available
    fprintf(fid, "H5 file: %s\n", h5Used);
    fprintf(fid, "Dataset: %s\n\n", datasetUsed);
else
    fprintf(fid, "H5 file: not used / not available\n");
    fprintf(fid, "Source: PNG source field from trial folder\n\n");
end

fprintf(fid, "Top-line interpretation:\n");
fprintf(fid, "- source_retention_corr:        %.6f\n", sourceCorr);
fprintf(fid, "- decode_presence_mean:         %.6f\n", decodeMean);
fprintf(fid, "- symmetry_mean_score_01:       %.6f\n", symMean);
fprintf(fid, "- overall_experimental_score:   %.6f\n\n", overallScore);

fprintf(fid, "Detailed metrics:\n\n");

for k = 1:numel(names)
    fprintf(fid, "%-34s %.8f    %s\n", names{k}, values(k), notes{k});
end

fprintf(fid, "\nSuggested reading:\n");
fprintf(fid, "0.00-0.20 = weak / mostly visual only\n");
fprintf(fid, "0.20-0.40 = detectable but fragile\n");
fprintf(fid, "0.40-0.60 = meaningful first-pass encoding\n");
fprintf(fid, "0.60-0.80 = strong encoding\n");
fprintf(fid, "0.80-1.00 = very strong, probably too explicit / less eta-like\n");

fclose(fid);

%% 10. Diagnostic contact sheet

fig = figure("Color", "w", "Position", [80 80 1800 900]);

subplot(2,4,1);
imshow(S, []);
title("Source / H5 field");

subplot(2,4,2);
imshow(U, []);
title("Unified calculus eta");

subplot(2,4,3);
imshow(mat2gray(baseFit), []);
title("Fitted source base");

subplot(2,4,4);
imshow(R_vis, []);
title("Decoded residual");

subplot(2,4,5);
imshow(F.etaCarrier, []);
title("Expected eta carrier");

subplot(2,4,6);
imshow(F.calculusAtoms, []);
title("Expected calculus atoms");

subplot(2,4,7);
imshow(F.Gmag, []);
title("Expected gradient");

subplot(2,4,8);
imshow(F.L, []);
title("Expected Laplacian");

sgtitle("CALCULUS ETA DECODER V1 — source preservation + encoded calculus signatures");

exportgraphics(fig, fullfile(outDir, "05_decoder_contact_sheet.png"), "Resolution", 200);
close(fig);

%% 11. Print compact summary to command window

fprintf("\nDONE: CALCULUS_ETA_DECODER_V1\n");
fprintf("Outputs written to: %s\n\n", outDir);

fprintf("TOP-LINE METRICS\n");
fprintf("----------------\n");
fprintf("source_retention_corr:       %.6f\n", sourceCorr);
fprintf("decode_presence_mean:        %.6f\n", decodeMean);
fprintf("symmetry_mean_score_01:      %.6f\n", symMean);
fprintf("overall_experimental_score:  %.6f\n\n", overallScore);

fprintf("KEY DECODING METRICS\n");
fprintf("--------------------\n");
fprintf("eta_carrier_abs_corr:        %.6f\n", etaCorr);
fprintf("calculus_atoms_abs_corr:     %.6f\n", atomsCorr);
fprintf("limit_abs_corr:              %.6f\n", limitCorr);
fprintf("gradient_abs_corr:           %.6f\n", gradientCorr);
fprintf("laplacian_abs_corr:          %.6f\n", laplaceCorr);
fprintf("taylor_abs_corr:             %.6f\n", taylorCorr);
fprintf("riemann_abs_corr:            %.6f\n", riemannCorr);
fprintf("radial_taylor_profile_corr:  %.6f\n\n", abs(radialTaylorScore));

fprintf("Please send back:\n");
fprintf("1. Command Window summary\n");
fprintf("2. CALCULUS_ETA_DECODER_V1/decoder_report.txt\n");
fprintf("3. 05_decoder_contact_sheet.png if possible\n");

%% Helper: add metric

function addMetric(metricName, metricValue, metricNote)
    assignin("caller", "names",  [evalin("caller", "names"),  {char(metricName)}]);
    assignin("caller", "values", [evalin("caller", "values"), metricValue]);
    assignin("caller", "notes",  [evalin("caller", "notes"),  {char(metricNote)}]);
end

%% Helper: read grayscale image

function I = readGrayImage(path)
    I = imread(path);

    if ndims(I) == 3
        I = rgb2gray(I);
    end

    I = im2double(I);
    I = mat2gray(I);
end

%% Helper: build expected calculus fields

function F = buildCalculusFields(S)

    S = mat2gray(double(S));

    F.S_low = imgaussfilt(S, 8);

    S_high = S - imgaussfilt(S, 18);
    F.S_high = mat2gray(S_high);

    [Gx, Gy] = gradient(F.S_low);
    F.Gmag = mat2gray(sqrt(Gx.^2 + Gy.^2));

    L = del2(F.S_low);
    F.L = mat2gray(abs(L));

    Icum = cumsum(cumsum(F.S_low, 1), 2);
    F.Icum = mat2gray(Icum);

    [H, W] = size(S);
    [x, y] = meshgrid(linspace(-1, 1, W), linspace(-1, 1, H));

    r = sqrt(x.^2 + y.^2);
    theta = atan2(y, x);

    F.limitField = mat2gray(exp(-7 * r.^2));

    F.derivativeField = mat2gray(cos(6 * theta) .* exp(-1.5 * r.^2));

    F.integralField = mat2gray(1 - exp(-4 * r.^2));

    F.concavityField = mat2gray(cos(10 * pi * r) .* exp(-1.2 * r.^2));

    F.taylorField = mat2gray( ...
        1 ...
        - 1.8 * r.^2 ...
        + 0.9 * r.^4 ...
        - 0.18 * r.^6 );

    gridX = abs(sin(20 * pi * x));
    gridY = abs(sin(20 * pi * y));

    riemannField = double((gridX > 0.94) | (gridY > 0.94));
    F.riemannField = mat2gray(imgaussfilt(riemannField, 1.2));

    etaCarrier = ...
        0.38 * F.limitField + ...
        0.18 * F.derivativeField + ...
        0.16 * F.concavityField + ...
        0.10 * F.taylorField + ...
        0.08 * F.riemannField + ...
        0.10 * F.S_high;

    F.etaCarrier = mat2gray(etaCarrier);

    calculusAtoms = ...
        0.28 * F.limitField + ...
        0.20 * F.Gmag + ...
        0.16 * F.Icum + ...
        0.16 * F.L + ...
        0.12 * F.taylorField + ...
        0.08 * F.riemannField;

    F.calculusAtoms = mat2gray(calculusAtoms);
end

%% Helper: safe correlation

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

%% Helper: conditional H5 correlation

function c = conditionalCorr(A, B, condition)
    if condition
        c = safeCorr(A, B);
    else
        c = NaN;
    end
end

%% Helper: radial profile correlation

function c = radialProfileCorr(A, B, r, nBins)

    A = double(A);
    B = double(B);

    edges = linspace(0, max(r(:)), nBins + 1);

    profA = zeros(nBins, 1);
    profB = zeros(nBins, 1);

    for k = 1:nBins
        mask = r >= edges(k) & r < edges(k+1);

        if any(mask(:))
            profA(k) = mean(A(mask));
            profB(k) = mean(B(mask));
        else
            profA(k) = NaN;
            profB(k) = NaN;
        end
    end

    c = safeCorr(profA, profB);
end