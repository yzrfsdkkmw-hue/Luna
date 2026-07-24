function result = YEHOSHUA_PLATO_RECONSTRUCTION_v2()
% YEHOSHUA_PLATO_RECONSTRUCTION_v2
% Mathematical implementation of:
% YEHOSHUA_PLATO_RECONSTRUCTION_PREEXECUTION_MATH_v5_MATHEMATICAL_CORE
% neutral_wave_atlas_v1 temporal integration

cfg = makeConfig();
rng(cfg.seed, 'twister');

runID = datestr(now, 'yyyymmdd_HHMMSS_FFF');
outDir = fullfile(cfg.root, ['YEHOSHUA_PLATO_RECONSTRUCTION_v2_' runID]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% SSOT
assert(isfile(cfg.ssotFile), 'SSOT file not found: %s', cfg.ssotFile);
actualHash = sha256File(cfg.ssotFile);
assert(strcmpi(actualHash, cfg.ssotSHA256), ...
    'SHA256 mismatch. expected=%s actual=%s', cfg.ssotSHA256, actualHash);

F = readSSOT(cfg);
assert(isequal(size(F), cfg.ssotShape), 'SSOT shape mismatch.');
assert(numel(F) == cfg.ssotValueCount, 'SSOT value-count mismatch.');
assert(all(isfinite(F(:))), 'SSOT contains non-finite values.');

ssot = buildSSOTBasis(F, cfg);

%% Inputs
refs = loadReferenceManifest(cfg);
[refs, consensus] = normalizeReferences(refs, cfg);
v1Bank = buildV1Bank(cfg);
orchKernels = loadOrchKernels(cfg);
atlas = loadNeutralPDEAtlas(cfg);
for j = 1:numel(refs)
    refs(j).phi = phiPipeline(refs(j).alignedRGB, orchKernels, v1Bank, cfg);
end

%% Fixed feature fields
consensusPhi = phiPipeline(consensus.rgb, orchKernels, v1Bank, cfg);

graphRef = buildKnowledgeGraph(consensusPhi, [], cfg);
ssotWork = resizeField(ssot.Z, cfg.workSize);
ssotBasisWork = buildWorkResidualBasis(ssotWork);

ctx = struct();
ctx.cfg = cfg;
ctx.refs = refs;
ctx.consensus = consensus;
ctx.orchKernels = orchKernels;
ctx.v1Bank = v1Bank;
ctx.atlas = atlas;
ctx.consensusPhi = consensusPhi;
ctx.graphRef = graphRef;
ctx.ssotWork = ssotWork;
ctx.ssotBasisWork = ssotBasisWork;
ctx.mode = modeWeights('E', cfg);

%% Optimization
theta0 = zeros(9, 1);
[thetaStar, EStar, optInfo] = optimizeTheta(theta0, ctx, cfg);

%% Luna geodesic update
luna = lunaGeodesicStep(thetaStar, ctx, cfg);
if luna.E_next < EStar
    thetaFinal = luna.theta_next;
    EFinal = luna.E_next;
else
    thetaFinal = thetaStar;
    EFinal = EStar;
end

[~, partsFinal, stateFinal] = totalObjective(thetaFinal, ctx);

%% Leave-one-object-out
loo = leaveOneObjectOut(thetaFinal, ctx, cfg);

%% Hessian ensemble
[H, SigmaTheta] = numericalHessian(@(x) totalObjectiveScalar(x, ctx), ...
    thetaFinal, cfg.hessianStep, cfg.hessianPairs);
[ensemble, ensembleTheta] = renderEnsemble(thetaFinal, SigmaTheta, ctx, cfg);
Imean = mean(ensemble, 4);
Ivar = var(ensemble, 0, 4);

%% Neutral PDE temporal analysis
pdeTemporal = fullPDETemporalAnalysis(stateFinal.gray, atlas, cfg);

%% Uncertainty field
Sunc = rank01(mean(Ivar, 3) + consensus.damage + consensus.restoration + ...
    loo.residualMap + cfg.pde.uncertaintyWeight*(1-pdeTemporal.persistenceMap));
Ustar = uncertaintyPDE(Sunc, cfg);
Cmap = exp(-Ustar / cfg.tauU);

%% Metrics
metrics = computeMetrics(thetaFinal, EFinal, partsFinal, stateFinal, loo, ...
    SigmaTheta, consensus, refs, cfg);

%% Ablation
ablation = runAblation(thetaStar, thetaFinal, ctx, ensemble, graphRef, cfg);

%% Outputs
writeOutputs(outDir, cfg, refs, consensus, stateFinal, graphRef, atlas, ...
    pdeTemporal, luna, ensemble, ensembleTheta, Imean, Ivar, Ustar, Cmap, ...
    loo, ablation, metrics, thetaStar, thetaFinal, H, SigmaTheta, optInfo, actualHash);

result = struct();
result.run_id = runID;
result.output_directory = outDir;
result.theta_star = thetaStar;
result.theta_final = thetaFinal;
result.E_star = EStar;
result.E_final = EFinal;
result.metrics = metrics;
result.luna = luna;
result.loo = loo;
result.ablation = ablation;
result.pde_temporal = pdeTemporal.metrics;
result.output_files = cfg.outputFiles;
end

%% Configuration
function cfg = makeConfig()
cfg.matlabDrive = '/MATLAB Drive';
cfg.root = fullfile(cfg.matlabDrive, 'modelTRAINING');
cfg.ssotFile = fullfile(cfg.root, 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5');
cfg.ssotDataset = '/n_5_composite_field_1000x1000/data';
cfg.ssotSHA256 = '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.ssotShape = [1000 1000 5];
cfg.ssotValueCount = 5000000;
codeDir = fileparts(mfilename('/MATLAB Drive/modelTRAINING/plato_reference_manifest.json'));
cfg.referenceManifest = fullfile(codeDir, 'plato_reference_manifest.json');cfg.minimumObjects = 3;
cfg.orchFile = fullfile(cfg.root, 'OrchParticleFoundationsLearningTensors.h5');
cfg.orchMaximumMaps = 32;

cfg.pde.runDir = fullfile(cfg.matlabDrive, 'YEHOSHUA_NEUTRAL_PDE_EXPORTS', ...
    '20260713T234010Z_f4e1967e');
cfg.pde.atlasFile = fullfile(cfg.pde.runDir, 'neutral_wave_atlas_v1.png');
cfg.pde.runtimeManifest = fullfile(cfg.pde.runDir, 'runtime_manifest.json');
cfg.pde.validationReport = fullfile(cfg.pde.runDir, 'matlab_validation_report.json');
cfg.pde.derivationManifest = fullfile(cfg.pde.runDir, 'derivation_manifest.internal.json');
cfg.pde.atlasSHA256 = 'afba00219d0ec28168f30aaab352bf6074aa048f1b596203376ed7807425716f';
cfg.pde.frameGrid = [4 4];
cfg.pde.frameCount = 16;
cfg.pde.frameSize = [256 256];
cfg.pde.pcaEnergyTarget = 0.96;
cfg.pde.maximumModes = 5;
cfg.pde.materialIntensity = 0.35;
cfg.pde.spatialScale = 1.0;
cfg.pde.rotationRate = 0.0;
cfg.pde.responseWeight = 0.35;
cfg.pde.sensitivityWeight = 0.30;
cfg.pde.persistenceTau = 0.075;
cfg.pde.uncertaintyWeight = 0.35;

cfg.workSize = [256 256];
cfg.seed = 271828;
cfg.eps = 1e-9;

cfg.display.contrast = 1.0;
cfg.display.white = 1.0;
cfg.display.black = 0.0;
cfg.display.rho = 1.0;

cfg.photo.lambda = (380:5:780)';
cfg.photo.primaryCenters = [610 545 460];
cfg.photo.primaryWidths = [35 30 25];
cfg.photo.coneCenters = [560 530 420];
cfg.photo.coneWidths = [40 35 25];
cfg.photo.steps = 48;
cfg.photo.dt = 0.05;
cfg.photo.kOplus = 1.10;
cfg.photo.kOminus = 0.35;
cfg.photo.kTplus = 0.95;
cfg.photo.kTminus = 0.30;
cfg.photo.kPplus = 0.85;
cfg.photo.kPminus = 0.25;
cfg.photo.kSyn = 0.60;
cfg.photo.kHyd = 0.80;
cfg.photo.n = 3.0;
cfg.photo.KCNG = 0.45;
cfg.photo.Vdark = -0.25;
cfg.photo.Ghyp = 1.0;
cfg.photo.thetaGlu = -0.45;
cfg.photo.sGlu = 0.10;

cfg.retina.sigmaC = 1.2;
cfg.retina.sigmaS = 3.6;
cfg.retina.alphaS = 0.82;
cfg.retina.sigmaD = 4.0;
cfg.retina.epsD = 1e-4;
cfg.v1.orientations = 0:30:150;
cfg.v1.wavelengths = [4 8 16];

cfg.graph.maxQuanta = 64;
cfg.graph.sigmaP = [];
cfg.graph.sigmaMu = [];
cfg.graph.spectrumCount = 24;

cfg.thetaLB = [-1 -1 -1 -1 -1 -1 -1 -1 -1]';
cfg.thetaUB = [ 1  1  1  1  1  1  1  1  1]';
cfg.optimizerMaxIterations = 48;
cfg.optimizerMaxEvaluations = 650;
cfg.looMaxIterations = 20;
cfg.hessianStep = 0.025;
cfg.hessianPairs = [nchoosek(1:6,2); 7 9; 1 7; 2 7; 1 9; 2 9; 3 9];
cfg.ensembleCount = 9;
cfg.ensembleScale = 0.45;
cfg.lunaStep = 0.12;
cfg.lunaFDStep = 0.02;
cfg.lunaLambda = 1e-3 * ones(8,1);

cfg.lambda.d = 1.00;
cfg.lambda.l = 0.80;
cfg.lambda.s = 0.55;
cfg.lambda.n = 0.35;
cfg.lambda.y = 0.15;
cfg.lambda.m = 0.08;
cfg.lambda.a = 0.20;
cfg.lambda.c = 0.05;
cfg.lambda.t = 0.05;
cfg.lambda.T = 0.25;
cfg.lambda.graph = 0.45;
cfg.lambda.ssot = 0.35;
cfg.lambda.orch = 0.20;
cfg.lambda.pde = 0.18;
cfg.lambda.A = 0.10;
cfg.lambda.res = 0.20;
cfg.lambda.O = 0.40;
cfg.lambda.Q = 0.40;
cfg.lambda.P = 0.20;

cfg.robustDelta = 0.25;
cfg.sigmaCopy = 0.5;
cfg.sigmaStyle = 0.5;
cfg.residualPi = [0.40 0.30 0.20 0.10];

cfg.uncertainty.D = 0.18;
cfg.uncertainty.lambda = 0.08;
cfg.uncertainty.dt = 0.15;
cfg.uncertainty.steps = 300;
cfg.tauU = 0.25;

cfg.tau.source = 1.0;
cfg.tau.landmark = 0.05;
cfg.tau.loo = 0.05;
cfg.tau.graph = 1.0;
cfg.tau.posterior = 1.0;
cfg.tau.pde = 0.40;

cfg.outputFiles = { ...
    '00_run_manifest.json', ...
    '01_reference_registry.csv', ...
    '02_reference_alignment.png', ...
    '03_landmark_consensus.png', ...
    '04_shape_depth_consensus.mat', ...
    '05_nuisance_parameters.csv', ...
    '06_v1_orch_qok.h5', ...
    '07_knowledge_quanta.csv', ...
    '08_graph_laplacian_spectrum.csv', ...
    '09_luna_states.json', ...
    '10_visual_ensemble_3x3.png', ...
    '11_ensemble_mean.png', ...
    '12_uncertainty_map.png', ...
    '13_shape_variance_map.png', ...
    '14_leave_one_object_out.json', ...
    '15_ablation.json', ...
    '16_metrics.json', ...
    '17_pde_temporal_metrics.json', ...
    '18_structural_persistence_map.png', ...
    '19_pde_basis_grid.png', ...
    '20_pde_response_grid.png'};
end

%% Source decode
function F = readSSOT(cfg)
raw = h5read(cfg.ssotFile, cfg.ssotDataset);
v = double(raw(:));
assert(numel(v) == cfg.ssotValueCount, 'Unexpected dataset length.');
F = permute(reshape(v, [5 1000 1000]), [2 3 1]);
end


function atlas = loadNeutralPDEAtlas(cfg)
atlasFile = locateFileBySHA(cfg.pde.atlasFile, cfg.matlabDrive, ...
    'neutral_wave_atlas_v1.png', cfg.pde.atlasSHA256);
runDir = fileparts(atlasFile);

runtimeFile = fullfile(runDir, 'runtime_manifest.json');
validationFile = fullfile(runDir, 'matlab_validation_report.json');
derivationFile = fullfile(runDir, 'derivation_manifest.internal.json');

assert(isfile(runtimeFile), 'Runtime manifest not found: %s', runtimeFile);
assert(isfile(validationFile), 'Validation report not found: %s', validationFile);
assert(isfile(derivationFile), 'Derivation manifest not found: %s', derivationFile);

runtime = jsondecode(fileread(runtimeFile));
validation = jsondecode(fileread(validationFile));
derivation = jsondecode(fileread(derivationFile));

assert(strcmpi(runtime.asset_sha256, cfg.pde.atlasSHA256), ...
    'Atlas hash mismatch in runtime manifest.');
assert(strcmpi(derivation.output_sha256.neutral_wave_atlas_v1_png, ...
    cfg.pde.atlasSHA256), 'Atlas hash mismatch in derivation manifest.');
assert(strcmpi(validation.validation_result, 'PASSED'), ...
    'PDE validation_result mismatch.');
checkValues = cell2mat(struct2cell(validation.checks));
assert(all(checkValues), 'At least one PDE validation check is false.');

bounds = runtime.approved_runtime_bounds;
assert(inClosedInterval(cfg.pde.materialIntensity,bounds.material_intensity), ...
    'materialIntensity outside runtime bounds.');
assert(inClosedInterval(cfg.pde.spatialScale,bounds.spatial_scale), ...
    'spatialScale outside runtime bounds.');
assert(inClosedInterval(cfg.pde.rotationRate,bounds.rotation_rate), ...
    'rotationRate outside runtime bounds.');
assert(inClosedInterval(cfg.pde.responseWeight,bounds.response_weight), ...
    'responseWeight outside runtime bounds.');

I = im2double(imread(atlasFile));
if ndims(I) == 3
    I = rgb2gray(I(:,:,1:min(3,size(I,3))));
end
expectedAtlasSize = cfg.pde.frameGrid .* cfg.pde.frameSize;
assert(isequal(size(I), expectedAtlasSize), 'Unexpected atlas dimensions.');

N = prod(cfg.pde.frameGrid);
frames = zeros([cfg.workSize N]);
n = 0;
for r = 1:cfg.pde.frameGrid(1)
    rr = (r-1)*cfg.pde.frameSize(1) + (1:cfg.pde.frameSize(1));
    for c = 1:cfg.pde.frameGrid(2)
        cc = (c-1)*cfg.pde.frameSize(2) + (1:cfg.pde.frameSize(2));
        n = n + 1;
        frame = I(rr,cc);
        if ~isequal(size(frame), cfg.workSize)
            frame = imresize(frame, cfg.workSize, 'bilinear');
        end
        frames(:,:,n) = frame;
    end
end
assert(n == cfg.pde.frameCount, 'Unexpected PDE frame count.');

X = reshape(frames, [], N);
meanVector = mean(X,2);
Xc = X - meanVector;
[U,S,V] = svd(Xc,'econ');
sv = diag(S);
variance = sv.^2;
if sum(variance) <= cfg.eps
    explained = zeros(size(variance));
else
    explained = variance/sum(variance);
end
r = find(cumsum(explained) >= cfg.pde.pcaEnergyTarget, 1, 'first');
if isempty(r)
    r = min(cfg.pde.maximumModes, size(U,2));
end
r = max(1,min([r cfg.pde.maximumModes size(U,2)]));

modes = reshape(U(:,1:r), [cfg.workSize r]);
for k = 1:r
    modes(:,:,k) = modes(:,:,k)/(max(abs(modes(:,:,k)),[],'all')+cfg.eps);
end
coefficients = S(1:r,1:r)*V(:,1:r)';

centeredFrames = zeros(size(frames));
frameEnergy = zeros(N,1);
frameMean = zeros(N,1);
for k = 1:N
    frameMean(k) = mean(frames(:,:,k),'all');
    centeredFrames(:,:,k) = frames(:,:,k)-frameMean(k);
    frameEnergy(k) = mean(centeredFrames(:,:,k).^2,'all');
end
globalAmplitude = max(abs(centeredFrames),[],'all');
signedFrames = centeredFrames/(globalAmplitude+cfg.eps);

adjacentCorrelation = zeros(N-1,1);
for k = 1:N-1
    a = Xc(:,k);
    b = Xc(:,k+1);
    adjacentCorrelation(k) = dot(a,b)/(norm(a)*norm(b)+cfg.eps);
end

atlas = struct();
atlas.file = atlasFile;
atlas.sha256 = sha256File(atlasFile);
atlas.runtime = runtime;
atlas.validation = validation;
atlas.derivation = derivation;
atlas.frames = frames;
atlas.signedFrames = signedFrames;
atlas.meanMap = reshape(meanVector,cfg.workSize);
atlas.varianceMap = reshape(var(X,0,2),cfg.workSize);
atlas.modes = modes;
atlas.coefficients = coefficients;
atlas.explained = explained;
atlas.modeCount = r;
atlas.modeWeights = sqrt(explained(1:r));
atlas.modeWeights = atlas.modeWeights/(sum(atlas.modeWeights)+cfg.eps);
atlas.metrics = struct( ...
    'frame_count',N, ...
    'mode_count',r, ...
    'explained_variance',explained, ...
    'cumulative_explained_variance',cumsum(explained), ...
    'frame_mean',frameMean, ...
    'frame_energy',frameEnergy, ...
    'global_frame_amplitude',globalAmplitude, ...
    'adjacent_correlation',adjacentCorrelation, ...
    'initial_energy',validation.metrics.initial_energy, ...
    'final_energy',validation.metrics.final_energy, ...
    'stability_ratio',validation.metrics.stability_ratio, ...
    'maximum_generated_amplitude',validation.metrics.maximum_generated_amplitude);
end

function tf = inClosedInterval(x,bounds)
tf = isfinite(x) && numel(bounds)==2 && x>=bounds(1) && x<=bounds(2);
end

function file = locateFileBySHA(expectedFile, searchRoot, fileName, expectedSHA)
if isfile(expectedFile)
    actual = sha256File(expectedFile);
    if strcmpi(actual,expectedSHA)
        file = expectedFile;
        return;
    end
end
candidates = dir(fullfile(searchRoot,'**',fileName));
for k = 1:numel(candidates)
    candidate = fullfile(candidates(k).folder,candidates(k).name);
    if strcmpi(sha256File(candidate),expectedSHA)
        file = candidate;
        return;
    end
end
error('Asset not found by SHA256: %s',expectedSHA);
end

function ssot = buildSSOTBasis(F, cfg)
Z = zeros(size(F));
for c = 1:size(F,3)
    x = double(F(:,:,c));
    med = median(x(:));
    sigma = 1.4826*mad(x(:),1)+cfg.eps;
    Z(:,:,c) = (x-med)/sigma;
end

YF = reshape(Z,[],size(Z,3));
C = (YF'*YF)/max(size(YF,1)-1,1);
[V,D] = eig((C+C')/2);
[eigenvalues,order] = sort(diag(D),'descend');
V = V(:,order);
singularValues = sqrt(max(eigenvalues,0)*max(size(YF,1)-1,1));
ssot = struct('Z',Z,'covariance',C,'S',singularValues,'V',V);
end

function B = buildWorkResidualBasis(Fwork)
Y = reshape(Fwork, [], size(Fwork,3));
[~,~,V] = svd(Y, 'econ');
B = cell(4,1);
for r = 1:4
    Vr = V(:,1:r);
    R = Y - Y * Vr * Vr';
    B{r} = orth(R);
end
end

function RGB = fieldToRGB(Z)
RGB = zeros(size(Z,1), size(Z,2), 3);
for c = 1:3
    RGB(:,:,c) = rank01(Z(:,:,c));
end
end

function Fw = resizeField(F, outSize)
Fw = zeros([outSize size(F,3)]);
for c = 1:size(F,3)
    Fw(:,:,c) = imresize(F(:,:,c), outSize, 'bilinear');
end
end

%% Historical references
function refs = loadReferenceManifest(cfg)
assert(isfile(cfg.referenceManifest), 'Reference manifest not found: %s', cfg.referenceManifest);
manifestRoot = fileparts(cfg.referenceManifest);
manifest = jsondecode(fileread(cfg.referenceManifest));
if isfield(manifest, 'references')
    entries = manifest.references;
else
    entries = manifest;
end
if isstruct(entries)
    getEntry = @(j) entries(j);
elseif iscell(entries) && all(cellfun(@isstruct, entries))
    getEntry = @(j) entries{j};
else
    error('Reference manifest entries must be JSON objects.');
end

J = numel(entries);
refs = repmat(struct(), J, 1);
for j = 1:J
    e = getEntry(j);
    refs(j).index = j;
    refs(j).object_id = stringField(e, 'object_id', sprintf('object_%03d', j));
    refs(j).view = stringField(e, 'view_angle', 'front');
    refs(j).weight_class = upper(stringField(e, 'provenance_grade', 'A'));
refs(j).image_file = resolvePath(manifestRoot, stringField(e, 'image_file', ''));
refs(j).landmarks = readLandmarks(e, manifestRoot);    assert(isfile(refs(j).image_file), 'Reference image not found: %s', refs(j).image_file);
    refs(j).rgb = readRGB(refs(j).image_file);
    refs(j).landmarks = readLandmarks(e, cfg.root);
    imageSize = [size(refs(j).rgb,1) size(refs(j).rgb,2)];
refs(j).damage = readMask(e, 'damage_mask', manifestRoot, imageSize);
refs(j).restoration = readMask(e, 'restoration_mask', manifestRoot, imageSize);
    refs(j).museum_or_collection = stringField(e, 'museum_or_collection', '');
    refs(j).inventory_id = stringField(e, 'inventory_id', '');
    refs(j).object_type = stringField(e, 'object_type', '');
    refs(j).estimated_date = stringField(e, 'estimated_date', '');
    refs(j).copy_relation = stringField(e, 'copy_relation', '');
    refs(j).source_hash = stringField(e, 'source_hash', '');
    if ~isempty(refs(j).source_hash)
        assert(strcmpi(sha256File(refs(j).image_file), refs(j).source_hash), ...
            'Reference SHA256 mismatch: %s', refs(j).image_file);
    end
    refs(j).weight = classWeight(refs(j).weight_class);
end
assert(numel(unique(string({refs.object_id}))) >= cfg.minimumObjects, ...
    'Reference object count is below cfg.minimumObjects.');
end

function [refs, consensus] = normalizeReferences(refs, cfg)
J = numel(refs);
K = size(refs(1).landmarks,1);
for j = 1:J
    assert(size(refs(j).landmarks,1) == K && size(refs(j).landmarks,2) == 2, ...
        'All landmark arrays must have equal Kx2 shape.');
end

base = normalizeLandmarksToGrid(refs(1).landmarks, cfg.workSize);
target = base;
for iter = 1:6
    aligned = zeros(K,2,J);
    for j = 1:J
        tform = fitgeotrans(refs(j).landmarks, target, 'nonreflectivesimilarity');
        aligned(:,:,j) = transformPointsForward(tform, refs(j).landmarks);
    end
    w = [refs.weight]';
    w = w / sum(w);
    target = sum(aligned .* reshape(w,1,1,[]), 3);
end

R = imref2d(cfg.workSize);
for j = 1:J
    refs(j).tform = fitgeotrans(refs(j).landmarks, target, 'nonreflectivesimilarity');
    refs(j).alignedRGB = imwarp(refs(j).rgb, refs(j).tform, 'OutputView', R);
    refs(j).alignedGray = rgb2gray(refs(j).alignedRGB);
    refs(j).alignedDamage = imwarp(refs(j).damage, refs(j).tform, 'OutputView', R, 'Interp','nearest');
    refs(j).alignedRestoration = imwarp(refs(j).restoration, refs(j).tform, 'OutputView', R, 'Interp','nearest');
    refs(j).alignedLandmarks = transformPointsForward(refs(j).tform, refs(j).landmarks);
    refs(j).silhouette = deriveSilhouette(refs(j).alignedGray, refs(j).alignedDamage | refs(j).alignedRestoration);
end

w = [refs.weight]';
objectIDs = string({refs.object_id});
uniqueObjects = unique(objectIDs);
for o = 1:numel(uniqueObjects)
    idx = objectIDs == uniqueObjects(o);
    w(idx) = w(idx) / nnz(idx);
end
w = w / sum(w);
for j = 1:J
    refs(j).weight = w(j);
end

rgb = zeros([cfg.workSize 3]);
gray = zeros(cfg.workSize);
damage = zeros(cfg.workSize);
restoration = zeros(cfg.workSize);
silhouette = zeros(cfg.workSize);
landmarks = zeros(K,2);
for j = 1:J
    rgb = rgb + refs(j).weight * refs(j).alignedRGB;
    gray = gray + refs(j).weight * refs(j).alignedGray;
    damage = damage + refs(j).weight * double(refs(j).alignedDamage);
    restoration = restoration + refs(j).weight * double(refs(j).alignedRestoration);
    silhouette = silhouette + refs(j).weight * double(refs(j).silhouette);
    landmarks = landmarks + refs(j).weight * refs(j).alignedLandmarks;
end
consensus = struct();
consensus.rgb = clamp01(rgb);
consensus.gray = clamp01(gray);
consensus.damage = clamp01(damage);
consensus.restoration = clamp01(restoration);
consensus.silhouette = silhouette >= 0.5;
consensus.landmarks = landmarks;
end

function landmarks = normalizeLandmarksToGrid(L, outSize)
L0 = L - mean(L,1);
scale = max(range(L0,1));
L0 = L0 / max(scale, eps);
landmarks = zeros(size(L0));
landmarks(:,1) = outSize(2)/2 + 0.62*outSize(2)*L0(:,1);
landmarks(:,2) = outSize(1)/2 + 0.72*outSize(1)*L0(:,2);
end

function mask = deriveSilhouette(I, excluded)
I = mat2gray(I);
edgeMap = imgradient(I);
edgeMap = imgaussfilt(edgeMap, 1.2);
centerPrior = centralEllipse(size(I), 0.46, 0.48);
level = graythresh(I(centerPrior));
a = imbinarize(I, level);
b = ~a;
if sum(a(centerPrior),'all') >= sum(b(centerPrior),'all')
    mask = a;
else
    mask = b;
end
mask = imclose(mask, strel('disk', 5, 0));
mask = imfill(mask, 'holes');
mask = bwareafilt(mask, 1);
mask = mask | (edgeMap > prctile(edgeMap(:), 85) & centerPrior);
mask(excluded) = false;
end

%% Feature pipeline
function bank = buildV1Bank(cfg)
[WL, ORI] = ndgrid(cfg.v1.wavelengths, cfg.v1.orientations);
bank = gabor(WL(:), ORI(:));
end

function phi = phiPipeline(RGB, orchKernels, v1Bank, cfg)
photo = phototransduction(RGB, cfg);
retina = retinaV1(photo.V_photo, v1Bank, cfg);
orch = orchResponse(retina.R_norm, orchKernels);
eta = etaPhase(retina, orch, cfg);
phi = struct();
phi.rgb = RGB;
phi.gray = rgb2gray(RGB);
phi.photo = photo;
phi.retina = retina;
phi.orch = orch;
phi.eta = eta;
end

function photo = phototransduction(RGB, cfg)
I = applyDisplayTransform(RGB, cfg.display);
lambda = cfg.photo.lambda;

P = zeros(numel(lambda),3);
C = zeros(numel(lambda),3);
for c = 1:3
    P(:,c) = exp(-0.5*((lambda-cfg.photo.primaryCenters(c))/cfg.photo.primaryWidths(c)).^2);
    C(:,c) = exp(-0.5*((lambda-cfg.photo.coneCenters(c))/cfg.photo.coneWidths(c)).^2);
end
P = P ./ max(P,[],1);
C = C ./ max(C,[],1);

h = 6.62607015e-34;
c0 = 299792458;
photonFactor = lambda*1e-9/(h*c0);
M = zeros(3,3);
for p = 1:3
    for k = 1:3
        M(p,k) = trapz(lambda, P(:,p).*C(:,k).*photonFactor);
    end
end
M = M / max(M(:));
Q = reshape(reshape(I,[],3)*M, [size(I,1) size(I,2) 3]);
Q = Q / (max(Q(:)) + cfg.eps);
Iexc = mean(Q,3);

O = zeros(size(Iexc));
T = zeros(size(Iexc));
Pstate = zeros(size(Iexc));
cGMP = ones(size(Iexc));
for n = 1:cfg.photo.steps
    O = O + cfg.photo.dt*(cfg.photo.kOplus*Iexc.*(1-O)-cfg.photo.kOminus*O);
    T = T + cfg.photo.dt*(cfg.photo.kTplus*O.*(1-T)-cfg.photo.kTminus*T);
    Pstate = Pstate + cfg.photo.dt*(cfg.photo.kPplus*T.*(1-Pstate)-cfg.photo.kPminus*Pstate);
    cGMP = cGMP + cfg.photo.dt*(cfg.photo.kSyn*(1-cGMP)-cfg.photo.kHyd*Pstate.*cGMP);
    O = clamp01(O); T = clamp01(T); Pstate = clamp01(Pstate); cGMP = max(cGMP,0);
end

gCNG = cGMP.^cfg.photo.n ./ (cfg.photo.KCNG^cfg.photo.n + cGMP.^cfg.photo.n + cfg.eps);
Vphoto = cfg.photo.Vdark - cfg.photo.Ghyp*(1-gCNG);
Glu = 1 ./ (1 + exp(-(Vphoto-cfg.photo.thetaGlu)/cfg.photo.sGlu));

photo = struct('I_A',I,'Q',Q,'O',O,'T',T,'P',Pstate,'c',cGMP, ...
    'g_CNG',gCNG,'V_photo',Vphoto,'Glu',Glu);
end

function I = applyDisplayTransform(RGB, p)
I = (double(RGB)-p.black) / max(p.white-p.black, eps);
I = clamp01(I);
I = 0.5 + p.contrast*(I-0.5);
I = clamp01(I).^p.rho;
end

function retina = retinaV1(Vphoto, v1Bank, cfg)
center = imgaussfilt(Vphoto, cfg.retina.sigmaC);
surround = imgaussfilt(Vphoto, cfg.retina.sigmaS);
DoG = center - cfg.retina.alphaS*surround;
RON = max(DoG,0);
ROFF = max(-DoG,0);
R = RON + ROFF;
Rnorm = R ./ (imgaussfilt(abs(R),cfg.retina.sigmaD)+cfg.retina.epsD);
Rnorm = rank01(Rnorm);

[mag, phase] = imgaborfilt(Rnorm, v1Bank);
Z = mag .* exp(1i*phase);
E = mean(abs(Z).^2, 3);
Zsum = sum(Z, 3);
Msum = sum(abs(Z), 3);
etaV1 = angle(Zsum);
Pcoh = abs(Zsum) ./ (Msum + cfg.eps);

retina = struct('DoG',DoG,'R_ON',RON,'R_OFF',ROFF,'R_norm',Rnorm, ...
    'E_V1',E,'eta_V1',etaV1,'P_coh',Pcoh);
end

function kernels = loadOrchKernels(cfg)
assert(isfile(cfg.orchFile), 'ORCH tensor file not found: %s', cfg.orchFile);
paths = h5DatasetPaths(h5info(cfg.orchFile));
kernels = {};
for i = 1:numel(paths)
    x = h5read(cfg.orchFile, paths{i});
    if ~isnumeric(x)
        continue;
    end
    x = squeeze(double(x));
    if ismatrix(x)
        slices = {x};
    elseif ndims(x) == 3
        slices = cell(size(x,3),1);
        for k = 1:size(x,3)
            slices{k} = x(:,:,k);
        end
    else
        continue;
    end
    for k = 1:numel(slices)
        a = slices{k};
        if min(size(a)) < 3
            continue;
        end
        a = a - mean(a(:));
        a = a / (norm(a(:))+cfg.eps);
        target = min([31 size(a,1) size(a,2)]);
        if mod(target,2)==0, target=target-1; end
        a = imresize(a, [target target], 'bilinear');
        a = a - mean(a(:));
        a = a / (norm(a(:))+cfg.eps);
        kernels{end+1,1} = a; %#ok<AGROW>
        if numel(kernels) >= cfg.orchMaximumMaps
            return;
        end
    end
end
assert(~isempty(kernels), 'No numeric ORCH kernels were loaded.');
end

function O = orchResponse(Fv1, kernels)
acc = zeros(size(Fv1));
for m = 1:numel(kernels)
    r = imfilter(Fv1, kernels{m}, 'replicate', 'conv');
    acc = acc + 1./(1+exp(-r));
end
O = rank01(acc / numel(kernels));
end

function eta = etaPhase(retina, O, cfg)
A = sqrt(max(retina.E_V1,0));
Z = A .* exp(1i*retina.eta_V1);
w = windingMap(retina.eta_V1);
Curv = del2(real(Z));
Sq = rank01(retina.E_V1 .* (0.25+0.75*retina.P_coh) .* ...
    (1+0.50*abs(w)) .* (1+0.25*abs(Curv)));
W = 1 + cfg.lambda.O*O + cfg.lambda.Q*Sq + cfg.lambda.P*retina.P_coh;
eta = struct('A',A,'Z',Z,'w',w,'Curv',Curv,'S_q',Sq,'W',W);
end

function w = windingMap(phi)
right = wrapToPiLocal(phi(:,[2:end end]) - phi);
down = wrapToPiLocal(phi([2:end end],:) - phi);
left = wrapToPiLocal(phi(:,[1 1:end-1]) - phi);
up = wrapToPiLocal(phi([1 1:end-1],:) - phi);
w = (right + down(:,[2:end end]) + left([2:end end],:) + up) / (2*pi);
w = round(w);
end

%% Knowledge graph
function graph = buildKnowledgeGraph(phi, fixedPositions, cfg)
Sq = phi.eta.S_q;
if isempty(fixedPositions)
    maxima = imregionalmax(imgaussfilt(Sq, 1.0));
    idx = find(maxima);
    if isempty(idx)
        [~,ord] = sort(Sq(:),'descend');
        idx = ord(1:min(cfg.graph.maxQuanta,numel(ord)));
    else
        [~,ord] = sort(Sq(idx), 'descend');
        idx = idx(ord(1:min(cfg.graph.maxQuanta,numel(ord))));
    end
    [y,x] = ind2sub(size(Sq), idx);
else
    x = round(fixedPositions(:,1));
    y = round(fixedPositions(:,2));
    x = min(max(x,1),size(Sq,2));
    y = min(max(y,1),size(Sq,1));
    idx = sub2ind(size(Sq), y, x);
end

p = [x/size(Sq,2), y/size(Sq,1)];
a = phi.retina.E_V1(idx);
eta_i = phi.retina.eta_V1(idx);
mu = [phi.retina.E_V1(idx), phi.retina.P_coh(idx), phi.orch(idx), phi.eta.Curv(idx)];
tau = abs(phi.eta.Curv(idx));
q = Sq(idx);

Dp = pdist2(p,p);
Dmu = pdist2(mu,mu);
sp = cfg.graph.sigmaP;
sm = cfg.graph.sigmaMu;
if isempty(sp), sp = median(Dp(Dp>0)); end
if isempty(sm), sm = median(Dmu(Dmu>0)); end
if isempty(sp) || ~isfinite(sp), sp = 1; end
if isempty(sm) || ~isfinite(sm), sm = 1; end
sp = max(sp,cfg.eps);
sm = max(sm,cfg.eps);
phaseTerm = (1 + cos(eta_i-eta_i'))/2;
qTerm = 0.75 + 0.25*exp(-abs(q-q'));
Aij = exp(-(Dp.^2)/(sp^2)) .* exp(-(Dmu.^2)/(sm^2)) .* phaseTerm .* qTerm;
Aij(1:size(Aij,1)+1:end) = 0;
Aij = (Aij+Aij')/2;
D = diag(sum(Aij,2));
L = D-Aij;
e = sort(real(eig((L+L')/2)), 'ascend');
e = e(1:min(cfg.graph.spectrumCount,numel(e)));

graph = struct('p',p,'pixel',[x y],'a',a,'eta',eta_i,'mu',mu,'tau',tau, ...
    'q',q,'A',Aij,'D',D,'L',L,'spectrum',e);
end

%% Model and objective
function [E, parts, state] = totalObjective(theta, ctx)
cfg = ctx.cfg;
[RGB, gray, silhouette, landmarks] = renderModel(theta, ctx.consensus, cfg);
phi = phiPipeline(RGB, ctx.orchKernels, ctx.v1Bank, cfg);
graph = buildKnowledgeGraph(phi, ctx.graphRef.pixel, cfg);

Edata = 0;
Eland = 0;
Esil = 0;
Enorm = 0;
refErrors = zeros(numel(ctx.refs),1);
nuisance = zeros(numel(ctx.refs),6);

candidatePhoto = rank01(phi.photo.V_photo);
candidateV1 = rank01(phi.retina.E_V1);
for j = 1:numel(ctx.refs)
    r = ctx.refs(j);
    valid = ~(r.alignedDamage|r.alignedRestoration);
    [grayAdj, nu] = matchNuisance(gray, r.alignedGray, valid);
    nuisance(j,:) = nu;

    residual = cat(3, ...
        grayAdj-r.alignedGray, ...
        candidatePhoto-rank01(r.phi.photo.V_photo), ...
        candidateV1-rank01(r.phi.retina.E_V1), ...
        phi.retina.P_coh-r.phi.retina.P_coh, ...
        phi.orch-r.phi.orch, ...
        phi.eta.S_q-r.phi.eta.S_q);

    W = r.phi.eta.W .* double(valid);
    u = mean(residual.^2,3).*W;
    Ej = mean(robustRho(u,cfg.robustDelta),'all');
    Edata = Edata + r.weight*Ej;
    refErrors(j) = Ej;

    dL = landmarks-r.alignedLandmarks;
    diagScale = hypot(cfg.workSize(1),cfg.workSize(2));
    Eland = Eland + r.weight*mean(sum(dL.^2,2))/(diagScale^2);

    Esil = Esil + r.weight*chamferDistance(silhouette,r.silhouette);
    Enorm = Enorm + r.weight*normalDistance(grayAdj,r.alignedGray,valid);
end

Esym = mean((gray-fliplr(gray)).^2,'all');
Esmooth = mean(del2(gray).^2,'all');
Eanat = sum(max(cfg.thetaLB-theta,0).^2 + max(theta-cfg.thetaUB,0).^2);
Ecopy = sum(nuisance(:,1:3).^2,'all')/(cfg.sigmaCopy^2+cfg.eps);
Estyle = sum(nuisance(:,4:6).^2,'all')/(cfg.sigmaStyle^2+cfg.eps);

[Egraph, Essot, Eorch, Etensor] = tensorEnergy(gray, phi, graph, ctx);
[Epde, pdeMap, pdeStats] = pdeModeEnergy(gray, ctx.atlas, cfg);

m = ctx.mode;
L = cfg.lambda;
E = m.historical*(L.d*Edata + L.l*Eland + L.s*Esil + L.n*Enorm + ...
    L.y*Esym + L.m*Esmooth + L.a*Eanat + L.c*Ecopy + L.t*Estyle) + ...
    L.T*(m.graph*L.graph*Egraph + m.ssot*L.ssot*Essot + ...
    m.orch*L.orch*Eorch + m.pde*L.pde*Epde);

if nargout >= 2
    parts = struct('E_data',Edata,'E_land',Eland,'E_sil',Esil,'E_norm',Enorm, ...
        'E_sym',Esym,'E_smooth',Esmooth,'E_anat',Eanat,'E_copy',Ecopy, ...
        'E_style',Estyle,'E_graph',Egraph,'E_ssot',Essot,'E_orch',Eorch, ...
        'E_pde',Epde,'E_tensor',Etensor,'E_total',E,'reference_errors',refErrors);
end
if nargout >= 3
    state = struct('rgb',RGB,'gray',gray,'silhouette',silhouette,'landmarks',landmarks, ...
        'phi',phi,'graph',graph,'nuisance',nuisance,'pdeMap',pdeMap,'pdeStats',pdeStats);
end
end

function y = totalObjectiveScalar(theta, ctx)
y = totalObjective(theta, ctx);
end

function [Egraph, Essot, Eorch, Etensor] = tensorEnergy(gray, phi, graph, ctx)
cfg = ctx.cfg;
k = min(numel(graph.spectrum),numel(ctx.graphRef.spectrum));
Egraph = sum((graph.spectrum(1:k)-ctx.graphRef.spectrum(1:k)).^2) + ...
    cfg.lambda.A*mean((graph.A-ctx.graphRef.A).^2,'all');

[gx,gy] = gradient(gray);
phase = atan2(gy,gx);
Frender = cat(3, gray, gx, gy, del2(gray), phase/pi);
for c = 1:size(Frender,3)
    Frender(:,:,c) = robustZ(Frender(:,:,c));
end
Dfield = reshape(Frender-ctx.ssotWork,[],5);
Fref = reshape(ctx.ssotWork,[],5);
alphaF = (Fref'*Fref + cfg.eps*eye(5)) \ (Fref'*reshape(Frender,[],5));
Essot = sum(alphaF.^2,'all');
for r = 1:4
    Q = ctx.ssotBasisWork{r};
    Essot = Essot + cfg.lambda.res*cfg.residualPi(r)*sum((Q'*Dfield).^2,'all');
end

Eorch = mean((phi.orch-ctx.consensusPhi.orch).^2,'all');
Etensor = cfg.lambda.graph*Egraph + cfg.lambda.ssot*Essot + cfg.lambda.orch*Eorch;
end


function [E, sensitivityMap, stats] = pdeModeEnergy(gray, atlas, cfg)
F0 = structuralFeature(gray, cfg);
support = rank01(mean(abs(F0),3));
K = atlas.modeCount;
sensitivity = zeros([size(gray) K]);
correlation = zeros(K,1);
weights = atlas.modeWeights(:);
weights = weights/(sum(weights)+cfg.eps);
baseAmplitude = cfg.pde.responseWeight*cfg.pde.materialIntensity;

for k = 1:K
    field = transformPDEField(atlas.modes(:,:,k), cfg);
    amplitude = baseAmplitude*sqrt(max(K*weights(k),cfg.eps));
    gp = clamp01(gray + amplitude*field);
    gm = clamp01(gray - amplitude*field);
    Fp = structuralFeature(gp, cfg);
    Fm = structuralFeature(gm, cfg);
    d = 0.5*(abs(Fp-F0)+abs(Fm-F0));
    sensitivity(:,:,k) = mean(d,3);
    correlation(k) = 0.5*(weightedCosine(F0,Fp,support,cfg.eps) + ...
        weightedCosine(F0,Fm,support,cfg.eps));
end

sensitivityMap = sum(sensitivity.*reshape(weights,1,1,[]),3);
Ecorrelation = mean(1-correlation);
Esensitivity = mean(sensitivityMap.*(0.25+0.75*support),'all');
E = Ecorrelation + cfg.pde.sensitivityWeight*Esensitivity;
stats = struct('mode_correlation',correlation,'E_correlation',Ecorrelation, ...
    'E_sensitivity',Esensitivity,'mode_count',K);
end

function analysis = fullPDETemporalAnalysis(gray, atlas, cfg)
F0 = structuralFeature(gray, cfg);
support = rank01(mean(abs(F0),3));
N = size(atlas.signedFrames,3);
sensitivity = zeros([size(gray) N]);
correlation = zeros(N,1);
responses = zeros([size(gray) 3 N]);
baseAmplitude = cfg.pde.responseWeight*cfg.pde.materialIntensity;

for n = 1:N
    field = transformPDEField(atlas.signedFrames(:,:,n), cfg);
    response = clamp01(gray + baseAmplitude*field);
    Fr = structuralFeature(response, cfg);
    sensitivity(:,:,n) = mean(abs(Fr-F0),3);
    correlation(n) = weightedCosine(F0,Fr,support,cfg.eps);
    responses(:,:,:,n) = repmat(response,1,1,3);
end

sensitivityMap = mean(sensitivity,3);
persistenceMap = exp(-sensitivityMap/cfg.pde.persistenceTau);
metrics = atlas.metrics;
metrics.response_correlation = correlation;
metrics.mean_response_correlation = mean(correlation);
metrics.minimum_response_correlation = min(correlation);
metrics.maximum_response_correlation = max(correlation);
metrics.mean_sensitivity = mean(sensitivityMap,'all');
metrics.mean_persistence = mean(persistenceMap,'all');
metrics.pca_mode_count = atlas.modeCount;
metrics.pca_retained_variance = sum(atlas.explained(1:atlas.modeCount));

analysis = struct('sensitivityMap',sensitivityMap, ...
    'persistenceMap',persistenceMap,'correlation',correlation, ...
    'responseImages',responses,'metrics',metrics);
end

function F = structuralFeature(gray, cfg)
DoG = imgaussfilt(gray,cfg.retina.sigmaC) - ...
    cfg.retina.alphaS*imgaussfilt(gray,cfg.retina.sigmaS);
[gx,gy] = gradient(gray);
G = hypot(gx,gy);
L = del2(gray);
F = cat(3,robustZ(DoG),robustZ(G),robustZ(L));
end

function c = weightedCosine(A,B,W,epsilon)
W3 = repmat(W,1,1,size(A,3));
a = A(:).*W3(:);
b = B(:).*W3(:);
c = dot(a,b)/(norm(a)*norm(b)+epsilon);
c = min(max(c,-1),1);
end

function field = transformPDEField(field, cfg)
field = imresize(field,cfg.pde.spatialScale,'bilinear');
field = centerFit(field,cfg.workSize);
if cfg.pde.rotationRate ~= 0
    field = imrotate(field,cfg.pde.rotationRate*180/pi,'bilinear','crop');
end
field = field/(max(abs(field),[],'all')+cfg.eps);
end

function out = centerFit(in,outSize)
out = zeros(outSize);
h = size(in,1);
w = size(in,2);
copyH = min(h,outSize(1));
copyW = min(w,outSize(2));
srcR = floor((h-copyH)/2)+(1:copyH);
srcC = floor((w-copyW)/2)+(1:copyW);
dstR = floor((outSize(1)-copyH)/2)+(1:copyH);
dstC = floor((outSize(2)-copyW)/2)+(1:copyW);
out(dstR,dstC) = in(srcR,srcC);
end

function [thetaStar, EStar, info] = optimizeTheta(theta0, ctx, cfg)
obj = @(x) totalObjectiveScalar(x,ctx);
if exist('fmincon','file') == 2
    opts = optimoptions('fmincon','Algorithm','interior-point','Display','iter', ...
        'MaxIterations',cfg.optimizerMaxIterations, ...
        'MaxFunctionEvaluations',cfg.optimizerMaxEvaluations, ...
        'FiniteDifferenceType','central');
    [thetaStar,EStar,exitflag,output] = fmincon(obj,theta0,[],[],[],[], ...
        cfg.thetaLB,cfg.thetaUB,[],opts);
else
    penalty = @(x) obj(min(max(x,cfg.thetaLB),cfg.thetaUB)) + ...
        1e3*sum((x-min(max(x,cfg.thetaLB),cfg.thetaUB)).^2);
    opts = optimset('Display','iter','MaxIter',cfg.optimizerMaxIterations, ...
        'MaxFunEvals',cfg.optimizerMaxEvaluations);
    [x,EStar,exitflag,output] = fminsearch(penalty,theta0,opts);
    thetaStar = min(max(x,cfg.thetaLB),cfg.thetaUB);
end
info = struct('exitflag',exitflag,'output',output);
end

function [RGB, gray, silhouette, landmarks] = renderModel(theta, consensus, cfg)
H = cfg.workSize(1); W = cfg.workSize(2);
[x,y] = meshgrid(linspace(-1,1,W),linspace(-1,1,H));

scale = 1 + 0.10*theta(1);
persp = 1 + 0.08*theta(9).*y;
bulge = 1 + 0.10*theta(3).*exp(-(y/0.65).^2);
ang = deg2rad(8*theta(7));
xr = ( cos(ang)*x + sin(ang)*y ) ./ (scale.*bulge.*persp);
yr = (-sin(ang)*x + cos(ang)*y ) ./ scale;
mouthBand = exp(-((yr-0.38)/0.15).^2);
yr = yr - 0.06*theta(6).*mouthBand;

xs = (xr+1)*(W-1)/2 + 1;
ys = (yr+1)*(H-1)/2 + 1;
base = interp2(consensus.gray,xs,ys,'linear',median(consensus.gray(:)));
mask = interp2(double(consensus.silhouette),xs,ys,'linear',0) >= 0.5;

low = imgaussfilt(base,2.0);
high = base-low;
gray = low + (1+0.65*theta(2))*high;
gray = (1-0.22*max(theta(3),0))*gray + 0.22*max(theta(3),0)*imgaussfilt(gray,2.2);

hairMask = exp(-((y+0.70)/0.28).^2) + 0.65*exp(-((y-0.62)/0.25).^2);
gray = gray - 0.12*theta(4).*hairMask.*mask;
ageField = rank01(abs(del2(imgaussfilt(gray,0.6))));
gray = gray - 0.10*theta(5).*ageField.*mask;
gray = gray + 0.13*theta(8).*x + 0.05*theta(8).*y;
gray = clamp01(gray);
bgValues = gray(~mask & isfinite(gray));
if isempty(bgValues)
    background = 0.5;
else
    background = median(bgValues);
end
gray(~mask) = background;
if ~all(isfinite(gray(:)))
    finiteValues = gray(isfinite(gray));
    if isempty(finiteValues), finiteValues = 0.5; end
    gray(~isfinite(gray)) = median(finiteValues);
end

RGB = repmat(gray,1,1,3);
silhouette = mask;
landmarks = transformModelLandmarks(consensus.landmarks, theta, cfg.workSize);
end

function L = transformModelLandmarks(L0, theta, outSize)
W = outSize(2); H = outSize(1);
x = (L0(:,1)-1)*2/(W-1)-1;
y = (L0(:,2)-1)*2/(H-1)-1;
scale = 1 + 0.10*theta(1);
bulge = 1 + 0.10*theta(3).*exp(-(y/0.65).^2);
persp = 1 + 0.08*theta(9).*y;
x = x.*scale.*bulge.*persp;
y = y.*scale + 0.06*theta(6).*exp(-((y-0.38)/0.15).^2);
ang = deg2rad(8*theta(7));
x2 = cos(ang)*x - sin(ang)*y;
y2 = sin(ang)*x + cos(ang)*y;
L = [(x2+1)*(W-1)/2+1, (y2+1)*(H-1)/2+1];
end

function [adjusted, nu] = matchNuisance(cand, ref, valid)
x = cand(valid); y = ref(valid);
A = [x(:) ones(numel(x),1)];
ab = (A'*A + 1e-8*eye(2)) \ (A'*y(:));
gain = ab(1); bias = ab(2);
adjusted = clamp01(gain*cand+bias);
blur = max(0, min(2, std(y)-std(x)));
shiftx = 0; shifty = 0;
contrast = std(adjusted(valid))/(std(ref(valid))+eps)-1;
nu = [gain-1 bias blur shiftx shifty contrast];
end

function y = robustRho(u, delta)
y = 2*delta^2*(sqrt(1+u/delta^2)-1);
end

function d = chamferDistance(A,B)
DA = bwdist(A); DB = bwdist(B);
ea = bwperim(A); eb = bwperim(B);
d = 0.5*(mean(DB(ea),'omitnan') + mean(DA(eb),'omitnan')) / hypot(size(A,1),size(A,2));
if ~isfinite(d), d = 1; end
end

function d = normalDistance(A,B,valid)
[ax,ay] = gradient(A); [bx,by] = gradient(B);
an = sqrt(ax.^2+ay.^2+1); bn = sqrt(bx.^2+by.^2+1);
dotn = (ax.*bx+ay.*by+1)./(an.*bn);
d = mean(1-dotn(valid),'omitnan');
if ~isfinite(d), d = 1; end
end

%% Luna
function luna = lunaGeodesicStep(theta, ctx, cfg)
q = theta(1:8);
J = numericalDescriptorJacobian(q, theta, ctx, cfg.lunaFDStep);
Wq = eye(size(J,1));
g = J'*Wq*J + diag(cfg.lunaLambda) + cfg.eps*eye(8);
grad = numericalGradient(@(x) totalObjectiveScalar(x,ctx), theta, cfg.lunaFDStep);
v = -g \ grad(1:8);
if norm(v)>0
    v = v/norm(v);
end
qNext = q + cfg.lunaStep*v;
thetaNext = theta;
thetaNext(1:8) = min(max(qNext,cfg.thetaLB(1:8)),cfg.thetaUB(1:8));
Ecurrent = totalObjectiveScalar(theta,ctx);
Enext = totalObjectiveScalar(thetaNext,ctx);
dq = thetaNext(1:8)-q;
lengthG = sqrt(max(dq'*g*dq,0));
luna = struct('q_current',q,'metric',g,'velocity',v,'theta_next',thetaNext, ...
    'E_current',Ecurrent,'E_next',Enext,'geodesic_length',lengthG);
end

function J = numericalDescriptorJacobian(q, theta, ctx, h)
d0 = stateDescriptor(theta,ctx);
J = zeros(numel(d0),numel(q));
for k = 1:numel(q)
    tp = theta; tm = theta;
    tp(k)=tp(k)+h; tm(k)=tm(k)-h;
    J(:,k) = (stateDescriptor(tp,ctx)-stateDescriptor(tm,ctx))/(2*h);
end
end

function d = stateDescriptor(theta,ctx)
[~,~,s] = totalObjective(theta,ctx);
g = s.gray;
d = [mean(g,'all'); std(g,0,'all'); mean(s.phi.retina.E_V1,'all'); ...
    mean(s.phi.retina.P_coh,'all'); mean(s.phi.orch,'all'); ...
    mean(s.phi.eta.S_q,'all'); mean(s.pdeMap,'all'); ...
    mean(s.pdeStats.mode_correlation); mean((g-fliplr(g)).^2,'all'); ...
    mean(del2(g).^2,'all')];
end

%% LOO, Hessian, ensemble, uncertainty
function loo = leaveOneObjectOut(theta0, ctx, cfg)
ids = unique(string({ctx.refs.object_id}));
thetas = zeros(numel(theta0),numel(ids));
renders = zeros([cfg.workSize numel(ids)]);
for k = 1:numel(ids)
    sub = ctx;
    keep = string({ctx.refs.object_id}) ~= ids(k);
    sub.refs = ctx.refs(keep);
    w = [sub.refs.weight];
    for j = 1:numel(sub.refs)
        sub.refs(j).weight = w(j)/sum(w);
    end
    oldIter = sub.cfg.optimizerMaxIterations;
    oldEval = sub.cfg.optimizerMaxEvaluations;
    sub.cfg.optimizerMaxIterations = cfg.looMaxIterations;
    sub.cfg.optimizerMaxEvaluations = max(250,10*cfg.looMaxIterations);
    [tk,~,~] = optimizeTheta(theta0,sub,sub.cfg);
    sub.cfg.optimizerMaxIterations = oldIter;
    sub.cfg.optimizerMaxEvaluations = oldEval;
    thetas(:,k)=tk;
    [~,g] = renderModel(tk,ctx.consensus,cfg);
    renders(:,:,k)=g;
end
shift = vecnorm(thetas-theta0,2,1);
baseGray = renderModelGray(theta0,ctx.consensus,cfg);
residualMap = mean(abs(renders-baseGray),3);
loo = struct('object_ids',ids,'theta',thetas,'parameter_shift',shift, ...
    'median_parameter_shift',median(shift),'residualMap',rank01(residualMap));
end

function g = renderModelGray(theta,consensus,cfg)
[~,g] = renderModel(theta,consensus,cfg);
end

function [H,Sigma] = numericalHessian(fun,x,h,pairs)
n = numel(x);
H = zeros(n);
f0 = fun(x);

for i = 1:n
    ei = zeros(n,1);
    ei(i)=h;
    H(i,i) = (fun(x+ei)-2*f0+fun(x-ei))/h^2;
end

for k = 1:size(pairs,1)
    i = pairs(k,1);
    j = pairs(k,2);
    ei = zeros(n,1);
    ej = zeros(n,1);
    ei(i)=h;
    ej(j)=h;
    H(i,j) = (fun(x+ei+ej)-fun(x+ei-ej)- ...
        fun(x-ei+ej)+fun(x-ei-ej))/(4*h^2);
    H(j,i)=H(i,j);
end

H = (H+H')/2;
[V,D] = eig(H);
d = max(diag(D),1e-5);
H = V*diag(d)*V';
Sigma = V*diag(1./d)*V';
Sigma = (Sigma+Sigma')/2;
end

function g = numericalGradient(fun,x,h)
g = zeros(size(x));
for i = 1:numel(x)
    e = zeros(size(x)); e(i)=h;
    g(i)=(fun(x+e)-fun(x-e))/(2*h);
end
end

function [ensemble,thetaN] = renderEnsemble(thetaStar,Sigma,ctx,cfg)
[V,D] = eig((Sigma+Sigma')/2);
D = diag(max(diag(D),0));
S = V*sqrt(D)*V';
N = cfg.ensembleCount;
ensemble = zeros([cfg.workSize 3 N]);
thetaN = zeros(numel(thetaStar),N);
for n = 1:N
    xi = randn(numel(thetaStar),1);
    t = thetaStar + cfg.ensembleScale*S*xi;
    t = min(max(t,cfg.thetaLB),cfg.thetaUB);
    thetaN(:,n)=t;
    ensemble(:,:,:,n)=renderModel(t,ctx.consensus,cfg);
end
end

function U = uncertaintyPDE(S,cfg)
U = zeros(size(S));
for k = 1:cfg.uncertainty.steps
    U = U + cfg.uncertainty.dt*(cfg.uncertainty.D*del2(U)-cfg.uncertainty.lambda*U+S);
    U = max(U,0);
end
U = rank01(U);
end

%% Metrics and ablation
function metrics = computeMetrics(theta,E,parts,state,loo,Sigma,consensus,refs,cfg)
Csource = exp(-median(parts.reference_errors)/cfg.tau.source);
NRMSE = sqrt(parts.E_land);
Clandmark = exp(-NRMSE/cfg.tau.landmark);
Cloo = exp(-(loo.median_parameter_shift^2)/cfg.tau.loo);
Cgraph = exp(-parts.E_graph/cfg.tau.graph);
Cposterior = exp(-trace(Sigma)/cfg.tau.posterior);
Cpde = exp(-parts.E_pde/cfg.tau.pde);
Cdamage = 1-mean(max(consensus.damage,consensus.restoration),'all');

obj = string({refs.object_id});
wObj = zeros(numel(unique(obj)),1);
u = unique(obj);
for k = 1:numel(u)
    wObj(k)=sum([refs(obj==u(k)).weight]);
end
Neff = 1/sum(wObj.^2);
Cindependence = Neff/numel(u);
Ctotal = max(0,Csource*Clandmark*Cloo*Cgraph*Cposterior*Cpde* ...
    Cdamage*Cindependence)^(1/8);

metrics = struct('theta',theta,'E_total',E,'C_source',Csource, ...
    'C_landmark',Clandmark,'C_loo',Cloo,'C_graph',Cgraph, ...
    'C_posterior',Cposterior,'C_pde',Cpde,'C_damage',Cdamage, ...
    'C_independence',Cindependence,'C_total',Ctotal, ...
    'NRMSE_landmark',NRMSE,'E_pde',parts.E_pde, ...
    'pde_mode_correlation',state.pdeStats.mode_correlation, ...
    'graph_spectrum',state.graph.spectrum);
end

function ablation = runAblation(thetaStar,thetaFinal,ctx,ensemble,graphRef,cfg)
ids = {'A','B','C','D','E','F'};
ablation = repmat(struct(),numel(ids),1);
baseVar = mean(var(ensemble,0,4),'all');

for k = 1:numel(ids)
    sub = ctx;
    sub.mode = modeWeights(ids{k},cfg);
    if any(strcmp(ids{k},{'E','F'}))
        theta = thetaFinal;
    else
        theta = thetaStar;
    end
    [E,p,s] = totalObjective(theta,sub);
    m = struct();
    m.E_total = E;
    m.C_total = exp(-E);
    m.I_var = baseVar;
    m.graph_spectrum_delta = norm(s.graph.spectrum-graphRef.spectrum);
    m.E_pde = p.E_pde;
    m.pde_mean_mode_correlation = mean(s.pdeStats.mode_correlation);
    if strcmp(ids{k},'E')
        m.geodesic_length = norm(thetaFinal(1:8)-thetaStar(1:8));
    end
    ablation(k).id = ids{k};
    ablation(k).mode = sub.mode;
    ablation(k).parts = p;
    ablation(k).metrics = m;
end
end

function m = modeWeights(id,~)
switch upper(id)
    case 'A'
        m = struct('historical',1,'ssot',0,'orch',0,'graph',0,'pde',0,'luna',0);
    case 'B'
        m = struct('historical',1,'ssot',1,'orch',0,'graph',0,'pde',0,'luna',0);
    case 'C'
        m = struct('historical',1,'ssot',1,'orch',1,'graph',1,'pde',0,'luna',0);
    case 'D'
        m = struct('historical',1,'ssot',1,'orch',1,'graph',1,'pde',1,'luna',0);
    case 'E'
        m = struct('historical',1,'ssot',1,'orch',1,'graph',1,'pde',1,'luna',1);
    case 'F'
        m = struct('historical',0,'ssot',1,'orch',1,'graph',1,'pde',1,'luna',1);
    otherwise
        error('Unknown ablation mode: %s',id);
end
end

%% Output
function writeOutputs(outDir,cfg,refs,consensus,state,graphRef,atlas,pdeTemporal, ...
    luna,ensemble,thetaN,Imean,Ivar,Ustar,Cmap,loo,ablation,metrics, ...
    thetaStar,thetaFinal,H,Sigma,optInfo,actualHash)

graph = state.graph;
manifest = struct('schema','YEHOSHUA_PLATO_RECONSTRUCTION_RUN_v2', ...
    'timestamp',datestr(now,30),'ssot_file',cfg.ssotFile,'ssot_dataset',cfg.ssotDataset, ...
    'ssot_sha256',actualHash,'reference_manifest',cfg.referenceManifest, ...
    'orch_file',cfg.orchFile,'pde_atlas_file',atlas.file, ...
    'pde_atlas_sha256',atlas.sha256,'pde_mode_count',atlas.modeCount, ...
    'work_size',cfg.workSize,'seed',cfg.seed,'theta_star',thetaStar, ...
    'theta_final',thetaFinal,'optimizer',optInfo);
writeJSON(fullfile(outDir,cfg.outputFiles{1}),manifest);

T = table((1:numel(refs))',string({refs.object_id})',string({refs.view})', ...
    string({refs.weight_class})',[refs.weight]',string({refs.image_file})', ...
    'VariableNames',{'index','object_id','view','weight_class','weight','image_file'});
writetable(T,fullfile(outDir,cfg.outputFiles{2}));

aligned = cat(4,refs.alignedRGB);
imwrite(makeGrid(aligned,ceil(sqrt(numel(refs)))),fullfile(outDir,cfg.outputFiles{3}));

fig = figure('Visible','off','Color','w');
imshow(consensus.rgb); hold on;
plot(consensus.landmarks(:,1),consensus.landmarks(:,2),'o','MarkerSize',5,'LineWidth',1);
exportgraphics(fig,fullfile(outDir,cfg.outputFiles{4}),'Resolution',180);
close(fig);

shape_depth = struct('gray',consensus.gray,'silhouette',consensus.silhouette, ...
    'landmarks',consensus.landmarks,'depth_proxy',rank01(-del2(consensus.gray)));
save(fullfile(outDir,cfg.outputFiles{5}),'-struct','shape_depth','-v7.3');

nu = state.nuisance;
Tnu = array2table(nu,'VariableNames',{'gain_delta','bias','blur','shift_x','shift_y','contrast_delta'});
Tnu.object_id = string({refs.object_id})';
Tnu = movevars(Tnu,'object_id','Before',1);
writetable(Tnu,fullfile(outDir,cfg.outputFiles{6}));

h5file = fullfile(outDir,cfg.outputFiles{7});
writeH5Dataset(h5file,'/v1/E_V1',single(state.phi.retina.E_V1));
writeH5Dataset(h5file,'/v1/eta_V1',single(state.phi.retina.eta_V1));
writeH5Dataset(h5file,'/v1/P_coh',single(state.phi.retina.P_coh));
writeH5Dataset(h5file,'/orch/O',single(state.phi.orch));
writeH5Dataset(h5file,'/eta_phase/S_q',single(state.phi.eta.S_q));
writeH5Dataset(h5file,'/eta_phase/w',single(state.phi.eta.w));
writeH5Dataset(h5file,'/eta_phase/Curv',single(state.phi.eta.Curv));
writeH5Dataset(h5file,'/pde/atlas_mean',single(atlas.meanMap));
writeH5Dataset(h5file,'/pde/atlas_variance',single(atlas.varianceMap));
writeH5Dataset(h5file,'/pde/modes',single(atlas.modes));
writeH5Dataset(h5file,'/pde/coefficients',single(atlas.coefficients));
writeH5Dataset(h5file,'/pde/persistence',single(pdeTemporal.persistenceMap));
writeH5Dataset(h5file,'/pde/sensitivity',single(pdeTemporal.sensitivityMap));
writeH5Dataset(h5file,'/pde/response_correlation',single(pdeTemporal.correlation));

K = table((1:size(graph.p,1))',graph.pixel(:,1),graph.pixel(:,2),graph.p(:,1),graph.p(:,2), ...
    graph.a,graph.eta,graph.tau,graph.q,'VariableNames', ...
    {'id','x_pixel','y_pixel','p_x','p_y','amplitude','phase','tau','q'});
writetable(K,fullfile(outDir,cfg.outputFiles{8}));

spectrumTable = table((1:numel(graph.spectrum))',graph.spectrum(:), ...
    graphRef.spectrum(:),'VariableNames',{'index','final','reference'});
writetable(spectrumTable,fullfile(outDir,cfg.outputFiles{9}));
writeJSON(fullfile(outDir,cfg.outputFiles{10}),luna);

imwrite(makeGrid(ensemble,3),fullfile(outDir,cfg.outputFiles{11}));
imwrite(clamp01(Imean),fullfile(outDir,cfg.outputFiles{12}));
imwrite(rank01(Ustar),fullfile(outDir,cfg.outputFiles{13}));
imwrite(rank01(mean(Ivar,3)),fullfile(outDir,cfg.outputFiles{14}));

looOut = rmfield(loo,'residualMap');
writeJSON(fullfile(outDir,cfg.outputFiles{15}),looOut);
writeJSON(fullfile(outDir,cfg.outputFiles{16}),ablation);

metrics.H = H;
metrics.Sigma_theta = Sigma;
metrics.theta_ensemble = thetaN;
metrics.C_map_mean = mean(Cmap,'all');
metrics.pde_temporal = pdeTemporal.metrics;
writeJSON(fullfile(outDir,cfg.outputFiles{17}),metrics);

pdeMetrics = pdeTemporal.metrics;
pdeMetrics.atlas_file = atlas.file;
pdeMetrics.atlas_sha256 = atlas.sha256;
pdeMetrics.mode_weights = atlas.modeWeights;
pdeMetrics.coefficients = atlas.coefficients;
writeJSON(fullfile(outDir,cfg.outputFiles{18}),pdeMetrics);
imwrite(clamp01(pdeTemporal.persistenceMap),fullfile(outDir,cfg.outputFiles{19}));

basisImages = zeros([cfg.workSize 3 atlas.modeCount]);
for k = 1:atlas.modeCount
    basisImages(:,:,:,k) = signedFieldRGB(atlas.modes(:,:,k));
end
imwrite(makeGrid(basisImages,ceil(sqrt(atlas.modeCount))), ...
    fullfile(outDir,cfg.outputFiles{20}));
imwrite(makeGrid(pdeTemporal.responseImages,cfg.pde.frameGrid(2)), ...
    fullfile(outDir,cfg.outputFiles{21}));
end

function writeH5Dataset(file,path,data)
if isfile(file)
    assert(~any(strcmp(h5DatasetPaths(h5info(file)),path)), ...
        'H5 dataset already exists: %s',path);
end
dims = size(data);
chunk = min(dims, 64*ones(size(dims)));
chunk = max(chunk, ones(size(chunk)));
h5create(file,path,dims,'Datatype',class(data),'ChunkSize',chunk,'Deflate',5);
h5write(file,path,data);
end

function writeJSON(file,s)
text = jsonencode(s,'PrettyPrint',true);
fid = fopen(file,'w');
assert(fid>=0,'Cannot open JSON output: %s',file);
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,text,'char');
end

%% Utilities
function paths = h5DatasetPaths(info)
paths = {};
paths = collectGroup(info, '', paths);
end

function paths = collectGroup(group,prefix,paths)
if isempty(prefix)
    current = group.Name;
else
    current = prefix;
end
for i = 1:numel(group.Datasets)
    if strcmp(current,'/')
        p = ['/' group.Datasets(i).Name];
    else
        p = [current '/' group.Datasets(i).Name];
    end
    paths{end+1,1}=p; %#ok<AGROW>
end
for i = 1:numel(group.Groups)
    paths = collectGroup(group.Groups(i),group.Groups(i).Name,paths);
end
end

function hash = sha256File(file)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(file,'rb');
assert(fid>=0,'Cannot open file for SHA256: %s',file);
cleanup = onCleanup(@() fclose(fid));
while true
    bytes = fread(fid,1024*1024,'*uint8');
    if isempty(bytes), break; end
    md.update(typecast(bytes,'int8'));
end
digest = typecast(md.digest(),'uint8');
hash = lower(reshape(dec2hex(digest,2).',1,[]));
end

function s = stringField(x,name,default)
if isfield(x,name)
    v = x.(name);
    if isstring(v) || ischar(v)
        s = char(v);
    else
        s = char(string(v));
    end
else
    s = default;
end
end

function p = resolvePath(root,p)
if isempty(p), return; end
if startsWith(p,'/') || (~isempty(regexp(p,'^[A-Za-z]:[\\/]', 'once')))
    return;
end
p = fullfile(root,p);
end

function RGB = readRGB(file)
I = im2double(imread(file));
if ndims(I)==2
    RGB = repmat(I,1,1,3);
elseif size(I,3)>3
    RGB = I(:,:,1:3);
else
    RGB = I;
end
RGB = clamp01(RGB);
end

function L = readLandmarks(e,root)
if isfield(e,'landmarks')
    L = double(e.landmarks);
elseif isfield(e,'landmarks_file')
    file = resolvePath(root,char(e.landmarks_file));
    assert(isfile(file),'Landmark file not found: %s',file);
    [~,~,ext] = fileparts(file);
    switch lower(ext)
        case '.csv'
            L = readmatrix(file);
        case '.json'
            x = jsondecode(fileread(file));
            if isfield(x,'landmarks'), x=x.landmarks; end
            L = double(x);
        case '.mat'
            x = load(file);
            names = fieldnames(x);
            L = double(x.(names{1}));
        otherwise
            error('Unsupported landmark format: %s',ext);
    end
else
    error('Reference entry has no landmarks or landmarks_file.');
end
assert(size(L,2)==2,'Landmarks must be Kx2.');
end

function mask = readMask(e,name,root,sz)
if ~isfield(e,name) || isempty(e.(name))
    mask = false(sz);
    return;
end
v = e.(name);
if isnumeric(v) || islogical(v)
    mask = logical(v);
else
    file = resolvePath(root,char(v));
    assert(isfile(file),'Mask file not found: %s',file);
    mask = imread(file);
    if ndims(mask)>2, mask=mask(:,:,1); end
    mask = mask>0;
end
if ~isequal(size(mask),sz)
    mask = imresize(mask,sz,'nearest')>0;
end
end

function w = classWeight(c)
switch upper(char(c))
    case 'A', w=1.0;
    case 'B', w=0.35;
    case 'C', w=0.05;
    otherwise, w=1.0;
end
end

function M = centralEllipse(sz,rx,ry)
[x,y] = meshgrid(linspace(-1,1,sz(2)),linspace(-1,1,sz(1)));
M = (x/rx).^2+(y/ry).^2<=1;
end

function y = rank01(x)
x = double(x);
lo = prctile(x(:),1);
hi = prctile(x(:),99);
y = (x-lo)/(hi-lo+eps);
y = clamp01(y);
end

function z = robustZ(x)
x = double(x);
z = (x-median(x(:)))/(1.4826*mad(x(:),1)+eps);
end

function y = clamp01(x)
y = min(max(double(x),0),1);
end

function p = wrapToPiLocal(p)
p = mod(p+pi,2*pi)-pi;
end

function RGB = signedFieldRGB(x)
x = x/(max(abs(x),[],'all')+eps);
RGB = zeros([size(x) 3]);
RGB(:,:,1) = max(x,0);
RGB(:,:,2) = 1-abs(x);
RGB(:,:,3) = max(-x,0);
RGB = clamp01(RGB);
end

function G = makeGrid(images,ncol)
H = size(images,1); W = size(images,2); C = size(images,3); N = size(images,4);
nrow = ceil(N/ncol);
G = ones(nrow*H,ncol*W,C);
for n = 1:N
    r = floor((n-1)/ncol);
    c = mod(n-1,ncol);
    G(r*H+(1:H),c*W+(1:W),:) = images(:,:,:,n);
end
G = clamp01(G);
end
