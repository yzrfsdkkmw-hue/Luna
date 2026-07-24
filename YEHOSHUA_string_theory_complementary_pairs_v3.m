function results = YEHOSHUA_string_theory_complementary_pairs_v3(mode)
% YEHOSHUA_string_theory_complementary_pairs_v3
% Adds non-text complementary visual-learning pairs and tensor files inside
% the two existing string-theory bundles without changing existing files.

if nargin < 1
    mode = "execute";
end
mode = lower(string(mode));
assert(ismember(mode, ["preflight", "execute"]), ...
    'Mode must be preflight or execute.');

cfg = configuration();
startTime = tic;
bundles = defineBundles(cfg);
validateInputs(cfg, bundles);
canonical = extractCanonicalFields(cfg);
[primitives, primitiveNames, topicToSource] = ...
    buildCompletionPrimitives(cfg, canonical);

prepared = cell(numel(bundles), 1);
for bundleIndex = 1:numel(bundles)
    prepared{bundleIndex} = prepareBundle(cfg, bundles(bundleIndex), ...
        canonical, primitives, primitiveNames, topicToSource);
end

validatePreparedBundles(cfg, bundles, prepared, canonical, primitives, ...
    topicToSource);

if mode == "preflight"
    results = summarizeResults(mode, bundles, prepared, startTime);
    fprintf('\nPREFLIGHT COMPLETE - NO OUTPUT FILES WRITTEN\n');
    fprintf('Bundles checked        : %d\n', numel(bundles));
    fprintf('Pairs checked          : %d\n', results.totalPairCount);
    fprintf('New complementary views: %d\n', results.totalPairCount);
    fprintf('Canonical field channels: %d\n', size(canonical.fieldBasis, 3));
    fprintf('Completion primitives  : %d\n', size(primitives, 3));
    fprintf('Elapsed                : %.3f s\n', toc(startTime));
    return;
end

for bundleIndex = 1:numel(bundles)
    writeBundleOutput(cfg, bundles(bundleIndex), prepared{bundleIndex}, ...
        canonical, primitives, primitiveNames, topicToSource, startTime);
end

validateWrittenOutputs(cfg, bundles, prepared);
results = summarizeResults(mode, bundles, prepared, startTime);
fprintf('\nRUN COMPLETE\n');
fprintf('Bundles extended       : %d\n', numel(bundles));
fprintf('Image pairs            : %d\n', results.totalPairCount);
fprintf('New complementary views: %d\n', results.totalPairCount);
fprintf('Paired image files     : %d\n', 2 * results.totalPairCount);
fprintf('Tensor H5 files        : %d\n', numel(bundles));
fprintf('Tensor MAT files       : %d\n', numel(bundles));
fprintf('Existing files changed : 0\n');
fprintf('Elapsed                : %.3f s\n', results.elapsedSeconds);
end


function cfg = configuration()
cfg = struct;
cfg.version = 'YEHOSHUA_string_theory_complementary_pairs_v3';
cfg.subject = 'image_learning';
cfg.domain = 'string_theory_complementary_visual_pairs';
cfg.canonicalH5 = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.basePath = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15'];
cfg.pairFolderName = 'paired_image_learning_v3';
cfg.spatialSize = 64;
cfg.outputImageSize = 512;
cfg.primitiveCount = 12;
cfg.canonicalChannelCount = 14;
end


function bundles = defineBundles(cfg)
bundles = repmat(emptyBundle(), 2, 1);

relative1 = [ ...
    "images/string_foundations/String.png"
    "images/string_foundations/OpenString.png"
    "images/string_foundations/ClosedString.png"
    "images/string_foundations/StringTension.png"
    "images/string_foundations/ModeSpectrum.png"
    "images/string_foundations/Worldsheet.png"
    "images/string_foundations/Brane.png"
    "images/string_foundations/StringInteraction.png"
    "images/string_foundations/CompactDimension.png"
    "images/string_foundations/DualityMapping.png"
    "images/wave_function/WaveFunctionExtension.png"
    "images/wave_function/ProbabilityFlow.png"
    "images/wave_function/PhaseTransport.png"
    "images/wave_function/ModeSuperposition.png"
    "images/terminal_system/HumanSymbolCalibration.png"
    "images/terminal_system/TerminalChain.png"
    "images/terminal_system/ProjectionEfficiency.png"];
original1 = [ ...
    "String"
    "OpenString"
    "ClosedString"
    "StringTension"
    "ModeSpectrum"
    "Worldsheet"
    "Brane"
    "StringInteraction"
    "CompactDimension"
    "DualityMapping"
    "WaveFunctionExtension"
    "ProbabilityFlow"
    "PhaseTransport"
    "ModeSuperposition"
    "HumanSymbolCalibration"
    "TerminalChain"
    "ProjectionEfficiency"];
complement1 = [ ...
    "QuantizedVibration"
    "EndpointBoundaryConditions"
    "PeriodicBoundaryConditions"
    "EnergyLengthScale"
    "OscillatorQuantization"
    "SpacetimeEmbedding"
    "OpenStringBoundary"
    "SplittingJoining"
    "MomentumWinding"
    "RadiusInversion"
    "ComplexAmplitude"
    "ProbabilityCurrent"
    "PhaseCoherence"
    "InterferenceStructure"
    "SymbolMeaningBinding"
    "AcyclicDependency"
    "InformationRetention"];
codes1 = [ ...
    6 5 3
    2 9 3
    2 4 9
    1 3 5
    5 6 9
    1 3 12
    2 7 10
    10 3 11
    1 7 8
    8 4 1
    6 11 12
    11 9 3
    11 4 5
    4 5 10
    12 9 6
    9 12 3
    12 9 11];

bundles(1).name = 'wave_function_string_foundations_v1';
bundles(1).path = fullfile(cfg.basePath, ...
    'YEHOSHUA_wave_function_string_foundations_tensor_training_bundle_v1');
bundles(1).relativePaths = relative1;
bundles(1).originalNames = original1;
bundles(1).complementNames = complement1;
bundles(1).topicCodes = codes1;
bundles(1).pairRoot = fullfile(bundles(1).path, cfg.pairFolderName);

relative2 = [ ...
    "images/concepts/Worldsheet.png"
    "images/concepts/EmbeddingMap.png"
    "images/concepts/ReggeSlope.png"
    "images/concepts/StringTension.png"
    "images/concepts/InducedMetric.png"
    "images/concepts/NambuGotoAction.png"
    "images/concepts/PolyakovAction.png"
    "images/concepts/WeylSymmetry.png"
    "images/concepts/WorldsheetStressEnergy.png"
    "images/concepts/VirasoroAlgebra.png"
    "images/concepts/OscillatorModes.png"
    "images/concepts/LevelMatching.png"
    "images/concepts/CriticalDimension.png"
    "images/concepts/WorldsheetSupersymmetry.png"
    "images/concepts/NeveuSchwarzRamondSectors.png"
    "images/concepts/GSOProjection.png"
    "images/concepts/BRSTCohomology.png"
    "images/concepts/CalabiYauCompactification.png"
    "images/concepts/TDuality.png"
    "images/concepts/DBranes.png"
    "images/canonical_sources/ChamberField.png"
    "images/canonical_sources/ConnectionGraph.png"
    "images/canonical_sources/DefectTopology.png"
    "images/canonical_sources/FuchsianTiling.png"
    "images/canonical_sources/GeodesicTrajectories.png"
    "images/canonical_sources/GinibreField.png"
    "images/canonical_sources/SpectralPalette.png"
    "images/canonical_sources/StreamlineField.png"
    "images/symbol_system/ConceptRelations.png"
    "images/symbol_system/HumanNotationCalibration.png"];
original2 = [ ...
    "Worldsheet"
    "EmbeddingMap"
    "ReggeSlope"
    "StringTension"
    "InducedMetric"
    "NambuGotoAction"
    "PolyakovAction"
    "WeylSymmetry"
    "WorldsheetStressEnergy"
    "VirasoroAlgebra"
    "OscillatorModes"
    "LevelMatching"
    "CriticalDimension"
    "WorldsheetSupersymmetry"
    "NeveuSchwarzRamondSectors"
    "GSOProjection"
    "BRSTCohomology"
    "CalabiYauCompactification"
    "TDuality"
    "DBranes"
    "ChamberField"
    "ConnectionGraph"
    "DefectTopology"
    "FuchsianTiling"
    "GeodesicTrajectories"
    "GinibreField"
    "SpectralPalette"
    "StreamlineField"
    "ConceptRelations"
    "HumanNotationCalibration"];
complement2 = [ ...
    "SpacetimeEmbedding"
    "TargetSpaceCoordinates"
    "MassSpinTrajectory"
    "EnergyLengthScale"
    "WorldsheetGeometry"
    "MinimalSurfaceDynamics"
    "AuxiliaryWorldsheetMetric"
    "ConformalGauge"
    "VirasoroConstraints"
    "ConformalGenerators"
    "ExcitationLevels"
    "LeftRightModeBalance"
    "AnomalyCancellation"
    "BosonFermionPairing"
    "FermionBoundaryConditions"
    "SpectrumConsistency"
    "PhysicalStateSelection"
    "ExtraDimensionGeometry"
    "MomentumWindingExchange"
    "OpenStringEndpoints"
    "RegionalBoundaryStructure"
    "AdjacencyStructure"
    "TopologicalCharge"
    "HyperbolicSymmetry"
    "CurvedSpacePaths"
    "SpectralRepulsion"
    "ModeEnergyEncoding"
    "DirectionalFlow"
    "KnowledgeNeighborhood"
    "SymbolMeaningBinding"];
codes2 = [ ...
    1 3 12
    1 12 9
    5 3 1
    1 3 5
    1 9 12
    3 1 9
    3 1 12
    4 9 1
    9 3 12
    4 5 9
    5 6 3
    9 4 5
    9 4 6
    4 6 5
    2 6 4
    9 5 6
    9 6 12
    1 7 4
    8 6 5
    2 10 7
    2 1 7
    10 7 12
    7 6 9
    4 7 1
    1 11 3
    5 7 6
    5 6 12
    11 3 9
    12 10 7
    12 9 6];

bundles(2).name = 'string_theory_symbol_structure_v2';
bundles(2).path = fullfile(cfg.basePath, ...
    'YEHOSHUA_string_theory_symbol_structure_tensor_training_bundle_v2');
bundles(2).relativePaths = relative2;
bundles(2).originalNames = original2;
bundles(2).complementNames = complement2;
bundles(2).topicCodes = codes2;
bundles(2).pairRoot = fullfile(bundles(2).path, cfg.pairFolderName);
end


function bundle = emptyBundle()
bundle = struct('name', '', 'path', '', 'relativePaths', strings(0, 1), ...
    'originalNames', strings(0, 1), 'complementNames', strings(0, 1), ...
    'topicCodes', zeros(0, 3), 'pairRoot', '');
end


function validateInputs(cfg, bundles)
assert(isfile(cfg.canonicalH5), 'Canonical H5 was not found.');
assert(strcmpi(sha256File(cfg.canonicalH5), cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
for b = 1:numel(bundles)
    current = bundles(b);
    assert(isfolder(current.path), 'Previous bundle was not found: %s', ...
        current.path);
    assert(~isfolder(current.pairRoot) && ~isfile(current.pairRoot), ...
        'Pair output already exists; no files were changed: %s', ...
        current.pairRoot);
    count = numel(current.originalNames);
    assert(numel(current.relativePaths) == count, ...
        'Relative path mapping count mismatch.');
    assert(numel(current.complementNames) == count, ...
        'Complement mapping count mismatch.');
    assert(isequal(size(current.topicCodes), [count 3]), ...
        'Topic-code mapping shape mismatch.');
    assert(numel(unique(current.originalNames)) == count, ...
        'Original representation names must be unique per bundle.');
    assert(all(current.topicCodes(:) >= 1 & ...
        current.topicCodes(:) <= cfg.primitiveCount), ...
        'Topic code is outside the completion vocabulary.');
    for i = 1:count
        sourcePath = fullfile(current.path, char(current.relativePaths(i)));
        assert(isfile(sourcePath), 'Mapped image was not found: %s', sourcePath);
        [~, baseName, extension] = fileparts(sourcePath);
        assert(strcmp(baseName, current.originalNames(i)), ...
            'Mapped representation does not match its filename.');
        assert(strcmpi(extension, '.png'), 'Mapped image must be PNG.');
        assert(~isempty(regexp(current.originalNames(i), ...
            '^[A-Za-z][A-Za-z0-9]*$', 'once')), ...
            'Original representation name is not filesystem-safe.');
        assert(~isempty(regexp(current.complementNames(i), ...
            '^[A-Za-z][A-Za-z0-9]*$', 'once')), ...
            'Complement representation name is not filesystem-safe.');
    end
    listed = dir(fullfile(current.path, 'images', '**', '*.png'));
    assert(numel(listed) == count, ...
        'Every existing image must have exactly one mapped complement.');
end
end


function canonical = extractCanonicalFields(cfg)
fprintf('[1/5] Extracting canonical visual fields\n');
chamberField = readResizeField(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/chamber_field/data', 3, cfg.spatialSize);
fuchsianTiling = readResizeField(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/fuchsian_tiling/data', 5, cfg.spatialSize);
ginibreField = readResizeField(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/ginibre_field/data', 3, cfg.spatialSize);

streamXY = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/streamlines/xy')), 2);
streamLogMagnitude = double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/streamlines/logmag'));
streamID = double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/streamlines/sid'));
streamlineTensor = gridPointAttributes(streamXY, ...
    [streamLogMagnitude(:), streamID(:)], cfg.spatialSize);

crystalColors = orientPalette(double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/crystal_colors')), 9);
crystalStops = double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/crystal_stops'));
phaseColors = orientPalette(double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/phase_colors')), 6);
phaseStops = double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/phase_stops'));
spectralPalette = [crystalStops(:), crystalColors; ...
    phaseStops(:), phaseColors];

fieldBasis = cat(3, chamberField, fuchsianTiling, ...
    ginibreField, streamlineTensor);
for c = 1:size(fieldBasis, 3)
    fieldBasis(:, :, c) = single(normalize01(fieldBasis(:, :, c)));
end

canonical = struct;
canonical.chamberField = chamberField;
canonical.fuchsianTiling = fuchsianTiling;
canonical.ginibreField = ginibreField;
canonical.streamlineTensor = streamlineTensor;
canonical.spectralPalette = spectralPalette;
canonical.fieldBasis = fieldBasis;
assert(size(fieldBasis, 3) == cfg.canonicalChannelCount, ...
    'Unexpected canonical field channel count.');
assert(allFiniteStruct(canonical), ...
    'Canonical extraction contains non-finite values.');
end


function colors = orientPalette(colors, expectedRows)
colors = squeeze(colors);
if size(colors, 1) == expectedRows
    return;
end
if size(colors, 2) == expectedRows
    colors = colors.';
    return;
end
error('Unexpected spectral palette shape: %s', mat2str(size(colors)));
end


function [primitives, names, topicToSource] = ...
        buildCompletionPrimitives(cfg, canonical)
fprintf('[2/5] Building twelve structural completion primitives\n');
side = cfg.spatialSize;
[x, y] = meshgrid(linspace(-1, 1, side));
r = sqrt(x .^ 2 + y .^ 2);
theta = atan2(y, x);
primitives = zeros(side, side, cfg.primitiveCount, 'single');

primitives(:, :, 1) = single(normalize01( ...
    exp(-((r - 0.38) ./ 0.07) .^ 2) + ...
    0.7 .* exp(-((r - 0.70) ./ 0.09) .^ 2)));
primitives(:, :, 2) = single(normalize01( ...
    exp(-((abs(x) - 0.73) ./ 0.05) .^ 2) + ...
    exp(-((abs(y) - 0.73) ./ 0.05) .^ 2)));
primitives(:, :, 3) = single(normalize01( ...
    (sin(10 .* r - 3 .* theta) .^ 2) .* exp(-0.55 .* r)));
primitives(:, :, 4) = single(normalize01( ...
    exp(-0.9 .* r .^ 2) .* cos(4 .* theta) .^ 2));
spectral = zeros(side, side);
for k = 2:6
    spectral = spectral + (1 ./ k) .* sin(k .* pi .* (x + 1)) .^ 2;
end
primitives(:, :, 5) = single(normalize01(spectral));
primitives(:, :, 6) = single(normalize01( ...
    exp(-((mod(r, 0.19) - 0.095) ./ 0.028) .^ 2)));
primitives(:, :, 7) = single(normalize01( ...
    exp(-((sqrt((x - 0.34) .^ 2 + y .^ 2) - 0.28) ./ 0.055) .^ 2) + ...
    exp(-((sqrt((x + 0.34) .^ 2 + y .^ 2) - 0.28) ./ 0.055) .^ 2)));
primitives(:, :, 8) = single(normalize01( ...
    exp(-((x - 0.42) .^ 2 + y .^ 2) ./ 0.11) + ...
    exp(-((x + 0.42) .^ 2 + y .^ 2) ./ 0.11)));
primitives(:, :, 9) = single(normalize01( ...
    exp(-((y - x) ./ 0.075) .^ 2) + ...
    exp(-((y + x) ./ 0.075) .^ 2)));
bridge = exp(-(y ./ 0.09) .^ 2) .* exp(-0.65 .* x .^ 2);
nodes = exp(-((x - 0.58) .^ 2 + y .^ 2) ./ 0.035) + ...
    exp(-((x + 0.58) .^ 2 + y .^ 2) ./ 0.035);
primitives(:, :, 10) = single(normalize01(bridge + nodes));
primitives(:, :, 11) = single(normalize01( ...
    sin(7 .* x + 2.5 .* y + 1.7 .* sin(3 .* y)) .^ 2 .* ...
    exp(-0.42 .* r .^ 2)));
gridField = exp(-(sin(5 .* pi .* x) ./ 0.18) .^ 2) + ...
    exp(-(sin(5 .* pi .* y) ./ 0.18) .^ 2) + 1.5 .* exp(-r .^ 2 ./ 0.025);
primitives(:, :, 12) = single(normalize01(gridField));

names = ["geometry"; "boundary"; "dynamics"; "symmetry"; ...
    "spectrum"; "quantization"; "topology"; "duality"; ...
    "constraint"; "interaction"; "flow"; "interpretation"];

topicToSource = zeros(cfg.primitiveCount, size(canonical.fieldBasis, 3));
for p = 1:cfg.primitiveCount
    topicToSource(p, p) = 0.72;
    if p <= cfg.primitiveCount / 2
        topicToSource(p, 13:14) = [0.18 0.10];
    else
        topicToSource(p, 13:14) = [0.10 0.18];
    end
end
topicToSource = normalizeRowsPositive(topicToSource);
assert(rank(topicToSource) == cfg.primitiveCount, ...
    'Topic-to-source projection must have full row rank.');
assert(allFiniteNumeric(primitives) && allFiniteNumeric(topicToSource), ...
    'Completion primitive construction contains non-finite values.');
end


function prepared = prepareBundle(cfg, bundle, canonical, primitives, ...
        primitiveNames, topicToSource)
fprintf('[3/5] Preparing %d pairs for %s\n', ...
    numel(bundle.originalNames), bundle.name);
count = numel(bundle.originalNames);
side = cfg.spatialSize;
originalTensor = zeros(side, side, 3, count, 'single');
complementTensor = zeros(side, side, 3, count, 'single');
overlapTensor = zeros(side, side, count, 'single');
knowledgeGapTensor = zeros(side, side, count, 'single');
knowledgeCompletionTensor = zeros(side, side, 5, count, 'single');
topicEmbedding = zeros(count, cfg.primitiveCount);
sourceProjection = zeros(count, cfg.canonicalChannelCount);
pairCoupling = zeros(count, 3);
originalSHA256 = strings(count, 1);

for i = 1:count
    sourcePath = fullfile(bundle.path, char(bundle.relativePaths(i)));
    originalSHA256(i) = string(sha256File(sourcePath));
    originalRGB = readRGB01(sourcePath, side);
    originalTensor(:, :, :, i) = originalRGB;

    codes = bundle.topicCodes(i, :);
    topicEmbedding(i, codes) = [0.50 0.30 0.20];
    topicEmbedding(i, :) = normalizeRowsPositive(topicEmbedding(i, :));
    sourceProjection(i, :) = topicEmbedding(i, :) * topicToSource;

    sourceMix = weightedStack(canonical.fieldBasis, sourceProjection(i, :));
    primitiveMix = weightedStack(primitives, topicEmbedding(i, :));
    luminance = 0.2126 .* double(originalRGB(:, :, 1)) + ...
        0.7152 .* double(originalRGB(:, :, 2)) + ...
        0.0722 .* double(originalRGB(:, :, 3));
    [gx, gy] = gradient(luminance);
    edgeField = normalize01(sqrt(gx .^ 2 + gy .^ 2));
    overlap = normalize01(0.46 .* luminance + 0.29 .* sourceMix + ...
        0.25 .* primitiveMix);
    gap = normalize01(0.58 .* abs(sourceMix - luminance) + ...
        0.42 .* abs(primitiveMix - luminance));

    red = normalize01(0.38 .* sourceMix + 0.30 .* primitiveMix + ...
        0.22 .* edgeField + 0.10 .* double(originalRGB(:, :, 1)));
    green = normalize01(0.35 .* overlap + 0.35 .* primitiveMix + ...
        0.20 .* double(originalRGB(:, :, 2)) + 0.10 .* gap);
    blue = normalize01(0.40 .* gap + 0.30 .* sourceMix + ...
        0.20 .* double(originalRGB(:, :, 3)) + 0.10 .* (1 - edgeField));
    mask = normalize01(max(luminance, 0.55 .* sourceMix + ...
        0.45 .* primitiveMix));
    complement = cat(3, red, green, blue) .* (0.18 + 0.82 .* mask);
    for c = 1:3
        complement(:, :, c) = normalize01(imgaussfilt( ...
            complement(:, :, c), 0.72));
    end

    overlapTensor(:, :, i) = single(overlap);
    knowledgeGapTensor(:, :, i) = single(gap);
    complementTensor(:, :, :, i) = single(complement);
    knowledgeCompletionTensor(:, :, 1, i) = single(luminance);
    knowledgeCompletionTensor(:, :, 2, i) = single(sourceMix);
    knowledgeCompletionTensor(:, :, 3, i) = single(primitiveMix);
    knowledgeCompletionTensor(:, :, 4, i) = single(overlap);
    knowledgeCompletionTensor(:, :, 5, i) = single(gap);
    pairCoupling(i, :) = [mean(overlap(:)), mean(gap(:)), ...
        cosineSimilarity(luminance, complement(:, :, 2))];
end

pairRelation = topicEmbedding * topicEmbedding.';
radius = max(abs(eig(pairRelation)));
if radius > eps
    pairRelation = pairRelation ./ radius;
end
pairAdjacency = zeros(2 * count);
for i = 1:count
    pairAdjacency(i, count + i) = 1;
end

prepared = struct;
prepared.originalTensor = originalTensor;
prepared.complementTensor = complementTensor;
prepared.overlapTensor = overlapTensor;
prepared.knowledgeGapTensor = knowledgeGapTensor;
prepared.knowledgeCompletionTensor = knowledgeCompletionTensor;
prepared.topicEmbedding = topicEmbedding;
prepared.sourceProjection = sourceProjection;
prepared.pairCoupling = pairCoupling;
prepared.pairRelation = pairRelation;
prepared.pairAdjacency = pairAdjacency;
prepared.originalSHA256 = originalSHA256;
prepared.primitiveNames = primitiveNames;
prepared.pairCount = count;
end


function value = weightedStack(stack, weights)
assert(size(stack, 3) == numel(weights), ...
    'Weighted stack channel count mismatch.');
value = zeros(size(stack, 1), size(stack, 2));
for c = 1:numel(weights)
    value = value + double(stack(:, :, c)) .* weights(c);
end
value = normalize01(value);
end


function similarity = cosineSimilarity(a, b)
a = double(a(:));
b = double(b(:));
denominator = norm(a) .* norm(b);
if denominator <= eps %#ok<BDSCI>
    similarity = 0;
else
    similarity = dot(a, b) ./ denominator;
end
end


function validatePreparedBundles(cfg, bundles, prepared, canonical, ...
        primitives, topicToSource)
fprintf('[4/5] Validating tensor dimensions and pair coverage\n');
assert(isequal(size(canonical.fieldBasis), ...
    [cfg.spatialSize cfg.spatialSize cfg.canonicalChannelCount]), ...
    'Canonical field-basis shape mismatch.');
assert(isequal(size(primitives), ...
    [cfg.spatialSize cfg.spatialSize cfg.primitiveCount]), ...
    'Completion primitive shape mismatch.');
assert(rank(topicToSource) == cfg.primitiveCount, ...
    'Topic-to-source projection lost rank.');
for b = 1:numel(bundles)
    count = numel(bundles(b).originalNames);
    current = prepared{b};
    assert(current.pairCount == count, 'Pair count mismatch.');
    assert(isequal(size(current.originalTensor), ...
        [cfg.spatialSize cfg.spatialSize 3 count]), ...
        'Original tensor shape mismatch.');
    assert(isequal(size(current.complementTensor), ...
        [cfg.spatialSize cfg.spatialSize 3 count]), ...
        'Complement tensor shape mismatch.');
    assert(isequal(size(current.knowledgeCompletionTensor), ...
        [cfg.spatialSize cfg.spatialSize 5 count]), ...
        'Knowledge-completion tensor shape mismatch.');
    assert(isequal(size(current.topicEmbedding), ...
        [count cfg.primitiveCount]), 'Topic embedding shape mismatch.');
    assert(max(abs(sum(current.topicEmbedding, 2) - 1)) < 1e-12, ...
        'Topic-embedding rows must sum to one.');
    assert(all(std(reshape(current.complementTensor, [], count), 0, 1) ...
        > 0.015), 'A complementary image is visually degenerate.');
    assert(isdag(digraph(current.pairAdjacency)), ...
        'Pair adjacency must be forward-only.');
    fields = rmfield(current, {'originalSHA256', 'primitiveNames'});
    assert(allFiniteStruct(fields), ...
        'Prepared bundle contains non-finite values.');
end
end


function writeBundleOutput(cfg, bundle, prepared, canonical, primitives, ...
        primitiveNames, topicToSource, startTime)
fprintf('[5/5] Writing additive pairs and tensors for %s\n', bundle.name);
assert(~isfolder(bundle.pairRoot) && ~isfile(bundle.pairRoot), ...
    'Pair output appeared after preflight; no write was started.');
pairDirectory = fullfile(bundle.pairRoot, 'pairs');
tensorDirectory = fullfile(bundle.pairRoot, 'tensors');
manifestDirectory = fullfile(bundle.pairRoot, 'manifests');
mkdir(bundle.pairRoot);
mkdir(pairDirectory);
mkdir(tensorDirectory);
mkdir(manifestDirectory);

count = prepared.pairCount;
copiedSHA256 = strings(count, 1);
for i = 1:count
    pairFolder = fullfile(pairDirectory, char(bundle.originalNames(i)));
    mkdir(pairFolder);
    sourcePath = fullfile(bundle.path, char(bundle.relativePaths(i)));
    originalCopy = fullfile(pairFolder, ...
        char(bundle.originalNames(i) + ".png"));
    complementPath = fullfile(pairFolder, ...
        char(bundle.complementNames(i) + ".png"));
    assert(~isfile(originalCopy) && ~isfile(complementPath), ...
        'Pair file already exists.');
    copyfile(sourcePath, originalCopy);
    copiedSHA256(i) = string(sha256File(originalCopy));
    assert(copiedSHA256(i) == prepared.originalSHA256(i), ...
        'Copied original does not match the source image.');
    outputRGB = imresize(prepared.complementTensor(:, :, :, i), ...
        [cfg.outputImageSize cfg.outputImageSize], 'nearest');
    imwrite(im2uint8(outputRGB), complementPath);
end

tensorBundle = struct;
tensorBundle.version = cfg.version;
tensorBundle.subject = cfg.subject;
tensorBundle.domain = cfg.domain;
tensorBundle.bundle_name = bundle.name;
tensorBundle.canonical_h5 = cfg.canonicalH5;
tensorBundle.canonical_sha256 = cfg.expectedSHA256;
tensorBundle.original_names = bundle.originalNames;
tensorBundle.complement_names = bundle.complementNames;
tensorBundle.relative_sources = bundle.relativePaths;
tensorBundle.primitive_names = primitiveNames;
tensorBundle.canonical = canonical;
tensorBundle.completionPrimitives = primitives;
tensorBundle.topicToSource = topicToSource;
tensorBundle.tensors = rmfield(prepared, ...
    {'originalSHA256', 'primitiveNames', 'pairCount'});
tensorBundle.original_sha256 = prepared.originalSHA256;
tensorBundle.copied_sha256 = copiedSHA256;

matPath = fullfile(tensorDirectory, ...
    'StringTheoryComplementaryPairsTensors.mat');
save(matPath, 'tensorBundle', '-v7.3');
h5Path = fullfile(tensorDirectory, ...
    'StringTheoryComplementaryPairsTensors.h5');
writeTensorH5(h5Path, canonical, primitives, topicToSource, prepared);

writePairManifests(cfg, bundle, prepared, copiedSHA256, ...
    primitiveNames, topicToSource, h5Path, matPath, manifestDirectory, ...
    startTime);
end


function writeTensorH5(filePath, canonical, primitives, topicToSource, prepared)
assert(~isfile(filePath), 'Tensor H5 already exists.');
writeNumericDataset(filePath, '/canonical_source/chamberField', ...
    canonical.chamberField);
writeNumericDataset(filePath, '/canonical_source/fuchsianTiling', ...
    canonical.fuchsianTiling);
writeNumericDataset(filePath, '/canonical_source/ginibreField', ...
    canonical.ginibreField);
writeNumericDataset(filePath, '/canonical_source/streamlineTensor', ...
    canonical.streamlineTensor);
writeNumericDataset(filePath, '/canonical_source/spectralPalette', ...
    canonical.spectralPalette);
writeNumericDataset(filePath, '/canonical_source/fieldBasis', ...
    canonical.fieldBasis);
writeNumericDataset(filePath, '/tensors/originalTensor', ...
    prepared.originalTensor);
writeNumericDataset(filePath, '/tensors/complementTensor', ...
    prepared.complementTensor);
writeNumericDataset(filePath, '/tensors/overlapTensor', ...
    prepared.overlapTensor);
writeNumericDataset(filePath, '/tensors/knowledgeGapTensor', ...
    prepared.knowledgeGapTensor);
writeNumericDataset(filePath, '/tensors/knowledgeCompletionTensor', ...
    prepared.knowledgeCompletionTensor);
writeNumericDataset(filePath, '/tensors/completionPrimitiveTensor', ...
    primitives);
writeNumericDataset(filePath, '/weights/topicEmbedding', ...
    prepared.topicEmbedding);
writeNumericDataset(filePath, '/weights/topicToSource', topicToSource);
writeNumericDataset(filePath, '/weights/sourceProjection', ...
    prepared.sourceProjection);
writeNumericDataset(filePath, '/weights/pairCoupling', ...
    prepared.pairCoupling);
writeNumericDataset(filePath, '/weights/pairRelation', ...
    prepared.pairRelation);
writeNumericDataset(filePath, '/weights/pairAdjacency', ...
    prepared.pairAdjacency);
end


function writeNumericDataset(filePath, datasetPath, value)
if islogical(value)
    value = uint8(value);
end
if isa(value, 'double')
    dataType = 'double';
elseif isa(value, 'single')
    dataType = 'single';
elseif isa(value, 'uint8')
    dataType = 'uint8';
else
    value = double(value);
    dataType = 'double';
end
h5create(filePath, datasetPath, size(value), 'Datatype', dataType);
h5write(filePath, datasetPath, value);
end


function writePairManifests(cfg, bundle, prepared, copiedSHA256, ...
        primitiveNames, topicToSource, h5Path, matPath, manifestDirectory, ...
        startTime)
count = prepared.pairCount;
relation = bundle.originalNames + " requires " + bundle.complementNames;
pairFolder = "pairs/" + bundle.originalNames;
pairTable = table((1:count).', bundle.originalNames, ...
    bundle.complementNames, bundle.relativePaths, pairFolder, relation, ...
    prepared.originalSHA256, copiedSHA256, ...
    'VariableNames', {'pair_id', 'original_representation', ...
    'complementary_representation', 'source_relative_path', ...
    'pair_folder', 'knowledge_gap_relation', 'source_sha256', ...
    'paired_copy_sha256'});
writetable(pairTable, fullfile(manifestDirectory, 'PairIndex.csv'));

shapeRows = { ...
    'category', 'name', 'dimensions', 'element_count';
    'canonical', 'fieldBasis', mat2str(size(prepared.sourceProjection, 2)), ...
        numel(prepared.sourceProjection);
    'tensor', 'originalTensor', mat2str(size(prepared.originalTensor)), ...
        numel(prepared.originalTensor);
    'tensor', 'complementTensor', mat2str(size(prepared.complementTensor)), ...
        numel(prepared.complementTensor);
    'tensor', 'overlapTensor', mat2str(size(prepared.overlapTensor)), ...
        numel(prepared.overlapTensor);
    'tensor', 'knowledgeGapTensor', ...
        mat2str(size(prepared.knowledgeGapTensor)), ...
        numel(prepared.knowledgeGapTensor);
    'tensor', 'knowledgeCompletionTensor', ...
        mat2str(size(prepared.knowledgeCompletionTensor)), ...
        numel(prepared.knowledgeCompletionTensor);
    'tensor', 'completionPrimitiveTensor', ...
        sprintf('[%d %d %d]', cfg.spatialSize, cfg.spatialSize, ...
        cfg.primitiveCount), cfg.spatialSize ^ 2 * cfg.primitiveCount;
    'weight', 'topicEmbedding', mat2str(size(prepared.topicEmbedding)), ...
        numel(prepared.topicEmbedding);
    'weight', 'topicToSource', mat2str(size(topicToSource)), ...
        numel(topicToSource);
    'weight', 'sourceProjection', mat2str(size(prepared.sourceProjection)), ...
        numel(prepared.sourceProjection);
    'weight', 'pairCoupling', mat2str(size(prepared.pairCoupling)), ...
        numel(prepared.pairCoupling);
    'weight', 'pairRelation', mat2str(size(prepared.pairRelation)), ...
        numel(prepared.pairRelation);
    'weight', 'pairAdjacency', mat2str(size(prepared.pairAdjacency)), ...
        numel(prepared.pairAdjacency)};
writecell(shapeRows, fullfile(manifestDirectory, 'TensorShapes.csv'));

entries = repmat(struct('pair_id', 0, 'original_representation', '', ...
    'complementary_representation', '', 'source_relative_path', '', ...
    'pair_folder', '', 'knowledge_gap_relation', '', ...
    'rendered_text', false), count, 1);
for i = 1:count
    entries(i).pair_id = i;
    entries(i).original_representation = char(bundle.originalNames(i));
    entries(i).complementary_representation = ...
        char(bundle.complementNames(i));
    entries(i).source_relative_path = char(bundle.relativePaths(i));
    entries(i).pair_folder = char(pairFolder(i));
    entries(i).knowledge_gap_relation = char(relation(i));
    entries(i).rendered_text = false;
end
index = struct;
index.version = cfg.version;
index.subject = cfg.subject;
index.domain = cfg.domain;
index.bundle_name = bundle.name;
index.canonical_h5 = cfg.canonicalH5;
index.canonical_sha256 = cfg.expectedSHA256;
index.existing_files_changed = 0;
index.pair_count = count;
index.complementary_image_count = count;
index.paired_image_file_count = 2 * count;
index.rendered_text = false;
index.primitive_names = cellstr(primitiveNames);
index.primitive_count = numel(primitiveNames);
index.topic_to_source_rank = rank(topicToSource);
index.pair_adjacency_is_dag = isdag(digraph(prepared.pairAdjacency));
index.all_finite = allFiniteStruct(rmfield(prepared, ...
    {'originalSHA256', 'primitiveNames'}));
index.tensor_h5 = h5Path;
index.tensor_mat = matPath;
index.pairs = entries;
writeText(fullfile(manifestDirectory, 'PairIndex.json'), ...
    jsonencode(index, PrettyPrint=true));

lines = { ...
    'YEHOSHUA STRING THEORY COMPLEMENTARY PAIRS V3'
    'subject=image_learning'
    'domain=string_theory_complementary_visual_pairs'
    sprintf('bundle_name=%s', bundle.name)
    sprintf('canonical_sha256=%s', cfg.expectedSHA256)
    sprintf('pair_count=%d', count)
    sprintf('complementary_image_count=%d', count)
    sprintf('paired_image_file_count=%d', 2 * count)
    sprintf('primitive_count=%d', numel(primitiveNames))
    sprintf('topic_to_source_rank=%d', rank(topicToSource))
    sprintf('pair_adjacency_is_dag=%s', ...
        string(isdag(digraph(prepared.pairAdjacency))))
    'rendered_text=false'
    'existing_files_changed=0'
    sprintf('elapsed_seconds=%.6f', toc(startTime))};
writeText(fullfile(manifestDirectory, 'RunSummary.txt'), ...
    strjoin(lines, newline));
end


function validateWrittenOutputs(cfg, bundles, prepared)
for b = 1:numel(bundles)
    current = bundles(b);
    expected = prepared{b}.pairCount;
    pairFiles = dir(fullfile(current.pairRoot, 'pairs', '**', '*.png'));
    assert(numel(pairFiles) == 2 * expected, ...
        'Written pair image count mismatch.');
    assert(isfile(fullfile(current.pairRoot, 'tensors', ...
        'StringTheoryComplementaryPairsTensors.h5')), ...
        'Written H5 tensor file is missing.');
    assert(isfile(fullfile(current.pairRoot, 'tensors', ...
        'StringTheoryComplementaryPairsTensors.mat')), ...
        'Written MAT tensor file is missing.');
    for i = 1:expected
        sourcePath = fullfile(current.path, char(current.relativePaths(i)));
        assert(strcmpi(sha256File(sourcePath), ...
            prepared{b}.originalSHA256(i)), ...
            'An existing source image changed during the run.');
    end
end
assert(strcmpi(sha256File(cfg.canonicalH5), cfg.expectedSHA256), ...
    'Canonical H5 changed during the run.');
end


function results = summarizeResults(mode, bundles, prepared, startTime)
pairCounts = zeros(numel(prepared), 1);
outputRoots = strings(numel(prepared), 1);
for i = 1:numel(prepared)
    pairCounts(i) = prepared{i}.pairCount;
    outputRoots(i) = string(bundles(i).pairRoot);
end
results = struct;
results.mode = char(mode);
results.bundleCount = numel(bundles);
results.pairCounts = pairCounts;
results.totalPairCount = sum(pairCounts);
results.outputRoots = outputRoots;
results.elapsedSeconds = toc(startTime);
end


function rgb = readRGB01(filePath, side)
raw = imread(filePath);
if isinteger(raw)
    raw = single(raw) ./ single(intmax(class(raw)));
else
    raw = single(raw);
    raw = single(normalize01(raw));
end
if ismatrix(raw)
    raw = repmat(raw, 1, 1, 3);
elseif size(raw, 3) == 1
    raw = repmat(raw, 1, 1, 3);
else
    raw = raw(:, :, 1:3);
end
rgb = imresize(raw, [side side], 'bilinear');
rgb = min(max(rgb, 0), 1);
end


function field = readResizeField(filePath, datasetPath, channels, outputSize)
raw = orientChannelsFirst(single(h5read(filePath, datasetPath)), channels);
stack = decodeFlatChannels(raw, 800, 800);
field = resizeStack(stack, outputSize);
end


function stack = decodeFlatChannels(raw, height, width)
raw = squeeze(raw);
pixelCount = height .* width;
if size(raw, 2) == pixelCount %#ok<BDSCI>
    channelCount = size(raw, 1);
elseif size(raw, 1) == pixelCount %#ok<BDSCI>
    raw = raw.';
    channelCount = size(raw, 1);
else
    error('Unsupported flat field shape: %s', mat2str(size(raw)));
end
stack = zeros(height, width, channelCount, 'single');
for c = 1:channelCount
    stack(:, :, c) = reshape(single(raw(c, :)), height, width);
end
end


function output = resizeStack(input, outputSize)
output = zeros(outputSize, outputSize, size(input, 3), 'single');
for c = 1:size(input, 3)
    output(:, :, c) = single(imresize(input(:, :, c), ...
        [outputSize outputSize], 'bilinear'));
end
end


function data = orientChannelsFirst(data, expectedChannels)
data = squeeze(data);
if size(data, 1) == expectedChannels
    return;
end
if size(data, 2) == expectedChannels
    data = data.';
    return;
end
error('Expected %d channels; found shape %s.', ...
    expectedChannels, mat2str(size(data)));
end


function tensor = gridPointAttributes(points, attributes, side)
x = normalizeVector(points(1, :));
y = normalizeVector(points(2, :));
xi = min(side, max(1, floor(x .* side) + 1));
yi = min(side, max(1, floor(y .* side) + 1));
count = accumarray([yi(:), xi(:)], 1, [side side], @sum, 0);
tensor = zeros(side, side, 1 + size(attributes, 2), 'single');
tensor(:, :, 1) = single(normalize01(count));
for attributeIndex = 1:size(attributes, 2)
    sums = accumarray([yi(:), xi(:)], attributes(:, attributeIndex), ...
        [side side], @sum, 0);
    means = sums ./ max(count, 1);
    tensor(:, :, attributeIndex + 1) = single(normalize01(means));
end
end


function output = normalizeRowsPositive(input)
output = max(double(input), 0);
denominator = sum(output, 2);
denominator(denominator <= eps) = 1;
output = output ./ denominator;
end


function output = normalizeVector(input)
input = double(input);
minimum = min(input(:));
maximum = max(input(:));
span = maximum - minimum;
if span <= eps(max(abs([minimum maximum 1])))
    output = zeros(size(input));
else
    output = (input - minimum) ./ span;
end
end


function output = normalize01(input)
input = double(input);
valid = isfinite(input);
if ~any(valid(:))
    output = zeros(size(input));
    return;
end
minimum = min(input(valid));
maximum = max(input(valid));
span = maximum - minimum;
output = zeros(size(input));
if span > eps(max(abs([minimum maximum 1])))
    output(valid) = (input(valid) - minimum) ./ span;
end
end


function valid = allFiniteStruct(structure)
valid = true;
names = fieldnames(structure);
for i = 1:numel(names)
    value = structure.(names{i});
    if isnumeric(value) && ~allFiniteNumeric(value)
        valid = false;
        return;
    end
end
end


function valid = allFiniteNumeric(value)
valid = all(isfinite(real(value(:)))) && all(isfinite(imag(value(:))));
end


function writeText(filePath, content)
fileID = fopen(filePath, 'w');
assert(fileID > 0, 'Could not create text file: %s', filePath);
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, '%s', content);
clear cleanup;
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
