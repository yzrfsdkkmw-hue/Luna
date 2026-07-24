%% CALCULUS_ETA_TRIAL_V1
% Reads SSOT H5 from current modelTRAINING folder.
% Creates a few calculus-encoded eta-phase trial images.
%
% SAFE:
% - read-only for H5
% - writes only PNG outputs + text report
% - does not modify source truth

clear; clc; close all;

%% 0. Setup

outDir = "CALCULUS_ETA_TRIAL_V1";
if ~exist(outDir, "dir")
    mkdir(outDir);
end

h5Files = dir("*.h5");

if isempty(h5Files)
    error("No .h5 file found in current folder. Put this script inside modelTRAINING next to the H5 file.");
end

% Prefer known SSOT name if present
preferredName = "jsonhotel_unified_001_002_SAFE_20260628_181406.h5";
idx = find(strcmp({h5Files.name}, preferredName), 1);

if isempty(idx)
    h5File = h5Files(1).name;
else
    h5File = h5Files(idx).name;
end

fprintf("Using H5 file: %s\n", h5File);

%% 1. Read source field from H5

preferredDataset = "/n_5_composite_field_1000x1000/data";

try
    S = h5read(h5File, preferredDataset);
    datasetPath = preferredDataset;
catch
    fprintf("Preferred dataset not found. Searching for largest numeric 2D dataset...\n");
    info = h5info(h5File);
    datasetPath = findLargest2DDataset(info, "");
    if datasetPath == ""
        error("Could not find a usable 2D numeric dataset in H5.");
    end
    S = h5read(h5File, datasetPath);
end

fprintf("Using dataset: %s\n", datasetPath);

S = double(S);

% If data is 3D, take first slice safely
if ndims(S) > 2
    S = S(:,:,1);
end

% Normalize
S = mat2gray(S);

% Resize to stable working size
targetSize = [1000 1000];
S = imresize(S, targetSize);

%% 2. Build source-derived fields

% Smooth low frequency base
S_low = imgaussfilt(S, 8);

% High frequency detail
S_high = S - imgaussfilt(S, 18);
S_high = mat2gray(S_high);

% Gradient = derivative-like field
[Gx, Gy] = gradient(S_low);
Gmag = mat2gray(sqrt(Gx.^2 + Gy.^2));

% Laplacian = concavity-like field
L = del2(S_low);
L = mat2gray(abs(L));

% Integral-like field: cumulative accumulation
Icum = cumsum(cumsum(S_low, 1), 2);
Icum = mat2gray(Icum);

%% 3. Coordinate system

[H, W] = size(S);
[x, y] = meshgrid(linspace(-1, 1, W), linspace(-1, 1, H));

r = sqrt(x.^2 + y.^2);
theta = atan2(y, x);

%% 4. Calculus concept fields

% Limit: convergence toward center
limitField = exp(-7 * r.^2);

% Derivative: directional slope pattern
derivativeField = mat2gray(cos(6 * theta) .* exp(-1.5 * r.^2));

% Integral: accumulated radial mass
integralField = mat2gray(1 - exp(-4 * r.^2));

% Concavity: alternating rings = second derivative / curvature zones
concavityField = mat2gray(cos(10 * pi * r) .* exp(-1.2 * r.^2));

% Taylor: local polynomial approximation rings around center
taylorField = mat2gray( ...
    1 ...
    - 1.8 * r.^2 ...
    + 0.9 * r.^4 ...
    - 0.18 * r.^6 );

% Riemann grid: weak rectangles
gridX = abs(sin(20 * pi * x));
gridY = abs(sin(20 * pi * y));
riemannField = mat2gray((gridX > 0.94) | (gridY > 0.94));
riemannField = imgaussfilt(double(riemannField), 1.2);

%% 5. Eta carrier

% Very faint symmetric carrier: phase structure, not a loud drawing
etaCarrier = ...
    0.38 * limitField + ...
    0.18 * derivativeField + ...
    0.16 * concavityField + ...
    0.10 * taylorField + ...
    0.08 * riemannField + ...
    0.10 * S_high;

etaCarrier = mat2gray(etaCarrier);

% Make it faint like the original eta phase
etaFaint = 0.88 + 0.12 * etaCarrier;
etaFaint = mat2gray(etaFaint);

%% 6. Calculus atoms image

calculusAtoms = ...
    0.28 * limitField + ...
    0.20 * Gmag + ...
    0.16 * Icum + ...
    0.16 * L + ...
    0.12 * taylorField + ...
    0.08 * riemannField;

calculusAtoms = mat2gray(calculusAtoms);

%% 7. Unified calculus eta image

% This is the first real experiment:
% SSOT + weak eta carrier + calculus fields
unified = ...
    0.48 * S_low + ...
    0.14 * S_high + ...
    0.12 * etaCarrier + ...
    0.08 * limitField + ...
    0.07 * Gmag + ...
    0.06 * L + ...
    0.05 * taylorField;

unified = mat2gray(unified);

% Slight perceptual smoothing
unified = imgaussfilt(unified, 0.65);
unified = mat2gray(unified);

%% 8. Save individual images

imwrite(S, fullfile(outDir, "01_source_field.png"));
imwrite(etaFaint, fullfile(outDir, "02_eta_carrier.png"));
imwrite(calculusAtoms, fullfile(outDir, "03_calculus_atoms.png"));
imwrite(unified, fullfile(outDir, "04_unified_calculus_eta.png"));

%% 9. Contact sheet

fig = figure("Color", "w", "Position", [100 100 1800 900]);

subplot(2,4,1);
imshow(S, []);
title("Source field from H5");

subplot(2,4,2);
imshow(S_high, []);
title("Source high frequency");

subplot(2,4,3);
imshow(Gmag, []);
title("Derivative / gradient");

subplot(2,4,4);
imshow(L, []);
title("Concavity / Laplacian");

subplot(2,4,5);
imshow(etaFaint, []);
title("Eta carrier faint");

subplot(2,4,6);
imshow(calculusAtoms, []);
title("Calculus atoms");

subplot(2,4,7);
imshow(taylorField, []);
title("Taylor / local approximation");

subplot(2,4,8);
imshow(unified, []);
title("Unified calculus eta");

sgtitle("CALCULUS ETA TRIAL V1 — SSOT H5 + Calculus 1 visual encoding");

exportgraphics(fig, fullfile(outDir, "05_contact_sheet.png"), "Resolution", 200);
close(fig);

%% 10. Report

reportFile = fullfile(outDir, "calculus_eta_report.txt");
fid = fopen(reportFile, "w");

fprintf(fid, "CALCULUS_ETA_TRIAL_V1\n");
fprintf(fid, "=====================\n\n");
fprintf(fid, "H5 file: %s\n", h5File);
fprintf(fid, "Dataset: %s\n", datasetPath);
fprintf(fid, "Output folder: %s\n\n", outDir);

fprintf(fid, "Fields created:\n");
fprintf(fid, "- source_field: raw normalized H5 field\n");
fprintf(fid, "- eta_carrier: faint phase-like visual carrier\n");
fprintf(fid, "- calculus_atoms: limit / derivative / integral / concavity / Taylor / Riemann\n");
fprintf(fid, "- unified_calculus_eta: SSOT + weak encoded calculus fields\n\n");

fprintf(fid, "Concept mapping:\n");
fprintf(fid, "limitField      = convergence toward center\n");
fprintf(fid, "Gmag            = derivative / local change\n");
fprintf(fid, "Icum            = integral / accumulation\n");
fprintf(fid, "Laplacian       = concavity / second derivative\n");
fprintf(fid, "taylorField     = local polynomial approximation\n");
fprintf(fid, "riemannField    = weak rectangular partition grid\n\n");

fprintf(fid, "Safety:\n");
fprintf(fid, "- H5 was read only\n");
fprintf(fid, "- No source file modified\n");

fclose(fid);

fprintf("\nDone.\n");
fprintf("Outputs written to: %s\n", outDir);

%% Helper function: recursively find largest 2D dataset

function bestPath = findLargest2DDataset(groupInfo, currentPath)

    bestPath = "";
    bestScore = -inf;

    % Check datasets in current group
    for k = 1:numel(groupInfo.Datasets)
        ds = groupInfo.Datasets(k);
        dims = ds.Dataspace.Size;

        if numel(dims) >= 2
            score = prod(double(dims(1:2)));

            if currentPath == ""
                candidatePath = "/" + string(ds.Name);
            else
                candidatePath = currentPath + "/" + string(ds.Name);
            end

            if score > bestScore
                bestScore = score;
                bestPath = candidatePath;
            end
        end
    end

    % Recurse into groups
    for g = 1:numel(groupInfo.Groups)
        sub = groupInfo.Groups(g);

        if currentPath == ""
            subPath = "/" + string(sub.Name);
        else
            subPath = string(sub.Name);
        end

        candidate = findLargest2DDataset(sub, subPath);

        if candidate ~= ""
            try
                dims = h5infoeval(groupInfo, candidate);
            catch
                dims = [];
            end

            % Simpler fallback: accept first strong recursive result
            if bestPath == ""
                bestPath = candidate;
            end
        end
    end
end

function dims = h5infoeval(~, ~)
    dims = [];
end