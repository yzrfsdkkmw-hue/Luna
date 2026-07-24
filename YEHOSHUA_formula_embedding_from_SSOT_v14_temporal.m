function YEHOSHUA_formula_embedding_from_SSOT_v14_temporal()
% YEHOSHUA_FORMULA_EMBEDDING_FROM_SSOT_V14_TEMPORAL
%
% SSOT-only temporal formula embedding.
%
% Reads only from:
%   /MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%
% Core rule:
%   Human mathematical symbols are embedded into the numeric field structure
%   across a temporal sequence, not drawn as text overlay.
%
% V14 additions:
%   - 1000 x 1000 x 5 SSOT channel interpretation
%   - temporal carrier
%   - formula evolves across frames
%   - final frame + motion energy + temporal contact sheet
%
% Active formula:
%   f001_distributive = a(b+c)=ab+ac

clear; clc;

%% =========================
% CONFIG — SINGLE SSOT ONLY
% =========================

SSOT_DIR = "/MATLAB Drive/modelTRAINING";
SSOT_FILENAME = "jsonhotel_unified_001_002_SAFE_20260628_181406.h5";
SSOT_H5_PATH = fullfile(SSOT_DIR, SSOT_FILENAME);

EXPECTED_SSOT_SHA256 = ...
    "5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013";

DATASET_PATH = "/n_5_composite_field_1000x1000/data";

OUTDIR = "YEHOSHUA_temporal_formula_from_SSOT_v14";
ZIP_NAME = "YEHOSHUA_temporal_formula_from_SSOT_v14.zip";

N_ANCHORS = 4;
ROI_WINDOW = 256;
N_FRAMES = 12;

FORMULA_ID = "f001_distributive";

fprintf('\n=== YEHOSHUA TEMPORAL FORMULA FROM SSOT V14 ===\n');
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
% CLEAN OUTPUT
% =========================

try
    diary off;
catch
end

if exist(OUTDIR, 'dir')
    fprintf('[CLEAN] Removing previous output folder.\n');
    rmdir(OUTDIR, 's');
end

if isfile(ZIP_NAME)
    delete(ZIP_NAME);
end

mkdir(OUTDIR);
diary(fullfile(OUTDIR, "YEHOSHUA_temporal_formula_run_log.txt"));

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
methods = temporal_embedding_methods();

manifestRows = {};
contactFiles = {};

%% =========================
% MAIN TEMPORAL EXPERIMENT
% =========================

for ai = 1:numel(anchors)
    a = anchors(ai);

    fprintf('\n[ANCHOR %02d] row=%d col=%d window=%d\n', ...
        ai, a.row, a.col, a.window);

    [roiCH, roiMeta] = extract_roi_channels(CH, a.row, a.col, a.window);
    roiBase = base_from_channels(roiCH);
    baseRGB = render_channels(roiCH);

    baseName = sprintf("yehoshua_v14_a%02d_r%04d_c%04d_w%03d_base.png", ...
        ai, a.row, a.col, a.window);
    imwrite(uint8(255 * clamp01(baseRGB)), fullfile(OUTDIR, baseName));
    contactFiles{end+1} = fullfile(OUTDIR, baseName); %#ok<AGROW>

    for mi = 1:numel(methods)
        method = methods(mi);

        fprintf('  [METHOD] %s\n', char(method.id));

        masks = make_formula_masks(size(roiBase,1), size(roiBase,2), formula, method, roiBase);

        [framesRGB, finalCH, motionEnergy, temporalDelta, metrics] = ...
            temporal_embed_formula_into_channels(roiCH, masks, method, N_FRAMES);

        finalRGB = framesRGB(:,:,:,end);
        motionRGB = render_motion_energy(motionEnergy);
        deltaRGB = render_delta_field(temporalDelta);

        outName = sprintf("yehoshua_v14_a%02d_r%04d_c%04d_w%03d_%s_%s_final.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        motionName = sprintf("yehoshua_v14_a%02d_r%04d_c%04d_w%03d_%s_%s_motion_energy.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        deltaName = sprintf("yehoshua_v14_a%02d_r%04d_c%04d_w%03d_%s_%s_temporal_delta.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        maskName = sprintf("yehoshua_v14_a%02d_r%04d_c%04d_w%03d_%s_%s_mask.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        frameSheetName = sprintf("yehoshua_v14_a%02d_r%04d_c%04d_w%03d_%s_%s_framesheet.png", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        matName = sprintf("yehoshua_v14_a%02d_r%04d_c%04d_w%03d_%s_%s_temporal_patch.mat", ...
            ai, a.row, a.col, a.window, char(formula.id), char(method.id));

        imwrite(uint8(255 * clamp01(finalRGB)), fullfile(OUTDIR, outName));
        imwrite(uint8(255 * clamp01(motionRGB)), fullfile(OUTDIR, motionName));
        imwrite(uint8(255 * clamp01(deltaRGB)), fullfile(OUTDIR, deltaName));
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

        manifestRows(end+1,:) = { ...
            ai, a.row, a.col, a.window, a.score, ...
            string(formula.id), string(formula.human), string(method.id), ...
            N_FRAMES, ...
            metrics.mask_density, metrics.mean_motion_energy, metrics.max_motion_energy, ...
            metrics.temporal_stability_mean, metrics.structure_preservation, ...
            metrics.formula_region_motion_ratio, ...
            string(baseName), string(outName), string(motionName), string(deltaName), ...
            string(maskName), string(frameSheetName), string(matName)}; %#ok<AGROW>
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
    'formula_region_motion_ratio', ...
    'base_png','final_png','motion_energy_png','temporal_delta_png', ...
    'mask_png','framesheet_png','temporal_patch_mat'});

writetable(manifest, fullfile(OUTDIR, "YEHOSHUA_temporal_formula_manifest.csv"));

make_contact_sheet(contactFiles, fullfile(OUTDIR, "YEHOSHUA_temporal_formula_contactsheet.png"));

write_summary(OUTDIR, ssotPath, actualHash, DATASET_PATH, prepareNote, layoutNote, ...
    formula, methods, anchors, manifest, N_FRAMES);

write_config(OUTDIR, SSOT_FILENAME, actualHash, DATASET_PATH, prepareNote, layoutNote, ...
    formula, methods, N_FRAMES);

diary off;

zip(ZIP_NAME, OUTDIR);

fprintf('\n[DONE]\n');
fprintf('Output folder: %s\n', OUTDIR);
fprintf('ZIP: %s\n', ZIP_NAME);
fprintf('\nSend back:\n');
fprintf('1. YEHOSHUA_temporal_formula_contactsheet.png\n');
fprintf('2. YEHOSHUA_temporal_formula_manifest.csv\n');
fprintf('3. YEHOSHUA_temporal_formula_summary.txt\n');
fprintf('4. ZIP if needed\n');

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

scoreMap = norm01(0.55*ridge + 0.30*F + 0.15*lap);

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
    case "f001_distributive"
        f.id = "f001_distributive";
        f.human = "a(b+c)=ab+ac";
        f.tokens = {'a','(','b','+','c',')','=','a','b','+','a','c'};
        f.edges = [
            1 8
            1 11
            3 9
            5 12
        ];
    otherwise
        error('Unknown formula id: %s', id);
end

end

function methods = temporal_embedding_methods()

methods = struct('id', {}, 'mode', {}, 'strength', {}, 'sigma', {}, 'relationStrength', {}, ...
                 'flow', {}, 'radial', {}, 'spiral', {}, 'preserve', {});

methods(1) = struct( ...
    'id',"m01_temporal_visible", ...
    'mode',"visible", ...
    'strength',0.70, ...
    'sigma',0.90, ...
    'relationStrength',0.38, ...
    'flow',0.16, ...
    'radial',0.14, ...
    'spiral',0.10, ...
    'preserve',0.58);

methods(2) = struct( ...
    'id',"m02_temporal_balanced", ...
    'mode',"balanced", ...
    'strength',0.46, ...
    'sigma',1.55, ...
    'relationStrength',0.26, ...
    'flow',0.14, ...
    'radial',0.12, ...
    'spiral',0.08, ...
    'preserve',0.68);

methods(3) = struct( ...
    'id',"m03_temporal_structural", ...
    'mode',"structural", ...
    'strength',0.28, ...
    'sigma',2.35, ...
    'relationStrength',0.18, ...
    'flow',0.11, ...
    'radial',0.10, ...
    'spiral',0.07, ...
    'preserve',0.78);

end

%% ========================================================================
% TEMPORAL MASKS + EMBEDDING
% ========================================================================

function masks = make_formula_masks(H, W, formula, method, baseField)

main = zeros(H,W,'single');
relations = zeros(H,W,'single');

[X,Y] = meshgrid(single(1:W), single(1:H));

n = numel(formula.tokens);

xs = linspace(0.08 * W, 0.92 * W, n);
ys = 0.53 * H + 0.035 * H * sin(linspace(0, 2*pi, n));

scale = max(7, min(H,W) / 34);
thick = max(1.1, min(H,W) / 175);

switch string(method.mode)
    case "visible"
        angleBase = 0.000;
        symbolScale = 1.00;
    case "balanced"
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

    lift = 0.17 * H + 0.018 * H * mod(ei,2);
    pc = [(p1(1)+p2(1))/2, min(p1(2),p2(2)) - lift];

    relations = draw_bezier(relations, X, Y, p1, pc, p2, ...
        max(1.0, thick*0.55), method.relationStrength);
end

soft = blur2(main, method.sigma);
relSoft = blur2(relations, method.sigma * 1.2);

ridge = local_ridge(baseField);
curv = norm01(abs(laplace2(baseField)));

carrier = clamp01((0.66*soft + 0.34*relSoft) .* ...
    (0.22 + 0.58*ridge + 0.20*curv));

masks.main = clamp01(main);
masks.relations = clamp01(relSoft);
masks.soft = clamp01(soft);
masks.carrier = clamp01(carrier);
masks.export = clamp01(0.68*soft + 0.22*relSoft + 0.10*carrier);

end

function [framesRGB, finalCH, motionEnergy, temporalDelta, metrics] = ...
    temporal_embed_formula_into_channels(CH, masks, method, T)

BCH = normalize_channels(CH);
baseBefore = base_from_channels(BCH);

[H,W,K] = size(BCH);
if K < 5
    BCH = replicate_to_5(BCH);
end

[X,Y] = meshgrid(single(1:W), single(1:H));
cx = single((W+1)/2);
cy = single((H+1)/2);

xn = (X - cx) ./ max(1, W);
yn = (Y - cy) ./ max(1, H);
rad = sqrt(xn.^2 + yn.^2);
ang = atan2(yn, xn); 

ridge = local_ridge(baseBefore);
curv = norm01(abs(laplace2(baseBefore)));

framesRGB = zeros(H,W,3,T,'single');
baseFrames = zeros(H,W,T,'single');

for t = 1:T
    tau = single((t-1) / max(1,T-1));
    phase = 2*pi*tau;

    progressive = 1 ./ (1 + exp(-18 * (single(tau) - single(X./W))));
    wave = 0.5 + 0.5*sin(phase + 9*xn + 5*yn + method.spiral*18*ang);
    radialGate = 0.5 + 0.5*sin(phase + method.radial*35*rad);
    flowGate = 0.5 + 0.5*sin(phase + method.flow*25*(xn - yn));

    temporalCarrier = masks.carrier .* ...
        (0.30 + 0.35*progressive + 0.20*wave + 0.15*radialGate) .* ...
        (0.55 + 0.45*flowGate) .* ...
        (0.35 + 0.45*ridge + 0.20*curv);

    temporalCarrier = clamp01(temporalCarrier);

    frameCH = embed_one_temporal_frame(BCH, temporalCarrier, masks, method, tau, ridge, curv);
    frameRGB = render_channels(frameCH);

    framesRGB(:,:,:,t) = frameRGB;
    baseFrames(:,:,t) = base_from_channels(frameCH);
end

finalCH = embed_one_temporal_frame(BCH, masks.carrier, masks, method, 1, ridge, curv);

motionEnergy = zeros(H,W,'single');
for t = 2:T
    motionEnergy = motionEnergy + abs(baseFrames(:,:,t) - baseFrames(:,:,t-1));
end
motionEnergy = motionEnergy ./ max(1,T-1);
motionEnergy = norm01(motionEnergy);

temporalDelta = abs(baseFrames(:,:,end) - baseFrames(:,:,1));
temporalDelta = norm01(temporalDelta);

baseAfter = base_from_channels(finalCH);

stabilities = zeros(T-1,1);
for t = 1:T-1
    stabilities(t) = corr_safe(baseFrames(:,:,t), baseFrames(:,:,t+1));
end

formulaRegion = masks.export > 0.08;
outsideRegion = ~formulaRegion;

insideMotion = mean(motionEnergy(formulaRegion), 'all');
outsideMotion = mean(motionEnergy(outsideRegion), 'all');

metrics = struct();
metrics.mask_density = mean(formulaRegion(:));
metrics.mean_motion_energy = mean(motionEnergy(:));
metrics.max_motion_energy = max(motionEnergy(:));
metrics.temporal_stability_mean = mean(stabilities);
metrics.structure_preservation = corr_safe(baseBefore(:), baseAfter(:));
metrics.formula_region_motion_ratio = insideMotion / max(outsideMotion, eps('single'));

end

function frameCH = embed_one_temporal_frame(BCH, C, masks, method, tau, ridge, curv)

frameCH = BCH;
S = single(method.strength);

switch string(method.mode)
    case "visible"
        frameCH(:,:,1) = norm01(frameCH(:,:,1) + 0.72*S*C + 0.28*S*masks.soft*tau);
        frameCH(:,:,2) = norm01(frameCH(:,:,2) + 0.40*S*masks.relations.*C);
        frameCH(:,:,3) = norm01(frameCH(:,:,3) + 0.56*S*C.*(0.5+0.5*ridge));
        frameCH(:,:,4) = norm01(frameCH(:,:,4) + 0.25*S*C.*curv);
        frameCH(:,:,5) = norm01(frameCH(:,:,5) + 0.44*S*masks.relations.*(0.4+0.6*tau));

    case "balanced"
        frameCH(:,:,1) = norm01(frameCH(:,:,1) + 0.42*S*C.*(0.55+0.45*ridge));
        frameCH(:,:,2) = norm01(frameCH(:,:,2) + 0.28*S*masks.relations.*C);
        frameCH(:,:,3) = norm01(frameCH(:,:,3) + 0.34*S*C.*(0.45+0.55*curv));
        frameCH(:,:,4) = norm01(frameCH(:,:,4) + 0.20*S*masks.soft.*C);
        frameCH(:,:,5) = norm01(frameCH(:,:,5) + 0.25*S*C);

    otherwise
        signedTexture = norm_signed(laplace2(base_from_channels(BCH)));
        structuralCarrier = C .* (0.30 + 0.45*ridge + 0.25*curv);
        frameCH(:,:,1) = norm01(frameCH(:,:,1) + 0.22*S*structuralCarrier);
        frameCH(:,:,2) = norm01(frameCH(:,:,2) + 0.19*S*structuralCarrier.*signedTexture);
        frameCH(:,:,3) = norm01(frameCH(:,:,3) + 0.16*S*masks.relations.*C);
        frameCH(:,:,4) = norm01(frameCH(:,:,4) + 0.17*S*structuralCarrier);
        frameCH(:,:,5) = norm01(frameCH(:,:,5) + 0.15*S*masks.soft.*C);
end

P = single(method.preserve);
frameCH = P*BCH + (1-P)*normalize_channels(frameCH);
frameCH = normalize_channels(frameCH);

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

fid = fopen(fullfile(outdir, "YEHOSHUA_temporal_formula_summary.txt"), 'w');

fprintf(fid, 'YEHOSHUA TEMPORAL FORMULA FROM SSOT V14\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));

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

fprintf(fid, '\nAnchors:\n');
for i = 1:numel(anchors)
    fprintf(fid, '  %02d: row=%d col=%d window=%d score=%.6f\n', ...
        i, anchors(i).row, anchors(i).col, anchors(i).window, anchors(i).score);
end

fprintf(fid, '\nMethods:\n');
for i = 1:numel(methods)
    fprintf(fid, '  %s | mode=%s | strength=%.3f | preserve=%.3f\n', ...
        methods(i).id, methods(i).mode, methods(i).strength, methods(i).preserve);
end

fprintf(fid, '\nManifest rows: %d\n', height(manifest));
fprintf(fid, '\nMeaning:\n');
fprintf(fid, 'Formula structure is coupled into the 5-channel numeric field over time.\n');
fprintf(fid, 'Motion energy marks where the formula participates in temporal field change.\n');
fprintf(fid, 'The SSOT source is never modified. All outputs are derived artifacts.\n');

fclose(fid);

end

function write_config(outdir, ssotFilename, actualHash, datasetPath, prepareNote, layoutNote, formula, methods, nFrames)

fid = fopen(fullfile(outdir, "YEHOSHUA_temporal_formula_config.txt"), 'w');

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
    fprintf(fid, '%s mode=%s strength=%.6f sigma=%.6f relationStrength=%.6f flow=%.6f radial=%.6f spiral=%.6f preserve=%.6f\n', ...
        methods(i).id, methods(i).mode, methods(i).strength, methods(i).sigma, ...
        methods(i).relationStrength, methods(i).flow, methods(i).radial, ...
        methods(i).spiral, methods(i).preserve);
end

fclose(fid);

end

function make_contact_sheet(files, outpath)

if isempty(files)
    return;
end

maxN = min(36, numel(files));
thumbH = 200;
thumbW = 200;
cols = 6;
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

[H,W,~,T] = size(framesRGB);
thumbH = 160;
thumbW = 160;
cols = min(6,T);
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