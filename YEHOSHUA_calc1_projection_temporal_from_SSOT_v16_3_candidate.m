function YEHOSHUA_calc1_projection_temporal_from_SSOT_v16_3_candidate()
% YEHOSHUA_CALC1_PROJECTION_TEMPORAL_FROM_SSOT_V16_3_CANDIDATE
%
% SSOT-only.
%
% Reads only from the authoritative local MATLAB Drive path:
%   /Users/yehoshua/MATLAB-Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%
% V16.3 candidate:
%   SSOT 5-channel field
%   + projection geometry
%   + temporal carrier
%   + Calculus-1 derivative-linearity structure
%
% Core idea:
%   formula(t) = projected formula structure along temporal/geodesic carrier
%
% No old MAT.
% No old PNG.
% No ZIP fallback.
% No metadata labels.
% No text overlay.

clear; clc;

%% =========================
% CONFIG — SINGLE SSOT ONLY
% =========================

SSOT_DIR = "/Users/yehoshua/MATLAB-Drive/modelTRAINING";
SSOT_FILENAME = "jsonhotel_unified_001_002_SAFE_20260628_181406.h5";
SSOT_H5_PATH = fullfile(SSOT_DIR, SSOT_FILENAME);

EXPECTED_SSOT_SHA256 = ...
    "5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013";

DATASET_PATH = "/n_5_composite_field_1000x1000/data";

RUN_STAMP = string(datetime('now','Format','yyyyMMdd_HHmmss'));
OUTDIR = "YEHOSHUA_calc1_projection_temporal_from_SSOT_v16_3_candidate_" + RUN_STAMP;

N_ANCHORS = 4;
ROI_WINDOW = 256;
N_FRAMES = 16;

FORMULA_ID = "f002_derivative_linearity";

fprintf('\n=== YEHOSHUA CALC1 PROJECTION TEMPORAL FROM SSOT V16.3 CANDIDATE ===\n');
fprintf('SSOT path: %s\n', SSOT_H5_PATH);
fprintf('Dataset: %s\n\n', DATASET_PATH);

%% =========================
% VERIFY SSOT
% =========================

ssotPath = char(SSOT_H5_PATH);

if ~isfile(ssotPath)
    error("SSOT H5 not found at the only allowed path: %s", ssotPath);
end

actualHash = sha256_file(ssotPath);

fprintf('[HASH] expected: %s\n', EXPECTED_SSOT_SHA256);
fprintf('[HASH] actual:   %s\n', actualHash);

if strlength(EXPECTED_SSOT_SHA256) > 0 && ~strcmpi(actualHash, EXPECTED_SSOT_SHA256)
    error("SSOT hash mismatch. STOPPING.");
end

fprintf('[HASH] OK\n\n');

%% =========================
% CREATE NEW VERSIONED OUTPUT
% =========================

if exist(OUTDIR, 'dir')
    error("Versioned output already exists; refusing to overwrite: %s", OUTDIR);
end

mkdir(OUTDIR);

fprintf('\n=== RUN LOG ===\n');
fprintf('Created: %s\n', datestr(now));
fprintf('SSOT: %s\n', ssotPath);
fprintf('SSOT SHA256: %s\n', actualHash);
fprintf('Dataset: %s\n\n', DATASET_PATH);

%% =========================
% READ SSOT CHANNEL FIELD
% =========================

fprintf('[READ] Loading 5-channel SSOT field...\n');

raw = h5read(ssotPath, DATASET_PATH);
[CH, prepareNote, layoutNote] = prepare_ssot_5ch(raw);

CH = normalize_channels(CH);
BASE = base_from_channels(CH);

[H, W, K] = size(CH);
ROI_WINDOW = choose_safe_roi_window(ROI_WINDOW, H, W);

fprintf('[FIELD] prepare note: %s\n', prepareNote);
fprintf('[FIELD] layout note: %s\n', layoutNote);
fprintf('[FIELD] size: %d x %d x %d\n', H, W, K);
fprintf('[FIELD] ROI_WINDOW: %d\n', ROI_WINDOW);
fprintf('[FIELD] N_FRAMES: %d\n\n', N_FRAMES);

%% =========================
% ANCHORS
% =========================

fprintf('[ANCHORS] Computing deterministic anchors...\n');

anchors = compute_ssot_anchors(BASE, N_ANCHORS, ROI_WINDOW);

for i = 1:numel(anchors)
    fprintf('  %02d | row=%d col=%d window=%d score=%.6f\n', ...
        i, anchors(i).row, anchors(i).col, anchors(i).window, anchors(i).score);
end

%% =========================
% FORMULA + METHODS
% =========================

formula = formula_def(FORMULA_ID);
methods = projection_temporal_methods();

manifestRows = {};
contactFiles = {};

%% =========================
% MAIN TEMPORAL PROJECTION EXPERIMENT
% =========================

for ai = 1:numel(anchors)
    a = anchors(ai);

    fprintf('\n[ANCHOR %02d] row=%d col=%d window=%d\n', ...
        ai, a.row, a.col, a.window);

    [roiCH, roiMeta] = extract_roi_channels(CH, a.row, a.col, a.window);
    roiBase = base_from_channels(roiCH);
    baseRGB = render_channels(roiCH);

    baseName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_base.png", ...
        ai, a.row, a.col, a.window);

    imwrite(uint8(255 * clamp01(baseRGB)), fullfile(OUTDIR, baseName));
    contactFiles{end+1} = fullfile(OUTDIR, baseName); %#ok<AGROW>

    for mi = 1:numel(methods)
        method = methods(mi);

        fprintf('  [METHOD] %s\n', char(method.id));

        masks = make_formula_masks(size(roiBase,1), size(roiBase,2), formula, method, roiBase);

        [framesRGB, finalCH, motionEnergy, temporalDelta, projectionMap, metrics] = ...
            projection_temporal_embed_formula_into_channels(roiCH, masks, method, N_FRAMES);

        finalRGB = framesRGB(:,:,:,end);
        motionRGB = render_motion_energy(motionEnergy);
        deltaRGB = render_delta_field(temporalDelta);
        projectionRGB = render_projection_map(projectionMap);

        outName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_%s_%s_final.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        motionName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_%s_%s_motion_energy.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        deltaName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_%s_%s_temporal_delta.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        projectionName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_%s_%s_projection_map.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        maskName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_%s_%s_mask.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        frameSheetName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_%s_%s_framesheet.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        matName = sprintf("yehoshua_v16_3_candidate_a%02d_r%04d_c%04d_w%03d_%s_%s_temporal_patch.mat", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        imwrite(uint8(255 * clamp01(finalRGB)), fullfile(OUTDIR, outName));
        imwrite(uint8(255 * clamp01(motionRGB)), fullfile(OUTDIR, motionName));
        imwrite(uint8(255 * clamp01(deltaRGB)), fullfile(OUTDIR, deltaName));
        imwrite(uint8(255 * clamp01(projectionRGB)), fullfile(OUTDIR, projectionName));
        imwrite(uint8(255 * clamp01(masks.export)), fullfile(OUTDIR, maskName));

        make_frame_sheet(framesRGB, fullfile(OUTDIR, frameSheetName));

        ssot = struct();
        ssot.filename = char(SSOT_FILENAME);
        ssot.path = ssotPath;
        ssot.sha256 = char(actualHash);
        ssot.dataset = char(DATASET_PATH);
        ssot.prepare_note = char(prepareNote);
        ssot.layout_note = char(layoutNote);

        temporal = struct();
        temporal.n_frames = N_FRAMES;
        temporal.method = method;
        temporal.motion_energy = single(motionEnergy);
        temporal.temporal_delta = single(temporalDelta);
        temporal.projection_map = single(projectionMap);
        temporal.frames_rgb = single(framesRGB);

        patch = struct();
        patch.anchor_index = ai;
        patch.row = a.row;
        patch.col = a.col;
        patch.window = a.window;
        patch.roi_meta = roiMeta;
        patch.base_channels = single(roiCH);
        patch.final_channels = single(finalCH);
        patch.formula_mask = single(masks.export);
        patch.main_mask = single(masks.main);
        patch.relation_mask = single(masks.relations);

        save(fullfile(OUTDIR, matName), ...
            "ssot", "formula", "method", "patch", "temporal", "metrics", "-v7");

        contactFiles{end+1} = fullfile(OUTDIR, outName); %#ok<AGROW>
        contactFiles{end+1} = fullfile(OUTDIR, motionName); %#ok<AGROW>
        contactFiles{end+1} = fullfile(OUTDIR, projectionName); %#ok<AGROW>

        manifestRows(end+1,:) = { ...
            ai, a.row, a.col, a.window, a.score, ...
            string(formula.id), string(formula.human), string(method.id), ...
            N_FRAMES, ...
            metrics.mask_density, ...
            metrics.mean_motion_energy, metrics.max_motion_energy, ...
            metrics.temporal_stability_mean, ...
            metrics.structure_preservation, ...
            metrics.formula_region_motion_ratio, ...
            metrics.projection_alignment_mean, ...
            metrics.projected_motion_gain, ...
            string(baseName), string(outName), string(motionName), string(deltaName), ...
            string(projectionName), string(maskName), string(frameSheetName), string(matName)}; %#ok<AGROW>
    end
end

%% =========================
% WRITE SUMMARY OUTPUTS
% =========================

manifest = cell2table(manifestRows, 'VariableNames', { ...
    'anchor_index','row','col','window','anchor_score', ...
    'formula_id','formula_human','method_id','n_frames', ...
    'mask_density','mean_motion_energy','max_motion_energy', ...
    'temporal_stability_mean','structure_preservation', ...
    'formula_region_motion_ratio','projection_alignment_mean','projected_motion_gain', ...
    'base_png','final_png','motion_energy_png','temporal_delta_png', ...
    'projection_map_png','mask_png','framesheet_png','temporal_patch_mat'});

writetable(manifest, fullfile(OUTDIR, "YEHOSHUA_calc1_v16_3_candidate_manifest.csv"));

make_contact_sheet(contactFiles, fullfile(OUTDIR, "YEHOSHUA_calc1_v16_3_candidate_contactsheet.png"));

write_summary(OUTDIR, ssotPath, actualHash, DATASET_PATH, prepareNote, layoutNote, ...
    formula, methods, anchors, manifest, N_FRAMES);

write_config(OUTDIR, SSOT_FILENAME, actualHash, DATASET_PATH, prepareNote, layoutNote, ...
    formula, methods, N_FRAMES);

write_candidate_scope(OUTDIR, ssotPath, actualHash, DATASET_PATH, formula);

write_run_log(OUTDIR, ssotPath, actualHash, DATASET_PATH, prepareNote, ...
    layoutNote, formula, methods, anchors, manifest, N_FRAMES);

fprintf('\n[DONE]\n');
fprintf('Output folder: %s\n', OUTDIR);
fprintf('\nSend back:\n');
fprintf('1. YEHOSHUA_calc1_v16_3_candidate_contactsheet.png\n');
fprintf('2. YEHOSHUA_calc1_v16_3_candidate_manifest.csv\n');
fprintf('3. YEHOSHUA_calc1_v16_3_candidate_summary.txt\n');

end

%% ========================================================================
% HASH
% ========================================================================

function hashHex = sha256_file(filePath)

fid = fopen(filePath, 'r');
if fid < 0
    error('Cannot open file for SHA256: %s', filePath);
end

bytes = fread(fid, Inf, '*uint8');
fclose(fid);

md = java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(bytes, 'int8'));
digest = typecast(md.digest(), 'uint8');

hashHex = lower(reshape(dec2hex(digest, 2).', 1, []));
hashHex = string(hashHex);

end

%% ========================================================================
% SSOT CHANNEL PREP
% ========================================================================

function [CH, prepareNote, layoutNote] = prepare_ssot_5ch(raw)

A = single(raw);
A = squeeze(A);
A(~isfinite(A)) = 0;

n = numel(A);

if n ~= 5000000
    error("Expected SSOT dataset to contain 5,000,000 values. Actual: %d", n);
end

v = A(:);

candidates = cell(3,1);
notes = strings(3,1);

candidates{1} = reshape(v, 1000, 1000, 5);
notes(1) = "layout_A reshape(v,1000,1000,5)";

candidates{2} = permute(reshape(v, 5, 1000, 1000), [2 3 1]);
notes(2) = "layout_B reshape(v,5,1000,1000)->HxWxC";

candidates{3} = permute(reshape(v, 1000, 5, 1000), [1 3 2]);
notes(3) = "layout_C reshape(v,1000,5,1000)->HxWxC";

scores = zeros(3,1);

for i = 1:3
    scores(i) = field_likeness_score(candidates{i});
end

[~, idx] = max(scores);

CH = candidates{idx};
CH = normalize_channels(CH);

prepareNote = "interpreted 5,000,000 values as 1000x1000x5 channel field";
layoutNote = sprintf('%s | selected by locality score %.6f', notes(idx), scores(idx));

end

function s = field_likeness_score(CH)

CH = normalize_channels(CH);
B = base_from_channels(CH);

gx = abs(diff(B,1,2));
gy = abs(diff(B,1,1));

rough = mean(gx(:)) + mean(gy(:));
contrast = std(B(:));

C1 = corr_safe(B(:,1:end-1), B(:,2:end));
C2 = corr_safe(B(1:end-1,:), B(2:end,:));

s = double(contrast / max(rough, eps('single')) + 0.25*C1 + 0.25*C2);

end

%% ========================================================================
% CHANNEL UTILITIES
% ========================================================================

function CHn = normalize_channels(CH)

CH = single(CH);
CH(~isfinite(CH)) = 0;

if ndims(CH) == 2
    CH = reshape(CH, size(CH,1), size(CH,2), 1);
end

[H,W,K] = size(CH);
CHn = zeros(H,W,K,'single');

for k = 1:K
    CHn(:,:,k) = norm01(CH(:,:,k));
end

end

function B = base_from_channels(CH)

CH = normalize_channels(CH);
B = mean(CH, 3);
B = norm01(B);

end

function win = choose_safe_roi_window(requestedWin, H, W)

minHW = min(H,W);

if minHW < 32
    error('Prepared field too small: %dx%d', H, W);
end

maxWin = max(32, 2 * floor((minHW - 4) / 3));
win = min(requestedWin, maxWin);
win = 2 * floor(win / 2);

if win < 32
    win = 32;
end

end

%% ========================================================================
% ANCHORS
% ========================================================================

function anchors = compute_ssot_anchors(F, nAnchors, win)

[H, W] = size(F);
half = floor(win/2);

ridge = local_ridge(F);
lap = norm01(abs(laplace2(F)));

scoreMap = norm01(0.52*ridge + 0.28*F + 0.20*lap);

valid = true(H,W);
valid(1:half,:) = false;
valid(end-half+1:end,:) = false;
valid(:,1:half) = false;
valid(:,end-half+1:end) = false;
scoreMap(~valid) = -Inf;

[vals, idx] = sort(scoreMap(:), 'descend');

anchors = struct('row', {}, 'col', {}, 'window', {}, 'score', {});
minSep = max(32, round(win * 0.65));

for k = 1:numel(idx)
    if numel(anchors) >= nAnchors
        break;
    end

    if ~isfinite(vals(k))
        continue;
    end

    [r,c] = ind2sub([H,W], idx(k));

    keep = true;
    for j = 1:numel(anchors)
        d = hypot(double(r - anchors(j).row), double(c - anchors(j).col));
        if d < minSep
            keep = false;
            break;
        end
    end

    if keep
        anchors(end+1) = struct( ...
            'row', r, ...
            'col', c, ...
            'window', win, ...
            'score', double(vals(k))); %#ok<AGROW>
    end
end

fallback = [
    round(H/2),    round(W/2)
    round(H*0.35), round(W*0.35)
    round(H*0.35), round(W*0.65)
    round(H*0.65), round(W*0.35)
    round(H*0.65), round(W*0.65)
];

fi = 1;

while numel(anchors) < nAnchors && fi <= size(fallback,1)
    r = fallback(fi,1);
    c = fallback(fi,2);

    r = min(max(r, half+1), H-half);
    c = min(max(c, half+1), W-half);

    anchors(end+1) = struct( ...
        'row', r, ...
        'col', c, ...
        'window', win, ...
        'score', double(scoreMap(r,c))); %#ok<AGROW>

    fi = fi + 1;
end

end

%% ========================================================================
% ROI
% ========================================================================

function [roiCH, meta] = extract_roi_channels(CH, row, col, win)

[H,W,~] = size(CH);
half = floor(win/2);

r0 = max(1, row-half);
c0 = max(1, col-half);
r1 = min(H, r0 + win - 1);
c1 = min(W, c0 + win - 1);

r0 = max(1, r1 - win + 1);
c0 = max(1, c1 - win + 1);

roiCH = CH(r0:r1, c0:c1, :);

meta = struct();
meta.row = row;
meta.col = col;
meta.window = win;
meta.r0 = r0;
meta.r1 = r1;
meta.c0 = c0;
meta.c1 = c1;
meta.height = size(roiCH,1);
meta.width = size(roiCH,2);
meta.channels = size(roiCH,3);

end

%% ========================================================================
% FORMULA + METHODS
% ========================================================================

function f = formula_def(id)

switch string(id)
    case "f002_derivative_linearity"
        f.id = "f002_derivative_linearity";
        f.human = "d/dx[a f(x)+b g(x)] = a f'(x)+b g'(x)";
        % Compact structural encoding: D(af+bg)=aDf+bDg.
        % D is the derivative operator; the relation edges preserve the
        % coefficient/function pairings through the operator.
        f.tokens = {'D','(','a','f','+','b','g',')','=','a','D','f','+','b','D','g'};
        f.layout = "two_row_readable";
        f.relation_scale = 0.10;
        f.edges = [
            1 11
            1 15
            3 10
            4 12
            6 14
            7 16
        ];
    otherwise
        error('Unknown formula id: %s', id);
end

end

function methods = projection_temporal_methods()

methods = struct('id', {}, 'mode', {}, 'strength', {}, 'sigma', {}, 'relationStrength', {}, ...
                 'flow', {}, 'radial', {}, 'spiral', {}, 'preserve', {}, ...
                 'fieldMotionPx', {}, 'formulaMotionPx', {});

methods(1) = struct( ...
    'id',"m01_projection_visible", ...
    'mode',"wave_arc", ...
    'strength',0.78, ...
    'sigma',0.90, ...
    'relationStrength',0.40, ...
    'flow',0.20, ...
    'radial',0.15, ...
    'spiral',0.12, ...
    'preserve',0.56, ...
    'fieldMotionPx',8.0, ...
    'formulaMotionPx',17.0);

methods(2) = struct( ...
    'id',"m02_projection_balanced", ...
    'mode',"geodesic_arc", ...
    'strength',0.54, ...
    'sigma',1.55, ...
    'relationStrength',0.28, ...
    'flow',0.17, ...
    'radial',0.13, ...
    'spiral',0.10, ...
    'preserve',0.66, ...
    'fieldMotionPx',6.5, ...
    'formulaMotionPx',13.0);

methods(3) = struct( ...
    'id',"m03_projection_structural", ...
    'mode',"curvature_flow", ...
    'strength',0.34, ...
    'sigma',2.35, ...
    'relationStrength',0.20, ...
    'flow',0.13, ...
    'radial',0.11, ...
    'spiral',0.08, ...
    'preserve',0.76, ...
    'fieldMotionPx',4.5, ...
    'formulaMotionPx',9.0);

end

%% ========================================================================
% MASKS
% ========================================================================

function masks = make_formula_masks(H, W, formula, method, baseField)

main = zeros(H,W,'single');
relations = zeros(H,W,'single');

[X,Y] = meshgrid(single(1:W), single(1:H));

n = numel(formula.tokens);

if isfield(formula, 'layout') && formula.layout == "two_row_readable"
    splitIndex = 8;
    xs = zeros(1,n);
    ys = zeros(1,n);
    xs(1:splitIndex) = linspace(0.16 * W, 0.84 * W, splitIndex);
    ys(1:splitIndex) = 0.34 * H;
    xs(splitIndex+1:end) = linspace(0.12 * W, 0.88 * W, n-splitIndex);
    ys(splitIndex+1:end) = 0.67 * H;
    scale = max(7, min(H,W) / 32);
else
    xs = linspace(0.08 * W, 0.92 * W, n);
    ys = 0.53 * H + 0.035 * H * sin(linspace(0, 2*pi, n));
    scale = max(7, min(H,W) / 34);
end

thick = max(1.1, min(H,W) / 175);

switch string(method.mode)
    case "wave_arc"
        angleBase = 0.000;
        symbolScale = 1.00;
    case "geodesic_arc"
        angleBase = 0.035;
        symbolScale = 0.94;
    otherwise
        angleBase = -0.060;
        symbolScale = 0.88;
end

centers = zeros(n,2);

for i = 1:n
    token = formula.tokens{i};

    cx = xs(i);
    cy = ys(i);
    centers(i,:) = [cx cy];

    localAngle = angleBase + 0.020 * sin(i * 1.61803398875);
    localScale = scale * symbolScale * (0.94 + 0.06*cos(i));

    main = draw_glyph(main, X, Y, token, cx, cy, localScale, localAngle, thick, 1.0);
end

for ei = 1:size(formula.edges,1)
    p = formula.edges(ei,1);
    q = formula.edges(ei,2);

    p1 = centers(p,:);
    p2 = centers(q,:);

    if isfield(formula, 'layout') && formula.layout == "two_row_readable"
        lateral = (2*mod(ei,2)-1) * 0.025 * W;
        pc = [(p1(1)+p2(1))/2 + lateral, (p1(2)+p2(2))/2];
        relationValue = method.relationStrength * formula.relation_scale;
        relationThickness = max(0.6, thick*0.28);
    else
        lift = 0.17 * H + 0.018 * H * mod(ei,2);
        pc = [(p1(1)+p2(1))/2, min(p1(2),p2(2)) - lift];
        relationValue = method.relationStrength;
        relationThickness = max(1.0, thick*0.55);
    end

    relations = draw_bezier(relations, X, Y, p1, pc, p2, ...
        relationThickness, relationValue);
end

soft = blur2(main, method.sigma);
relSoft = blur2(relations, method.sigma * 1.2);

ridge = local_ridge(baseField);
curv = norm01(abs(laplace2(baseField)));

carrier = clamp01((0.66*soft + 0.34*relSoft) .* ...
    (0.18 + 0.60*ridge + 0.22*curv));

masks.main = clamp01(main);
masks.relations = clamp01(relSoft);
masks.soft = clamp01(soft);
masks.carrier = clamp01(carrier);
masks.export = clamp01(0.68*soft + 0.22*relSoft + 0.10*carrier);

end

%% ========================================================================
% PROJECTION TEMPORAL EMBEDDING
% ========================================================================

function [framesRGB, finalCH, motionEnergy, temporalDelta, projectionMap, metrics] = ...
    projection_temporal_embed_formula_into_channels(CH, masks, method, T)

BCH = normalize_channels(CH);
if size(BCH,3) < 5
    BCH = replicate_to_5(BCH);
end

baseBefore = base_from_channels(BCH);

[H,W,~] = size(BCH);
framesRGB = zeros(H,W,3,T,'single');
baseFrames = zeros(H,W,T,'single');
projectionStack = zeros(H,W,T,'single');

for t = 1:T
    tau = single((t-1) / max(1,T-1));

    [ux, uy] = temporal_vector_field(H, W, method, tau, baseBefore);

    movingCarrier = advect2(masks.carrier, ux, uy, method.formulaMotionPx * (tau - 0.5));
    movingSoft = advect2(masks.soft, ux, uy, method.formulaMotionPx * (tau - 0.5));
    movingRelations = advect2(masks.relations, ux, uy, method.formulaMotionPx * (tau - 0.5));

    projectionCarrier = projected_formula_carrier(baseBefore, movingCarrier, movingSoft, movingRelations, ux, uy, tau);

    fieldMoved = advect_channels(BCH, ux, uy, method.fieldMotionPx * sin(2*pi*tau));
    frameCH = method.preserve * BCH + (1-method.preserve) * fieldMoved;
    frameCH = normalize_channels(frameCH);

    frameCH = embed_projected_frame(frameCH, projectionCarrier, movingSoft, movingRelations, method, tau);

    framesRGB(:,:,:,t) = render_channels(frameCH);
    baseFrames(:,:,t) = base_from_channels(frameCH);
    projectionStack(:,:,t) = projectionCarrier;
end

finalCH = embed_projected_frame(BCH, projectionStack(:,:,end), masks.soft, masks.relations, method, 1);
finalCH = normalize_channels(finalCH);

motionEnergy = zeros(H,W,'single');
for t = 2:T
    motionEnergy = motionEnergy + abs(baseFrames(:,:,t) - baseFrames(:,:,t-1));
end
motionEnergy = norm01(motionEnergy ./ max(1,T-1));

temporalDelta = norm01(abs(baseFrames(:,:,end) - baseFrames(:,:,1)));
projectionMap = norm01(max(projectionStack, [], 3));

baseAfter = base_from_channels(finalCH);

stabilities = zeros(T-1,1);
for t = 1:T-1
    stabilities(t) = corr_safe(baseFrames(:,:,t), baseFrames(:,:,t+1));
end

formulaRegion = masks.export > 0.08;
outsideRegion = ~formulaRegion;

insideMotion = mean(motionEnergy(formulaRegion));
outsideMotion = mean(motionEnergy(outsideRegion));

projVals = projectionMap(formulaRegion);

metrics = struct();
metrics.mask_density = mean(formulaRegion(:));
metrics.mean_motion_energy = mean(motionEnergy(:));
metrics.max_motion_energy = max(motionEnergy(:));
metrics.temporal_stability_mean = mean(stabilities);
metrics.structure_preservation = corr_safe(baseBefore(:), baseAfter(:));
metrics.formula_region_motion_ratio = insideMotion / max(outsideMotion, eps('single'));
metrics.projection_alignment_mean = mean(projVals(:));
metrics.projected_motion_gain = metrics.formula_region_motion_ratio * metrics.projection_alignment_mean;

end

function C = projected_formula_carrier(baseField, carrier, soft, relations, ux, uy, tau)

[gfx, gfy] = gradient(carrier + 0.45*soft + 0.25*relations);
[gbx, gby] = gradient(baseField);

vx = 0.72*gfx + 0.28*gbx;
vy = 0.72*gfy + 0.28*gby;

den = ux.^2 + uy.^2 + eps('single');

coeff = (vx.*ux + vy.*uy) ./ den;

projx = coeff .* ux;
projy = coeff .* uy;

projMag = norm01(sqrt(projx.^2 + projy.^2));

phaseGate = 0.55 + 0.45*sin(2*pi*tau + 6*norm01(baseField));
phaseGate = norm01(phaseGate);

C = clamp01((0.60*carrier + 0.28*soft + 0.12*relations) .* ...
    (0.20 + 0.80*projMag) .* ...
    (0.35 + 0.65*phaseGate));

end

function [ux, uy] = temporal_vector_field(H, W, method, tau, baseField)

[X,Y] = meshgrid(single(1:W), single(1:H));

cx = single((W+1)/2);
cy = single((H+1)/2);

xn = (X - cx) ./ max(1,W);
yn = (Y - cy) ./ max(1,H);

ang = atan2(yn, xn);
rad = sqrt(xn.^2 + yn.^2);

[gx, gy] = gradient(baseField);
gx = norm_signed(gx) - 0.5;
gy = norm_signed(gy) - 0.5;

phase = single(2*pi*tau);

switch string(method.mode)
    case "wave_arc"
        ux = 1.0 + method.flow*sin(phase + 8*xn + 3*yn);
        uy = 0.35*cos(phase + 5*xn) + method.spiral*(-yn);

    case "geodesic_arc"
        arc = sin(phase + 3*xn) + 0.5*cos(phase + 4*yn);
        ux = 0.75 + method.flow*arc + 0.25*gx;
        uy = 0.28 + method.radial*(xn) + method.spiral*cos(ang + phase) + 0.25*gy;

    otherwise
        ux = method.radial*xn - method.spiral*yn + 0.40*gx + 0.35*cos(phase + 5*rad);
        uy = method.radial*yn + method.spiral*xn + 0.40*gy + 0.35*sin(phase + 5*rad);
end

mag = sqrt(ux.^2 + uy.^2) + eps('single');
ux = single(ux ./ mag);
uy = single(uy ./ mag);

end

function frameCH = embed_projected_frame(frameCH, C, soft, relations, method, tau)

frameCH = normalize_channels(frameCH);
S = single(method.strength);

frameCH(:,:,1) = norm01(frameCH(:,:,1) + 0.70*S*C + 0.16*S*soft*tau);
frameCH(:,:,2) = norm01(frameCH(:,:,2) + 0.42*S*C.*relations + 0.10*S*soft);
frameCH(:,:,3) = norm01(frameCH(:,:,3) + 0.55*S*C.*(0.45 + 0.55*tau));
frameCH(:,:,4) = norm01(frameCH(:,:,4) + 0.30*S*C.*soft);
frameCH(:,:,5) = norm01(frameCH(:,:,5) + 0.48*S*C.*relations + 0.10*S*C);

frameCH = normalize_channels(frameCH);

end

function A2 = advect2(A, ux, uy, amountPx)

A = single(A);
[H,W] = size(A);

[X,Y] = meshgrid(single(1:W), single(1:H));

xq = X - single(amountPx) .* ux;
yq = Y - single(amountPx) .* uy;

A2 = interp2(A, xq, yq, 'linear', 0);
A2 = single(A2);
A2 = norm01(A2);

end

function CH2 = advect_channels(CH, ux, uy, amountPx)

CH = normalize_channels(CH);
[H,W,K] = size(CH);

CH2 = zeros(H,W,K,'single');

for k = 1:K
    CH2(:,:,k) = advect2(CH(:,:,k), ux, uy, amountPx);
end

CH2 = normalize_channels(CH2);

end

function Y = replicate_to_5(X)

[H,W,K] = size(X);
Y = zeros(H,W,5,'single');

for i = 1:5
    Y(:,:,i) = X(:,:,mod(i-1,K)+1);
end

end

%% ========================================================================
% RENDER
% ========================================================================

function rgb = render_channels(CH)

CH = normalize_channels(CH);

r = norm01(0.62*CH(:,:,1) + 0.23*CH(:,:,4) + 0.15*local_ridge(CH(:,:,1)));
g = norm01(0.56*CH(:,:,2) + 0.28*CH(:,:,5) + 0.16*local_ridge(CH(:,:,2)));
b = norm01(0.52*CH(:,:,3) + 0.24*CH(:,:,1) + 0.24*CH(:,:,5));

rgb = clamp01(cat(3, r, g, b));

end

function rgb = render_motion_energy(M)

M = norm01(M);
ridge = local_ridge(M);

r = norm01(0.80*M + 0.20*ridge);
g = norm01(0.45*M + 0.55*ridge);
b = norm01(0.25*M + 0.75*ridge);

rgb = clamp01(cat(3, r, g, b));

end

function rgb = render_delta_field(D)

D = norm01(D);
ridge = local_ridge(D);

r = norm01(0.85*D + 0.15*ridge);
g = norm01(0.45*D + 0.55*ridge);
b = norm01(0.25*D + 0.75*ridge);

rgb = clamp01(cat(3, r, g, b));

end

function rgb = render_projection_map(P)

P = norm01(P);
ridge = local_ridge(P);

r = norm01(0.58*P + 0.42*ridge);
g = norm01(0.30*P + 0.70*ridge);
b = norm01(0.80*P + 0.20*ridge);

rgb = clamp01(cat(3, r, g, b));

end

%% ========================================================================
% GLYPHS
% ========================================================================

function mask = draw_glyph(mask, X, Y, token, cx, cy, s, angle, thick, val)

segments = glyph_segments(token);

for k = 1:size(segments,1)
    [x1,y1] = local_to_global(segments(k,1), segments(k,2), cx, cy, s, angle);
    [x2,y2] = local_to_global(segments(k,3), segments(k,4), cx, cy, s, angle);
    mask = draw_line(mask, X, Y, x1, y1, x2, y2, thick, val);
end

end

function segments = glyph_segments(token)

switch token
    case '+'
        segments = [-0.70 0.00 0.70 0.00; 0.00 -0.70 0.00 0.70];
    case '='
        segments = [-0.75 -0.25 0.75 -0.25; -0.75 0.25 0.75 0.25];
    case '('
        segments = arc_segments(0.35, 0.00, 0.55, 1.00, 110, 250, 9);
    case ')'
        segments = arc_segments(-0.35, 0.00, 0.55, 1.00, -70, 70, 9);
    case 'a'
        circ = arc_segments(0.00, 0.10, 0.55, 0.55, 0, 360, 14);
        stem = [0.45 -0.40 0.45 0.70; 0.42 0.08 0.78 0.08];
        segments = [circ; stem];
    case 'b'
        line = [-0.45 -0.90 -0.45 0.90];
        loop = arc_segments(-0.05, 0.25, 0.55, 0.55, -90, 270, 14);
        segments = [line; loop];
    case 'c'
        segments = arc_segments(0.10, 0.05, 0.62, 0.58, 45, 315, 13);
    case 'D'
        stem = [-0.55 -0.90 -0.55 0.90];
        bowl = arc_segments(-0.35, 0.00, 0.95, 0.90, -90, 90, 14);
        segments = [stem; bowl];
    case 'f'
        stem = [0.10 -0.90 -0.10 0.90];
        top = [-0.05 -0.75 0.58 -0.75];
        cross = [-0.48 -0.10 0.42 -0.10];
        segments = [stem; top; cross];
    case 'g'
        loop = arc_segments(0.00, -0.15, 0.58, 0.52, 0, 360, 14);
        descender = [0.48 -0.10 0.38 0.86; 0.38 0.86 -0.25 0.92];
        segments = [loop; descender];
    case 'x'
        segments = [-0.65 -0.65 0.65 0.65; -0.65 0.65 0.65 -0.65];
    case '/'
        segments = [-0.55 0.80 0.55 -0.80];
    case '-'
        segments = [-0.65 0.00 0.65 0.00];
    otherwise
        segments = [-0.22 0.00 0.22 0.00; 0.00 -0.22 0.00 0.22];
end

end

function seg = arc_segments(cx, cy, rx, ry, deg1, deg2, n)

t = linspace(deg1*pi/180, deg2*pi/180, n+1);
seg = zeros(n,4);

for i = 1:n
    x1 = cx + rx*cos(t(i));
    y1 = cy + ry*sin(t(i));
    x2 = cx + rx*cos(t(i+1));
    y2 = cy + ry*sin(t(i+1));
    seg(i,:) = [x1 y1 x2 y2];
end

end

function [xg, yg] = local_to_global(x, y, cx, cy, s, angle)

ca = cos(angle);
sa = sin(angle);

xg = cx + s * (ca*x - sa*y);
yg = cy + s * (sa*x + ca*y);

end

function mask = draw_line(mask, X, Y, x1, y1, x2, y2, thick, val)

vx = x2 - x1;
vy = y2 - y1;
den = vx*vx + vy*vy + eps;

t = ((X - x1)*vx + (Y - y1)*vy) ./ den;
t = min(1, max(0, t));

px = x1 + t*vx;
py = y1 + t*vy;

dist2 = (X - px).^2 + (Y - py).^2;
sigma = max(0.70, thick * 0.65);

stroke = single(val) * exp(-dist2 ./ (2*sigma*sigma));
mask = max(mask, stroke);

end

function mask = draw_bezier(mask, X, Y, p1, pc, p2, thick, val)

steps = 30;
prev = p1;

for i = 1:steps
    t = i / steps;
    p = (1-t)^2 * p1 + 2*(1-t)*t * pc + t^2 * p2;
    mask = draw_line(mask, X, Y, prev(1), prev(2), p(1), p(2), thick, val);
    prev = p;
end

end

%% ========================================================================
% NUMERIC
% ========================================================================

function y = norm01(x)

x = single(x);
x(~isfinite(x)) = 0;

lo = percentile(x, 1);
hi = percentile(x, 99);

y = (x - lo) ./ max(hi - lo, eps('single'));
y = clamp01(y);

end

function p = percentile(x, q)

v = sort(single(x(:)));

if isempty(v)
    p = single(0);
    return;
end

k = max(1, min(numel(v), round(1 + (numel(v)-1)*q/100)));
p = v(k);

end

function y = clamp01(x)

y = min(1, max(0, single(x)));

end

function r = local_ridge(F)

F = single(F);
F(~isfinite(F)) = 0;

[gx, gy] = gradient(F);
r = sqrt(gx.^2 + gy.^2);
r = norm01(r);
r = blur2(r, 0.8);

end

function L = laplace2(F)

F = single(F);
k = single([0 1 0; 1 -4 1; 0 1 0]);
L = conv2(F, k, 'same');

end

function y = blur2(x, sigma)

x = single(x);

if sigma <= 0
    y = x;
    return;
end

rad = max(1, ceil(3*sigma));
[vx, vy] = meshgrid(-rad:rad, -rad:rad);

k = exp(-(vx.^2 + vy.^2) ./ (2*sigma*sigma));
k = single(k ./ sum(k(:)));

y = conv2(x, k, 'same');
y = norm01(y);

end

function y = norm_signed(x)

x = single(x);
x(~isfinite(x)) = 0;

m = max(abs(x(:)));

if m <= eps('single')
    y = zeros(size(x), 'single');
else
    y = 0.5 + 0.5 * (x ./ m);
end

y = clamp01(y);

end

function c = corr_safe(a,b)

a = single(a(:));
b = single(b(:));

a(~isfinite(a)) = 0;
b(~isfinite(b)) = 0;

a = a - mean(a);
b = b - mean(b);

den = sqrt(sum(a.^2) * sum(b.^2));

if den <= eps('single')
    c = 0;
else
    c = double(sum(a.*b) / den);
end

end

%% ========================================================================
% OUTPUT
% ========================================================================

function write_summary(outdir, ssotPath, hash, datasetPath, prepareNote, layoutNote, formula, methods, anchors, manifest, nFrames)

fid = fopen(fullfile(outdir, "YEHOSHUA_calc1_v16_3_candidate_summary.txt"), 'w');

fprintf(fid, 'YEHOSHUA CALC1 PROJECTION TEMPORAL FROM SSOT V16.3 CANDIDATE\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));
fprintf(fid, 'STATUS: CANDIDATE_FOR_REVIEW — NOT AN ACTIVE ANCHOR\n\n');

fprintf(fid, 'SOURCE RULE\n');
fprintf(fid, 'Read only from verified unified SSOT H5.\n');
fprintf(fid, 'No old MAT. No old PNG. No metadata. No fallback outside SSOT.\n\n');

fprintf(fid, 'SSOT path: %s\n', ssotPath);
fprintf(fid, 'SSOT SHA256: %s\n', hash);
fprintf(fid, 'Dataset path used: %s\n', datasetPath);
fprintf(fid, 'Prepare note: %s\n', prepareNote);
fprintf(fid, 'Layout note: %s\n', layoutNote);
fprintf(fid, 'Frames: %d\n\n', nFrames);

fprintf(fid, 'Formula: %s = %s\n', formula.id, formula.human);
fprintf(fid, 'Readable layout: two rows; compact glyph scale; minimal relation weight\n');

fprintf(fid, '\nProjection rule:\n');
fprintf(fid, 'Formula structure gradient is projected onto a temporal vector carrier.\n');
fprintf(fid, 'The projection coefficient follows the same structure as proj_u(v) = ((v.u)/(u.u))u.\n');

fprintf(fid, '\nAnchors:\n');
for i = 1:numel(anchors)
    fprintf(fid, '  %02d: row=%d col=%d window=%d score=%.6f\n', ...
        i, anchors(i).row, anchors(i).col, anchors(i).window, anchors(i).score);
end

fprintf(fid, '\nMethods:\n');
for i = 1:numel(methods)
    fprintf(fid, '  %s | mode=%s | strength=%.3f | preserve=%.3f | formulaMotionPx=%.2f | fieldMotionPx=%.2f\n', ...
        methods(i).id, methods(i).mode, methods(i).strength, methods(i).preserve, ...
        methods(i).formulaMotionPx, methods(i).fieldMotionPx);
end

fprintf(fid, '\nManifest rows: %d\n', height(manifest));
fprintf(fid, '\nMeaning:\n');
fprintf(fid, 'Derivative-linearity structure is coupled into the 5-channel numeric field through projection onto temporal carriers.\n');
fprintf(fid, 'Motion energy marks where the formula participates in temporal field change.\n');
fprintf(fid, 'This is a derived visualization experiment, not evidence that the formula existed in the SSOT.\n');
fprintf(fid, 'The SSOT source is never modified. All outputs are derived artifacts.\n');

fclose(fid);

end

function write_config(outdir, ssotFilename, actualHash, datasetPath, prepareNote, layoutNote, formula, methods, nFrames)

fid = fopen(fullfile(outdir, "YEHOSHUA_calc1_v16_3_candidate_config.txt"), 'w');

fprintf(fid, 'CONFIG\n');
fprintf(fid, 'ssot_filename=%s\n', ssotFilename);
fprintf(fid, 'actual_sha256=%s\n', actualHash);
fprintf(fid, 'dataset_path_used=%s\n', datasetPath);
fprintf(fid, 'prepare_note=%s\n', prepareNote);
fprintf(fid, 'layout_note=%s\n', layoutNote);
fprintf(fid, 'n_frames=%d\n', nFrames);
fprintf(fid, 'formula_id=%s\n', formula.id);
fprintf(fid, 'formula_human=%s\n', formula.human);

fprintf(fid, '\nmethods:\n');
for i = 1:numel(methods)
    fprintf(fid, '%s mode=%s strength=%.6f sigma=%.6f relationStrength=%.6f flow=%.6f radial=%.6f spiral=%.6f preserve=%.6f fieldMotionPx=%.6f formulaMotionPx=%.6f\n', ...
        methods(i).id, methods(i).mode, methods(i).strength, methods(i).sigma, ...
        methods(i).relationStrength, methods(i).flow, methods(i).radial, ...
        methods(i).spiral, methods(i).preserve, methods(i).fieldMotionPx, methods(i).formulaMotionPx);
end

fclose(fid);

end

function write_candidate_scope(outdir, ssotPath, actualHash, datasetPath, formula)

fid = fopen(fullfile(outdir, "00_RUN_SCOPE.md"), 'w');
fprintf(fid, '# YEHOSHUA Calculus-1 V16.3 Candidate Run\n\n');
fprintf(fid, 'Status: `CANDIDATE_FOR_REVIEW`\n\n');
fprintf(fid, 'This run is not an active continuation anchor unless Yehoshua explicitly promotes it after review.\n\n');
fprintf(fid, '## Canonical input\n\n');
fprintf(fid, '- SSOT: `%s`\n', ssotPath);
fprintf(fid, '- SHA-256: `%s`\n', actualHash);
fprintf(fid, '- Dataset: `%s`\n\n', datasetPath);
fprintf(fid, '## Mathematical structure\n\n');
fprintf(fid, '- Formula ID: `%s`\n', formula.id);
fprintf(fid, '- Human form: `%s`\n', formula.human);
fprintf(fid, '- Structural encoding: `D(af+bg)=aDf+bDg`\n\n');
fprintf(fid, '- Layout: two readable rows with compact glyph scale and minimal relation weight.\n\n');
fprintf(fid, '## Safety\n\n');
fprintf(fid, '- Read-only access to the canonical SSOT.\n');
fprintf(fid, '- New timestamped output only.\n');
fprintf(fid, '- No delete, move, rename, overwrite, or ZIP duplication.\n');
fclose(fid);

end

function write_run_log(outdir, ssotPath, actualHash, datasetPath, prepareNote, ...
    layoutNote, formula, methods, anchors, manifest, nFrames)

fid = fopen(fullfile(outdir, "YEHOSHUA_calc1_v16_3_candidate_run_log.txt"), 'w');
if fid < 0
    error('Unable to create explicit run log in %s', outdir);
end

fprintf(fid, 'YEHOSHUA CALC1 V16.3 CANDIDATE RUN LOG\n');
fprintf(fid, 'Created: %s\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
fprintf(fid, 'Status: CANDIDATE_FOR_REVIEW\n');
fprintf(fid, 'SSOT: %s\n', ssotPath);
fprintf(fid, 'SSOT SHA256: %s\n', actualHash);
fprintf(fid, 'Dataset: %s\n', datasetPath);
fprintf(fid, 'Prepare note: %s\n', prepareNote);
fprintf(fid, 'Layout note: %s\n', layoutNote);
fprintf(fid, 'Formula: %s = %s\n', formula.id, formula.human);
fprintf(fid, 'Formula layout: %s\n', formula.layout);
fprintf(fid, 'Frames: %d\n', nFrames);
fprintf(fid, 'Anchors: %d\n', numel(anchors));
fprintf(fid, 'Methods: %d\n', numel(methods));
fprintf(fid, 'Manifest rows: %d\n\n', height(manifest));

fprintf(fid, 'RESULT ROWS\n');
for i = 1:height(manifest)
    fprintf(fid, ['anchor=%d method=%s stability=%.9f preservation=%.9f ' ...
        'motion_ratio=%.9f alignment=%.9f gain=%.9f\n'], ...
        manifest.anchor_index(i), manifest.method_id(i), ...
        manifest.temporal_stability_mean(i), manifest.structure_preservation(i), ...
        manifest.formula_region_motion_ratio(i), manifest.projection_alignment_mean(i), ...
        manifest.projected_motion_gain(i));
end

fclose(fid);

end

function make_contact_sheet(files, outpath)

if isempty(files)
    return;
end

maxN = min(48, numel(files));
thumbH = 180;
thumbW = 180;
cols = 8;
rows = ceil(maxN / cols);

sheet = zeros(rows*thumbH, cols*thumbW, 3, 'single');

for i = 1:maxN
    img = imread(files{i});
    img = im2single_safe(img);

    if size(img,3) == 1
        img = repmat(img, 1, 1, 3);
    end

    img = img(:,:,1:3);
    img = resize_nearest(img, thumbH, thumbW);

    r = floor((i-1)/cols) + 1;
    c = mod(i-1, cols) + 1;

    rr = (r-1)*thumbH + (1:thumbH);
    cc = (c-1)*thumbW + (1:thumbW);

    sheet(rr, cc, :) = img;
end

imwrite(uint8(255 * clamp01(sheet)), outpath);

end

function make_frame_sheet(framesRGB, outpath)

[~,~,~,T] = size(framesRGB);
thumbH = 160;
thumbW = 160;
cols = min(8,T);
rows = ceil(T/cols);

sheet = zeros(rows*thumbH, cols*thumbW, 3, 'single');

for t = 1:T
    img = framesRGB(:,:,:,t);
    img = resize_nearest(img, thumbH, thumbW);

    r = floor((t-1)/cols) + 1;
    c = mod(t-1, cols) + 1;

    rr = (r-1)*thumbH + (1:thumbH);
    cc = (c-1)*thumbW + (1:thumbW);

    sheet(rr, cc, :) = img;
end

imwrite(uint8(255 * clamp01(sheet)), outpath);

end

function img = im2single_safe(img)

if isa(img, 'uint8')
    img = single(img) / 255;
elseif isa(img, 'uint16')
    img = single(img) / 65535;
else
    img = single(img);
    mx = max(img(:));
    if mx > 1
        img = img ./ mx;
    end
end

end

function out = resize_nearest(img, H2, W2)

[H,W,C] = size(img);

rr = round(linspace(1, H, H2));
cc = round(linspace(1, W, W2));

out = zeros(H2, W2, C, 'single');

for k = 1:C
    tmp = img(:,:,k);
    out(:,:,k) = tmp(rr, cc);
end

end
