function results = YEHOSHUA_quantum_mechanics_tensor_training_v1()
% YEHOSHUA_quantum_mechanics_tensor_training_v1
% Builds a separate quantum-mechanics image-learning bundle from the
% canonical H5 and the previously organized discrete training tensors.

cfg = configuration();
startTime = tic;
validateInputs(cfg);
assert(~isfolder(cfg.outputRoot), ...
    'Quantum output folder already exists; no files were changed.');

try
    createOutputFolders(cfg);
    fprintf('\n%s\n', repmat('=', 1, 72));
    fprintf('YEHOSHUA QUANTUM MECHANICS TENSOR TRAINING V1\n');
    fprintf('%s\n', repmat('=', 1, 72));
    fprintf('canonical H5 : %s\n', cfg.canonicalH5);
    fprintf('prior bundle : %s\n', cfg.priorBundle);
    fprintf('quantum output: %s\n\n', cfg.outputRoot);

    prior = readPriorBundle(cfg);
    tensors = buildQuantumTensors(cfg, prior);
    weights = buildQuantumWeights(tensors, prior);
    validation = validateQuantumBundle(tensors, weights);
    images = renderQuantumImages(cfg, tensors, weights);

    bundle = assembleBundle(cfg, tensors, weights, validation, images);
    matPath = fullfile(cfg.weightsDirectory, 'QuantumTensorWeights.mat');
    save(matPath, 'bundle', '-v7');

    h5Path = fullfile(cfg.weightsDirectory, 'QuantumTensorWeights.h5');
    [h5Exported, h5Message] = writeQuantumH5( ...
        h5Path, tensors, weights);
    csvPath = fullfile(cfg.weightsDirectory, ...
        'QuantumMeasurementWeights.csv');
    writematrix(weights.measurementKernel, csvPath);

    manifests = writeManifests(cfg, bundle, h5Exported, ...
        h5Message, startTime);

    results = struct;
    results.outputRoot = cfg.outputRoot;
    results.images = images;
    results.imageCount = numel(images);
    results.tensorCount = numel(fieldnames(tensors));
    results.weightCount = numel(fieldnames(weights));
    results.weightsMAT = matPath;
    results.weightsH5 = h5Path;
    results.h5Exported = h5Exported;
    results.validation = validation;
    results.manifests = manifests;
    results.elapsedSeconds = toc(startTime);

    fprintf('\nRUN COMPLETE\n');
    fprintf('Quantum images  : %d\n', results.imageCount);
    fprintf('Quantum tensors : %d\n', results.tensorCount);
    fprintf('Weight arrays   : %d\n', results.weightCount);
    fprintf('H5 export       : %s\n', string(h5Exported));
    fprintf('Output folder   : %s\n', cfg.outputRoot);
    fprintf('Elapsed         : %.3f s\n', results.elapsedSeconds);
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
cfg.version = 'YEHOSHUA_quantum_mechanics_tensor_training_v1';
cfg.subject = 'image_learning';
cfg.domain = 'quantum_mechanics';
cfg.canonicalH5 = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.basePath = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15'];
cfg.priorBundle = fullfile(cfg.basePath, ...
    'YEHOSHUA_Orch_tensor_training_bundle_v1');
cfg.priorH5 = fullfile(cfg.priorBundle, 'weights', ...
    'OrchTensorWeights.h5');
cfg.priorManifest = fullfile(cfg.priorBundle, 'manifests', ...
    'TensorIndex.json');
cfg.integrationDraft = fullfile(cfg.priorBundle, 'manifests', ...
    ['This_is_a_quantization_of_knowledge_' ...
    'shared_visual_calibration_draft_v1.json']);
cfg.outputRoot = fullfile(cfg.basePath, ...
    'YEHOSHUA_quantum_mechanics_tensor_training_bundle_v1');
cfg.imagesDirectory = fullfile(cfg.outputRoot, 'images');
cfg.stateImages = fullfile(cfg.imagesDirectory, 'states');
cfg.processImages = fullfile(cfg.imagesDirectory, 'processes');
cfg.operatorImages = fullfile(cfg.imagesDirectory, 'operators');
cfg.tensorsDirectory = fullfile(cfg.outputRoot, 'tensors');
cfg.weightsDirectory = fullfile(cfg.outputRoot, 'weights');
cfg.manifestsDirectory = fullfile(cfg.outputRoot, 'manifests');
cfg.spatialSize = 64;
cfg.basisDimension = 16;
cfg.snapshotCount = 8;
cfg.symbolCount = 10;
cfg.outputImageSize = 512;
end


function validateInputs(cfg)
assert(isfile(cfg.canonicalH5), 'Canonical H5 was not found.');
assert(strcmpi(sha256File(cfg.canonicalH5), cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
assert(isfile(cfg.priorH5), 'Prior tensor H5 was not found.');
assert(isfile(cfg.priorManifest), 'Prior tensor manifest was not found.');
assert(isfile(cfg.integrationDraft), ...
    'Shared visual calibration draft was not found.');

priorManifest = jsondecode(fileread(cfg.priorManifest));
assert(strcmp(priorManifest.subject, 'image_learning'), ...
    'Prior bundle is not an image-learning bundle.');
assert(~priorManifest.rendered_text, ...
    'Prior bundle must remain free of rendered text.');
assert(priorManifest.basis_dimension == cfg.basisDimension, ...
    'Prior basis dimension does not match the quantum design.');

draft = jsondecode(fileread(cfg.integrationDraft));
assert(isfield(draft, 'layer_18A_shared_visual_field') && ...
    isfield(draft, 'layer_18B_human_agent_symbol_calibration'), ...
    'Shared visual calibration layers are incomplete.');
end


function createOutputFolders(cfg)
mkdir(cfg.outputRoot);
mkdir(cfg.imagesDirectory);
mkdir(cfg.stateImages);
mkdir(cfg.processImages);
mkdir(cfg.operatorImages);
mkdir(cfg.tensorsDirectory);
mkdir(cfg.weightsDirectory);
mkdir(cfg.manifestsDirectory);
end


function prior = readPriorBundle(cfg)
fprintf('[1/5] Reading the organized discrete training bundle\n');
prior = struct;
prior.training = double(h5read(cfg.priorH5, '/tensors/training'));
prior.densityState = double(h5read( ...
    cfg.priorH5, '/weights/densityState'));
prior.localEnergy = double(h5read( ...
    cfg.priorH5, '/weights/localEnergy'));
prior.transitionCoupling = double(h5read( ...
    cfg.priorH5, '/weights/transitionCoupling'));
prior.stateCoupling = double(h5read( ...
    cfg.priorH5, '/weights/stateCoupling'));
prior.phaseCoupling = double(h5read( ...
    cfg.priorH5, '/weights/phaseCoupling'));
prior.knowledgeChannel = double(h5read( ...
    cfg.priorH5, '/weights/knowledgeChannel'));
prior.temporalKernel = double(h5read( ...
    cfg.priorH5, '/weights/temporalKernel'));
prior.symbolCalibration = double(h5read( ...
    cfg.priorH5, '/weights/symbolCalibration'));
prior.phaseStops = double(h5read( ...
    cfg.canonicalH5, '/spectral_mappings/phase_stops'));
prior.chamberAngles = double(h5read( ...
    cfg.canonicalH5, ...
    '/n_7_apollonian_circle_model/e8_chamber_angles'));

assert(isequal(size(prior.training), [16 16 8]), ...
    'Prior training tensor must be 16 x 16 x 8.');
assert(isequal(size(prior.knowledgeChannel), [10 16]), ...
    'Prior knowledge channel must be 10 x 16.');
assert(allFiniteStruct(prior), 'Prior tensors contain non-finite values.');
end


function tensors = buildQuantumTensors(cfg, prior)
fprintf('[2/5] Building quantum-mechanics tensors\n');
n = cfg.spatialSize;
s = cfg.snapshotCount;
[x, y] = meshgrid(linspace(-1, 1, n));
sourceField = normalize01(imresize(mean(prior.training, 3), ...
    [n n], 'bicubic'));
phaseSeed = buildPhaseSeed(prior, s);

waveFunction = complex(zeros(n, n, s, 'single'));
superposition = complex(zeros(n, n, s, 'single'));
packetAStack = complex(zeros(n, n, s, 'single'));
packetBStack = complex(zeros(n, n, s, 'single'));

for k = 1:s
    progress = (k - 1) ./ max(s - 1, 1);
    centerX = -0.52 + 1.04 .* progress;
    centerY = 0.18 .* sin(2 .* pi .* progress);
    sigma = 0.16 + 0.035 .* cos(pi .* progress) .^ 2;
    momentumX = 5.0 + 1.2 .* cos(2 .* pi .* progress);
    momentumY = 1.4 .* sin(2 .* pi .* progress);

    packetA = exp(-((x - centerX) .^ 2 + ...
        (y - centerY) .^ 2) ./ (2 .* sigma .^ 2)) .* ...
        exp(1i .* (momentumX .* x + momentumY .* y));
    packetB = exp(-((x + centerX) .^ 2 + ...
        (y + centerY) .^ 2) ./ (2 .* sigma .^ 2)) .* ...
        exp(-1i .* (momentumX .* x - momentumY .* y));
    packetA = normalizeWaveFunction(packetA);
    packetB = normalizeWaveFunction(packetB);
    relativePhase = phaseSeed(k);
    psiSuperposed = packetA + exp(1i .* relativePhase) .* packetB;
    psiSuperposed = normalizeWaveFunction(psiSuperposed);
    modulation = 0.62 + 0.38 .* sourceField;
    psi = normalizeWaveFunction(psiSuperposed .* modulation);

    packetAStack(:, :, k) = single(packetA);
    packetBStack(:, :, k) = single(packetB);
    superposition(:, :, k) = single(psiSuperposed);
    waveFunction(:, :, k) = single(psi);
end

probabilityDensity = single(abs(waveFunction) .^ 2);
phaseField = single(angle(waveFunction));
for k = 1:s
    probabilityDensity(:, :, k) = probabilityDensity(:, :, k) ./ ...
        sum(probabilityDensity(:, :, k), 'all');
end

mid = ceil(s ./ 2);
interferenceEnvelope = exp(-0.5 .* ((x ./ 0.62) .^ 2 + ...
    (y ./ 0.38) .^ 2));
interferenceA = interferenceEnvelope .* ...
    exp(1i .* (9.0 .* x + 8.5 .* y));
interferenceB = interferenceEnvelope .* ...
    exp(1i .* (9.0 .* x - 8.5 .* y + phaseSeed(mid)));
interferenceA = normalizeWaveFunction(interferenceA);
interferenceB = normalizeWaveFunction(interferenceB);
interferenceSuperposed = normalizeWaveFunction( ...
    interferenceA + interferenceB);
probabilityA = abs(interferenceA) .^ 2;
probabilityB = abs(interferenceB) .^ 2;
probabilitySuperposed = abs(interferenceSuperposed) .^ 2;
crossTerm = 2 .* real(interferenceA .* conj(interferenceB));
interference = single(cat(3, probabilityA, probabilityB, ...
    probabilitySuperposed, crossTerm));

incident = abs(packetAStack(:, :, mid)) .^ 2;
barrier = single(abs(x) <= 0.13);
attenuation = exp(-5.5 .* max(x + 0.13, 0)) .* (x > -0.13) + ...
    single(x <= -0.13);
attenuation(x > 0.13) = exp(-5.5 .* 0.26);
transmittedWave = packetAStack(:, :, mid) .* attenuation;
transmitted = abs(transmittedWave) .^ 2;
tunneling = single(cat(3, incident, barrier, transmitted, ...
    normalize01(transmitted + 0.25 .* barrier)));

[hamiltonian, initialState, unitaryEvolution, densityMatrices, ...
    decoherence, discreteStates] = buildDiscreteEvolution(prior, cfg);
entanglement = buildEntanglementTensor(prior);
measurementKernel = normalizeColumnsPositive(abs(prior.knowledgeChannel).');
measurementKernel = measurementKernel.';
measurementProbabilities = measurementKernel * ...
    (abs(discreteStates) .^ 2);
measurementProbabilities = normalizeColumnsPositive( ...
    measurementProbabilities);
blochVectors = buildBlochVectors(discreteStates);

tensors = struct;
tensors.waveFunction = waveFunction;
tensors.probabilityDensity = probabilityDensity;
tensors.phaseField = phaseField;
tensors.superposition = superposition;
tensors.interference = interference;
tensors.tunneling = tunneling;
tensors.entanglement = entanglement;
tensors.unitaryEvolution = unitaryEvolution;
tensors.densityMatrices = densityMatrices;
tensors.decoherence = decoherence;
tensors.discreteStates = discreteStates;
tensors.measurementProbabilities = measurementProbabilities;
tensors.blochVectors = blochVectors;
tensors.hamiltonianReference = hamiltonian;
tensors.initialStateReference = initialState;
assert(allFiniteStruct(tensors), ...
    'Quantum tensors contain non-finite values.');
end


function phase = buildPhaseSeed(prior, count)
seed = [prior.phaseStops(:); prior.chamberAngles(:)];
seed = seed(isfinite(seed));
if isscalar(seed)
    phase = repmat(seed, count, 1);
else
    phase = interp1(1:numel(seed), seed, ...
        linspace(1, numel(seed), count), 'linear').';
end
phase = 2 .* pi .* normalizeVector(phase);
end


function psi = normalizeWaveFunction(psi)
normalizer = sqrt(sum(abs(psi) .^ 2, 'all'));
assert(normalizer > eps, 'Wave function has zero magnitude.');
psi = psi ./ normalizer;
end


function [hamiltonian, initialState, unitaryEvolution, ...
    densityMatrices, decoherence, discreteStates] = ...
    buildDiscreteEvolution(prior, cfg)
d = cfg.basisDimension;
s = cfg.snapshotCount;
hamiltonian = prior.localEnergy + ...
    0.48 .* prior.transitionCoupling + ...
    0.30 .* prior.stateCoupling + ...
    0.22 .* prior.phaseCoupling;
hamiltonian = real((hamiltonian + hamiltonian') ./ 2);
radius = max(abs(eig(hamiltonian)));
if radius > eps
    hamiltonian = hamiltonian ./ radius;
end

diagonal = max(real(diag(prior.densityState)), 0);
initialState = sqrt(diagonal + eps);
phase = 2 .* pi .* normalizeVector(mean(prior.training, [1 2]));
phase = imresize(reshape(phase, [], 1), [d 1], 'bilinear');
initialState = initialState .* exp(1i .* phase);
initialState = initialState ./ norm(initialState);

unitaryEvolution = complex(zeros(d, d, s));
densityMatrices = complex(zeros(d, d, s));
decoherence = complex(zeros(d, d, s));
discreteStates = complex(zeros(d, s));
times = linspace(0, 1, s);
for k = 1:s
    unitary = expm(-1i .* hamiltonian .* times(k));
    state = unitary * initialState;
    state = state ./ norm(state);
    rho = state * state';
    decay = exp(-times(k) ./ 0.60);
    rhoDiagonal = diag(diag(rho));
    rhoDecohered = rhoDiagonal + decay .* (rho - rhoDiagonal);
    rhoDecohered = rhoDecohered ./ trace(rhoDecohered);
    unitaryEvolution(:, :, k) = unitary;
    densityMatrices(:, :, k) = rho;
    decoherence(:, :, k) = rhoDecohered;
    discreteStates(:, k) = state;
end
end


function entanglement = buildEntanglementTensor(prior)
schmidt = max(real(diag(prior.densityState(1:4, 1:4))), eps);
schmidt = schmidt ./ sum(schmidt);
phase = 2 .* pi .* normalizeVector(prior.phaseCoupling(1:4, 1));
indices = 0:3;
fourier = exp(2i .* pi .* (indices.' * indices) ./ 4) ./ 2;
amplitude = fourier * ...
    diag(sqrt(schmidt) .* exp(1i .* phase)) * fourier.';
state = amplitude(:);
state = state ./ norm(state);
rho = state * state';
reducedA = amplitude * amplitude';
reducedB = amplitude' * amplitude;
productReference = kron(reducedA, reducedB);
correlation = rho - productReference;
entanglement = single(cat(3, abs(rho), angle(rho), ...
    abs(productReference), abs(correlation)));
end


function bloch = buildBlochVectors(states)
snapshotCount = size(states, 2);
bloch = zeros(3, snapshotCount);
for k = 1:snapshotCount
    pair = states(1:2, k);
    pairNorm = norm(pair);
    if pairNorm <= eps
        continue;
    end
    pair = pair ./ pairNorm;
    a = pair(1);
    b = pair(2);
    bloch(:, k) = [2 .* real(conj(a) .* b); ...
        2 .* imag(conj(a) .* b); abs(a) .^ 2 - abs(b) .^ 2];
end
end


function weights = buildQuantumWeights(tensors, prior)
fprintf('[3/5] Building quantum training weights\n');
d = size(tensors.hamiltonianReference, 1);
symbolCount = size(prior.knowledgeChannel, 1);
measurementKernel = abs(prior.knowledgeChannel);
measurementKernel = normalizeRowsPositive(measurementKernel);
projectors = complex(zeros(d, d, symbolCount));
for j = 1:symbolCount
    vector = measurementKernel(j, :).';
    vector = vector ./ max(norm(vector), eps);
    projectors(:, :, j) = vector * vector';
end

temporalKernel = exp(-(0:size(tensors.discreteStates, 2)-1).' ./ 3);
temporalKernel = temporalKernel ./ sum(temporalKernel);
schmidtWeights = max(real(diag( ...
    prior.densityState(1:4, 1:4))), eps);
schmidtWeights = schmidtWeights ./ sum(schmidtWeights);

classicalChannels = squeeze(mean(mean(prior.training, 1), 2));
quantumChannels = [ ...
    squeeze(mean(mean(tensors.probabilityDensity, 1), 2)); ...
    mean(abs(tensors.blochVectors), 1).'];
sourceCoupling = classicalChannels(:) * quantumChannels(:).';
sourceCoupling = sourceCoupling ./ max(norm(sourceCoupling, 'fro'), eps);

weights = struct;
weights.hamiltonian = tensors.hamiltonianReference;
weights.initialState = tensors.initialStateReference;
weights.measurementKernel = measurementKernel;
weights.projectors = projectors;
weights.temporalKernel = temporalKernel;
weights.schmidtWeights = schmidtWeights;
weights.sourceCoupling = sourceCoupling;
end


function validation = validateQuantumBundle(tensors, weights)
fprintf('[4/5] Validating quantum tensor constraints\n');
snapshotCount = size(tensors.waveFunction, 3);
waveNorms = zeros(snapshotCount, 1);
probabilitySums = zeros(snapshotCount, 1);
unitaryErrors = zeros(snapshotCount, 1);
densityTraces = zeros(snapshotCount, 1);
densityHermitianErrors = zeros(snapshotCount, 1);
decoherenceMinEigenvalues = zeros(snapshotCount, 1);
for k = 1:snapshotCount
    psi = tensors.waveFunction(:, :, k);
    waveNorms(k) = sum(abs(psi) .^ 2, 'all');
    probabilitySums(k) = sum( ...
        tensors.probabilityDensity(:, :, k), 'all');
    unitary = tensors.unitaryEvolution(:, :, k);
    unitaryErrors(k) = norm(unitary' * unitary - ...
        eye(size(unitary)), 'fro');
    rho = tensors.densityMatrices(:, :, k);
    densityTraces(k) = real(trace(rho));
    densityHermitianErrors(k) = norm(rho - rho', 'fro');
    rhoD = tensors.decoherence(:, :, k);
    decoherenceMinEigenvalues(k) = min(real(eig((rhoD + rhoD') ./ 2)));
end

measurementSums = sum(tensors.measurementProbabilities, 1);
blochNorms = sqrt(sum(tensors.blochVectors .^ 2, 1));
hamiltonianError = norm(weights.hamiltonian - weights.hamiltonian', 'fro');
projectorErrors = zeros(size(weights.projectors, 3), 1);
for j = 1:size(weights.projectors, 3)
    projector = weights.projectors(:, :, j);
    projectorErrors(j) = norm(projector * projector - projector, 'fro');
end

assert(max(abs(waveNorms - 1)) < 2e-6, ...
    'Wave-function normalization failed.');
assert(max(abs(probabilitySums - 1)) < 2e-6, ...
    'Probability-density normalization failed.');
assert(max(unitaryErrors) < 1e-10, ...
    'Unitary evolution validation failed.');
assert(max(abs(densityTraces - 1)) < 1e-10, ...
    'Density-matrix trace validation failed.');
assert(max(densityHermitianErrors) < 1e-10, ...
    'Density-matrix Hermitian validation failed.');
assert(min(decoherenceMinEigenvalues) > -1e-10, ...
    'Decoherence tensor contains a negative eigenvalue.');
assert(max(abs(measurementSums - 1)) < 1e-10, ...
    'Measurement distributions are not normalized.');
assert(max(blochNorms) <= 1 + 1e-10, ...
    'Bloch-vector norm exceeds one.');
assert(hamiltonianError < 1e-10, ...
    'Hamiltonian is not Hermitian.');
assert(max(projectorErrors) < 1e-10, ...
    'Measurement projector validation failed.');
assert(abs(sum(weights.temporalKernel) - 1) < 1e-10, ...
    'Temporal kernel is not normalized.');
assert(allFiniteStruct(tensors) && allFiniteStruct(weights), ...
    'Quantum bundle contains non-finite values.');

validation = struct;
validation.wave_norm_max_error = max(abs(waveNorms - 1));
validation.probability_sum_max_error = ...
    max(abs(probabilitySums - 1));
validation.unitary_max_error = max(unitaryErrors);
validation.density_trace_max_error = ...
    max(abs(densityTraces - 1));
validation.density_hermitian_max_error = ...
    max(densityHermitianErrors);
validation.decoherence_min_eigenvalue = ...
    min(decoherenceMinEigenvalues);
validation.measurement_sum_max_error = ...
    max(abs(measurementSums - 1));
validation.bloch_norm_max = max(blochNorms);
validation.hamiltonian_hermitian_error = hamiltonianError;
validation.projector_max_error = max(projectorErrors);
validation.temporal_kernel_sum = sum(weights.temporalKernel);
validation.all_finite = true;
end


function images = renderQuantumImages(cfg, tensors, ~)
fprintf('[5/5] Rendering quantum-mechanics representations\n');
images = repmat(emptyImageIndex(), 12, 1);
mid = ceil(size(tensors.waveFunction, 3) ./ 2);
last = size(tensors.waveFunction, 3);

definitions = { ...
    'WaveFunctionAmplitude', cfg.stateImages, ...
        complexToRGB(tensors.waveFunction(:, :, mid));
    'ProbabilityDensity', cfg.stateImages, ...
        scalarToRGB(mean(tensors.probabilityDensity, 3), false);
    'PhaseField', cfg.stateImages, ...
        phaseToRGB(tensors.phaseField(:, :, mid), ...
        abs(tensors.waveFunction(:, :, mid)));
    'Superposition', cfg.stateImages, ...
        complexToRGB(tensors.superposition(:, :, mid));
    'Interference', cfg.processImages, ...
        scalarToRGB(tensors.interference(:, :, 4), true);
    'Tunneling', cfg.processImages, ...
        tunnelingToRGB(tensors.tunneling);
    'Entanglement', cfg.stateImages, ...
        scalarToRGB(tensors.entanglement(:, :, 4), false);
    'UnitaryEvolution', cfg.operatorImages, ...
        complexToRGB(tensors.unitaryEvolution(:, :, last));
    'DensityMatrix', cfg.operatorImages, ...
        complexToRGB(tensors.densityMatrices(:, :, last));
    'MeasurementTransition', cfg.processImages, ...
        scalarToRGB(tensors.measurementProbabilities, false);
    'Decoherence', cfg.processImages, ...
        complexToRGB(tensors.decoherence(:, :, last));
    'BlochState', cfg.stateImages, ...
        renderBlochImage(tensors.blochVectors, cfg.outputImageSize)};

for i = 1:size(definitions, 1)
    name = definitions{i, 1};
    directory = definitions{i, 2};
    rgb = definitions{i, 3};
    if ~isequal(size(rgb, 1), cfg.outputImageSize) || ...
            ~isequal(size(rgb, 2), cfg.outputImageSize)
        rgb = imresize(rgb, [cfg.outputImageSize cfg.outputImageSize], ...
            'nearest');
    end
    outputPath = fullfile(directory, [name '.png']);
    imwrite(rgb, outputPath);
    images(i).representation = name;
    images(i).file = outputPath;
    images(i).rendered_text = false;
end
end


function rgb = complexToRGB(value)
magnitude = normalize01(abs(value));
phase = mod(angle(value) + pi, 2 .* pi) ./ (2 .* pi);
hsvImage = cat(3, phase, 0.42 + 0.58 .* magnitude, ...
    0.05 + 0.95 .* sqrt(magnitude));
rgb = im2uint8(hsv2rgb(hsvImage));
end


function rgb = phaseToRGB(phase, magnitude)
hue = mod(double(phase) + pi, 2 .* pi) ./ (2 .* pi);
magnitude = normalize01(magnitude);
hsvImage = cat(3, hue, 0.86 .* ones(size(hue)), ...
    0.08 + 0.92 .* magnitude);
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
    rgb = cat(3, 0.04 + 0.92 .* positive + 0.20 .* magnitude, ...
        0.04 + 0.70 .* magnitude, ...
        0.07 + 0.92 .* negative + 0.24 .* magnitude);
else
    normalized = normalize01(value);
    rgb = cat(3, 0.03 + 0.90 .* normalized .^ 1.4, ...
        0.04 + 0.78 .* sqrt(normalized), ...
        0.10 + 0.88 .* (1 - exp(-3 .* normalized)));
end
rgb = im2uint8(min(max(rgb, 0), 1));
end


function rgb = tunnelingToRGB(tensor)
incident = normalize01(tensor(:, :, 1));
barrier = normalize01(tensor(:, :, 2));
transmitted = normalize01(tensor(:, :, 3));
rgb = cat(3, 0.06 + 0.90 .* incident, ...
    0.04 + 0.72 .* transmitted + 0.18 .* barrier, ...
    0.10 + 0.82 .* transmitted + 0.40 .* barrier);
rgb = im2uint8(min(max(rgb, 0), 1));
end


function rgb = renderBlochImage(vectors, outputSize)
[x, y] = meshgrid(1:outputSize, 1:outputSize);
center = (outputSize + 1) ./ 2;
radius = 0.36 .* outputSize;
radialDistance = abs(hypot(x - center, y - center) - radius);
circle = exp(-0.5 .* (radialDistance ./ 1.4) .^ 2);
axisHorizontal = exp(-0.5 .* ((y - center) ./ 1.2) .^ 2) .* ...
    (abs(x - center) <= radius);
axisVertical = exp(-0.5 .* ((x - center) ./ 1.2) .^ 2) .* ...
    (abs(y - center) <= radius);
base = 0.12 .* circle + 0.06 .* axisHorizontal + 0.06 .* axisVertical;
rgb = repmat(base, 1, 1, 3);
for k = 1:size(vectors, 2)
    endpointX = center + radius .* vectors(1, k);
    endpointY = center - radius .* vectors(3, k);
    lineDistance = pointToSegmentDistance(x, y, center, center, ...
        endpointX, endpointY);
    lineMask = exp(-0.5 .* (lineDistance ./ 1.6) .^ 2);
    pointMask = exp(-0.5 .* (((x - endpointX) .^ 2 + ...
        (y - endpointY) .^ 2) ./ 12));
    phase = (k - 1) ./ max(size(vectors, 2) - 1, 1);
    color = hsv2rgb([phase, 0.78, 1]);
    for channel = 1:3
        rgb(:, :, channel) = rgb(:, :, channel) + ...
            color(channel) .* (0.42 .* lineMask + 0.90 .* pointMask);
    end
end
rgb = im2uint8(min(max(rgb, 0), 1));
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


function bundle = assembleBundle(cfg, tensors, weights, validation, images)
bundle = struct;
bundle.version = cfg.version;
bundle.subject = cfg.subject;
bundle.domain = cfg.domain;
bundle.separate_from_classical_physics = true;
bundle.rendered_text = false;
bundle.canonical_h5 = cfg.canonicalH5;
bundle.canonical_sha256 = cfg.expectedSHA256;
bundle.prior_bundle = cfg.priorBundle;
bundle.integration_draft = cfg.integrationDraft;
bundle.spatial_size = cfg.spatialSize;
bundle.basis_dimension = cfg.basisDimension;
bundle.snapshot_count = cfg.snapshotCount;
bundle.tensors = tensors;
bundle.weights = weights;
bundle.validation = validation;
bundle.images = images;
bundle.generated_at = char(datetime('now', ...
    'TimeZone', 'Asia/Jerusalem', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
end


function [exported, message] = writeQuantumH5(filePath, tensors, weights)
exported = false;
try
    tensorNames = fieldnames(tensors);
    for i = 1:numel(tensorNames)
        name = tensorNames{i};
        writeH5Value(filePath, ['/tensors/' name], tensors.(name));
    end
    weightNames = fieldnames(weights);
    for i = 1:numel(weightNames)
        name = weightNames{i};
        writeH5Value(filePath, ['/weights/' name], weights.(name));
    end
    exported = true;
    message = 'complete';
catch h5Error
    if isfile(filePath)
        delete(filePath);
    end
    message = h5Error.message;
    warning('Quantum H5 export skipped: %s', h5Error.message);
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
    'QuantumTensorIndex.json');
paths.shapesCSV = fullfile(cfg.manifestsDirectory, ...
    'QuantumTensorShapes.csv');
paths.summaryTXT = fullfile(cfg.manifestsDirectory, 'RunSummary.txt');

index = struct;
index.version = bundle.version;
index.subject = bundle.subject;
index.domain = bundle.domain;
index.separate_from_classical_physics = true;
index.rendered_text = false;
index.canonical_h5 = bundle.canonical_h5;
index.canonical_sha256 = bundle.canonical_sha256;
index.prior_bundle = bundle.prior_bundle;
index.integration_draft = bundle.integration_draft;
index.spatial_size = bundle.spatial_size;
index.basis_dimension = bundle.basis_dimension;
index.snapshot_count = bundle.snapshot_count;
index.tensor_names = fieldnames(bundle.tensors);
index.weight_names = fieldnames(bundle.weights);
index.images = bundle.images;
index.validation = bundle.validation;
index.h5_exported = h5Exported;
index.h5_message = h5Message;
writeText(paths.indexJSON, jsonencode(index, PrettyPrint=true));

rows = buildShapeRows(bundle.tensors, bundle.weights);
writecell(rows, paths.shapesCSV);

lines = { ...
    'YEHOSHUA QUANTUM MECHANICS TENSOR TRAINING V1'
    'subject=image_learning'
    'domain=quantum_mechanics'
    'separate_from_classical_physics=true'
    'rendered_text=false'
    sprintf('canonical_sha256=%s', cfg.expectedSHA256)
    sprintf('spatial_size=%d', bundle.spatial_size)
    sprintf('basis_dimension=%d', bundle.basis_dimension)
    sprintf('snapshot_count=%d', bundle.snapshot_count)
    sprintf('image_count=%d', numel(bundle.images))
    sprintf('tensor_count=%d', numel(fieldnames(bundle.tensors)))
    sprintf('weight_count=%d', numel(fieldnames(bundle.weights)))
    sprintf('wave_norm_max_error=%.12g', ...
        bundle.validation.wave_norm_max_error)
    sprintf('unitary_max_error=%.12g', ...
        bundle.validation.unitary_max_error)
    sprintf('density_trace_max_error=%.12g', ...
        bundle.validation.density_trace_max_error)
    sprintf('measurement_sum_max_error=%.12g', ...
        bundle.validation.measurement_sum_max_error)
    sprintf('h5_exported=%s', string(h5Exported))
    sprintf('elapsed_seconds=%.6f', toc(startTime))};
writeText(paths.summaryTXT, strjoin(lines, newline));
end


function rows = buildShapeRows(tensors, weights)
tensorNames = fieldnames(tensors);
weightNames = fieldnames(weights);
rows = cell(1 + numel(tensorNames) + numel(weightNames), 5);
rows(1, :) = {'category', 'name', 'dimensions', ...
    'element_count', 'complex'};
row = 2;
for i = 1:numel(tensorNames)
    value = tensors.(tensorNames{i});
    rows(row, :) = {'tensor', tensorNames{i}, ...
        mat2str(size(value)), numel(value), ~isreal(value)};
    row = row + 1;
end
for i = 1:numel(weightNames)
    value = weights.(weightNames{i});
    rows(row, :) = {'weight', weightNames{i}, ...
        mat2str(size(value)), numel(value), ~isreal(value)};
    row = row + 1;
end
end


function output = normalizeColumnsPositive(input)
output = max(double(input), 0);
denominator = sum(output, 1);
denominator(denominator <= eps) = 1;
output = output ./ denominator;
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
