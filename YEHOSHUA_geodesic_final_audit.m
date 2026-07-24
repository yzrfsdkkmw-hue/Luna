function R = YEHOSHUA_geodesic_final_audit()
% YEHOSHUA_GEODESIC_FINAL_AUDIT
% Read-only, self-contained audit of the V15 projection artifacts.
%
% Save as YEHOSHUA_geodesic_final_audit.m, then run:
%     R = YEHOSHUA_geodesic_final_audit;
%
% This audit proves what the files can prove. It does not invent a metric.
%
% Decision rule:
%   1) In Euclidean 2-D, a geodesic must have zero curvature.
%   2) In a Riemannian space, "geodesic" is undefined until g_ij
%      (or an affine connection) is specified and tested.
%   3) A shape prescribed by a renderer cannot be independent evidence
%      that the same shape was discovered in the SSOT.

clc;

artifactDir = ...
    "/Users/yehoshua/Desktop/YEHOSHUA_projection_temporal_formula_from_SSOT_v15";

canonicalDir = "/Users/yehoshua/MATLAB-Drive/modelTRAINING";

ssotFile = fullfile(canonicalDir, ...
    "jsonhotel_unified_001_002_SAFE_20260628_181406.h5");

generatorFile = fullfile(canonicalDir, ...
    "YEHOSHUA_formula_embedding_from_SSOT_v13.m");

expectedHash = ...
    "5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013";

expectedDataset = "/n_5_composite_field_1000x1000/data";

assert(isfolder(artifactDir), ...
    "Artifact folder not found: %s", artifactDir);

assert(isfile(ssotFile), ...
    "Canonical SSOT not found: %s", ssotFile);

assert(isfile(generatorFile), ...
    "Exact V15 generator not found: %s", generatorFile);

fprintf("\n============================================================\n");
fprintf("YEHOSHUA V15 — FINAL GEODESIC EVIDENCE AUDIT\n");
fprintf("============================================================\n\n");

%% 1. Canonical source integrity

actualHash = string(sha256File(ssotFile));

assert(strcmpi(actualHash, expectedHash), ...
    "STOP: canonical H5 SHA-256 mismatch. Expected %s, got %s", ...
    expectedHash, actualHash);

fprintf("[PASS] Canonical SSOT SHA-256 is exact:\n");
fprintf("       %s\n", actualHash);

%% 2. Manifest and artifact integrity

manifestFile = fullfile(artifactDir, ...
    "YEHOSHUA_projection_temporal_manifest.csv");

assert(isfile(manifestFile), "Manifest is missing.");

T = readtable(manifestFile, ...
    "Delimiter", ",", ...
    "ReadVariableNames", true, ...
    "TextType", "string", ...
    "VariableNamingRule", "preserve");

requiredColumns = [ ...
    "anchor_index", "method_id", "n_frames", ...
    "base_png", "final_png", "motion_energy_png", ...
    "temporal_delta_png", "projection_map_png", ...
    "mask_png", "framesheet_png", "temporal_patch_mat"];

assert(all(ismember(requiredColumns, ...
    string(T.Properties.VariableNames))), ...
    "Manifest schema is incomplete.");

assert(height(T) == 12, ...
    "Expected 12 manifest rows; found %d.", height(T));

assert(numel(unique(T.anchor_index)) == 4, ...
    "Expected four anchors.");

assert(numel(unique(string(T.method_id))) == 3, ...
    "Expected three methods.");

assert(all(T.n_frames == 16), ...
    "Every row must contain 16 frames.");

fileColumns = [ ...
    "base_png", "final_png", "motion_energy_png", ...
    "temporal_delta_png", "projection_map_png", ...
    "mask_png", "framesheet_png", "temporal_patch_mat"];

referenced = strings(0,1);

for c = fileColumns
    names = string(T.(c));
    referenced = [referenced; names]; %#ok<AGROW>

    for i = 1:numel(names)
        assert(isfile(fullfile(artifactDir, names(i))), ...
            "Manifest target is missing: %s", names(i));
    end
end

referenced = unique(referenced);

assert(numel(referenced) == 88, ...
    "Expected 88 unique manifest artifacts; found %d.", ...
    numel(referenced));

allEntries = dir(artifactDir);
allEntries = allEntries(~[allEntries.isdir]);

fprintf("[PASS] Folder inventory: %d files; ", numel(allEntries));
fprintf("all 88 manifest artifacts exist.\n");

%% 3. Read all temporal MAT files

n = height(T);

mainMask = cell(n,1);
relationMask = cell(n,1);
formulaMask = cell(n,1);
baseChannels = cell(n,1);
roiMeta = cell(n,1);

allFieldPaths = strings(0,1);
mode = strings(n,1);
dataset = strings(n,1);

metricNames = [ ...
    "mask_density", ...
    "mean_motion_energy", ...
    "max_motion_energy", ...
    "temporal_stability_mean", ...
    "structure_preservation", ...
    "formula_region_motion_ratio", ...
    "projection_alignment_mean", ...
    "projected_motion_gain"];

maxMetricError = 0;

for i = 1:n
    matPath = fullfile(artifactDir, ...
        string(T.temporal_patch_mat(i)));

    S = load(matPath);

    mustHave = [ ...
        "formula", "method", "metrics", ...
        "ssot", "temporal", "patch"];

    assert(all(isfield(S, cellstr(mustHave))), ...
        "MAT schema is incomplete: %s", matPath);

    assert(strcmpi(string(S.ssot.sha256), expectedHash), ...
        "MAT SSOT hash mismatch: %s", matPath);

    assert(string(S.ssot.dataset) == expectedDataset, ...
        "Unexpected source dataset in %s", matPath);

    assert(double(S.temporal.n_frames) == 16, ...
        "Unexpected frame count in %s", matPath);

    assert(string(S.method.id) == string(T.method_id(i)), ...
        "Method mismatch in %s", matPath);

    mainMask{i} = double(S.patch.main_mask);
    relationMask{i} = double(S.patch.relation_mask);
    formulaMask{i} = double(S.patch.formula_mask);
    baseChannels{i} = double(S.patch.base_channels);
    roiMeta{i} = S.patch.roi_meta;

    mode(i) = string(S.method.mode);
    dataset(i) = string(S.ssot.dataset);

    allFieldPaths = [ ...
        allFieldPaths; structFieldPaths(S, "")]; %#ok<AGROW>

    for m = metricNames
        assert(isfield(S.metrics, m), ...
            "Metric %s is missing in %s", m, matPath);

        err = abs(double(S.metrics.(m)) - double(T.(m)(i)));
        maxMetricError = max(maxMetricError, err);
    end
end

assert(maxMetricError <= 1e-5, ...
    "Manifest/MAT metric mismatch: max error %.9g", ...
    maxMetricError);

assert(all(dataset == expectedDataset), ...
    "At least one artifact did not use the declared N5 dataset.");

assert(sum(mode == "geodesic_arc") == 4, ...
    "Expected exactly four geodesic_arc labels.");

fprintf("[PASS] All 12 MAT files match the SSOT, ");
fprintf("manifest and frame count.\n");

fprintf("[PASS] Maximum manifest/MAT metric error = %.9g.\n", ...
    maxMetricError);

%% 4. Independently reconstruct base_channels from the canonical H5

raw = h5read(ssotFile, expectedDataset);
raw = single(raw);
raw(~isfinite(raw)) = 0;

assert(numel(raw) == 5000000, ...
    "Unexpected N5 dataset element count.");

field5 = permute( ...
    reshape(raw(:), 5, 1000, 1000), ...
    [2 3 1]);

field5 = normalizeChannelsLikeGenerator(field5);

maxBaseReconstructionError = 0;

for i = 1:n
    q = roiMeta{i};

    reconstructed = double( ...
        field5(q.r0:q.r1, q.c0:q.c1, :));

    err = max(abs( ...
        reconstructed(:) - baseChannels{i}(:)));

    maxBaseReconstructionError = max( ...
        maxBaseReconstructionError, err);
end

assert(maxBaseReconstructionError <= 5e-7, ...
    "Base-channel reconstruction failed: max error %.9g", ...
    maxBaseReconstructionError);

fprintf("[PASS] Base channels independently reconstructed from H5; ");
fprintf("max error = %.9g.\n", maxBaseReconstructionError);

%% 5. Independence audit

methods = unique(string(T.method_id), "stable");

mainExact = true;
relationsExact = true;
minFormulaCorrelation = 1;
maxMainDifference = 0;
maxRelationDifference = 0;

for m = 1:numel(methods)
    ix = find(string(T.method_id) == methods(m));

    [~, order] = sort(T.anchor_index(ix));
    ix = ix(order);

    for j = 2:numel(ix)
        dm = max(abs( ...
            mainMask{ix(j)}(:) - mainMask{ix(1)}(:)));

        dr = max(abs( ...
            relationMask{ix(j)}(:) - ...
            relationMask{ix(1)}(:)));

        cf = scalarCorrelation( ...
            formulaMask{ix(j)}, formulaMask{ix(1)});

        maxMainDifference = max(maxMainDifference, dm);
        maxRelationDifference = max(maxRelationDifference, dr);
        minFormulaCorrelation = min(minFormulaCorrelation, cf);

        mainExact = mainExact && (dm == 0);
        relationsExact = relationsExact && (dr == 0);
    end
end

% Confirm that the source patches differ, while each anchor's base is
% identical between the three rendering methods.

anchors = unique(T.anchor_index, "stable");
anchorBase = cell(numel(anchors),1);
withinAnchorBaseExact = true;

for a = 1:numel(anchors)
    ix = find(T.anchor_index == anchors(a));
    anchorBase{a} = baseChannels{ix(1)};

    for j = 2:numel(ix)
        withinAnchorBaseExact = withinAnchorBaseExact && ...
            max(abs( ...
                baseChannels{ix(j)}(:) - anchorBase{a}(:))) == 0;
    end
end

betweenAnchorBaseDifferent = true;

for a = 1:numel(anchorBase)
    for b = a+1:numel(anchorBase)
        betweenAnchorBaseDifferent = ...
            betweenAnchorBaseDifferent && ...
            max(abs( ...
                anchorBase{a}(:) - anchorBase{b}(:))) > 1e-6;
    end
end

assert(mainExact && relationsExact, ...
    "Expected deterministic template equality was not reproduced.");

assert(withinAnchorBaseExact && betweenAnchorBaseDifferent, ...
    "Source-patch independence check failed.");

fprintf("\n[PROVED] Four different SSOT patches were used.\n");

fprintf("[PROVED] Yet, within every method, main_mask is ");
fprintf("bit-identical across anchors.\n");
fprintf("         maximum absolute difference = %.17g\n", ...
    maxMainDifference);

fprintf("[PROVED] relation_mask is also bit-identical across anchors.\n");
fprintf("         maximum absolute difference = %.17g\n", ...
    maxRelationDifference);

fprintf("[INFO]   Minimum cross-anchor formula_mask correlation = %.9f.\n", ...
    minFormulaCorrelation);

%% 6. Inspect the exact matching generator

source = fileread(generatorFile);
sourceLower = lower(source);

hasSineCenterline = ~isempty(regexp(source, ...
    "ys\s*=\s*0\.53\s*\*\s*H\s*\+\s*" + ...
    "0\.035\s*\*\s*H\s*\*\s*sin", ...
    "once"));

hasGeodesicLabel = contains(source, '"geodesic_arc"');

hasN5Dataset = contains(source, ...
    '"/n_5_composite_field_1000x1000/data"');

maskStart = regexp(source, ...
    "function masks = make_formula_masks", "once");

embedStart = regexp(source, ...
    "function \[framesRGB, finalCH, motionEnergy", "once");

assert(~isempty(maskStart) && ~isempty(embedStart) && ...
    embedStart > maskStart, ...
    "Could not isolate make_formula_masks in the generator.");

maskCode = source(maskStart:embedStart-1);

drawPosition = regexp(maskCode, ...
    "main\s*=\s*draw_glyph", "once");

relationPosition = regexp(maskCode, ...
    "relations\s*=\s*draw_bezier", "once");

fieldPosition = regexp(maskCode, ...
    "ridge\s*=\s*local_ridge\(baseField\)", "once");

templateBeforeField = ...
    ~isempty(drawPosition) && ...
    ~isempty(relationPosition) && ...
    ~isempty(fieldPosition) && ...
    drawPosition < fieldPosition && ...
    relationPosition < fieldPosition;

solverTokens = [ ...
    "christoffel", ...
    "covariant derivative", ...
    "geodesic equation", ...
    "shortestpath(", ...
    "ode45(", ...
    "eikonal", ...
    "fast marching"];

hasGeodesicSolver = any( ...
    contains(sourceLower, solverTokens));

assert(hasSineCenterline && ...
       hasGeodesicLabel && ...
       hasN5Dataset && ...
       templateBeforeField, ...
       "Generator provenance checks failed.");

assert(~hasGeodesicSolver, ...
    "A geodesic solver token was found; inspect the generator manually.");

fprintf("\n[PROVED] The exact generator prescribes token centers as\n");
fprintf("         y = 0.53 H + 0.035 H sin(t), ");
fprintf("before consulting baseField.\n");

fprintf("[PROVED] 'geodesic_arc' is a method label/vector-field branch;\n");
fprintf("         the generator contains no geodesic-equation solver.\n");

%% 7. Euclidean verdict for the prescribed curve

% Continuous version of the exact centerline:
%
% x(t) = 0.08W + 0.84Wt
% y(t) = 0.53H + 0.035H sin(2*pi*t)

H = 256;
W = 256;
t = linspace(0,1,10001);

xPrime = 0.84 * W * ones(size(t));
yPrime = 0.07 * pi * H * cos(2*pi*t);

xSecond = zeros(size(t));
ySecond = -0.14 * pi^2 * H * sin(2*pi*t);

kappa = abs( ...
    xPrime .* ySecond - yPrime .* xSecond) ./ ...
    (xPrime.^2 + yPrime.^2).^(3/2);

maxEuclideanCurvature = max(kappa);

assert(maxEuclideanCurvature > 0, ...
    "Unexpected zero curvature for the prescribed sine curve.");

fprintf("[PROVED] Maximum Euclidean curvature = ");
fprintf("%.12g pixel^-1 > 0.\n", maxEuclideanCurvature);

fprintf("         Therefore this prescribed curve ");
fprintf("is NOT a Euclidean geodesic.\n");

%% 8. Test whether a non-Euclidean claim is defined

requiredGeometricObjects = [ ...
    "metric_tensor", ...
    "riemannian_metric", ...
    "christoffel_symbols", ...
    "affine_connection", ...
    "curve_parameter", ...
    "geodesic_residual", ...
    "covariant_acceleration"];

allFieldPathsLower = lower(unique(allFieldPaths));
presentObjects = strings(0,1);

for q = requiredGeometricObjects
    found = endsWith(allFieldPathsLower, "." + q) | ...
        allFieldPathsLower == q;

    if any(found)
        presentObjects(end+1,1) = q; %#ok<AGROW>
    end
end

assert(isempty(presentObjects), ...
    "Unexpected geometric object(s) found: %s", ...
    strjoin(presentObjects, ", "));

fprintf("[PROVED] No metric tensor, connection, parameterized curve,\n");
fprintf("         or geodesic residual exists in any MAT schema.\n");

%% 9. Exclude the unrelated MATLAB file in the artifact folder

strayFile = fullfile(artifactDir, ...
    "hotel_ai_harmony_stabilizer.m");

assert(isfile(strayFile), ...
    "Expected folder MATLAB file is missing.");

straySource = fileread(strayFile);

strayIsUnrelated = ...
    ~contains(straySource, "f001_distributive") && ...
    ~contains(straySource, "YEHOSHUA_projection_temporal");

strayUsesOtherH5 = ...
    contains(straySource, "מתמטיקה.h5");

strayUsesOldDatasetNames = ...
    contains(straySource, "'/4_geodesic_field/") && ...
    ~contains(straySource, "'/n_4_geodesic_field/");

assert(strayIsUnrelated && ...
       strayUsesOtherH5 && ...
       strayUsesOldDatasetNames, ...
       "The status of hotel_ai_harmony_stabilizer.m changed.");

fprintf("[PROVED] hotel_ai_harmony_stabilizer.m is unrelated ");
fprintf("and noncanonical;\n");
fprintf("         it cannot supply the missing geodesic test.\n");

%% 10. Disprove projection = geodesic-speed^2 as a general identity

u = [2; 0];
v = [1; 0];

projectionCoefficient = ...
    (u.' * v) / (v.' * v);

vSpeedSquared = v.' * v;

assert(projectionCoefficient ~= vSpeedSquared);

fprintf("[PROVED] Projection coefficient need not equal |v|^2: ");
fprintf("counterexample %.1f ~= %.1f.\n", ...
    projectionCoefficient, vSpeedSquared);

%% 11. Final logically valid result

R = struct();

R.ssot_sha256 = actualHash;
R.manifest_rows = height(T);
R.unique_manifest_artifacts = numel(referenced);

R.max_manifest_metric_error = ...
    maxMetricError;

R.max_base_reconstruction_error = ...
    maxBaseReconstructionError;

R.main_masks_bit_identical_across_anchors = ...
    mainExact;

R.relation_masks_bit_identical_across_anchors = ...
    relationsExact;

R.minimum_formula_mask_cross_anchor_correlation = ...
    minFormulaCorrelation;

R.source_patches_different = ...
    betweenAnchorBaseDifferent;

R.generator_prescribes_sine_centerline = ...
    hasSineCenterline;

R.generator_contains_geodesic_solver = ...
    hasGeodesicSolver;

R.max_euclidean_curvature_pixel_inverse = ...
    maxEuclideanCurvature;

R.metric_or_connection_present = ...
    ~isempty(presentObjects);

R.final_code = ...
    "REJECT_CURRENT_ARTIFACTS_AS_GEODESIC_PROOF";

R.final_statement = ...
    "The recurring structure is a renderer-prescribed formula template, " + ...
    "not an independently discovered SSOT geodesic. It is not a Euclidean " + ...
    "geodesic, and a non-Euclidean geodesic claim is undefined because no " + ...
    "metric or connection was specified or tested.";

fprintf("\n============================================================\n");
fprintf("FINAL VERDICT: %s\n", R.final_code);
fprintf("============================================================\n");

fprintf("%s\n", R.final_statement);

fprintf("\nThis is a definitive negative audit ");
fprintf("of the CURRENT EVIDENCE.\n");

fprintf("It is not a claim that no future, explicitly defined metric ");
fprintf("could make a related curve geodesic.\n\n");

end

function hex = sha256File(filePath)

md = java.security.MessageDigest.getInstance("SHA-256");

fid = fopen(filePath, "rb");
assert(fid >= 0, "Could not open %s", filePath);

cleanup = onCleanup(@() fclose(fid));

while true
    bytes = fread(fid, 1024*1024, "*uint8");

    if isempty(bytes)
        break;
    end

    md.update(bytes);
end

digest = typecast(md.digest(), "uint8");
hex = lower(reshape(dec2hex(digest, 2).', 1, []));

end

function c = scalarCorrelation(A, B)

a = double(A(:));
b = double(B(:));

a = a - mean(a);
b = b - mean(b);

den = sqrt(sum(a.^2) * sum(b.^2));

assert(den > 0, ...
    "Correlation is undefined for a constant array.");

c = sum(a .* b) / den;

end

function paths = structFieldPaths(S, prefix)

names = string(fieldnames(S));
paths = strings(0,1);

for i = 1:numel(names)
    name = names(i);

    if strlength(prefix) == 0
        path = name;
    else
        path = prefix + "." + name;
    end

    paths(end+1,1) = path; %#ok<AGROW>

    value = S.(name);

    if isstruct(value) && isscalar(value)
        paths = [ ...
            paths; structFieldPaths(value, path)]; %#ok<AGROW>
    end
end

end

function output = normalizeChannelsLikeGenerator(input)

input = single(input);
input(~isfinite(input)) = 0;

[height, width, channels] = size(input);

output = zeros(height, width, channels, "single");

for k = 1:channels
    output(:,:,k) = ...
        norm01LikeGenerator(input(:,:,k));
end

end

function output = norm01LikeGenerator(input)

input = single(input);
input(~isfinite(input)) = 0;

lo = percentileLikeGenerator(input, 1);
hi = percentileLikeGenerator(input, 99);

output = ...
    (input - lo) ./ max(hi - lo, eps("single"));

output = min(1, max(0, single(output)));

end

function p = percentileLikeGenerator(input, q)

values = sort(single(input(:)));

assert(~isempty(values), ...
    "Cannot compute a percentile of an empty array.");

k = max(1, min(numel(values), ...
    round(1 + (numel(values)-1)*q/100)));

p = values(k);

end