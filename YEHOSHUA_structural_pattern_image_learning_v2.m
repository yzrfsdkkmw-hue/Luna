function results = YEHOSHUA_structural_pattern_image_learning_v2()
% YEHOSHUA_structural_pattern_image_learning_v2
%
% Image-learning continuation:
%   1. Read the verified canonical H5 field.
%   2. Read the v15 notebook/system description and reference masks.
%   3. Convert notebook visual grammar into neutral structural roles.
%   4. Embed roles and relations into the field geometry without text.
%   5. Export a progressive sequence, contact sheet, video, and manifests.

cfg = configuration();
startTime = tic;

validateInputs(cfg);
systemDocument = jsondecode(fileread(cfg.systemJSON));
validateNotebookSystem(systemDocument);

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('YEHOSHUA STRUCTURAL PATTERN IMAGE LEARNING V2\n');
fprintf('%s\n', repmat('=', 1, 72));
fprintf('Canonical H5 : %s\n', cfg.h5File);
fprintf('System JSON  : %s\n', cfg.systemJSON);
fprintf('Output       : %s\n\n', cfg.outputDirectory);

datasetInfo = h5info(cfg.h5File, cfg.datasetPath);
stack = readCanonicalStack(cfg.h5File, cfg.datasetPath);
stack = selectStructuralROI(stack, cfg.cropSize);
stack = resizeStack(stack, cfg.outputSize);
features = extractFeatures(stack);
backgroundRGB = createBackground(features);

referenceMask = readImage01(cfg.referenceMask);
referenceEnergy = readImage01(cfg.referenceMotionEnergy);
referenceCalibration = calibrateReference(referenceMask, referenceEnergy);

[carrierRow, carrierConfidence] = buildCarrierPath( ...
    features, referenceMask, cfg);

grammar = buildStructuralGrammar(carrierRow, features, cfg);
validateGrammar(grammar);

if ~exist(cfg.outputDirectory, 'dir')
    mkdir(cfg.outputDirectory);
end

frames = cell(cfg.nodeCount, 1);
frameMetrics = repmat(emptyFrameMetric(), cfg.nodeCount, 1);

for step = 1:cfg.nodeCount
    fprintf('[%02d/%02d] Integrating structural state\n', ...
        step, cfg.nodeCount);

    [frames{step}, frameMetrics(step)] = renderStructuralState( ...
        backgroundRGB, features, grammar, step, cfg);

    frameName = sprintf('state_%02d.png', step);
    imwrite(frames{step}, fullfile(cfg.outputDirectory, frameName));
end

contactSheet = buildContactSheet(frames, 3, 4, 8);
contactSheetPath = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_pattern_contactsheet.png');
imwrite(contactSheet, contactSheetPath);

[structureMap, couplingMap] = renderDiagnosticMaps( ...
    features, grammar, cfg);
structureMapPath = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_role_map.png');
couplingMapPath = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_field_coupling.png');
imwrite(structureMap, structureMapPath);
imwrite(couplingMap, couplingMapPath);

videoPath = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_pattern_sequence.mp4');
writeSequenceVideo(frames, videoPath, cfg.videoFPS);

manifestPaths = writeManifests(cfg, grammar, frameMetrics, ...
    carrierConfidence, referenceCalibration, datasetInfo, startTime);

runData = struct;
runData.version = cfg.version;
runData.source_file = cfg.h5File;
runData.source_sha256 = cfg.expectedSHA256;
runData.dataset_path = cfg.datasetPath;
runData.system_json = cfg.systemJSON;
runData.reference_mask = cfg.referenceMask;
runData.reference_motion_energy = cfg.referenceMotionEnergy;
runData.node_count = cfg.nodeCount;
runData.edge_count = size(grammar.edges, 1);
runData.roles = grammar.roles;
runData.node_xy = grammar.nodeXY;
runData.edges = grammar.edges;
runData.frame_metrics = frameMetrics;
runData.generated_at = char(datetime('now'));

save(fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_pattern_run_data.mat'), ...
    'runData', '-v7.3');

results = struct;
results.outputDirectory = cfg.outputDirectory;
results.contactSheet = contactSheetPath;
results.structureMap = structureMapPath;
results.couplingMap = couplingMapPath;
results.video = videoPath;
results.manifests = manifestPaths;
results.nodeCount = cfg.nodeCount;
results.edgeCount = size(grammar.edges, 1);
results.elapsedSeconds = toc(startTime);

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('RUN COMPLETE\n');
fprintf('Frames        : %d\n', cfg.nodeCount);
fprintf('Relations     : %d\n', size(grammar.edges, 1));
fprintf('Contact sheet : %s\n', contactSheetPath);
fprintf('Output folder : %s\n', cfg.outputDirectory);
fprintf('Elapsed       : %.3f s\n', results.elapsedSeconds);
fprintf('%s\n', repmat('=', 1, 72));
end


function cfg = configuration()
cfg = struct;
cfg.version = 'YEHOSHUA_structural_pattern_image_learning_v2';
cfg.h5File = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.datasetPath = '/n_5_composite_field_1000x1000/data';

cfg.v15Directory = ...
    '/Users/yehoshua/Desktop/YEHOSHUA_projection_temporal_formula_from_SSOT_v15';
cfg.systemJSON = fullfile(cfg.v15Directory, ...
    'This is a quantization of knowledge.json');
cfg.referenceMask = fullfile(cfg.v15Directory, ...
    ['yehoshua_v15_a01_r0379_c0129_w256_f001_distributive_' ...
     'm01_projection_visible_mask.png']);
cfg.referenceMotionEnergy = fullfile(cfg.v15Directory, ...
    ['yehoshua_v15_a01_r0379_c0129_w256_f001_distributive_' ...
     'm01_projection_visible_motion_energy.png']);

cfg.outputDirectory = fullfile(fileparts(cfg.h5File), ...
    [cfg.version '_output']);
cfg.outputSize = 512;
cfg.cropSize = 720;
cfg.nodeCount = 12;
cfg.videoFPS = 4;
cfg.glyphRadius = 13;
cfg.relationThickness = 2.2;
cfg.fieldWarpPixels = 4.0;
cfg.referencePathWeight = 0.22;
end


function validateInputs(cfg)
assert(isfile(cfg.h5File), 'Canonical H5 file was not found.');
assert(isfile(cfg.systemJSON), 'Notebook/system JSON was not found.');
assert(isfile(cfg.referenceMask), 'Reference structural mask was not found.');
assert(isfile(cfg.referenceMotionEnergy), ...
    'Reference motion-energy image was not found.');

actualHash = sha256File(cfg.h5File);
assert(strcmpi(actualHash, cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
end


function validateNotebookSystem(document)
requiredFields = { ...
    'layer_11_knowledge_quantization', ...
    'layer_13_relations_and_knowledge_graph', ...
    'layer_18_symbol_calibration', ...
    'layer_19_equation_generation', ...
    'layer_20_notebook_as_dynamic_state'};

for i = 1:numel(requiredFields)
    assert(isfield(document, requiredFields{i}), ...
        'Notebook/system JSON is missing required layer: %s', ...
        requiredFields{i});
end
end


function hex = sha256File(filePath)
command = sprintf('/usr/bin/shasum -a 256 "%s"', ...
    strrep(filePath, '"', '\"'));
[status, output] = system(command);
assert(status == 0, 'Could not compute SHA-256.');
hex = regexp(output, '^[0-9a-fA-F]{64}', 'match', 'once');
assert(~isempty(hex), 'SHA-256 output could not be parsed.');
hex = lower(hex);
end


function stack = readCanonicalStack(h5File, datasetPath)
raw = squeeze(h5read(h5File, datasetPath));
rawSize = size(raw);

if isvector(raw)
    side = round(sqrt(numel(raw)));
    assert(side^2 == numel(raw), ...
        'One-dimensional dataset is not a square field.');
    stack = reshape(single(raw), side, side, 1);
elseif ismatrix(raw)
    rowCount = rawSize(1);
    columnCount = rawSize(2);
    rowSide = round(sqrt(rowCount));
    columnSide = round(sqrt(columnCount));

    if rowCount == columnCount
        stack = reshape(single(raw), rowCount, columnCount, 1);
    elseif columnSide^2 == columnCount && rowCount <= 128
        stack = zeros(columnSide, columnSide, rowCount, 'single');
        for t = 1:rowCount
            stack(:, :, t) = reshape(single(raw(t, :)), ...
                columnSide, columnSide);
        end
    elseif rowSide^2 == rowCount && columnCount <= 128
        stack = zeros(rowSide, rowSide, columnCount, 'single');
        for t = 1:columnCount
            stack(:, :, t) = reshape(single(raw(:, t)), ...
                rowSide, rowSide);
        end
    else
        error('Unsupported canonical dataset shape: %s', ...
            mat2str(rawSize));
    end
elseif ndims(raw) == 3
    dimensions = size(raw);
    bestPair = [];
    bestSize = 0;
    for i = 1:3
        for j = i+1:3
            if dimensions(i) == dimensions(j) && dimensions(i) > bestSize
                bestPair = [i, j];
                bestSize = dimensions(i);
            end
        end
    end
    assert(~isempty(bestPair), 'No equal spatial dimensions were detected.');
    temporalDimension = setdiff(1:3, bestPair);
    stack = permute(single(raw), [bestPair, temporalDimension]);
else
    error('Unsupported canonical dataset dimensionality.');
end

for t = 1:size(stack, 3)
    stack(:, :, t) = normalize01(stack(:, :, t));
end
end


function cropped = selectStructuralROI(stack, cropRequest)
base = mean(stack, 3);
if size(stack, 3) > 1
    temporal = mean(abs(diff(stack, 1, 3)), 3);
else
    temporal = zeros(size(base), 'like', base);
end
[gx, gy] = gradient(gaussianBlur(base, 1.4));
activity = normalize01(0.46 .* normalize01(base) + ...
    0.36 .* normalize01(hypot(gx, gy)) + ...
    0.18 .* normalize01(temporal));
activity = gaussianBlur(activity, max(4, round(min(size(activity)) / 90)));
[~, index] = max(activity(:));
[centerRow, centerColumn] = ind2sub(size(activity), index);

cropSize = min([cropRequest, size(stack, 1), size(stack, 2)]);
cropSize = max(32, floor(cropSize));
firstRow = max(1, min(centerRow - floor(cropSize / 2), ...
    size(stack, 1) - cropSize + 1));
firstColumn = max(1, min(centerColumn - floor(cropSize / 2), ...
    size(stack, 2) - cropSize + 1));
cropped = stack(firstRow:firstRow + cropSize - 1, ...
    firstColumn:firstColumn + cropSize - 1, :);
end


function output = resizeStack(input, outputSize)
output = zeros(outputSize, outputSize, size(input, 3), 'single');
for t = 1:size(input, 3)
    output(:, :, t) = resizeBilinear(input(:, :, t), ...
        outputSize, outputSize);
end
end


function features = extractFeatures(stack)
features.base = normalize01(mean(stack, 3));
if size(stack, 3) > 1
    features.temporal = normalize01(mean(abs(diff(stack, 1, 3)), 3));
else
    features.temporal = zeros(size(features.base), 'single');
end

[gx, gy] = gradient(gaussianBlur(features.base, 1.25));
features.gradientX = single(gx);
features.gradientY = single(gy);
features.gradientMagnitude = normalize01(hypot(gx, gy));
features.orientation = single(atan2(gy, gx));
features.curvature = normalize01(abs(del2(gaussianBlur(features.base, 1.7))));
features.energy = normalize01( ...
    0.42 .* features.base + ...
    0.29 .* features.gradientMagnitude + ...
    0.21 .* features.temporal + ...
    0.08 .* features.curvature);
features.envelope = normalize01(gaussianBlur(features.energy, 5.5));
end


function rgb = createBackground(features)
[height, width] = size(features.base);
[x, y] = meshgrid(linspace(-1, 1, width), ...
    linspace(-1, 1, height));
micro = 0.5 + 0.5 .* sin(2 .* pi .* (8 .* x + 11 .* y) + ...
    1.7 .* features.base + features.orientation);
texture = normalize01( ...
    0.50 .* features.energy + ...
    0.22 .* features.envelope + ...
    0.16 .* micro .* features.gradientMagnitude + ...
    0.12 .* features.temporal);
hue = mod(0.57 + 0.14 .* features.base + ...
    0.06 .* sin(features.orientation) + 0.025 .* micro, 1);
saturation = clamp01(0.68 + 0.22 .* features.gradientMagnitude);
value = clamp01(0.025 + 0.58 .* texture .^ 0.82);
rgb = single(hsv2rgb(cat(3, hue, saturation, value)));
rgb = rgb .* repmat(clamp01(0.30 + 0.70 .* features.envelope), ...
    [1, 1, 3]);
end


function image = readImage01(path)
image = single(imread(path)) ./ 255;
if size(image, 3) == 1
    image = repmat(image, [1, 1, 3]);
end
end


function calibration = calibrateReference(maskRGB, motionRGB)
mask = mean(maskRGB, 3);
motion = mean(motionRGB, 3);
maskSupport = mask > max(0.10, 0.35 .* max(mask(:)));
motionSupport = motion > samplePercentile(motion, 0.70);
calibration = struct;
calibration.mask_occupancy = mean(maskSupport(:));
calibration.motion_occupancy = mean(motionSupport(:));
calibration.mean_motion_on_mask = mean(motion(maskSupport), 'omitnan');
calibration.reference_width = size(maskRGB, 2);
calibration.reference_height = size(maskRGB, 1);
end


function [carrier, confidence] = buildCarrierPath(features, referenceMask, cfg)
N = size(features.energy, 1);
rows = round(0.16 .* N):round(0.84 .* N);
fieldPath = zeros(1, N);
fieldConfidence = zeros(1, N);

for column = 1:N
    localWeights = double(features.energy(rows, column)) .^ 3 + ...
        0.24 .* double(features.gradientMagnitude(rows, column)) .^ 2;
    denominator = sum(localWeights) + eps;
    fieldPath(column) = sum(double(rows(:)) .* localWeights(:)) ./ denominator;
    fieldConfidence(column) = max(localWeights) ./ (mean(localWeights) + eps);
end
fieldPath = smoothVector(fieldPath, 41);

referenceGray = mean(referenceMask, 3);
referenceWeights = max(referenceGray - 0.06, 0) .^ 2;
referencePath = nan(1, size(referenceGray, 2));
for column = 1:size(referenceGray, 2)
    weights = referenceWeights(:, column);
    if sum(weights) > 1e-6
        referencePath(column) = sum((1:size(referenceGray, 1))' .* weights) ./ ...
            sum(weights);
    end
end
valid = find(isfinite(referencePath));
if numel(valid) >= 2
    referencePath = interp1(valid, referencePath(valid), ...
        1:numel(referencePath), 'linear', 'extrap');
else
    referencePath(:) = (size(referenceGray, 1) + 1) ./ 2;
end
referencePath = 1 + (referencePath - 1) .* ...
    (N - 1) ./ max(size(referenceGray, 1) - 1, 1);
referencePath = interp1(linspace(1, N, numel(referencePath)), ...
    referencePath, 1:N, 'linear');
referencePath = smoothVector(referencePath, 31);

carrier = (1 - cfg.referencePathWeight) .* fieldPath + ...
    cfg.referencePathWeight .* referencePath;
carrier = min(max(smoothVector(carrier, 31), 0.14 .* N), 0.86 .* N);
confidence = mean(fieldConfidence);
end


function grammar = buildStructuralGrammar(carrierRow, features, cfg)
nodeColumns = round(linspace(0.10 .* cfg.outputSize, ...
    0.90 .* cfg.outputSize, cfg.nodeCount));
nodeRows = interp1(1:cfg.outputSize, carrierRow, nodeColumns, 'linear');

roles = { ...
    'anchor', 'boundary_open', 'unit', 'relation', ...
    'unit', 'boundary_close', 'transition', 'unit', ...
    'relation', 'unit', 'state', 'closure'};

edges = [(1:cfg.nodeCount-1)', (2:cfg.nodeCount)'; ...
    1, 3; 1, 5; 3, 8; 5, 10; 6, 11];
edgeKind = [repmat({'sequence'}, cfg.nodeCount - 1, 1); ...
    repmat({'dependency'}, 5, 1)];

nodeEnergy = zeros(cfg.nodeCount, 1);
nodeAngle = zeros(cfg.nodeCount, 1);
for i = 1:cfg.nodeCount
    x = nodeColumns(i);
    y = round(nodeRows(i));
    nodeEnergy(i) = features.energy(y, x);
    left = max(1, x - 3);
    right = min(cfg.outputSize, x + 3);
    nodeAngle(i) = atan2(carrierRow(right) - carrierRow(left), ...
        right - left);
end

grammar = struct;
grammar.roles = roles;
grammar.nodeXY = [nodeColumns(:), nodeRows(:)];
grammar.nodeEnergy = nodeEnergy;
grammar.nodeAngle = nodeAngle;
grammar.edges = edges;
grammar.edgeKind = edgeKind;
end


function validateGrammar(grammar)
nodeCount = numel(grammar.roles);
assert(nodeCount == 12, 'Structural grammar must contain 12 nodes.');
assert(size(grammar.edges, 1) == 16, ...
    'Structural grammar must contain 16 relations.');
assert(all(grammar.edges(:) >= 1 & grammar.edges(:) <= nodeCount), ...
    'Structural grammar contains an invalid node index.');
assert(all(grammar.edges(:, 1) < grammar.edges(:, 2)), ...
    'Structural grammar must progress forward in state order.');
end


function metric = emptyFrameMetric()
metric = struct('step', 0, 'active_nodes', 0, 'active_edges', 0, ...
    'structure_occupancy', 0, 'mean_field_coupling', 0, ...
    'mean_local_response', 0);
end


function [frame, metric] = renderStructuralState( ...
    background, features, grammar, step, cfg)
N = cfg.outputSize;
glyphMask = zeros(N, N, 'single');
edgeMask = zeros(N, N, 'single');

for i = 1:step
    radius = cfg.glyphRadius .* (0.88 + 0.24 .* grammar.nodeEnergy(i));
    glyphMask = max(glyphMask, rasterizeGlyph( ...
        N, grammar.nodeXY(i, 1), grammar.nodeXY(i, 2), ...
        grammar.nodeAngle(i), radius, grammar.roles{i}));
end

activeEdgeCount = 0;
for e = 1:size(grammar.edges, 1)
    source = grammar.edges(e, 1);
    target = grammar.edges(e, 2);
    if target <= step
        isDependency = strcmp(grammar.edgeKind{e}, 'dependency');
        bend = -isDependency .* min(54, ...
            0.24 .* abs(grammar.nodeXY(target, 1) - ...
            grammar.nodeXY(source, 1)));
        edgeMask = max(edgeMask, rasterizeRelation( ...
            N, grammar.nodeXY(source, :), grammar.nodeXY(target, :), ...
            bend, cfg.relationThickness + 0.8 .* isDependency));
        activeEdgeCount = activeEdgeCount + 1;
    end
end

structure = normalize01( ...
    glyphMask .* (0.38 + 0.62 .* features.energy) + ...
    0.72 .* edgeMask .* (0.42 + 0.58 .* features.gradientMagnitude));
response = normalize01(gaussianBlur(structure, 3.2));

[responseX, responseY] = gradient(response);
responseX = robustSignedNormalize(responseX);
responseY = robustSignedNormalize(responseY);
[gridX, gridY] = meshgrid(1:N, 1:N);
queryX = gridX + cfg.fieldWarpPixels .* responseX .* response;
queryY = gridY + cfg.fieldWarpPixels .* responseY .* response;

warped = zeros(size(background), 'single');
for channel = 1:3
    warped(:, :, channel) = single(interp2( ...
        double(background(:, :, channel)), queryX, queryY, ...
        'linear', 0));
end

phase = 2 .* pi .* (step - 1) ./ max(cfg.nodeCount - 1, 1);
hue = mod(0.56 + 0.17 .* features.base + ...
    0.08 .* sin(features.orientation + phase), 1);
saturation = clamp01(0.68 + 0.26 .* glyphMask + 0.12 .* edgeMask);
value = clamp01(0.10 + 0.90 .* normalize01( ...
    0.78 .* glyphMask + 0.56 .* edgeMask + 0.38 .* response));
accent = single(hsv2rgb(cat(3, hue, saturation, value)));

alpha = clamp01(0.10 .* response + 0.83 .* structure);
alphaRGB = repmat(alpha, [1, 1, 3]);
frame = warped .* (1 - 0.76 .* alphaRGB) + accent .* alphaRGB;
frame = frame + 0.18 .* repmat(response .^ 1.4, [1, 1, 3]);
frame = uint8(round(255 .* clamp01(frame)));

support = structure > 0.12;
metric = emptyFrameMetric();
metric.step = step;
metric.active_nodes = step;
metric.active_edges = activeEdgeCount;
metric.structure_occupancy = mean(support(:));
if any(support(:))
    metric.mean_field_coupling = mean(features.energy(support));
    metric.mean_local_response = mean(response(support));
end
end


function mask = rasterizeGlyph(N, centerX, centerY, angle, radius, role)
mask = zeros(N, N, 'single');
padding = ceil(1.35 .* radius);
columns = max(1, floor(centerX - padding)):min(N, ceil(centerX + padding));
rows = max(1, floor(centerY - padding)):min(N, ceil(centerY + padding));
[x, y] = meshgrid(columns - centerX, rows - centerY);

localX = (cos(angle) .* x + sin(angle) .* y) ./ radius;
localY = (-sin(angle) .* x + cos(angle) .* y) ./ radius;
ring = abs(hypot(localX, localY) - 0.48) <= 0.11;

switch role
    case 'anchor'
        glyph = ring | hypot(localX, localY) <= 0.13;
    case 'boundary_open'
        glyph = (abs(localX + 0.38) <= 0.09 & abs(localY) <= 0.68) | ...
            (abs(localY - 0.62) <= 0.09 & localX >= -0.38 & localX <= 0.10) | ...
            (abs(localY + 0.62) <= 0.09 & localX >= -0.38 & localX <= 0.10);
    case 'boundary_close'
        glyph = (abs(localX - 0.38) <= 0.09 & abs(localY) <= 0.68) | ...
            (abs(localY - 0.62) <= 0.09 & localX <= 0.38 & localX >= -0.10) | ...
            (abs(localY + 0.62) <= 0.09 & localX <= 0.38 & localX >= -0.10);
    case 'unit'
        glyph = ring;
    case 'relation'
        glyph = (abs(localY - 0.20) <= 0.09 | ...
            abs(localY + 0.20) <= 0.09) & abs(localX) <= 0.58;
    case 'transition'
        glyph = segmentDistance(localX, localY, -0.62, 0, 0.42, 0) <= 0.09 | ...
            segmentDistance(localX, localY, 0.42, 0, 0.04, -0.34) <= 0.09 | ...
            segmentDistance(localX, localY, 0.42, 0, 0.04, 0.34) <= 0.09;
    case 'state'
        outer = max(abs(localX), abs(localY));
        glyph = outer >= 0.48 & outer <= 0.64;
    case 'closure'
        glyph = (abs(localX - 0.22) <= 0.09 | ...
            abs(localX + 0.22) <= 0.09) & abs(localY) <= 0.62;
        glyph = glyph | hypot(localX, localY) <= 0.10;
    otherwise
        glyph = ring;
end

localMask = single(gaussianBlur(single(glyph), 0.55));
mask(rows, columns) = max(mask(rows, columns), localMask);
end


function distance = segmentDistance(x, y, x1, y1, x2, y2)
dx = x2 - x1;
dy = y2 - y1;
t = ((x - x1) .* dx + (y - y1) .* dy) ./ (dx.^2 + dy.^2 + eps);
t = min(max(t, 0), 1);
distance = hypot(x - (x1 + t .* dx), y - (y1 + t .* dy));
end


function mask = rasterizeRelation(N, pointA, pointB, bend, thickness)
mask = zeros(N, N, 'single');
control = 0.5 .* (pointA + pointB) + [0, bend];
t = linspace(0, 1, 150);
curveX = (1 - t).^2 .* pointA(1) + ...
    2 .* (1 - t) .* t .* control(1) + t.^2 .* pointB(1);
curveY = (1 - t).^2 .* pointA(2) + ...
    2 .* (1 - t) .* t .* control(2) + t.^2 .* pointB(2);

radius = max(1, ceil(thickness));
for i = 1:numel(t)
    x = round(curveX(i));
    y = round(curveY(i));
    columns = max(1, x - radius):min(N, x + radius);
    rows = max(1, y - radius):min(N, y + radius);
    [gx, gy] = meshgrid(columns - x, rows - y);
    disk = single(hypot(gx, gy) <= thickness);
    mask(rows, columns) = max(mask(rows, columns), disk);
end
mask = single(gaussianBlur(mask, 0.65));
end


function [structureMap, couplingMap] = renderDiagnosticMaps(features, grammar, cfg)
N = cfg.outputSize;
glyphMask = zeros(N, N, 'single');
edgeMask = zeros(N, N, 'single');

for i = 1:cfg.nodeCount
    glyphMask = max(glyphMask, rasterizeGlyph(N, ...
        grammar.nodeXY(i, 1), grammar.nodeXY(i, 2), ...
        grammar.nodeAngle(i), cfg.glyphRadius, grammar.roles{i}));
end

for e = 1:size(grammar.edges, 1)
    source = grammar.edges(e, 1);
    target = grammar.edges(e, 2);
    isDependency = strcmp(grammar.edgeKind{e}, 'dependency');
    bend = -isDependency .* min(54, ...
        0.24 .* abs(grammar.nodeXY(target, 1) - grammar.nodeXY(source, 1)));
    edgeMask = max(edgeMask, rasterizeRelation(N, ...
        grammar.nodeXY(source, :), grammar.nodeXY(target, :), ...
        bend, cfg.relationThickness + 0.8 .* isDependency));
end

structure = normalize01(glyphMask + 0.70 .* edgeMask);
structureMap = uint8(round(255 .* cat(3, ...
    0.72 .* edgeMask, 0.92 .* structure, glyphMask)));

coupling = normalize01(structure .* (0.30 + 0.70 .* features.energy) + ...
    0.42 .* gaussianBlur(structure, 4.0) .* features.gradientMagnitude);
couplingMap = uint8(round(255 .* cat(3, ...
    coupling, 0.55 .* features.energy, ...
    0.32 .* features.base + 0.68 .* coupling)));
end


function writeSequenceVideo(frames, videoPath, frameRate)
try
    writer = VideoWriter(videoPath, 'MPEG-4');
    writer.FrameRate = frameRate;
    writer.Quality = 96;
    open(writer);
    cleanup = onCleanup(@() closeWriterSafe(writer));
    for i = 1:numel(frames)
        writeVideo(writer, frames{i});
    end
    close(writer);
    clear cleanup;
catch videoError
    warning('Video export failed; PNG sequence is complete. %s', ...
        videoError.message);
end
end


function closeWriterSafe(writer)
try
    close(writer);
catch
end
end


function paths = writeManifests(cfg, grammar, frameMetrics, ...
    carrierConfidence, referenceCalibration, datasetInfo, startTime)
paths = struct;
paths.nodesCSV = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_nodes.csv');
paths.edgesCSV = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_relations.csv');
paths.stateJSON = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_notebook_system_state.json');
paths.summaryTXT = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_structural_pattern_summary.txt');

fileID = fopen(paths.nodesCSV, 'w');
assert(fileID > 0, 'Could not create node manifest.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, 'node_id,role,x,y,local_energy,active_step\n');
for i = 1:cfg.nodeCount
    fprintf(fileID, '%d,%s,%.6f,%.6f,%.9f,%d\n', ...
        i, grammar.roles{i}, grammar.nodeXY(i, 1), ...
        grammar.nodeXY(i, 2), grammar.nodeEnergy(i), i);
end
clear cleanup;

fileID = fopen(paths.edgesCSV, 'w');
assert(fileID > 0, 'Could not create relation manifest.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, 'relation_id,source_node,target_node,kind,active_step\n');
for e = 1:size(grammar.edges, 1)
    fprintf(fileID, '%d,%d,%d,%s,%d\n', e, grammar.edges(e, 1), ...
        grammar.edges(e, 2), grammar.edgeKind{e}, grammar.edges(e, 2));
end
clear cleanup;

nodeState = repmat(struct('id', 0, 'role', '', 'x', 0, 'y', 0, ...
    'local_energy', 0, 'active_step', 0), cfg.nodeCount, 1);
for i = 1:cfg.nodeCount
    nodeState(i).id = i;
    nodeState(i).role = grammar.roles{i};
    nodeState(i).x = grammar.nodeXY(i, 1);
    nodeState(i).y = grammar.nodeXY(i, 2);
    nodeState(i).local_energy = grammar.nodeEnergy(i);
    nodeState(i).active_step = i;
end

relationState = repmat(struct('id', 0, 'source', 0, 'target', 0, ...
    'kind', '', 'active_step', 0), size(grammar.edges, 1), 1);
for e = 1:size(grammar.edges, 1)
    relationState(e).id = e;
    relationState(e).source = grammar.edges(e, 1);
    relationState(e).target = grammar.edges(e, 2);
    relationState(e).kind = grammar.edgeKind{e};
    relationState(e).active_step = grammar.edges(e, 2);
end

state = struct;
state.version = cfg.version;
state.subject = 'image_learning';
state.rendered_text = false;
state.notebook_is_system = true;
state.node_count = cfg.nodeCount;
state.relation_count = size(grammar.edges, 1);
state.nodes = nodeState;
state.relations = relationState;
state.frame_metrics = frameMetrics;
state.reference_calibration = referenceCalibration;
state.carrier_confidence = carrierConfidence;
state.source_sha256 = cfg.expectedSHA256;
state.generated_at = char(datetime('now'));

fileID = fopen(paths.stateJSON, 'w');
assert(fileID > 0, 'Could not create system-state JSON.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, '%s', jsonencode(state, PrettyPrint=true));
clear cleanup;

fileID = fopen(paths.summaryTXT, 'w');
assert(fileID > 0, 'Could not create summary.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, 'YEHOSHUA STRUCTURAL PATTERN IMAGE LEARNING V2\n');
fprintf(fileID, 'subject=image_learning\n');
fprintf(fileID, 'rendered_text=false\n');
fprintf(fileID, 'notebook_is_system=true\n');
fprintf(fileID, 'canonical_sha256=%s\n', cfg.expectedSHA256);
fprintf(fileID, 'dataset_size=%s\n', mat2str(datasetInfo.Dataspace.Size));
fprintf(fileID, 'node_count=%d\n', cfg.nodeCount);
fprintf(fileID, 'relation_count=%d\n', size(grammar.edges, 1));
fprintf(fileID, 'carrier_confidence=%.9f\n', carrierConfidence);
fprintf(fileID, 'reference_mask_occupancy=%.9f\n', ...
    referenceCalibration.mask_occupancy);
fprintf(fileID, 'reference_motion_occupancy=%.9f\n', ...
    referenceCalibration.motion_occupancy);
fprintf(fileID, 'elapsed_seconds=%.6f\n', toc(startTime));
clear cleanup;
end


function sheet = buildContactSheet(frames, rowCount, columnCount, gap)
height = size(frames{1}, 1);
width = size(frames{1}, 2);
sheet = zeros(rowCount .* height + (rowCount - 1) .* gap, ...
    columnCount .* width + (columnCount - 1) .* gap, 3, 'uint8');
for i = 1:numel(frames)
    row = floor((i - 1) ./ columnCount);
    column = mod(i - 1, columnCount);
    firstRow = row .* (height + gap) + 1;
    firstColumn = column .* (width + gap) + 1;
    sheet(firstRow:firstRow + height - 1, ...
        firstColumn:firstColumn + width - 1, :) = frames{i};
end
end


function output = gaussianBlur(input, sigma)
if sigma <= 0
    output = input;
    return;
end
radius = max(1, ceil(3 .* sigma));
coordinate = -radius:radius;
kernel = exp(-(coordinate .^ 2) ./ (2 .* sigma .^ 2));
kernel = kernel ./ sum(kernel);
output = conv2(conv2(double(input), kernel, 'same'), ...
    kernel.', 'same');
output = single(output);
end


function output = resizeBilinear(input, outputRows, outputColumns)
inputRows = size(input, 1);
inputColumns = size(input, 2);
if inputRows == outputRows && inputColumns == outputColumns
    output = single(input);
    return;
end
[queryX, queryY] = meshgrid( ...
    linspace(1, inputColumns, outputColumns), ...
    linspace(1, inputRows, outputRows));
output = interp2(double(input), queryX, queryY, 'linear');
output(~isfinite(output)) = 0;
output = single(output);
end


function output = smoothVector(input, windowSize)
windowSize = max(1, round(windowSize));
kernel = ones(1, windowSize) ./ windowSize;
padding = floor(windowSize ./ 2);
padded = [repmat(input(1), 1, padding), input, ...
    repmat(input(end), 1, padding)];
smoothed = conv(padded, kernel, 'same');
output = smoothed(padding + 1:padding + numel(input));
end


function output = normalize01(input)
input = double(input);
finiteValues = input(isfinite(input));
if isempty(finiteValues)
    output = zeros(size(input), 'single');
    return;
end
if numel(finiteValues) > 200000
    indices = round(linspace(1, numel(finiteValues), 200000));
    finiteValues = finiteValues(indices);
end
finiteValues = sort(finiteValues(:));
low = finiteValues(max(1, round(0.01 .* numel(finiteValues))));
high = finiteValues(min(numel(finiteValues), ...
    round(0.99 .* numel(finiteValues))));
if high <= low
    low = min(finiteValues);
    high = max(finiteValues);
end
if high <= low
    output = zeros(size(input), 'single');
else
    output = single(clamp01((input - low) ./ (high - low)));
end
end


function output = robustSignedNormalize(input)
scale = samplePercentile(abs(input), 0.98);
output = single(min(max(double(input) ./ max(scale, eps), -1), 1));
end


function value = samplePercentile(input, fraction)
values = double(input(isfinite(input)));
if isempty(values)
    value = 0;
    return;
end
if numel(values) > 200000
    indices = round(linspace(1, numel(values), 200000));
    values = values(indices);
end
values = sort(values(:));
index = min(numel(values), max(1, round(fraction .* numel(values))));
value = values(index);
end


function output = clamp01(input)
output = min(max(input, 0), 1);
end
