function results = Yehoshua_System_Gradient_integration()
% Yehoshua&System_Gradient_integration
%
% Save this file exactly as:
%   Yehoshua_System_Gradient_integration.m
%
% The generated image is named:
%   Yehoshua&System_Gradient_integration_<timestamp>.png
%
% Input:
%   Read-only canonical H5 source and canonical dataset only.
%
% Output:
%   Exactly one PNG image per run.
%
% No PNG is used as input.
% No derived H5, MAT, CSV, JSON, contact sheet, figure, or exportgraphics
% operation is created.

    clc;
    format compact;
    rng(2511, 'twister');

    cfg = configuration();
    validateCanonicalSource(cfg);

    fprintf('\n============================================================\n');
    fprintf(' Yehoshua&System_Gradient_integration\n');
    fprintf(' Canonical H5 -> one integrated image\n');
    fprintf('============================================================\n\n');

    totalTimer = tic;

    %% 01. Canonical H5
    fprintf('[01/10] Reading canonical H5 dataset...\n');

    raw = h5read(cfg.sourceFile, cfg.datasetPath);
    cube = decodeCanonicalLayoutB(raw, cfg);
    clear raw;

    %% 02. Five-channel source integration
    fprintf('[02/10] Integrating five source channels...\n');

    [I0, channelWeights] = integrateFiveChannels(cube, cfg);
    clear cube;

    %% 03. Differential, multiscale, and spectral fields
    fprintf('[03/10] Differential, multiscale, and spectral computation...\n');

    base = computeDifferentialFields(I0, cfg);
    multiscale = computeMultiscaleFields(I0, cfg);
    spectral = computeSpectralFields(I0, cfg);

    %% 04. RGB and Apple display operator
    fprintf('[04/10] Source RGB and Apple display operator...\n');

    I0_RGB = buildSourceRGB(I0, base, multiscale, spectral, cfg);
    IA_RGB = applyAppleDisplayOperator(I0_RGB, cfg);

    %% 05. Optical field and cone responses
    fprintf('[05/10] Optical field and L/M/S responses...\n');

    optical = computeOpticalConeFields(IA_RGB, cfg);

    %% 06. Phototransduction and retina
    fprintf('[06/10] Phototransduction and retinal processing...\n');

    photo = simulatePhototransduction(optical.Q, cfg);
    retina = computeRetinalFields(optical.Q, photo, cfg);
    relay = computeRelayField(retina, cfg);

    %% 07. V1 complex bank
    fprintf('[07/10] V1 oriented complex bank...\n');

    v1 = computeV1ComplexBank(relay, retina, cfg);

    %% 08. Quantization field
    fprintf('[08/10] Phase winding and vortex-core field...\n');

    quant = computeQuantizationField(v1, base, cfg);

    %% 09. Yehoshua&System gradient integration
    fprintf('[09/10] Yehoshua&System gradient integration...\n');

    gradientState = computeGradientIntegration( ...
        base, multiscale, spectral, optical, photo, ...
        retina, relay, v1, quant, cfg);

    finalRGB = composeSingleImage( ...
        I0_RGB, IA_RGB, I0, base, multiscale, spectral, optical, ...
        photo, retina, relay, v1, quant, gradientState, cfg);

    %% 10. Exactly one image
    fprintf('[10/10] Writing one PNG image...\n');

    if ~exist(cfg.outputFolder, 'dir')
        mkdir(cfg.outputFolder);
    end

    runTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));

    outputFile = fullfile( ...
        cfg.outputFolder, ...
        ['Yehoshua&System_Gradient_integration_' runTag '.png']);

    imwrite(toUint8(finalRGB), outputFile, 'png');

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
    results.runtime_seconds = elapsed;
end

%% ========================================================================
function cfg = configuration()

    cfg = struct();

    cfg.gradientDisplayName = ...
        'Yehoshua&System_Gradient_integration';

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

    cfg.display.colorMatrix = eye(3, 'single');
    cfg.display.whiteGain = single([1, 1, 1]);
    cfg.display.brightness = single(1);
    cfg.display.spatialSigma = single(0.35);
    cfg.display.shoulder = single(0.08);

    cfg.optics.lambdaNm = single((380:5:780)');
    cfg.optics.primaryCentersNm = single([620, 535, 460]);
    cfg.optics.primaryWidthsNm = single([22, 20, 18]);
    cfg.optics.coneCentersNm = single([565, 535, 445]);
    cfg.optics.coneWidthsNm = single([42, 38, 28]);

    cfg.photo.steps = 192;
    cfg.photo.dt = single(0.0125);
    cfg.photo.modulationDepth = single(0.025);
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

    cfg.retina.centerSigma = single(1.2);
    cfg.retina.surroundSigma = single(5.5);
    cfg.retina.divisiveSigma = single(7.5);
    cfg.retina.divisiveEpsilon = single(0.06);

    cfg.v1.numberOfAngles = 16;
    cfg.v1.wavelengthPixels = ...
        single([4, 6, 9, 13, 19, 28, 42]);
    cfg.v1.frequencySigmaRatio = single(0.36);
    cfg.v1.inputChromaticWeight = single(0.22);
    cfg.v1.inputTemporalWeight = single(0.18);

    cfg.quant.maxCores = 96;
    cfg.quant.minimumDistance = 14;
    cfg.quant.windingThreshold = single(0.32);
    cfg.quant.energyPercentile = 72;

    % The 16 documented image layers fused into one image.
    cfg.fusionWeights = single([ ...
        0.90, ... % 01 I0 source RGB luminance
        1.00, ... % 02 IA display RGB luminance
        0.90, ... % 03 canonical integrated field
        1.25, ... % 04 gradient magnitude
        0.90, ... % 05 Laplacian
        1.00, ... % 06 multiscale DoG
        0.80, ... % 07 FFT magnitude
        0.85, ... % 08 optical energy
        0.70, ... % 09 qL
        0.70, ... % 10 qM
        0.70, ... % 11 qS
        0.85, ... % 12 photoreceptor voltage
        1.00, ... % 13 retinal ON+OFF
        0.95, ... % 14 relay
        1.20, ... % 15 V1 energy
        1.35]);    % 16 gradient integration
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

    opsin = zeros(cfg.H, cfg.W, 'single');
    transducin = zeros(cfg.H, cfg.W, 'single');
    pde6 = zeros(cfg.H, cfg.W, 'single');
    cgmp = ones(cfg.H, cfg.W, 'single');

    voltage = ...
        cfg.photo.vDark * ones(cfg.H, cfg.W, 'single');

    meanVoltage = zeros(cfg.H, cfg.W, 'single');
    temporalEnergy = zeros(cfg.H, cfg.W, 'single');
    previousVoltage = voltage;

    shiftPattern = [ ...
         0,  0; ...
         1,  0; ...
         0,  1; ...
        -1,  0; ...
         0, -1; ...
         1,  1; ...
        -1,  1; ...
        -1, -1; ...
         1, -1];

    for stepIndex = 1:cfg.photo.steps

        phase = single( ...
            2 * pi * (stepIndex - 1) / 12);

        modulation = ...
            single(1) + ...
            cfg.photo.modulationDepth * sin(phase);

        shift = shiftPattern( ...
            mod(stepIndex - 1, size(shiftPattern, 1)) + 1, :);

        stimulus = clamp01( ...
            circshift(stimulusBase, shift) * modulation);

        opsin = opsin + cfg.photo.dt * ( ...
            cfg.photo.opsinOn * stimulus .* (1 - opsin) - ...
            cfg.photo.opsinOff * opsin);

        opsin = clamp01(opsin);

        transducin = transducin + cfg.photo.dt * ( ...
            cfg.photo.transducinOn * ...
            opsin .* (1 - transducin) - ...
            cfg.photo.transducinOff * transducin);

        transducin = clamp01(transducin);

        pde6 = pde6 + cfg.photo.dt * ( ...
            cfg.photo.pdeOn * ...
            transducin .* (1 - pde6) - ...
            cfg.photo.pdeOff * pde6);

        pde6 = clamp01(pde6);

        cgmp = cgmp + cfg.photo.dt * ( ...
            cfg.photo.cgmpSynthesis * (1 - cgmp) - ...
            cfg.photo.cgmpHydrolysis * pde6 .* cgmp);

        cgmp = clamp01(cgmp);

        numerator = cgmp .^ cfg.photo.cngHill;

        denominator = ...
            numerator + ...
            cfg.photo.cngK .^ cfg.photo.cngHill;

        cng = ...
            numerator ./ (denominator + single(1e-7));

        voltage = ...
            cfg.photo.vDark - ...
            cfg.photo.hyperGain * (1 - cng);

        voltageDifference = ...
            voltage - previousVoltage;

        temporalEnergy = ...
            temporalEnergy + voltageDifference .^ 2;

        meanVoltage = meanVoltage + voltage;
        previousVoltage = voltage;

        if mod(stepIndex, 16) == 0 || ...
                stepIndex == cfg.photo.steps

            fprintf( ...
                '  Transduction %d/%d\n', ...
                stepIndex, cfg.photo.steps);
        end
    end

    meanVoltage = meanVoltage / cfg.photo.steps;

    glutamate = ...
        single(1) ./ ...
        (single(1) + exp( ...
        -(voltage - cfg.photo.glutamateTheta) / ...
        cfg.photo.glutamateSlope));

    photo = struct();
    photo.meanVoltage = meanVoltage;
    photo.voltage = voltage;
    photo.cgmp = cgmp;
    photo.glutamate = glutamate;

    photo.temporalEnergy = normalize01( ...
        sqrt(temporalEnergy / cfg.photo.steps), ...
        cfg.robustSampleCount);
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
function finalRGB = composeSingleImage( ...
    I0_RGB, IA_RGB, I0, base, multiscale, spectral, optical, ...
    photo, retina, relay, v1, quant, gradientState, cfg)

    layers = zeros(cfg.H, cfg.W, 16, 'single');

    layers(:, :, 1) = rgbLuminance(I0_RGB);
    layers(:, :, 2) = rgbLuminance(IA_RGB);
    layers(:, :, 3) = normalize01( ...
        abs(I0), cfg.robustSampleCount);
    layers(:, :, 4) = normalize01( ...
        base.magnitude, cfg.robustSampleCount);
    layers(:, :, 5) = normalize01( ...
        abs(base.laplacian), cfg.robustSampleCount);
    layers(:, :, 6) = normalize01( ...
        multiscale.dogEnergy, cfg.robustSampleCount);
    layers(:, :, 7) = normalize01( ...
        spectral.fftLogMagnitude, cfg.robustSampleCount);
    layers(:, :, 8) = optical.energy;
    layers(:, :, 9) = optical.Q(:, :, 1);
    layers(:, :, 10) = optical.Q(:, :, 2);
    layers(:, :, 11) = optical.Q(:, :, 3);
    layers(:, :, 12) = normalize01( ...
        -photo.meanVoltage, cfg.robustSampleCount);
    layers(:, :, 13) = normalize01( ...
        retina.on + retina.off, cfg.robustSampleCount);
    layers(:, :, 14) = relay;
    layers(:, :, 15) = v1.energy;
    layers(:, :, 16) = gradientState.energy;

    weightField = reshape( ...
        cfg.fusionWeights, 1, 1, []);

    fusionEnergy = sqrt( ...
        sum(layers .^ 2 .* weightField, 3) / ...
        sum(cfg.fusionWeights));

    fusionEnergy = normalize01( ...
        fusionEnergy, cfg.robustSampleCount);

    gradientHue = mod( ...
        (gradientState.angle + pi) / (2 * pi), ...
        1);

    gradientSaturation = clamp01( ...
        single(0.55) + ...
        single(0.25) * base.coherence + ...
        single(0.20) * v1.orientationCoherence);

    gradientValue = clamp01( ...
        fusionEnergy .* ...
        (single(0.35) + ...
        single(0.65) * gradientState.energy));

    gradientRGB = single(hsv2rgb(cat( ...
        3, ...
        gradientHue, ...
        gradientSaturation, ...
        gradientValue)));

    coneRGB = clamp01(cat( ...
        3, ...
        optical.Q(:, :, 1), ...
        optical.Q(:, :, 2), ...
        optical.Q(:, :, 3)));

    phaseHue = mod( ...
        (v1.phase + pi) / (2 * pi), ...
        1);

    phaseRGB = single(hsv2rgb(cat( ...
        3, ...
        phaseHue, ...
        clamp01( ...
        single(0.45) + ...
        single(0.55) * v1.phaseCoherence), ...
        clamp01( ...
        v1.energy .* ...
        (single(0.25) + ...
        single(0.75) * v1.phaseCoherence)))));

    gateRGB = repmat(fusionEnergy, 1, 1, 3);

    finalRGB = ...
        single(0.28) * IA_RGB + ...
        single(0.20) * I0_RGB + ...
        single(0.24) * gradientRGB .* gateRGB + ...
        single(0.13) * coneRGB .* gateRGB + ...
        single(0.10) * phaseRGB .* gateRGB;

    oppositionRGB = cat( ...
        3, ...
        normalize01( ...
        max(gradientState.divergence, 0), ...
        cfg.robustSampleCount), ...
        normalize01( ...
        abs(gradientState.curl), ...
        cfg.robustSampleCount), ...
        normalize01( ...
        max(-gradientState.divergence, 0), ...
        cfg.robustSampleCount));

    finalRGB = ...
        finalRGB + ...
        single(0.05) * oppositionRGB .* gateRGB;

    finalRGB(:, :, 1) = ...
        finalRGB(:, :, 1) + ...
        single(0.18) * quant.coreGlow;

    finalRGB(:, :, 2) = ...
        finalRGB(:, :, 2) + ...
        single(0.28) * quant.coreGlow;

    finalRGB(:, :, 3) = ...
        finalRGB(:, :, 3) + ...
        single(0.38) * quant.coreGlow;

    finalRGB = clamp01(finalRGB);

    finalRGB = ...
        finalRGB ./ ...
        (single(0.92) + single(0.08) * finalRGB);

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
