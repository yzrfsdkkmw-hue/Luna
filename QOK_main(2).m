function results = QOK_main()
% Quantization_of_Knowledge
% For_The_Quantization_of_Knowledge
%
% Canonical chain implemented by this file:
%
% I_0(x,y)
%   -> I_A(x,y)
%   -> S_A(lambda,x,y,t)
%   -> Q_LMS(x,y,t)
%   -> V_photo(x,y,t)
%   -> R_retina(x,y,t)
%   -> F_V1(x,y)
%   -> K = {kappa_i}
%   -> E = {r_ij}
%   -> Sigma
%   -> coupled state update
%
% The source H5 is opened read-only. Every generated artifact is written to
% a new timestamped output directory.

    clc;
    format compact;
    rng(2511, 'twister');

    cfg = defaultConfiguration();

    runTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    runDir = fullfile(cfg.outputRoot, ['run_' runTag]);
    if ~exist(runDir, 'dir')
        mkdir(runDir);
    end

    logPath = fullfile(runDir, 'Quantization_of_Knowledge_run_log.txt');
    diary(logPath);
    diaryCleanup = onCleanup(@() diary('off')); %#ok<NASGU>

    fprintf('\n============================================================\n');
    fprintf(' Quantization_of_Knowledge\n');
    fprintf(' For_The_Quantization_of_Knowledge\n');
    fprintf(' Run: %s\n', runTag);
    fprintf('============================================================\n\n');

    totalTimer = tic;
    stageTimes = struct();

    %% 0. Canonical source validation and H5 read
    t = tic;
    validateCanonicalSource(cfg);
    datasetInfo = h5info(cfg.sourceFile, cfg.datasetPath);
    raw = h5read(cfg.sourceFile, cfg.datasetPath);
    [channelCube, decodeMeta] = decodeCanonicalDataset(raw, cfg);
    clear raw;
    stageTimes.source_read_seconds = toc(t);
    fprintf('[01/13] Canonical H5 loaded in %.3f s\n', stageTimes.source_read_seconds);

    %% 1. Channel integration: I_0 : Omega -> R^C
    t = tic;
    [I0, channelWeights, normalizedCube] = integrateChannels(channelCube, cfg);
    clear channelCube normalizedCube;
    stageTimes.channel_integration_seconds = toc(t);
    fprintf('[02/13] Channel integration completed in %.3f s\n', stageTimes.channel_integration_seconds);

    %% 2. Differential and multiscale fields
    t = tic;
    base = computeDifferentialFields(I0, cfg);
    multiscale = computeMultiscaleFields(I0, cfg);
    spectral = computeSpectralFields(I0, cfg);
    stageTimes.field_analysis_seconds = toc(t);
    fprintf('[03/13] Differential, multiscale, and spectral fields completed in %.3f s\n', stageTimes.field_analysis_seconds);

    %% 3. Source RGB and display operator: I_A = T_A(I_0; C,gamma,W,B,rho)
    t = tic;
    I0_RGB = buildSourceRGB(I0, base, multiscale, spectral, cfg);
    IA_RGB = applyDisplayOperator(I0_RGB, cfg);
    stageTimes.display_operator_seconds = toc(t);
    fprintf('[04/13] Display operator completed in %.3f s\n', stageTimes.display_operator_seconds);

    %% 4. RGB -> spectral field -> cone catches
    t = tic;
    optical = computeOpticalConeFields(IA_RGB, cfg);
    stageTimes.optical_cone_seconds = toc(t);
    fprintf('[05/13] Optical and cone fields completed in %.3f s\n', stageTimes.optical_cone_seconds);

    %% 5. Photon-driven transduction dynamics
    t = tic;
    photo = simulatePhototransduction(optical.Q, cfg);
    stageTimes.phototransduction_seconds = toc(t);
    fprintf('[06/13] Transduction dynamics completed in %.3f s\n', stageTimes.phototransduction_seconds);

    %% 6. Retina: ON/OFF, center-surround, chromatic, temporal
    t = tic;
    retina = computeRetinalFields(optical.Q, photo, cfg);
    stageTimes.retina_seconds = toc(t);
    fprintf('[07/13] Retinal fields completed in %.3f s\n', stageTimes.retina_seconds);

    %% 7. LGN-like relay and V1-oriented complex filter bank
    t = tic;
    lgn = computeRelayFields(retina, cfg);
    v1 = computeV1ComplexBank(lgn, retina, cfg);
    stageTimes.v1_seconds = toc(t);
    fprintf('[08/13] V1 complex bank completed in %.3f s\n', stageTimes.v1_seconds);

    %% 8. ETA_PHASE: phase winding -> vortex cores -> knowledge quanta
    t = tic;
    knowledge = extractKnowledgeQuanta(I0, base, multiscale, spectral, retina, v1, cfg);
    stageTimes.quantization_seconds = toc(t);
    fprintf('[09/13] Knowledge quantization completed in %.3f s (%d cores)\n', ...
        stageTimes.quantization_seconds, numel(knowledge.cores));

    %% 9. Relations and graph operators
    t = tic;
    graphState = buildKnowledgeRelations(knowledge.cores, cfg);
    stageTimes.relations_seconds = toc(t);
    fprintf('[10/13] Knowledge relations completed in %.3f s (%d edges)\n', ...
        stageTimes.relations_seconds, numel(graphState.edges));

    %% 10. Coupled open-state and knowledge-state evolution
    t = tic;
    state = evolveCoupledStates(knowledge.cores, graphState, cfg);
    stageTimes.state_evolution_seconds = toc(t);
    fprintf('[11/13] Coupled state evolution completed in %.3f s\n', stageTimes.state_evolution_seconds);

    %% 11. Calibration of human mathematical and scientific symbols
    t = tic;
    knowledge.cores = calibrateHumanSymbols(knowledge.cores, state, cfg);
    stageTimes.symbol_calibration_seconds = toc(t);
    fprintf('[12/13] Symbol calibration completed in %.3f s\n', stageTimes.symbol_calibration_seconds);

    %% 12. Composite image and artifacts
    t = tic;
    masterRGB = composeMasterImage(IA_RGB, I0, base, spectral, retina, v1, knowledge, state, cfg);

    metrics = buildMetrics(cfg, runTag, decodeMeta, datasetInfo, channelWeights, ...
        base, spectral, optical, photo, retina, v1, knowledge, graphState, state, stageTimes);

    paths = writeArtifacts(runDir, I0_RGB, IA_RGB, masterRGB, I0, base, multiscale, ...
        spectral, optical, photo, retina, lgn, v1, knowledge, graphState, state, metrics, cfg);

    stageTimes.artifact_write_seconds = toc(t);
    stageTimes.total_seconds = toc(totalTimer);
    metrics.stage_times = stageTimes;
    rewriteMetrics(paths.metricsJSON, metrics);

    fprintf('[13/13] Artifacts written in %.3f s\n', stageTimes.artifact_write_seconds);
    fprintf('\nTotal runtime: %.3f s\n', stageTimes.total_seconds);
    fprintf('Output directory:\n%s\n\n', runDir);

    results = struct();
    results.version = cfg.version;
    results.run_tag = runTag;
    results.source_file = cfg.sourceFile;
    results.dataset_path = cfg.datasetPath;
    results.output_directory = runDir;
    results.channel_weights = channelWeights;
    results.number_of_cores = numel(knowledge.cores);
    results.number_of_relations = numel(graphState.edges);
    results.phase_order = state.phaseOrderFinal;
    results.integration_index = state.integrationIndexFinal;
    results.paths = paths;
    results.metrics = metrics;
end

%% ========================================================================
function cfg = defaultConfiguration()
    cfg = struct();
    cfg.version = 'Quantization_of_Knowledge_For_The_Quantization_of_Knowledge_v3_raster_export';

    cfg.sourceFile = '/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
    cfg.datasetPath = '/n_5_composite_field_1000x1000/data';
    cfg.expectedSHA256 = '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
    cfg.verifySHA256 = true;

    cfg.outputRoot = '/MATLAB Drive/modelTRAINING/Quantization_of_Knowledge_For_The_Quantization_of_Knowledge_output';
    cfg.targetHeight = 1000;
    cfg.targetWidth = 1000;
    cfg.expectedChannels = 5;
    cfg.flattenedOrder = 'MATLAB_COLUMN_MAJOR';

    cfg.robustSampleCount = 250000;
    cfg.channelPCASampleCount = 300000;

    cfg.gaussianScales = single([0.75, 1.5, 3, 6, 12, 24, 40]);
    cfg.spectralCutoffs = single([0, 0.008, 0.016, 0.032, 0.064, 0.125, 0.250, 0.500, 0.700]);

    cfg.display.colorMatrix = eye(3, 'single');
    cfg.display.whiteGain = single([1.0, 1.0, 1.0]);
    cfg.display.brightness = single(1.0);
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
    cfg.photo.vDark = single(-40.0);
    cfg.photo.hyperGain = single(30.0);
    cfg.photo.glutamateTheta = single(-50.0);
    cfg.photo.glutamateSlope = single(4.0);

    cfg.retina.centerSigma = single(1.2);
    cfg.retina.surroundSigma = single(5.5);
    cfg.retina.divisiveSigma = single(7.5);
    cfg.retina.divisiveEpsilon = single(0.06);

    cfg.v1.numberOfAngles = 16;
    cfg.v1.wavelengthPixels = single([4, 6, 9, 13, 19, 28, 42]);
    cfg.v1.frequencySigmaRatio = single(0.36);
    cfg.v1.inputChromaticWeight = single(0.22);
    cfg.v1.inputTemporalWeight = single(0.18);

    cfg.quantization.maxCores = 96;
    cfg.quantization.minCores = 12;
    cfg.quantization.minimumDistance = 14;
    cfg.quantization.windingThresholds = single([0.48, 0.40, 0.32, 0.24]);
    cfg.quantization.energyPercentiles = single([88, 80, 72, 64]);

    cfg.graph.kNearest = 4;
    cfg.graph.maximumRadius = single(180);
    cfg.graph.distanceScale = single(70);
    cfg.graph.featureScale = single(1.2);

    cfg.state.maxDimension = 64;
    cfg.state.steps = 384;
    cfg.state.dt = single(0.018);
    cfg.state.graphCoupling = single(0.65);
    cfg.state.inputCoupling = single(0.35);
    cfg.state.dephasing = single(0.008);
    cfg.state.crossCoupling = single(0.12);

    cfg.render.exportDPI = 240;
    cfg.render.maxRenderedLabels = 48;
    cfg.render.coreMarkerSize = 32;
    cfg.render.contactPanelSize = 260;
    cfg.render.contactBorder = 8;
end

%% ========================================================================
function validateCanonicalSource(cfg)
    lockedSourceFile = '/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
    lockedDatasetPath = '/n_5_composite_field_1000x1000/data';

    if ~strcmp(cfg.sourceFile, lockedSourceFile)
        error('Source path lock mismatch. Expected: %s', lockedSourceFile);
    end

    if ~strcmp(cfg.datasetPath, lockedDatasetPath)
        error('Dataset path lock mismatch. Expected: %s', lockedDatasetPath);
    end

    if ~isfile(cfg.sourceFile)
        error('Canonical H5 file was not found: %s', cfg.sourceFile);
    end

    h5info(cfg.sourceFile, cfg.datasetPath);

    fprintf('Canonical H5 source locked to:\n%s\n', cfg.sourceFile);
    fprintf('Canonical dataset locked to:\n%s\n', cfg.datasetPath);

    if cfg.verifySHA256
        fprintf('Computing source SHA256...\n');
        actual = sha256File(cfg.sourceFile);
        if ~strcmpi(actual, cfg.expectedSHA256)
            error('SHA256 mismatch. Expected %s, received %s.', cfg.expectedSHA256, actual);
        end
        fprintf('SHA256 matched.\n');
    end
end

%% ========================================================================
function hex = sha256File(filePath)
    md = java.security.MessageDigest.getInstance('SHA-256');
    fid = fopen(filePath, 'rb');
    if fid < 0
        error('Could not open source file for SHA256 calculation.');
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    chunkBytes = 8 * 1024 * 1024;
    while true
        data = fread(fid, chunkBytes, '*uint8');
        if isempty(data)
            break;
        end
        md.update(typecast(data, 'int8'));
    end

    digest = typecast(md.digest(), 'uint8');
    hex = lower(reshape(dec2hex(digest, 2).', 1, []));
end

%% ========================================================================
function [cube, meta] = decodeCanonicalDataset(raw, cfg)
    if ~isnumeric(raw)
        error('The canonical dataset must be numeric.');
    end

    H = cfg.targetHeight;
    W = cfg.targetWidth;
    C = cfg.expectedChannels;
    dims = size(raw);

    meta = struct();
    meta.source_size = dims;
    meta.target_height = H;
    meta.target_width = W;
    meta.flattened_order = cfg.flattenedOrder;

    if ismatrix(raw) && isequal(dims, [H, W])
        cube = reshape(single(raw), H, W, 1);
        meta.decode_mode = 'direct_2D';

    elseif ndims(raw) == 3 && isequal(dims, [H, W, C])
        cube = single(raw);
        meta.decode_mode = 'H_W_C';

    elseif ndims(raw) == 3 && isequal(dims, [C, H, W])
        cube = permute(single(raw), [2, 3, 1]);
        meta.decode_mode = 'C_H_W_to_H_W_C';

    elseif ismatrix(raw) && isequal(dims, [C, H * W])
        cube = zeros(H, W, C, 'single');
        for c = 1:C
            cube(:, :, c) = reshape(single(raw(c, :)), H, W);
        end
        meta.decode_mode = 'C_by_flat';

    elseif ismatrix(raw) && isequal(dims, [H * W, C])
        cube = zeros(H, W, C, 'single');
        for c = 1:C
            cube(:, :, c) = reshape(single(raw(:, c)), H, W);
        end
        meta.decode_mode = 'flat_by_C';

    else
        error(['Unsupported canonical dataset shape: [%s]. Accepted shapes are ', ...
            '[1000 1000], [1000 1000 5], [5 1000 1000], ', ...
            '[5 1000000], or [1000000 5].'], num2str(dims));
    end

    cube(~isfinite(cube)) = 0;
    meta.decoded_channels = size(cube, 3);
end

%% ========================================================================
function [field, weights, Z] = integrateChannels(cube, cfg)
    [H, W, C] = size(cube);
    Z = zeros(H, W, C, 'single');

    for c = 1:C
        Z(:, :, c) = robustSignedNormalize(cube(:, :, c), cfg.robustSampleCount);
    end

    if C == 1
        weights = single(1);
        field = Z(:, :, 1);
        return;
    end

    X = reshape(Z, [], C);
    n = size(X, 1);
    step = max(1, floor(n / cfg.channelPCASampleCount));
    Xs = double(X(1:step:end, :));
    Xs = Xs - mean(Xs, 1);

    covarianceMatrix = (Xs.' * Xs) / max(1, size(Xs, 1) - 1);
    covarianceMatrix = 0.5 * (covarianceMatrix + covarianceMatrix.');
    [V, D] = eig(covarianceMatrix, 'vector');
    [~, idx] = max(real(D));
    weights = single(real(V(:, idx)));

    reference = mean(Xs, 2);
    projected = Xs * double(weights);
    if dot(projected, reference) < 0
        weights = -weights;
    end

    weights = weights / max(norm(weights), eps('single'));
    field = reshape(X * weights, H, W);
    field = robustSignedNormalize(field, cfg.robustSampleCount);
end

%% ========================================================================
function base = computeDifferentialFields(I0, cfg)
    [gx, gy] = gradient(I0);
    gradMag = hypot(gx, gy);
    lapKernel = single([0, 1, 0; 1, -4, 1; 0, 1, 0]);
    lap = conv2(I0, lapKernel, 'same');

    tensorSigma = single(2.2);
    Jxx = gaussianBlur(gx .* gx, tensorSigma);
    Jyy = gaussianBlur(gy .* gy, tensorSigma);
    Jxy = gaussianBlur(gx .* gy, tensorSigma);

    orientation = 0.5 * atan2(2 * Jxy, Jxx - Jyy);
    coherence = sqrt((Jxx - Jyy).^2 + 4 * Jxy.^2) ./ (Jxx + Jyy + single(1e-6));

    base = struct();
    base.gx = gx;
    base.gy = gy;
    base.gradientMagnitude = gradMag;
    base.laplacian = lap;
    base.orientation = orientation;
    base.coherence = clamp01(coherence);
    base.salience = normalize01(0.55 * gradMag + 0.30 * abs(lap) + 0.15 * abs(I0), cfg.robustSampleCount);
end

%% ========================================================================
function multiscale = computeMultiscaleFields(I0, cfg)
    scales = cfg.gaussianScales;
    H = size(I0, 1);
    W = size(I0, 2);
    n = numel(scales);

    gaussianStack = zeros(H, W, n, 'single');
    dogStack = zeros(H, W, n - 1, 'single');

    for k = 1:n
        gaussianStack(:, :, k) = gaussianBlur(I0, scales(k));
        if k > 1
            dogStack(:, :, k - 1) = gaussianStack(:, :, k - 1) - gaussianStack(:, :, k);
        end
        fprintf('  Multiscale Gaussian %d/%d, sigma=%.3f\n', k, n, scales(k));
    end

    multiscale = struct();
    multiscale.scales = scales;
    multiscale.gaussian = gaussianStack;
    multiscale.dog = dogStack;
    multiscale.dogEnergy = sqrt(sum(dogStack .^ 2, 3));
end

%% ========================================================================
function spectral = computeSpectralFields(I0, cfg)
    [H, W] = size(I0);
    [U, V] = frequencyGrid(H, W);
    radius = sqrt(U .^ 2 + V .^ 2);
    F = fft2(I0);

    cutoffs = cfg.spectralCutoffs;
    nBands = numel(cutoffs) - 1;
    bands = zeros(H, W, nBands, 'single');

    for k = 1:nBands
        lowCut = cutoffs(k);
        highCut = cutoffs(k + 1);

        if lowCut == 0
            lowPassA = ones(H, W, 'single');
        else
            lowPassA = exp(-((radius ./ lowCut) .^ 8));
        end
        lowPassB = exp(-((radius ./ highCut) .^ 8));
        mask = max(lowPassB - lowPassA, 0);

        if k == 1
            mask = lowPassB;
        end

        bands(:, :, k) = real(ifft2(F .* mask));
        fprintf('  Spectral band %d/%d, %.5f -> %.5f cycles/pixel\n', ...
            k, nBands, lowCut, highCut);
    end

    lowCount = min(2, nBands);
    midStart = min(3, nBands);
    midEnd = min(5, nBands);
    highStart = min(6, nBands);

    lowField = sum(bands(:, :, 1:lowCount), 3);
    midField = sum(bands(:, :, midStart:midEnd), 3);
    highField = sum(bands(:, :, highStart:end), 3);

    spectral = struct();
    spectral.cutoffs = cutoffs;
    spectral.bands = bands;
    spectral.low = lowField;
    spectral.mid = midField;
    spectral.high = highField;
    spectral.energy = sqrt(sum(bands .^ 2, 3));
    spectral.fftLogMagnitude = log1p(abs(fftshift(F)));
end

%% ========================================================================
function rgb = buildSourceRGB(I0, base, multiscale, spectral, cfg)
    angleField = atan2(base.gy, base.gx);
    hue = mod((angleField + pi) / (2 * pi) ...
        + 0.14 * normalize01(spectral.mid, cfg.robustSampleCount), 1);

    saturation = clamp01(0.40 ...
        + 0.35 * normalize01(abs(spectral.high), cfg.robustSampleCount) ...
        + 0.25 * base.coherence);

    valueField = 0.30 * abs(I0) ...
        + 0.24 * base.gradientMagnitude ...
        + 0.18 * abs(base.laplacian) ...
        + 0.16 * multiscale.dogEnergy ...
        + 0.12 * spectral.energy;

    value = normalize01(valueField, cfg.robustSampleCount) .^ single(0.72);
    gate = normalize01(base.salience + multiscale.dogEnergy, cfg.robustSampleCount);
    value = value .* (single(0.05) + single(0.95) * gate);

    hsvImage = cat(3, hue, saturation, clamp01(value));
    rgb = single(hsv2rgb(hsvImage));
end

%% ========================================================================
function rgbOut = applyDisplayOperator(rgbIn, cfg)
    linearRGB = srgbDecode(clamp01(rgbIn));
    [H, W, ~] = size(linearRGB);

    flat = reshape(linearRGB, [], 3);
    flat = flat * cfg.display.colorMatrix.';
    flat = flat .* cfg.display.whiteGain;
    flat = flat * cfg.display.brightness;
    linearRGB = reshape(flat, H, W, 3);

    for c = 1:3
        linearRGB(:, :, c) = gaussianBlur(linearRGB(:, :, c), cfg.display.spatialSigma);
    end

    linearRGB = max(linearRGB, 0);
    linearRGB = linearRGB ./ (1 + cfg.display.shoulder * linearRGB);
    rgbOut = srgbEncode(linearRGB);
    rgbOut = clamp01(rgbOut);
end

%% ========================================================================
function optical = computeOpticalConeFields(rgbDisplay, cfg)
    lambda = cfg.optics.lambdaNm;
    dlambda = mean(diff(lambda));

    primary = zeros(numel(lambda), 3, 'single');
    cone = zeros(numel(lambda), 3, 'single');

    for c = 1:3
        primary(:, c) = exp(-0.5 * ((lambda - cfg.optics.primaryCentersNm(c)) ...
            / cfg.optics.primaryWidthsNm(c)) .^ 2);
        cone(:, c) = exp(-0.5 * ((lambda - cfg.optics.coneCentersNm(c)) ...
            / cfg.optics.coneWidthsNm(c)) .^ 2);
    end

    primary = primary ./ max(primary, [], 1);
    cone = cone ./ max(cone, [], 1);

    hPlanck = 6.62607015e-34;
    cLight = 299792458;
    photonEnergy = hPlanck * cLight ./ (double(lambda) * 1e-9);
    photonWeight = single((1 ./ photonEnergy) / max(1 ./ photonEnergy));

    linearRGB = srgbDecode(rgbDisplay);
    R = linearRGB(:, :, 1);
    G = linearRGB(:, :, 2);
    B = linearRGB(:, :, 3);

    qL = zeros(size(R), 'single');
    qM = zeros(size(R), 'single');
    qS = zeros(size(R), 'single');
    opticalEnergy = zeros(size(R), 'single');

    for k = 1:numel(lambda)
        spectralPlane = R * primary(k, 1) + G * primary(k, 2) + B * primary(k, 3);
        weightedPlane = spectralPlane * photonWeight(k);

        qL = qL + weightedPlane * cone(k, 1) * dlambda;
        qM = qM + weightedPlane * cone(k, 2) * dlambda;
        qS = qS + weightedPlane * cone(k, 3) * dlambda;
        opticalEnergy = opticalEnergy + spectralPlane * dlambda;

        if mod(k, 10) == 0 || k == numel(lambda)
            fprintf('  Spectral integration %d/%d, lambda=%.1f nm\n', k, numel(lambda), lambda(k));
        end
    end

    qL = normalize01(qL, cfg.robustSampleCount);
    qM = normalize01(qM, cfg.robustSampleCount);
    qS = normalize01(qS, cfg.robustSampleCount);

    optical = struct();
    optical.lambdaNm = lambda;
    optical.primaryBasis = primary;
    optical.coneBasis = cone;
    optical.photonWeight = photonWeight;
    optical.Q = cat(3, qL, qM, qS);
    optical.energy = normalize01(opticalEnergy, cfg.robustSampleCount);
end

%% ========================================================================
function photo = simulatePhototransduction(Q, cfg)
    qL = Q(:, :, 1);
    qM = Q(:, :, 2);
    qS = Q(:, :, 3);
    stimulusBase = clamp01(single(0.45) * qL + single(0.45) * qM + single(0.10) * qS);

    opsin = zeros(size(stimulusBase), 'single');
    transducin = zeros(size(stimulusBase), 'single');
    pde6 = zeros(size(stimulusBase), 'single');
    cgmp = ones(size(stimulusBase), 'single');
    cng = ones(size(stimulusBase), 'single');
    voltage = cfg.photo.vDark * ones(size(stimulusBase), 'single');
    glutamate = ones(size(stimulusBase), 'single');

    meanVoltage = zeros(size(stimulusBase), 'single');
    temporalEnergy = zeros(size(stimulusBase), 'single');
    previousVoltage = voltage;

    shiftPattern = [0, 0; 1, 0; 0, 1; -1, 0; 0, -1; 1, 1; -1, 1; -1, -1; 1, -1];
    dt = cfg.photo.dt;

    voltageMeanTrace = zeros(cfg.photo.steps, 1, 'single');
    cgmpMeanTrace = zeros(cfg.photo.steps, 1, 'single');
    glutamateMeanTrace = zeros(cfg.photo.steps, 1, 'single');

    for stepIndex = 1:cfg.photo.steps
        phase = single(2 * pi * (stepIndex - 1) / 12);
        modulation = single(1) + cfg.photo.modulationDepth * sin(phase);
        shift = shiftPattern(mod(stepIndex - 1, size(shiftPattern, 1)) + 1, :);
        stimulus = clamp01(circshift(stimulusBase, shift) * modulation);

        opsin = opsin + dt * (cfg.photo.opsinOn * stimulus .* (1 - opsin) ...
            - cfg.photo.opsinOff * opsin);
        opsin = clamp01(opsin);

        transducin = transducin + dt * (cfg.photo.transducinOn * opsin .* (1 - transducin) ...
            - cfg.photo.transducinOff * transducin);
        transducin = clamp01(transducin);

        pde6 = pde6 + dt * (cfg.photo.pdeOn * transducin .* (1 - pde6) ...
            - cfg.photo.pdeOff * pde6);
        pde6 = clamp01(pde6);

        cgmp = cgmp + dt * (cfg.photo.cgmpSynthesis * (1 - cgmp) ...
            - cfg.photo.cgmpHydrolysis * pde6 .* cgmp);
        cgmp = clamp01(cgmp);

        numerator = cgmp .^ cfg.photo.cngHill;
        denominator = numerator + cfg.photo.cngK .^ cfg.photo.cngHill;
        cng = numerator ./ (denominator + single(1e-7));

        voltage = cfg.photo.vDark - cfg.photo.hyperGain * (1 - cng);
        glutamate = 1 ./ (1 + exp(-(voltage - cfg.photo.glutamateTheta) ...
            / cfg.photo.glutamateSlope));

        deltaVoltage = voltage - previousVoltage;
        temporalEnergy = temporalEnergy + deltaVoltage .^ 2;
        meanVoltage = meanVoltage + voltage;
        previousVoltage = voltage;

        voltageMeanTrace(stepIndex) = mean(voltage, 'all');
        cgmpMeanTrace(stepIndex) = mean(cgmp, 'all');
        glutamateMeanTrace(stepIndex) = mean(glutamate, 'all');

        if mod(stepIndex, 16) == 0 || stepIndex == cfg.photo.steps
            fprintf('  Transduction step %d/%d\n', stepIndex, cfg.photo.steps);
        end
    end

    meanVoltage = meanVoltage / cfg.photo.steps;
    temporalEnergy = sqrt(temporalEnergy / cfg.photo.steps);

    photo = struct();
    photo.opsin = opsin;
    photo.transducin = transducin;
    photo.pde6 = pde6;
    photo.cgmp = cgmp;
    photo.cng = cng;
    photo.voltage = voltage;
    photo.meanVoltage = meanVoltage;
    photo.glutamate = glutamate;
    photo.temporalEnergy = normalize01(temporalEnergy, cfg.robustSampleCount);
    photo.voltageMeanTrace = voltageMeanTrace;
    photo.cgmpMeanTrace = cgmpMeanTrace;
    photo.glutamateMeanTrace = glutamateMeanTrace;
end

%% ========================================================================
function retina = computeRetinalFields(Q, photo, cfg)
    qL = Q(:, :, 1);
    qM = Q(:, :, 2);
    qS = Q(:, :, 3);

    responseField = normalize01(-photo.meanVoltage, cfg.robustSampleCount);
    center = gaussianBlur(responseField, cfg.retina.centerSigma);
    surround = gaussianBlur(responseField, cfg.retina.surroundSigma);
    dog = center - surround;

    onField = max(dog, 0);
    offField = max(-dog, 0);

    lum = single(0.5) * (qL + qM);
    lm = qL - qM;
    sLm = qS - single(0.5) * (qL + qM);

    localDenominator = cfg.retina.divisiveEpsilon ...
        + gaussianBlur(abs(onField) + abs(offField) + lum, cfg.retina.divisiveSigma);

    onField = onField ./ localDenominator;
    offField = offField ./ localDenominator;

    ganglionDrive = single(0.34) * normalize01(onField, cfg.robustSampleCount) ...
        + single(0.26) * normalize01(offField, cfg.robustSampleCount) ...
        + single(0.16) * normalize01(abs(lm), cfg.robustSampleCount) ...
        + single(0.12) * normalize01(abs(sLm), cfg.robustSampleCount) ...
        + single(0.12) * photo.temporalEnergy;

    retina = struct();
    retina.center = center;
    retina.surround = surround;
    retina.dog = dog;
    retina.on = normalize01(onField, cfg.robustSampleCount);
    retina.off = normalize01(offField, cfg.robustSampleCount);
    retina.luminance = normalize01(lum, cfg.robustSampleCount);
    retina.LM = robustSignedNormalize(lm, cfg.robustSampleCount);
    retina.SLM = robustSignedNormalize(sLm, cfg.robustSampleCount);
    retina.temporal = photo.temporalEnergy;
    retina.ganglionDrive = normalize01(ganglionDrive, cfg.robustSampleCount);
end

%% ========================================================================
function lgn = computeRelayFields(retina, cfg)
    relayRaw = single(0.36) * retina.ganglionDrive ...
        + single(0.20) * retina.on ...
        + single(0.18) * retina.off ...
        + single(0.14) * abs(retina.LM) ...
        + single(0.12) * abs(retina.SLM);

    normalizationPool = single(0.08) + gaussianBlur(relayRaw, single(6.0));
    relay = relayRaw ./ normalizationPool;

    lgn = struct();
    lgn.relay = normalize01(relay, cfg.robustSampleCount);
    lgn.magnocellularLike = normalize01(retina.on + retina.off + retina.temporal, cfg.robustSampleCount);
    lgn.parvocellularLike = normalize01(retina.luminance + abs(retina.LM), cfg.robustSampleCount);
    lgn.koniocellularLike = normalize01(abs(retina.SLM), cfg.robustSampleCount);
end

%% ========================================================================
function v1 = computeV1ComplexBank(lgn, retina, cfg)
    inputField = lgn.relay ...
        + cfg.v1.inputChromaticWeight * normalize01(abs(retina.LM) + abs(retina.SLM), cfg.robustSampleCount) ...
        + cfg.v1.inputTemporalWeight * retina.temporal;
    inputField = robustSignedNormalize(inputField, cfg.robustSampleCount);

    [H, W] = size(inputField);
    [U, V] = frequencyGrid(H, W);
    F = fft2(inputField);

    angles = linspace(0, pi, cfg.v1.numberOfAngles + 1);
    angles(end) = [];
    wavelengths = cfg.v1.wavelengthPixels;

    maxEnergy = zeros(H, W, 'single');
    totalEnergy = zeros(H, W, 'single');
    orientationVector = complex(zeros(H, W, 'single'));
    frequencyNumerator = zeros(H, W, 'single');
    frequencyDenominator = zeros(H, W, 'single');
    phaseCarrier = complex(zeros(H, W, 'single'));
    winningScale = zeros(H, W, 'single');

    totalFilters = numel(angles) * numel(wavelengths);
    filterCounter = 0;

    for s = 1:numel(wavelengths)
        wavelength = wavelengths(s);
        f0 = single(1) / wavelength;
        sigmaF = max(single(1e-4), cfg.v1.frequencySigmaRatio * f0);

        for a = 1:numel(angles)
            theta = single(angles(a));
            u0 = f0 * cos(theta);
            v0 = f0 * sin(theta);

            frequencyKernel = exp(-((U - u0) .^ 2 + (V - v0) .^ 2) / (2 * sigmaF ^ 2));
            frequencyKernel = frequencyKernel ./ max(frequencyKernel, [], 'all');

            response = ifft2(F .* frequencyKernel);
            energy = abs(response);

            replacementMask = energy > maxEnergy;
            maxEnergy(replacementMask) = energy(replacementMask);
            winningScale(replacementMask) = wavelength;

            totalEnergy = totalEnergy + energy;
            orientationVector = orientationVector + energy * exp(1i * single(2) * theta);
            frequencyNumerator = frequencyNumerator + energy * f0;
            frequencyDenominator = frequencyDenominator + energy;
            phaseCarrier = phaseCarrier + response / sqrt(single(s));

            filterCounter = filterCounter + 1;
            if mod(filterCounter, 8) == 0 || filterCounter == totalFilters
                fprintf('  V1 filter %d/%d, wavelength=%.1f, angle=%.2f deg\n', ...
                    filterCounter, totalFilters, wavelength, double(theta * 180 / pi));
            end
        end
    end

    orientation = single(0.5) * angle(orientationVector);
    orientationCoherence = abs(orientationVector) ./ (totalEnergy + single(1e-7));
    preferredFrequency = frequencyNumerator ./ (frequencyDenominator + single(1e-7));
    eta = angle(phaseCarrier);
    phaseCoherence = abs(phaseCarrier) ./ (totalEnergy + single(1e-7));

    v1 = struct();
    v1.input = inputField;
    v1.energy = normalize01(maxEnergy, cfg.robustSampleCount);
    v1.totalEnergy = normalize01(totalEnergy, cfg.robustSampleCount);
    v1.orientation = orientation;
    v1.orientationCoherence = clamp01(orientationCoherence);
    v1.preferredFrequency = normalize01(preferredFrequency, cfg.robustSampleCount);
    v1.winningScale = winningScale;
    v1.phase = eta;
    v1.phaseCoherence = clamp01(phaseCoherence);
    v1.phaseCarrier = phaseCarrier;
end

%% ========================================================================
function knowledge = extractKnowledgeQuanta(I0, base, multiscale, spectral, retina, v1, cfg)
    phase = v1.phase;

    dTop = wrapToPiLocal(phase(1:end-1, 2:end) - phase(1:end-1, 1:end-1));
    dRight = wrapToPiLocal(phase(2:end, 2:end) - phase(1:end-1, 2:end));
    dBottom = wrapToPiLocal(phase(2:end, 1:end-1) - phase(2:end, 2:end));
    dLeft = wrapToPiLocal(phase(1:end-1, 1:end-1) - phase(2:end, 1:end-1));

    winding = (dTop + dRight + dBottom + dLeft) / single(2 * pi);

    cellEnergy = single(0.25) * (v1.energy(1:end-1, 1:end-1) ...
        + v1.energy(1:end-1, 2:end) ...
        + v1.energy(2:end, 1:end-1) ...
        + v1.energy(2:end, 2:end));

    cellCoherence = single(0.25) * (v1.phaseCoherence(1:end-1, 1:end-1) ...
        + v1.phaseCoherence(1:end-1, 2:end) ...
        + v1.phaseCoherence(2:end, 1:end-1) ...
        + v1.phaseCoherence(2:end, 2:end));

    selectedX = [];
    selectedY = [];
    selectedScore = [];
    selectedWinding = [];

    for level = 1:numel(cfg.quantization.windingThresholds)
        windingThreshold = cfg.quantization.windingThresholds(level);
        energyThreshold = samplePercentile(cellEnergy, cfg.quantization.energyPercentiles(level), cfg.robustSampleCount);

        candidateMask = abs(winding) >= windingThreshold ...
            & cellEnergy >= energyThreshold ...
            & cellCoherence >= single(0.05);

        candidateScore = abs(winding) .* cellEnergy .* (single(0.25) + single(0.75) * cellCoherence);
        [selectedX, selectedY, selectedScore, selectedWinding] = selectSeparatedCandidates( ...
            candidateMask, candidateScore, winding, cfg.quantization.maxCores, ...
            cfg.quantization.minimumDistance);

        if numel(selectedX) >= cfg.quantization.minCores
            break;
        end
    end

    n = numel(selectedX);
    cores = repmat(emptyCore(), n, 1);

    lowMap = normalize01(abs(spectral.low), cfg.robustSampleCount);
    midMap = normalize01(abs(spectral.mid), cfg.robustSampleCount);
    highMap = normalize01(abs(spectral.high), cfg.robustSampleCount);
    dogMap = normalize01(multiscale.dogEnergy, cfg.robustSampleCount);
    lapMap = normalize01(abs(base.laplacian), cfg.robustSampleCount);
    gradMap = normalize01(base.gradientMagnitude, cfg.robustSampleCount);
    chromaMap = normalize01(abs(retina.LM) + abs(retina.SLM), cfg.robustSampleCount);

    for i = 1:n
        x = selectedX(i);
        y = selectedY(i);

        signature = single([ ...
            sampleMap(gradMap, x, y), ...
            sampleMap(lapMap, x, y), ...
            sampleMap(lowMap, x, y), ...
            sampleMap(midMap, x, y), ...
            sampleMap(highMap, x, y), ...
            sampleMap(chromaMap, x, y), ...
            sampleMap(retina.temporal, x, y), ...
            sampleMap(v1.orientationCoherence, x, y), ...
            sampleMap(v1.phaseCoherence, x, y), ...
            sampleMap(dogMap, x, y)]);

        cores(i).id = i;
        cores(i).x = x;
        cores(i).y = y;
        cores(i).amplitude = selectedScore(i);
        cores(i).phase = sampleMap(v1.phase, x, y);
        cores(i).winding = selectedWinding(i);
        cores(i).orientation = sampleMap(v1.orientation, x, y);
        cores(i).preferredFrequency = sampleMap(v1.preferredFrequency, x, y);
        cores(i).sourceValue = sampleMap(I0, x, y);
        cores(i).signature = signature;
        cores(i).symbol = '';
        cores(i).symbolIndex = 0;
        cores(i).calibrationScore = 0;
    end

    knowledge = struct();
    knowledge.winding = winding;
    knowledge.cellEnergy = cellEnergy;
    knowledge.cellCoherence = cellCoherence;
    knowledge.cores = cores;
end

%% ========================================================================
function c = emptyCore()
    c = struct('id', 0, 'x', 0, 'y', 0, 'amplitude', 0, 'phase', 0, ...
        'winding', 0, 'orientation', 0, 'preferredFrequency', 0, ...
        'sourceValue', 0, 'signature', zeros(1, 10, 'single'), ...
        'symbol', '', 'symbolIndex', 0, 'calibrationScore', 0);
end

%% ========================================================================
function [xSelected, ySelected, scoreSelected, windingSelected] = selectSeparatedCandidates( ...
    candidateMask, scoreMap, windingMap, maxCount, minimumDistance)

    [yAll, xAll] = find(candidateMask);
    if isempty(xAll)
        xSelected = [];
        ySelected = [];
        scoreSelected = [];
        windingSelected = [];
        return;
    end

    linear = sub2ind(size(scoreMap), yAll, xAll);
    scores = scoreMap(linear);
    windings = windingMap(linear);
    [scores, order] = sort(scores, 'descend');
    xAll = xAll(order);
    yAll = yAll(order);
    windings = windings(order);

    xSelected = zeros(maxCount, 1);
    ySelected = zeros(maxCount, 1);
    scoreSelected = zeros(maxCount, 1, 'single');
    windingSelected = zeros(maxCount, 1, 'single');
    count = 0;
    minDistanceSquared = minimumDistance ^ 2;

    for i = 1:numel(xAll)
        x = xAll(i) + 1;
        y = yAll(i) + 1;

        if count > 0
            distanceSquared = (xSelected(1:count) - x) .^ 2 + (ySelected(1:count) - y) .^ 2;
            if any(distanceSquared < minDistanceSquared)
                continue;
            end
        end

        count = count + 1;
        xSelected(count) = x;
        ySelected(count) = y;
        scoreSelected(count) = scores(i);
        windingSelected(count) = windings(i);

        if count >= maxCount
            break;
        end
    end

    xSelected = xSelected(1:count);
    ySelected = ySelected(1:count);
    scoreSelected = scoreSelected(1:count);
    windingSelected = windingSelected(1:count);
end

%% ========================================================================
function graphState = buildKnowledgeRelations(cores, cfg)
    N = numel(cores);
    adjacency = zeros(N, N, 'single');
    distanceMatrix = inf(N, N, 'single');
    featureSimilarity = zeros(N, N, 'single');

    for i = 1:N
        distanceMatrix(i, i) = 0;
        for j = i + 1:N
            dx = single(cores(i).x - cores(j).x);
            dy = single(cores(i).y - cores(j).y);
            distance = hypot(dx, dy);
            distanceMatrix(i, j) = distance;
            distanceMatrix(j, i) = distance;

            ds = cores(i).signature - cores(j).signature;
            similarity = exp(-sum(ds .^ 2) / (2 * cfg.graph.featureScale ^ 2));
            featureSimilarity(i, j) = similarity;
            featureSimilarity(j, i) = similarity;
        end
    end

    for i = 1:N
        [distances, order] = sort(distanceMatrix(i, :), 'ascend');
        accepted = 0;
        for k = 2:numel(order)
            j = order(k);
            if distances(k) > cfg.graph.maximumRadius
                break;
            end

            phaseAlignment = single(0.5) * (1 + cos(single(cores(i).phase - cores(j).phase)));
            orientationAlignment = single(0.5) * (1 + cos(single(2) * ...
                single(cores(i).orientation - cores(j).orientation)));
            distanceWeight = exp(-distances(k) / cfg.graph.distanceScale);

            weight = distanceWeight ...
                * (single(0.20) + single(0.80) * phaseAlignment) ...
                * (single(0.25) + single(0.75) * orientationAlignment) ...
                * (single(0.25) + single(0.75) * featureSimilarity(i, j));

            adjacency(i, j) = max(adjacency(i, j), weight);
            adjacency(j, i) = adjacency(i, j);
            accepted = accepted + 1;

            if accepted >= cfg.graph.kNearest
                break;
            end
        end
    end

    degree = diag(sum(adjacency, 2));
    laplacian = degree - adjacency;

    edgeList = repmat(struct('source', 0, 'target', 0, 'distance', 0, ...
        'weight', 0, 'phaseDifference', 0, 'featureSimilarity', 0), 0, 1);

    [ii, jj] = find(triu(adjacency, 1) > 0);
    for e = 1:numel(ii)
        i = ii(e);
        j = jj(e);
        edgeList(e, 1).source = i;
        edgeList(e, 1).target = j;
        edgeList(e, 1).distance = distanceMatrix(i, j);
        edgeList(e, 1).weight = adjacency(i, j);
        edgeList(e, 1).phaseDifference = wrapToPiLocal(single(cores(i).phase - cores(j).phase));
        edgeList(e, 1).featureSimilarity = featureSimilarity(i, j);
    end

    graphState = struct();
    graphState.adjacency = adjacency;
    graphState.degree = degree;
    graphState.laplacian = laplacian;
    graphState.distance = distanceMatrix;
    graphState.featureSimilarity = featureSimilarity;
    graphState.edges = edgeList;
end

%% ========================================================================
function state = evolveCoupledStates(cores, graphState, cfg)
    Nall = numel(cores);
    N = min(Nall, cfg.state.maxDimension);

    if N == 0
        state = emptyState();
        return;
    end

    amplitudes = single([cores(1:N).amplitude].');
    phases = single([cores(1:N).phase].');
    amplitudes = sqrt(max(amplitudes, 0) + single(1e-8));
    psiK = amplitudes .* exp(1i * phases);
    psiK = psiK / max(norm(psiK), eps('single'));
    rhoK = psiK * psiK';

    A = graphState.adjacency(1:N, 1:N);
    L = graphState.laplacian(1:N, 1:N);

    featureEnergy = zeros(N, 1, 'single');
    for i = 1:N
        featureEnergy(i) = mean(cores(i).signature);
    end

    HB = diag(featureEnergy) + cfg.state.graphCoupling * L;
    HK = cfg.state.graphCoupling * L + cfg.state.inputCoupling * diag(featureEnergy);

    rhoB = diag(amplitudes .^ 2);
    rhoB = rhoB / trace(rhoB);

    UB = expm(-1i * double(cfg.state.dt) * double(HB));
    UK = expm(-1i * double(cfg.state.dt) * double(HK));
    UB = complex(single(UB));
    UK = complex(single(UK));

    entropyBTrace = zeros(cfg.state.steps, 1, 'single');
    entropyKTrace = zeros(cfg.state.steps, 1, 'single');
    phaseOrderTrace = zeros(cfg.state.steps, 1, 'single');
    integrationTrace = zeros(cfg.state.steps, 1, 'single');

    offDiagonalMask = ones(N, N, 'single') - eye(N, 'single');
    couplingMatrix = normalizeMatrix(A + eye(N, 'single'));
    algebraicConnectivity = graphConnectivity(L);

    for stepIndex = 1:cfg.state.steps
        rhoB = UB * rhoB * UB';
        rhoK = UK * rhoK * UK';

        rhoB = applyDephasing(rhoB, cfg.state.dephasing, offDiagonalMask);
        rhoK = applyDephasing(rhoK, cfg.state.dephasing, offDiagonalMask);

        diagonalB = real(diag(rhoB));
        drive = couplingMatrix * diagonalB;
        drive = drive / max(sum(drive), single(1e-7));
        phaseReference = angle(sum(rhoK, 2) + complex(single(1e-7), single(0)));
        drivenState = sqrt(max(drive, 0)) .* exp(1i * phaseReference);
        drivenState = drivenState / max(norm(drivenState), eps('single'));
        drivenDensity = drivenState * drivenState';

        rhoK = (1 - cfg.state.crossCoupling) * rhoK + cfg.state.crossCoupling * drivenDensity;
        rhoK = hermitianNormalize(rhoK);
        rhoB = hermitianNormalize(rhoB);

        entropyBTrace(stepIndex) = densityEntropy(rhoB);
        entropyKTrace(stepIndex) = densityEntropy(rhoK);

        principalVector = principalStateVector(rhoK);
        phaseOrderTrace(stepIndex) = abs(sum(abs(principalVector) .* exp(1i * angle(principalVector))) ...
            / max(sum(abs(principalVector)), single(1e-7)));

        normalizedEntropy = entropyKTrace(stepIndex) / max(log(single(N)), single(1e-7));
        normalizedEntropy = min(max(normalizedEntropy, single(0)), single(1));
        integrationTrace(stepIndex) = algebraicConnectivity ...
            * phaseOrderTrace(stepIndex) ...
            * (single(0.25) + single(0.75) * (1 - normalizedEntropy));

        if mod(stepIndex, 32) == 0 || stepIndex == cfg.state.steps
            fprintf('  Coupled state step %d/%d\n', stepIndex, cfg.state.steps);
        end
    end

    principalVector = principalStateVector(rhoK);

    state = struct();
    state.dimension = N;
    state.rhoB = rhoB;
    state.rhoK = rhoK;
    state.psiK = principalVector;
    state.entropyBTrace = entropyBTrace;
    state.entropyKTrace = entropyKTrace;
    state.phaseOrderTrace = phaseOrderTrace;
    state.integrationTrace = integrationTrace;
    state.phaseOrderFinal = phaseOrderTrace(end);
    state.integrationIndexFinal = integrationTrace(end);
    state.algebraicConnectivity = algebraicConnectivity;
end

%% ========================================================================
function state = emptyState()
    state = struct();
    state.dimension = 0;
    state.rhoB = zeros(0, 0, 'single');
    state.rhoK = zeros(0, 0, 'single');
    state.psiK = zeros(0, 1, 'single');
    state.entropyBTrace = zeros(0, 1, 'single');
    state.entropyKTrace = zeros(0, 1, 'single');
    state.phaseOrderTrace = zeros(0, 1, 'single');
    state.integrationTrace = zeros(0, 1, 'single');
    state.phaseOrderFinal = single(0);
    state.integrationIndexFinal = single(0);
    state.algebraicConnectivity = single(0);
end

%% ========================================================================
function rho = applyDephasing(rho, rate, offDiagonalMask)
    diagonalPart = diag(diag(rho));
    offDiagonalPart = rho .* offDiagonalMask;
    rho = diagonalPart + exp(-rate) * offDiagonalPart;
    rho = hermitianNormalize(rho);
end

%% ========================================================================
function rho = hermitianNormalize(rho)
    rho = single(0.5) * (rho + rho');
    tr = real(trace(rho));
    if tr <= 0 || ~isfinite(tr)
        rho = eye(size(rho), 'single') / max(1, size(rho, 1));
    else
        rho = rho / tr;
    end
end

%% ========================================================================
function entropyValue = densityEntropy(rho)
    eigenvalues = real(eig(double(0.5 * (rho + rho'))));
    eigenvalues = max(eigenvalues, 0);
    eigenvalues = eigenvalues / max(sum(eigenvalues), eps);
    eigenvalues = eigenvalues(eigenvalues > 1e-12);
    entropyValue = single(-sum(eigenvalues .* log(eigenvalues)));
end

%% ========================================================================
function vector = principalStateVector(rho)
    [V, D] = eig(double(0.5 * (rho + rho')), 'vector');
    [~, idx] = max(real(D));
    vector = complex(single(V(:, idx)));
    vector = vector / max(norm(vector), eps('single'));
end

%% ========================================================================
function value = graphConnectivity(L)
    N = size(L, 1);
    if N < 2
        value = single(0);
        return;
    end
    eigenvalues = sort(real(eig(double(0.5 * (L + L')))), 'ascend');
    lambda2 = max(eigenvalues(2), 0);
    scale = max(eigenvalues(end), eps);
    value = single(lambda2 / scale);
end

%% ========================================================================
function M = normalizeMatrix(M)
    rowSums = sum(M, 2);
    M = M ./ (rowSums + single(1e-7));
end

%% ========================================================================
function cores = calibrateHumanSymbols(cores, state, cfg)
    symbols = {'\nabla', '\partial', '\int', '\Sigma', '\eta', '\Omega', '\vec{v}'};
    N = numel(cores);

    for i = 1:N
        s = cores(i).signature;
        stateWeight = single(0);
        if i <= state.dimension
            stateWeight = abs(state.psiK(i));
        end

        calibrationVector = single([ ...
            s(1) * (single(0.6) + single(0.4) * s(8)), ...
            s(2) * (single(0.6) + single(0.4) * s(10)), ...
            s(3) * (single(0.7) + single(0.3) * (1 - s(5))), ...
            max(s(4), s(5)) * (single(0.6) + single(0.4) * s(10)), ...
            s(9) * (single(0.55) + single(0.45) * stateWeight), ...
            max(s(1), s(10)) * (single(0.55) + single(0.45) * abs(cores(i).winding)), ...
            s(8) * (single(0.55) + single(0.45) * cores(i).preferredFrequency)]);

        calibrationVector = calibrationVector .^ single(0.75);
        [score, index] = max(calibrationVector);

        cores(i).symbol = symbols{index};
        cores(i).symbolIndex = index;
        cores(i).calibrationScore = score;
    end
end

%% ========================================================================
function master = composeMasterImage(IA_RGB, I0, base, spectral, retina, v1, knowledge, state, cfg)
    phaseHue = mod((v1.phase + pi) / (2 * pi), 1);
    phaseSaturation = clamp01(single(0.45) + single(0.55) * v1.phaseCoherence);
    phaseValue = normalize01(v1.energy .* (single(0.25) + single(0.75) * v1.phaseCoherence), ...
        cfg.robustSampleCount);
    phaseRGB = single(hsv2rgb(cat(3, phaseHue, phaseSaturation, phaseValue)));

    retinalRGB = cat(3, ...
        normalize01(retina.on + max(retina.LM, 0), cfg.robustSampleCount), ...
        normalize01(retina.luminance + max(retina.SLM, 0), cfg.robustSampleCount), ...
        normalize01(retina.off + max(-retina.LM, 0), cfg.robustSampleCount));

    edgeGlow = normalize01(base.gradientMagnitude + abs(base.laplacian) + abs(spectral.high), ...
        cfg.robustSampleCount);
    edgeRGB = cat(3, edgeGlow, sqrt(edgeGlow), clamp01(single(0.55) + single(0.45) * edgeGlow));

    sourceGate = normalize01(abs(I0) + base.salience + v1.energy, cfg.robustSampleCount);
    sourceGate3 = repmat(sourceGate, 1, 1, 3);

    stateGain = single(0.85) + single(0.15) * state.phaseOrderFinal;

    master = single(0.48) * IA_RGB ...
        + single(0.24) * phaseRGB .* sourceGate3 ...
        + single(0.18) * retinalRGB .* sourceGate3 ...
        + single(0.10) * edgeRGB .* sourceGate3;

    master = clamp01(master * stateGain);

    if ~isempty(knowledge.cores)
        coreField = zeros(size(I0), 'single');
        for i = 1:numel(knowledge.cores)
            coreField(knowledge.cores(i).y, knowledge.cores(i).x) = knowledge.cores(i).amplitude;
        end
        coreGlow = gaussianBlur(normalize01(coreField, cfg.robustSampleCount), single(3.5));
        master(:, :, 1) = clamp01(master(:, :, 1) + single(0.30) * coreGlow);
        master(:, :, 2) = clamp01(master(:, :, 2) + single(0.45) * coreGlow);
        master(:, :, 3) = clamp01(master(:, :, 3) + single(0.60) * coreGlow);
    end
end

%% ========================================================================
function metrics = buildMetrics(cfg, runTag, decodeMeta, datasetInfo, channelWeights, ...
    base, spectral, optical, photo, retina, v1, knowledge, graphState, state, stageTimes)

    metrics = struct();
    metrics.version = cfg.version;
    metrics.run_tag = runTag;
    metrics.source_file = cfg.sourceFile;
    metrics.dataset_path = cfg.datasetPath;
    metrics.expected_sha256 = cfg.expectedSHA256;
    metrics.decode = decodeMeta;
    metrics.h5_dataspace_size = datasetInfo.Dataspace.Size;
    metrics.channel_weights = double(channelWeights(:).');

    metrics.gradient_mean = double(mean(base.gradientMagnitude, 'all'));
    metrics.laplacian_abs_mean = double(mean(abs(base.laplacian), 'all'));
    metrics.spectral_energy_mean = double(mean(spectral.energy, 'all'));
    metrics.optical_energy_mean = double(mean(optical.energy, 'all'));
    metrics.voltage_mean_final = double(mean(photo.voltage, 'all'));
    metrics.cgmp_mean_final = double(mean(photo.cgmp, 'all'));
    metrics.glutamate_mean_final = double(mean(photo.glutamate, 'all'));
    metrics.retina_on_mean = double(mean(retina.on, 'all'));
    metrics.retina_off_mean = double(mean(retina.off, 'all'));
    metrics.v1_energy_mean = double(mean(v1.energy, 'all'));
    metrics.v1_phase_coherence_mean = double(mean(v1.phaseCoherence, 'all'));

    metrics.number_of_cores = numel(knowledge.cores);
    metrics.number_of_relations = numel(graphState.edges);
    metrics.state_dimension = state.dimension;
    metrics.phase_order_final = double(state.phaseOrderFinal);
    metrics.integration_index_final = double(state.integrationIndexFinal);
    metrics.algebraic_connectivity = double(state.algebraicConnectivity);
    metrics.stage_times = stageTimes;

    if ~isempty(state.entropyBTrace)
        metrics.entropy_B_final = double(state.entropyBTrace(end));
        metrics.entropy_K_final = double(state.entropyKTrace(end));
    else
        metrics.entropy_B_final = 0;
        metrics.entropy_K_final = 0;
    end
end

%% ========================================================================
function paths = writeArtifacts(runDir, I0_RGB, IA_RGB, masterRGB, I0, base, multiscale, ...
    spectral, optical, photo, retina, lgn, v1, knowledge, graphState, state, metrics, cfg)

    paths = struct();

    paths.sourceRGB = fullfile(runDir, '01_I0_source_RGB.png');
    paths.displayRGB = fullfile(runDir, '02_IA_display_RGB.png');
    paths.masterRaw = fullfile(runDir, '03_Quantization_of_Knowledge_master_raw.png');
    paths.masterAnnotated = fullfile(runDir, '04_Quantization_of_Knowledge_master_annotated.png');
    paths.contactSheet = fullfile(runDir, '05_Quantization_of_Knowledge_contact_sheet.png');
    paths.contactMap = fullfile(runDir, '05_Quantization_of_Knowledge_contact_sheet_map.txt');
    paths.derivedH5 = fullfile(runDir, 'Quantization_of_Knowledge_derived_fields.h5');
    paths.metricsJSON = fullfile(runDir, 'Quantization_of_Knowledge_metrics.json');
    paths.coresCSV = fullfile(runDir, 'Quantization_of_Knowledge_cores.csv');
    paths.relationsCSV = fullfile(runDir, 'Quantization_of_Knowledge_relations.csv');
    paths.chainTXT = fullfile(runDir, 'Quantization_of_Knowledge_chain.txt');

    imwrite(toUint8(I0_RGB), paths.sourceRGB);
    imwrite(toUint8(IA_RGB), paths.displayRGB);
    imwrite(toUint8(masterRGB), paths.masterRaw);

    renderAnnotatedMasterRaster(masterRGB, knowledge.cores, graphState.edges, state, ...
        paths.masterAnnotated, cfg);

    renderContactSheetRaster(I0_RGB, IA_RGB, masterRGB, I0, base, multiscale, spectral, ...
        optical, photo, retina, lgn, v1, knowledge, state, paths.contactSheet, cfg);

    writeContactSheetMap(paths.contactMap, knowledge, state);

    writeDerivedH5(paths.derivedH5, I0, masterRGB, base, spectral, optical, photo, ...
        retina, lgn, v1, knowledge, graphState, state);

    rewriteMetrics(paths.metricsJSON, metrics);
    writeCoreTable(paths.coresCSV, knowledge.cores);
    writeRelationTable(paths.relationsCSV, graphState.edges);
    writeChainFile(paths.chainTXT);
end

%% ========================================================================
function renderAnnotatedMasterRaster(masterRGB, cores, edges, state, outputPath, cfg)
% Pure raster renderer. It does not create figures and does not call
% exportgraphics, print, saveas, getframe, tiledlayout, or axes.

    canvas = clamp01(single(masterRGB));

    for e = 1:numel(edges)
        i = edges(e).source;
        j = edges(e).target;

        if i < 1 || j < 1 || i > numel(cores) || j > numel(cores)
            continue;
        end

        w = min(max(single(edges(e).weight), 0), 1);
        phaseValue = single(0.5 + 0.5 * cos(edges(e).phaseDifference));
        color = clamp01(single([0.20 + 0.80 * w, 0.45 + 0.55 * phaseValue, 1.0]));
        alpha = single(0.12 + 0.48 * w);
        thickness = 1 + round(2 * double(w));

        canvas = drawLineRGB(canvas, cores(i).x, cores(i).y, ...
            cores(j).x, cores(j).y, color, alpha, thickness);
    end

    if ~isempty(cores)
        amplitudes = normalizeVector([cores.amplitude]);

        for i = 1:numel(cores)
            radius = 3 + round(6 * amplitudes(i));

            if cores(i).winding >= 0
                markerColor = single([0.75, 1.00, 1.00]);
                canvas = drawCircleRGB(canvas, cores(i).x, cores(i).y, ...
                    radius, markerColor, single(0.92));
            else
                markerColor = single([1.00, 0.72, 0.95]);
                canvas = drawSquareRGB(canvas, cores(i).x, cores(i).y, ...
                    radius, markerColor, single(0.92));
            end
        end

        [~, labelOrder] = sort([cores.calibrationScore] .* [cores.amplitude], 'descend');
        labelCount = min(cfg.render.maxRenderedLabels, numel(labelOrder));

        for k = 1:labelCount
            i = labelOrder(k);
            glyphRadius = 5 + round(3 * amplitudes(i));
            canvas = drawSymbolGlyph(canvas, cores(i).x + glyphRadius + 4, ...
                cores(i).y - glyphRadius - 4, glyphRadius, cores(i).symbolIndex, ...
                single([1, 1, 1]), single(0.95));
        end
    end

    [H, W, ~] = size(canvas);
    barHeight = max(4, round(0.008 * H));
    margin = max(4, round(0.012 * W));
    usable = max(1, W - 2 * margin);

    phaseWidth = round(usable * min(max(double(state.phaseOrderFinal), 0), 1));
    integrationScaled = min(max(double(state.integrationIndexFinal) * 50, 0), 1);
    integrationWidth = round(usable * integrationScaled);

    canvas = fillRectangleRGB(canvas, margin, margin, usable, barHeight, ...
        single([0.08, 0.12, 0.18]), single(0.85));
    canvas = fillRectangleRGB(canvas, margin, margin, phaseWidth, barHeight, ...
        single([0.20, 0.95, 1.00]), single(0.95));

    y2 = margin + barHeight + 3;
    canvas = fillRectangleRGB(canvas, margin, y2, usable, barHeight, ...
        single([0.08, 0.12, 0.18]), single(0.85));
    canvas = fillRectangleRGB(canvas, margin, y2, integrationWidth, barHeight, ...
        single([1.00, 0.45, 0.85]), single(0.95));

    imwrite(toUint8(canvas), outputPath);
end

%% ========================================================================
function renderContactSheetRaster(I0_RGB, IA_RGB, masterRGB, I0, base, multiscale, spectral, ...
    optical, photo, retina, lgn, v1, knowledge, state, outputPath, cfg)
% Pure raster 4x4 contact sheet. Panel numbering is written directly into
% the image matrix. Panel names are stored in the adjacent map text file.

    panels = cell(16, 1);
    panels{1} = clamp01(I0_RGB);
    panels{2} = clamp01(IA_RGB);
    panels{3} = scalarToRGB(I0, cfg);
    panels{4} = scalarToRGB(base.gradientMagnitude, cfg);
    panels{5} = scalarToRGB(base.laplacian, cfg);
    panels{6} = scalarToRGB(multiscale.dogEnergy, cfg);
    panels{7} = scalarToRGB(spectral.fftLogMagnitude, cfg);
    panels{8} = scalarToRGB(optical.energy, cfg);
    panels{9} = scalarToRGB(optical.Q(:, :, 1), cfg);
    panels{10} = scalarToRGB(optical.Q(:, :, 2), cfg);
    panels{11} = scalarToRGB(optical.Q(:, :, 3), cfg);
    panels{12} = scalarToRGB(photo.meanVoltage, cfg);
    panels{13} = scalarToRGB(retina.on + retina.off, cfg);
    panels{14} = scalarToRGB(lgn.relay, cfg);
    panels{15} = scalarToRGB(v1.energy, cfg);
    panels{16} = clamp01(masterRGB);

    panelSize = cfg.render.contactPanelSize;
    border = cfg.render.contactBorder;
    cellSize = panelSize + 2 * border;

    sheet = zeros(4 * cellSize, 4 * cellSize, 3, 'single');
    sheet(:) = single(0.025);

    for p = 1:16
        row = floor((p - 1) / 4);
        col = mod(p - 1, 4);

        y0 = row * cellSize + border + 1;
        x0 = col * cellSize + border + 1;

        panel = resizeImageLocal(panels{p}, panelSize, panelSize);
        sheet(y0:y0 + panelSize - 1, x0:x0 + panelSize - 1, :) = panel;

        borderColor = single([0.65, 0.72, 0.82]);
        sheet = drawRectangleOutlineRGB(sheet, x0 - 1, y0 - 1, ...
            panelSize + 2, panelSize + 2, borderColor, single(0.95), 2);

        sheet = drawIntegerRGB(sheet, x0 + 8, y0 + 8, p, 4, ...
            single([1, 1, 1]), single(0.98));
    end

    phaseBarWidth = round(size(sheet, 2) * min(max(double(state.phaseOrderFinal), 0), 1));
    coreBarWidth = round(size(sheet, 2) * min(numel(knowledge.cores) / max(cfg.quantization.maxCores, 1), 1));

    sheet = fillRectangleRGB(sheet, 1, 1, size(sheet, 2), 5, ...
        single([0.02, 0.03, 0.05]), single(1));
    sheet = fillRectangleRGB(sheet, 1, 1, phaseBarWidth, 2, ...
        single([0.20, 0.95, 1.00]), single(1));
    sheet = fillRectangleRGB(sheet, 1, 4, coreBarWidth, 2, ...
        single([1.00, 0.45, 0.85]), single(1));

    imwrite(toUint8(sheet), outputPath);
end

%% ========================================================================
function writeContactSheetMap(filePath, knowledge, state)

    lines = {
        'Quantization_of_Knowledge contact sheet map';
        '01 = I0 source RGB';
        '02 = IA display operator RGB';
        '03 = canonical integrated field I0';
        '04 = gradient magnitude';
        '05 = Laplacian';
        '06 = multiscale DoG energy';
        '07 = log FFT magnitude';
        '08 = optical energy field';
        '09 = qL cone field';
        '10 = qM cone field';
        '11 = qS cone field';
        '12 = mean photoreceptor voltage';
        '13 = retinal ON plus OFF';
        '14 = relay field';
        '15 = V1 oriented energy';
        '16 = master image';
        sprintf('number_of_cores = %d', numel(knowledge.cores));
        sprintf('phase_order_final = %.9g', state.phaseOrderFinal);
        sprintf('integration_index_final = %.9g', state.integrationIndexFinal)
        };

    fid = fopen(filePath, 'w');
    if fid < 0
        error('Could not write contact sheet map.');
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end

%% ========================================================================
function rgb = scalarToRGB(field, cfg)

    normalized = normalize01(single(real(field)), cfg.robustSampleCount);

    if exist('turbo', 'file') == 2 || exist('turbo', 'builtin') == 5
        map = single(turbo(256));
    else
        map = single(parula(256));
    end

    index = 1 + floor(double(normalized) * 255);
    index = min(max(index, 1), 256);

    rgb = reshape(map(index(:), :), size(field, 1), size(field, 2), 3);
    rgb = clamp01(rgb);
end

%% ========================================================================
function output = resizeImageLocal(input, newHeight, newWidth)
% Toolbox-independent bilinear resizing through interp2.

    input = single(input);

    if ndims(input) == 2
        input = reshape(input, size(input, 1), size(input, 2), 1);
    end

    oldHeight = size(input, 1);
    oldWidth = size(input, 2);
    channels = size(input, 3);

    if oldHeight == newHeight && oldWidth == newWidth
        output = input;
        return;
    end

    xq = linspace(1, oldWidth, newWidth);
    yq = linspace(1, oldHeight, newHeight);
    [Xq, Yq] = meshgrid(xq, yq);

    output = zeros(newHeight, newWidth, channels, 'single');

    for c = 1:channels
        output(:, :, c) = single(interp2(double(input(:, :, c)), Xq, Yq, 'linear'));
    end

    output(~isfinite(output)) = 0;
    output = clamp01(output);
end

%% ========================================================================
function image = drawLineRGB(image, x1, y1, x2, y2, color, alpha, thickness)

    n = max(abs(round(x2) - round(x1)), abs(round(y2) - round(y1))) + 1;
    n = max(n, 2);

    xs = round(linspace(double(x1), double(x2), n));
    ys = round(linspace(double(y1), double(y2), n));

    radius = max(0, floor((thickness - 1) / 2));

    for k = 1:n
        for dy = -radius:radius
            for dx = -radius:radius
                if dx * dx + dy * dy <= max(radius * radius, 1)
                    image = blendPixelRGB(image, xs(k) + dx, ys(k) + dy, color, alpha);
                end
            end
        end
    end
end

%% ========================================================================
function image = drawCircleRGB(image, xc, yc, radius, color, alpha)

    samples = max(24, round(8 * pi * radius));
    theta = linspace(0, 2 * pi, samples);
    xs = xc + radius * cos(theta);
    ys = yc + radius * sin(theta);

    image = drawPolylineRGB(image, xs, ys, color, alpha, 2);
end

%% ========================================================================
function image = drawSquareRGB(image, xc, yc, radius, color, alpha)

    xs = [xc - radius, xc + radius, xc + radius, xc - radius, xc - radius];
    ys = [yc - radius, yc - radius, yc + radius, yc + radius, yc - radius];

    image = drawPolylineRGB(image, xs, ys, color, alpha, 2);
end

%% ========================================================================
function image = drawRectangleOutlineRGB(image, x, y, width, height, color, alpha, thickness)

    xs = [x, x + width - 1, x + width - 1, x, x];
    ys = [y, y, y + height - 1, y + height - 1, y];
    image = drawPolylineRGB(image, xs, ys, color, alpha, thickness);
end

%% ========================================================================
function image = fillRectangleRGB(image, x, y, width, height, color, alpha)

    if width <= 0 || height <= 0
        return;
    end

    H = size(image, 1);
    W = size(image, 2);

    x1 = max(1, round(x));
    y1 = max(1, round(y));
    x2 = min(W, round(x + width - 1));
    y2 = min(H, round(y + height - 1));

    if x2 < x1 || y2 < y1
        return;
    end

    alpha = min(max(single(alpha), 0), 1);
    color = reshape(single(color), 1, 1, 3);

    region = image(y1:y2, x1:x2, :);
    image(y1:y2, x1:x2, :) = (1 - alpha) * region + alpha * color;
end

%% ========================================================================
function image = drawPolylineRGB(image, xs, ys, color, alpha, thickness)

    for k = 1:numel(xs) - 1
        image = drawLineRGB(image, xs(k), ys(k), xs(k + 1), ys(k + 1), ...
            color, alpha, thickness);
    end
end

%% ========================================================================
function image = blendPixelRGB(image, x, y, color, alpha)

    x = round(x);
    y = round(y);

    if x < 1 || y < 1 || x > size(image, 2) || y > size(image, 1)
        return;
    end

    alpha = min(max(single(alpha), 0), 1);
    oldPixel = reshape(image(y, x, :), 1, 3);
    newPixel = (1 - alpha) * oldPixel + alpha * reshape(single(color), 1, 3);
    image(y, x, :) = reshape(clamp01(newPixel), 1, 1, 3);
end

%% ========================================================================
function image = drawSymbolGlyph(image, xc, yc, radius, symbolIndex, color, alpha)
% Raster stroke glyphs for the calibrated symbols:
% 1 nabla, 2 partial, 3 integral, 4 Sigma, 5 eta, 6 Omega, 7 vector-v.

    r = max(3, radius);

    switch symbolIndex
        case 1
            xs = [xc, xc - r, xc + r, xc];
            ys = [yc + r, yc - r, yc - r, yc + r];
            image = drawPolylineRGB(image, xs, ys, color, alpha, 2);

        case 2
            theta = linspace(-0.35 * pi, 1.55 * pi, 28);
            xs = xc + 0.65 * r * cos(theta);
            ys = yc + 0.75 * r * sin(theta);
            image = drawPolylineRGB(image, xs, ys, color, alpha, 2);
            image = drawLineRGB(image, xc + 0.2 * r, yc - r, ...
                xc - 0.35 * r, yc + r, color, alpha, 2);

        case 3
            xs = xc + r * [-0.45, -0.75, -0.55, 0.30, 0.55, 0.25, 0.05];
            ys = yc + r * [-1.00, -0.65, -0.20, 0.20, 0.65, 1.00, 1.20];
            image = drawPolylineRGB(image, xs, ys, color, alpha, 2);

        case 4
            xs = [xc + r, xc - r, xc, xc - r, xc + r];
            ys = [yc - r, yc - r, yc, yc + r, yc + r];
            image = drawPolylineRGB(image, xs, ys, color, alpha, 2);

        case 5
            xs = xc + r * [-1, -1, -0.55, 0.15, 0.65, 0.65];
            ys = yc + r * [1, -1, -1, -0.25, 0.10, 1];
            image = drawPolylineRGB(image, xs, ys, color, alpha, 2);

        case 6
            theta = linspace(pi, 2 * pi, 32);
            xs = xc + r * cos(theta);
            ys = yc + r * sin(theta);
            image = drawPolylineRGB(image, xs, ys, color, alpha, 2);
            image = drawLineRGB(image, xc - r, yc, xc - 0.45 * r, yc + r, color, alpha, 2);
            image = drawLineRGB(image, xc + r, yc, xc + 0.45 * r, yc + r, color, alpha, 2);
            image = drawLineRGB(image, xc - 0.45 * r, yc + r, xc + 0.45 * r, yc + r, color, alpha, 2);

        case 7
            image = drawLineRGB(image, xc - r, yc - 0.4 * r, xc, yc + r, color, alpha, 2);
            image = drawLineRGB(image, xc, yc + r, xc + r, yc - 0.4 * r, color, alpha, 2);
            image = drawLineRGB(image, xc - r, yc - r, xc + r, yc - r, color, alpha, 2);
            image = drawLineRGB(image, xc + r, yc - r, xc + 0.55 * r, yc - 1.3 * r, color, alpha, 2);
            image = drawLineRGB(image, xc + r, yc - r, xc + 0.55 * r, yc - 0.7 * r, color, alpha, 2);

        otherwise
            image = drawCircleRGB(image, xc, yc, r, color, alpha);
    end
end

%% ========================================================================
function image = drawIntegerRGB(image, x, y, value, scale, color, alpha)

    textValue = sprintf('%02d', value);
    cursorX = x;

    for i = 1:numel(textValue)
        digit = double(textValue(i) - '0');
        image = drawDigitRGB(image, cursorX, y, digit, scale, color, alpha);
        cursorX = cursorX + 4 * scale;
    end
end

%% ========================================================================
function image = drawDigitRGB(image, x, y, digit, scale, color, alpha)

    glyphs = {
        [1 1 1; 1 0 1; 1 0 1; 1 0 1; 1 1 1], ... % 0
        [0 1 0; 1 1 0; 0 1 0; 0 1 0; 1 1 1], ... % 1
        [1 1 1; 0 0 1; 1 1 1; 1 0 0; 1 1 1], ... % 2
        [1 1 1; 0 0 1; 1 1 1; 0 0 1; 1 1 1], ... % 3
        [1 0 1; 1 0 1; 1 1 1; 0 0 1; 0 0 1], ... % 4
        [1 1 1; 1 0 0; 1 1 1; 0 0 1; 1 1 1], ... % 5
        [1 1 1; 1 0 0; 1 1 1; 1 0 1; 1 1 1], ... % 6
        [1 1 1; 0 0 1; 0 1 0; 0 1 0; 0 1 0], ... % 7
        [1 1 1; 1 0 1; 1 1 1; 1 0 1; 1 1 1], ... % 8
        [1 1 1; 1 0 1; 1 1 1; 0 0 1; 1 1 1]};    % 9

    if digit < 0 || digit > 9
        return;
    end

    glyph = glyphs{digit + 1};

    for row = 1:5
        for col = 1:3
            if glyph(row, col) ~= 0
                image = fillRectangleRGB(image, x + (col - 1) * scale, ...
                    y + (row - 1) * scale, scale, scale, color, alpha);
            end
        end
    end
end

%% ========================================================================
function writeDerivedH5(filePath, I0, masterRGB, base, spectral, optical, photo, ...
    retina, lgn, v1, knowledge, graphState, state)

    h5writeDataset(filePath, '/source/I0', single(I0));
    h5writeDataset(filePath, '/display/master_RGB', single(masterRGB));
    h5writeDataset(filePath, '/differential/gradient_magnitude', single(base.gradientMagnitude));
    h5writeDataset(filePath, '/differential/laplacian', single(base.laplacian));
    h5writeDataset(filePath, '/spectral/low', single(spectral.low));
    h5writeDataset(filePath, '/spectral/mid', single(spectral.mid));
    h5writeDataset(filePath, '/spectral/high', single(spectral.high));
    h5writeDataset(filePath, '/optical/Q_LMS', single(optical.Q));
    h5writeDataset(filePath, '/photo/voltage', single(photo.voltage));
    h5writeDataset(filePath, '/photo/cgmp', single(photo.cgmp));
    h5writeDataset(filePath, '/photo/glutamate', single(photo.glutamate));
    h5writeDataset(filePath, '/retina/on', single(retina.on));
    h5writeDataset(filePath, '/retina/off', single(retina.off));
    h5writeDataset(filePath, '/retina/LM', single(retina.LM));
    h5writeDataset(filePath, '/retina/SLM', single(retina.SLM));
    h5writeDataset(filePath, '/relay/field', single(lgn.relay));
    h5writeDataset(filePath, '/v1/energy', single(v1.energy));
    h5writeDataset(filePath, '/v1/orientation', single(v1.orientation));
    h5writeDataset(filePath, '/v1/phase', single(v1.phase));
    h5writeDataset(filePath, '/v1/phase_coherence', single(v1.phaseCoherence));
    h5writeDataset(filePath, '/quantization/winding', single(knowledge.winding));
    h5writeDataset(filePath, '/graph/adjacency', single(graphState.adjacency));
    h5writeDataset(filePath, '/graph/laplacian', single(graphState.laplacian));
    h5writeDataset(filePath, '/state/rhoB_real', single(real(state.rhoB)));
    h5writeDataset(filePath, '/state/rhoB_imag', single(imag(state.rhoB)));
    h5writeDataset(filePath, '/state/rhoK_real', single(real(state.rhoK)));
    h5writeDataset(filePath, '/state/rhoK_imag', single(imag(state.rhoK)));
    h5writeDataset(filePath, '/state/phase_order_trace', single(state.phaseOrderTrace));
    h5writeDataset(filePath, '/state/integration_trace', single(state.integrationTrace));

    if ~isempty(knowledge.cores)
        coreMatrix = zeros(numel(knowledge.cores), 17, 'single');
        for i = 1:numel(knowledge.cores)
            coreMatrix(i, :) = single([knowledge.cores(i).id, knowledge.cores(i).x, ...
                knowledge.cores(i).y, knowledge.cores(i).amplitude, ...
                knowledge.cores(i).phase, knowledge.cores(i).winding, ...
                knowledge.cores(i).orientation, knowledge.cores(i).preferredFrequency, ...
                knowledge.cores(i).sourceValue, knowledge.cores(i).signature(1:7), ...
                knowledge.cores(i).calibrationScore]);
        end
        h5writeDataset(filePath, '/quantization/cores_numeric', coreMatrix);
    end
end

%% ========================================================================
function h5writeDataset(filePath, datasetPath, data)
    if isempty(data)
        return;
    end
    dataSize = size(data);
    h5create(filePath, datasetPath, dataSize, 'Datatype', class(data), ...
        'ChunkSize', chooseChunkSize(dataSize), 'Deflate', 4);
    h5write(filePath, datasetPath, data);
end

%% ========================================================================
function chunk = chooseChunkSize(dataSize)
    chunk = dataSize;
    if numel(dataSize) >= 2
        chunk(1) = min(dataSize(1), 128);
        chunk(2) = min(dataSize(2), 128);
    end
    if numel(dataSize) >= 3
        chunk(3) = min(dataSize(3), 3);
    end
    chunk = max(chunk, 1);
end

%% ========================================================================
function rewriteMetrics(filePath, metrics)
    try
        text = jsonencode(metrics, 'PrettyPrint', true);
    catch
        text = jsonencode(metrics);
    end

    fid = fopen(filePath, 'w');
    if fid < 0
        error('Could not write metrics JSON.');
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, text, 'char');
end

%% ========================================================================
function writeCoreTable(filePath, cores)
    N = numel(cores);
    if N == 0
        T = table();
        writetable(T, filePath);
        return;
    end

    id = zeros(N, 1);
    x = zeros(N, 1);
    y = zeros(N, 1);
    amplitude = zeros(N, 1);
    phase = zeros(N, 1);
    winding = zeros(N, 1);
    orientation = zeros(N, 1);
    preferredFrequency = zeros(N, 1);
    calibrationScore = zeros(N, 1);
    symbol = strings(N, 1);

    for i = 1:N
        id(i) = cores(i).id;
        x(i) = cores(i).x;
        y(i) = cores(i).y;
        amplitude(i) = cores(i).amplitude;
        phase(i) = cores(i).phase;
        winding(i) = cores(i).winding;
        orientation(i) = cores(i).orientation;
        preferredFrequency(i) = cores(i).preferredFrequency;
        calibrationScore(i) = cores(i).calibrationScore;
        symbol(i) = string(cores(i).symbol);
    end

    T = table(id, x, y, amplitude, phase, winding, orientation, ...
        preferredFrequency, calibrationScore, symbol);
    writetable(T, filePath);
end

%% ========================================================================
function writeRelationTable(filePath, edges)
    N = numel(edges);
    if N == 0
        T = table();
        writetable(T, filePath);
        return;
    end

    source = zeros(N, 1);
    target = zeros(N, 1);
    distance = zeros(N, 1);
    weight = zeros(N, 1);
    phaseDifference = zeros(N, 1);
    featureSimilarity = zeros(N, 1);

    for i = 1:N
        source(i) = edges(i).source;
        target(i) = edges(i).target;
        distance(i) = edges(i).distance;
        weight(i) = edges(i).weight;
        phaseDifference(i) = edges(i).phaseDifference;
        featureSimilarity(i) = edges(i).featureSimilarity;
    end

    T = table(source, target, distance, weight, phaseDifference, featureSimilarity);
    writetable(T, filePath);
end

%% ========================================================================
function writeChainFile(filePath)
    lines = {
        'Quantization_of_Knowledge';
        'For_The_Quantization_of_Knowledge';
        '';
        'I_0(x,y) -> I_A(x,y)';
        'I_A(x,y) -> S_A(lambda,x,y,t)';
        'S_A(lambda,x,y,t) -> Q_LMS(x,y,t)';
        'Q_LMS(x,y,t) -> V_photo(x,y,t)';
        'V_photo(x,y,t) -> R_retina(x,y,t)';
        'R_retina(x,y,t) -> F_V1(x,y)';
        'F_V1(x,y) -> K={kappa_i}';
        'K -> E={r_ij}';
        '(K,E) -> Sigma';
        '(K,E,Sigma) -> coupled state update';
        '';
        'kappa_i = vortex core';
        'r_ij = relation between knowledge quanta';
        'Sigma = calibrated human mathematical and scientific symbols';
        };

    fid = fopen(filePath, 'w');
    if fid < 0
        error('Could not write chain file.');
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end

%% ========================================================================
function Y = gaussianBlur(X, sigma)
    sigma = double(sigma);
    if sigma <= 0
        Y = X;
        return;
    end

    radius = max(1, ceil(3.5 * sigma));
    x = single(-radius:radius);
    kernel = exp(-0.5 * (x / single(sigma)) .^ 2);
    kernel = kernel / sum(kernel);

    Y = conv2(conv2(single(X), kernel, 'same'), kernel.', 'same');
end

%% ========================================================================
function [U, V] = frequencyGrid(H, W)
    u = single(ifftshift((-floor(W / 2):ceil(W / 2) - 1) / W));
    v = single(ifftshift((-floor(H / 2):ceil(H / 2) - 1) / H));
    [U, V] = meshgrid(u, v);
end

%% ========================================================================
function Y = robustSignedNormalize(X, sampleCount)
    X = single(X);
    finiteMask = isfinite(X);
    values = X(finiteMask);
    if isempty(values)
        Y = zeros(size(X), 'single');
        return;
    end

    step = max(1, floor(numel(values) / sampleCount));
    sample = double(values(1:step:end));
    center = median(sample);
    scale = 1.4826 * median(abs(sample - center));
    if ~isfinite(scale) || scale < 1e-12
        scale = std(sample);
    end
    if ~isfinite(scale) || scale < 1e-12
        scale = 1;
    end

    Y = single((double(X) - center) / (3 * scale));
    Y = tanh(Y);
    Y(~finiteMask) = 0;
end

%% ========================================================================
function Y = normalize01(X, sampleCount)
    X = single(real(X));
    low = samplePercentile(X, 0.5, sampleCount);
    high = samplePercentile(X, 99.5, sampleCount);

    if ~isfinite(low) || ~isfinite(high) || high <= low
        low = min(X, [], 'all');
        high = max(X, [], 'all');
    end

    if high <= low
        Y = zeros(size(X), 'single');
    else
        Y = (X - low) / (high - low);
        Y = clamp01(Y);
    end
end

%% ========================================================================
function value = samplePercentile(X, percentile, sampleCount)
    values = X(isfinite(X));
    if isempty(values)
        value = single(0);
        return;
    end

    step = max(1, floor(numel(values) / sampleCount));
    sample = sort(single(values(1:step:end)));
    position = 1 + (numel(sample) - 1) * double(percentile) / 100;
    lowerIndex = max(1, floor(position));
    upperIndex = min(numel(sample), ceil(position));
    fraction = single(position - lowerIndex);
    value = sample(lowerIndex) * (1 - fraction) + sample(upperIndex) * fraction;
end

%% ========================================================================
function y = sampleMap(map, x, yIndex)
    x = min(max(round(x), 1), size(map, 2));
    yIndex = min(max(round(yIndex), 1), size(map, 1));
    y = map(yIndex, x);
end

%% ========================================================================
function Y = srgbDecode(X)
    X = clamp01(single(X));
    Y = zeros(size(X), 'single');
    mask = X <= single(0.04045);
    Y(mask) = X(mask) / single(12.92);
    Y(~mask) = ((X(~mask) + single(0.055)) / single(1.055)) .^ single(2.4);
end

%% ========================================================================
function Y = srgbEncode(X)
    X = max(single(X), 0);
    Y = zeros(size(X), 'single');
    mask = X <= single(0.0031308);
    Y(mask) = single(12.92) * X(mask);
    Y(~mask) = single(1.055) * X(~mask) .^ single(1 / 2.4) - single(0.055);
    Y = clamp01(Y);
end

%% ========================================================================
function Y = clamp01(X)
    Y = min(max(single(X), single(0)), single(1));
end

%% ========================================================================
function Y = wrapToPiLocal(X)
    Y = mod(X + single(pi), single(2 * pi)) - single(pi);
end

%% ========================================================================
function values = normalizeVector(values)
    values = double(values(:).');
    if isempty(values)
        return;
    end
    low = min(values);
    high = max(values);
    if high <= low
        values = ones(size(values));
    else
        values = (values - low) / (high - low);
    end
end

%% ========================================================================
function image8 = toUint8(imageSingle)
    image8 = uint8(round(255 * double(clamp01(imageSingle))));
end
