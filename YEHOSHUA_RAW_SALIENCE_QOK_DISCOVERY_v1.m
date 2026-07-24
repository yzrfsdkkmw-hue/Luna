function result = YEHOSHUA_RAW_SALIENCE_QOK_DISCOVERY_v1()
% YEHOSHUA_RAW_SALIENCE_QOK_DISCOVERY_v1
% -------------------------------------------------------------------------
% Read-only, SSOT-only mathematical discovery pipeline.
%
% Fixed source
%   /MATLAB Drive/modelTRAINING/
%   jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%   dataset: /n_5_composite_field_1000x1000/data
%
% This function:
%   1. Reads only the original SSOT H5 dataset.
%   2. Does not read QOK-derived H5 files, MAT patches, StringTheory files,
%      Orch tensors, images, or any other external source.
%   3. Does not create directories and does not write files.
%   4. Extracts the five-channel field and its shared singular subspaces.
%   5. Computes candidate RAW residuals after removing each possible shared
%      rank r = 1,2,3,4.
%   6. Computes residual modes, phase coherence, phase winding, curvature,
%      candidate salience, knowledge quanta, relation graphs, graph
%      Laplacians, and differential-operator commutators for every rank.
%
% Important mathematical boundary
%   The SSOT dataset itself does not label one singular rank as a
%   "string-theory layer". Therefore this function does not select such a
%   rank. It returns all mathematically possible non-zero candidate
%   removals. Yehoshua alone may inspect the outputs and decide whether any
%   candidate should later receive a system meaning.
%
% No source file is moved, renamed, deleted, modified, or hashed.
% No result is declared canonical by this function.
% -------------------------------------------------------------------------

%% Configuration: one source only
cfg.version = 'YEHOSHUA_RAW_SALIENCE_QOK_DISCOVERY_v1';
cfg.ssotFile = ['/MATLAB Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.ssotDataset = '/n_5_composite_field_1000x1000/data';
cfg.expectedValueCount = 5000000;
cfg.expectedChannelCount = 5;
cfg.originalSpatialSize = [1000 1000];
cfg.workSize = [256 256];
cfg.candidateRemovalRanks = 1:4;
cfg.maxResidualModes = 4;
cfg.maxKnowledgeQuanta = 96;
cfg.minQuantumDistance = 14;
cfg.quantumSalienceQuantile = 0.985;
cfg.graphK = 4;
cfg.commutatorProbeCount = 3;
cfg.randomSeed = 26072026;

fprintf('\n[%s] Starting SSOT-only read-only run.\n', cfg.version);
fprintf('Source:  %s\n', cfg.ssotFile);
fprintf('Dataset: %s\n', cfg.ssotDataset);
fprintf('Disk writes: disabled\n\n');

%% Read and verify only the fixed dataset
assert(isfile(cfg.ssotFile), 'SSOT file not found: %s', cfg.ssotFile);
info = h5info(cfg.ssotFile, cfg.ssotDataset);
raw = readCanonicalFiveChannelField( ...
    cfg.ssotFile, cfg.ssotDataset, cfg.expectedValueCount);

assert(isequal(size(raw), [cfg.originalSpatialSize cfg.expectedChannelCount]), ...
    'SSOT field must resolve to 1000x1000x5; received %s.', ...
    mat2str(size(raw)));
assert(all(isfinite(raw(:))), 'SSOT field contains non-finite values.');

%% Common work grid: derived only from the five SSOT channels
H = cfg.workSize(1);
W = cfg.workSize(2);
N = H * W;
M = cfg.expectedChannelCount;

workTensor = zeros(H, W, M, 'single');
Y = zeros(N, M, 'single');
channelStatistics = repmat(struct( ...
    'channel', 0, 'minimum', 0, 'maximum', 0, 'mean', 0, ...
    'standard_deviation', 0, 'median', 0, 'mad_scale', 0), M, 1);

for c = 1:M
    sourceChannel = single(raw(:,:,c));
    workTensor(:,:,c) = resize2Safe(sourceChannel, cfg.workSize);
    [Y(:,c), channelStatistics(c)] = robustFieldVector(workTensor(:,:,c), c);
end

%% Shared channel-space decomposition from the SSOT alone
[Ushared, Sshared, Vshared] = svd(double(Y), 'econ'); %#ok<ASGLU>
sharedSingularValues = diag(Sshared);
sharedEigenvalues = (sharedSingularValues.^2) / max(N - 1, 1);
sharedEnergyFraction = sharedEigenvalues ./ max(sum(sharedEigenvalues), eps);
sharedCumulativeEnergy = cumsum(sharedEnergyFraction);

sharedModes = zeros(H, W, M, 'single');
for k = 1:M
    sharedModes(:,:,k) = reshape(single(Ushared(:,k) * Sshared(k,k)), H, W);
end

%% Candidate residuals for every removable non-zero rank
candidateTemplate = struct( ...
    'removedRank', [], ...
    'removedChannelBasis', [], ...
    'removedEnergyFraction', [], ...
    'residualTensor', [], ...
    'residualFractionByChannel', [], ...
    'residualModes', [], ...
    'residualEigenvalues', [], ...
    'residualEnergy', [], ...
    'phaseCoherence', [], ...
    'dominantPhase', [], ...
    'winding', [], ...
    'curvature', [], ...
    'salience', [], ...
    'quanta', [], ...
    'graph', [], ...
    'operator', [], ...
    'summary', []);

ranks = cfg.candidateRemovalRanks;
candidates = repmat(candidateTemplate, numel(ranks), 1);

for idx = 1:numel(ranks)
    removedRank = ranks(idx);
    assert(removedRank >= 1 && removedRank < M, ...
        'Candidate rank must be between 1 and %d.', M-1);

    % Projection is performed only in the five-channel space.
    % No external symbolic tensor or semantic label is introduced.
    Vr = Vshared(:,1:removedRank);
    represented = double(Y) * Vr * Vr';
    residualMatrix = single(double(Y) - represented);

    rng(cfg.randomSeed + removedRank, 'twister');
    candidates(idx) = analyzeResidualCandidate( ...
        residualMatrix, Y, H, W, cfg, removedRank, Vr, ...
        sum(sharedEnergyFraction(1:removedRank)));
end

%% In-memory result only
result = struct();
result.config = cfg;
result.source = struct( ...
    'file', cfg.ssotFile, ...
    'dataset', cfg.ssotDataset, ...
    'h5_dataspace_size', double(info.Dataspace.Size), ...
    'resolved_size', size(raw), ...
    'value_count', numel(raw), ...
    'read_only', true, ...
    'external_sources_read', false, ...
    'disk_writes_performed', false);
result.raw = raw;
result.workTensor = workTensor;
result.normalizedFieldMatrix = Y;
result.channelStatistics = channelStatistics;
result.shared.channelBasis = Vshared;
result.shared.singularValues = sharedSingularValues;
result.shared.eigenvalues = sharedEigenvalues;
result.shared.energyFraction = sharedEnergyFraction;
result.shared.cumulativeEnergy = sharedCumulativeEnergy;
result.shared.spatialModes = sharedModes;
result.candidates = candidates;
result.selection = struct( ...
    'selectedRank', [], ...
    'status', 'not selected by code', ...
    'reason', ['The SSOT dataset contains no explicit label identifying ' ...
               'one singular rank as the string-theory layer.']);

fprintf('Resolved SSOT tensor: %dx%dx%d\n', size(raw,1), size(raw,2), size(raw,3));
fprintf('Candidate removal ranks computed: %s\n', mat2str(ranks));
for idx = 1:numel(candidates)
    s = candidates(idx).summary;
    fprintf(['  rank %d | residual fraction %.6f | modes %d | ' ...
             'quanta %d | mean salience %.6f\n'], ...
        s.removed_rank, s.total_residual_fraction, ...
        s.residual_mode_count, s.knowledge_quantum_count, ...
        s.mean_salience);
end
fprintf('No directory or output file was created.\n\n');
end

%% ------------------------------------------------------------------------
function candidate = analyzeResidualCandidate(R, Y, H, W, cfg, ...
        removedRank, removedBasis, removedEnergyFraction)
N = H * W;
M = size(R,2);
residualTensor = reshape(R, H, W, M);

sourceEnergyByChannel = sum(double(Y).^2, 1);
residualEnergyByChannel = sum(double(R).^2, 1);
residualFractionByChannel = residualEnergyByChannel ./ ...
    max(sourceEnergyByChannel, eps);
totalResidualFraction = sum(residualEnergyByChannel) / ...
    max(sum(sourceEnergyByChannel), eps);

%% Joint residual spectrum and spatial modes
C = double(R' * R) / max(N - 1, 1);
C = (C + C') / 2;
[V, D] = eig(C, 'vector');
[D, order] = sort(real(D), 'descend');
V = real(V(:,order));

if isempty(D)
    keep = false(0,1);
else
    keep = D > max(max(D), eps) * 1e-12;
end
D = D(keep);
V = V(:,keep);
K = min([cfg.maxResidualModes, numel(D), size(V,2)]);

if K > 0
    residualEigenvalues = D(1:K);
    residualModesMatrix = double(R) * V(:,1:K);
    for k = 1:K
        scale = sqrt(max((N - 1) * residualEigenvalues(k), eps));
        residualModesMatrix(:,k) = residualModesMatrix(:,k) / scale;
    end
    residualModes = reshape(single(residualModesMatrix), H, W, K);
else
    residualEigenvalues = zeros(0,1);
    residualModes = zeros(H,W,0,'single');
end

residualEnergy = reshape(single(sum(double(R).^2, 2)), H, W);

%% Phase system derived only from residual channels
[phaseCoherence, phaseStack, quadratureAmplitude] = ...
    weightedPhaseCoherence(residualTensor); %#ok<ASGLU>

if K >= 2
    dominantComplex = complex( ...
        double(residualModes(:,:,1)), double(residualModes(:,:,2)));
elseif K == 1
    dominantComplex = rieszComplex(residualModes(:,:,1));
else
    dominantComplex = complex(zeros(H,W), zeros(H,W));
end

dominantPhase = angle(dominantComplex);
windingMap = phaseWinding(dominantPhase);
curvatureMap = laplacian2(real(dominantComplex));

%% Candidate salience: no notebook, Orch, RGB, or external QOK fields
E = rank01(log1p(residualEnergy));
P = rank01(phaseCoherence);
Wn = rank01(abs(windingMap));
Curv = rank01(abs(curvatureMap));

salience = rank01( ...
    E .* (0.25 + 0.75 * P) .* ...
    (1 + 0.50 * Wn) .* ...
    (1 + 0.25 * Curv));

%% Knowledge quanta
[qr, qc] = greedyNMS(salience, cfg.maxKnowledgeQuanta, ...
    cfg.minQuantumDistance, cfg.quantumSalienceQuantile);
Qn = numel(qr);

positionXY = zeros(Qn,2);
positionRCOriginal = zeros(Qn,2);
amplitude = zeros(Qn,1);
eta = zeros(Qn,1);
charge = zeros(Qn,1);

% tau is intentionally not inferred. The fixed H5 dataset has five fields,
% but no explicitly anchored time axis in this function.
tau = nan(Qn,3);

muLabels = [compose("residual_channel_%d", 1:M)'; ...
    "residual_energy"; "phase_coherence"; "winding"; "curvature"];
mu = zeros(Qn, numel(muLabels));

for i = 1:Qn
    r = qr(i);
    c = qc(i);
    positionXY(i,:) = [(c - 1) / max(W - 1, 1), ...
                       (r - 1) / max(H - 1, 1)];
    positionRCOriginal(i,:) = [ ...
        1 + (r - 1) * (cfg.originalSpatialSize(1)-1) / max(H-1,1), ...
        1 + (c - 1) * (cfg.originalSpatialSize(2)-1) / max(W-1,1)];
    amplitude(i) = salience(r,c);
    eta(i) = dominantPhase(r,c);
    charge(i) = windingMap(r,c);

    featureIndex = 0;
    for ch = 1:M
        featureIndex = featureIndex + 1;
        mu(i,featureIndex) = localMean(residualTensor(:,:,ch), r, c, 2);
    end
    featureIndex = featureIndex + 1;
    mu(i,featureIndex) = localMean(E, r, c, 2);
    featureIndex = featureIndex + 1;
    mu(i,featureIndex) = localMean(P, r, c, 2);
    featureIndex = featureIndex + 1;
    mu(i,featureIndex) = localMean(windingMap, r, c, 2);
    featureIndex = featureIndex + 1;
    mu(i,featureIndex) = localMean(Curv, r, c, 2);
end
mu = robustColumns(mu);

[adjacency, graphLaplacian, graphEmbedding] = buildQuantumGraph( ...
    positionXY, eta, charge, mu, cfg.graphK);

quantumTable = table( ...
    (1:Qn)', ...
    positionXY(:,1), positionXY(:,2), ...
    positionRCOriginal(:,1), positionRCOriginal(:,2), ...
    amplitude, eta, charge, ...
    tau(:,1), tau(:,2), tau(:,3), ...
    'VariableNames', {'id','x','y','row_original','col_original', ...
    'amplitude','eta','charge','tau_1','tau_2','tau_3'});

%% Matrix-free noncommutativity of residual-conditioned operators
fieldResidualEnergy = squeeze(sum(sum(double(residualTensor).^2,1),2));
[~, operatorOrder] = sort(fieldResidualEnergy, 'descend');
operatorOrder = operatorOrder(:)';
operatorNames = compose("residual_channel_%d", operatorOrder)';
commutatorEnergy = estimateOperatorCommutators( ...
    residualTensor(:,:,operatorOrder), cfg.commutatorProbeCount);

summary = struct();
summary.removed_rank = removedRank;
summary.removed_shared_energy_fraction = removedEnergyFraction;
summary.total_residual_fraction = totalResidualFraction;
summary.residual_fraction_by_channel = residualFractionByChannel;
summary.residual_mode_count = K;
summary.residual_eigenvalues = residualEigenvalues(:)';
summary.knowledge_quantum_count = Qn;
summary.mean_salience = mean(double(salience(:)));
summary.max_salience = max(double(salience(:)));
summary.mean_phase_coherence = mean(double(phaseCoherence(:)));
summary.max_abs_winding = max(abs(double(windingMap(:))));
summary.tau_available = false;
summary.external_sources_used = false;
summary.disk_writes_performed = false;

candidate = struct();
candidate.removedRank = removedRank;
candidate.removedChannelBasis = removedBasis;
candidate.removedEnergyFraction = removedEnergyFraction;
candidate.residualTensor = residualTensor;
candidate.residualFractionByChannel = residualFractionByChannel;
candidate.residualModes = residualModes;
candidate.residualEigenvalues = residualEigenvalues;
candidate.residualEnergy = residualEnergy;
candidate.phaseCoherence = phaseCoherence;
candidate.dominantPhase = single(dominantPhase);
candidate.winding = windingMap;
candidate.curvature = curvatureMap;
candidate.salience = salience;
candidate.quanta = struct( ...
    'table', quantumTable, ...
    'positionXY', positionXY, ...
    'positionRCOriginal', positionRCOriginal, ...
    'amplitude', amplitude, ...
    'eta', eta, ...
    'charge', charge, ...
    'mu', mu, ...
    'muLabels', muLabels, ...
    'tau', tau, ...
    'tauAvailable', false);
candidate.graph = struct( ...
    'adjacency', adjacency, ...
    'laplacian', graphLaplacian, ...
    'embedding', graphEmbedding);
candidate.operator = struct( ...
    'names', operatorNames, ...
    'commutatorEnergy', commutatorEnergy);
candidate.summary = summary;
end

%% ------------------------------------------------------------------------
function raw = readCanonicalFiveChannelField(file, dataset, expectedCount)
x = h5read(file, dataset);
assert(isnumeric(x) || islogical(x), ...
    'SSOT dataset must be numeric or logical.');
x = single(x);
assert(numel(x) == expectedCount, ...
    'Expected %d values at %s; received %d.', ...
    expectedCount, dataset, numel(x));

sz = size(x);
if isequal(sz, [5 1000000])
    raw = permute(reshape(x, [5 1000 1000]), [2 3 1]);
elseif isequal(sz, [1000000 5])
    raw = reshape(x, [1000 1000 5]);
else
    % The fixed source is known as five interleaved channels. This branch
    % preserves that representation when MATLAB reports singleton-extended
    % dimensions or a flat vector.
    v = x(:);
    raw = permute(reshape(v, [5 1000 1000]), [2 3 1]);
end
end

function [v, stats] = robustFieldVector(x, channelIndex)
x = double(x(:));
med = median(x);
scale = 1.4826 * median(abs(x - med));
if ~isfinite(scale) || scale <= eps
    scale = std(x);
end
if ~isfinite(scale) || scale <= eps
    z = zeros(size(x));
    scale = 0;
else
    z = (x - med) / scale;
    z = max(min(z, 8), -8);
    z = z - mean(z);
end
v = single(z);
stats = struct( ...
    'channel', channelIndex, ...
    'minimum', min(x), ...
    'maximum', max(x), ...
    'mean', mean(x), ...
    'standard_deviation', std(x), ...
    'median', med, ...
    'mad_scale', scale);
end

function y = resize2Safe(x, targetSize)
x = single(squeeze(x));
assert(ismatrix(x), 'resize2Safe expects a 2-D field.');
if isequal(size(x), targetSize)
    y = x;
    return;
end
if exist('imresize', 'file') == 2
    y = single(imresize(x, targetSize, 'bicubic'));
else
    [h,w] = size(x);
    [Xq,Yq] = meshgrid( ...
        linspace(1,w,targetSize(2)), ...
        linspace(1,h,targetSize(1)));
    y = single(interp2(double(x), Xq, Yq, 'linear', 0));
end
end

function [coherence, phaseStack, amplitudeStack] = ...
        weightedPhaseCoherence(tensor)
[H,W,M] = size(tensor);
phaseStack = zeros(H,W,M,'single');
amplitudeStack = zeros(H,W,M,'single');
phasorSum = complex(zeros(H,W), zeros(H,W));
weightSum = zeros(H,W);

for i = 1:M
    z = rieszComplex(tensor(:,:,i));
    a = abs(z);
    p = angle(z);
    phaseStack(:,:,i) = single(p);
    amplitudeStack(:,:,i) = single(a);
    phasorSum = phasorSum + a .* exp(1i * p);
    weightSum = weightSum + a;
end
coherence = single(abs(phasorSum) ./ max(weightSum, eps));
coherence(~isfinite(coherence)) = 0;
end

function Z = rieszComplex(x)
x = double(x);
[H,W] = size(x);
[kx,ky] = meshgrid( ...
    ifftshift((-floor(W/2):ceil(W/2)-1) / W), ...
    ifftshift((-floor(H/2):ceil(H/2)-1) / H));
k = sqrt(kx.^2 + ky.^2);
k(1,1) = 1;
multiplier = -1i * (kx + ky) ./ (sqrt(2) * k);
multiplier(1,1) = 0;
q = real(ifft2(multiplier .* fft2(x)));
Z = complex(x, q);
end

function w = phaseWinding(phi)
wrap = @(a) mod(a + pi, 2*pi) - pi;
d1 = wrap(phi(1:end-1,2:end) - phi(1:end-1,1:end-1));
d2 = wrap(phi(2:end,2:end) - phi(1:end-1,2:end));
d3 = wrap(phi(2:end,1:end-1) - phi(2:end,2:end));
d4 = wrap(phi(1:end-1,1:end-1) - phi(2:end,1:end-1));
charge = (d1 + d2 + d3 + d4) / (2*pi);
w = zeros(size(phi), 'single');
w(1:end-1,1:end-1) = single(charge);
end

function L = laplacian2(x)
L = single(conv2(double(x), [0 1 0; 1 -4 1; 0 1 0], 'same'));
end

function y = rank01(x)
x = double(x);
finiteMask = isfinite(x);
y = zeros(size(x), 'single');
if ~any(finiteMask(:))
    return;
end
v = x(finiteMask);
lo = localPercentile(v, 1);
hi = localPercentile(v, 99);
if hi <= lo + eps
    lo = min(v);
    hi = max(v);
end
if hi <= lo + eps
    return;
end
z = (x - lo) / (hi - lo);
z = min(max(z, 0), 1);
z(~finiteMask) = 0;
y = single(z);
end

function q = localPercentile(v, p)
v = sort(double(v(:)));
if isempty(v)
    q = NaN;
    return;
end
idx = 1 + (numel(v)-1) * (p/100);
a = floor(idx);
b = ceil(idx);
if a == b
    q = v(a);
else
    q = v(a) + (idx-a) * (v(b)-v(a));
end
end

function [rows, cols] = greedyNMS(S, maxCount, minDistance, qtl)
S = double(S);
[H,W] = size(S);
if isempty(S) || ~any(isfinite(S(:))) || max(S(:), [], 'omitnan') <= eps
    rows = zeros(0,1);
    cols = zeros(0,1);
    return;
end
S(~isfinite(S)) = -Inf;
threshold = localPercentile(S(isfinite(S)), 100*qtl);
[values, idx] = sort(S(:), 'descend');
rows = zeros(maxCount,1);
cols = zeros(maxCount,1);
count = 0;

for k = 1:numel(idx)
    if ~isfinite(values(k))
        break;
    end
    if values(k) < threshold && count >= min(12, maxCount)
        break;
    end
    [r,c] = ind2sub([H W], idx(k));
    if count == 0 || all((rows(1:count)-r).^2 + ...
            (cols(1:count)-c).^2 >= minDistance^2)
        count = count + 1;
        rows(count) = r;
        cols(count) = c;
        if count >= maxCount
            break;
        end
    end
end
rows = rows(1:count);
cols = cols(1:count);
end

function v = localMean(X, r, c, radius)
X = double(X);
r0 = max(1, r-radius);
r1 = min(size(X,1), r+radius);
c0 = max(1, c-radius);
c1 = min(size(X,2), c+radius);
block = X(r0:r1, c0:c1);
finiteValues = block(isfinite(block));
if isempty(finiteValues)
    v = 0;
else
    v = mean(finiteValues);
end
end

function X = robustColumns(X)
X = double(X);
for j = 1:size(X,2)
    col = X(:,j);
    finiteMask = isfinite(col);
    if ~any(finiteMask)
        X(:,j) = 0;
        continue;
    end
    med = median(col(finiteMask));
    s = 1.4826 * median(abs(col(finiteMask)-med));
    if ~isfinite(s) || s <= eps
        s = std(col(finiteMask));
    end
    if ~isfinite(s) || s <= eps
        X(:,j) = 0;
    else
        col(~finiteMask) = med;
        X(:,j) = max(min((col-med)/s, 8), -8);
    end
end
end

function [A, L, E] = buildQuantumGraph(P, eta, charge, mu, k)
N = size(P,1);
if N == 0
    A = zeros(0);
    L = zeros(0);
    E = zeros(0,0);
    return;
elseif N == 1
    A = 0;
    L = 0;
    E = zeros(1,0);
    return;
end

DP2 = pairwiseSquared(P);
DM2 = pairwiseSquared(mu);

nonzeroP = DP2(DP2 > 0);
nonzeroM = DM2(DM2 > 0);
sp = sqrt(median(nonzeroP));
sm = sqrt(median(nonzeroM));
if ~isfinite(sp) || sp <= eps, sp = 1; end
if ~isfinite(sm) || sm <= eps, sm = 1; end

phaseSim = (1 + cos(eta - eta')) / 2;
chargeSim = exp(-abs(charge - charge'));
weights = exp(-DP2/(sp^2 + eps)) .* ...
    exp(-DM2/(sm^2 + eps)) .* ...
    phaseSim .* (0.75 + 0.25 * chargeSim);
weights(1:N+1:end) = 0;

mask = false(N);
for i = 1:N
    [~, idx] = sort(weights(i,:), 'descend');
    idx = idx(1:min(k, N-1));
    mask(i,idx) = true;
end
A = max(weights .* mask, (weights .* mask)');
D = diag(sum(A,2));
L = D - A;
Dinv = diag(1 ./ sqrt(max(diag(D), eps)));
Ln = Dinv * L * Dinv;
[V, lambda] = eig((Ln + Ln')/2, 'vector');
[~, order] = sort(real(lambda), 'ascend');
V = real(V(:,order));
E = V(:,2:min(4,size(V,2)));
end

function D2 = pairwiseSquared(X)
X = double(X);
if isempty(X)
    D2 = zeros(size(X,1));
    return;
end
s = sum(X.^2,2);
D2 = max(0, s + s' - 2*(X*X'));
end

function C = estimateOperatorCommutators(fields, probeCount)
[H,W,M] = size(fields);
weights = cell(M,1);
for i = 1:M
    X = double(fields(:,:,i));
    [gx,gy] = gradient(X);
    g = sqrt(gx.^2 + gy.^2);
    positive = g(g > 0 & isfinite(g));
    if isempty(positive)
        scale = 1;
    else
        scale = median(positive);
        if ~isfinite(scale) || scale <= eps
            scale = 1;
        end
    end
    weights{i} = 1 ./ sqrt(1 + (g/scale).^2);
end

C = zeros(M,M);
for i = 1:M
    for j = i+1:M
        acc = 0;
        for p = 1:probeCount
            z = sign(randn(H,W));
            a = applyAnisotropic( ...
                applyAnisotropic(z, weights{j}), weights{i});
            b = applyAnisotropic( ...
                applyAnisotropic(z, weights{i}), weights{j});
            acc = acc + sum((a(:)-b(:)).^2) / ...
                max(sum(z(:).^2), eps);
        end
        C(i,j) = acc / probeCount;
        C(j,i) = C(i,j);
    end
end
end

function out = applyAnisotropic(z, w)
z = double(z);
w = double(w);
fx = 0.5 * (w(:,1:end-1) + w(:,2:end)) .* diff(z,1,2);
fy = 0.5 * (w(1:end-1,:) + w(2:end,:)) .* diff(z,1,1);

divx = zeros(size(z));
divy = zeros(size(z));
divx(:,1) = fx(:,1);
divx(:,2:end-1) = fx(:,2:end) - fx(:,1:end-1);
divx(:,end) = -fx(:,end);
divy(1,:) = fy(1,:);
divy(2:end-1,:) = fy(2:end,:) - fy(1:end-1,:);
divy(end,:) = -fy(end,:);
out = divx + divy;
end
