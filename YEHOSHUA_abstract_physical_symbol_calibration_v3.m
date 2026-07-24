function results = YEHOSHUA_abstract_physical_symbol_calibration_v3()
% YEHOSHUA_abstract_physical_symbol_calibration_v3
%
% Continues directly from:
%   v1 - ten abstract visual representations
%   v2 - structural roles, relations, and temporal state grammar
%
% The output is a human-facing calibration sequence whose symbols are
% coupled to image location, orientation, scale, and local field energy.
% No literal text is rendered into the images.

cfg = configuration();
startTime = tic;

validateInputs(cfg);
grammarState = jsondecode(fileread(cfg.v2StateJSON));
validateGrammarState(grammarState);
dictionary = buildSymbolDictionary();
validateDictionary(dictionary);
normalizedGrammar = normalizePriorGrammar(grammarState);

if ~exist(cfg.outputDirectory, 'dir')
    mkdir(cfg.outputDirectory);
end

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('YEHOSHUA ABSTRACT PHYSICAL SYMBOL CALIBRATION V3\n');
fprintf('%s\n', repmat('=', 1, 72));
fprintf('v1 source : %s\n', cfg.v1Directory);
fprintf('v2 state  : %s\n', cfg.v2StateJSON);
fprintf('output    : %s\n\n', cfg.outputDirectory);

frames = cell(cfg.familyCount, 1);
dictionaryTiles = cell(cfg.familyCount, 1);
metrics = repmat(emptyMetric(), cfg.familyCount, 1);

for familyIndex = 1:cfg.familyCount
    fprintf('[%02d/%02d] Calibrating %s\n', familyIndex, ...
        cfg.familyCount, dictionary.familyNames{familyIndex});

    sourcePath = fullfile(cfg.v1Directory, ...
        cfg.v1Files{familyIndex});
    sourceRGB = resizeRGB(readImage01(sourcePath), cfg.outputSize);
    imageState = analyzeImageState(sourceRGB);

    [unitMask, relationMask, boundaryMask, grammarMask] = ...
        buildFamilyMasks(dictionary, familyIndex, imageState, ...
        normalizedGrammar, cfg);

    [frames{familyIndex}, metrics(familyIndex)] = ...
        integrateCalibration(sourceRGB, imageState, unitMask, ...
        relationMask, boundaryMask, grammarMask, ...
        dictionary, familyIndex, cfg);

    dictionaryTiles{familyIndex} = renderDictionaryTile( ...
        dictionary, familyIndex, cfg);

    outputName = sprintf('calibration_%02d_%s.png', ...
        familyIndex, dictionary.familyNames{familyIndex});
    imwrite(frames{familyIndex}, ...
        fullfile(cfg.outputDirectory, outputName));
end

contactSheet = buildContactSheet(frames, 2, 5, 8);
contactSheetPath = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_calibration_contactsheet.png');
imwrite(contactSheet, contactSheetPath);

dictionarySheet = buildContactSheet(dictionaryTiles, 2, 5, 8);
dictionaryPath = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_dictionary.png');
imwrite(dictionarySheet, dictionaryPath);

videoPath = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_calibration_sequence.mp4');
writeSequenceVideo(frames, videoPath, cfg.videoFPS);

manifestPaths = writeManifests(cfg, dictionary, metrics, ...
    grammarState, startTime);

runData = struct;
runData.version = cfg.version;
runData.subject = 'image_learning';
runData.rendered_text = false;
runData.canonical_h5 = cfg.h5File;
runData.canonical_sha256 = cfg.expectedSHA256;
runData.v1_directory = cfg.v1Directory;
runData.v2_state_json = cfg.v2StateJSON;
runData.family_names = dictionary.familyNames;
runData.primitive_names = dictionary.primitiveNames;
runData.incidence = dictionary.incidence;
runData.metrics = metrics;
runData.generated_at = char(datetime('now'));
save(fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_calibration_run_data.mat'), ...
    'runData', '-v7.3');

results = struct;
results.outputDirectory = cfg.outputDirectory;
results.contactSheet = contactSheetPath;
results.dictionary = dictionaryPath;
results.video = videoPath;
results.manifests = manifestPaths;
results.familyCount = cfg.familyCount;
results.primitiveCount = numel(dictionary.primitiveNames);
results.elapsedSeconds = toc(startTime);

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('RUN COMPLETE\n');
fprintf('Families      : %d\n', cfg.familyCount);
fprintf('Primitives    : %d\n', numel(dictionary.primitiveNames));
fprintf('Contact sheet : %s\n', contactSheetPath);
fprintf('Dictionary    : %s\n', dictionaryPath);
fprintf('Output folder : %s\n', cfg.outputDirectory);
fprintf('Elapsed       : %.3f s\n', results.elapsedSeconds);
fprintf('%s\n', repmat('=', 1, 72));
end


function cfg = configuration()
cfg = struct;
cfg.version = 'YEHOSHUA_abstract_physical_symbol_calibration_v3';
cfg.h5File = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';

cfg.v1Directory = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'YEHOSHUA_particle_visual_sequence_from_SSOT_v1_output'];
cfg.v2Directory = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'YEHOSHUA_structural_pattern_image_learning_v2_output'];
cfg.v2StateJSON = fullfile(cfg.v2Directory, ...
    'YEHOSHUA_notebook_system_state.json');

cfg.v1Files = { ...
    '01_photon.png'
    '02_electron.png'
    '03_neutrino.png'
    '04_quarks.png'
    '05_gluon.png'
    '06_proton.png'
    '07_neutron.png'
    '08_weak_bosons_WZ.png'
    '09_higgs_boson.png'
    '10_nucleus.png'};

cfg.outputDirectory = fullfile(fileparts(cfg.h5File), ...
    [cfg.version '_output']);
cfg.outputSize = 512;
cfg.familyCount = 10;
cfg.videoFPS = 3;
cfg.fieldWarpPixels = 3.5;
cfg.preserveSource = 0.70;
end


function validateInputs(cfg)
assert(isfile(cfg.h5File), 'Canonical H5 file was not found.');
assert(strcmpi(sha256File(cfg.h5File), cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
assert(isfile(cfg.v2StateJSON), 'v2 system-state JSON was not found.');
for i = 1:numel(cfg.v1Files)
    assert(isfile(fullfile(cfg.v1Directory, cfg.v1Files{i})), ...
        'Missing v1 source frame: %s', cfg.v1Files{i});
end
end


function validateGrammarState(state)
assert(isfield(state, 'subject') && strcmp(state.subject, 'image_learning'), ...
    'v2 state is not an image-learning state.');
assert(isfield(state, 'rendered_text') && ~state.rendered_text, ...
    'v2 state must remain free of rendered text.');
assert(state.node_count == 12, 'v2 node count must equal 12.');
assert(state.relation_count == 16, 'v2 relation count must equal 16.');
assert(numel(state.nodes) == 12, 'v2 node array is incomplete.');
assert(numel(state.relations) == 16, 'v2 relation array is incomplete.');
end


function dictionary = buildSymbolDictionary()
dictionary = struct;
dictionary.primitiveNames = { ...
    'point', 'ring', 'arrow', 'line', ...
    'boundary', 'bridge', 'arc', 'balance'};
dictionary.familyNames = { ...
    'localized_presence'
    'directed_quantity'
    'continuous_field'
    'bounded_domain'
    'interaction_coupling'
    'transformation_mapping'
    'superposed_paths'
    'balanced_pair'
    'temporal_samples'
    'composite_system'};
dictionary.incidence = logical([ ...
    1 1 0 0 0 0 0 0
    1 0 1 1 0 0 0 0
    0 0 1 1 0 0 1 0
    0 0 0 1 1 0 0 0
    1 1 0 1 0 1 1 0
    1 0 1 1 1 1 0 0
    0 1 0 1 0 1 1 0
    1 0 0 1 0 1 0 1
    1 0 1 1 0 0 1 1
    1 1 1 1 1 1 1 1]);
end


function validateDictionary(dictionary)
assert(size(dictionary.incidence, 1) == 10, ...
    'Symbol dictionary must contain ten families.');
assert(size(dictionary.incidence, 2) == 8, ...
    'Symbol dictionary must contain eight primitives.');
assert(all(sum(dictionary.incidence, 2) > 0), ...
    'Every family must contain at least one primitive.');

weights = 2 .^ (0:7);
signatures = double(dictionary.incidence) * weights(:);
assert(numel(unique(signatures)) == numel(signatures), ...
    'Every family must have a unique primitive signature.');
assert(rank(double(dictionary.incidence)) == 8, ...
    'Primitive dictionary must have full column rank.');
end


function grammar = normalizePriorGrammar(state)
x = arrayfun(@(node) double(node.x), state.nodes);
y = arrayfun(@(node) double(node.y), state.nodes);
xSpan = max(x) - min(x);
grammar.x = -0.82 + 1.64 .* (x - min(x)) ./ max(xSpan, eps);
grammar.y = 2.2 .* (y - mean(y)) ./ max(xSpan, eps);
grammar.roles = arrayfun(@(node) string(node.role), ...
    state.nodes, UniformOutput=false);
grammar.edges = zeros(numel(state.relations), 2);
grammar.kinds = cell(numel(state.relations), 1);
for i = 1:numel(state.relations)
    grammar.edges(i, :) = [state.relations(i).source, ...
        state.relations(i).target];
    grammar.kinds{i} = state.relations(i).kind;
end
end


function image = readImage01(path)
image = single(imread(path)) ./ 255;
if size(image, 3) == 1
    image = repmat(image, [1, 1, 3]);
end
end


function output = resizeRGB(input, outputSize)
output = zeros(outputSize, outputSize, 3, 'single');
for channel = 1:3
    output(:, :, channel) = resizeBilinear( ...
        input(:, :, channel), outputSize, outputSize);
end
end


function state = analyzeImageState(rgb)
luminance = 0.2126 .* rgb(:, :, 1) + ...
    0.7152 .* rgb(:, :, 2) + 0.0722 .* rgb(:, :, 3);
smooth = gaussianBlur(luminance, 1.2);
[gx, gy] = gradient(smooth);
gradientMagnitude = normalize01(hypot(gx, gy));
curvature = normalize01(abs(del2(gaussianBlur(luminance, 1.8))));
energy = normalize01(0.52 .* normalize01(luminance) + ...
    0.34 .* gradientMagnitude + 0.14 .* curvature);

[height, width] = size(energy);
[xGrid, yGrid] = meshgrid(1:width, 1:height);
threshold = samplePercentile(energy, 0.82);
weights = max(double(energy) - threshold, 0) .^ 2;
if sum(weights(:)) <= eps
    weights = double(energy) .^ 2;
end
weightSum = sum(weights(:)) + eps;
centerX = sum(xGrid(:) .* weights(:)) ./ weightSum;
centerY = sum(yGrid(:) .* weights(:)) ./ weightSum;

dx = xGrid - centerX;
dy = yGrid - centerY;
cxx = sum(weights(:) .* dx(:) .^ 2) ./ weightSum;
cyy = sum(weights(:) .* dy(:) .^ 2) ./ weightSum;
cxy = sum(weights(:) .* dx(:) .* dy(:)) ./ weightSum;
covariance = [cxx, cxy; cxy, cyy];
[vectors, values] = eig(covariance);
[eigenvalues, order] = sort(diag(values), 'descend');
principal = vectors(:, order(1));
angle = atan2(principal(2), principal(1));
scale = min(max(1.45 .* sqrt(max(eigenvalues(1), 1)), 70), 155);

state = struct;
state.luminance = single(luminance);
state.gradientMagnitude = gradientMagnitude;
state.curvature = curvature;
state.energy = energy;
state.center = [centerX, centerY];
state.angle = angle;
state.scale = scale;
state.activeThreshold = threshold;
end


function [unitMask, relationMask, boundaryMask, grammarMask] = ...
    buildFamilyMasks(dictionary, familyIndex, imageState, grammar, cfg)
N = cfg.outputSize;
[xGrid, yGrid] = meshgrid(1:N, 1:N);
dx = (xGrid - imageState.center(1)) ./ imageState.scale;
dy = (yGrid - imageState.center(2)) ./ imageState.scale;
u = cos(imageState.angle) .* dx + sin(imageState.angle) .* dy;
v = -sin(imageState.angle) .* dx + cos(imageState.angle) .* dy;

primitive = cell(8, 1);
primitive{1} = exp(-0.5 .* ((u ./ 0.07) .^ 2 + (v ./ 0.07) .^ 2));
primitive{2} = softStroke(abs(hypot(u, v) - 0.28), 0.035);
primitive{3} = buildArrow(u, v);
primitive{4} = softStroke(abs(v - 0.08 .* sin(5 .* u)), 0.030) .* ...
    single(abs(u) <= 0.62);
outer = max(abs(u), abs(v));
primitive{5} = softStroke(abs(outer - 0.58), 0.035);
primitive{6} = buildBridge(u, v);
primitive{7} = softStroke(abs(v + 0.20 - 0.42 .* u .^ 2), 0.030) .* ...
    single(abs(u) <= 0.66);
primitive{8} = buildBalance(u, v);

selected = dictionary.incidence(familyIndex, :);
unitMask = zeros(N, N, 'single');
relationMask = zeros(N, N, 'single');
boundaryMask = zeros(N, N, 'single');

for primitiveIndex = find(selected)
    current = single(primitive{primitiveIndex});
    if ismember(primitiveIndex, [1, 2])
        unitMask = max(unitMask, current);
    elseif ismember(primitiveIndex, [5, 8])
        boundaryMask = max(boundaryMask, current);
    else
        relationMask = max(relationMask, current);
    end
end

activeGrammarNodes = min(12, max(3, familyIndex + 2));
grammarMask = rasterizePriorGrammar(grammar, activeGrammarNodes, ...
    imageState, cfg);

unitMask = normalize01(unitMask .* (0.38 + 0.62 .* imageState.energy));
relationMask = normalize01(relationMask .* ...
    (0.42 + 0.58 .* imageState.gradientMagnitude));
boundaryMask = normalize01(boundaryMask .* ...
    (0.45 + 0.55 .* imageState.energy));
grammarMask = normalize01(grammarMask .* ...
    (0.36 + 0.64 .* imageState.energy));
end


function arrow = buildArrow(u, v)
shaft = softStroke(segmentDistance(u, v, -0.54, 0, 0.42, 0), 0.035);
headA = softStroke(segmentDistance(u, v, 0.42, 0, 0.12, -0.22), 0.035);
headB = softStroke(segmentDistance(u, v, 0.42, 0, 0.12, 0.22), 0.035);
arrow = max(shaft, max(headA, headB));
end


function bridge = buildBridge(u, v)
left = softStroke(abs(hypot(u + 0.32, v) - 0.14), 0.032);
right = softStroke(abs(hypot(u - 0.32, v) - 0.14), 0.032);
connector = softStroke(segmentDistance(u, v, -0.18, 0, 0.18, 0), 0.035);
bridge = max(left, max(right, connector));
end


function balance = buildBalance(u, v)
bars = max(softStroke(abs(v - 0.11), 0.027), ...
    softStroke(abs(v + 0.11), 0.027)) .* single(abs(u) <= 0.48);
left = exp(-0.5 .* (((u + 0.56) ./ 0.07) .^ 2 + (v ./ 0.07) .^ 2));
right = exp(-0.5 .* (((u - 0.56) ./ 0.07) .^ 2 + (v ./ 0.07) .^ 2));
balance = max(bars, max(left, right));
end


function output = softStroke(distance, width)
output = single(exp(-0.5 .* (double(distance) ./ width) .^ 2));
end


function distance = segmentDistance(x, y, x1, y1, x2, y2)
dx = x2 - x1;
dy = y2 - y1;
t = ((x - x1) .* dx + (y - y1) .* dy) ./ (dx .^ 2 + dy .^ 2 + eps);
t = min(max(t, 0), 1);
distance = hypot(x - (x1 + t .* dx), y - (y1 + t .* dy));
end


function mask = rasterizePriorGrammar(grammar, activeCount, imageState, cfg)
N = cfg.outputSize;
mask = zeros(N, N, 'single');
nodeXY = zeros(12, 2);

for i = 1:12
    localX = 0.86 .* grammar.x(i) .* imageState.scale;
    localY = (0.55 .* grammar.y(i) - 0.28) .* imageState.scale;
    nodeXY(i, 1) = imageState.center(1) + ...
        cos(imageState.angle) .* localX - sin(imageState.angle) .* localY;
    nodeXY(i, 2) = imageState.center(2) + ...
        sin(imageState.angle) .* localX + cos(imageState.angle) .* localY;
end

for i = 1:activeCount
    mask = max(mask, rasterizeDisk(N, nodeXY(i, 1), nodeXY(i, 2), 3.8));
end

for e = 1:size(grammar.edges, 1)
    source = grammar.edges(e, 1);
    target = grammar.edges(e, 2);
    if target <= activeCount
        dependency = strcmp(grammar.kinds{e}, 'dependency');
        bend = -dependency .* min(36, 0.18 .* abs( ...
            nodeXY(target, 1) - nodeXY(source, 1)));
        mask = max(mask, rasterizeRelation(N, nodeXY(source, :), ...
            nodeXY(target, :), bend, 1.35 + 0.55 .* dependency));
    end
end
mask = normalize01(mask);
end


function mask = rasterizeDisk(N, centerX, centerY, radius)
mask = zeros(N, N, 'single');
padding = ceil(radius + 2);
columns = max(1, floor(centerX - padding)):min(N, ceil(centerX + padding));
rows = max(1, floor(centerY - padding)):min(N, ceil(centerY + padding));
[x, y] = meshgrid(columns - centerX, rows - centerY);
disk = single(exp(-0.5 .* (hypot(x, y) ./ max(radius .* 0.55, eps)) .^ 2));
mask(rows, columns) = disk;
end


function mask = rasterizeRelation(N, pointA, pointB, bend, thickness)
mask = zeros(N, N, 'single');
control = 0.5 .* (pointA + pointB) + [0, bend];
t = linspace(0, 1, 120);
curveX = (1 - t) .^ 2 .* pointA(1) + ...
    2 .* (1 - t) .* t .* control(1) + t .^ 2 .* pointB(1);
curveY = (1 - t) .^ 2 .* pointA(2) + ...
    2 .* (1 - t) .* t .* control(2) + t .^ 2 .* pointB(2);

for i = 1:numel(t)
    mask = max(mask, rasterizeDisk(N, curveX(i), curveY(i), thickness));
end
mask = gaussianBlur(mask, 0.45);
end


function [frame, metric] = integrateCalibration(sourceRGB, imageState, ...
    unitMask, relationMask, boundaryMask, grammarMask, ...
    dictionary, familyIndex, cfg)
N = cfg.outputSize;
structure = normalize01( ...
    0.78 .* unitMask + 0.70 .* relationMask + ...
    0.66 .* boundaryMask + 0.38 .* grammarMask);
response = normalize01(gaussianBlur(structure, 3.1));

[responseX, responseY] = gradient(response);
responseX = robustSignedNormalize(responseX);
responseY = robustSignedNormalize(responseY);
[gridX, gridY] = meshgrid(1:N, 1:N);
queryX = gridX + cfg.fieldWarpPixels .* responseX .* response;
queryY = gridY + cfg.fieldWarpPixels .* responseY .* response;

warped = zeros(size(sourceRGB), 'single');
for channel = 1:3
    warped(:, :, channel) = single(interp2( ...
        double(sourceRGB(:, :, channel)), queryX, queryY, ...
        'linear', 0));
end

unitColor = [0.18, 0.92, 1.00];
relationColor = [1.00, 0.28, 0.78];
boundaryColor = [1.00, 0.78, 0.20];
grammarColor = [0.58, 0.40, 1.00];

fieldUnit = unitMask .* (0.35 + 0.65 .* imageState.energy);
fieldRelation = relationMask .* ...
    (0.35 + 0.65 .* imageState.gradientMagnitude);
fieldBoundary = boundaryMask .* ...
    (0.38 + 0.62 .* imageState.energy);
fieldGrammar = grammarMask .* (0.32 + 0.68 .* imageState.energy);

alpha = clamp01(0.08 .* response + 0.72 .* structure);
frame = cfg.preserveSource .* warped .* (1 - repmat(0.48 .* alpha, [1, 1, 3])) + ...
    (1 - cfg.preserveSource) .* sourceRGB;
frame = addColor(frame, fieldUnit, unitColor, 0.78);
frame = addColor(frame, fieldRelation, relationColor, 0.74);
frame = addColor(frame, fieldBoundary, boundaryColor, 0.70);
frame = addColor(frame, fieldGrammar, grammarColor, 0.48);
frame = frame + 0.13 .* repmat(response .^ 1.4, [1, 1, 3]);
frame = uint8(round(255 .* clamp01(frame)));

support = structure > 0.12;
outputLuminance = 0.2126 .* single(frame(:, :, 1)) ./ 255 + ...
    0.7152 .* single(frame(:, :, 2)) ./ 255 + ...
    0.0722 .* single(frame(:, :, 3)) ./ 255;

metric = emptyMetric();
metric.family_index = familyIndex;
metric.family_name = dictionary.familyNames{familyIndex};
metric.primitive_signature = sum(double(dictionary.incidence(familyIndex, :)) .* ...
    (2 .^ (0:7)));
metric.primitive_count = sum(dictionary.incidence(familyIndex, :));
metric.structure_occupancy = mean(support(:));
metric.mean_field_coupling = mean(imageState.energy(support), 'omitnan');
metric.source_preservation = safeCorrelation( ...
    imageState.luminance(:), outputLuminance(:));
metric.center_x = imageState.center(1);
metric.center_y = imageState.center(2);
metric.orientation_radians = imageState.angle;
metric.scale_pixels = imageState.scale;
end


function output = addColor(input, mask, color, gain)
output = input;
for channel = 1:3
    output(:, :, channel) = output(:, :, channel) + ...
        gain .* mask .* color(channel);
end
end


function tile = renderDictionaryTile(dictionary, familyIndex, cfg)
N = cfg.outputSize;
neutral = zeros(N, N, 3, 'single');
state = struct;
state.energy = single(repmat(linspace(0.22, 0.78, N), N, 1));
state.gradientMagnitude = normalize01(abs(gradient(state.energy)));
state.center = [(N + 1) ./ 2, (N + 1) ./ 2];
state.angle = -0.10 + 0.022 .* familyIndex;
state.scale = 0.48 .* N;

dummyGrammar.x = linspace(-0.82, 0.82, 12);
dummyGrammar.y = 0.08 .* sin(linspace(0, 2 .* pi, 12));
dummyGrammar.edges = [(1:11)', (2:12)'];
dummyGrammar.kinds = repmat({'sequence'}, 11, 1);

[unitMask, relationMask, boundaryMask, grammarMask] = ...
    buildFamilyMasks(dictionary, familyIndex, state, dummyGrammar, cfg);
tile = addColor(neutral, unitMask, [0.18, 0.92, 1.00], 0.88);
tile = addColor(tile, relationMask, [1.00, 0.28, 0.78], 0.84);
tile = addColor(tile, boundaryMask, [1.00, 0.78, 0.20], 0.82);
tile = addColor(tile, grammarMask, [0.58, 0.40, 1.00], 0.42);
tile = uint8(round(255 .* clamp01(tile)));
end


function metric = emptyMetric()
metric = struct('family_index', 0, 'family_name', '', ...
    'primitive_signature', 0, 'primitive_count', 0, ...
    'structure_occupancy', 0, 'mean_field_coupling', 0, ...
    'source_preservation', 0, 'center_x', 0, 'center_y', 0, ...
    'orientation_radians', 0, 'scale_pixels', 0);
end


function paths = writeManifests(cfg, dictionary, metrics, grammarState, startTime)
paths = struct;
paths.dictionaryCSV = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_dictionary.csv');
paths.metricsCSV = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_calibration_metrics.csv');
paths.stateJSON = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_calibration_state.json');
paths.summaryTXT = fullfile(cfg.outputDirectory, ...
    'YEHOSHUA_abstract_symbol_calibration_summary.txt');

fileID = fopen(paths.dictionaryCSV, 'w');
assert(fileID > 0, 'Could not create dictionary CSV.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, 'family_index,family_name');
for p = 1:numel(dictionary.primitiveNames)
    fprintf(fileID, ',%s', dictionary.primitiveNames{p});
end
fprintf(fileID, ',signature\n');
for family = 1:cfg.familyCount
    signature = sum(double(dictionary.incidence(family, :)) .* (2 .^ (0:7)));
    fprintf(fileID, '%d,%s', family, dictionary.familyNames{family});
    fprintf(fileID, ',%d', dictionary.incidence(family, :));
    fprintf(fileID, ',%d\n', signature);
end
clear cleanup;

fileID = fopen(paths.metricsCSV, 'w');
assert(fileID > 0, 'Could not create metrics CSV.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, ['family_index,family_name,primitive_signature,' ...
    'primitive_count,structure_occupancy,mean_field_coupling,' ...
    'source_preservation,center_x,center_y,orientation_radians,' ...
    'scale_pixels\n']);
for i = 1:numel(metrics)
    m = metrics(i);
    fprintf(fileID, ['%d,%s,%d,%d,%.9f,%.9f,%.9f,' ...
        '%.6f,%.6f,%.9f,%.6f\n'], ...
        m.family_index, m.family_name, m.primitive_signature, ...
        m.primitive_count, m.structure_occupancy, ...
        m.mean_field_coupling, m.source_preservation, ...
        m.center_x, m.center_y, m.orientation_radians, m.scale_pixels);
end
clear cleanup;

state = struct;
state.version = cfg.version;
state.subject = 'image_learning';
state.rendered_text = false;
state.continues_v1 = true;
state.continues_v2 = true;
state.v2_node_count = grammarState.node_count;
state.v2_relation_count = grammarState.relation_count;
state.family_count = cfg.familyCount;
state.primitive_count = numel(dictionary.primitiveNames);
state.family_names = dictionary.familyNames;
state.primitive_names = dictionary.primitiveNames;
state.incidence = dictionary.incidence;
state.metrics = metrics;
state.canonical_sha256 = cfg.expectedSHA256;
state.generated_at = char(datetime('now'));

fileID = fopen(paths.stateJSON, 'w');
assert(fileID > 0, 'Could not create state JSON.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, '%s', jsonencode(state, PrettyPrint=true));
clear cleanup;

fileID = fopen(paths.summaryTXT, 'w');
assert(fileID > 0, 'Could not create summary TXT.');
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, 'YEHOSHUA ABSTRACT PHYSICAL SYMBOL CALIBRATION V3\n');
fprintf(fileID, 'subject=image_learning\n');
fprintf(fileID, 'rendered_text=false\n');
fprintf(fileID, 'continues_v1=true\n');
fprintf(fileID, 'continues_v2=true\n');
fprintf(fileID, 'family_count=%d\n', cfg.familyCount);
fprintf(fileID, 'primitive_count=%d\n', numel(dictionary.primitiveNames));
fprintf(fileID, 'dictionary_rank=%d\n', rank(double(dictionary.incidence)));
fprintf(fileID, 'mean_source_preservation=%.9f\n', ...
    mean([metrics.source_preservation]));
fprintf(fileID, 'mean_field_coupling=%.9f\n', ...
    mean([metrics.mean_field_coupling]));
fprintf(fileID, 'canonical_sha256=%s\n', cfg.expectedSHA256);
fprintf(fileID, 'elapsed_seconds=%.6f\n', toc(startTime));
clear cleanup;
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


function value = safeCorrelation(a, b)
a = double(a(:));
b = double(b(:));
valid = isfinite(a) & isfinite(b);
a = a(valid);
b = b(valid);
if numel(a) < 3
    value = 0;
    return;
end
a = a - mean(a);
b = b - mean(b);
denominator = sqrt(sum(a .^ 2) .* sum(b .^ 2));
if denominator <= eps
    value = 0;
else
    value = sum(a .* b) ./ denominator;
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
