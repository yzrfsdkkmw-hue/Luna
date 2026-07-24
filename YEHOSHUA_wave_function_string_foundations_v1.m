function results = YEHOSHUA_wave_function_string_foundations_v1()
% YEHOSHUA_wave_function_string_foundations_v1
% Extends the organized wave-function tensor, adds human symbol calibration
% for foundational string-theory vocabulary, and computes the strict
% terminal-chain and projection metrics described in the supplied draft.

cfg = configuration();
startTime = tic;
validateInputs(cfg);
assert(~isfolder(cfg.outputRoot), ...
    'Output folder already exists; no files were changed.');

try
    createOutputFolders(cfg);
    fprintf('\n%s\n', repmat('=', 1, 72));
    fprintf('YEHOSHUA WAVE FUNCTION AND STRING FOUNDATIONS V1\n');
    fprintf('%s\n', repmat('=', 1, 72));
    fprintf('canonical H5: %s\n', cfg.canonicalH5);
    fprintf('draft JSON  : %s\n', cfg.draftJSON);
    fprintf('output      : %s\n\n', cfg.outputRoot);

    document = analyzeDraftDocument(cfg);
    h5Source = extractCanonicalTensors(cfg);
    prior = readPriorBundles(cfg);
    projection = computeProjectionMetrics(prior, document);
    vocabulary = buildStringVocabulary(prior);
    tensors = buildWaveAndStringTensors( ...
        cfg, h5Source, prior, projection, vocabulary, document);
    weights = buildTrainingWeights( ...
        tensors, prior, projection, vocabulary, document);
    validation = validateBundle( ...
        tensors, weights, projection, document, vocabulary);
    images = renderImages(cfg, tensors, weights, projection, document);

    bundle = assembleBundle(cfg, h5Source, tensors, weights, ...
        projection, document, vocabulary, validation, images);
    matPath = fullfile(cfg.weightsDirectory, ...
        'WaveFunctionStringTensorWeights.mat');
    save(matPath, 'bundle', '-v7.3');

    h5Path = fullfile(cfg.weightsDirectory, ...
        'WaveFunctionStringTensorWeights.h5');
    [h5Exported, h5Message] = writeBundleH5( ...
        h5Path, h5Source, tensors, weights);
    writematrix(weights.humanSymbolCalibration, ...
        fullfile(cfg.weightsDirectory, 'HumanSymbolCalibrationWeights.csv'));

    manifests = writeManifests(cfg, bundle, h5Exported, ...
        h5Message, startTime);

    results = struct;
    results.outputRoot = cfg.outputRoot;
    results.imageCount = numel(images);
    results.tensorCount = numel(fieldnames(tensors));
    results.h5SourceTensorCount = numel(fieldnames(h5Source));
    results.weightCount = numel(fieldnames(weights));
    results.weightsMAT = matPath;
    results.weightsH5 = h5Path;
    results.h5Exported = h5Exported;
    results.validation = validation;
    results.documentMetrics = document.metrics;
    results.manifests = manifests;
    results.elapsedSeconds = toc(startTime);

    fprintf('\nRUN COMPLETE\n');
    fprintf('Images                 : %d\n', results.imageCount);
    fprintf('Training tensors       : %d\n', results.tensorCount);
    fprintf('Canonical H5 tensors   : %d\n', results.h5SourceTensorCount);
    fprintf('Weight arrays          : %d\n', results.weightCount);
    fprintf('Terminal process DAG   : %s\n', ...
        string(document.metrics.terminal_process_is_dag));
    fprintf('Full graph DAG         : %s\n', ...
        string(document.metrics.full_graph_is_dag));
    fprintf('H5 export              : %s\n', string(h5Exported));
    fprintf('Output folder          : %s\n', cfg.outputRoot);
    fprintf('Elapsed                : %.3f s\n', results.elapsedSeconds);
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
cfg.version = 'YEHOSHUA_wave_function_string_foundations_v1';
cfg.subject = 'image_learning';
cfg.domain = 'wave_function_and_string_foundations';
cfg.canonicalH5 = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.draftJSON = ['/Users/yehoshua/Downloads/' ...
    ['This_is_a_quantization_of_knowledge_strictly_acyclic_' ...
    'no_amplification_terminal_chain_draft_v3.json']];
cfg.basePath = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15'];
cfg.orchBundle = fullfile(cfg.basePath, ...
    'YEHOSHUA_Orch_tensor_training_bundle_v1');
cfg.orchH5 = fullfile(cfg.orchBundle, 'weights', ...
    'OrchTensorWeights.h5');
cfg.quantumBundle = fullfile(cfg.basePath, ...
    'YEHOSHUA_quantum_mechanics_tensor_training_bundle_v1');
cfg.quantumH5 = fullfile(cfg.quantumBundle, 'weights', ...
    'QuantumTensorWeights.h5');
cfg.outputRoot = fullfile(cfg.basePath, ...
    'YEHOSHUA_wave_function_string_foundations_tensor_training_bundle_v1');
cfg.imagesDirectory = fullfile(cfg.outputRoot, 'images');
cfg.waveImages = fullfile(cfg.imagesDirectory, 'wave_function');
cfg.stringImages = fullfile(cfg.imagesDirectory, 'string_foundations');
cfg.systemImages = fullfile(cfg.imagesDirectory, 'terminal_system');
cfg.tensorsDirectory = fullfile(cfg.outputRoot, 'tensors');
cfg.weightsDirectory = fullfile(cfg.outputRoot, 'weights');
cfg.manifestsDirectory = fullfile(cfg.outputRoot, 'manifests');
cfg.spatialSize = 64;
cfg.waveSnapshotCount = 12;
cfg.processStageCount = 8;
cfg.basisDimension = 16;
cfg.termCount = 10;
cfg.outputImageSize = 512;
end


function validateInputs(cfg)
assert(isfile(cfg.canonicalH5), 'Canonical H5 was not found.');
assert(strcmpi(sha256File(cfg.canonicalH5), cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
assert(isfile(cfg.draftJSON), 'Draft v3 JSON was not found.');
assert(isfile(cfg.orchH5), 'Organized training H5 was not found.');
assert(isfile(cfg.quantumH5), 'Quantum training H5 was not found.');

draft = jsondecode(fileread(cfg.draftJSON));
required = { ...
    'layer_18B_human_agent_symbol_calibration'
    'layer_23_biological_theoretical_noise_filtering'
    'layer_24_acyclic_constant_novelty_learning_trajectory'
    'layer_25_terminal_visual_educational_learning_state'};
for i = 1:numel(required)
    assert(isfield(draft, required{i}), ...
        'Required draft layer is missing: %s', required{i});
end
end


function createOutputFolders(cfg)
mkdir(cfg.outputRoot);
mkdir(cfg.imagesDirectory);
mkdir(cfg.waveImages);
mkdir(cfg.stringImages);
mkdir(cfg.systemImages);
mkdir(cfg.tensorsDirectory);
mkdir(cfg.weightsDirectory);
mkdir(cfg.manifestsDirectory);
end


function document = analyzeDraftDocument(cfg)
fprintf('[1/7] Computing document graph and terminal-chain metrics\n');
rawText = fileread(cfg.draftJSON);
draft = jsondecode(rawText);
declaredNodes = string(draft.complete_dependency_graph.nodes(:));
edgeRecords = draft.complete_dependency_graph.directed_edges;
sources = strings(0, 1);
targets = strings(0, 1);
operators = strings(0, 1);
for i = 1:numel(edgeRecords)
    currentSources = splitEndpoint(edgeRecords(i).from);
    currentTargets = splitEndpoint(edgeRecords(i).to);
    for s = 1:numel(currentSources)
        for t = 1:numel(currentTargets)
            sources(end + 1, 1) = currentSources(s); %#ok<AGROW>
            targets(end + 1, 1) = currentTargets(t); %#ok<AGROW>
            operators(end + 1, 1) = string(edgeRecords(i).operator); %#ok<AGROW>
        end
    end
end

allReferenced = unique([sources; targets], 'stable');
undeclared = setdiff(allReferenced, declaredNodes, 'stable');
allNodes = unique([declaredNodes; allReferenced], 'stable');
fullGraph = digraph(cellstr(sources), cellstr(targets), [], ...
    cellstr(allNodes));
simpleFullGraph = simplify(fullGraph);
fullGraphIsDAG = isdag(simpleFullGraph);
bins = conncomp(simpleFullGraph, 'Type', 'strong');
cycleComponents = cell(0, 1);
for component = unique(bins)
    members = string(simpleFullGraph.Nodes.Name(bins == component));
    if numel(members) > 1
        cycleComponents{end + 1, 1} = cellstr(members); %#ok<AGROW>
    end
end

edgeKeys = sources + " -> " + targets;
duplicateEdgeCount = numel(edgeKeys) - numel(unique(edgeKeys));
process = buildTerminalProcessGraph(cfg.processStageCount);

taskEnergy = 1;
abruptNoise = 2.0488;
organizedNoise = 0.4771;
etaAbrupt = taskEnergy ./ (taskEnergy + abruptNoise);
etaOrganized = taskEnergy ./ (taskEnergy + organizedNoise);
noiseSlope = organizedNoise - abruptNoise;
linearSensitivity = abs(-taskEnergy .* noiseSlope ./ ...
    (taskEnergy + organizedNoise) .^ 2);

metrics = struct;
metrics.full_graph_declared_node_count = numel(declaredNodes);
metrics.full_graph_referenced_node_count = numel(allNodes);
metrics.full_graph_expanded_edge_count = numel(sources);
metrics.full_graph_duplicate_edge_count = duplicateEdgeCount;
metrics.full_graph_undeclared_endpoint_count = numel(undeclared);
metrics.full_graph_undeclared_endpoints = cellstr(undeclared);
metrics.full_graph_is_dag = fullGraphIsDAG;
metrics.full_graph_cycle_components = cycleComponents;
metrics.terminal_process_node_count = numnodes(process.graph);
metrics.terminal_process_edge_count = numedges(process.graph);
metrics.terminal_process_is_dag = isdag(process.graph);
metrics.terminal_rank_condition = process.rankCondition;
metrics.terminal_longest_path_edges = process.longestPathEdges;
metrics.terminal_adjacency_nilpotency_index = process.nilpotencyIndex;
metrics.terminal_forbidden_back_path_count = process.forbiddenBackPathCount;
metrics.eta_abrupt_fraction = '1250/3811';
metrics.eta_abrupt = etaAbrupt;
metrics.eta_organized_fraction = '10000/14771';
metrics.eta_organized = etaOrganized;
metrics.eta_absolute_change = etaOrganized - etaAbrupt;
metrics.eta_relative_change = etaOrganized ./ etaAbrupt - 1;
metrics.nsr_reduction_fraction = 1 - organizedNoise ./ abruptNoise;
metrics.linear_novelty_max_sensitivity = linearSensitivity;
metrics.legacy_gain_parallel_symbol_count = ...
    count(string(rawText), "g_∥");
metrics.legacy_gain_orthogonal_symbol_count = ...
    count(string(rawText), "g_⊥");
metrics.legacy_selective_amplification_phrase_count = ...
    count(string(rawText), "אופרטור הגברה סלקטיבי");
metrics.terminal_closure_numeric_gate_computable = false;
metrics.terminal_closure_missing_inputs = { ...
    'human response records r_0:M^H'
    'terminal loss values'
    'closure thresholds epsilon'
    'eta_min'
    'rho_max'};

document = struct;
document.sourceHash = sha256File(cfg.draftJSON);
document.metrics = metrics;
document.process = process;
document.fullGraphSources = sources;
document.fullGraphTargets = targets;
document.fullGraphOperators = operators;
document.v3Status = draft.integration_revision_draft. ...
    strict_acyclic_correction_v3.status;
end


function tokens = splitEndpoint(value)
tokens = strtrim(split(string(value), ','));
tokens = tokens(strlength(tokens) > 0);
end


function process = buildTerminalProcessGraph(stageCount)
M = stageCount - 1;
sceneNodes = "X_SV_" + string((0:M).');
nodes = [sceneNodes; "H_M"; "A_M"; "J_M"; "Lambda_learn_terminal"];
sources = strings(0, 1);
targets = strings(0, 1);
for m = 0:M-1
    sources(end + 1, 1) = "X_SV_" + string(m); %#ok<AGROW>
    targets(end + 1, 1) = "X_SV_" + string(m + 1); %#ok<AGROW>
end
sources = [sources; "X_SV_" + string(M); "X_SV_" + string(M); ...
    "H_M"; "A_M"; "J_M"];
targets = [targets; "H_M"; "A_M"; "J_M"; "J_M"; ...
    "Lambda_learn_terminal"];
graph = digraph(cellstr(sources), cellstr(targets), [], cellstr(nodes));
ranks = [(0:M).'; M + 1; M + 1; M + 2; M + 3];
sourceRanks = ranks(findnode(graph, cellstr(sources)));
targetRanks = ranks(findnode(graph, cellstr(targets)));
rankCondition = all(sourceRanks < targetRanks);
adjacencyMatrix = full(adjacency(graph));
powerMatrix = eye(size(adjacencyMatrix));
nilpotencyIndex = NaN;
for k = 1:size(adjacencyMatrix, 1) + 1
    powerMatrix = powerMatrix * adjacencyMatrix;
    if ~any(powerMatrix(:))
        nilpotencyIndex = k;
        break;
    end
end
distanceMatrix = distances(graph);
longestPathEdges = max(distanceMatrix(isfinite(distanceMatrix)));
terminalIndex = findnode(graph, 'Lambda_learn_terminal');
sceneIndices = findnode(graph, cellstr(sceneNodes));
forbiddenBackPathCount = sum(isfinite( ...
    distanceMatrix(terminalIndex, sceneIndices)));

process = struct;
process.graph = graph;
process.nodes = nodes;
process.sources = sources;
process.targets = targets;
process.ranks = ranks;
process.adjacency = adjacencyMatrix;
process.topologicalOrder = toposort(graph);
process.rankCondition = rankCondition;
process.nilpotencyIndex = nilpotencyIndex;
process.longestPathEdges = longestPathEdges;
process.forbiddenBackPathCount = forbiddenBackPathCount;
end


function h5Source = extractCanonicalTensors(cfg)
fprintf('[2/7] Extracting tensors from the canonical H5\n');
h5Source = struct;
h5Source.latticeModes = double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/laplacian_modes/modes'));
h5Source.latticeModes = orientChannelsFirst(h5Source.latticeModes, 12);
h5Source.roots2D = double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/roots_2d'));
h5Source.roots2D = orientChannelsFirst(h5Source.roots2D, 2);

raw = single(h5read(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/modular_eta/data'));
h5Source.modularEta = resizeStack( ...
    decodeFlatChannels(raw, 800, 800), cfg.spatialSize);
clear raw;
raw = single(h5read(cfg.canonicalH5, ...
    '/n_6_field_maps_v3_800x800/weyl_field/data'));
h5Source.weylField = resizeStack( ...
    decodeFlatChannels(raw, 800, 800), cfg.spatialSize);
clear raw;
raw = single(h5read(cfg.canonicalH5, ...
    '/n_5_composite_field_1000x1000/data'));
h5Source.compositeField = resizeStack( ...
    decodeFlatChannels(raw, 1000, 1000), cfg.spatialSize);
clear raw;

velocity = single(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/vel'));
velocity = orientChannelsFirst(velocity, 2);
velocity = decodeFlatChannels(velocity, 220, 220);
curlField = single(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/curl'));
curlField = reshape(curlField(:), 220, 220);
h5Source.geodesic = cat(3, resizeStack(velocity, cfg.spatialSize), ...
    single(imresize(curlField, [cfg.spatialSize cfg.spatialSize])));

positions = double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/pos'));
positions = orientChannelsFirst(positions, 2);
charges = double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/charge'));
h5Source.defectDensity = buildDefectDensity(positions, charges, 32);
h5Source.phaseStops = double(h5read(cfg.canonicalH5, ...
    '/spectral_mappings/phase_stops'));
h5Source.chamberAngles = double(h5read(cfg.canonicalH5, ...
    '/n_7_apollonian_circle_model/e8_chamber_angles'));
assert(allFiniteStruct(h5Source), ...
    'Canonical H5 extraction contains non-finite values.');
end


function prior = readPriorBundles(cfg)
fprintf('[3/7] Reading organized quantum and symbol calibration tensors\n');
prior = struct;
prior.training = double(h5read(cfg.orchH5, '/tensors/training'));
prior.symbolCalibration = double(h5read( ...
    cfg.orchH5, '/weights/symbolCalibration'));
prior.knowledgeChannel = double(h5read( ...
    cfg.orchH5, '/weights/knowledgeChannel'));
prior.waveFunction = complex( ...
    double(h5read(cfg.quantumH5, '/tensors/waveFunction/real')), ...
    double(h5read(cfg.quantumH5, '/tensors/waveFunction/imag')));
prior.densityMatrices = complex( ...
    double(h5read(cfg.quantumH5, '/tensors/densityMatrices/real')), ...
    double(h5read(cfg.quantumH5, '/tensors/densityMatrices/imag')));
prior.hamiltonian = double(h5read( ...
    cfg.quantumH5, '/weights/hamiltonian'));
prior.measurementKernel = double(h5read( ...
    cfg.quantumH5, '/weights/measurementKernel'));
assert(isequal(size(prior.training), [16 16 8]), ...
    'Prior training tensor must be 16 x 16 x 8.');
assert(isequal(size(prior.waveFunction), [64 64 8]), ...
    'Prior wave-function tensor must be 64 x 64 x 8.');
assert(allFiniteStruct(prior), 'Prior bundle contains non-finite values.');
end


function projection = computeProjectionMetrics(prior, document)
fprintf('[4/7] Computing orthogonal projection and no-amplification metrics\n');
fieldMatrix = reshape(prior.training, [], size(prior.training, 3));
[leftVectors, ~, ~] = svd(fieldMatrix, 'econ');
taskRank = 4;
basis = leftVectors(:, 1:taskRank);
taskProjector = basis * basis';
complementProjector = eye(size(taskProjector)) - taskProjector;
stageCount = size(fieldMatrix, 2);
metrics = zeros(stageCount, 6);
for stage = 1:stageCount
    field = fieldMatrix(:, stage);
    task = taskProjector * field;
    nonTask = complementProjector * field;
    taskEnergy = norm(task) .^ 2;
    nonTaskEnergy = norm(nonTask) .^ 2;
    totalEnergy = norm(field) .^ 2;
    metrics(stage, :) = [taskEnergy, nonTaskEnergy, ...
        taskEnergy ./ max(totalEnergy, eps), abs(task' * nonTask), ...
        norm(field - task - nonTask), ...
        abs(totalEnergy - taskEnergy - nonTaskEnergy)];
end

projection = struct;
projection.taskProjector = taskProjector;
projection.complementProjector = complementProjector;
projection.metrics = metrics;
projection.metricNames = { ...
    'task_energy', 'non_task_energy', 'eta', 'orthogonality_error', ...
    'reconstruction_error', 'energy_identity_error'};
projection.taskRank = taskRank;
projection.taskOperatorNorm = norm(taskProjector, 2);
projection.complementOperatorNorm = norm(complementProjector, 2);
projection.projectorIdempotenceError = ...
    norm(taskProjector * taskProjector - taskProjector, 'fro');
projection.complementIdempotenceError = ...
    norm(complementProjector * complementProjector - ...
    complementProjector, 'fro');
projection.crossProjectorError = ...
    norm(taskProjector * complementProjector, 'fro');
projection.noAmplification = ...
    projection.taskOperatorNorm <= 1 + 1e-10 && ...
    projection.complementOperatorNorm <= 1 + 1e-10;
projection.documentEtaAbrupt = document.metrics.eta_abrupt;
projection.documentEtaOrganized = document.metrics.eta_organized;
end


function vocabulary = buildStringVocabulary(prior)
terms = { ...
    'string'
    'open_string'
    'closed_string'
    'worldsheet'
    'string_mode'
    'string_tension'
    'compact_dimension'
    'brane'
    'string_interaction'
    'duality_mapping'};
definitions = { ...
    'one-dimensional extended object'
    'string with two endpoints'
    'loop-shaped string without endpoints'
    'two-dimensional surface traced by string evolution'
    'discrete oscillation pattern along a string'
    'energy scale associated with string extension'
    'spatial direction represented with compact periodic structure'
    'extended surface supporting or constraining string endpoints'
    'joining or splitting relation among string trajectories'
    'mapping between two equivalent structural descriptions'};
primitives = { ...
    'point', 'line', 'loop', 'surface', 'boundary', ...
    'node', 'bridge', 'oscillation', 'compact_cycle', 'dual_pair'};
incidence = logical(tril(ones(10)));
target = normalizeRowsPositive(double(incidence));
priorMap = prior.symbolCalibration;
extendedPrior = [priorMap, mean(priorMap(:, 1:4), 2), ...
    mean(priorMap(:, 5:8), 2)];
estimatedHuman = normalizeRowsPositive(extendedPrior);
calibrated = normalizeRowsPositive(0.65 .* target + ...
    0.35 .* estimatedHuman);

vocabulary = struct;
vocabulary.terms = terms;
vocabulary.definitions = definitions;
vocabulary.primitives = primitives;
vocabulary.incidence = incidence;
vocabulary.targetMap = target;
vocabulary.estimatedHumanMap = estimatedHuman;
vocabulary.calibratedMap = calibrated;
vocabulary.rank = rank(double(incidence));
end


function tensors = buildWaveAndStringTensors(cfg, h5Source, prior, ...
    projection, vocabulary, document)
fprintf('[5/7] Extending the wave function and string-foundation tensors\n');
n = cfg.spatialSize;
snapshotCount = cfg.waveSnapshotCount;
[x, y] = meshgrid(linspace(-1, 1, n));
baseWave = interpolateComplexSnapshots(prior.waveFunction, snapshotCount);
modeMaps = buildModeMaps(h5Source.roots2D, ...
    h5Source.latticeModes, n);
extendedWave = complex(zeros(n, n, snapshotCount));
stringModes = complex(zeros(n, n, snapshotCount));
tensionField = zeros(n, n, snapshotCount);
for k = 1:snapshotCount
    mode = normalizeSigned(modeMaps(:, :, k));
    sourceModulation = 0.72 + 0.18 .* normalize01( ...
        h5Source.modularEta(:, :, mod(k - 1, ...
        size(h5Source.modularEta, 3)) + 1)) + ...
        0.10 .* normalize01(h5Source.compositeField(:, :, ...
        mod(k - 1, size(h5Source.compositeField, 3)) + 1));
    stringMode = (0.55 + 0.45 .* abs(mode)) .* ...
        exp(1i .* pi .* mode);
    psi = baseWave(:, :, k) .* stringMode .* sourceModulation;
    psi = normalizeWaveFunction(psi);
    [gradientX, gradientY] = gradient(psi);
    extendedWave(:, :, k) = psi;
    stringModes(:, :, k) = stringMode;
    tensionField(:, :, k) = abs(gradientX) .^ 2 + ...
        abs(gradientY) .^ 2;
end
probability = abs(extendedWave) .^ 2;
phase = angle(extendedWave);

openString = zeros(n, n, cfg.processStageCount);
closedString = zeros(n, n, cfg.processStageCount);
for k = 1:cfg.processStageCount
    openString(:, :, k) = renderOpenStringField(x, y, k, ...
        cfg.processStageCount);
    closedString(:, :, k) = renderClosedStringField(x, y, k, ...
        cfg.processStageCount);
end
worldsheet = buildWorldsheetTensor(x, y, openString, extendedWave);
compactDimension = buildCompactDimensionTensor(32);
brane = buildBraneTensor(x, y, h5Source.weylField);
interaction = buildInteractionTensor(x, y);
duality = buildDualityTensor(prior, vocabulary);

tensors = struct;
tensors.extendedWaveFunction = extendedWave;
tensors.probabilityDensity = probability;
tensors.phaseTransport = phase;
tensors.stringModes = stringModes;
tensors.worldsheet = worldsheet;
tensors.openString = openString;
tensors.closedString = closedString;
tensors.compactDimension = compactDimension;
tensors.brane = brane;
tensors.stringInteraction = interaction;
tensors.modeSpectrum = h5Source.latticeModes;
tensors.tensionField = tensionField;
tensors.dualityMapping = duality;
tensors.humanSymbolCalibration = vocabulary.calibratedMap;
tensors.terminalChainAdjacency = document.process.adjacency;
tensors.terminalChainRanks = document.process.ranks;
tensors.projectionMetrics = projection.metrics;
assert(allFiniteStruct(tensors), ...
    'Wave and string tensors contain non-finite values.');
end


function output = interpolateComplexSnapshots(input, outputCount)
inputCount = size(input, 3);
inputAxis = 1:inputCount;
outputAxis = linspace(1, inputCount, outputCount);
flat = reshape(input, [], inputCount);
realPart = interp1(inputAxis, real(flat).', outputAxis, 'linear').';
imagPart = interp1(inputAxis, imag(flat).', outputAxis, 'linear').';
output = reshape(complex(realPart, imagPart), ...
    size(input, 1), size(input, 2), outputCount);
for k = 1:outputCount
    output(:, :, k) = normalizeWaveFunction(output(:, :, k));
end
end


function maps = buildModeMaps(roots, modes, side)
rootX = normalizeVector(roots(1, :));
rootY = normalizeVector(roots(2, :));
xi = min(side, max(1, floor(rootX .* side) + 1));
yi = min(side, max(1, floor(rootY .* side) + 1));
modeCount = size(modes, 1);
maps = zeros(side, side, modeCount);
for k = 1:modeCount
    maps(:, :, k) = accumarray([yi(:), xi(:)], modes(k, :).', ...
        [side side], @mean, 0);
    maps(:, :, k) = imgaussfilt(maps(:, :, k), 2.0);
end
end


function field = renderOpenStringField(x, y, index, count)
progress = (index - 1) ./ max(count - 1, 1);
curve = 0.24 .* sin((2 + 2 .* progress) .* pi .* x + ...
    2 .* pi .* progress);
distance = abs(y - curve);
window = exp(-((x ./ 0.86) .^ 10));
field = exp(-0.5 .* (distance ./ 0.025) .^ 2) .* window;
end


function field = renderClosedStringField(x, y, index, count)
progress = (index - 1) ./ max(count - 1, 1);
radius = hypot(x, y);
angle = atan2(y, x);
targetRadius = 0.48 + 0.06 .* sin(3 .* angle + 2 .* pi .* progress);
field = exp(-0.5 .* ((radius - targetRadius) ./ 0.025) .^ 2);
end


function worldsheet = buildWorldsheetTensor(x, y, openString, wave)
stageCount = size(openString, 3);
worldsheet = zeros(size(x, 1), size(x, 2), 4, stageCount);
for k = 1:stageCount
    height = 0.65 .* openString(:, :, k) + ...
        0.35 .* normalize01(abs(wave(:, :, k)));
    worldsheet(:, :, 1, k) = x;
    worldsheet(:, :, 2, k) = y;
    worldsheet(:, :, 3, k) = height;
    worldsheet(:, :, 4, k) = angle(wave(:, :, k));
end
end


function tensor = buildCompactDimensionTensor(side)
[u, v] = meshgrid(linspace(0, 2 .* pi, side));
majorRadius = 0.62;
minorRadius = 0.24;
tensor = zeros(side, side, 4);
tensor(:, :, 1) = (majorRadius + minorRadius .* cos(v)) .* cos(u);
tensor(:, :, 2) = (majorRadius + minorRadius .* cos(v)) .* sin(u);
tensor(:, :, 3) = minorRadius .* sin(v);
tensor(:, :, 4) = mod(u + v, 2 .* pi) ./ (2 .* pi);
end


function tensor = buildBraneTensor(x, y, weylField)
tensor = zeros(size(x, 1), size(x, 2), 4);
tensor(:, :, 1) = x;
tensor(:, :, 2) = y;
tensor(:, :, 3) = 0.22 .* sin(2 .* pi .* x) .* cos(2 .* pi .* y);
tensor(:, :, 4) = normalize01(mean(weylField, 3));
end


function tensor = buildInteractionTensor(x, y)
leftUpper = lineField(x, y, [-0.90 0.42], [0 0]);
leftLower = lineField(x, y, [-0.90 -0.42], [0 0]);
rightUpper = lineField(x, y, [0 0], [0.90 0.34]);
rightLower = lineField(x, y, [0 0], [0.90 -0.34]);
join = exp(-0.5 .* ((x .^ 2 + y .^ 2) ./ 0.035 .^ 2));
tensor = cat(3, leftUpper + leftLower, ...
    rightUpper + rightLower, join, ...
    normalize01(leftUpper + leftLower + rightUpper + rightLower + join));
end


function field = lineField(x, y, startPoint, endPoint)
distance = pointToSegmentDistance(x, y, startPoint(1), startPoint(2), ...
    endPoint(1), endPoint(2));
field = exp(-0.5 .* (distance ./ 0.026) .^ 2);
end


function tensor = buildDualityTensor(prior, vocabulary)
hamiltonian = prior.hamiltonian;
density = prior.densityMatrices(:, :, end);
symbol = imresize(vocabulary.calibratedMap, [16 16], 'bilinear');
dual = rot90(symbol, 2);
tensor = cat(3, normalizeSigned(hamiltonian), abs(density), ...
    normalize01(symbol), normalize01(dual));
end


function weights = buildTrainingWeights(tensors, prior, projection, ...
    vocabulary, document)
fprintf('[6/7] Building training weights and terminal masks\n');
stageKernel = exp(-(0:size(tensors.openString, 3)-1).' ./ 3);
stageKernel = stageKernel ./ sum(stageKernel);
modeEnergy = sum(abs(tensors.modeSpectrum) .^ 2, 2);
modeEnergy = modeEnergy ./ sum(modeEnergy);
chainMask = double(document.process.adjacency > 0);
chainTransition = normalizeRowsPositive(chainMask);
terminalGateMask = zeros(size(chainMask, 1), 1);
terminalGateMask(end) = 1;

weights = struct;
weights.taskProjector = projection.taskProjector;
weights.complementProjector = projection.complementProjector;
weights.hamiltonian = prior.hamiltonian;
weights.measurementKernel = prior.measurementKernel;
weights.humanSymbolCalibration = vocabulary.calibratedMap;
weights.stringModeEnergy = modeEnergy;
weights.stageKernel = stageKernel;
weights.chainTransition = chainTransition;
weights.terminalGateMask = terminalGateMask;
end


function validation = validateBundle(tensors, weights, projection, ...
    document, vocabulary)
fprintf('[7/7] Validating normalization, DAG and calibration constraints\n');
waveCount = size(tensors.extendedWaveFunction, 3);
waveNorms = zeros(waveCount, 1);
probabilitySums = zeros(waveCount, 1);
for k = 1:waveCount
    waveNorms(k) = sum(abs(tensors.extendedWaveFunction(:, :, k)) .^ 2, ...
        'all');
    probabilitySums(k) = sum(tensors.probabilityDensity(:, :, k), 'all');
end
calibrationRowSums = sum(weights.humanSymbolCalibration, 2);
maxProjectionOrthogonality = max(projection.metrics(:, 4));
maxProjectionReconstruction = max(projection.metrics(:, 5));
maxProjectionEnergyError = max(projection.metrics(:, 6));

assert(max(abs(waveNorms - 1)) < 1e-10, ...
    'Extended wave-function normalization failed.');
assert(max(abs(probabilitySums - 1)) < 1e-10, ...
    'Probability normalization failed.');
assert(projection.projectorIdempotenceError < 1e-10, ...
    'Task projector is not idempotent.');
assert(projection.complementIdempotenceError < 1e-10, ...
    'Complement projector is not idempotent.');
assert(projection.crossProjectorError < 1e-10, ...
    'Task and complement projectors are not orthogonal.');
assert(maxProjectionOrthogonality < 1e-10, ...
    'Projected components are not orthogonal.');
assert(maxProjectionReconstruction < 1e-10, ...
    'Projection reconstruction failed.');
assert(maxProjectionEnergyError < 1e-10, ...
    'Projection energy identity failed.');
assert(projection.noAmplification, ...
    'Projection operator norm exceeds one.');
assert(document.metrics.terminal_process_is_dag && ...
    document.metrics.terminal_rank_condition, ...
    'Terminal process is not a ranked DAG.');
assert(document.metrics.terminal_forbidden_back_path_count == 0, ...
    'Terminal process contains a forbidden back path.');
assert(vocabulary.rank == 10, ...
    'String vocabulary incidence matrix is not full rank.');
assert(max(abs(calibrationRowSums - 1)) < 1e-12, ...
    'Human symbol calibration rows are not normalized.');
assert(allFiniteStruct(tensors) && allFiniteStruct(weights), ...
    'Bundle contains non-finite values.');

validation = struct;
validation.wave_norm_max_error = max(abs(waveNorms - 1));
validation.probability_sum_max_error = max(abs(probabilitySums - 1));
validation.projector_idempotence_error = ...
    projection.projectorIdempotenceError;
validation.complement_idempotence_error = ...
    projection.complementIdempotenceError;
validation.cross_projector_error = projection.crossProjectorError;
validation.projection_orthogonality_max_error = ...
    maxProjectionOrthogonality;
validation.projection_reconstruction_max_error = ...
    maxProjectionReconstruction;
validation.projection_energy_identity_max_error = ...
    maxProjectionEnergyError;
validation.task_operator_norm = projection.taskOperatorNorm;
validation.complement_operator_norm = projection.complementOperatorNorm;
validation.no_amplification = projection.noAmplification;
validation.terminal_process_is_dag = ...
    document.metrics.terminal_process_is_dag;
validation.full_graph_is_dag = document.metrics.full_graph_is_dag;
validation.terminal_forbidden_back_path_count = ...
    document.metrics.terminal_forbidden_back_path_count;
validation.vocabulary_rank = vocabulary.rank;
validation.calibration_row_sum_max_error = ...
    max(abs(calibrationRowSums - 1));
validation.all_finite = true;
end


function images = renderImages(cfg, tensors, weights, projection, document)
images = repmat(emptyImageIndex(), 16, 1);
mid = ceil(size(tensors.extendedWaveFunction, 3) ./ 2);
worldsheetHeight = tensors.worldsheet(:, :, 3, ...
    ceil(size(tensors.worldsheet, 4) ./ 2));
compactComplex = tensors.compactDimension(:, :, 1) + ...
    1i .* tensors.compactDimension(:, :, 2);

definitions = { ...
    'WaveFunctionExtension', cfg.waveImages, ...
        complexToRGB(tensors.extendedWaveFunction(:, :, mid));
    'PhaseTransport', cfg.waveImages, ...
        phaseToRGB(tensors.phaseTransport(:, :, mid), ...
        abs(tensors.extendedWaveFunction(:, :, mid)));
    'ProbabilityFlow', cfg.waveImages, ...
        scalarToRGB(mean(tensors.probabilityDensity, 3), false);
    'ModeSuperposition', cfg.waveImages, ...
        complexToRGB(tensors.stringModes(:, :, mid));
    'String', cfg.stringImages, ...
        scalarToRGB(mean(tensors.openString, 3) + ...
        mean(tensors.closedString, 3), false);
    'OpenString', cfg.stringImages, ...
        scalarToRGB(tensors.openString(:, :, end), false);
    'ClosedString', cfg.stringImages, ...
        scalarToRGB(tensors.closedString(:, :, end), false);
    'Worldsheet', cfg.stringImages, ...
        surfaceToRGB(worldsheetHeight);
    'CompactDimension', cfg.stringImages, ...
        complexToRGB(compactComplex .* exp(1i .* 2 .* pi .* ...
        tensors.compactDimension(:, :, 4)));
    'Brane', cfg.stringImages, ...
        surfaceToRGB(tensors.brane(:, :, 3) + ...
        0.25 .* tensors.brane(:, :, 4));
    'StringInteraction', cfg.stringImages, ...
        scalarToRGB(tensors.stringInteraction(:, :, 4), false);
    'ModeSpectrum', cfg.stringImages, ...
        scalarToRGB(tensors.modeSpectrum, true);
    'StringTension', cfg.stringImages, ...
        scalarToRGB(mean(tensors.tensionField, 3), false);
    'DualityMapping', cfg.stringImages, ...
        tensorTileRGB(tensors.dualityMapping);
    'HumanSymbolCalibration', cfg.systemImages, ...
        scalarToRGB(weights.humanSymbolCalibration, false);
    'TerminalChain', cfg.systemImages, ...
        renderTerminalChain(document.process, cfg.outputImageSize)};

for i = 1:size(definitions, 1)
    name = definitions{i, 1};
    directory = definitions{i, 2};
    rgb = definitions{i, 3};
    if size(rgb, 1) ~= cfg.outputImageSize || ...
            size(rgb, 2) ~= cfg.outputImageSize
        rgb = imresize(rgb, [cfg.outputImageSize cfg.outputImageSize], ...
            'nearest');
    end
    path = fullfile(directory, [name '.png']);
    imwrite(rgb, path);
    images(i).representation = name;
    images(i).file = path;
    images(i).rendered_text = false;
end

projectionImage = scalarToRGB(reshape(projection.metrics(:, 3), [], 1), false);
imwrite(imresize(projectionImage, [cfg.outputImageSize cfg.outputImageSize], ...
    'nearest'), fullfile(cfg.systemImages, 'ProjectionEfficiency.png'));
images(end + 1, 1) = emptyImageIndex();
images(end).representation = 'ProjectionEfficiency';
images(end).file = fullfile(cfg.systemImages, 'ProjectionEfficiency.png');
images(end).rendered_text = false;
end


function rgb = complexToRGB(value)
magnitude = normalize01(abs(value));
phase = mod(angle(value) + pi, 2 .* pi) ./ (2 .* pi);
hsvImage = cat(3, phase, 0.42 + 0.58 .* magnitude, ...
    0.04 + 0.96 .* sqrt(magnitude));
rgb = im2uint8(hsv2rgb(hsvImage));
end


function rgb = phaseToRGB(phase, magnitude)
hue = mod(double(phase) + pi, 2 .* pi) ./ (2 .* pi);
magnitude = normalize01(magnitude);
hsvImage = cat(3, hue, 0.88 .* ones(size(hue)), ...
    0.07 + 0.93 .* magnitude);
rgb = im2uint8(hsv2rgb(hsvImage));
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
    rgb = cat(3, 0.04 + 0.92 .* positive + 0.18 .* magnitude, ...
        0.04 + 0.72 .* magnitude, ...
        0.08 + 0.92 .* negative + 0.24 .* magnitude);
else
    normalized = normalize01(value);
    rgb = cat(3, 0.03 + 0.92 .* normalized .^ 1.3, ...
        0.04 + 0.80 .* sqrt(normalized), ...
        0.10 + 0.88 .* (1 - exp(-3 .* normalized)));
end
rgb = im2uint8(min(max(rgb, 0), 1));
end


function rgb = surfaceToRGB(height)
height = normalize01(height);
[gradientX, gradientY] = gradient(height);
shade = normalize01(0.55 - 0.42 .* gradientX + 0.28 .* gradientY);
rgb = cat(3, 0.05 + 0.85 .* height, ...
    0.08 + 0.74 .* shade, ...
    0.15 + 0.82 .* (0.55 .* height + 0.45 .* shade));
rgb = im2uint8(min(max(rgb, 0), 1));
end


function rgb = tensorTileRGB(tensor)
tiles = cell(4, 1);
for i = 1:4
    tiles{i} = scalarToRGB(tensor(:, :, i), i == 1);
end
side = size(tiles{1}, 1);
rgb = zeros(2 .* side, 2 .* side, 3, 'uint8');
rgb(1:side, 1:side, :) = tiles{1};
rgb(1:side, side + 1:end, :) = tiles{2};
rgb(side + 1:end, 1:side, :) = tiles{3};
rgb(side + 1:end, side + 1:end, :) = tiles{4};
end


function rgb = renderTerminalChain(process, outputSize)
[x, y] = meshgrid(1:outputSize, 1:outputSize);
rgb = zeros(outputSize, outputSize, 3);
nodeCount = numel(process.nodes);
positionsX = linspace(0.08 .* outputSize, 0.92 .* outputSize, nodeCount);
positionsY = 0.50 .* outputSize + ...
    0.12 .* outputSize .* sin(linspace(0, 2 .* pi, nodeCount));
for edge = 1:numel(process.sources)
    sourceIndex = find(process.nodes == process.sources(edge), 1);
    targetIndex = find(process.nodes == process.targets(edge), 1);
    distance = pointToSegmentDistance(x, y, ...
        positionsX(sourceIndex), positionsY(sourceIndex), ...
        positionsX(targetIndex), positionsY(targetIndex));
    mask = exp(-0.5 .* (distance ./ 1.5) .^ 2);
    rgb(:, :, 2) = rgb(:, :, 2) + 0.42 .* mask;
    rgb(:, :, 3) = rgb(:, :, 3) + 0.72 .* mask;
end
for node = 1:nodeCount
    mask = exp(-0.5 .* (((x - positionsX(node)) .^ 2 + ...
        (y - positionsY(node)) .^ 2) ./ 22));
    color = hsv2rgb([(node - 1) ./ max(nodeCount - 1, 1), 0.72, 1]);
    for channel = 1:3
        rgb(:, :, channel) = rgb(:, :, channel) + ...
            color(channel) .* mask;
    end
end
rgb = im2uint8(min(max(rgb, 0), 1));
end


function bundle = assembleBundle(cfg, h5Source, tensors, weights, ...
    projection, document, vocabulary, validation, images)
bundle = struct;
bundle.version = cfg.version;
bundle.subject = cfg.subject;
bundle.domain = cfg.domain;
bundle.rendered_text = false;
bundle.canonical_h5 = cfg.canonicalH5;
bundle.canonical_sha256 = cfg.expectedSHA256;
bundle.draft_json = cfg.draftJSON;
bundle.draft_sha256 = document.sourceHash;
bundle.prior_quantum_bundle = cfg.quantumBundle;
bundle.h5_source_tensors = h5Source;
bundle.tensors = tensors;
bundle.weights = weights;
bundle.projection = projection;
bundle.document_metrics = document.metrics;
bundle.vocabulary = vocabulary;
bundle.validation = validation;
bundle.images = images;
bundle.generated_at = char(datetime('now', ...
    'TimeZone', 'Asia/Jerusalem', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
end


function [exported, message] = writeBundleH5(filePath, h5Source, ...
    tensors, weights)
exported = false;
try
    writeStructH5(filePath, '/canonical_source', h5Source);
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


function paths = writeManifests(cfg, bundle, h5Exported, ...
    h5Message, startTime)
paths = struct;
paths.indexJSON = fullfile(cfg.manifestsDirectory, ...
    'WaveFunctionStringTensorIndex.json');
paths.metricsJSON = fullfile(cfg.manifestsDirectory, ...
    'DocumentExactMetrics.json');
paths.vocabularyJSON = fullfile(cfg.manifestsDirectory, ...
    'StringFoundationVocabulary.json');
paths.shapesCSV = fullfile(cfg.manifestsDirectory, ...
    'TensorShapes.csv');
paths.projectionCSV = fullfile(cfg.manifestsDirectory, ...
    'ProjectionMetrics.csv');
paths.issuesCSV = fullfile(cfg.manifestsDirectory, ...
    'DocumentConsistency.csv');
paths.summaryTXT = fullfile(cfg.manifestsDirectory, 'RunSummary.txt');

index = struct;
index.version = bundle.version;
index.subject = bundle.subject;
index.domain = bundle.domain;
index.rendered_text = false;
index.canonical_h5 = bundle.canonical_h5;
index.canonical_sha256 = bundle.canonical_sha256;
index.draft_json = bundle.draft_json;
index.draft_sha256 = bundle.draft_sha256;
index.tensor_names = fieldnames(bundle.tensors);
index.canonical_source_tensor_names = ...
    fieldnames(bundle.h5_source_tensors);
index.weight_names = fieldnames(bundle.weights);
index.images = bundle.images;
index.validation = bundle.validation;
index.h5_exported = h5Exported;
index.h5_message = h5Message;
writeText(paths.indexJSON, jsonencode(index, PrettyPrint=true));
writeText(paths.metricsJSON, jsonencode( ...
    bundle.document_metrics, PrettyPrint=true));

vocabularyOutput = rmfield(bundle.vocabulary, ...
    {'incidence', 'targetMap', 'estimatedHumanMap', 'calibratedMap'});
vocabularyOutput.incidence_shape = size(bundle.vocabulary.incidence);
vocabularyOutput.calibration_shape = ...
    size(bundle.vocabulary.calibratedMap);
writeText(paths.vocabularyJSON, jsonencode( ...
    vocabularyOutput, PrettyPrint=true));

rows = buildShapeRows(bundle.h5_source_tensors, ...
    bundle.tensors, bundle.weights);
writecell(rows, paths.shapesCSV);

projectionRows = [{'stage'}, bundle.projection.metricNames; ...
    num2cell([(0:size(bundle.projection.metrics, 1)-1).', ...
    bundle.projection.metrics])];
writecell(projectionRows, paths.projectionCSV);

issues = buildIssueRows(bundle.document_metrics);
writecell(issues, paths.issuesCSV);

lines = { ...
    'YEHOSHUA WAVE FUNCTION AND STRING FOUNDATIONS V1'
    'subject=image_learning'
    'domain=wave_function_and_string_foundations'
    'rendered_text=false'
    sprintf('canonical_sha256=%s', cfg.expectedSHA256)
    sprintf('draft_sha256=%s', bundle.draft_sha256)
    sprintf('image_count=%d', numel(bundle.images))
    sprintf('tensor_count=%d', numel(fieldnames(bundle.tensors)))
    sprintf('canonical_source_tensor_count=%d', ...
        numel(fieldnames(bundle.h5_source_tensors)))
    sprintf('weight_count=%d', numel(fieldnames(bundle.weights)))
    sprintf('terminal_process_is_dag=%s', ...
        string(bundle.document_metrics.terminal_process_is_dag))
    sprintf('full_graph_is_dag=%s', ...
        string(bundle.document_metrics.full_graph_is_dag))
    sprintf('terminal_nilpotency_index=%d', ...
        bundle.document_metrics.terminal_adjacency_nilpotency_index)
    sprintf('eta_abrupt=%.12f', ...
        bundle.document_metrics.eta_abrupt)
    sprintf('eta_organized=%.12f', ...
        bundle.document_metrics.eta_organized)
    sprintf('no_amplification=%s', ...
        string(bundle.validation.no_amplification))
    sprintf('wave_norm_max_error=%.12g', ...
        bundle.validation.wave_norm_max_error)
    sprintf('h5_exported=%s', string(h5Exported))
    sprintf('elapsed_seconds=%.6f', toc(startTime))};
writeText(paths.summaryTXT, strjoin(lines, newline));
end


function rows = buildShapeRows(h5Source, tensors, weights)
total = 1 + numel(fieldnames(h5Source)) + ...
    numel(fieldnames(tensors)) + numel(fieldnames(weights));
rows = cell(total, 5);
rows(1, :) = {'category', 'name', 'dimensions', ...
    'element_count', 'complex'};
row = 2;
groups = {h5Source, 'canonical_source'; tensors, 'tensor'; ...
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


function rows = buildIssueRows(metrics)
rows = { ...
    'item', 'value', 'status';
    'terminal_process_is_dag', metrics.terminal_process_is_dag, 'valid';
    'full_graph_is_dag', metrics.full_graph_is_dag, ...
        'scope_distinction_required';
    'full_graph_duplicate_edge_count', ...
        metrics.full_graph_duplicate_edge_count, 'review';
    'full_graph_undeclared_endpoint_count', ...
        metrics.full_graph_undeclared_endpoint_count, 'review';
    'legacy_gain_parallel_symbol_count', ...
        metrics.legacy_gain_parallel_symbol_count, 'legacy_text_present';
    'legacy_gain_orthogonal_symbol_count', ...
        metrics.legacy_gain_orthogonal_symbol_count, 'legacy_text_present';
    'legacy_selective_amplification_phrase_count', ...
        metrics.legacy_selective_amplification_phrase_count, ...
        'legacy_text_present';
    'terminal_closure_numeric_gate_computable', ...
        metrics.terminal_closure_numeric_gate_computable, ...
        'missing_calibration_values'};
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


function density = buildDefectDensity(positions, charges, side)
x = normalizeVector(positions(1, :));
y = normalizeVector(positions(2, :));
xi = min(side, max(1, floor(x .* side) + 1));
yi = min(side, max(1, floor(y .* side) + 1));
weights = 1 + normalizeVector(abs(charges(:).'));
density = accumarray([yi(:), xi(:)], weights(:), ...
    [side side], @sum, 0);
density = single(normalize01(density));
end


function psi = normalizeWaveFunction(psi)
normalizer = sqrt(sum(abs(psi) .^ 2, 'all'));
assert(normalizer > eps, 'Wave function has zero magnitude.');
psi = psi ./ normalizer;
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


function output = normalizeSigned(input)
input = double(input);
scale = max(abs(input(:)));
if scale <= eps
    output = zeros(size(input));
else
    output = input ./ scale;
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


function distance = pointToSegmentDistance(x, y, x1, y1, x2, y2)
dx = x2 - x1;
dy = y2 - y1;
denominator = dx .^ 2 + dy .^ 2;
if denominator <= eps
    distance = hypot(x - x1, y - y1);
    return;
end
t = ((x - x1) .* dx + (y - y1) .* dy) ./ denominator;
t = min(max(t, 0), 1);
projectionX = x1 + t .* dx;
projectionY = y1 + t .* dy;
distance = hypot(x - projectionX, y - projectionY);
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
    'rendered_text', false);
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
