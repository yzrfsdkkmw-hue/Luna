function [results, tensors] = Yehoshua_System_Gradient_integration_v4_temporal_living_tensor_export()
% Yehoshua&System_Gradient_integration
%
% Save this file exactly as:
%   Yehoshua_System_Gradient_integration_v4_temporal_living.m
%
% Canonical read-only input:
%   /MATLAB Drive/modelTRAINING/
%   jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%
% Canonical dataset:
%   /n_5_composite_field_1000x1000/data
%
% Output:
%   Exactly one PNG image per run.
%
% Revision v3 adds:
%   - bounded local-SNR adaptive gate weighting;
%   - online temporal variance/noise estimation across 192 steps;
%   - soft sparse coding on the final gate;
%   - precision-weighted local degree homeostasis;
%   - overload-adaptive spectral cutoff;
%   - adaptive A(t), normalized-Laplacian filtering, phase gating;
%   - structural plasticity x_i(t), attraction, repulsion, and radius control.
%
% The canonical H5 is never modified. No external PNG is used as input.
% No derived H5, MAT, CSV, JSON, figure, contact sheet, or exportgraphics
% artifact is created. The only written artifact is one PNG image.

    clc;
    format compact;
    rng(2511, 'twister');

    cfg = configuration();
    validateCanonicalSource(cfg);

    fprintf('\n============================================================\n');
    fprintf(' Yehoshua&System_Gradient_integration v4 temporal living\n');
    fprintf(' Deep temporal phase + coherent motion + 16-bit living render\n');
    fprintf(' Canonical H5 -> one integrated image\n');
    fprintf('============================================================\n\n');

    totalTimer = tic;

    %% 01. Canonical H5
    fprintf('[01/12] Reading canonical H5 dataset...\n');

    raw = h5read(cfg.sourceFile, cfg.datasetPath);
    cube = decodeCanonicalLayoutB(raw, cfg);
    clear raw;

    %% 02. Five-channel source integration
    fprintf('[02/12] Integrating five source channels...\n');

    [I0, channelWeights] = integrateFiveChannels(cube, cfg);
    clear cube;

    %% 03. Differential, multiscale, and spectral fields
    fprintf('[03/12] Differential, multiscale, and spectral computation...\n');

    base = computeDifferentialFields(I0, cfg);
    multiscale = computeMultiscaleFields(I0, cfg);
    spectral = computeSpectralFields(I0, cfg);

    %% 04. RGB and display operator
    fprintf('[04/12] Source RGB and Apple display operator...\n');

    I0_RGB = buildSourceRGB(I0, base, multiscale, spectral, cfg);
    IA_RGB = applyAppleDisplayOperator(I0_RGB, cfg);

    %% 05. Optical field and cone responses
    fprintf('[05/12] Optical field and L/M/S responses...\n');

    optical = computeOpticalConeFields(IA_RGB, cfg);

    %% 06. Phototransduction and retina
    fprintf('[06/12] Phototransduction, temporal statistics, and retina...\n');

    photo = simulatePhototransduction(optical.Q, cfg);
    retina = computeRetinalFields(optical.Q, photo, cfg);
    relay = computeRelayField(retina, cfg);

    %% 07. V1 complex bank
    fprintf('[07/12] V1 oriented complex bank...\n');

    v1 = computeV1ComplexBank(relay, retina, cfg);

    %% 08. Quantization field
    fprintf('[08/12] Phase winding and vortex-core field...\n');

    quant = computeQuantizationField(v1, base, cfg);

    %% 09. Gradient integration
    fprintf('[09/12] Yehoshua&System gradient integration...\n');

    gradientState = computeGradientIntegration( ...
        base, multiscale, spectral, optical, photo, ...
        retina, relay, v1, quant, cfg);

    %% 10. Precision gate with temporal-noise separation and sparse coding
    fprintf('[10/12] Local-SNR precision gate and soft sparse coding...\n');

    layers = buildUnifiedInformationLayers( ...
        I0_RGB, IA_RGB, I0, base, multiscale, spectral, ...
        optical, photo, retina, relay, v1, gradientState, cfg);

    qGate = computeQByteAdaptivePatternGate( ...
        layers, gradientState, v1, retina, photo, cfg);

    %% 11. Adaptive topology and structural plasticity
    fprintf('[11/12] Adaptive Laplacian and semantic geometry evolution...\n');

    network = evolveAdaptiveQByteNetwork( ...
        quant, I0, base, spectral, optical, photo, ...
        retina, relay, v1, qGate, cfg);

    finalRGB = composeSingleImage( ...
        I0_RGB, IA_RGB, base, optical, photo, v1, quant, ...
        gradientState, layers, qGate, network, cfg);

    %% 12. Exactly one image
    fprintf('[12/12] Writing one PNG image...\n');

    if ~exist(cfg.outputFolder, 'dir')
        mkdir(cfg.outputFolder);
    end

    runTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));

    outputFile = fullfile( ...
        cfg.outputFolder, ...
        ['Yehoshua&System_Gradient_integration_v4_temporal_living_' runTag '.png']);

    writeRGB16Temporal(finalRGB, outputFile, cfg);

    [tensors, tensorMatFile, tensorH5File] = ...
        exportTensorFiles( ...
        I0_RGB, IA_RGB, base, optical, photo, v1, quant, ...
        gradientState, layers, qGate, network, finalRGB, ...
        outputFile);

    if ~isfile(outputFile)
        error('The requested PNG output was not created.');
    end

    fileInfo = dir(outputFile);

    if isempty(fileInfo) || fileInfo.bytes <= 0
        error('The requested PNG output is empty.');
    end

    elapsed = toc(totalTimer);

    fprintf('\nCompleted in %.3f seconds.\n', elapsed);
    fprintf('One output image:\n%s\n\n', outputFile);

    results = struct();
    results.tensor_mat_file = tensorMatFile;
    results.tensor_h5_file = tensorH5File;
    results.version = cfg.version;
    results.name = cfg.gradientDisplayName;
    results.source_file = cfg.sourceFile;
    results.dataset_path = cfg.datasetPath;
    results.source_sha256 = cfg.expectedSHA256;
    results.output_image = outputFile;
    results.output_count = 1;
    results.channel_weights = channelWeights;
    results.number_of_vortex_cores = numel(quant.coresX);

    results.gradient_energy_mean = ...
        mean(gradientState.energy, 'all');

    results.gradient_projection_mean = ...
        mean(gradientState.projectionMagnitude, 'all');

    results.temporal_variance_mean = ...
        mean(photo.temporalVariance, 'all');

    results.temporal_phase_coherence_mean = ...
        mean(photo.temporalPhaseCoherence, 'all');

    results.temporal_phase_velocity_mean = ...
        mean(photo.temporalPhaseVelocity, 'all');

    results.temporal_noise_mean = ...
        mean(photo.temporalNoise, 'all');

    results.precision_mean = ...
        mean(qGate.precision, 'all');

    results.overload_mean = ...
        mean(qGate.overload, 'all');

    results.local_signal_confidence_mean = ...
        mean(qGate.localSignalConfidence, 'all');

    results.soft_wta_threshold = ...
        qGate.wtaThreshold;

    results.soft_wta_strong_fraction = ...
        qGate.strongActivationFraction;

    results.network_steps = network.actualSteps;

    results.network_participation_ratio = ...
        network.participationRatioFinal;

    results.network_adjacency_entrywise_l1 = ...
        network.adjacencyEntrywiseL1;

    results.network_max_degree = ...
        network.maximumDegree;

    results.network_spectral_radius = ...
        network.spectralRadius;

    results.network_semantic_radius = ...
        network.semanticRadius;

    results.network_global_noise_level = ...
        network.globalNoiseLevel;

    results.network_effective_spectral_cutoff = ...
        network.effectiveSpectralCutoff;

    results.network_relative_change_A = ...
        network.relativeChangeAFinal;

    results.network_relative_change_X = ...
        network.relativeChangeXFinal;

    results.runtime_seconds = elapsed;
end

%% ========================================================================
function cfg = configuration()

    cfg = struct();

    cfg.version = ...
        'Yehoshua_System_Gradient_integration_v4_temporal_living_tensor_export';

    cfg.gradientDisplayName = ...
        'Yehoshua&System_Gradient_integration';

    %% Canonical source lock
    cfg.sourceFile = ...
        ['/MATLAB Drive/modelTRAINING/', ...
        'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];

    cfg.datasetPath = ...
        '/n_5_composite_field_1000x1000/data';

    cfg.expectedSHA256 = ...
        '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';

    cfg.outputFolder = ...
        ['/MATLAB Drive/modelTRAINING/', ...
        'Yehoshua_System_Gradient_integration_output'];

    cfg.H = 1000;
    cfg.W = 1000;
    cfg.C = 5;

    cfg.robustSampleCount = 250000;
    cfg.pcaSampleCount = 300000;

    cfg.gaussianScales = ...
        single([0.75, 1.5, 3, 6, 12, 24, 40]);

    cfg.spectralCutoffs = ...
        single([0, 0.008, 0.016, 0.032, 0.064, ...
        0.125, 0.250, 0.500, 0.700]);

    %% Display operator
    cfg.display.colorMatrix = eye(3, 'single');
    cfg.display.whiteGain = single([1, 1, 1]);
    cfg.display.brightness = single(1);
    cfg.display.spatialSigma = single(0.35);
    cfg.display.shoulder = single(0.08);

    %% Optical field
    cfg.optics.lambdaNm = single((380:5:780)');
    cfg.optics.primaryCentersNm = single([620, 535, 460]);
    cfg.optics.primaryWidthsNm = single([22, 20, 18]);
    cfg.optics.coneCentersNm = single([565, 535, 445]);
    cfg.optics.coneWidthsNm = single([42, 38, 28]);

    %% Phototransduction
    cfg.photo.steps = 720;
    cfg.photo.dt = single(0.00625);
    cfg.photo.modulationDepth = single(0.095);
    cfg.photo.phaseCycles = single([8, 13, 21]);
    cfg.photo.phaseWarp = single(0.34);
    cfg.photo.motionRadiusPixels = single(3.0);
    cfg.photo.trailDecay = single(0.965);
    cfg.photo.opsinOn = single(3.6);
    cfg.photo.opsinOff = single(1.0);
    cfg.photo.transducinOn = single(4.2);
    cfg.photo.transducinOff = single(1.35);
    cfg.photo.pdeOn = single(4.8);
    cfg.photo.pdeOff = single(1.55);
    cfg.photo.cgmpSynthesis = single(2.4);
    cfg.photo.cgmpHydrolysis = single(7.0);
    cfg.photo.cngK = single(0.42);
    cfg.photo.cngHill = single(3.0);
    cfg.photo.vDark = single(-40);
    cfg.photo.hyperGain = single(30);
    cfg.photo.glutamateTheta = single(-50);
    cfg.photo.glutamateSlope = single(4);

    %% Retina
    cfg.retina.centerSigma = single(1.2);
    cfg.retina.surroundSigma = single(5.5);
    cfg.retina.divisiveSigma = single(7.5);
    cfg.retina.divisiveEpsilon = single(0.06);

    %% V1 bank
    cfg.v1.numberOfAngles = 16;
    cfg.v1.wavelengthPixels = ...
        single([4, 6, 9, 13, 19, 28, 42]);
    cfg.v1.frequencySigmaRatio = single(0.36);
    cfg.v1.inputChromaticWeight = single(0.22);
    cfg.v1.inputTemporalWeight = single(0.18);

    %% Quantization
    cfg.quant.maxCores = 96;
    cfg.quant.minimumDistance = 14;
    cfg.quant.windingThreshold = single(0.32);
    cfg.quant.energyPercentile = 72;

    %% Sixteen image layers
    cfg.fusionWeights = single([ ...
        0.90, 1.00, 0.90, 1.25, ...
        0.90, 1.00, 0.80, 0.85, ...
        0.70, 0.70, 0.70, 0.85, ...
        1.00, 0.95, 1.20, 1.35]);

    %% q-byte adaptive precision gate
    cfg.qgate.baseBudget = single(0.72);

    cfg.qgate.noiseWeight = single(0.48);
    cfg.qgate.errorWeight = single(0.42);
    cfg.qgate.minimumAdaptivePenalty = single(0.35);
    cfg.qgate.temporalNoiseWeight = single(0.55);

    cfg.qgate.overloadGain = single(3.20);
    cfg.qgate.selectivityGain = single(7.50);
    cfg.qgate.noisePenalty = single(0.80);
    cfg.qgate.errorPenalty = single(0.72);
    cfg.qgate.temporalPenalty = single(0.62);
    cfg.qgate.leakWeight = single(0.38);

    % Threshold at the 82nd percentile: strongest ~18% remain unchanged.
    cfg.qgate.sparsityPercentile = 82;
    cfg.qgate.softShoulderGain = single(0.18);
    cfg.qgate.softShoulderPower = single(2.0);

    %% Adaptive graph A(t) and semantic geometry X(t)
    cfg.network.steps = 384;
    cfg.network.graphUpdateEvery = 8;
    cfg.network.geometryUpdateEvery = 16;
    cfg.network.minimumSteps = 128;
    cfg.network.convergencePatience = 6;
    cfg.network.convergenceToleranceA = 1e-4;
    cfg.network.convergenceToleranceX = 1e-4;

    cfg.network.kNearest = 5;
    cfg.network.maximumEdgesPerNode = 6;

    cfg.network.featureSigma = 0.90;
    cfg.network.geometrySigma = 0.70;
    cfg.network.phasePower = 2.0;
    cfg.network.phaseFloor = 0.04;

    cfg.network.learningRateA = 0.035;
    cfg.network.weightDecay = 0.018;
    cfg.network.noisePenalty = 0.62;
    cfg.network.instabilityWeight = 0.55;
    cfg.network.featureMismatchWeight = 0.20;
    cfg.network.collapseNoiseWeight = 0.22;
    cfg.network.softThresholdA = 0.012;
    cfg.network.maximumEdgeWeight = 1.0;

    cfg.network.globalBudgetPerNode = 2.80;

    cfg.network.targetDegree = 2.40;
    cfg.network.maximumDegree = 4.50;
    cfg.network.precisionDegreeFloor = 0.60;
    cfg.network.precisionDegreeRange = 0.40;
    cfg.network.precisionMaximumDegreeFloor = 0.65;
    cfg.network.precisionMaximumDegreeRange = 0.35;

    cfg.network.homeostasisRate = 0.30;
    cfg.network.minimumHomeostasisScale = 0.72;
    cfg.network.maximumHomeostasisScale = 1.28;
    cfg.network.constraintIterations = 3;

    %% Adaptive normalized-Laplacian spectral filter
    cfg.network.spectralCutoff = 0.78;
    cfg.network.minimumSpectralCutoff = 0.35;
    cfg.network.maximumSpectralCutoff = 0.78;
    cfg.network.cutoffNoiseGain = 0.30;
    cfg.network.spectralOrder = 4.0;

    %% Stable state propagation
    cfg.network.stateDt = 0.080;
    cfg.network.collapseSpreadGain = 1.10;
    cfg.network.baseAmplitudeThreshold = 0.006;
    cfg.network.collapseThresholdGain = 1.70;
    cfg.network.overloadThresholdGain = 0.65;
    cfg.network.nonlinearDamping = 0.18;
    cfg.network.potentialGain = 0.08;
    cfg.network.structurePotentialGain = 0.04;

    %% Structural plasticity
    cfg.network.geometryLearningRate = 0.0060;
    cfg.network.velocityDamping = 0.86;
    cfg.network.attractionGain = 0.80;
    cfg.network.repulsionGain = 0.045;
    cfg.network.barrierGain = 0.12;
    cfg.network.centerGain = 0.018;
    cfg.network.minimumPairDistance = 0.060;
    cfg.network.targetSemanticRadius = 0.68;
    cfg.network.maximumSemanticRadius = 1.25;
    cfg.network.maximumGeometryStep = 0.025;
    cfg.network.radiusCorrectionLimit = 0.02;

    % High-quality temporal living render
    cfg.render.outputSize = 1800;
    cfg.render.sharpenSigma = single(0.85);
    cfg.render.sharpenAmount = single(0.52);
    cfg.render.glowSigma = single(5.5);
    cfg.render.glowAmount = single(0.15);
    cfg.render.gamma = single(1.06);
end

%% ========================================================================
function validateCanonicalSource(cfg)

    lockedFile = ...
        ['/MATLAB Drive/modelTRAINING/', ...
        'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];

    lockedDataset = ...
        '/n_5_composite_field_1000x1000/data';

    if ~strcmp(cfg.sourceFile, lockedFile)
        error('Source-path lock mismatch.');
    end

    if ~strcmp(cfg.datasetPath, lockedDataset)
        error('Dataset-path lock mismatch.');
    end

    if ~isfile(cfg.sourceFile)
        error('Canonical H5 source was not found: %s', cfg.sourceFile);
    end

    datasetInfo = h5info(cfg.sourceFile, cfg.datasetPath);

    if isempty(datasetInfo) || ~isfield(datasetInfo, 'Dataspace')
        error('Canonical H5 dataset could not be opened.');
    end

    fprintf('Computing source SHA256...\n');

    actualSHA256 = sha256File(cfg.sourceFile);

    if ~strcmpi(actualSHA256, cfg.expectedSHA256)
        error( ...
            'SHA256 mismatch. Expected %s; received %s.', ...
            cfg.expectedSHA256, actualSHA256);
    end

    fprintf('SHA256 matched.\n');
end

%% ========================================================================
function hex = sha256File(filePath)

    digestEngine = ...
        java.security.MessageDigest.getInstance('SHA-256');

    fileID = fopen(filePath, 'rb');

    if fileID < 0
        error('Could not open the canonical H5 source.');
    end

    cleanupObject = onCleanup(@() fclose(fileID)); %#ok<NASGU>
    chunkBytes = 8 * 1024 * 1024;

    while true

        data = fread(fileID, chunkBytes, '*uint8');

        if isempty(data)
            break;
        end

        digestEngine.update(typecast(data, 'int8'));
    end

    digest = typecast(digestEngine.digest(), 'uint8');
    hex = lower(reshape(dec2hex(digest, 2).', 1, []));
end

%% ========================================================================
function cube = decodeCanonicalLayoutB(raw, cfg)
% Recorded canonical layout:
% reshape(v,5,1000,1000) -> H x W x C

    if ~isnumeric(raw)
        error('The canonical dataset must be numeric.');
    end

    expectedValues = cfg.H * cfg.W * cfg.C;

    if numel(raw) ~= expectedValues
        error( ...
            'Expected %d values; received %d.', ...
            expectedValues, numel(raw));
    end

    sourceVector = single(raw(:));

    cube = permute( ...
        reshape(sourceVector, [cfg.C, cfg.H, cfg.W]), ...
        [2, 3, 1]);

    cube(~isfinite(cube)) = 0;
end

%% ========================================================================
function [field, weights] = integrateFiveChannels(cube, cfg)

    [H, W, C] = size(cube);

    normalizedCube = zeros(H, W, C, 'single');

    for channelIndex = 1:C

        normalizedCube(:, :, channelIndex) = ...
            robustSignedNormalize( ...
            cube(:, :, channelIndex), ...
            cfg.robustSampleCount);
    end

    X = reshape(normalizedCube, [], C);

    sampleStep = max( ...
        1, floor(size(X, 1) / cfg.pcaSampleCount));

    Xsample = double(X(1:sampleStep:end, :));
    Xsample = Xsample - mean(Xsample, 1);

    covarianceMatrix = ...
        (Xsample.' * Xsample) / ...
        max(1, size(Xsample, 1) - 1);

    covarianceMatrix = ...
        0.5 * (covarianceMatrix + covarianceMatrix.');

    [eigenvectors, eigenvalues] = ...
        eig(covarianceMatrix, 'vector');

    [~, principalIndex] = max(real(eigenvalues));

    weights = single(real(eigenvectors(:, principalIndex)));

    reference = mean(Xsample, 2);
    projected = Xsample * double(weights);

    if dot(projected, reference) < 0
        weights = -weights;
    end

    weights = ...
        weights / max(norm(weights), eps('single'));

    field = reshape(X * weights, H, W);

    field = robustSignedNormalize( ...
        field, cfg.robustSampleCount);
end

%% ========================================================================
function base = computeDifferentialFields(I0, cfg)

    [gradientX, gradientY] = gradient(I0);

    gradientMagnitude = hypot(gradientX, gradientY);

    laplacianKernel = single([ ...
        0, 1, 0; ...
        1, -4, 1; ...
        0, 1, 0]);

    laplacian = conv2(I0, laplacianKernel, 'same');

    Jxx = gaussianBlur(gradientX .* gradientX, single(2.2));
    Jyy = gaussianBlur(gradientY .* gradientY, single(2.2));
    Jxy = gaussianBlur(gradientX .* gradientY, single(2.2));

    orientation = ...
        single(0.5) * atan2(2 * Jxy, Jxx - Jyy);

    coherence = ...
        sqrt((Jxx - Jyy) .^ 2 + 4 * Jxy .^ 2) ./ ...
        (Jxx + Jyy + single(1e-7));

    base = struct();
    base.gx = gradientX;
    base.gy = gradientY;
    base.magnitude = gradientMagnitude;
    base.laplacian = laplacian;
    base.orientation = orientation;
    base.coherence = clamp01(coherence);

    base.salience = normalize01( ...
        single(0.55) * gradientMagnitude + ...
        single(0.30) * abs(laplacian) + ...
        single(0.15) * abs(I0), ...
        cfg.robustSampleCount);
end

%% ========================================================================
function multiscale = computeMultiscaleFields(I0, cfg)

    scales = cfg.gaussianScales;

    gaussianStack = zeros( ...
        cfg.H, cfg.W, numel(scales), 'single');

    dogStack = zeros( ...
        cfg.H, cfg.W, numel(scales) - 1, 'single');

    for scaleIndex = 1:numel(scales)

        gaussianStack(:, :, scaleIndex) = ...
            gaussianBlur(I0, scales(scaleIndex));

        if scaleIndex > 1

            dogStack(:, :, scaleIndex - 1) = ...
                gaussianStack(:, :, scaleIndex - 1) - ...
                gaussianStack(:, :, scaleIndex);
        end

        fprintf( ...
            '  Gaussian %d/%d | sigma=%.3f\n', ...
            scaleIndex, numel(scales), scales(scaleIndex));
    end

    multiscale = struct();
    multiscale.gaussian = gaussianStack;
    multiscale.dog = dogStack;
    multiscale.dogEnergy = sqrt(sum(dogStack .^ 2, 3));
end

%% ========================================================================
function spectral = computeSpectralFields(I0, cfg)

    [frequencyX, frequencyY] = ...
        frequencyGrid(cfg.H, cfg.W);

    radius = sqrt(frequencyX .^ 2 + frequencyY .^ 2);

    sourceFFT = fft2(I0);

    cutoffs = cfg.spectralCutoffs;
    numberOfBands = numel(cutoffs) - 1;

    bands = zeros( ...
        cfg.H, cfg.W, numberOfBands, 'single');

    for bandIndex = 1:numberOfBands

        lowCut = cutoffs(bandIndex);
        highCut = cutoffs(bandIndex + 1);

        if lowCut == 0
            lowPassA = zeros(cfg.H, cfg.W, 'single');
        else
            lowPassA = exp(-((radius ./ lowCut) .^ 8));
        end

        lowPassB = exp(-((radius ./ highCut) .^ 8));

        if bandIndex == 1
            bandMask = lowPassB;
        else
            bandMask = max(lowPassB - lowPassA, 0);
        end

        bands(:, :, bandIndex) = ...
            real(ifft2(sourceFFT .* bandMask));

        fprintf( ...
            '  Spectral band %d/%d | %.5f -> %.5f cycles/pixel\n', ...
            bandIndex, numberOfBands, lowCut, highCut);
    end

    spectral = struct();
    spectral.bands = bands;
    spectral.low = sum(bands(:, :, 1:2), 3);
    spectral.mid = sum(bands(:, :, 3:5), 3);
    spectral.high = sum(bands(:, :, 6:end), 3);
    spectral.energy = sqrt(sum(bands .^ 2, 3));
    spectral.fftLogMagnitude = ...
        log1p(abs(fftshift(sourceFFT)));
end

%% ========================================================================
function rgb = buildSourceRGB( ...
    I0, base, multiscale, spectral, cfg)

    hue = mod( ...
        (atan2(base.gy, base.gx) + pi) / (2 * pi) + ...
        single(0.14) * normalize01( ...
        spectral.mid, cfg.robustSampleCount), ...
        1);

    saturation = clamp01( ...
        single(0.40) + ...
        single(0.35) * normalize01( ...
        abs(spectral.high), cfg.robustSampleCount) + ...
        single(0.25) * base.coherence);

    valueField = ...
        single(0.30) * abs(I0) + ...
        single(0.24) * base.magnitude + ...
        single(0.18) * abs(base.laplacian) + ...
        single(0.16) * multiscale.dogEnergy + ...
        single(0.12) * spectral.energy;

    value = ...
        normalize01(valueField, cfg.robustSampleCount) .^ ...
        single(0.72);

    gate = normalize01( ...
        base.salience + multiscale.dogEnergy, ...
        cfg.robustSampleCount);

    value = ...
        value .* (single(0.05) + single(0.95) * gate);

    rgb = single(hsv2rgb(cat( ...
        3, hue, saturation, clamp01(value))));
end

%% ========================================================================
function rgbOutput = applyAppleDisplayOperator(rgbInput, cfg)

    linearRGB = srgbDecode(clamp01(rgbInput));

    flatRGB = reshape(linearRGB, [], 3);

    flatRGB = flatRGB * cfg.display.colorMatrix.';
    flatRGB = flatRGB .* cfg.display.whiteGain;
    flatRGB = flatRGB * cfg.display.brightness;

    linearRGB = reshape(flatRGB, cfg.H, cfg.W, 3);

    for channelIndex = 1:3

        linearRGB(:, :, channelIndex) = ...
            gaussianBlur( ...
            linearRGB(:, :, channelIndex), ...
            cfg.display.spatialSigma);
    end

    linearRGB = max(linearRGB, 0);

    linearRGB = ...
        linearRGB ./ ...
        (1 + cfg.display.shoulder * linearRGB);

    rgbOutput = clamp01(srgbEncode(linearRGB));
end

%% ========================================================================
function optical = computeOpticalConeFields(rgbDisplay, cfg)

    wavelength = cfg.optics.lambdaNm;
    wavelengthStep = mean(diff(wavelength));

    primaryBasis = zeros( ...
        numel(wavelength), 3, 'single');

    coneBasis = zeros( ...
        numel(wavelength), 3, 'single');

    for channelIndex = 1:3

        primaryBasis(:, channelIndex) = exp( ...
            -single(0.5) * ...
            ((wavelength - ...
            cfg.optics.primaryCentersNm(channelIndex)) / ...
            cfg.optics.primaryWidthsNm(channelIndex)) .^ 2);

        coneBasis(:, channelIndex) = exp( ...
            -single(0.5) * ...
            ((wavelength - ...
            cfg.optics.coneCentersNm(channelIndex)) / ...
            cfg.optics.coneWidthsNm(channelIndex)) .^ 2);
    end

    primaryBasis = ...
        primaryBasis ./ max(primaryBasis, [], 1);

    coneBasis = ...
        coneBasis ./ max(coneBasis, [], 1);

    planckConstant = 6.62607015e-34;
    lightSpeed = 299792458;

    photonEnergy = ...
        planckConstant * lightSpeed ./ ...
        (double(wavelength) * 1e-9);

    photonWeight = single( ...
        (1 ./ photonEnergy) / max(1 ./ photonEnergy));

    linearRGB = srgbDecode(rgbDisplay);

    red = linearRGB(:, :, 1);
    green = linearRGB(:, :, 2);
    blue = linearRGB(:, :, 3);

    qL = zeros(cfg.H, cfg.W, 'single');
    qM = zeros(cfg.H, cfg.W, 'single');
    qS = zeros(cfg.H, cfg.W, 'single');
    opticalEnergy = zeros(cfg.H, cfg.W, 'single');

    for wavelengthIndex = 1:numel(wavelength)

        spectralPlane = ...
            red * primaryBasis(wavelengthIndex, 1) + ...
            green * primaryBasis(wavelengthIndex, 2) + ...
            blue * primaryBasis(wavelengthIndex, 3);

        weightedPlane = ...
            spectralPlane * photonWeight(wavelengthIndex);

        qL = qL + ...
            weightedPlane * ...
            coneBasis(wavelengthIndex, 1) * wavelengthStep;

        qM = qM + ...
            weightedPlane * ...
            coneBasis(wavelengthIndex, 2) * wavelengthStep;

        qS = qS + ...
            weightedPlane * ...
            coneBasis(wavelengthIndex, 3) * wavelengthStep;

        opticalEnergy = ...
            opticalEnergy + spectralPlane * wavelengthStep;

        if mod(wavelengthIndex, 10) == 0 || ...
                wavelengthIndex == numel(wavelength)

            fprintf( ...
                '  Wavelength %d/%d | %.1f nm\n', ...
                wavelengthIndex, ...
                numel(wavelength), ...
                wavelength(wavelengthIndex));
        end
    end

    optical = struct();

    optical.Q = cat( ...
        3, ...
        normalize01(qL, cfg.robustSampleCount), ...
        normalize01(qM, cfg.robustSampleCount), ...
        normalize01(qS, cfg.robustSampleCount));

    optical.energy = normalize01( ...
        opticalEnergy, cfg.robustSampleCount);
end

%% ========================================================================
function photo = simulatePhototransduction(Q, cfg)

    stimulusBase = clamp01( ...
        single(0.45) * Q(:, :, 1) + ...
        single(0.45) * Q(:, :, 2) + ...
        single(0.10) * Q(:, :, 3));

    phaseSeed = single(pi) * ( ...
        single(0.55) * (Q(:, :, 1) - Q(:, :, 3)) + ...
        single(0.30) * (Q(:, :, 2) - Q(:, :, 1)) + ...
        single(0.15) * (Q(:, :, 3) - Q(:, :, 2)));

    phaseSeed = phaseSeed + ...
        single(0.45) * atan2( ...
        Q(:, :, 3) - Q(:, :, 1), ...
        Q(:, :, 2) - single(0.5) * ...
        (Q(:, :, 1) + Q(:, :, 3)));

    opsin = zeros(cfg.H, cfg.W, 'single');
    transducin = zeros(cfg.H, cfg.W, 'single');
    pde6 = zeros(cfg.H, cfg.W, 'single');
    cgmp = ones(cfg.H, cfg.W, 'single');

    voltage = cfg.photo.vDark * ...
        ones(cfg.H, cfg.W, 'single');

    meanVoltage = zeros(cfg.H, cfg.W, 'single');
    temporalEnergy = zeros(cfg.H, cfg.W, 'single');
    temporalMean = zeros(cfg.H, cfg.W, 'single');
    temporalM2 = zeros(cfg.H, cfg.W, 'single');

    phaseAccumulator = complex( ...
        zeros(cfg.H, cfg.W, 'single'), ...
        zeros(cfg.H, cfg.W, 'single'));

    phaseVelocityAccumulator = ...
        zeros(cfg.H, cfg.W, 'single');

    temporalTrail = zeros(cfg.H, cfg.W, 'single');
    previousVoltage = voltage;
    previousPhaseField = phaseSeed;

    cycles = cfg.photo.phaseCycles;

    for stepIndex = 1:cfg.photo.steps

        tau = single(stepIndex - 1) / ...
            single(max(cfg.photo.steps - 1, 1));

        phaseA = single(2 * pi) * ...
            (cycles(1) * tau + ...
            cfg.photo.phaseWarp * tau .* tau);

        phaseB = single(2 * pi) * ...
            (cycles(2) * tau - ...
            single(0.18) * tau .* tau);

        phaseC = single(2 * pi) * ...
            (cycles(3) * tau + ...
            single(0.07) * sin(single(2 * pi) * tau));

        phaseField = ...
            phaseSeed + phaseA + ...
            single(0.38) * sin(phaseB + ...
            single(0.65) * phaseSeed) + ...
            single(0.22) * cos(phaseC - ...
            single(0.40) * phaseSeed);

        temporalCarrier = ...
            single(0.52) * sin(phaseField) + ...
            single(0.30) * sin(phaseB - ...
            single(0.55) * phaseSeed) + ...
            single(0.18) * cos(phaseC + phaseSeed);

        modulation = single(1) + ...
            cfg.photo.modulationDepth * temporalCarrier;

        shiftX = round(double( ...
            cfg.photo.motionRadiusPixels * cos(phaseA)));

        shiftY = round(double( ...
            cfg.photo.motionRadiusPixels * sin(phaseB)));

        stimulus = clamp01( ...
            circshift(stimulusBase, [shiftY, shiftX]) .* modulation);

        opsin = opsin + cfg.photo.dt * ( ...
            cfg.photo.opsinOn * stimulus .* (1 - opsin) - ...
            cfg.photo.opsinOff * opsin);
        opsin = clamp01(opsin);

        transducin = transducin + cfg.photo.dt * ( ...
            cfg.photo.transducinOn * opsin .* ...
            (1 - transducin) - ...
            cfg.photo.transducinOff * transducin);
        transducin = clamp01(transducin);

        pde6 = pde6 + cfg.photo.dt * ( ...
            cfg.photo.pdeOn * transducin .* ...
            (1 - pde6) - ...
            cfg.photo.pdeOff * pde6);
        pde6 = clamp01(pde6);

        cgmp = cgmp + cfg.photo.dt * ( ...
            cfg.photo.cgmpSynthesis * (1 - cgmp) - ...
            cfg.photo.cgmpHydrolysis * pde6 .* cgmp);
        cgmp = clamp01(cgmp);

        numerator = cgmp .^ cfg.photo.cngHill;
        denominator = numerator + ...
            cfg.photo.cngK .^ cfg.photo.cngHill;
        cng = numerator ./ (denominator + single(1e-7));

        voltage = cfg.photo.vDark - ...
            cfg.photo.hyperGain * (1 - cng);

        temporalDelta = voltage - temporalMean;
        temporalMean = temporalMean + ...
            temporalDelta / single(stepIndex);
        temporalDelta2 = voltage - temporalMean;
        temporalM2 = temporalM2 + ...
            temporalDelta .* temporalDelta2;

        voltageDifference = voltage - previousVoltage;
        temporalEnergy = temporalEnergy + ...
            voltageDifference .^ 2;

        temporalTrail = ...
            cfg.photo.trailDecay * temporalTrail + ...
            (single(1) - cfg.photo.trailDecay) * ...
            abs(voltageDifference);

        phaseWeight = single(0.15) + ...
            single(0.85) * stimulus;

        phaseAccumulator = phaseAccumulator + ...
            phaseWeight .* complex( ...
            cos(phaseField), sin(phaseField));

        wrappedPhaseStep = angle(exp( ...
            complex(zeros(cfg.H, cfg.W, 'single'), ...
            phaseField - previousPhaseField)));

        phaseVelocityAccumulator = ...
            phaseVelocityAccumulator + ...
            abs(wrappedPhaseStep) .* phaseWeight;

        meanVoltage = meanVoltage + voltage;
        previousVoltage = voltage;
        previousPhaseField = phaseField;

        if mod(stepIndex, 30) == 0 || ...
                stepIndex == cfg.photo.steps
            fprintf('  Deep temporal phase %d/%d\n', ...
                stepIndex, cfg.photo.steps);
        end
    end

    meanVoltage = meanVoltage / single(cfg.photo.steps);

    glutamate = single(1) ./ ...
        (single(1) + exp( ...
        -(voltage - cfg.photo.glutamateTheta) / ...
        cfg.photo.glutamateSlope));

    temporalVariance = temporalM2 / ...
        single(max(cfg.photo.steps - 1, 1));

    phaseMagnitude = abs(phaseAccumulator);
    phaseWeightTotal = single(cfg.photo.steps) * ...
        (single(0.15) + single(0.85) * stimulusBase);

    photo = struct();
    photo.meanVoltage = meanVoltage;
    photo.voltage = voltage;
    photo.cgmp = cgmp;
    photo.glutamate = glutamate;

    photo.temporalEnergy = normalize01( ...
        sqrt(temporalEnergy / single(cfg.photo.steps)), ...
        cfg.robustSampleCount);

    photo.temporalVariance = normalize01( ...
        temporalVariance, cfg.robustSampleCount);

    photo.temporalNoise = normalize01( ...
        temporalVariance ./ ...
        (abs(temporalMean) + single(1e-6)), ...
        cfg.robustSampleCount);

    photo.temporalPhase = angle(phaseAccumulator);

    photo.temporalPhaseCoherence = clamp01( ...
        phaseMagnitude ./ ...
        (phaseWeightTotal + single(1e-6)));

    photo.temporalPhaseVelocity = normalize01( ...
        phaseVelocityAccumulator / ...
        single(max(cfg.photo.steps - 1, 1)), ...
        cfg.robustSampleCount);

    photo.temporalTrail = normalize01( ...
        temporalTrail, cfg.robustSampleCount);
end

%% ========================================================================
function retina = computeRetinalFields(Q, photo, cfg)

    responseField = normalize01( ...
        -photo.meanVoltage, cfg.robustSampleCount);

    center = gaussianBlur( ...
        responseField, cfg.retina.centerSigma);

    surround = gaussianBlur( ...
        responseField, cfg.retina.surroundSigma);

    centerSurround = center - surround;

    onField = max(centerSurround, 0);
    offField = max(-centerSurround, 0);

    qL = Q(:, :, 1);
    qM = Q(:, :, 2);
    qS = Q(:, :, 3);

    luminance = single(0.5) * (qL + qM);
    LM = qL - qM;
    SLM = qS - single(0.5) * (qL + qM);

    denominator = ...
        cfg.retina.divisiveEpsilon + ...
        gaussianBlur( ...
        onField + offField + luminance, ...
        cfg.retina.divisiveSigma);

    onField = onField ./ denominator;
    offField = offField ./ denominator;

    ganglionDrive = ...
        single(0.34) * normalize01( ...
        onField, cfg.robustSampleCount) + ...
        single(0.26) * normalize01( ...
        offField, cfg.robustSampleCount) + ...
        single(0.16) * normalize01( ...
        abs(LM), cfg.robustSampleCount) + ...
        single(0.12) * normalize01( ...
        abs(SLM), cfg.robustSampleCount) + ...
        single(0.12) * photo.temporalEnergy;

    retina = struct();
    retina.on = normalize01(onField, cfg.robustSampleCount);
    retina.off = normalize01(offField, cfg.robustSampleCount);
    retina.luminance = normalize01( ...
        luminance, cfg.robustSampleCount);
    retina.LM = robustSignedNormalize( ...
        LM, cfg.robustSampleCount);
    retina.SLM = robustSignedNormalize( ...
        SLM, cfg.robustSampleCount);
    retina.temporal = photo.temporalEnergy;
    retina.ganglion = normalize01( ...
        ganglionDrive, cfg.robustSampleCount);
end

%% ========================================================================
function relay = computeRelayField(retina, cfg)

    relayRaw = ...
        single(0.36) * retina.ganglion + ...
        single(0.20) * retina.on + ...
        single(0.18) * retina.off + ...
        single(0.14) * abs(retina.LM) + ...
        single(0.12) * abs(retina.SLM);

    normalizationPool = ...
        single(0.08) + ...
        gaussianBlur(relayRaw, single(6));

    relay = normalize01( ...
        relayRaw ./ normalizationPool, ...
        cfg.robustSampleCount);
end

%% ========================================================================
function v1 = computeV1ComplexBank(relay, retina, cfg)

    inputField = ...
        relay + ...
        cfg.v1.inputChromaticWeight * normalize01( ...
        abs(retina.LM) + abs(retina.SLM), ...
        cfg.robustSampleCount) + ...
        cfg.v1.inputTemporalWeight * retina.temporal;

    inputField = robustSignedNormalize( ...
        inputField, cfg.robustSampleCount);

    [frequencyX, frequencyY] = ...
        frequencyGrid(cfg.H, cfg.W);

    inputFFT = fft2(inputField);

    angles = linspace( ...
        0, pi, cfg.v1.numberOfAngles + 1);

    angles(end) = [];

    wavelengths = cfg.v1.wavelengthPixels;

    maximumEnergy = zeros(cfg.H, cfg.W, 'single');
    totalEnergy = zeros(cfg.H, cfg.W, 'single');

    orientationVector = ...
        complex(zeros(cfg.H, cfg.W, 'single'));

    phaseCarrier = ...
        complex(zeros(cfg.H, cfg.W, 'single'));

    totalFilters = ...
        numel(angles) * numel(wavelengths);

    filterCounter = 0;

    for scaleIndex = 1:numel(wavelengths)

        wavelength = wavelengths(scaleIndex);
        centerFrequency = single(1) / wavelength;

        frequencySigma = max( ...
            single(1e-4), ...
            cfg.v1.frequencySigmaRatio * centerFrequency);

        for angleIndex = 1:numel(angles)

            theta = single(angles(angleIndex));

            centerX = centerFrequency * cos(theta);
            centerY = centerFrequency * sin(theta);

            frequencyKernel = exp( ...
                -((frequencyX - centerX) .^ 2 + ...
                (frequencyY - centerY) .^ 2) / ...
                (2 * frequencySigma ^ 2));

            frequencyKernel = ...
                frequencyKernel ./ ...
                max(frequencyKernel, [], 'all');

            complexResponse = ...
                ifft2(inputFFT .* frequencyKernel);

            responseEnergy = abs(complexResponse);

            maximumEnergy = ...
                max(maximumEnergy, responseEnergy);

            totalEnergy = totalEnergy + responseEnergy;

            orientationVector = ...
                orientationVector + ...
                responseEnergy * ...
                exp(1i * single(2) * theta);

            phaseCarrier = ...
                phaseCarrier + ...
                complexResponse / sqrt(single(scaleIndex));

            filterCounter = filterCounter + 1;

            if mod(filterCounter, 8) == 0 || ...
                    filterCounter == totalFilters

                fprintf( ...
                    '  V1 filter %d/%d\n', ...
                    filterCounter, totalFilters);
            end
        end
    end

    v1 = struct();

    v1.energy = normalize01( ...
        maximumEnergy, cfg.robustSampleCount);

    v1.totalEnergy = normalize01( ...
        totalEnergy, cfg.robustSampleCount);

    v1.orientation = ...
        single(0.5) * angle(orientationVector);

    v1.orientationCoherence = clamp01( ...
        abs(orientationVector) ./ ...
        (totalEnergy + single(1e-7)));

    v1.phase = angle(phaseCarrier);

    v1.phaseCoherence = clamp01( ...
        abs(phaseCarrier) ./ ...
        (totalEnergy + single(1e-7)));
end

%% ========================================================================
function quant = computeQuantizationField(v1, base, cfg)

    phase = v1.phase;

    deltaTop = wrapToPiLocal( ...
        phase(1:end-1, 2:end) - ...
        phase(1:end-1, 1:end-1));

    deltaRight = wrapToPiLocal( ...
        phase(2:end, 2:end) - ...
        phase(1:end-1, 2:end));

    deltaBottom = wrapToPiLocal( ...
        phase(2:end, 1:end-1) - ...
        phase(2:end, 2:end));

    deltaLeft = wrapToPiLocal( ...
        phase(1:end-1, 1:end-1) - ...
        phase(2:end, 1:end-1));

    windingSmall = ...
        (deltaTop + deltaRight + ...
        deltaBottom + deltaLeft) / single(2 * pi);

    energySmall = single(0.25) * ( ...
        v1.energy(1:end-1, 1:end-1) + ...
        v1.energy(1:end-1, 2:end) + ...
        v1.energy(2:end, 1:end-1) + ...
        v1.energy(2:end, 2:end));

    coherenceSmall = single(0.25) * ( ...
        v1.phaseCoherence(1:end-1, 1:end-1) + ...
        v1.phaseCoherence(1:end-1, 2:end) + ...
        v1.phaseCoherence(2:end, 1:end-1) + ...
        v1.phaseCoherence(2:end, 2:end));

    energyThreshold = samplePercentile( ...
        energySmall, ...
        cfg.quant.energyPercentile, ...
        cfg.robustSampleCount);

    candidateMask = ...
        abs(windingSmall) >= cfg.quant.windingThreshold & ...
        energySmall >= energyThreshold & ...
        coherenceSmall >= single(0.05);

    scoreMap = ...
        abs(windingSmall) .* ...
        energySmall .* ...
        (single(0.25) + single(0.75) * coherenceSmall);

    [coresX, coresY, coreScores] = ...
        selectSeparatedCandidates( ...
        candidateMask, scoreMap, ...
        cfg.quant.maxCores, ...
        cfg.quant.minimumDistance);

    coreField = zeros(cfg.H, cfg.W, 'single');

    for coreIndex = 1:numel(coresX)

        coreField( ...
            coresY(coreIndex), ...
            coresX(coreIndex)) = ...
            coreScores(coreIndex);
    end

    winding = zeros(cfg.H, cfg.W, 'single');
    winding(1:end-1, 1:end-1) = windingSmall;

    quant = struct();
    quant.winding = winding;
    quant.coreGlow = gaussianBlur( ...
        normalize01(coreField, cfg.robustSampleCount), ...
        single(4));
    quant.coresX = coresX;
    quant.coresY = coresY;
    quant.coreScores = coreScores;
    quant.boundarySupport = normalize01( ...
        base.magnitude .* ...
        (single(0.25) + single(0.75) * v1.energy), ...
        cfg.robustSampleCount);
end

%% ========================================================================
function gradientState = computeGradientIntegration( ...
    base, multiscale, spectral, optical, photo, ...
    retina, relay, v1, quant, cfg)

    % Temporal phase carrier.
    [phaseGradientX, phaseGradientY] = gradient(v1.phase);

    carrierNorm = ...
        hypot(phaseGradientX, phaseGradientY) + ...
        single(1e-7);

    carrierX = phaseGradientX ./ carrierNorm;
    carrierY = phaseGradientY ./ carrierNorm;

    % proj_t(g) = ((g.t)/(t.t)) t
    projectionDenominator = ...
        carrierX .^ 2 + carrierY .^ 2 + ...
        single(1e-7);

    projectionCoefficient = ...
        (base.gx .* carrierX + ...
        base.gy .* carrierY) ./ ...
        projectionDenominator;

    projectionX = ...
        projectionCoefficient .* carrierX;

    projectionY = ...
        projectionCoefficient .* carrierY;

    projectionMagnitude = ...
        hypot(projectionX, projectionY);

    divergence = ...
        gradientComponent(projectionX, 2) + ...
        gradientComponent(projectionY, 1);

    curlField = ...
        gradientComponent(projectionY, 2) - ...
        gradientComponent(projectionX, 1);

    coneContrast = normalize01( ...
        abs(optical.Q(:, :, 1) - optical.Q(:, :, 2)) + ...
        abs(optical.Q(:, :, 3) - ...
        single(0.5) * ...
        (optical.Q(:, :, 1) + optical.Q(:, :, 2))), ...
        cfg.robustSampleCount);

    transductionField = normalize01( ...
        -photo.meanVoltage + photo.temporalEnergy, ...
        cfg.robustSampleCount);

    integratedEnergy = ...
        single(0.19) * normalize01( ...
        base.magnitude, cfg.robustSampleCount) + ...
        single(0.13) * normalize01( ...
        abs(base.laplacian), cfg.robustSampleCount) + ...
        single(0.12) * normalize01( ...
        multiscale.dogEnergy, cfg.robustSampleCount) + ...
        single(0.09) * normalize01( ...
        spectral.energy, cfg.robustSampleCount) + ...
        single(0.11) * normalize01( ...
        projectionMagnitude, cfg.robustSampleCount) + ...
        single(0.07) * normalize01( ...
        abs(divergence), cfg.robustSampleCount) + ...
        single(0.07) * normalize01( ...
        abs(curlField), cfg.robustSampleCount) + ...
        single(0.07) * transductionField + ...
        single(0.05) * coneContrast + ...
        single(0.04) * normalize01( ...
        retina.on + retina.off, cfg.robustSampleCount) + ...
        single(0.03) * relay + ...
        single(0.02) * v1.energy + ...
        single(0.01) * quant.coreGlow;

    gradientAngle = atan2( ...
        single(0.55) * base.gy + ...
        single(0.45) * projectionY, ...
        single(0.55) * base.gx + ...
        single(0.45) * projectionX);

    gradientState = struct();
    gradientState.name = cfg.gradientDisplayName;
    gradientState.projectionX = projectionX;
    gradientState.projectionY = projectionY;
    gradientState.projectionMagnitude = projectionMagnitude;
    gradientState.divergence = divergence;
    gradientState.curl = curlField;
    gradientState.angle = gradientAngle;
    gradientState.energy = normalize01( ...
        integratedEnergy, cfg.robustSampleCount);
end


%% ========================================================================
function layers = buildUnifiedInformationLayers( ...
    I0_RGB, IA_RGB, I0, base, multiscale, spectral, ...
    optical, photo, retina, relay, v1, gradientState, cfg)

    layers = zeros(cfg.H, cfg.W, 16, 'single');

    layers(:, :, 1) = rgbLuminance(I0_RGB);
    layers(:, :, 2) = rgbLuminance(IA_RGB);
    layers(:, :, 3) = normalize01(abs(I0), cfg.robustSampleCount);
    layers(:, :, 4) = normalize01(base.magnitude, cfg.robustSampleCount);
    layers(:, :, 5) = normalize01(abs(base.laplacian), cfg.robustSampleCount);
    layers(:, :, 6) = normalize01(multiscale.dogEnergy, cfg.robustSampleCount);
    layers(:, :, 7) = normalize01(spectral.fftLogMagnitude, cfg.robustSampleCount);
    layers(:, :, 8) = optical.energy;
    layers(:, :, 9) = optical.Q(:, :, 1);
    layers(:, :, 10) = optical.Q(:, :, 2);
    layers(:, :, 11) = optical.Q(:, :, 3);
    layers(:, :, 12) = normalize01(-photo.meanVoltage, cfg.robustSampleCount);
    layers(:, :, 13) = normalize01(retina.on + retina.off, cfg.robustSampleCount);
    layers(:, :, 14) = relay;
    layers(:, :, 15) = v1.energy;
    layers(:, :, 16) = gradientState.energy;
end

%% ========================================================================
function qGate = computeQByteAdaptivePatternGate( ...
    layers, gradientState, v1, retina, photo, cfg)

    epsilonValue = single(1e-7);
    numberOfLayers = size(layers, 3);

    weights = reshape( ...
        cfg.fusionWeights(1:numberOfLayers), ...
        1, 1, numberOfLayers);

    weights = weights ./ ...
        (sum(weights, 3) + epsilonValue);

    informationLoad = sum(layers .* weights, 3);

    layerMean = mean(layers, 3);

    spatialDisagreement = sqrt(mean( ...
        (layers - layerMean) .^ 2, 3));

    spatialDisagreement = normalize01( ...
        spatialDisagreement, cfg.robustSampleCount);

    predictedField = gaussianBlur(informationLoad, single(3.0));

    predictionError = normalize01( ...
        abs(informationLoad - predictedField), ...
        cfg.robustSampleCount);

    temporalNoise = clamp01(photo.temporalNoise);

    disagreement = normalize01( ...
        spatialDisagreement + ...
        cfg.qgate.temporalNoiseWeight * temporalNoise, ...
        cfg.robustSampleCount);

    structuredSupport = normalize01( ...
        single(0.34) * gradientState.energy + ...
        single(0.26) * v1.energy + ...
        single(0.18) * v1.phaseCoherence + ...
        single(0.12) * retina.ganglion + ...
        single(0.10) * normalize01( ...
        retina.on + retina.off, cfg.robustSampleCount), ...
        cfg.robustSampleCount);

    % Bounded local signal confidence in [0,1].
    localSignalConfidence = ...
        structuredSupport ./ ...
        (structuredSupport + ...
        disagreement + ...
        predictionError + ...
        cfg.qgate.temporalPenalty * temporalNoise + ...
        epsilonValue);

    localSignalConfidence = clamp01(localSignalConfidence);

    noiseAdaptiveWeight = ...
        single(1) - localSignalConfidence;

    penaltyFloor = cfg.qgate.minimumAdaptivePenalty;

    effectiveNoiseWeight = ...
        cfg.qgate.noiseWeight .* ...
        (penaltyFloor + ...
        (single(1) - penaltyFloor) .* ...
        noiseAdaptiveWeight);

    effectiveErrorWeight = ...
        cfg.qgate.errorWeight .* ...
        (penaltyFloor + ...
        (single(1) - penaltyFloor) .* ...
        noiseAdaptiveWeight);

    qBudget = ...
        cfg.qgate.baseBudget .* ...
        (single(0.55) + ...
        single(0.45) * structuredSupport);

    consumedCapacity = ...
        informationLoad + ...
        effectiveNoiseWeight .* disagreement + ...
        effectiveErrorWeight .* predictionError + ...
        cfg.qgate.temporalPenalty .* ...
        noiseAdaptiveWeight .* temporalNoise;

    overload = max( ...
        single(0), ...
        consumedCapacity ./ ...
        (qBudget + epsilonValue) - ...
        single(1));

    precision = clamp01(exp( ...
        -cfg.qgate.overloadGain .* overload));

    selectiveGate = sigmoidLocal( ...
        cfg.qgate.selectivityGain .* ...
        (structuredSupport - ...
        cfg.qgate.noisePenalty .* disagreement - ...
        cfg.qgate.errorPenalty .* predictionError - ...
        cfg.qgate.temporalPenalty .* temporalNoise));

    adaptiveGate = ...
        precision .* selectiveGate + ...
        (single(1) - precision);

    adaptiveGate = clamp01(adaptiveGate);

    retainedPattern = adaptiveGate .* informationLoad;

    leakedNoise = ...
        (single(1) - precision) .* ...
        (disagreement + predictionError + temporalNoise);

    preSparseOutput = normalize01( ...
        retainedPattern + ...
        cfg.qgate.leakWeight .* leakedNoise, ...
        cfg.robustSampleCount);

    % Soft k-winners-take-all / sparse coding.
    wtaThreshold = samplePercentile( ...
        preSparseOutput, ...
        cfg.qgate.sparsityPercentile, ...
        cfg.robustSampleCount);

    aboveThreshold = preSparseOutput > wtaThreshold;
    belowThreshold = ~aboveThreshold;

    sparseOutput = zeros( ...
        size(preSparseOutput), 'single');

    sparseOutput(aboveThreshold) = ...
        preSparseOutput(aboveThreshold);

    shoulderScale = ...
        max(wtaThreshold, single(1e-7));

    normalizedShoulder = ...
        preSparseOutput(belowThreshold) ./ ...
        shoulderScale;

    sparseOutput(belowThreshold) = ...
        cfg.qgate.softShoulderGain .* ...
        preSparseOutput(belowThreshold) .* ...
        normalizedShoulder .^ ...
        cfg.qgate.softShoulderPower;

    integratedOutput = normalize01( ...
        sparseOutput, cfg.robustSampleCount);

    qGate = struct();
    qGate.informationLoad = informationLoad;
    qGate.spatialDisagreement = spatialDisagreement;
    qGate.temporalNoise = temporalNoise;
    qGate.disagreement = disagreement;
    qGate.predictionError = predictionError;
    qGate.structuredSupport = structuredSupport;
    qGate.localSignalConfidence = localSignalConfidence;
    qGate.noiseAdaptiveWeight = noiseAdaptiveWeight;
    qGate.effectiveNoiseWeight = effectiveNoiseWeight;
    qGate.effectiveErrorWeight = effectiveErrorWeight;
    qGate.qBudget = qBudget;
    qGate.consumedCapacity = consumedCapacity;
    qGate.overload = overload;
    qGate.precision = precision;
    qGate.adaptiveGate = adaptiveGate;
    qGate.preSparseOutput = preSparseOutput;
    qGate.wtaThreshold = wtaThreshold;
    qGate.strongActivationFraction = mean(aboveThreshold, 'all');
    qGate.integratedOutput = integratedOutput;
end

%% ========================================================================
function output = sigmoidLocal(input)

    input = min(max(single(input), single(-40)), single(40));

    output = ...
        single(1) ./ ...
        (single(1) + exp(-input));
end

%% ========================================================================
function network = evolveAdaptiveQByteNetwork( ...
    quant, I0, base, spectral, optical, photo, ...
    retina, relay, v1, qGate, cfg)

    nodeCount = numel(quant.coresX);

    globalNoiseLevel = mean( ...
        min(qGate.overload, single(1)), ...
        'all');

    effectiveSpectralCutoff = computeEffectiveSpectralCutoff( ...
        globalNoiseLevel, cfg);

    if nodeCount < 2

        network = emptyAdaptiveNetwork(cfg);
        network.globalNoiseLevel = globalNoiseLevel;
        network.effectiveSpectralCutoff = effectiveSpectralCutoff;

        if nodeCount == 1

            network.activityMap( ...
                quant.coresY(1), quant.coresX(1)) = single(1);

            network.activityMap = gaussianBlur( ...
                network.activityMap, single(4));

            network.coherentMap = network.activityMap;
        end

        return;
    end

    nodeX = double(quant.coresX(:));
    nodeY = double(quant.coresY(:));

    features = buildNodeFeatures( ...
        nodeX, nodeY, I0, base, spectral, optical, ...
        photo, retina, relay, v1, quant, qGate, cfg);

    intrinsicPhase = double(sampleAtNodes( ...
        v1.phase, nodeX, nodeY));

    nodePrecision = double(sampleAtNodes( ...
        qGate.precision, nodeX, nodeY));

    nodeOverload = double(sampleAtNodes( ...
        qGate.overload, nodeX, nodeY));

    nodeStructure = double(sampleAtNodes( ...
        qGate.structuredSupport, nodeX, nodeY));

    nodePrecision = min(max(nodePrecision, 0), 1);
    nodeOverload = max(nodeOverload, 0);
    nodeStructure = min(max(nodeStructure, 0), 1);

    semanticX = initialSemanticGeometry( ...
        nodeX, nodeY, features, cfg);

    semanticVelocity = zeros(nodeCount, 2);

    featureDistanceSquared = pairwiseSquaredDistance(features);

    featureSimilarity = exp( ...
        -featureDistanceSquared / ...
        (2 * cfg.network.featureSigma ^ 2));

    featureSimilarity(1:nodeCount + 1:end) = 0;

    adjacency = buildInitialAdjacency( ...
        semanticX, featureSimilarity, intrinsicPhase, ...
        nodePrecision, cfg);

    initialAmplitude = sqrt( ...
        max(double(quant.coreScores(:)), 0) .* ...
        (0.25 + 0.75 * nodeStructure) + eps);

    psi = initialAmplitude .* exp(1i * intrinsicPhase);
    psi = psi / max(norm(psi), eps);

    participationTrace = zeros(cfg.network.steps, 1);
    adjacencyMassTrace = zeros(cfg.network.steps, 1);
    maximumDegreeTrace = zeros(cfg.network.steps, 1);
    semanticRadiusTrace = zeros(cfg.network.steps, 1);
    relativeChangeATrace = nan(cfg.network.steps, 1);
    relativeChangeXTrace = nan(cfg.network.steps, 1);

    previousGraphProbability = abs(psi) .^ 2;
    previousAdjacency = adjacency;
    previousSemanticX = semanticX;

    resonance = zeros(nodeCount);
    noiseScore = zeros(nodeCount);

    filteredOperator = buildSpectrallyFilteredOperator( ...
        adjacency, angle(psi), ...
        effectiveSpectralCutoff, cfg);

    stableUpdateCount = 0;
    actualSteps = cfg.network.steps;
    identityMatrix = eye(nodeCount);

    for stepIndex = 1:cfg.network.steps

        graphUpdate = ...
            stepIndex == 1 || ...
            mod(stepIndex - 1, ...
            cfg.network.graphUpdateEvery) == 0;

        if graphUpdate

            currentProbability = abs(psi) .^ 2;
            currentProbability = ...
                currentProbability / ...
                max(sum(currentProbability), eps);

            [adjacency, resonance, noiseScore] = ...
                updateAdaptiveAdjacency( ...
                adjacency, semanticX, featureSimilarity, psi, ...
                currentProbability, previousGraphProbability, ...
                nodePrecision, cfg);

            previousGraphProbability = currentProbability;

            geometryUpdate = ...
                stepIndex == 1 || ...
                mod(stepIndex - 1, ...
                cfg.network.geometryUpdateEvery) == 0;

            if geometryUpdate

                [semanticX, semanticVelocity] = ...
                    updateSemanticGeometry( ...
                    semanticX, semanticVelocity, ...
                    adjacency, resonance, noiseScore, cfg);
            end

            filteredOperator = ...
                buildSpectrallyFilteredOperator( ...
                adjacency, angle(psi), ...
                effectiveSpectralCutoff, cfg);

            relativeChangeA = relativeChange( ...
                adjacency, previousAdjacency);

            relativeChangeX = relativeChange( ...
                semanticX, previousSemanticX);

            relativeChangeATrace(stepIndex) = relativeChangeA;
            relativeChangeXTrace(stepIndex) = relativeChangeX;

            previousAdjacency = adjacency;
            previousSemanticX = semanticX;

            if stepIndex >= cfg.network.minimumSteps && ...
                    relativeChangeA < ...
                    cfg.network.convergenceToleranceA && ...
                    relativeChangeX < ...
                    cfg.network.convergenceToleranceX

                stableUpdateCount = stableUpdateCount + 1;
            else
                stableUpdateCount = 0;
            end
        end

        collapseSpread = ...
            1 + ...
            cfg.network.collapseSpreadGain * ...
            (1 - nodePrecision);

        spreadMatrix = diag(sqrt(collapseSpread));

        Hamiltonian = ...
            spreadMatrix * ...
            filteredOperator * ...
            spreadMatrix;

        localPotential = ...
            cfg.network.potentialGain * ...
            (1 - nodePrecision) + ...
            cfg.network.structurePotentialGain * ...
            (1 - nodeStructure);

        Hamiltonian = ...
            Hamiltonian + diag(localPotential);

        Hamiltonian = ...
            0.5 * (Hamiltonian + Hamiltonian');

        leftMatrix = ...
            identityMatrix + ...
            1i * ...
            (cfg.network.stateDt / 2) * ...
            Hamiltonian;

        rightVector = ...
            (identityMatrix - ...
            1i * ...
            (cfg.network.stateDt / 2) * ...
            Hamiltonian) * psi;

        psi = leftMatrix \ rightVector;

        amplitudeThreshold = ...
            cfg.network.baseAmplitudeThreshold .* ...
            (1 + ...
            cfg.network.collapseThresholdGain * ...
            (1 - nodePrecision) + ...
            cfg.network.overloadThresholdGain * ...
            min(nodeOverload, 4));

        weakActivation = max( ...
            amplitudeThreshold - abs(psi), 0) ./ ...
            (amplitudeThreshold + eps);

        psi = psi .* exp( ...
            -cfg.network.stateDt * ...
            cfg.network.nonlinearDamping * ...
            weakActivation);

        psi = softThresholdComplexState( ...
            psi, amplitudeThreshold);

        if norm(psi) <= 1e-12 || ...
                any(~isfinite(real(psi))) || ...
                any(~isfinite(imag(psi)))

            psi = initialAmplitude .* ...
                exp(1i * intrinsicPhase);

            psi = psi / max(norm(psi), eps);
        else
            psi = psi / norm(psi);
        end

        probability = abs(psi) .^ 2;
        probability = probability / max(sum(probability), eps);

        participationTrace(stepIndex) = ...
            1 / max(sum(probability .^ 2), eps);

        adjacencyMassTrace(stepIndex) = ...
            sum(abs(adjacency), 'all');

        maximumDegreeTrace(stepIndex) = ...
            max(sum(adjacency, 2));

        semanticRadiusTrace(stepIndex) = ...
            sqrt(mean(sum(semanticX .^ 2, 2)));

        if mod(stepIndex, 32) == 0 || ...
                stepIndex == cfg.network.steps

            fprintf( ...
                ['  Adaptive network %d/%d | PR=%.3f | ', ...
                'sum(A)=%.3f | max degree=%.3f | cutoff=%.3f\n'], ...
                stepIndex, cfg.network.steps, ...
                participationTrace(stepIndex), ...
                adjacencyMassTrace(stepIndex), ...
                maximumDegreeTrace(stepIndex), ...
                effectiveSpectralCutoff);
        end

        if stableUpdateCount >= cfg.network.convergencePatience

            actualSteps = stepIndex;

            fprintf( ...
                '  Adaptive steady state reached at step %d.\n', ...
                actualSteps);

            break;
        end
    end

    participationTrace = participationTrace(1:actualSteps);
    adjacencyMassTrace = adjacencyMassTrace(1:actualSteps);
    maximumDegreeTrace = maximumDegreeTrace(1:actualSteps);
    semanticRadiusTrace = semanticRadiusTrace(1:actualSteps);
    relativeChangeATrace = relativeChangeATrace(1:actualSteps);
    relativeChangeXTrace = relativeChangeXTrace(1:actualSteps);

    probability = abs(psi) .^ 2;
    probability = probability / max(sum(probability), eps);

    maps = renderAdaptiveNetworkMaps( ...
        nodeX, nodeY, semanticX, adjacency, psi, cfg);

    degree = sum(adjacency, 2);

    spectralRadius = max(abs(eig( ...
        0.5 * (adjacency + adjacency'))));

    network = struct();
    network.nodeCount = nodeCount;
    network.actualSteps = actualSteps;
    network.adjacency = adjacency;
    network.semanticCoordinates = semanticX;
    network.state = psi;
    network.probability = probability;
    network.resonance = resonance;
    network.noiseScore = noiseScore;
    network.activityMap = maps.activityMap;
    network.semanticMap = maps.semanticMap;
    network.edgeMap = maps.edgeMap;
    network.coherentMap = maps.coherentMap;
    network.semanticPixelX = maps.semanticPixelX;
    network.semanticPixelY = maps.semanticPixelY;
    network.participationTrace = participationTrace;
    network.adjacencyMassTrace = adjacencyMassTrace;
    network.maximumDegreeTrace = maximumDegreeTrace;
    network.semanticRadiusTrace = semanticRadiusTrace;
    network.relativeChangeATrace = relativeChangeATrace;
    network.relativeChangeXTrace = relativeChangeXTrace;

    network.participationRatioFinal = ...
        1 / max(sum(probability .^ 2), eps);

    network.adjacencyEntrywiseL1 = ...
        sum(abs(adjacency), 'all');

    network.maximumDegree = max(degree);
    network.spectralRadius = spectralRadius;

    network.semanticRadius = ...
        sqrt(mean(sum(semanticX .^ 2, 2)));

    network.globalNoiseLevel = globalNoiseLevel;
    network.effectiveSpectralCutoff = effectiveSpectralCutoff;

    network.relativeChangeAFinal = ...
        lastFiniteOrZero(relativeChangeATrace);

    network.relativeChangeXFinal = ...
        lastFiniteOrZero(relativeChangeXTrace);
end

%% ========================================================================
function features = buildNodeFeatures( ...
    nodeX, nodeY, I0, base, spectral, optical, ...
    photo, retina, relay, v1, quant, qGate, cfg)

    featureColumns = [ ...
        double(sampleAtNodes(I0, nodeX, nodeY)), ...
        double(sampleAtNodes(normalize01( ...
        base.magnitude, cfg.robustSampleCount), nodeX, nodeY)), ...
        double(sampleAtNodes(normalize01( ...
        abs(base.laplacian), cfg.robustSampleCount), nodeX, nodeY)), ...
        double(sampleAtNodes(normalize01( ...
        abs(spectral.low), cfg.robustSampleCount), nodeX, nodeY)), ...
        double(sampleAtNodes(normalize01( ...
        abs(spectral.mid), cfg.robustSampleCount), nodeX, nodeY)), ...
        double(sampleAtNodes(normalize01( ...
        abs(spectral.high), cfg.robustSampleCount), nodeX, nodeY)), ...
        double(sampleAtNodes(optical.energy, nodeX, nodeY)), ...
        double(sampleAtNodes(photo.temporalEnergy, nodeX, nodeY)), ...
        double(sampleAtNodes(photo.temporalNoise, nodeX, nodeY)), ...
        double(sampleAtNodes(normalize01( ...
        retina.on + retina.off, cfg.robustSampleCount), nodeX, nodeY)), ...
        double(sampleAtNodes(relay, nodeX, nodeY)), ...
        double(sampleAtNodes(v1.energy, nodeX, nodeY)), ...
        double(sampleAtNodes(v1.phaseCoherence, nodeX, nodeY)), ...
        double(sampleAtNodes(normalize01( ...
        abs(quant.winding), cfg.robustSampleCount), nodeX, nodeY)), ...
        double(sampleAtNodes(qGate.structuredSupport, nodeX, nodeY)), ...
        double(sampleAtNodes(qGate.localSignalConfidence, nodeX, nodeY)), ...
        double(sampleAtNodes(qGate.precision, nodeX, nodeY))];

    featureColumns(~isfinite(featureColumns)) = 0;

    columnMean = mean(featureColumns, 1);
    columnScale = std(featureColumns, 0, 1);
    columnScale(columnScale < 1e-8) = 1;

    features = ...
        (featureColumns - columnMean) ./ columnScale;

    features = tanh(features / 2);

    rowNorm = sqrt(sum(features .^ 2, 2));

    features = ...
        features ./ max(rowNorm, 1e-8);
end

%% ========================================================================
function semanticX = initialSemanticGeometry( ...
    nodeX, nodeY, features, cfg)

    spatialCoordinates = [ ...
        2 * (nodeX - 1) / max(cfg.W - 1, 1) - 1, ...
        2 * (nodeY - 1) / max(cfg.H - 1, 1) - 1];

    spatialCoordinates = ...
        spatialCoordinates - mean(spatialCoordinates, 1);

    featureCoordinates = zeros(size(spatialCoordinates));

    centeredFeatures = ...
        features - mean(features, 1);

    if size(centeredFeatures, 1) >= 2 && ...
            norm(centeredFeatures, 'fro') > 1e-10

        [leftVectors, singularValues, ~] = ...
            svd(centeredFeatures, 'econ');

        availableDimensions = min( ...
            2, size(leftVectors, 2));

        featureCoordinates(:, 1:availableDimensions) = ...
            leftVectors(:, 1:availableDimensions) * ...
            singularValues( ...
            1:availableDimensions, ...
            1:availableDimensions);
    end

    featureCoordinates = ...
        featureCoordinates - mean(featureCoordinates, 1);

    featureRadius = sqrt( ...
        mean(sum(featureCoordinates .^ 2, 2)));

    if featureRadius > 1e-10
        featureCoordinates = ...
            featureCoordinates / featureRadius;
    end

    semanticX = ...
        0.60 * spatialCoordinates + ...
        0.40 * featureCoordinates;

    semanticX = projectSemanticGeometry(semanticX, cfg);
end

%% ========================================================================
function adjacency = buildInitialAdjacency( ...
    semanticX, featureSimilarity, ...
    intrinsicPhase, nodePrecision, cfg)

    nodeCount = size(semanticX, 1);

    geometryDistanceSquared = ...
        pairwiseSquaredDistance(semanticX);

    geometrySimilarity = exp( ...
        -geometryDistanceSquared / ...
        (2 * cfg.network.geometrySigma ^ 2));

    phaseDifference = ...
        intrinsicPhase - intrinsicPhase.';

    phaseResonance = max( ...
        cos(phaseDifference), 0) .^ ...
        cfg.network.phasePower;

    precisionPair = sqrt( ...
        nodePrecision * nodePrecision.');

    candidate = ...
        geometrySimilarity .* ...
        featureSimilarity .* ...
        (cfg.network.phaseFloor + ...
        (1 - cfg.network.phaseFloor) * ...
        phaseResonance) .* ...
        (0.50 + 0.50 * precisionPair);

    candidate(1:nodeCount + 1:end) = 0;

    adjacency = sparsifyTopKSymmetric( ...
        candidate, cfg.network.kNearest);

    adjacency = enforceAdjacencyConstraints( ...
        adjacency, nodePrecision, cfg);
end

%% ========================================================================
function [adjacency, resonance, noiseScore] = ...
    updateAdaptiveAdjacency( ...
    adjacency, semanticX, featureSimilarity, psi, ...
    probability, previousProbability, ...
    nodePrecision, cfg)

    nodeCount = size(adjacency, 1);

    geometryDistanceSquared = ...
        pairwiseSquaredDistance(semanticX);

    geometrySimilarity = exp( ...
        -geometryDistanceSquared / ...
        (2 * cfg.network.geometrySigma ^ 2));

    phase = angle(psi);
    phaseDifference = phase - phase.';
    phaseCosine = cos(phaseDifference);

    phaseResonance = max( ...
        phaseCosine, 0) .^ ...
        cfg.network.phasePower;

    phaseConflict = max(-phaseCosine, 0);

    activitySupport = sqrt( ...
        probability * probability.');

    maximumActivitySupport = ...
        max(activitySupport, [], 'all');

    if maximumActivitySupport > 0
        activitySupport = ...
            activitySupport / maximumActivitySupport;
    end

    instabilityNode = abs( ...
        probability - previousProbability);

    instabilityPair = ...
        0.5 * ...
        (instabilityNode + instabilityNode.');

    precisionPair = sqrt( ...
        nodePrecision * nodePrecision.');

    resonance = ...
        featureSimilarity .* ...
        geometrySimilarity .* ...
        (cfg.network.phaseFloor + ...
        (1 - cfg.network.phaseFloor) * ...
        phaseResonance) .* ...
        (0.25 + 0.75 * activitySupport) .* ...
        (0.50 + 0.50 * precisionPair);

    noiseScore = ...
        phaseConflict + ...
        cfg.network.instabilityWeight * instabilityPair + ...
        cfg.network.featureMismatchWeight * ...
        (1 - featureSimilarity) + ...
        cfg.network.collapseNoiseWeight * ...
        (1 - precisionPair);

    resonance(1:nodeCount + 1:end) = 0;
    noiseScore(1:nodeCount + 1:end) = 0;

    retention = max( ...
        0, ...
        1 - ...
        cfg.network.learningRateA * ...
        cfg.network.weightDecay);

    proposal = ...
        retention * adjacency + ...
        cfg.network.learningRateA * ...
        (resonance - ...
        cfg.network.noisePenalty * noiseScore);

    proposal = max(proposal, 0);
    proposal = 0.5 * (proposal + proposal.');
    proposal(1:nodeCount + 1:end) = 0;

    proposal = softThresholdNonnegative( ...
        proposal, cfg.network.softThresholdA);

    proposal = sparsifyTopKSymmetric( ...
        proposal, ...
        cfg.network.maximumEdgesPerNode);

    adjacency = enforceAdjacencyConstraints( ...
        proposal, nodePrecision, cfg);
end

%% ========================================================================
function adjacency = enforceAdjacencyConstraints( ...
    adjacency, nodePrecision, cfg)

    nodeCount = size(adjacency, 1);

    nodePrecision = double(nodePrecision(:));
    nodePrecision = min(max(nodePrecision, 0), 1);

    localTargetDegree = ...
        cfg.network.targetDegree .* ...
        (cfg.network.precisionDegreeFloor + ...
        cfg.network.precisionDegreeRange .* ...
        nodePrecision);

    localMaximumDegree = ...
        cfg.network.maximumDegree .* ...
        (cfg.network.precisionMaximumDegreeFloor + ...
        cfg.network.precisionMaximumDegreeRange .* ...
        nodePrecision);

    adjacency = max(adjacency, 0);
    adjacency = 0.5 * (adjacency + adjacency.');
    adjacency(1:nodeCount + 1:end) = 0;

    adjacency = min( ...
        adjacency, cfg.network.maximumEdgeWeight);

    for iterationIndex = 1: ...
            cfg.network.constraintIterations

        degree = sum(adjacency, 2);

        desiredScale = sqrt( ...
            localTargetDegree ./ ...
            max(degree, 1e-8));

        desiredScale = ...
            1 + ...
            cfg.network.homeostasisRate * ...
            (desiredScale - 1);

        desiredScale = min(max( ...
            desiredScale, ...
            cfg.network.minimumHomeostasisScale), ...
            cfg.network.maximumHomeostasisScale);

        adjacency = ...
            adjacency .* ...
            (desiredScale * desiredScale.');

        adjacency = min( ...
            max(adjacency, 0), ...
            cfg.network.maximumEdgeWeight);

        adjacency = ...
            0.5 * (adjacency + adjacency.');

        adjacency(1:nodeCount + 1:end) = 0;
    end

    degree = sum(adjacency, 2);

    degreeScale = min( ...
        1, ...
        localMaximumDegree ./ ...
        max(degree, 1e-8));

    adjacency = ...
        adjacency .* ...
        sqrt(degreeScale * degreeScale.');

    globalBudget = ...
        nodeCount * ...
        cfg.network.globalBudgetPerNode;

    adjacencyMass = ...
        sum(abs(adjacency), 'all');

    if adjacencyMass > globalBudget

        adjacency = ...
            adjacency * ...
            (globalBudget / adjacencyMass);
    end

    adjacency = sparsifyTopKSymmetric( ...
        adjacency, ...
        cfg.network.maximumEdgesPerNode);

    adjacency = ...
        0.5 * (adjacency + adjacency.');

    adjacency(1:nodeCount + 1:end) = 0;
end

%% ========================================================================
function effectiveCutoff = ...
    computeEffectiveSpectralCutoff( ...
    globalNoiseLevel, cfg)

    globalNoiseLevel = min(max( ...
        double(globalNoiseLevel), 0), 1);

    effectiveCutoff = ...
        cfg.network.spectralCutoff * ...
        (1 - ...
        cfg.network.cutoffNoiseGain * ...
        globalNoiseLevel);

    effectiveCutoff = min(max( ...
        effectiveCutoff, ...
        cfg.network.minimumSpectralCutoff), ...
        cfg.network.maximumSpectralCutoff);
end

%% ========================================================================
function sparseAdjacency = sparsifyTopKSymmetric( ...
    adjacency, maximumCount)

    nodeCount = size(adjacency, 1);
    keepMask = false(nodeCount);

    for nodeIndex = 1:nodeCount

        row = adjacency(nodeIndex, :);
        row(nodeIndex) = 0;

        [~, order] = sort(row, 'descend');
        positiveOrder = order(row(order) > 0);

        count = min(maximumCount, numel(positiveOrder));

        if count > 0
            keepMask( ...
                nodeIndex, ...
                positiveOrder(1:count)) = true;
        end
    end

    keepMask = keepMask | keepMask.';

    sparseAdjacency = adjacency .* keepMask;

    sparseAdjacency = ...
        0.5 * ...
        (sparseAdjacency + sparseAdjacency.');

    sparseAdjacency(1:nodeCount + 1:end) = 0;
end

%% ========================================================================
function output = softThresholdNonnegative(input, threshold)

    output = max(input - threshold, 0);
end

%% ========================================================================
function filteredOperator = ...
    buildSpectrallyFilteredOperator( ...
    adjacency, phase, effectiveCutoff, cfg)

    nodeCount = size(adjacency, 1);

    phaseDifference = phase - phase.';

    phaseGate = max( ...
        cos(phaseDifference), 0) .^ ...
        cfg.network.phasePower;

    interactionGate = ...
        cfg.network.phaseFloor + ...
        (1 - cfg.network.phaseFloor) * ...
        phaseGate;

    effectiveAdjacency = ...
        adjacency .* interactionGate;

    effectiveAdjacency = ...
        0.5 * ...
        (effectiveAdjacency + ...
        effectiveAdjacency.');

    effectiveAdjacency(1:nodeCount + 1:end) = 0;

    degree = sum(effectiveAdjacency, 2);

    inverseSquareRootDegree = zeros(nodeCount, 1);
    active = degree > 1e-10;

    inverseSquareRootDegree(active) = ...
        1 ./ sqrt(degree(active));

    normalizedAdjacency = ...
        effectiveAdjacency .* ...
        (inverseSquareRootDegree * ...
        inverseSquareRootDegree.');

    normalizedLaplacian = ...
        eye(nodeCount) - normalizedAdjacency;

    isolatedNodes = ~active;
    normalizedLaplacian(isolatedNodes, isolatedNodes) = 0;

    normalizedLaplacian = ...
        0.5 * ...
        (normalizedLaplacian + ...
        normalizedLaplacian.');

    [eigenvectors, eigenvalueMatrix] = ...
        eig(normalizedLaplacian);

    eigenvalues = real(diag(eigenvalueMatrix));
    eigenvalues = min(max(eigenvalues, 0), 2);

    filteredEigenvalues = ...
        eigenvalues .* exp( ...
        -(eigenvalues / effectiveCutoff) .^ ...
        cfg.network.spectralOrder);

    filteredOperator = real( ...
        eigenvectors * ...
        diag(filteredEigenvalues) * ...
        eigenvectors');

    filteredOperator = ...
        0.5 * ...
        (filteredOperator + filteredOperator.');
end

%% ========================================================================
function [semanticX, velocity] = ...
    updateSemanticGeometry( ...
    semanticX, velocity, adjacency, ...
    resonance, noiseScore, cfg)

    nodeCount = size(semanticX, 1);
    force = zeros(nodeCount, 2);

    for nodeIndex = 1:nodeCount

        difference = ...
            semanticX - semanticX(nodeIndex, :);

        distance = sqrt( ...
            sum(difference .^ 2, 2) + 1e-10);

        attractionWeight = ...
            adjacency(nodeIndex, :).' .* ...
            resonance(nodeIndex, :).';

        attractionForce = sum( ...
            difference .* attractionWeight, 1);

        repulsionWeight = ...
            noiseScore(nodeIndex, :).';

        barrier = max( ...
            cfg.network.minimumPairDistance - ...
            distance, 0) ./ ...
            cfg.network.minimumPairDistance;

        repulsionDenominator = ...
            (distance .^ 2 + ...
            cfg.network.minimumPairDistance ^ 2) .^ ...
            1.5;

        repulsionForce = sum( ...
            (-difference) .* ...
            ((repulsionWeight + ...
            cfg.network.barrierGain * barrier) ./ ...
            repulsionDenominator), 1);

        force(nodeIndex, :) = ...
            cfg.network.attractionGain * ...
            attractionForce + ...
            cfg.network.repulsionGain * ...
            repulsionForce - ...
            cfg.network.centerGain * ...
            semanticX(nodeIndex, :);
    end

    force(~isfinite(force)) = 0;

    velocity = ...
        cfg.network.velocityDamping * velocity + ...
        cfg.network.geometryLearningRate * force;

    stepNorm = sqrt(sum(velocity .^ 2, 2));

    stepScale = min( ...
        1, ...
        cfg.network.maximumGeometryStep ./ ...
        max(stepNorm, 1e-10));

    velocity = velocity .* stepScale;
    semanticX = semanticX + velocity;
    semanticX = projectSemanticGeometry(semanticX, cfg);
end

%% ========================================================================
function semanticX = projectSemanticGeometry(semanticX, cfg)

    semanticX(~isfinite(semanticX)) = 0;
    semanticX = semanticX - mean(semanticX, 1);

    currentRadius = sqrt( ...
        mean(sum(semanticX .^ 2, 2)));

    if currentRadius < 1e-10

        nodeCount = size(semanticX, 1);

        angles = linspace( ...
            0, 2 * pi, nodeCount + 1).';

        angles(end) = [];

        semanticX = ...
            cfg.network.targetSemanticRadius * ...
            [cos(angles), sin(angles)];

        currentRadius = ...
            cfg.network.targetSemanticRadius;
    end

    requestedScale = ...
        cfg.network.targetSemanticRadius / ...
        currentRadius;

    requestedScale = min(max( ...
        requestedScale, ...
        1 - cfg.network.radiusCorrectionLimit), ...
        1 + cfg.network.radiusCorrectionLimit);

    semanticX = semanticX * requestedScale;

    nodeRadius = sqrt(sum(semanticX .^ 2, 2));

    nodeScale = min( ...
        1, ...
        cfg.network.maximumSemanticRadius ./ ...
        max(nodeRadius, 1e-10));

    semanticX = semanticX .* nodeScale;
    semanticX = semanticX - mean(semanticX, 1);
end

%% ========================================================================
function outputState = softThresholdComplexState( ...
    inputState, threshold)

    amplitude = abs(inputState);
    phase = angle(inputState);
    threshold = threshold(:);

    outputAmplitude = max(amplitude - threshold, 0);

    outputState = ...
        outputAmplitude .* exp(1i * phase);
end

%% ========================================================================
function maps = renderAdaptiveNetworkMaps( ...
    originalX, originalY, semanticX, ...
    adjacency, psi, cfg)

    probability = abs(psi) .^ 2;
    probability = probability / max(sum(probability), eps);

    activityMap = zeros(cfg.H, cfg.W, 'single');

    for nodeIndex = 1:numel(originalX)

        x = min(max(round(originalX(nodeIndex)), 1), cfg.W);
        y = min(max(round(originalY(nodeIndex)), 1), cfg.H);

        activityMap(y, x) = ...
            activityMap(y, x) + ...
            single(probability(nodeIndex));
    end

    activityMap = normalize01( ...
        gaussianBlur(activityMap, single(4)), ...
        cfg.robustSampleCount);

    semanticPixelX = round( ...
        (semanticX(:, 1) / ...
        (2 * cfg.network.maximumSemanticRadius) + 0.5) * ...
        (cfg.W - 1) + 1);

    semanticPixelY = round( ...
        (semanticX(:, 2) / ...
        (2 * cfg.network.maximumSemanticRadius) + 0.5) * ...
        (cfg.H - 1) + 1);

    semanticPixelX = min(max(semanticPixelX, 1), cfg.W);
    semanticPixelY = min(max(semanticPixelY, 1), cfg.H);

    semanticMap = zeros(cfg.H, cfg.W, 'single');

    for nodeIndex = 1:numel(semanticPixelX)

        semanticMap( ...
            semanticPixelY(nodeIndex), ...
            semanticPixelX(nodeIndex)) = ...
            semanticMap( ...
            semanticPixelY(nodeIndex), ...
            semanticPixelX(nodeIndex)) + ...
            single(probability(nodeIndex));
    end

    semanticMap = normalize01( ...
        gaussianBlur(semanticMap, single(5)), ...
        cfg.robustSampleCount);

    edgeMap = zeros(cfg.H, cfg.W, 'single');
    maximumEdge = max(adjacency, [], 'all');

    if maximumEdge > 0

        edgeThreshold = 0.08 * maximumEdge;

        for sourceIndex = 1:size(adjacency, 1)

            for targetIndex = sourceIndex + 1: ...
                    size(adjacency, 2)

                edgeWeight = ...
                    adjacency(sourceIndex, targetIndex);

                if edgeWeight <= edgeThreshold
                    continue;
                end

                edgeMap = drawLineScalar( ...
                    edgeMap, ...
                    semanticPixelX(sourceIndex), ...
                    semanticPixelY(sourceIndex), ...
                    semanticPixelX(targetIndex), ...
                    semanticPixelY(targetIndex), ...
                    single(edgeWeight / maximumEdge));
            end
        end
    end

    edgeMap = normalize01( ...
        gaussianBlur(edgeMap, single(1.2)), ...
        cfg.robustSampleCount);

    coherentMap = normalize01( ...
        single(0.38) * activityMap + ...
        single(0.34) * semanticMap + ...
        single(0.28) * edgeMap, ...
        cfg.robustSampleCount);

    maps = struct();
    maps.activityMap = activityMap;
    maps.semanticMap = semanticMap;
    maps.edgeMap = edgeMap;
    maps.coherentMap = coherentMap;
    maps.semanticPixelX = semanticPixelX;
    maps.semanticPixelY = semanticPixelY;
end

%% ========================================================================
function image = drawLineScalar( ...
    image, x1, y1, x2, y2, value)

    sampleCount = max( ...
        abs(round(x2) - round(x1)), ...
        abs(round(y2) - round(y1))) + 1;

    sampleCount = max(sampleCount, 2);

    xValues = round(linspace( ...
        double(x1), double(x2), sampleCount));

    yValues = round(linspace( ...
        double(y1), double(y2), sampleCount));

    for sampleIndex = 1:sampleCount

        x = min(max(xValues(sampleIndex), 1), size(image, 2));
        y = min(max(yValues(sampleIndex), 1), size(image, 1));

        image(y, x) = max(image(y, x), value);
    end
end

%% ========================================================================
function samples = sampleAtNodes(field, nodeX, nodeY)

    nodeX = min(max(round(nodeX), 1), size(field, 2));
    nodeY = min(max(round(nodeY), 1), size(field, 1));

    linearIndex = sub2ind(size(field), nodeY, nodeX);

    samples = field(linearIndex);
    samples = samples(:);
end

%% ========================================================================
function distanceSquared = pairwiseSquaredDistance(values)

    squaredNorm = sum(values .^ 2, 2);

    distanceSquared = ...
        squaredNorm + squaredNorm.' - ...
        2 * (values * values.');

    distanceSquared = max(distanceSquared, 0);
end

%% ========================================================================
function value = relativeChange(currentValue, previousValue)

    value = ...
        norm(currentValue - previousValue, 'fro') / ...
        max(norm(previousValue, 'fro'), 1e-10);
end

%% ========================================================================
function value = lastFiniteOrZero(traceValue)

    finiteValue = traceValue(isfinite(traceValue));

    if isempty(finiteValue)
        value = 0;
    else
        value = finiteValue(end);
    end
end

%% ========================================================================
function network = emptyAdaptiveNetwork(cfg)

    zeroMap = zeros(cfg.H, cfg.W, 'single');

    network = struct();
    network.nodeCount = 0;
    network.actualSteps = 0;
    network.adjacency = zeros(0, 0);
    network.semanticCoordinates = zeros(0, 2);
    network.state = zeros(0, 1);
    network.probability = zeros(0, 1);
    network.resonance = zeros(0, 0);
    network.noiseScore = zeros(0, 0);
    network.activityMap = zeroMap;
    network.semanticMap = zeroMap;
    network.edgeMap = zeroMap;
    network.coherentMap = zeroMap;
    network.semanticPixelX = zeros(0, 1);
    network.semanticPixelY = zeros(0, 1);
    network.participationTrace = zeros(0, 1);
    network.adjacencyMassTrace = zeros(0, 1);
    network.maximumDegreeTrace = zeros(0, 1);
    network.semanticRadiusTrace = zeros(0, 1);
    network.relativeChangeATrace = zeros(0, 1);
    network.relativeChangeXTrace = zeros(0, 1);
    network.participationRatioFinal = 0;
    network.adjacencyEntrywiseL1 = 0;
    network.maximumDegree = 0;
    network.spectralRadius = 0;
    network.semanticRadius = 0;
    network.globalNoiseLevel = 0;
    network.effectiveSpectralCutoff = ...
        cfg.network.spectralCutoff;
    network.relativeChangeAFinal = 0;
    network.relativeChangeXFinal = 0;
end


%% ========================================================================
function finalRGB = composeSingleImage( ...
    I0_RGB, IA_RGB, base, optical, photo, v1, quant, ...
    gradientState, layers, qGate, network, cfg)

    weightField = reshape(cfg.fusionWeights, 1, 1, []);

    fusionEnergy = sqrt( ...
        sum(layers .^ 2 .* weightField, 3) / ...
        sum(cfg.fusionWeights));

    fusionEnergy = normalize01( ...
        fusionEnergy, cfg.robustSampleCount);

    gradientHue = mod( ...
        (gradientState.angle + pi) / (2 * pi), 1);

    gradientSaturation = clamp01( ...
        single(0.50) + ...
        single(0.25) * base.coherence + ...
        single(0.25) * v1.orientationCoherence);

    gradientValue = clamp01( ...
        fusionEnergy .* ...
        (single(0.28) + ...
        single(0.72) * gradientState.energy));

    gradientRGB = single(hsv2rgb(cat( ...
        3, gradientHue, gradientSaturation, gradientValue)));

    coneRGB = clamp01(cat( ...
        3, optical.Q(:, :, 1), ...
        optical.Q(:, :, 2), ...
        optical.Q(:, :, 3)));

    phaseHue = mod( ...
        (v1.phase + pi) / (2 * pi), 1);

    phaseRGB = single(hsv2rgb(cat( ...
        3, phaseHue, ...
        clamp01(single(0.42) + ...
        single(0.58) * v1.phaseCoherence), ...
        clamp01(v1.energy .* ...
        (single(0.20) + ...
        single(0.80) * v1.phaseCoherence)))));

    temporalHue = mod( ...
        (photo.temporalPhase + pi) / (2 * pi) + ...
        single(0.08) * gradientHue + ...
        single(0.04) * photo.temporalPhaseVelocity, 1);

    temporalSaturation = clamp01( ...
        single(0.52) + ...
        single(0.34) * photo.temporalPhaseCoherence + ...
        single(0.14) * qGate.precision);

    temporalValue = normalize01( ...
        single(0.30) * photo.temporalEnergy + ...
        single(0.22) * photo.temporalVariance + ...
        single(0.20) * photo.temporalTrail + ...
        single(0.18) * photo.temporalPhaseVelocity + ...
        single(0.10) * fusionEnergy, ...
        cfg.robustSampleCount);

    temporalValue = clamp01( ...
        temporalValue .* ...
        (single(0.30) + ...
        single(0.70) * photo.temporalPhaseCoherence));

    temporalRGB = single(hsv2rgb(cat( ...
        3, temporalHue, temporalSaturation, temporalValue)));

    qGateRGB = clamp01(cat( ...
        3, normalize01(qGate.overload, ...
        cfg.robustSampleCount), ...
        qGate.integratedOutput, qGate.precision));

    networkRGB = clamp01(cat( ...
        3, network.semanticMap, ...
        network.edgeMap, network.activityMap));

    oppositionRGB = clamp01(cat( ...
        3, normalize01(max( ...
        gradientState.divergence, 0), ...
        cfg.robustSampleCount), ...
        normalize01(abs(gradientState.curl), ...
        cfg.robustSampleCount), ...
        normalize01(max( ...
        -gradientState.divergence, 0), ...
        cfg.robustSampleCount)));

    gateRGB = repmat(fusionEnergy, 1, 1, 3);
    coherentRGB = repmat( ...
        network.coherentMap, 1, 1, 3);
    precisionRGB = repmat( ...
        qGate.precision, 1, 1, 3);
    confidenceRGB = repmat( ...
        qGate.localSignalConfidence, 1, 1, 3);

    finalRGB = ...
        single(0.20) * IA_RGB + ...
        single(0.10) * I0_RGB + ...
        single(0.17) * gradientRGB .* gateRGB + ...
        single(0.10) * coneRGB .* gateRGB + ...
        single(0.10) * phaseRGB .* coherentRGB + ...
        single(0.23) * temporalRGB .* ...
        (single(0.35) + single(0.65) * precisionRGB) + ...
        single(0.04) * qGateRGB .* confidenceRGB + ...
        single(0.04) * networkRGB .* coherentRGB + ...
        single(0.02) * oppositionRGB .* gateRGB;

    livingPulse = single(0.5) + single(0.5) * ...
        sin(photo.temporalPhase + ...
        single(1.75) * gradientState.angle);

    livingPulse = normalize01( ...
        livingPulse .* ...
        photo.temporalPhaseCoherence .* ...
        (single(0.25) + ...
        single(0.75) * photo.temporalPhaseVelocity), ...
        cfg.robustSampleCount);

    livingGlow = gaussianBlur( ...
        livingPulse + quant.coreGlow, ...
        cfg.render.glowSigma);

    finalRGB(:, :, 1) = finalRGB(:, :, 1) + ...
        single(0.10) * livingPulse + ...
        single(0.08) * livingGlow;

    finalRGB(:, :, 2) = finalRGB(:, :, 2) + ...
        single(0.18) * livingPulse + ...
        single(0.13) * livingGlow + ...
        single(0.20) * quant.coreGlow;

    finalRGB(:, :, 3) = finalRGB(:, :, 3) + ...
        single(0.26) * livingPulse + ...
        single(0.18) * livingGlow + ...
        single(0.30) * quant.coreGlow;

    finalRGB = max(finalRGB, 0);
    finalRGB = finalRGB ./ ...
        (single(0.82) + single(0.18) * finalRGB);
    finalRGB = clamp01(finalRGB);
end

%% ========================================================================
function [xSelected, ySelected, scoreSelected] = ...
    selectSeparatedCandidates( ...
    candidateMask, scoreMap, ...
    maximumCount, minimumDistance)

    [allY, allX] = find(candidateMask);

    if isempty(allX)

        xSelected = zeros(0, 1);
        ySelected = zeros(0, 1);
        scoreSelected = zeros(0, 1, 'single');

        return;
    end

    linearIndices = ...
        sub2ind(size(scoreMap), allY, allX);

    allScores = scoreMap(linearIndices);

    [allScores, order] = ...
        sort(allScores, 'descend');

    allX = allX(order) + 1;
    allY = allY(order) + 1;

    xSelected = zeros(maximumCount, 1);
    ySelected = zeros(maximumCount, 1);
    scoreSelected = zeros(maximumCount, 1, 'single');

    selectedCount = 0;
    minimumDistanceSquared = minimumDistance ^ 2;

    for candidateIndex = 1:numel(allX)

        candidateX = allX(candidateIndex);
        candidateY = allY(candidateIndex);

        if selectedCount > 0

            distanceSquared = ...
                (xSelected(1:selectedCount) - candidateX) .^ 2 + ...
                (ySelected(1:selectedCount) - candidateY) .^ 2;

            if any(distanceSquared < minimumDistanceSquared)
                continue;
            end
        end

        selectedCount = selectedCount + 1;

        xSelected(selectedCount) = candidateX;
        ySelected(selectedCount) = candidateY;
        scoreSelected(selectedCount) = ...
            allScores(candidateIndex);

        if selectedCount >= maximumCount
            break;
        end
    end

    xSelected = xSelected(1:selectedCount);
    ySelected = ySelected(1:selectedCount);
    scoreSelected = scoreSelected(1:selectedCount);
end

%% ========================================================================
function derivative = gradientComponent(field, dimensionIndex)

    derivative = zeros(size(field), 'single');

    if dimensionIndex == 1

        derivative(2:end-1, :) = ...
            single(0.5) * ...
            (field(3:end, :) - field(1:end-2, :));

        derivative(1, :) = ...
            field(2, :) - field(1, :);

        derivative(end, :) = ...
            field(end, :) - field(end-1, :);

    else

        derivative(:, 2:end-1) = ...
            single(0.5) * ...
            (field(:, 3:end) - field(:, 1:end-2));

        derivative(:, 1) = ...
            field(:, 2) - field(:, 1);

        derivative(:, end) = ...
            field(:, end) - field(:, end-1);
    end
end

%% ========================================================================
function blurred = gaussianBlur(field, sigma)

    sigma = double(sigma);

    if sigma <= 0
        blurred = field;
        return;
    end

    radius = max(1, ceil(3.5 * sigma));

    axisValues = single(-radius:radius);

    kernel = exp( ...
        single(-0.5) * ...
        (axisValues / single(sigma)) .^ 2);

    kernel = kernel / sum(kernel);

    blurred = conv2( ...
        conv2(single(field), kernel, 'same'), ...
        kernel.', 'same');
end

%% ========================================================================
function [frequencyX, frequencyY] = frequencyGrid(H, W)

    horizontalFrequency = single(ifftshift( ...
        (-floor(W / 2):ceil(W / 2) - 1) / W));

    verticalFrequency = single(ifftshift( ...
        (-floor(H / 2):ceil(H / 2) - 1) / H));

    [frequencyX, frequencyY] = ...
        meshgrid(horizontalFrequency, verticalFrequency);
end

%% ========================================================================
function normalized = robustSignedNormalize(field, sampleCount)

    field = single(field);

    finiteMask = isfinite(field);
    values = field(finiteMask);

    if isempty(values)

        normalized = zeros(size(field), 'single');

        return;
    end

    sampleStep = max( ...
        1, floor(numel(values) / sampleCount));

    sample = double(values(1:sampleStep:end));

    center = median(sample);

    scale = ...
        1.4826 * median(abs(sample - center));

    if ~isfinite(scale) || scale < 1e-12
        scale = std(sample);
    end

    if ~isfinite(scale) || scale < 1e-12
        scale = 1;
    end

    normalized = single( ...
        (double(field) - center) / (3 * scale));

    normalized = tanh(normalized);
    normalized(~finiteMask) = 0;
end

%% ========================================================================
function normalized = normalize01(field, sampleCount)

    field = single(real(field));

    lowerValue = samplePercentile( ...
        field, 0.5, sampleCount);

    upperValue = samplePercentile( ...
        field, 99.5, sampleCount);

    if ~isfinite(lowerValue) || ...
            ~isfinite(upperValue) || ...
            upperValue <= lowerValue

        lowerValue = min(field, [], 'all');
        upperValue = max(field, [], 'all');
    end

    if upperValue <= lowerValue

        normalized = zeros(size(field), 'single');

    else

        normalized = clamp01( ...
            (field - lowerValue) / ...
            (upperValue - lowerValue));
    end
end

%% ========================================================================
function value = samplePercentile(field, percentile, sampleCount)

    values = field(isfinite(field));

    if isempty(values)

        value = single(0);

        return;
    end

    sampleStep = max( ...
        1, floor(numel(values) / sampleCount));

    sample = sort(single(values(1:sampleStep:end)));

    position = ...
        1 + ...
        (numel(sample) - 1) * ...
        double(percentile) / 100;

    lowerIndex = max(1, floor(position));
    upperIndex = min(numel(sample), ceil(position));
    fraction = single(position - lowerIndex);

    value = ...
        sample(lowerIndex) * (1 - fraction) + ...
        sample(upperIndex) * fraction;
end

%% ========================================================================
function linearRGB = srgbDecode(rgb)

    rgb = clamp01(single(rgb));

    linearRGB = zeros(size(rgb), 'single');

    mask = rgb <= single(0.04045);

    linearRGB(mask) = ...
        rgb(mask) / single(12.92);

    linearRGB(~mask) = ...
        ((rgb(~mask) + single(0.055)) / ...
        single(1.055)) .^ single(2.4);
end

%% ========================================================================
function rgb = srgbEncode(linearRGB)

    linearRGB = max(single(linearRGB), 0);

    rgb = zeros(size(linearRGB), 'single');

    mask = ...
        linearRGB <= single(0.0031308);

    rgb(mask) = ...
        single(12.92) * linearRGB(mask);

    rgb(~mask) = ...
        single(1.055) * ...
        linearRGB(~mask) .^ single(1 / 2.4) - ...
        single(0.055);

    rgb = clamp01(rgb);
end

%% ========================================================================
function luminance = rgbLuminance(rgb)

    luminance = ...
        single(0.2126) * rgb(:, :, 1) + ...
        single(0.7152) * rgb(:, :, 2) + ...
        single(0.0722) * rgb(:, :, 3);
end

%% ========================================================================
function output = clamp01(input)

    output = min( ...
        max(single(input), single(0)), ...
        single(1));
end

%% ========================================================================
function wrapped = wrapToPiLocal(angleField)

    wrapped = ...
        mod( ...
        angleField + single(pi), ...
        single(2 * pi)) - ...
        single(pi);
end

%% ========================================================================
function image8 = toUint8(imageSingle)

    image8 = uint8(round( ...
        255 * double(clamp01(imageSingle))));
end

% ========================================================================
function writeRGB16Temporal(rgbInput, outputFile, cfg)

    rgb = clamp01(single(rgbInput));

    if size(rgb, 1) ~= cfg.render.outputSize || ...
            size(rgb, 2) ~= cfg.render.outputSize
        rgb = imresize( ...
            rgb, ...
            [cfg.render.outputSize, cfg.render.outputSize], ...
            'bicubic', 'Antialiasing', true);
    end

    glow = zeros(size(rgb), 'single');

    for channelIndex = 1:3
        glow(:, :, channelIndex) = imgaussfilt( ...
            rgb(:, :, channelIndex), ...
            double(cfg.render.glowSigma));
    end

    rgb = clamp01( ...
        rgb + cfg.render.glowAmount * glow);

    blurred = zeros(size(rgb), 'single');

    for channelIndex = 1:3
        blurred(:, :, channelIndex) = imgaussfilt( ...
            rgb(:, :, channelIndex), ...
            double(cfg.render.sharpenSigma));
    end

    rgb = clamp01( ...
        rgb + cfg.render.sharpenAmount * ...
        (rgb - blurred));

    rgb = clamp01( ...
        rgb .^ (single(1) / cfg.render.gamma));

    imwrite(uint16(round(rgb * single(65535))), ...
        outputFile, 'png');
end

% ========================================================================
function [tensors, matFile, h5File] = exportTensorFiles( ...
    I0_RGB, IA_RGB, base, optical, photo, v1, quant, ...
    gradientState, layers, qGate, network, finalRGB, ...
    outputImage)

    tensorOutputDir = fullfile( ...
        fileparts(outputImage), 'tensor_exports');

    if ~isfolder(tensorOutputDir)
        mkdir(tensorOutputDir);
    end

    tensorTag = datestr(now, 'yyyymmdd_HHMMSS_FFF');

    baseName = [ ...
        'Yehoshua_System_Gradient_v4_tensors_' tensorTag];

    matFile = fullfile(tensorOutputDir, [baseName '.mat']);
    h5File = fullfile(tensorOutputDir, [baseName '.h5']);

    tensors = struct();

    tensors.input.original_rgb = single(I0_RGB);
    tensors.input.adaptive_rgb = single(IA_RGB);

    tensors.base.coherence = single(base.coherence);

    tensors.optical.Q = single(optical.Q);

    tensors.photo.mean_voltage = single(photo.meanVoltage);
    tensors.photo.voltage = single(photo.voltage);
    tensors.photo.cgmp = single(photo.cgmp);
    tensors.photo.glutamate = single(photo.glutamate);
    tensors.photo.temporal_energy = ...
        single(photo.temporalEnergy);
    tensors.photo.temporal_variance = ...
        single(photo.temporalVariance);
    tensors.photo.temporal_noise = ...
        single(photo.temporalNoise);
    tensors.photo.temporal_phase = ...
        single(photo.temporalPhase);
    tensors.photo.temporal_phase_coherence = ...
        single(photo.temporalPhaseCoherence);
    tensors.photo.temporal_phase_velocity = ...
        single(photo.temporalPhaseVelocity);
    tensors.photo.temporal_trail = ...
        single(photo.temporalTrail);

    tensors.v1.energy = single(v1.energy);
    tensors.v1.phase = single(v1.phase);
    tensors.v1.phase_coherence = single(v1.phaseCoherence);
    tensors.v1.orientation_coherence = ...
        single(v1.orientationCoherence);

    tensors.quant.core_glow = single(quant.coreGlow);

    tensors.gradient.angle = single(gradientState.angle);
    tensors.gradient.energy = single(gradientState.energy);
    tensors.gradient.divergence = ...
        single(gradientState.divergence);
    tensors.gradient.curl = single(gradientState.curl);
    tensors.gradient.layers = single(layers);

    tensors.qgate.precision = single(qGate.precision);
    tensors.qgate.overload = single(qGate.overload);
    tensors.qgate.integrated_output = ...
        single(qGate.integratedOutput);
    tensors.qgate.local_signal_confidence = ...
        single(qGate.localSignalConfidence);

    tensors.network.semantic_map = single(network.semanticMap);
    tensors.network.edge_map = single(network.edgeMap);
    tensors.network.activity_map = single(network.activityMap);
    tensors.network.coherent_map = single(network.coherentMap);

    tensors.output.final_rgb = single(finalRGB);

    metadata = struct();
    metadata.version = ...
        'Yehoshua_System_Gradient_integration_v4_temporal_living';
    metadata.source_file = ...
        ['/MATLAB Drive/modelTRAINING/' ...
         'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
    metadata.dataset_path = ...
        '/n_5_composite_field_1000x1000/data';
    metadata.source_sha256 = ...
        ['5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97' ...
         'c914b7d3306013'];
    metadata.output_image = outputImage;
    metadata.created_local = datestr(now, 31);

    save(matFile, 'tensors', 'metadata', '-v7.3');

    writeTensorH5(h5File, '/input/original_rgb', ...
        tensors.input.original_rgb);
    writeTensorH5(h5File, '/input/adaptive_rgb', ...
        tensors.input.adaptive_rgb);
    writeTensorH5(h5File, '/base/coherence', ...
        tensors.base.coherence);
    writeTensorH5(h5File, '/optical/Q', tensors.optical.Q);

    writeTensorH5(h5File, '/photo/mean_voltage', ...
        tensors.photo.mean_voltage);
    writeTensorH5(h5File, '/photo/voltage', ...
        tensors.photo.voltage);
    writeTensorH5(h5File, '/photo/cgmp', tensors.photo.cgmp);
    writeTensorH5(h5File, '/photo/glutamate', ...
        tensors.photo.glutamate);
    writeTensorH5(h5File, '/photo/temporal_energy', ...
        tensors.photo.temporal_energy);
    writeTensorH5(h5File, '/photo/temporal_variance', ...
        tensors.photo.temporal_variance);
    writeTensorH5(h5File, '/photo/temporal_noise', ...
        tensors.photo.temporal_noise);
    writeTensorH5(h5File, '/photo/temporal_phase', ...
        tensors.photo.temporal_phase);
    writeTensorH5(h5File, ...
        '/photo/temporal_phase_coherence', ...
        tensors.photo.temporal_phase_coherence);
    writeTensorH5(h5File, ...
        '/photo/temporal_phase_velocity', ...
        tensors.photo.temporal_phase_velocity);
    writeTensorH5(h5File, '/photo/temporal_trail', ...
        tensors.photo.temporal_trail);

    writeTensorH5(h5File, '/v1/energy', tensors.v1.energy);
    writeTensorH5(h5File, '/v1/phase', tensors.v1.phase);
    writeTensorH5(h5File, '/v1/phase_coherence', ...
        tensors.v1.phase_coherence);
    writeTensorH5(h5File, '/v1/orientation_coherence', ...
        tensors.v1.orientation_coherence);

    writeTensorH5(h5File, '/quant/core_glow', ...
        tensors.quant.core_glow);

    writeTensorH5(h5File, '/gradient/angle', ...
        tensors.gradient.angle);
    writeTensorH5(h5File, '/gradient/energy', ...
        tensors.gradient.energy);
    writeTensorH5(h5File, '/gradient/divergence', ...
        tensors.gradient.divergence);
    writeTensorH5(h5File, '/gradient/curl', ...
        tensors.gradient.curl);
    writeTensorH5(h5File, '/gradient/layers', ...
        tensors.gradient.layers);

    writeTensorH5(h5File, '/qgate/precision', ...
        tensors.qgate.precision);
    writeTensorH5(h5File, '/qgate/overload', ...
        tensors.qgate.overload);
    writeTensorH5(h5File, '/qgate/integrated_output', ...
        tensors.qgate.integrated_output);
    writeTensorH5(h5File, ...
        '/qgate/local_signal_confidence', ...
        tensors.qgate.local_signal_confidence);

    writeTensorH5(h5File, '/network/semantic_map', ...
        tensors.network.semantic_map);
    writeTensorH5(h5File, '/network/edge_map', ...
        tensors.network.edge_map);
    writeTensorH5(h5File, '/network/activity_map', ...
        tensors.network.activity_map);
    writeTensorH5(h5File, '/network/coherent_map', ...
        tensors.network.coherent_map);

    writeTensorH5(h5File, '/output/final_rgb', ...
        tensors.output.final_rgb);

    h5writeatt(h5File, '/', 'version', metadata.version);
    h5writeatt(h5File, '/', 'source_file', ...
        metadata.source_file);
    h5writeatt(h5File, '/', 'dataset_path', ...
        metadata.dataset_path);
    h5writeatt(h5File, '/', 'source_sha256', ...
        metadata.source_sha256);
    h5writeatt(h5File, '/', 'output_image', ...
        metadata.output_image);
    h5writeatt(h5File, '/', 'created_local', ...
        metadata.created_local);

    disp(' ');
    disp(['Tensor MAT: ' matFile]);
    disp(['Tensor H5: ' h5File]);
end

function writeTensorH5(h5File,datasetPath,data)
    data=single(data);
    dimensions=size(data);
    if isscalar(data)
        data=reshape(data,[1 1]);
        dimensions=[1 1];
    end
    chunkSize=dimensions;
    chunkSize(1)=min(chunkSize(1),128);
    if numel(chunkSize)>=2
        chunkSize(2)=min(chunkSize(2),128);
    end
    for dimensionIndex=3:numel(chunkSize)
        chunkSize(dimensionIndex)=min(chunkSize(dimensionIndex),8);
    end
    h5create(h5File,datasetPath,dimensions,'Datatype','single','ChunkSize',chunkSize,'Deflate',4);
    h5write(h5File,datasetPath,data);
end
