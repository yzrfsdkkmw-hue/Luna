function result = YEHOSHUA_PLATO_PHASE_RECURRENCE_RECONSTRUCTION_v4()
% YEHOSHUA_PLATO_PHASE_RECURRENCE_RECONSTRUCTION_V4
% Multi-tensor phase recurrence and full-face visual reconstruction.
%
% The source H5 is read only. All derived artifacts are written to a new,
% timestamped output directory. The script emits nine visual candidates;
% it does not automatically select an appearance.

clc;
cfg = configuration();
rng(cfg.seed, 'twister');

runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
outputDirectory = fullfile(cfg.root, ...
    ['YEHOSHUA_PLATO_PHASE_RECURRENCE_RECONSTRUCTION_v4_' runStamp]);
mkdir(outputDirectory);

logFile = fullfile(outputDirectory, '10_run_log.txt');
logIdentifier = fopen(logFile, 'w');
assert(logIdentifier >= 0, 'Unable to open the run log.');
logCleanup = onCleanup(@() fclose(logIdentifier));

logLine(logIdentifier, 'Run started: %s', runStamp);
logLine(logIdentifier, 'Source: %s', cfg.sourceFile);

try
    %% 1. Source verification and shape-safe decode
    assert(isfile(cfg.sourceFile), 'Source H5 was not found.');
    actualHash = sha256File(cfg.sourceFile);
    assert(strcmpi(actualHash, cfg.expectedSHA256), ...
        'Source SHA-256 mismatch.');
    logLine(logIdentifier, 'SHA-256 matched.');

    raw = single(h5read(cfg.sourceFile, cfg.sourceDataset));
    sourceField = decodeSourceField(raw, cfg.sourceShape);
    sourceField = robustChannels01(sourceField);
    sourceComposite = weightedComposite(sourceField, cfg.channelWeights);
    sourceComposite = imresize(sourceComposite, cfg.workSize, 'bicubic');
    logLine(logIdentifier, 'Source decoded as %d x %d x %d.', ...
        size(sourceField, 1), size(sourceField, 2), size(sourceField, 3));

    %% 2. Existing phase, coherence, salience, and temporal tensors
    tensorData = loadTensorFamily(cfg, cfg.workSize, logIdentifier);

    %% 3. Multi-field recurrence search
    recurrence = findRecurrence(tensorData, cfg, logIdentifier);

    %% 4. Regularized backward phase reconstruction
    recovered = recoverPhaseState(sourceComposite, tensorData, ...
        recurrence.best_lag_samples, cfg);

    imwrite(phaseToRGB(recovered.phase, recovered.coherence), ...
        fullfile(outputDirectory, '02_phase_recovered.png'));
    imwrite(uint16(round(65535 * clamp01(recovered.coherence))), ...
        fullfile(outputDirectory, '03_phase_coherence.png'));

    %% 5. String/membrane-regularized full-face candidate ensemble
    candidateCount = cfg.candidateCount;
    ensemble = zeros([cfg.workSize 3 candidateCount], 'single');
    candidateFiles = strings(candidateCount, 1);
    candidateMetrics = repmat(struct(), candidateCount, 1);

    for candidateIndex = 1:candidateCount
        parameters = candidateParameters(candidateIndex, tensorData, ...
            recurrence, cfg);
        [rgb, faceMetrics] = renderFullFace(recovered, sourceComposite, ...
            parameters, cfg);
        rgb = membraneRegularize(rgb, faceMetrics.face_mask, ...
            cfg.membraneIterations, cfg.membraneStep);
        ensemble(:, :, :, candidateIndex) = single(clamp01(rgb));

        candidateName = sprintf('04_candidate_%02d.png', candidateIndex);
        candidateFiles(candidateIndex) = candidateName;
        imwrite(uint16(round(65535 * clamp01(rgb))), ...
            fullfile(outputDirectory, candidateName));

        candidateMetrics(candidateIndex).index = candidateIndex;
        candidateMetrics(candidateIndex).face_occupancy = ...
            faceMetrics.face_occupancy;
        candidateMetrics(candidateIndex).symmetry_score = ...
            faceMetrics.symmetry_score;
        candidateMetrics(candidateIndex).phase_texture_correlation = ...
            faceMetrics.phase_texture_correlation;
    end

    ensembleMean = mean(ensemble, 4);
    ensembleVariance = var(ensemble, 0, 4);
    uncertainty = robust01(mean(ensembleVariance, 3));
    candidateGrid = makeImageGrid(ensemble, 3, cfg.gridGap, cfg.backgroundColor);

    imwrite(uint16(round(65535 * clamp01(candidateGrid))), ...
        fullfile(outputDirectory, '05_candidate_grid.png'));
    imwrite(uint16(round(65535 * clamp01(ensembleMean))), ...
        fullfile(outputDirectory, '06_ensemble_mean.png'));
    imwrite(uint16(round(65535 * clamp01(uncertainty))), ...
        fullfile(outputDirectory, '07_uncertainty.png'));

    %% 6. Numeric artifacts and quality gates
    writetable(recurrence.scan, ...
        fullfile(outputDirectory, '01_recurrence_scan.csv'));

    diagnostics = struct();
    diagnostics.source_composite = single(sourceComposite);
    diagnostics.phase_recovered = single(recovered.phase);
    diagnostics.phase_coherence = single(recovered.coherence);
    diagnostics.phase_velocity = single(tensorData.phaseVelocity);
    diagnostics.salience = single(tensorData.salience);
    diagnostics.ensemble_mean = single(ensembleMean);
    diagnostics.ensemble_variance = single(ensembleVariance);
    diagnostics.uncertainty = single(uncertainty);
    diagnostics.recurrence = recurrence;
    save(fullfile(outputDirectory, '08_tensor_diagnostics.mat'), ...
        'diagnostics', '-v7.3');

    outputFinite = all(isfinite(ensemble(:))) && ...
        all(isfinite(recovered.phase(:))) && ...
        all(isfinite(recovered.coherence(:)));
    occupancyValues = [candidateMetrics.face_occupancy];
    symmetryValues = [candidateMetrics.symmetry_score];

    quality = struct();
    quality.hash_match = true;
    quality.source_shape_valid = isequal(size(sourceField), cfg.sourceShape);
    quality.output_finite = outputFinite;
    quality.recurrence_score_finite = ...
        isfinite(recurrence.best_combined_score);
    quality.recurrence_supported = recurrence.best_acf_score >= ...
        cfg.minimumACFScore;
    quality.full_face_occupancy = all(occupancyValues >= ...
        cfg.minimumFaceOccupancy);
    quality.candidate_count_valid = candidateCount == 9;
    quality.pass = all(cell2mat(struct2cell(quality)));

    metrics = struct();
    metrics.version = cfg.version;
    metrics.timestamp = runStamp;
    metrics.source_file = cfg.sourceFile;
    metrics.source_sha256 = actualHash;
    metrics.source_dataset = cfg.sourceDataset;
    metrics.source_shape = size(sourceField);
    metrics.best_lag_samples = recurrence.best_lag_samples;
    metrics.best_acf_score = recurrence.best_acf_score;
    metrics.best_phase_score = recurrence.best_phase_score;
    metrics.best_combined_score = recurrence.best_combined_score;
    metrics.timekernel_primary_period_samples = ...
        tensorData.primaryPeriodSamples;
    metrics.timekernel_mapped_frequency_hz = ...
        tensorData.mappedFrequencyHz;
    metrics.timekernel_phase_concentration = ...
        tensorData.phaseConcentration;
    metrics.candidate_count = candidateCount;
    metrics.mean_face_occupancy = mean(occupancyValues);
    metrics.mean_symmetry_score = mean(symmetryValues);
    metrics.mean_uncertainty = mean(uncertainty(:));
    metrics.quality = quality;
    metrics.appearance_selection = 'USER_CONTROLLED';
    writeJSON(fullfile(outputDirectory, '09_metrics.json'), metrics);

    manifest = struct();
    manifest.schema = 'YEHOSHUA_PLATO_PHASE_RECURRENCE_V4';
    manifest.timestamp = runStamp;
    manifest.output_directory = outputDirectory;
    manifest.source_file = cfg.sourceFile;
    manifest.source_sha256 = actualHash;
    manifest.source_dataset = cfg.sourceDataset;
    manifest.read_only_source = true;
    manifest.tensor_sources = tensorData.sources;
    manifest.candidate_files = cellstr(candidateFiles);
    manifest.files = { ...
        '00_run_manifest.json', '01_recurrence_scan.csv', ...
        '02_phase_recovered.png', '03_phase_coherence.png', ...
        '05_candidate_grid.png', '06_ensemble_mean.png', ...
        '07_uncertainty.png', '08_tensor_diagnostics.mat', ...
        '09_metrics.json', '10_run_log.txt'};
    manifest.quality_pass = quality.pass;
    manifest.best_lag_samples = recurrence.best_lag_samples;
    manifest.best_combined_score = recurrence.best_combined_score;
    writeJSON(fullfile(outputDirectory, '00_run_manifest.json'), manifest);

    logLine(logIdentifier, 'Best recurrence lag: %d samples.', ...
        recurrence.best_lag_samples);
    logLine(logIdentifier, 'Best recurrence score: %.8f.', ...
        recurrence.best_combined_score);
    logLine(logIdentifier, 'Quality pass: %d.', quality.pass);
    logLine(logIdentifier, 'Run completed: %s', outputDirectory);

    result = struct();
    result.output_directory = outputDirectory;
    result.best_lag_samples = recurrence.best_lag_samples;
    result.best_combined_score = recurrence.best_combined_score;
    result.quality_pass = quality.pass;
    result.metrics_file = fullfile(outputDirectory, '09_metrics.json');
    result.candidate_grid = fullfile(outputDirectory, '05_candidate_grid.png');
    result.ensemble_mean = fullfile(outputDirectory, '06_ensemble_mean.png');

    fprintf('\nYEHOSHUA V4 completed.\n');
    fprintf('Output: %s\n', outputDirectory);
    fprintf('Best recurrence lag: %d samples\n', ...
        recurrence.best_lag_samples);
    fprintf('Quality pass: %d\n', quality.pass);
catch executionError
    failure = struct();
    failure.status = 'RUN_FAILED';
    failure.identifier = executionError.identifier;
    failure.message = executionError.message;
    failure.timestamp = runStamp;
    writeJSON(fullfile(outputDirectory, 'RUN_FAILURE.json'), failure);
    logLine(logIdentifier, 'RUN FAILED: %s', executionError.message);
    rethrow(executionError);
end
end

%% Configuration
function cfg = configuration()
cfg.version = 'YEHOSHUA_PLATO_PHASE_RECURRENCE_RECONSTRUCTION_v4';
cfg.root = '/Users/yehoshua/MATLAB-Drive/modelTRAINING';
cfg.sourceFile = fullfile(cfg.root, ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5');
cfg.sourceDataset = '/n_5_composite_field_1000x1000/data';
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.sourceShape = [1000 1000 5];
cfg.channelWeights = [0.30 0.24 0.20 0.16 0.10];
cfg.workSize = [512 512];
cfg.seed = 271828;
cfg.candidateCount = 9;

cfg.discoveryDirectory = fullfile(cfg.root, 'YDV3_20260722_105428_369');
cfg.phaseMapFile = fullfile(cfg.discoveryDirectory, ...
    '06_complex_anchor_phase_maps.h5');
cfg.intrinsicFile = fullfile(cfg.discoveryDirectory, ...
    'intrinsic_field_family.h5');
cfg.timeKernelFile = fullfile(cfg.discoveryDirectory, ...
    'timekernel_autocorrelation.h5');
cfg.timeKernelCandidates = fullfile(cfg.discoveryDirectory, ...
    'timekernel_period_candidates.csv');
cfg.discoveryManifest = fullfile(cfg.discoveryDirectory, ...
    '19_run_manifest.json');

cfg.rawSalienceFile = fullfile(cfg.root, ...
    ['YEHOSHUA_RAW_SALIENCE_QOK_DISCOVERY_v1_output_' ...
    '20260722_111326_164'], ...
    'YEHOSHUA_RAW_SALIENCE_QOK_DISCOVERY_v1_tensors.h5');
cfg.gradientTensorFile = fullfile(cfg.root, ...
    'Yehoshua_System_Gradient_v4_tensors_20260717_040302_257.mat');

cfg.recurrenceRadiusFraction = 0.12;
cfg.recurrenceStep = 2;
cfg.phaseGridSize = [128 128];
cfg.minimumACFScore = 0.50;
cfg.minimumFaceOccupancy = 0.20;
cfg.phaseRegularization = 0.12;

cfg.membraneIterations = 4;
cfg.membraneStep = 0.055;
cfg.gridGap = 8;
cfg.backgroundColor = single([0.055 0.065 0.080]);
end

%% Source and tensor loading
function field = decodeSourceField(raw, expectedShape)
rawSize = size(raw);
if isequal(rawSize, expectedShape)
    field = raw;
elseif ismatrix(raw) && size(raw, 1) == expectedShape(3) && ...
        size(raw, 2) == expectedShape(1) * expectedShape(2)
    field = permute(reshape(raw, expectedShape(3), ...
        expectedShape(1), expectedShape(2)), [2 3 1]);
elseif numel(raw) == prod(expectedShape)
    field = permute(reshape(raw(:), expectedShape(3), ...
        expectedShape(1), expectedShape(2)), [2 3 1]);
else
    error('Unexpected source dataset shape.');
end
assert(all(isfinite(field(:))), 'Source field contains NaN or Inf.');
end

function data = loadTensorFamily(cfg, workSize, logIdentifier)
requiredFiles = {cfg.phaseMapFile, cfg.intrinsicFile, ...
    cfg.timeKernelFile, cfg.timeKernelCandidates, cfg.discoveryManifest};
for index = 1:numel(requiredFiles)
    assert(isfile(requiredFiles{index}), ...
        'Required tensor artifact not found: %s', requiredFiles{index});
end

phaseReal = single(h5read(cfg.phaseMapFile, '/phase/real'));
phaseImaginary = single(h5read(cfg.phaseMapFile, '/phase/imag'));
phaseCoherence = single(h5read(cfg.phaseMapFile, '/phase/coherence'));
phaseAmplitude = single(h5read(cfg.phaseMapFile, '/combined/amplitude'));

data.phase = imresize(angle(complex(phaseReal, phaseImaginary)), ...
    workSize, 'bilinear');
data.coherence = clamp01(imresize(phaseCoherence, workSize, 'bilinear'));
data.amplitude = robust01(imresize(phaseAmplitude, workSize, 'bilinear'));
data.intrinsicPhase = imresize(single(h5read(cfg.intrinsicFile, '/phase')), ...
    workSize, 'bilinear');
data.intrinsicCoherence = clamp01(imresize(single(h5read( ...
    cfg.intrinsicFile, '/coherence')), workSize, 'bilinear'));
data.salience = robust01(imresize(single(h5read( ...
    cfg.intrinsicFile, '/salience_base')), workSize, 'bilinear'));

data.rawPhase = zeros(workSize, 'single');
data.rawCoherence = zeros(workSize, 'single');
if isfile(cfg.rawSalienceFile)
    data.rawPhase = imresize(single(h5read(cfg.rawSalienceFile, ...
        '/phase/dominant')), workSize, 'bilinear');
    data.rawCoherence = clamp01(imresize(single(h5read( ...
        cfg.rawSalienceFile, '/phase/coherence')), workSize, 'bilinear'));
end

data.phaseVelocity = zeros(workSize, 'single');
if isfile(cfg.gradientTensorFile)
    gradientData = load(cfg.gradientTensorFile, 'tensors');
    if isfield(gradientData, 'tensors') && ...
            isfield(gradientData.tensors, 'photo') && ...
            isfield(gradientData.tensors.photo, 'temporal_phase_velocity')
        data.phaseVelocity = robust01(imresize(single( ...
            gradientData.tensors.photo.temporal_phase_velocity), ...
            workSize, 'bilinear'));
    end
    clear gradientData;
end

data.autocorrelation = double(h5read(cfg.timeKernelFile, ...
    '/autocorrelation'));
data.autocorrelation = data.autocorrelation(:);
periodTable = readtable(cfg.timeKernelCandidates);
data.periodTable = periodTable;
data.primaryPeriodSamples = round(periodTable.period_samples(1));

manifest = jsondecode(fileread(cfg.discoveryManifest));
data.mappedFrequencyHz = manifest.timekernel.dominant_frequency_hz;
data.phaseConcentration = manifest.timekernel.phase_concentration;
data.sources = {cfg.phaseMapFile, cfg.intrinsicFile, ...
    cfg.timeKernelFile, cfg.rawSalienceFile, cfg.gradientTensorFile};

logLine(logIdentifier, 'Tensor family loaded. Primary period: %d samples.', ...
    data.primaryPeriodSamples);
end

%% Recurrence and backward phase
function recurrence = findRecurrence(data, cfg, logIdentifier)
periods = round(data.periodTable.period_samples( ...
    1:min(3, height(data.periodTable))));
candidateLags = [];
for index = 1:numel(periods)
    radius = max(20, round(cfg.recurrenceRadiusFraction * periods(index)));
    candidateLags = [candidateLags, ...
        (periods(index) - radius):cfg.recurrenceStep: ...
        (periods(index) + radius)]; %#ok<AGROW>
end
candidateLags = unique(candidateLags(candidateLags > 0));
candidateLags = candidateLags(candidateLags < numel(data.autocorrelation));

velocitySmall = imresize(data.phaseVelocity, cfg.phaseGridSize, 'bilinear');
coherenceSmall = imresize(data.coherence .* ...
    (0.25 + 0.75 * data.intrinsicCoherence), ...
    cfg.phaseGridSize, 'bilinear');
coherenceSmall = max(single(1e-4), coherenceSmall);

primaryPeriod = double(data.primaryPeriodSamples);
localFrequency = (2 * pi / primaryPeriod) .* ...
    (0.85 + 0.30 * double(velocitySmall));
weights = double(coherenceSmall);
weightTotal = sum(weights(:)) + eps;
acfMaximum = max(max(data.autocorrelation(2:end)), eps);

acfScore = zeros(numel(candidateLags), 1);
phaseScore = zeros(numel(candidateLags), 1);
combinedScore = zeros(numel(candidateLags), 1);

for index = 1:numel(candidateLags)
    lag = candidateLags(index);
    acfScore(index) = max(0, data.autocorrelation(lag + 1)) / acfMaximum;
    phaseStep = exp(1i * localFrequency * lag);
    phaseScore(index) = abs(sum(weights(:) .* phaseStep(:))) / weightTotal;
    combinedScore(index) = 0.64 * acfScore(index) + ...
        0.36 * phaseScore(index);
end

[bestCombinedScore, bestIndex] = max(combinedScore);
scan = table(candidateLags(:), acfScore, phaseScore, combinedScore, ...
    'VariableNames', {'lag_samples', 'acf_score', ...
    'phase_score', 'combined_score'});
scan = sortrows(scan, 'combined_score', 'descend');

recurrence = struct();
recurrence.best_lag_samples = candidateLags(bestIndex);
recurrence.best_acf_score = acfScore(bestIndex);
recurrence.best_phase_score = phaseScore(bestIndex);
recurrence.best_combined_score = bestCombinedScore;
recurrence.scan = scan;

logLine(logIdentifier, ...
    'Recurrence scan completed: lag=%d, acf=%.6f, phase=%.6f.', ...
    recurrence.best_lag_samples, recurrence.best_acf_score, ...
    recurrence.best_phase_score);
end

function recovered = recoverPhaseState(sourceComposite, data, lag, cfg)
primaryPeriod = double(data.primaryPeriodSamples);
localFrequency = (2 * pi / primaryPeriod) .* ...
    (0.85 + 0.30 * double(data.phaseVelocity));
backwardPhase = wrapToPiLocal(double(data.phase) - localFrequency * lag);

weightA = 0.20 + 0.80 * double(data.coherence);
weightB = 0.15 + 0.55 * double(data.intrinsicCoherence);
weightC = 0.10 + 0.35 * double(data.rawCoherence);
complexState = weightA .* exp(1i * backwardPhase) + ...
    weightB .* exp(1i * double(data.intrinsicPhase)) + ...
    weightC .* exp(1i * double(data.rawPhase));

phase = angle(complexState);
coherence = abs(complexState) ./ (weightA + weightB + weightC + eps);
coherence = clamp01(imgaussfilt(coherence, 1.1));

sourceTexture = double(sourceComposite) - imgaussfilt(double(sourceComposite), 6);
phaseTexture = sin(phase) .* (0.20 + 0.80 * coherence);
texture = robustSigned(0.62 * sourceTexture + 0.24 * phaseTexture + ...
    0.14 * robustSigned(double(data.salience)));
texture = imgaussfilt(texture, cfg.phaseRegularization);

recovered = struct();
recovered.phase = single(phase);
recovered.coherence = single(coherence);
recovered.texture = single(texture);
recovered.salience = single(data.salience);
end

%% Visual reconstruction
function parameters = candidateParameters(index, data, recurrence, cfg)
row = floor((index - 1) / 3) - 1;
column = mod(index - 1, 3) - 1;
phaseSupport = mean(data.coherence(:));
salienceSupport = mean(data.salience(:));
recurrenceSupport = recurrence.best_combined_score;

parameters.faceWidth = 0.555 + 0.018 * column + ...
    0.010 * (phaseSupport - 0.5);
parameters.faceHeight = 0.765 + 0.014 * row;
parameters.jawTaper = 0.22 + 0.018 * row;
parameters.cheekWidth = 0.035 + 0.010 * column;
parameters.eyeSpacing = 0.205 + 0.008 * column;
parameters.eyeHeight = -0.155 + 0.006 * row;
parameters.noseLength = 0.285 + 0.012 * row;
parameters.mouthWidth = 0.265 + 0.010 * column;
parameters.beardStrength = 0.50 + 0.08 * row + ...
    0.08 * (salienceSupport - 0.5);
parameters.hairStrength = 0.58 + 0.07 * column;
parameters.ageTexture = 0.34 + 0.08 * recurrenceSupport;
parameters.lightAzimuth = -0.42 + 0.12 * column;
parameters.lightElevation = 0.72 + 0.06 * row;

skinPalette = [ ...
    0.72 0.50 0.37; 0.66 0.45 0.33; 0.76 0.56 0.43; ...
    0.69 0.48 0.35; 0.73 0.52 0.39; 0.64 0.43 0.32; ...
    0.77 0.57 0.45; 0.70 0.49 0.36; 0.67 0.46 0.34];
irisPalette = [ ...
    0.22 0.30 0.27; 0.24 0.18 0.12; 0.20 0.28 0.32; ...
    0.28 0.22 0.14; 0.18 0.25 0.22; 0.24 0.20 0.16; ...
    0.20 0.27 0.31; 0.26 0.21 0.14; 0.19 0.24 0.20];
parameters.skinColor = skinPalette(index, :);
parameters.irisColor = irisPalette(index, :);
parameters.hairColor = 0.10 + 0.06 * [1 0.88 0.75] + ...
    0.025 * (row + 1);
parameters.backgroundColor = cfg.backgroundColor;
end

function [rgb, metrics] = renderFullFace(recovered, sourceComposite, p, cfg)
height = cfg.workSize(1);
width = cfg.workSize(2);
[x, y] = meshgrid(linspace(-1, 1, width), ...
    linspace(-1, 1, height));

vertical = (y + 0.055) / p.faceHeight;
widthProfile = p.faceWidth .* (1 - p.jawTaper .* max(vertical, 0).^1.35);
widthProfile = widthProfile + p.cheekWidth .* ...
    exp(-((vertical - 0.08) / 0.30).^2);
faceMask = abs(x) <= widthProfile .* sqrt(max(0, 1 - vertical.^2));
earMask = ((abs(x) - p.faceWidth * 0.97) / 0.085).^2 + ...
    ((y + 0.02) / 0.19).^2 <= 1;
neckMask = y > 0.60 & abs(x) < (0.21 + 0.05 * (y - 0.60));
shoulderMask = ((x / 0.92).^2 + ((y - 1.02) / 0.42).^2) <= 1;

z = sqrt(max(0, 1 - (x ./ max(widthProfile, 0.08)).^2 - vertical.^2));
normalX = x ./ max(widthProfile.^2, 0.02);
normalY = vertical / max(p.faceHeight, 0.1);
normalZ = z;
normalNorm = sqrt(normalX.^2 + normalY.^2 + normalZ.^2) + eps;
normalX = normalX ./ normalNorm;
normalY = normalY ./ normalNorm;
normalZ = normalZ ./ normalNorm;

light = [p.lightAzimuth, -p.lightElevation, 1.0];
light = light / norm(light);
diffuse = max(0, normalX * light(1) + normalY * light(2) + normalZ * light(3));
shading = 0.47 + 0.47 * diffuse + 0.06 * z.^14;

texture = double(recovered.texture);
texture = texture .* (0.25 + 0.75 * double(recovered.coherence));
texture = texture + 0.22 * robustSigned(double(sourceComposite));
texture = imgaussfilt(texture, 0.55);

background = zeros(height, width, 3);
for channel = 1:3
    background(:, :, channel) = double(p.backgroundColor(channel)) .* ...
        (0.82 + 0.18 * (1 - (y + 1) / 2));
end
rgb = background;

skin = zeros(height, width, 3);
for channel = 1:3
    skin(:, :, channel) = p.skinColor(channel) .* shading .* ...
        (1 + 0.052 * texture * p.ageTexture);
end
skin = clamp01(skin);
rgb = alphaBlend(rgb, skin, imgaussfilt(single(faceMask | earMask), 0.8));

neckShade = 0.70 + 0.16 * (1 - abs(x) / 0.28);
neckColor = colorField(p.skinColor .* [0.80 0.78 0.76], neckShade);
rgb = alphaBlend(rgb, neckColor, imgaussfilt(single(neckMask), 1.4));

clothColor = [0.16 0.19 0.22] + 0.025 * mean(p.skinColor);
clothShade = 0.70 + 0.22 * (1 - y);
rgb = alphaBlend(rgb, colorField(clothColor, clothShade), ...
    imgaussfilt(single(shoulderMask), 1.2));

% Eyes, irises, pupils, and lids.
for side = [-1 1]
    eyeX = side * p.eyeSpacing;
    eyeShape = ((x - eyeX) / 0.125).^2 + ...
        ((y - p.eyeHeight) / 0.045).^2;
    eyeAlpha = clamp01(1.25 - eyeShape);
    sclera = colorField([0.86 0.84 0.80], 0.86 + 0.12 * z);
    rgb = alphaBlend(rgb, sclera, 0.86 * eyeAlpha .* faceMask);

    irisShape = ((x - eyeX) / 0.034).^2 + ...
        ((y - p.eyeHeight) / 0.038).^2;
    irisAlpha = clamp01(1.20 - irisShape);
    irisShade = 0.56 + 0.35 * robust01(cos(18 * atan2( ...
        y - p.eyeHeight, x - eyeX)));
    rgb = alphaBlend(rgb, colorField(p.irisColor, irisShade), ...
        irisAlpha .* faceMask);

    pupilShape = ((x - eyeX) / 0.014).^2 + ...
        ((y - p.eyeHeight) / 0.018).^2;
    rgb = alphaBlend(rgb, colorField([0.015 0.012 0.010], ones(height, width)), ...
        clamp01(1.25 - pupilShape) .* faceMask);

    highlight = exp(-((x - eyeX + 0.010) / 0.008).^2 - ...
        ((y - p.eyeHeight + 0.012) / 0.009).^2);
    rgb = alphaBlend(rgb, ones(height, width, 3), 0.62 * highlight .* faceMask);

    lid = exp(-((y - p.eyeHeight + 0.002) / 0.050).^2) .* ...
        exp(-((x - eyeX) / 0.145).^8);
    brow = exp(-((y - (p.eyeHeight - 0.105)) / 0.026).^2) .* ...
        exp(-((x - eyeX) / 0.155).^6);
    darkColor = colorField(p.hairColor, ones(height, width));
    rgb = alphaBlend(rgb, darkColor, 0.18 * lid .* faceMask);
    rgb = alphaBlend(rgb, darkColor, 0.52 * brow .* faceMask);
end

% Nose with a lit ridge, lateral shadows, and nostrils.
noseEnd = p.eyeHeight + p.noseLength;
noseSupport = exp(-(x / 0.11).^2) .* ...
    exp(-((y - (p.eyeHeight + 0.13)) / 0.25).^4);
noseLight = exp(-(x / 0.030).^2) .* ...
    exp(-((y - (p.eyeHeight + 0.12)) / 0.22).^4);
noseShadow = exp(-((x - 0.075) / 0.050).^2) .* ...
    exp(-((y - (p.eyeHeight + 0.12)) / 0.22).^4);
rgb = alphaBlend(rgb, ones(height, width, 3), ...
    0.10 * noseLight .* faceMask);
rgb = alphaBlend(rgb, zeros(height, width, 3), ...
    0.12 * noseShadow .* noseSupport .* faceMask);
for side = [-1 1]
    nostril = exp(-((x - side * 0.043) / 0.026).^2 - ...
        ((y - noseEnd) / 0.015).^2);
    rgb = alphaBlend(rgb, colorField([0.12 0.055 0.045], ones(height, width)), ...
        0.60 * nostril .* faceMask);
end

% Mouth and lips.
mouthY = 0.285;
mouthEnvelope = exp(-(x / p.mouthWidth).^8);
mouthLine = exp(-((y - mouthY - 0.012 * cos(pi * x / p.mouthWidth)) / 0.013).^2) .* ...
    mouthEnvelope;
upperLip = exp(-((y - (mouthY - 0.018)) / 0.025).^2) .* mouthEnvelope;
lowerLip = exp(-((y - (mouthY + 0.022)) / 0.030).^2) .* mouthEnvelope;
lipColor = colorField(p.skinColor .* [0.72 0.58 0.60], ones(height, width));
rgb = alphaBlend(rgb, lipColor, 0.30 * (upperLip + lowerLip) .* faceMask);
rgb = alphaBlend(rgb, colorField([0.11 0.045 0.040], ones(height, width)), ...
    0.55 * mouthLine .* faceMask);

% Hair and beard use phase texture as a subtle directional structure.
hairline = -0.52 + 0.035 * cos(3 * pi * x / max(p.faceWidth, 0.1));
hairMask = faceMask & y < hairline;
hairTexture = clamp01(0.42 + 0.34 * sin(42 * x + ...
    2.2 * double(recovered.phase)) + 0.24 * texture);
hairColor = colorField(p.hairColor, 0.48 + 0.30 * hairTexture);
rgb = alphaBlend(rgb, hairColor, ...
    p.hairStrength * imgaussfilt(single(hairMask), 0.7));

beardRegion = faceMask & y > 0.20 & ...
    (abs(x) > 0.08 + 0.22 * max(0, 0.48 - y) | y > 0.40);
beardTexture = clamp01(0.46 + 0.30 * sin(58 * y - 16 * x + ...
    1.7 * double(recovered.phase)) + 0.24 * texture);
beardColor = colorField(p.hairColor .* [0.88 0.90 0.94], ...
    0.50 + 0.30 * beardTexture);
rgb = alphaBlend(rgb, beardColor, ...
    p.beardStrength * 0.68 * imgaussfilt(single(beardRegion), 0.65));

% Fine tensor-driven skin relief kept below the identity geometry layer.
relief = robustSigned(sin(double(recovered.phase)) .* ...
    double(recovered.coherence) .* double(recovered.salience));
reliefRGB = cat(3, relief, relief, relief);
rgb = rgb + 0.018 * p.ageTexture * reliefRGB .* faceMask;
rgb = clamp01(rgb);

gray = rgb2gray(rgb);
grayMirror = fliplr(gray);
mirrorError = mean(abs(gray(faceMask) - grayMirror(faceMask)), 'all');
metrics = struct();
metrics.face_mask = faceMask;
metrics.face_occupancy = mean(faceMask(:));
metrics.symmetry_score = max(0, 1 - mirrorError);
metrics.phase_texture_correlation = safeCorrelation( ...
    gray(faceMask), sin(double(recovered.phase(faceMask))));
end

function rgb = membraneRegularize(rgb, mask, iterations, step)
mask3 = repmat(single(mask), 1, 1, 3);
original = single(rgb);
rgb = single(rgb);
for iteration = 1:iterations
    laplacian = zeros(size(rgb), 'single');
    for channel = 1:3
        laplacian(:, :, channel) = single(del2(double(rgb(:, :, channel))));
    end
    rgb = rgb + single(step) * laplacian .* mask3;
    rgb = 0.92 * rgb + 0.08 * original;
end
rgb = clamp01(rgb);
end

%% Output helpers
function grid = makeImageGrid(images, columns, gap, backgroundColor)
[height, width, channels, count] = size(images);
rows = ceil(count / columns);
gridHeight = rows * height + (rows + 1) * gap;
gridWidth = columns * width + (columns + 1) * gap;
grid = zeros(gridHeight, gridWidth, channels, 'single');
for channel = 1:channels
    grid(:, :, channel) = backgroundColor(channel);
end
for index = 1:count
    row = floor((index - 1) / columns);
    column = mod(index - 1, columns);
    rowRange = gap + row * (height + gap) + (1:height);
    columnRange = gap + column * (width + gap) + (1:width);
    grid(rowRange, columnRange, :) = images(:, :, :, index);
end
end

function rgb = phaseToRGB(phase, coherence)
hue = mod((double(phase) + pi) / (2 * pi), 1);
saturation = 0.35 + 0.65 * double(coherence);
value = 0.25 + 0.75 * robust01(double(coherence));
rgb = hsv2rgb(cat(3, hue, saturation, value));
rgb = uint16(round(65535 * clamp01(rgb)));
end

function field = colorField(color, intensity)
field = zeros([size(intensity) 3]);
for channel = 1:3
    field(:, :, channel) = color(channel) .* intensity;
end
field = clamp01(field);
end

function output = alphaBlend(background, foreground, alpha)
alpha = clamp01(double(alpha));
if ismatrix(alpha)
    alpha = repmat(alpha, 1, 1, 3);
end
output = double(background) .* (1 - alpha) + double(foreground) .* alpha;
end

function field = weightedComposite(sourceField, weights)
weights = weights(:) / sum(weights);
field = zeros(size(sourceField, 1), size(sourceField, 2), 'single');
for channel = 1:size(sourceField, 3)
    field = field + single(weights(channel)) * sourceField(:, :, channel);
end
field = robust01(field);
end

function field = robustChannels01(field)
for channel = 1:size(field, 3)
    field(:, :, channel) = robust01(field(:, :, channel));
end
end

function output = robust01(input)
input = double(input);
finiteValues = input(isfinite(input));
if isempty(finiteValues)
    output = zeros(size(input), 'single');
    return;
end
low = prctile(finiteValues, 1);
high = prctile(finiteValues, 99);
scale = max(high - low, max(1e-6, 1e-6 * max(abs(finiteValues))));
output = single(clamp01((input - low) / scale));
output(~isfinite(output)) = 0;
end

function output = robustSigned(input)
input = double(input);
finiteValues = input(isfinite(input));
if isempty(finiteValues)
    output = zeros(size(input));
    return;
end
center = median(finiteValues);
scale = 1.4826 * mad(finiteValues, 1);
scale = max(scale, max(1e-6, 1e-4 * iqr(finiteValues)));
output = (input - center) / scale;
output = max(-6, min(6, output)) / 6;
output(~isfinite(output)) = 0;
end

function output = clamp01(input)
output = min(max(input, 0), 1);
end

function phase = wrapToPiLocal(phase)
phase = mod(phase + pi, 2 * pi) - pi;
end

function correlation = safeCorrelation(a, b)
a = double(a(:));
b = double(b(:));
valid = isfinite(a) & isfinite(b);
a = a(valid);
b = b(valid);
if numel(a) < 3 || std(a) <= eps || std(b) <= eps
    correlation = 0;
else
    matrix = corrcoef(a, b);
    correlation = matrix(1, 2);
end
end

function hash = sha256File(filePath)
escapedPath = strrep(filePath, '"', '\"');
command = sprintf('/usr/bin/shasum -a 256 "%s"', escapedPath);
[status, output] = system(command);
assert(status == 0, 'Unable to compute SHA-256.');
tokens = regexp(strtrim(output), '^([0-9a-fA-F]{64})', 'tokens', 'once');
assert(~isempty(tokens), 'Unable to parse SHA-256 output.');
hash = lower(tokens{1});
end

function writeJSON(filePath, value)
identifier = fopen(filePath, 'w');
assert(identifier >= 0, 'Unable to open JSON output.');
cleanup = onCleanup(@() fclose(identifier));
encoded = jsonencode(value, 'PrettyPrint', true);
fprintf(identifier, '%s\n', encoded);
end

function logLine(identifier, formatString, varargin)
message = sprintf(formatString, varargin{:});
timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
fprintf(identifier, '[%s] %s\n', timestamp, message);
fprintf('[%s] %s\n', timestamp, message);
end
