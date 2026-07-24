function results = YEHOSHUA_orch_tensor_weight_extraction_v1()
% YEHOSHUA_orch_tensor_weight_extraction_v1
% Extracts compact training tensors from the canonical H5 and organizes
% image-learning representations and derived weights in one new bundle.

cfg = configuration();
startTime = tic;

validateInputs(cfg);
assert(~isfolder(cfg.outputRoot), ...
    'Output folder already exists; no files were changed.');

try
    createOutputFolders(cfg);

    fprintf('\n%s\n', repmat('=', 1, 72));
    fprintf('YEHOSHUA ORCH TENSOR WEIGHT EXTRACTION V1\n');
    fprintf('%s\n', repmat('=', 1, 72));
    fprintf('canonical H5 : %s\n', cfg.h5File);
    fprintf('output bundle: %s\n\n', cfg.outputRoot);

    prior = readPriorState(cfg);
    tensors = extractCompactTensors(cfg);
    weights = buildTrainingWeights(tensors, prior);
    validation = validateWeights(tensors, weights, prior);

    imageIndex = organizePriorImages(cfg);
    imageIndex = [imageIndex; renderWeightImages(cfg, weights)]; %#ok<AGROW>

    matPath = fullfile(cfg.weightsDirectory, 'OrchTensorWeights.mat');
    bundle = assembleBundle(cfg, tensors, weights, prior, validation);
    save(matPath, 'bundle', '-v7');

    h5Path = fullfile(cfg.weightsDirectory, 'OrchTensorWeights.h5');
    [h5Exported, h5Message] = writeWeightH5(h5Path, tensors, weights);

    csvPath = fullfile(cfg.weightsDirectory, ...
        'SymbolCalibrationWeights.csv');
    writematrix(weights.symbolCalibration, csvPath);

    manifestPaths = writeManifests(cfg, bundle, imageIndex, ...
        h5Exported, h5Message, startTime);

    results = struct;
    results.outputRoot = cfg.outputRoot;
    results.weightsMAT = matPath;
    results.weightsH5 = h5Path;
    results.h5Exported = h5Exported;
    results.imageCount = numel(imageIndex);
    results.weightCount = numel(fieldnames(weights));
    results.validation = validation;
    results.manifests = manifestPaths;
    results.elapsedSeconds = toc(startTime);

    fprintf('\nRUN COMPLETE\n');
    fprintf('Images organized : %d\n', results.imageCount);
    fprintf('Weight arrays     : %d\n', results.weightCount);
    fprintf('H5 weights export : %s\n', string(h5Exported));
    fprintf('Output folder     : %s\n', cfg.outputRoot);
    fprintf('Elapsed           : %.3f s\n', results.elapsedSeconds);
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
cfg.version = 'YEHOSHUA_orch_tensor_weight_extraction_v1';
cfg.subject = 'image_learning';
cfg.h5File = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.systemJSON = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15/' ...
    'This is a quantization of knowledge.json'];
cfg.v1Directory = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'YEHOSHUA_particle_visual_sequence_from_SSOT_v1_output'];
cfg.v2Directory = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'YEHOSHUA_structural_pattern_image_learning_v2_output'];
cfg.v3Directory = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'YEHOSHUA_abstract_physical_symbol_calibration_v3_output'];
cfg.v2StateJSON = fullfile(cfg.v2Directory, ...
    'YEHOSHUA_notebook_system_state.json');
cfg.v3StateJSON = fullfile(cfg.v3Directory, ...
    'YEHOSHUA_abstract_symbol_calibration_state.json');

cfg.outputRoot = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15/' ...
    'YEHOSHUA_Orch_tensor_training_bundle_v1'];
cfg.imagesDirectory = fullfile(cfg.outputRoot, 'images');
cfg.particleImages = fullfile(cfg.imagesDirectory, 'particles');
cfg.structuralImages = fullfile(cfg.imagesDirectory, 'structures');
cfg.symbolImages = fullfile(cfg.imagesDirectory, 'symbols');
cfg.tensorImages = fullfile(cfg.imagesDirectory, 'tensors');
cfg.weightsDirectory = fullfile(cfg.outputRoot, 'weights');
cfg.manifestsDirectory = fullfile(cfg.outputRoot, 'manifests');

cfg.compositePath = '/n_5_composite_field_1000x1000/data';
cfg.fieldPaths = { ...
    '/n_6_field_maps_v3_800x800/chamber_field/data'
    '/n_6_field_maps_v3_800x800/fuchsian_tiling/data'
    '/n_6_field_maps_v3_800x800/ginibre_field/data'
    '/n_6_field_maps_v3_800x800/modular_eta/data'
    '/n_6_field_maps_v3_800x800/weyl_field/data'};
cfg.geodesicVelocityPath = '/n_4_geodesic_field/vel';
cfg.geodesicCurlPath = '/n_4_geodesic_field/curl';
cfg.defectPositionPath = '/n_3_defect_topology/pos';
cfg.defectChargePath = '/n_3_defect_topology/charge';
cfg.latticeModesPath = '/n_2_e8_lattice/laplacian_modes/modes';
cfg.phaseStopsPath = '/spectral_mappings/phase_stops';
cfg.chamberAnglesPath = ...
    '/n_7_apollonian_circle_model/e8_chamber_angles';
end


function validateInputs(cfg)
assert(isfile(cfg.h5File), 'Canonical H5 file was not found.');
assert(strcmpi(sha256File(cfg.h5File), cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
assert(isfile(cfg.systemJSON), 'System JSON was not found.');
assert(isfile(cfg.v2StateJSON), 'v2 system-state JSON was not found.');
assert(isfile(cfg.v3StateJSON), 'v3 calibration-state JSON was not found.');

systemState = jsondecode(fileread(cfg.systemJSON));
requiredLayers = { ...
    'layer_06_biomolecular_quantum_module'
    'layer_07_formal_microtubule_module'
    'layer_08_decoherence'
    'layer_09_biomolecular_neural_coupling'
    'layer_10_discrete_event_map'
    'layer_14_biomolecular_to_knowledge_channel'
    'layer_15_phase_synchronization'
    'layer_16_information_integration'
    'layer_17_temporal_integration_window'
    'layer_18_symbol_calibration'
    'layer_20_notebook_as_dynamic_state'};
for i = 1:numel(requiredLayers)
    assert(isfield(systemState, requiredLayers{i}), ...
        'Required system layer is missing: %s', requiredLayers{i});
end
end


function createOutputFolders(cfg)
mkdir(cfg.outputRoot);
mkdir(cfg.imagesDirectory);
mkdir(cfg.particleImages);
mkdir(cfg.structuralImages);
mkdir(cfg.symbolImages);
mkdir(cfg.tensorImages);
mkdir(cfg.weightsDirectory);
mkdir(cfg.manifestsDirectory);
end


function prior = readPriorState(cfg)
v2 = jsondecode(fileread(cfg.v2StateJSON));
v3 = jsondecode(fileread(cfg.v3StateJSON));
assert(strcmp(v2.subject, 'image_learning') && ~v2.rendered_text, ...
    'v2 state is not a text-free image-learning state.');
assert(strcmp(v3.subject, 'image_learning') && ~v3.rendered_text, ...
    'v3 state is not a text-free image-learning state.');
assert(v2.node_count == 12 && v2.relation_count == 16, ...
    'v2 structural state is incomplete.');
assert(v3.family_count == 10 && v3.primitive_count == 8, ...
    'v3 symbol calibration is incomplete.');

prior = struct;
prior.v2 = v2;
prior.v3 = v3;
prior.incidence = double(v3.incidence);
prior.familyNames = cellstr(string(v3.family_names));
prior.primitiveNames = cellstr(string(v3.primitive_names));
prior.quality = zeros(10, 1);
for i = 1:10
    preservation = double(v3.metrics(i).source_preservation);
    coupling = double(v3.metrics(i).mean_field_coupling);
    prior.quality(i) = clampScalar(0.70 .* preservation + ...
        0.30 .* coupling, 0, 1);
end
end


function tensors = extractCompactTensors(cfg)
fprintf('[1/4] Extracting compact canonical tensors\n');

compositeRaw = single(h5read(cfg.h5File, cfg.compositePath));
compositeStack = decodeFlatChannels(compositeRaw, 1000, 1000);
tensors.composite = zeros(50, 50, size(compositeStack, 3), 'single');
for c = 1:size(compositeStack, 3)
    tensors.composite(:, :, c) = single(imresize( ...
        compositeStack(:, :, c), [50 50], 'bilinear'));
end
clear compositeRaw compositeStack;

tensors.fieldMaps = zeros(40, 40, numel(cfg.fieldPaths), 'single');
for i = 1:numel(cfg.fieldPaths)
    raw = single(h5read(cfg.h5File, cfg.fieldPaths{i}));
    stack = decodeFlatChannels(raw, 800, 800);
    reduced = mean(stack, 3, 'omitnan');
    tensors.fieldMaps(:, :, i) = single(imresize( ...
        reduced, [40 40], 'bilinear'));
    clear raw stack reduced;
end

velocity = single(h5read(cfg.h5File, cfg.geodesicVelocityPath));
velocity = orientChannelsFirst(velocity, 2);
curlField = single(h5read(cfg.h5File, cfg.geodesicCurlPath));
velocityStack = decodeFlatChannels(velocity, 220, 220);
curlMap = reshape(curlField(:), 220, 220);
tensors.geodesic = zeros(55, 55, 3, 'single');
tensors.geodesic(:, :, 1) = single(imresize( ...
    velocityStack(:, :, 1), [55 55], 'bilinear'));
tensors.geodesic(:, :, 2) = single(imresize( ...
    velocityStack(:, :, 2), [55 55], 'bilinear'));
tensors.geodesic(:, :, 3) = single(imresize( ...
    curlMap, [55 55], 'bilinear'));

positions = double(h5read(cfg.h5File, cfg.defectPositionPath));
positions = orientChannelsFirst(positions, 2);
charges = double(h5read(cfg.h5File, cfg.defectChargePath));
tensors.defectDensity = buildDefectDensity(positions, charges, 16);

modes = double(h5read(cfg.h5File, cfg.latticeModesPath));
modes = orientChannelsFirst(modes, 12);
tensors.latticeModes = single(modes);
tensors.phaseStops = double(h5read(cfg.h5File, cfg.phaseStopsPath));
tensors.chamberAngles = double(h5read(cfg.h5File, ...
    cfg.chamberAnglesPath));

tensors.training = buildTrainingTensor(tensors);
assert(allFiniteStruct(tensors), 'Extracted tensors contain non-finite data.');
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


function training = buildTrainingTensor(tensors)
training = zeros(16, 16, 8, 'single');
compositeMean = mean(tensors.composite, 3, 'omitnan');
compositeStd = std(tensors.composite, 0, 3, 'omitnan');
fieldMean = mean(tensors.fieldMaps, 3, 'omitnan');
fieldStd = std(tensors.fieldMaps, 0, 3, 'omitnan');
speed = hypot(tensors.geodesic(:, :, 1), tensors.geodesic(:, :, 2));
curlMagnitude = abs(tensors.geodesic(:, :, 3));
modeEnergy = abs(tensors.latticeModes(1:min(8, ...
    size(tensors.latticeModes, 1)), :)).';

channels = {compositeMean, compositeStd, fieldMean, fieldStd, ...
    speed, curlMagnitude, tensors.defectDensity, modeEnergy};
for i = 1:8
    channel = normalize01(channels{i});
    training(:, :, i) = single(imresize(channel, [16 16], 'bilinear'));
end
end


function weights = buildTrainingWeights(tensors, prior)
fprintf('[2/4] Building normalized weight arrays\n');
d = 16;
baseMap = mean(tensors.training, 3);
basis = double(mean(baseMap, 2));
basis = 0.05 + 0.95 .* normalizeVector(basis(:));
amplitude = sqrt(basis);
amplitude = amplitude ./ norm(amplitude);

rho = amplitude * amplitude.' + 0.04 .* diag(basis);
rho = real((rho + rho.') ./ 2);
rho = rho ./ trace(rho);

energyLevels = linspace(-1, 1, d).' .* (0.55 + basis);
localEnergy = diag(energyLevels);

phaseSeed = buildPhaseSeed(tensors, d);
[ii, jj] = ndgrid(1:d, 1:d);
distance = abs(ii - jj);
transition = exp(-distance ./ 3.2) .* ...
    cos(phaseSeed - phaseSeed.') .* ...
    (0.25 + abs(basis - basis.'));
transition(1:d+1:end) = 0;
transition = normalizeSymmetric(transition, 0.85);

stateVector = 2 .* basis - 1;
stateCoupling = exp(-distance ./ 4.5) .* ...
    (stateVector * stateVector.');
stateCoupling(1:d+1:end) = 0;
stateCoupling = normalizeSymmetric(stateCoupling, 0.85);

phaseCoupling = exp(-distance ./ 4.0) .* ...
    cos(phaseSeed - phaseSeed.');
phaseCoupling(1:d+1:end) = 0;
phaseCoupling = normalizeSymmetric(phaseCoupling, 0.90);

modeProjection = abs(tensors.latticeModes(1:8, :)).';
primitiveProjection = imresize(modeProjection, [d 8], 'bilinear');
primitiveProjection = normalizeColumns(primitiveProjection);

biomolecularNeural = primitiveProjection * prior.incidence.';
biomolecularNeural = normalizeColumns(biomolecularNeural);
knowledgeChannel = prior.incidence * primitiveProjection.';
knowledgeChannel = normalizeRows(knowledgeChannel);

decayRates = 0.02 + 0.18 .* (1 - normalizeVector(basis));
tau = 3.5 + 4.5 .* mean(prior.quality);
temporalKernel = exp(-(0:d-1).' ./ tau);
temporalKernel = temporalKernel ./ sum(temporalKernel);

symbolCalibration = diag(prior.quality) * prior.incidence;
symbolCalibration = normalizeRows(symbolCalibration);
notebookState = symbolCalibration * symbolCalibration.';
notebookState(1:11:end) = 0;
notebookState = normalizeRows(notebookState);

integrationWeights = [mean(basis); mean(abs(transition(:))); ...
    mean(abs(stateCoupling(:))); mean(abs(phaseCoupling(:))); ...
    mean(prior.quality)];
integrationWeights = integrationWeights ./ sum(integrationWeights);

weights = struct;
weights.densityState = rho;
weights.localEnergy = localEnergy;
weights.transitionCoupling = transition;
weights.stateCoupling = stateCoupling;
weights.decayRates = decayRates;
weights.biomolecularNeural = biomolecularNeural;
weights.knowledgeChannel = knowledgeChannel;
weights.phaseCoupling = phaseCoupling;
weights.temporalKernel = temporalKernel;
weights.symbolCalibration = symbolCalibration;
weights.notebookState = notebookState;
weights.integrationWeights = integrationWeights;
end


function phase = buildPhaseSeed(tensors, d)
seed = [tensors.phaseStops(:); tensors.chamberAngles(:)];
seed = seed(isfinite(seed));
if isempty(seed)
    seed = linspace(0, 2 .* pi, d).';
end
x = linspace(1, numel(seed), d);
phase = interp1(1:numel(seed), double(seed), x, 'linear').';
phase = 2 .* pi .* normalizeVector(phase);
end


function validation = validateWeights(tensors, weights, prior)
fprintf('[3/4] Validating dimensions and normalization\n');
assert(isequal(size(tensors.training), [16 16 8]), ...
    'Training tensor must be 16 x 16 x 8.');
assert(isequal(size(weights.densityState), [16 16]), ...
    'Density-state weight must be 16 x 16.');
assert(isequal(size(weights.biomolecularNeural), [16 10]), ...
    'Biomolecular-neural weight must be 16 x 10.');
assert(isequal(size(weights.knowledgeChannel), [10 16]), ...
    'Knowledge-channel weight must be 10 x 16.');
assert(isequal(size(weights.symbolCalibration), [10 8]), ...
    'Symbol-calibration weight must be 10 x 8.');
assert(rank(prior.incidence) == 8, ...
    'Prior symbol incidence must have full column rank.');
assert(allFiniteStruct(weights), 'Weight arrays contain non-finite data.');

rhoSymmetry = norm(weights.densityState - weights.densityState.', 'fro');
rhoTrace = trace(weights.densityState);
rhoMinEigenvalue = min(real(eig(weights.densityState)));
temporalSum = sum(weights.temporalKernel);
integrationSum = sum(weights.integrationWeights);
assert(rhoSymmetry < 1e-10, 'Density-state matrix is not symmetric.');
assert(abs(rhoTrace - 1) < 1e-10, ...
    'Density-state trace is not normalized.');
assert(rhoMinEigenvalue > -1e-10, ...
    'Density-state matrix contains a negative eigenvalue.');
assert(abs(temporalSum - 1) < 1e-10, ...
    'Temporal kernel is not normalized.');
assert(abs(integrationSum - 1) < 1e-10, ...
    'Integration weights are not normalized.');

validation = struct;
validation.training_shape = size(tensors.training);
validation.density_trace = rhoTrace;
validation.density_min_eigenvalue = rhoMinEigenvalue;
validation.density_symmetry_error = rhoSymmetry;
validation.temporal_kernel_sum = temporalSum;
validation.integration_weight_sum = integrationSum;
validation.symbol_dictionary_rank = rank(prior.incidence);
validation.all_finite = true;
end


function index = organizePriorImages(cfg)
fprintf('[4/4] Organizing prior and current image representations\n');
index = repmat(emptyImageIndex(), 0, 1);

particleSources = { ...
    '01_photon.png', '02_electron.png', '03_neutrino.png', ...
    '04_quarks.png', '05_gluon.png', '06_proton.png', ...
    '07_neutron.png', '08_weak_bosons_WZ.png', ...
    '09_higgs_boson.png', '10_nucleus.png'};
particleNames = { ...
    'Photon.png', 'Electron.png', 'Neutrino.png', 'Quarks.png', ...
    'Gluon.png', 'Proton.png', 'Neutron.png', 'WeakBosons.png', ...
    'HiggsBoson.png', 'Nucleus.png'};
index = [index; copyImageSet(cfg.v1Directory, cfg.particleImages, ...
    particleSources, particleNames, 'particle')]; %#ok<AGROW>

structuralSources = { ...
    'state_01.png', 'state_02.png', 'state_03.png', 'state_04.png', ...
    'state_05.png', 'state_06.png', 'state_07.png', 'state_08.png', ...
    'state_09.png', 'state_10.png', 'state_11.png', 'state_12.png', ...
    'YEHOSHUA_structural_field_coupling.png', ...
    'YEHOSHUA_structural_role_map.png'};
structuralNames = { ...
    'Anchor.png', 'BoundaryOpening.png', 'PrimaryUnit.png', ...
    'PrimaryRelation.png', 'CoupledUnit.png', 'BoundaryClosure.png', ...
    'Transition.png', 'TransformedUnit.png', 'SecondaryRelation.png', ...
    'ResultingUnit.png', 'State.png', 'Closure.png', ...
    'StructuralFieldCoupling.png', 'StructuralRoleMap.png'};
index = [index; copyImageSet(cfg.v2Directory, cfg.structuralImages, ...
    structuralSources, structuralNames, 'structure')]; %#ok<AGROW>

symbolSources = { ...
    'calibration_01_localized_presence.png', ...
    'calibration_02_directed_quantity.png', ...
    'calibration_03_continuous_field.png', ...
    'calibration_04_bounded_domain.png', ...
    'calibration_05_interaction_coupling.png', ...
    'calibration_06_transformation_mapping.png', ...
    'calibration_07_superposed_paths.png', ...
    'calibration_08_balanced_pair.png', ...
    'calibration_09_temporal_samples.png', ...
    'calibration_10_composite_system.png', ...
    'YEHOSHUA_abstract_symbol_dictionary.png'};
symbolNames = { ...
    'LocalizedPresence.png', 'DirectedQuantity.png', ...
    'ContinuousField.png', 'BoundedDomain.png', ...
    'InteractionCoupling.png', 'TransformationMapping.png', ...
    'SuperposedPaths.png', 'BalancedPair.png', ...
    'TemporalSamples.png', 'CompositeSystem.png', ...
    'SymbolDictionary.png'};
index = [index; copyImageSet(cfg.v3Directory, cfg.symbolImages, ...
    symbolSources, symbolNames, 'symbol')]; %#ok<AGROW>
end


function index = copyImageSet(sourceDirectory, destinationDirectory, ...
    sourceNames, destinationNames, category)
assert(numel(sourceNames) == numel(destinationNames), ...
    'Image source and destination lists do not match.');
index = repmat(emptyImageIndex(), numel(sourceNames), 1);
for i = 1:numel(sourceNames)
    sourcePath = fullfile(sourceDirectory, sourceNames{i});
    destinationPath = fullfile(destinationDirectory, destinationNames{i});
    assert(isfile(sourcePath), 'Required image is missing: %s', sourcePath);
    [copied, message] = copyfile(sourcePath, destinationPath);
    assert(copied, 'Could not organize image: %s', message);
    index(i).representation = erase(destinationNames{i}, '.png');
    index(i).category = category;
    index(i).file = destinationPath;
    index(i).source = sourcePath;
end
end


function index = renderWeightImages(cfg, weights)
names = { ...
    'DensityState', 'LocalEnergy', 'TransitionCoupling', ...
    'StateCoupling', 'PhaseCoupling', 'KnowledgeChannel'};
matrices = { ...
    weights.densityState, weights.localEnergy, ...
    weights.transitionCoupling, weights.stateCoupling, ...
    weights.phaseCoupling, weights.knowledgeChannel};
index = repmat(emptyImageIndex(), numel(names), 1);
for i = 1:numel(names)
    outputPath = fullfile(cfg.tensorImages, [names{i} '.png']);
    rgb = matrixToRGB(matrices{i}, 512);
    imwrite(rgb, outputPath);
    index(i).representation = names{i};
    index(i).category = 'tensor';
    index(i).file = outputPath;
    index(i).source = 'derived_from_canonical_h5';
end
end


function rgb = matrixToRGB(matrix, outputSize)
x = double(matrix);
scale = max(abs(x(:)));
if scale <= eps
    normalized = zeros(size(x));
else
    normalized = x ./ scale;
end
positive = max(normalized, 0);
negative = max(-normalized, 0);
magnitude = abs(normalized);
rgb = cat(3, ...
    0.04 + 0.92 .* positive + 0.22 .* magnitude, ...
    0.05 + 0.78 .* magnitude, ...
    0.07 + 0.92 .* negative + 0.30 .* magnitude);
rgb = uint8(round(255 .* min(max(rgb, 0), 1)));
rgb = imresize(rgb, [outputSize outputSize], 'nearest');
end


function bundle = assembleBundle(cfg, tensors, weights, prior, validation)
bundle = struct;
bundle.version = cfg.version;
bundle.subject = cfg.subject;
bundle.rendered_text = false;
bundle.formal_mapping = true;
bundle.canonical_h5 = cfg.h5File;
bundle.canonical_sha256 = cfg.expectedSHA256;
bundle.system_json = cfg.systemJSON;
bundle.formal_layers_used = [6 7 8 9 10 14 15 16 17 18 20];
bundle.basis_units = 4;
bundle.basis_dimension = 16;
bundle.family_count = 10;
bundle.primitive_count = 8;
bundle.tensors = tensors;
bundle.weights = weights;
bundle.family_names = prior.familyNames;
bundle.primitive_names = prior.primitiveNames;
bundle.validation = validation;
bundle.generated_at = char(datetime('now', ...
    'TimeZone', 'Asia/Jerusalem', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
end


function [exported, message] = writeWeightH5(filePath, tensors, weights)
exported = false;
message = '';
try
    writeH5Dataset(filePath, '/tensors/composite', tensors.composite);
    writeH5Dataset(filePath, '/tensors/field_maps', tensors.fieldMaps);
    writeH5Dataset(filePath, '/tensors/geodesic', tensors.geodesic);
    writeH5Dataset(filePath, '/tensors/defect_density', ...
        tensors.defectDensity);
    writeH5Dataset(filePath, '/tensors/training', tensors.training);
    names = fieldnames(weights);
    for i = 1:numel(names)
        writeH5Dataset(filePath, ['/weights/' names{i}], ...
            weights.(names{i}));
    end
    exported = true;
    message = 'complete';
catch h5Error
    if isfile(filePath)
        delete(filePath);
    end
    message = h5Error.message;
    warning('H5 weight export skipped: %s', h5Error.message);
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


function paths = writeManifests(cfg, bundle, imageIndex, ...
    h5Exported, h5Message, startTime)
paths = struct;
paths.indexJSON = fullfile(cfg.manifestsDirectory, 'TensorIndex.json');
paths.shapesCSV = fullfile(cfg.manifestsDirectory, 'TensorShapes.csv');
paths.summaryTXT = fullfile(cfg.manifestsDirectory, 'RunSummary.txt');

index = struct;
index.version = bundle.version;
index.subject = bundle.subject;
index.rendered_text = false;
index.canonical_h5 = bundle.canonical_h5;
index.canonical_sha256 = bundle.canonical_sha256;
index.system_json = bundle.system_json;
index.basis_units = bundle.basis_units;
index.basis_dimension = bundle.basis_dimension;
index.formal_layers_used = bundle.formal_layers_used;
index.images = imageIndex;
index.tensor_names = fieldnames(bundle.tensors);
index.weight_names = fieldnames(bundle.weights);
index.validation = bundle.validation;
index.h5_exported = h5Exported;
index.h5_message = h5Message;
writeText(paths.indexJSON, jsonencode(index, PrettyPrint=true));

rows = buildShapeRows(bundle.tensors, bundle.weights);
writecell(rows, paths.shapesCSV);

lines = { ...
    'YEHOSHUA ORCH TENSOR WEIGHT EXTRACTION V1'
    'subject=image_learning'
    'rendered_text=false'
    'formal_mapping=true'
    sprintf('canonical_sha256=%s', cfg.expectedSHA256)
    sprintf('basis_dimension=%d', bundle.basis_dimension)
    sprintf('training_tensor_shape=%s', ...
        mat2str(size(bundle.tensors.training)))
    sprintf('image_count=%d', numel(imageIndex))
    sprintf('weight_array_count=%d', ...
        numel(fieldnames(bundle.weights)))
    sprintf('density_trace=%.12f', ...
        bundle.validation.density_trace)
    sprintf('density_min_eigenvalue=%.12g', ...
        bundle.validation.density_min_eigenvalue)
    sprintf('temporal_kernel_sum=%.12f', ...
        bundle.validation.temporal_kernel_sum)
    sprintf('integration_weight_sum=%.12f', ...
        bundle.validation.integration_weight_sum)
    sprintf('symbol_dictionary_rank=%d', ...
        bundle.validation.symbol_dictionary_rank)
    sprintf('h5_exported=%s', string(h5Exported))
    sprintf('elapsed_seconds=%.6f', toc(startTime))};
writeText(paths.summaryTXT, strjoin(lines, newline));
end


function rows = buildShapeRows(tensors, weights)
rows = {'category', 'name', 'dimensions', 'element_count'};
tensorNames = fieldnames(tensors);
for i = 1:numel(tensorNames)
    value = tensors.(tensorNames{i});
    rows(end + 1, :) = {'tensor', tensorNames{i}, ... %#ok<AGROW>
        mat2str(size(value)), numel(value)};
end
weightNames = fieldnames(weights);
for i = 1:numel(weightNames)
    value = weights.(weightNames{i});
    rows(end + 1, :) = {'weight', weightNames{i}, ... %#ok<AGROW>
        mat2str(size(value)), numel(value)};
end
end


function writeText(filePath, content)
fileID = fopen(filePath, 'w');
assert(fileID > 0, 'Could not create text file: %s', filePath);
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, '%s', content);
clear cleanup;
end


function output = normalizeSymmetric(input, targetRadius)
output = double((input + input.') ./ 2);
radius = max(abs(eig(output)));
if radius > eps
    output = targetRadius .* output ./ radius;
end
end


function output = normalizeColumns(input)
output = double(input);
denominator = sum(abs(output), 1);
denominator(denominator <= eps) = 1;
output = output ./ denominator;
end


function output = normalizeRows(input)
output = double(input);
denominator = sum(abs(output), 2);
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
    if isnumeric(value) && ~all(isfinite(value(:)))
        valid = false;
        return;
    end
end
end


function value = clampScalar(value, lower, upper)
value = min(max(value, lower), upper);
end


function entry = emptyImageIndex()
entry = struct('representation', '', 'category', '', ...
    'file', '', 'source', '');
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
