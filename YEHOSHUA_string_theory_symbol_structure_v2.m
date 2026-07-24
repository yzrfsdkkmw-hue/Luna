function results = YEHOSHUA_string_theory_symbol_structure_v2()
% YEHOSHUA_string_theory_symbol_structure_v2
% Extends the prior string-foundation image-learning bundle with twenty
% human notation concepts and nine additional canonical H5 tensors.

cfg = configuration();
startTime = tic;
validateInputs(cfg);
assert(~isfolder(cfg.outputRoot), ...
    'Output folder already exists; no files were changed.');

try
    createOutputFolders(cfg);
    fprintf('\n%s\n', repmat('=', 1, 72));
    fprintf('YEHOSHUA STRING THEORY SYMBOL STRUCTURE V2\n');
    fprintf('%s\n', repmat('=', 1, 72));
    fprintf('canonical H5 : %s\n', cfg.canonicalH5);
    fprintf('vocabulary   : %s\n', cfg.vocabularyJSON);
    fprintf('output       : %s\n\n', cfg.outputRoot);

    vocabularySource = readVocabulary(cfg);
    canonical = extractAdditionalCanonicalTensors(cfg);
    prior = readPriorBundle(cfg);
    dictionary = buildHumanNotationDictionary( ...
        vocabularySource, prior, canonical);
    tensors = buildStructuralTensors(cfg, dictionary, canonical, prior);
    weights = buildWeights(dictionary, tensors, canonical);
    validation = validateBundle( ...
        vocabularySource, dictionary, canonical, tensors, weights);
    images = renderBundleImages( ...
        cfg, vocabularySource, canonical, tensors, weights);

    bundle = assembleBundle(cfg, vocabularySource, canonical, ...
        dictionary, tensors, weights, validation, images);
    matPath = fullfile(cfg.weightsDirectory, ...
        'StringTheorySymbolStructureWeights.mat');
    save(matPath, 'bundle', '-v7.3');

    h5Path = fullfile(cfg.weightsDirectory, ...
        'StringTheorySymbolStructureWeights.h5');
    [h5Exported, h5Message] = writeBundleH5( ...
        h5Path, canonical, tensors, weights);
    writematrix(weights.humanSymbolCalibration, fullfile( ...
        cfg.weightsDirectory, 'HumanSymbolCalibrationWeights.csv'));
    writematrix(weights.conceptRelations, fullfile( ...
        cfg.weightsDirectory, 'ConceptRelationWeights.csv'));

    manifests = writeManifests( ...
        cfg, bundle, h5Exported, h5Message, startTime);

    results = struct;
    results.outputRoot = cfg.outputRoot;
    results.imageCount = numel(images);
    results.canonicalTensorCount = numel(fieldnames(canonical));
    results.trainingTensorCount = numel(fieldnames(tensors));
    results.weightCount = numel(fieldnames(weights));
    results.weightsMAT = matPath;
    results.weightsH5 = h5Path;
    results.h5Exported = h5Exported;
    results.validation = validation;
    results.manifests = manifests;
    results.elapsedSeconds = toc(startTime);

    fprintf('\nRUN COMPLETE\n');
    fprintf('Concept images        : %d\n', vocabularySource.itemCount);
    fprintf('Total images          : %d\n', results.imageCount);
    fprintf('Additional H5 tensors : %d\n', results.canonicalTensorCount);
    fprintf('Training tensors      : %d\n', results.trainingTensorCount);
    fprintf('Weight arrays         : %d\n', results.weightCount);
    fprintf('H5 export             : %s\n', string(h5Exported));
    fprintf('Output folder         : %s\n', cfg.outputRoot);
    fprintf('Elapsed               : %.3f s\n', results.elapsedSeconds);
    fprintf('%s\n', repmat('=', 1, 72));
catch runError
    if isfolder(cfg.outputRoot)
        rmdir(cfg.outputRoot, 's');
    end
    rethrow(runError);
end
end


function cfg = configuration()
cfg = struct;
cfg.version = 'YEHOSHUA_string_theory_symbol_structure_v2';
cfg.subject = 'image_learning';
cfg.domain = 'string_theory_human_symbol_structure';
cfg.canonicalH5 = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.vocabularyJSON = ['/Users/yehoshua/.codex/attachments/' ...
    'cbdbaaf6-55a4-4f82-924c-0607fea23603/pasted-text.txt'];
cfg.basePath = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15'];
cfg.priorBundle = fullfile(cfg.basePath, ...
    'YEHOSHUA_wave_function_string_foundations_tensor_training_bundle_v1');
cfg.priorH5 = fullfile(cfg.priorBundle, 'weights', ...
    'WaveFunctionStringTensorWeights.h5');
cfg.outputRoot = fullfile(cfg.basePath, ...
    'YEHOSHUA_string_theory_symbol_structure_tensor_training_bundle_v2');
cfg.imagesDirectory = fullfile(cfg.outputRoot, 'images');
cfg.conceptImages = fullfile(cfg.imagesDirectory, 'concepts');
cfg.sourceImages = fullfile(cfg.imagesDirectory, 'canonical_sources');
cfg.systemImages = fullfile(cfg.imagesDirectory, 'symbol_system');
cfg.weightsDirectory = fullfile(cfg.outputRoot, 'weights');
cfg.manifestsDirectory = fullfile(cfg.outputRoot, 'manifests');
cfg.spatialSize = 64;
cfg.conceptCount = 20;
cfg.primitiveCount = 12;
cfg.sourceTensorCount = 9;
cfg.outputImageSize = 512;
end


function validateInputs(cfg)
assert(isfile(cfg.canonicalH5), 'Canonical H5 was not found.');
assert(strcmpi(sha256File(cfg.canonicalH5), cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
assert(isfile(cfg.vocabularyJSON), 'Vocabulary JSON was not found.');
assert(isfile(cfg.priorH5), 'Prior string-foundation H5 was not found.');
source = jsondecode(fileread(cfg.vocabularyJSON));
assert(strcmp(source.document, 'string_theory_foundational_concepts_v1'), ...
    'Unexpected vocabulary document.');
assert(numel(source.items) == cfg.conceptCount, ...
    'Vocabulary must contain twenty items.');
end


function createOutputFolders(cfg)
mkdir(cfg.outputRoot);
mkdir(cfg.imagesDirectory);
mkdir(cfg.conceptImages);
mkdir(cfg.sourceImages);
mkdir(cfg.systemImages);
mkdir(cfg.weightsDirectory);
mkdir(cfg.manifestsDirectory);
end


function vocabulary = readVocabulary(cfg)
fprintf('[1/6] Reading and validating twenty human notation concepts\n');
source = jsondecode(fileread(cfg.vocabularyJSON));
items = source.items;
ids = arrayfun(@(item) double(item.id), items);
ids = ids(:);
assert(isequal(ids, (1:cfg.conceptCount).'), ...
    'Vocabulary IDs must be sequential from one to twenty.');
requiredFields = {'term_he', 'term_en', 'symbol', 'definition', 'relation'};
for i = 1:numel(items)
    for fieldIndex = 1:numel(requiredFields)
        value = string(items(i).(requiredFields{fieldIndex}));
        assert(strlength(strtrim(value)) > 0, ...
            'Vocabulary item %d has an empty %s field.', ...
            i, requiredFields{fieldIndex});
    end
end

vocabulary = struct;
vocabulary.document = source.document;
vocabulary.language = source.language;
vocabulary.encoding = source.encoding;
vocabulary.schema = cellstr(string(source.schema));
vocabulary.items = items;
vocabulary.itemCount = numel(items);
vocabulary.sourceHash = sha256File(cfg.vocabularyJSON);
vocabulary.termHebrew = arrayfun( ...
    @(item) string(item.term_he), items);
vocabulary.termHebrew = vocabulary.termHebrew(:);
vocabulary.termEnglish = arrayfun( ...
    @(item) string(item.term_en), items);
vocabulary.termEnglish = vocabulary.termEnglish(:);
vocabulary.symbols = arrayfun( ...
    @(item) string(item.symbol), items);
vocabulary.symbols = vocabulary.symbols(:);
vocabulary.definitions = arrayfun( ...
    @(item) string(item.definition), items);
vocabulary.definitions = vocabulary.definitions(:);
vocabulary.relations = arrayfun( ...
    @(item) string(item.relation), items);
vocabulary.relations = vocabulary.relations(:);
vocabulary.symbolComplexity = stringComplexity(vocabulary.symbols);
vocabulary.relationComplexity = stringComplexity(vocabulary.relations);
end


function complexity = stringComplexity(values)
complexity = double(strlength(values));
complexity = complexity ./ max(max(complexity), 1);
end


function canonical = extractAdditionalCanonicalTensors(cfg)
fprintf('[2/6] Extracting nine additional tensors from the canonical H5\n');
a = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/connections/a')), 2);
b = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/connections/b')), 2);
d = double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/connections/d'));
connectionTensor = [a.', b.', d(:)];
latticeCoordinates = orientChannelsFirst(double(h5read( ...
    cfg.canonicalH5, '/n_2_e8_lattice/laplacian_modes/xy')), 2).';

streamXY = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/streamlines/xy')), 2);
streamLogMagnitude = double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/streamlines/logmag'));
streamID = double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/streamlines/sid'));
streamlineTensor = gridPointAttributes(streamXY, ...
    [streamLogMagnitude(:), streamID(:)], cfg.spatialSize);

defectPosition = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/pos')), 2);
defectCharge = double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/charge'));
defectDegree = double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/degree'));
defectTopology = gridPointAttributes(defectPosition, ...
    [defectCharge(:), defectDegree(:)], cfg.spatialSize);

rawPoints = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/raw_points')), 2);
fieldPoints = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/xy')), 2);
rawGrid = gridPointAttributes(rawPoints, zeros(size(rawPoints, 2), 0), ...
    cfg.spatialSize);
fieldGrid = gridPointAttributes(fieldPoints, zeros(size(fieldPoints, 2), 0), ...
    cfg.spatialSize);
geodesicTrajectories = cat(3, rawGrid(:, :, 1), ...
    fieldGrid(:, :, 1), normalize01(rawGrid(:, :, 1) - fieldGrid(:, :, 1)));

chamberField = readResizeField(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/chamber_field/data', 3, ...
    cfg.spatialSize);
fuchsianTiling = readResizeField(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/fuchsian_tiling/data', 5, ...
    cfg.spatialSize);
ginibreField = readResizeField(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/ginibre_field/data', 3, ...
    cfg.spatialSize);

crystalColors = double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/crystal_colors'));
crystalStops = double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/crystal_stops'));
phaseColors = double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/phase_colors'));
phaseStops = double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/phase_stops'));
spectralPalette = [crystalStops(:), crystalColors; ...
    phaseStops(:), phaseColors];

canonical = struct;
canonical.connectionTensor = connectionTensor;
canonical.latticeCoordinates = latticeCoordinates;
canonical.streamlineTensor = streamlineTensor;
canonical.defectTopology = defectTopology;
canonical.geodesicTrajectories = geodesicTrajectories;
canonical.chamberField = chamberField;
canonical.fuchsianTiling = fuchsianTiling;
canonical.ginibreField = ginibreField;
canonical.spectralPalette = spectralPalette;
assert(numel(fieldnames(canonical)) == cfg.sourceTensorCount, ...
    'Unexpected canonical source tensor count.');
assert(allFiniteStruct(canonical), ...
    'Canonical tensor extraction contains non-finite values.');
end


function field = readResizeField(filePath, datasetPath, channels, outputSize)
raw = orientChannelsFirst(single(h5read(filePath, datasetPath)), channels);
stack = decodeFlatChannels(raw, 800, 800);
field = resizeStack(stack, outputSize);
end


function tensor = gridPointAttributes(points, attributes, side)
x = normalizeVector(points(1, :));
y = normalizeVector(points(2, :));
xi = min(side, max(1, floor(x .* side) + 1));
yi = min(side, max(1, floor(y .* side) + 1));
count = accumarray([yi(:), xi(:)], 1, [side side], @sum, 0);
tensor = zeros(side, side, 1 + size(attributes, 2));
tensor(:, :, 1) = normalize01(count);
for attributeIndex = 1:size(attributes, 2)
    sums = accumarray([yi(:), xi(:)], attributes(:, attributeIndex), ...
        [side side], @sum, 0);
    means = sums ./ max(count, 1);
    tensor(:, :, attributeIndex + 1) = normalize01(means);
end
end


function prior = readPriorBundle(cfg)
fprintf('[3/6] Reading prior wave and human calibration tensors\n');
prior = struct;
prior.extendedWaveFunction = complex( ...
    double(h5read(cfg.priorH5, '/tensors/extendedWaveFunction/real')), ...
    double(h5read(cfg.priorH5, '/tensors/extendedWaveFunction/imag')));
prior.humanSymbolCalibration = double(h5read( ...
    cfg.priorH5, '/weights/humanSymbolCalibration'));
prior.modeSpectrum = double(h5read(cfg.priorH5, ...
    '/tensors/modeSpectrum'));
prior.stringModes = complex( ...
    double(h5read(cfg.priorH5, '/tensors/stringModes/real')), ...
    double(h5read(cfg.priorH5, '/tensors/stringModes/imag')));
assert(isequal(size(prior.extendedWaveFunction), [64 64 12]), ...
    'Prior wave tensor must be 64 x 64 x 12.');
assert(allFiniteStruct(prior), 'Prior bundle contains non-finite values.');
end


function dictionary = buildHumanNotationDictionary(vocabulary, prior, canonical)
fprintf('[4/6] Building the 20 x 12 human notation dictionary\n');
incidence = false(20, 12);
incidence(1:12, :) = logical(tril(ones(12)));
for i = 13:20
    incidence(i, mod(i - 1, 12) + 1) = true;
    incidence(i, mod(i + 3, 12) + 1) = true;
    incidence(i, mod(i + 7, 12) + 1) = true;
end
target = normalizeRowsPositive(double(incidence));
priorMap = imresize(prior.humanSymbolCalibration, [20 12], 'bilinear');
priorMap = normalizeRowsPositive(max(priorMap, 0));
complexityWeight = 0.85 + 0.15 .* vocabulary.symbolComplexity;
estimated = normalizeRowsPositive((0.70 .* target + 0.30 .* priorMap) .* ...
    complexityWeight);
relations = estimated * estimated.';
relations(1:21:end) = 0;
relations = (relations + relations.') ./ 2;
radius = max(abs(eig(relations)));
if radius > eps
    relations = relations ./ radius;
end

sourceStatistics = canonicalSourceStatistics(canonical);
conceptProfile = 0.55 .* vocabulary.symbolComplexity + ...
    0.45 .* vocabulary.relationComplexity;
conceptToSource = conceptProfile * sourceStatistics.';
conceptToSource = normalizeRowsPositive(conceptToSource);
phase = 2 .* pi .* normalizeVector(vocabulary.symbolComplexity + ...
    vocabulary.relationComplexity);
notationEmbedding = estimated .* exp(1i .* phase);

dictionary = struct;
dictionary.primitiveNames = { ...
    'point', 'line', 'loop', 'surface', 'map', 'scale', ...
    'metric', 'action', 'symmetry', 'constraint', 'mode', 'boundary'};
dictionary.incidence = incidence;
dictionary.targetMap = target;
dictionary.priorMap = priorMap;
dictionary.calibratedMap = estimated;
dictionary.conceptRelations = relations;
dictionary.sourceStatistics = sourceStatistics;
dictionary.conceptToSource = conceptToSource;
dictionary.notationEmbedding = notationEmbedding;
dictionary.rank = rank(double(incidence));
end


function statistics = canonicalSourceStatistics(canonical)
names = fieldnames(canonical);
statistics = zeros(numel(names), 1);
for i = 1:numel(names)
    value = double(canonical.(names{i}));
    statistics(i) = mean(abs(value(:)), 'omitnan') + ...
        std(value(:), 'omitnan');
end
statistics = 0.05 + 0.95 .* normalizeVector(statistics);
end


function tensors = buildStructuralTensors(cfg, dictionary, canonical, prior)
fprintf('[5/6] Building structural symbol and relation tensors\n');
primitiveTensor = buildPrimitiveTensor(cfg.spatialSize);
baseField = normalize01(mean(canonical.chamberField, 3) + ...
    mean(canonical.fuchsianTiling, 3) + ...
    mean(canonical.ginibreField, 3));
basePhase = angle(mean(prior.extendedWaveFunction, 3));
conceptTensor = zeros(cfg.spatialSize, cfg.spatialSize, cfg.conceptCount);
symbolField = complex(zeros( ...
    cfg.spatialSize, cfg.spatialSize, cfg.conceptCount));
for concept = 1:cfg.conceptCount
    weights = dictionary.calibratedMap(concept, :);
    structure = zeros(cfg.spatialSize);
    for primitive = 1:cfg.primitiveCount
        structure = structure + weights(primitive) .* ...
            primitiveTensor(:, :, primitive);
    end
    structure = circshift(structure, ...
        [mod(concept - 1, 5) - 2, floor((concept - 1) ./ 5) - 2]);
    coupled = normalize01(structure .* (0.55 + 0.45 .* baseField) + ...
        0.18 .* normalize01(abs(del2(structure))));
    conceptTensor(:, :, concept) = coupled;
    phaseOffset = angle(dictionary.notationEmbedding(concept, 1));
    symbolField(:, :, concept) = coupled .* ...
        exp(1i .* (basePhase + phaseOffset));
end

twoStep = dictionary.conceptRelations ^ 2;
threeStep = dictionary.conceptRelations ^ 3;
relationTensor = cat(3, dictionary.conceptRelations, twoStep, threeStep);
sequenceAdjacency = diag(ones(cfg.conceptCount - 1, 1), 1);

tensors = struct;
tensors.primitiveTensor = primitiveTensor;
tensors.conceptTensor = conceptTensor;
tensors.symbolField = symbolField;
tensors.humanSymbolCalibration = dictionary.calibratedMap;
tensors.notationEmbedding = dictionary.notationEmbedding;
tensors.conceptRelations = dictionary.conceptRelations;
tensors.relationTensor = relationTensor;
tensors.conceptToSource = dictionary.conceptToSource;
tensors.sourceStatistics = dictionary.sourceStatistics;
tensors.conceptComplexity = [dictionary.calibratedMap * ...
    (1:cfg.primitiveCount).', sum(dictionary.incidence, 2)];
tensors.semanticSequenceAdjacency = sequenceAdjacency;
assert(allFiniteStruct(tensors), ...
    'Structural tensors contain non-finite values.');
end


function primitives = buildPrimitiveTensor(side)
[x, y] = meshgrid(linspace(-1, 1, side));
primitives = zeros(side, side, 12);
primitives(:, :, 1) = exp(-0.5 .* ((x ./ 0.08) .^ 2 + ...
    (y ./ 0.08) .^ 2));
primitives(:, :, 2) = softStroke(abs(y), 0.025) .* (abs(x) < 0.78);
primitives(:, :, 3) = softStroke(abs(hypot(x, y) - 0.42), 0.025);
primitives(:, :, 4) = exp(-0.5 .* ((x ./ 0.62) .^ 8 + ...
    (y ./ 0.34) .^ 8));
shaft = softStroke(abs(y), 0.022) .* (x > -0.72) .* (x < 0.55);
head = softStroke(abs(abs(y) - 0.70 .* (0.72 - x)), 0.025) .* ...
    (x > 0.48) .* (x < 0.75);
primitives(:, :, 5) = normalize01(shaft + head);
primitives(:, :, 6) = normalize01(softStroke(abs(hypot(x, y) - 0.25), 0.02) + ...
    softStroke(abs(hypot(x, y) - 0.50), 0.02));
gridX = softStroke(abs(sin(4 .* pi .* x)), 0.05);
gridY = softStroke(abs(sin(4 .* pi .* y)), 0.05);
primitives(:, :, 7) = normalize01(gridX + gridY);
primitives(:, :, 8) = normalize01(primitives(:, :, 4) + ...
    0.7 .* primitives(:, :, 3));
primitives(:, :, 9) = normalize01( ...
    exp(-0.5 .* (((x - 0.35) ./ 0.13) .^ 2 + (y ./ 0.30) .^ 2)) + ...
    exp(-0.5 .* (((x + 0.35) ./ 0.13) .^ 2 + (y ./ 0.30) .^ 2)));
primitives(:, :, 10) = normalize01( ...
    softStroke(abs(x - 0.45), 0.025) + ...
    softStroke(abs(x + 0.45), 0.025));
primitives(:, :, 11) = softStroke(abs(y - 0.24 .* sin(4 .* pi .* x)), ...
    0.025) .* (abs(x) < 0.82);
squareDistance = max(abs(x), abs(y));
primitives(:, :, 12) = softStroke(abs(squareDistance - 0.60), 0.025);
for i = 1:12
    primitives(:, :, i) = normalize01(primitives(:, :, i));
end
end


function mask = softStroke(distance, width)
mask = exp(-0.5 .* (distance ./ width) .^ 2);
end


function weights = buildWeights(dictionary, tensors, canonical)
fprintf('[6/6] Building human symbol and source-coupling weights\n');
sequence = tensors.semanticSequenceAdjacency;
sequenceTransition = normalizeRowsPositive(sequence);
sourceReliability = dictionary.sourceStatistics;
sourceReliability = sourceReliability ./ sum(sourceReliability);

weights = struct;
weights.primitiveIncidence = double(dictionary.incidence);
weights.humanSymbolCalibration = dictionary.calibratedMap;
weights.priorContinuity = dictionary.priorMap;
weights.notationEmbedding = dictionary.notationEmbedding;
weights.conceptRelations = dictionary.conceptRelations;
weights.conceptToSource = dictionary.conceptToSource;
weights.sourceReliability = sourceReliability;
weights.sequenceTransition = sequenceTransition;
weights.spectralPalette = canonical.spectralPalette;
end


function validation = validateBundle(vocabulary, dictionary, canonical, ...
    tensors, weights)
rowSums = sum(dictionary.calibratedMap, 2);
relationSymmetry = norm(dictionary.conceptRelations - ...
    dictionary.conceptRelations.', 'fro');
relationDiagonal = max(abs(diag(dictionary.conceptRelations)));
relationRadius = max(abs(eig(dictionary.conceptRelations)));
sequenceGraph = digraph(tensors.semanticSequenceAdjacency);
conceptOccupancy = squeeze(mean(mean(tensors.conceptTensor > 0.05, 1), 2));

assert(vocabulary.itemCount == 20, ...
    'Vocabulary item count must equal twenty.');
assert(dictionary.rank == 12, ...
    'Human notation incidence matrix must have rank twelve.');
assert(all(dictionary.calibratedMap(:) >= 0), ...
    'Human symbol calibration contains a negative value.');
assert(max(abs(rowSums - 1)) < 1e-12, ...
    'Human symbol calibration rows are not normalized.');
assert(relationSymmetry < 1e-12, ...
    'Concept relation matrix is not symmetric.');
assert(relationDiagonal < 1e-12, ...
    'Concept relation diagonal must be zero.');
assert(relationRadius <= 1 + 1e-12, ...
    'Concept relation spectral radius exceeds one.');
assert(isdag(sequenceGraph), 'Semantic sequence must be acyclic.');
assert(all(conceptOccupancy > 0), ...
    'At least one concept tensor is empty.');
assert(allFiniteStruct(canonical) && allFiniteStruct(tensors) && ...
    allFiniteStruct(weights), 'Bundle contains non-finite values.');

validation = struct;
validation.vocabulary_item_count = vocabulary.itemCount;
validation.incidence_rank = dictionary.rank;
validation.calibration_row_sum_max_error = max(abs(rowSums - 1));
validation.relation_symmetry_error = relationSymmetry;
validation.relation_diagonal_max = relationDiagonal;
validation.relation_spectral_radius = relationRadius;
validation.semantic_sequence_is_dag = isdag(sequenceGraph);
validation.minimum_concept_occupancy = min(conceptOccupancy);
validation.canonical_tensor_count = numel(fieldnames(canonical));
validation.all_finite = true;
end


function images = renderBundleImages(cfg, vocabulary, canonical, ...
    tensors, weights)
conceptFileNames = { ...
    'Worldsheet', 'EmbeddingMap', 'ReggeSlope', 'StringTension', ...
    'InducedMetric', 'NambuGotoAction', 'PolyakovAction', ...
    'WeylSymmetry', 'WorldsheetStressEnergy', 'VirasoroAlgebra', ...
    'OscillatorModes', 'LevelMatching', 'CriticalDimension', ...
    'WorldsheetSupersymmetry', 'NeveuSchwarzRamondSectors', ...
    'GSOProjection', 'BRSTCohomology', ...
    'CalabiYauCompactification', 'TDuality', 'DBranes'};
sourceFileNames = { ...
    'ConnectionGraph', 'StreamlineField', 'DefectTopology', ...
    'GeodesicTrajectories', 'ChamberField', 'FuchsianTiling', ...
    'GinibreField', 'SpectralPalette'};
totalCount = numel(conceptFileNames) + numel(sourceFileNames) + 2;
images = repmat(emptyImageIndex(), totalCount, 1);
imageIndex = 1;
basePhase = angle(mean(tensors.symbolField, 3));
for concept = 1:numel(conceptFileNames)
    structure = tensors.conceptTensor(:, :, concept);
    phase = angle(tensors.symbolField(:, :, concept));
    rgb = structurePhaseRGB(structure, phase, ...
        vocabulary.symbolComplexity(concept));
    path = fullfile(cfg.conceptImages, [conceptFileNames{concept} '.png']);
    imwrite(imresize(rgb, [cfg.outputImageSize cfg.outputImageSize], ...
        'nearest'), path);
    images(imageIndex) = imageEntry(conceptFileNames{concept}, ...
        path, char(vocabulary.termEnglish(concept)));
    imageIndex = imageIndex + 1;
end

connectionMap = connectionDensityMap(canonical.connectionTensor, cfg.spatialSize);
sourceImages = { ...
    scalarToRGB(connectionMap, false), ...
    tensorCompositeRGB(canonical.streamlineTensor), ...
    tensorCompositeRGB(canonical.defectTopology), ...
    tensorCompositeRGB(canonical.geodesicTrajectories), ...
    tensorCompositeRGB(canonical.chamberField), ...
    tensorCompositeRGB(canonical.fuchsianTiling), ...
    tensorCompositeRGB(canonical.ginibreField), ...
    scalarToRGB(canonical.spectralPalette, false)};
for i = 1:numel(sourceFileNames)
    path = fullfile(cfg.sourceImages, [sourceFileNames{i} '.png']);
    imwrite(imresize(sourceImages{i}, ...
        [cfg.outputImageSize cfg.outputImageSize], 'nearest'), path);
    images(imageIndex) = imageEntry(sourceFileNames{i}, path, ...
        'canonical_h5');
    imageIndex = imageIndex + 1;
end

calibrationPath = fullfile(cfg.systemImages, ...
    'HumanNotationCalibration.png');
imwrite(imresize(scalarToRGB(weights.humanSymbolCalibration, false), ...
    [cfg.outputImageSize cfg.outputImageSize], 'nearest'), calibrationPath);
images(imageIndex) = imageEntry('HumanNotationCalibration', ...
    calibrationPath, 'twenty_concepts_by_twelve_primitives');
imageIndex = imageIndex + 1;

relationsPath = fullfile(cfg.systemImages, 'ConceptRelations.png');
relationRGB = complexToRGB(weights.conceptRelations .* exp(1i .* basePhase(1)));
imwrite(imresize(relationRGB, [cfg.outputImageSize cfg.outputImageSize], ...
    'nearest'), relationsPath);
images(imageIndex) = imageEntry('ConceptRelations', relationsPath, ...
    'structural_similarity');
end


function map = connectionDensityMap(connectionTensor, side)
points = [connectionTensor(:, 1:2); connectionTensor(:, 3:4)].';
weights = [connectionTensor(:, 5); connectionTensor(:, 5)];
x = normalizeVector(points(1, :));
y = normalizeVector(points(2, :));
xi = min(side, max(1, floor(x .* side) + 1));
yi = min(side, max(1, floor(y .* side) + 1));
map = accumarray([yi(:), xi(:)], abs(weights(:)), ...
    [side side], @sum, 0);
map = normalize01(imgaussfilt(map, 1.2));
end


function rgb = structurePhaseRGB(structure, phase, complexity)
magnitude = normalize01(structure);
hue = mod(phase + 2 .* pi .* complexity, 2 .* pi) ./ (2 .* pi);
hsvImage = cat(3, hue, 0.52 + 0.46 .* magnitude, ...
    0.04 + 0.96 .* sqrt(magnitude));
rgb = im2uint8(hsv2rgb(hsvImage));
end


function rgb = tensorCompositeRGB(tensor)
channelCount = size(tensor, 3);
red = normalize01(tensor(:, :, 1));
green = normalize01(tensor(:, :, min(2, channelCount)));
blue = normalize01(mean(tensor(:, :, min(3, channelCount):end), 3));
rgb = im2uint8(cat(3, red, green, blue));
end


function rgb = scalarToRGB(value, diverging)
value = double(value);
if diverging
    scale = max(abs(value(:)));
    if scale <= eps
        normalized = zeros(size(value));
    else
        normalized = value ./ scale;
    end
    positive = max(normalized, 0);
    negative = max(-normalized, 0);
    magnitude = abs(normalized);
    rgb = cat(3, 0.04 + 0.92 .* positive, ...
        0.04 + 0.74 .* magnitude, 0.08 + 0.92 .* negative);
else
    normalized = normalize01(value);
    rgb = cat(3, 0.03 + 0.92 .* normalized .^ 1.3, ...
        0.04 + 0.80 .* sqrt(normalized), ...
        0.10 + 0.88 .* (1 - exp(-3 .* normalized)));
end
rgb = im2uint8(min(max(rgb, 0), 1));
end


function rgb = complexToRGB(value)
magnitude = normalize01(abs(value));
phase = mod(angle(value) + pi, 2 .* pi) ./ (2 .* pi);
hsvImage = cat(3, phase, 0.44 + 0.56 .* magnitude, ...
    0.05 + 0.95 .* sqrt(magnitude));
rgb = im2uint8(hsv2rgb(hsvImage));
end


function entry = imageEntry(representation, filePath, source)
entry = emptyImageIndex();
entry.representation = representation;
entry.file = filePath;
entry.source = source;
end


function bundle = assembleBundle(cfg, vocabulary, canonical, dictionary, ...
    tensors, weights, validation, images)
bundle = struct;
bundle.version = cfg.version;
bundle.subject = cfg.subject;
bundle.domain = cfg.domain;
bundle.rendered_text = false;
bundle.canonical_h5 = cfg.canonicalH5;
bundle.canonical_sha256 = cfg.expectedSHA256;
bundle.vocabulary_source = cfg.vocabularyJSON;
bundle.vocabulary_sha256 = vocabulary.sourceHash;
bundle.prior_bundle = cfg.priorBundle;
bundle.vocabulary = vocabulary;
bundle.canonical_tensors = canonical;
bundle.dictionary = dictionary;
bundle.tensors = tensors;
bundle.weights = weights;
bundle.validation = validation;
bundle.images = images;
bundle.generated_at = char(datetime('now', ...
    'TimeZone', 'Asia/Jerusalem', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
end


function [exported, message] = writeBundleH5(filePath, canonical, ...
    tensors, weights)
exported = false;
try
    writeStructH5(filePath, '/canonical_source', canonical);
    writeStructH5(filePath, '/tensors', tensors);
    writeStructH5(filePath, '/weights', weights);
    exported = true;
    message = 'complete';
catch h5Error
    if isfile(filePath)
        delete(filePath);
    end
    message = h5Error.message;
    warning('H5 export skipped: %s', h5Error.message);
end
end


function writeStructH5(filePath, groupPath, structure)
names = fieldnames(structure);
for i = 1:numel(names)
    value = structure.(names{i});
    if isnumeric(value) || islogical(value)
        writeH5Value(filePath, [groupPath '/' names{i}], value);
    end
end
end


function writeH5Value(filePath, datasetPath, value)
if ~isreal(value)
    writeH5Dataset(filePath, [datasetPath '/real'], real(value));
    writeH5Dataset(filePath, [datasetPath '/imag'], imag(value));
else
    writeH5Dataset(filePath, datasetPath, value);
end
end


function writeH5Dataset(filePath, datasetPath, value)
value = single(value);
h5create(filePath, datasetPath, size(value), ...
    'Datatype', 'single', 'Deflate', 6, 'ChunkSize', chunkSize(value));
h5write(filePath, datasetPath, value);
end


function chunk = chunkSize(value)
dimensions = size(value);
chunk = min(dimensions, max(ones(size(dimensions)), ...
    ceil(dimensions ./ 2)));
end


function manifests = writeManifests(cfg, bundle, h5Exported, ...
    h5Message, startTime)
manifests = struct;
manifests.indexJSON = fullfile(cfg.manifestsDirectory, ...
    'StringTheorySymbolStructureIndex.json');
manifests.vocabularyJSON = fullfile(cfg.manifestsDirectory, ...
    'HumanNotationVocabulary.json');
manifests.shapesCSV = fullfile(cfg.manifestsDirectory, ...
    'TensorShapes.csv');
manifests.bindingsCSV = fullfile(cfg.manifestsDirectory, ...
    'HumanNotationBindings.csv');
manifests.summaryTXT = fullfile(cfg.manifestsDirectory, 'RunSummary.txt');

index = struct;
index.version = bundle.version;
index.subject = bundle.subject;
index.domain = bundle.domain;
index.rendered_text = false;
index.canonical_h5 = bundle.canonical_h5;
index.canonical_sha256 = bundle.canonical_sha256;
index.vocabulary_source = bundle.vocabulary_source;
index.vocabulary_sha256 = bundle.vocabulary_sha256;
index.concept_count = bundle.vocabulary.itemCount;
index.primitive_count = numel(bundle.dictionary.primitiveNames);
index.canonical_tensor_names = fieldnames(bundle.canonical_tensors);
index.tensor_names = fieldnames(bundle.tensors);
index.weight_names = fieldnames(bundle.weights);
index.images = bundle.images;
index.validation = bundle.validation;
index.h5_exported = h5Exported;
index.h5_message = h5Message;
writeText(manifests.indexJSON, jsonencode(index, PrettyPrint=true));

vocabularyOutput = struct;
vocabularyOutput.document = bundle.vocabulary.document;
vocabularyOutput.language = bundle.vocabulary.language;
vocabularyOutput.encoding = bundle.vocabulary.encoding;
vocabularyOutput.schema = bundle.vocabulary.schema;
vocabularyOutput.items = bundle.vocabulary.items;
vocabularyOutput.primitive_names = bundle.dictionary.primitiveNames;
vocabularyOutput.incidence_rank = bundle.dictionary.rank;
vocabularyOutput.incidence_shape = size(bundle.dictionary.incidence);
vocabularyOutput.calibration_shape = size(bundle.dictionary.calibratedMap);
writeText(manifests.vocabularyJSON, jsonencode( ...
    vocabularyOutput, PrettyPrint=true));

shapeRows = buildShapeRows(bundle.canonical_tensors, ...
    bundle.tensors, bundle.weights);
writecell(shapeRows, manifests.shapesCSV);

bindingRows = cell(bundle.vocabulary.itemCount + 1, 5);
bindingRows(1, :) = {'id', 'term_he', 'term_en', ...
    'symbol', 'active_primitive_count'};
for i = 1:bundle.vocabulary.itemCount
    bindingRows(i + 1, :) = {i, ...
        char(bundle.vocabulary.termHebrew(i)), ...
        char(bundle.vocabulary.termEnglish(i)), ...
        char(bundle.vocabulary.symbols(i)), ...
        sum(bundle.dictionary.incidence(i, :))};
end
writecell(bindingRows, manifests.bindingsCSV);

lines = { ...
    'YEHOSHUA STRING THEORY SYMBOL STRUCTURE V2'
    'subject=image_learning'
    'domain=string_theory_human_symbol_structure'
    'rendered_text=false'
    sprintf('canonical_sha256=%s', cfg.expectedSHA256)
    sprintf('vocabulary_sha256=%s', bundle.vocabulary_sha256)
    sprintf('concept_count=%d', bundle.vocabulary.itemCount)
    sprintf('primitive_count=%d', numel(bundle.dictionary.primitiveNames))
    sprintf('incidence_rank=%d', bundle.dictionary.rank)
    sprintf('image_count=%d', numel(bundle.images))
    sprintf('canonical_tensor_count=%d', ...
        numel(fieldnames(bundle.canonical_tensors)))
    sprintf('training_tensor_count=%d', ...
        numel(fieldnames(bundle.tensors)))
    sprintf('weight_count=%d', numel(fieldnames(bundle.weights)))
    sprintf('calibration_row_sum_max_error=%.12g', ...
        bundle.validation.calibration_row_sum_max_error)
    sprintf('relation_spectral_radius=%.12g', ...
        bundle.validation.relation_spectral_radius)
    sprintf('semantic_sequence_is_dag=%s', ...
        string(bundle.validation.semantic_sequence_is_dag))
    sprintf('h5_exported=%s', string(h5Exported))
    sprintf('elapsed_seconds=%.6f', toc(startTime))};
writeText(manifests.summaryTXT, strjoin(lines, newline));
end


function rows = buildShapeRows(canonical, tensors, weights)
total = 1 + numel(fieldnames(canonical)) + ...
    numel(fieldnames(tensors)) + numel(fieldnames(weights));
rows = cell(total, 5);
rows(1, :) = {'category', 'name', 'dimensions', ...
    'element_count', 'complex'};
row = 2;
groups = {canonical, 'canonical_source'; tensors, 'tensor'; ...
    weights, 'weight'};
for groupIndex = 1:size(groups, 1)
    structure = groups{groupIndex, 1};
    category = groups{groupIndex, 2};
    names = fieldnames(structure);
    for i = 1:numel(names)
        value = structure.(names{i});
        if isnumeric(value) || islogical(value)
            rows(row, :) = {category, names{i}, mat2str(size(value)), ...
                numel(value), ~isreal(value)};
            row = row + 1;
        end
    end
end
rows = rows(1:row - 1, :);
end


function stack = decodeFlatChannels(raw, height, width)
raw = squeeze(raw);
pixelCount = height .* width;
if size(raw, 2) == pixelCount
    channelCount = size(raw, 1);
elseif size(raw, 1) == pixelCount
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
    if isnumeric(value) && (~all(isfinite(real(value(:)))) || ...
            ~all(isfinite(imag(value(:)))))
        valid = false;
        return;
    end
end
end


function entry = emptyImageIndex()
entry = struct('representation', '', 'file', '', ...
    'source', '', 'rendered_text', false);
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
