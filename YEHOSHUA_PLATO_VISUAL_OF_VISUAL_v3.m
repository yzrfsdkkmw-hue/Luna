function result = YEHOSHUA_PLATO_VISUAL_OF_VISUAL_v3(mode)
% Second-order visual forecast and full-color human portrait rendering.
% Modes:
%   preflight - validate all inputs without creating output files.
%   execute   - compute the forecast, render candidates, and validate output.

% The final visual selection is intentionally left to Yehoshua.

% State law:
%   z1 = T(z0,u0)
%   z2 = T(z1,u1)
%   T(z,u) = (I+dt*(alpha*L+beta*L^2))^-1 *
%            (z+dt*(B*u+gamma*tanh(W*z+b)+0.5*H[z,z]))

% Surface law:
%   Ews(X) = Ts*trace(X'*Lcot*X) + kappa*||Lcot*X||_F^2.

% This implementation uses the image-grid Laplacian and bi-Laplacian,
% evaluated in the Fourier domain, as the discrete surface operator.

if nargin < 1
    mode = 'execute';
end
mode = lower(string(mode));
assert(any(mode == ["preflight","execute"]), ...
    'Mode must be preflight or execute.');

cfg = configuration();
sourceInfo = verifyInputs(cfg);

if mode == "preflight"
    result = struct();
    result.mode = 'preflight';
    result.ready = true;
    result.files_written = 0;
    result.source_sha256 = sourceInfo.sourceSHA256;
    result.source_value_count = sourceInfo.sourceValueCount;
    result.visual_one_size = sourceInfo.visualOneSize;
    result.depth_one_size = sourceInfo.depthOneSize;
    disp(jsonencode(result,PrettyPrint=true));
    return;
end

rng(cfg.seed,'twister');
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
outDir = fullfile(cfg.outputRoot, ...
    ['YEHOSHUA_PLATO_VISUAL_OF_VISUAL_v3_' stamp]);
[ok,msg] = mkdir(outDir);
assert(ok || isfolder(outDir), ...
    'Cannot create output directory: %s (%s)',outDir,msg);

fprintf('[01/10] Reading and decoding the five-channel H5 source...\n');
F = readSourceCube(cfg);

fprintf('[02/10] Building perceptual and phase fields...\n');
source = buildSourceState(F,cfg);
clear F

fprintf('[03/10] Loading visual state one...\n');
visualOne = loadVisualOne(cfg);

fprintf('[04/10] Computing the first and second visual forecasts...\n');
[visualFirst,visualSecond,forecast] = ...
    predictVisualOfVisual(visualOne,source,cfg);

fprintf('[05/10] Building the human surface and worldsheet response...\n');
surface = buildHumanSurface(visualSecond,source,cfg);

fprintf('[06/10] Rendering nine full-color candidates...\n');
candidates = zeros(cfg.N,cfg.N,3,cfg.candidateCount,'single');
candidateMetrics = struct([]);
primaryAux = struct();
for k = 1:cfg.candidateCount
    variation = candidateVariation(k,cfg);
    [candidates(:,:,:,k),aux] = renderColorPortrait( ...
        surface,visualSecond,source,variation,cfg);
    summary = summarizeCandidate(candidates(:,:,:,k),aux,k);
    if k == 1
        candidateMetrics = repmat(summary,cfg.candidateCount,1);
    else
        candidateMetrics(k) = summary;
    end
    if k == cfg.primaryCandidate
        primaryAux = aux;
    end
end
primary = candidates(:,:,:,cfg.primaryCandidate);

fprintf('[07/10] Writing isolated output artifacts...\n');
writeOutputs(outDir,primary,candidates,visualOne,visualFirst, ...
    visualSecond,surface,primaryAux,source,forecast,candidateMetrics,cfg);

fprintf('[08/10] Validating numerical and visual output...\n');
metrics = validateOutputs(outDir,primary,candidates,visualOne, ...
    visualFirst,visualSecond,surface,forecast,candidateMetrics,cfg);
writeJSON(fullfile(outDir,'10_metrics.json'),metrics);

fprintf('[09/10] Writing run manifest...\n');
manifest = struct();
manifest.schema = 'YEHOSHUA_PLATO_VISUAL_OF_VISUAL_v3';
manifest.created_at = char(datetime('now', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSS'));
manifest.source_h5 = cfg.sourceFile;
manifest.source_h5_sha256 = sourceInfo.sourceSHA256;
manifest.source_dataset = cfg.datasetPath;
manifest.visual_one = cfg.visualOneFile;
manifest.depth_one = cfg.depthOneFile;
manifest.state_law = ['z1=T(z0,u0); z2=T(z1,u1); ' ...
    'T=(I+dt*(alpha*L+beta*L^2))^-1*' ...
    '(z+dt*(B*u+gamma*tanh(W*z+b)+0.5*H[z,z]))'];
manifest.surface_law = ['Ews=Ts*trace(X''*Lcot*X)+' ...
    'kappa*norm(Lcot*X,F)^2'];
manifest.output_directory = outDir;
manifest.primary_candidate_index = cfg.primaryCandidate;
manifest.candidate_count = cfg.candidateCount;
manifest.validation_pass = metrics.validation_pass;
writeJSON(fullfile(outDir,'00_run_manifest.json'),manifest);

fprintf('[10/10] Rechecking the H5 source hash...\n');
assert(strcmpi(sha256File(cfg.sourceFile),cfg.expectedSHA256), ...
    'Source H5 changed during the run.');
assert(metrics.validation_pass,'Output validation did not pass.');

result = struct();
result.mode = 'execute';
result.output_directory = outDir;
result.primary_portrait = fullfile(outDir,'01_primary_color_portrait.png');
result.candidate_grid = fullfile(outDir,'02_candidate_grid.png');
result.candidate_count = cfg.candidateCount;
result.primary_candidate_index = cfg.primaryCandidate;
result.metrics = metrics;
disp(jsonencode(result,PrettyPrint=true));
end

function cfg = configuration()
cfg.root = '/Users/yehoshua/MATLAB-Drive/modelTRAINING';
cfg.sourceFile = fullfile(cfg.root, ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5');
cfg.datasetPath = '/n_5_composite_field_1000x1000/data';
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.visualOneFile = ['/Users/yehoshua/Documents/Codex/2026-07-22/' ...
    'new-chat/outputs/YEHOSHUA_PLATO_SYNTHESIS_v1_20260722_113958_382/' ...
    '01_plato_portrait.png'];
cfg.depthOneFile = ['/Users/yehoshua/Documents/Codex/2026-07-22/' ...
    'new-chat/outputs/YEHOSHUA_PLATO_SYNTHESIS_v1_20260722_113958_382/' ...
    '02_depth_map.png'];
cfg.outputRoot = '/Users/yehoshua/Documents/Codex/2026-07-22/new-chat/outputs';
cfg.N = 768;
cfg.seed = 2511;
cfg.candidateCount = 9;
cfg.primaryCandidate = 5;

% Values retained from the inspected v15 adaptive system.
cfg.dt = 0.080;
cfg.alpha = 0.78;
cfg.beta = 0.060;
cfg.driveGain = 0.34;
cfg.nonlinearGain = 0.22;
cfg.secondOrderGain = 0.12;
cfg.qBaseBudget = 0.72;
cfg.qOverloadGain = 3.20;
cfg.qSelectivityGain = 7.50;

% Discrete worldsheet weights.
cfg.stringTension = 0.16;
cfg.bendingWeight = 0.035;
cfg.detailAmplitude = 0.040;
cfg.normalScale = 68;
end

function info = verifyInputs(cfg)
assert(isfile(cfg.sourceFile),'Source H5 not found: %s',cfg.sourceFile);
actualHash = sha256File(cfg.sourceFile);
assert(strcmpi(actualHash,cfg.expectedSHA256),'Source H5 hash mismatch.');
h = h5info(cfg.sourceFile,cfg.datasetPath);
assert(prod(double(h.Dataspace.Size)) == 5000000, ...
    'Unexpected source value count.');
assert(isfile(cfg.visualOneFile),'Visual state one not found.');
assert(isfile(cfg.depthOneFile),'Depth state one not found.');
v = imfinfo(cfg.visualOneFile);
d = imfinfo(cfg.depthOneFile);
assert(v.Width > 0 && v.Height > 0 && d.Width > 0 && d.Height > 0, ...
    'Input image dimensions are invalid.');
assert(isfolder(cfg.outputRoot),'Output root does not exist.');
info = struct('sourceSHA256',actualHash, ...
    'sourceValueCount',prod(double(h.Dataspace.Size)), ...
    'visualOneSize',[v.Height v.Width], ...
    'depthOneSize',[d.Height d.Width]);
end

function F = readSourceCube(cfg)
v = double(h5read(cfg.sourceFile,cfg.datasetPath));
v = v(:);
assert(numel(v) == 5000000,'Unexpected source value count after reading.');
F = permute(reshape(v,[5 1000 1000]),[2 3 1]);
assert(isequal(size(F),[1000 1000 5]),'Unexpected decoded source shape.');
assert(all(isfinite(F),'all'),'Source contains non-finite values.');
end

function source = buildSourceState(F,cfg)
channels = zeros(cfg.N,cfg.N,5,'single');
for c = 1:5
    channels(:,:,c) = imresize(single(robust01(F(:,:,c))), ...
        [cfg.N cfg.N],'bilinear');
end
channelEnergy = squeeze(std(reshape(channels,[],5),0,1));
channelWeights = channelEnergy ./ max(sum(channelEnergy),eps);
I = sum(channels .* reshape(single(channelWeights),1,1,5),3);

kx = double([-1 0 1]/2);
ky = kx.';
gx = imfilter(I,kx,'replicate','conv');
gy = imfilter(I,ky,'replicate','conv');
grad = normalize01(hypot(gx,gy));
lap = normalize01(abs(imfilter(I,double([0 1 0;1 -4 1;0 1 0]), ...
    'replicate','conv')));
dog = normalize01(abs(imgaussfilt(I,1.2)-imgaussfilt(I,6.0)));
high = normalizeSigned(I-imgaussfilt(I,12));
phase = atan2(gy,gx);
phaseVector = imgaussfilt(cos(phase),3)+1i*imgaussfilt(sin(phase),3);
phaseCoherence = normalize01(abs(phaseVector));

structured = normalize01(0.34*grad+0.24*lap+0.18*dog+ ...
    0.14*phaseCoherence+0.10*abs(high));
information = normalize01(0.34*I+0.22*grad+0.17*lap+ ...
    0.15*dog+0.12*abs(high));
predictionError = normalize01(abs(information-imgaussfilt(information,3)));
disagreement = normalize01(std(channels,0,3));
budget = cfg.qBaseBudget*(0.55+0.45*structured);
consumed = information+0.48*disagreement+0.42*predictionError;
overload = max(0,consumed./(budget+eps)-1);
precision = exp(-cfg.qOverloadGain*overload);
selective = sigmoid(cfg.qSelectivityGain*(structured- ...
    0.80*disagreement-0.72*predictionError));
gate = clamp01(precision.*selective+(1-precision));

source = struct();
source.channels = channels;
source.channelWeights = channelWeights;
source.integrated = I;
source.gradient = grad;
source.laplacian = lap;
source.dog = dog;
source.high = high;
source.phase = phase;
source.phaseCoherence = phaseCoherence;
source.structured = structured;
source.information = information;
source.precision = precision;
source.overload = overload;
source.gate = gate;
end

function visualOne = loadVisualOne(cfg)
I = im2single(imread(cfg.visualOneFile));
if size(I,3) == 1
    G = I;
else
    G = rgb2gray(I(:,:,1:3));
end
D = im2single(imread(cfg.depthOneFile));
if size(D,3) > 1
    D = rgb2gray(D(:,:,1:3));
end
G = imresize(G,[cfg.N cfg.N],'bicubic');
D = imresize(D,[cfg.N cfg.N],'bicubic');
visualOne = normalize01(0.58*D+0.42*G);
end

function [z1,z2,diagnostics] = predictVisualOfVisual(z0,source,cfg)
u0 = normalize01(0.42*source.information+0.28*source.structured+ ...
    0.18*source.phaseCoherence+0.12*source.gate);
u1 = normalize01(0.35*u0+0.30*source.dog+ ...
    0.20*source.gradient+0.15*source.precision);
z1 = forecastStep(z0,u0,source.gate,cfg);
z2 = forecastStep(z1,u1,source.gate,cfg);
diagnostics = struct();
diagnostics.z0_z1_change = mean(abs(z1-z0),'all');
diagnostics.z1_z2_change = mean(abs(z2-z1),'all');
diagnostics.z0_z2_correlation = correlation01(z0,z2);
diagnostics.z1_z2_correlation = correlation01(z1,z2);
diagnostics.mean_precision = mean(source.precision,'all');
diagnostics.mean_overload = mean(source.overload,'all');
end

function zNext = forecastStep(z,u,gate,cfg)
[H,W] = size(z);
[fx,fy] = meshgrid(0:W-1,0:H-1);
lambda = 4*sin(pi*fx/W).^2 + 4*sin(pi*fy/H).^2;
smooth = imgaussfilt(z,2.4);
curvature = z-smooth;
secondOrder = curvature.*abs(curvature);
drive = cfg.driveGain*(u-0.5).*gate + ...
    cfg.nonlinearGain*tanh(2.2*(z-0.5)) + ...
    cfg.secondOrderGain*secondOrder;
denominator = 1+cfg.dt*(cfg.alpha*lambda+cfg.beta*lambda.^2);
zNext = real(ifft2(fft2(z+cfg.dt*drive)./denominator));
zNext = normalize01(zNext);
end

function surface = buildHumanSurface(z2,source,cfg)
N = cfg.N;
[x,y] = meshgrid(linspace(-1,1,N),linspace(-1,1,N));
width = 0.53 + 0.035*exp(-((y+0.28)/0.42).^2) ...
    -0.14*max(y-0.18,0) - 0.035*max(-y-0.62,0);
radial = (x./width).^2 + ((y+0.04)/0.90).^2;
face = radial <= 1;
ears = ((x-0.545)/0.075).^2+((y+0.01)/0.20).^2 <= 1 | ...
       ((x+0.545)/0.075).^2+((y+0.01)/0.20).^2 <= 1;
neck = abs(x) < 0.185 & y > 0.62 & y < 0.98;
shoulders = (x/0.92).^2+((y-1.02)/0.32).^2 <= 1 & y > 0.73;

base = sqrt(max(0,1-radial));
noseBridge = 0.34*exp(-(x/0.060).^2-((y+0.03)/0.28).^2);
noseTip = 0.18*exp(-(x/0.095).^2-((y-0.10)/0.075).^2);
cheeks = 0.13*(exp(-((x-0.235)/0.17).^2-((y-0.05)/0.20).^2)+ ...
    exp(-((x+0.235)/0.17).^2-((y-0.05)/0.20).^2));
eyeSockets = -0.18*(exp(-((x-0.185)/0.105).^2-((y+0.175)/0.060).^2)+ ...
    exp(-((x+0.185)/0.105).^2-((y+0.175)/0.060).^2));
browRidge = 0.07*(exp(-((x-0.19)/0.15).^2-((y+0.255)/0.055).^2)+ ...
    exp(-((x+0.19)/0.15).^2-((y+0.255)/0.055).^2));
upperLip = 0.050*exp(-(x/0.16).^2-((y-0.285)/0.030).^2);
lowerLip = 0.065*exp(-(x/0.17).^2-((y-0.335)/0.045).^2);
mouthSeam = -0.055*exp(-(x/0.18).^2-((y-0.305)/0.018).^2);
chin = 0.12*exp(-(x/0.19).^2-((y-0.53)/0.13).^2);
temples = -0.055*(exp(-((x-0.39)/0.12).^2-((y+0.18)/0.25).^2)+ ...
    exp(-((x+0.39)/0.12).^2-((y+0.18)/0.25).^2));

dataDepth = 0.82*base+noseBridge+noseTip+cheeks+eyeSockets+ ...
    browRidge+upperLip+lowerLip+mouthSeam+chin+temples;
detail = (z2-imgaussfilt(z2,9)).*(0.35+0.65*source.gate);
dataDepth = dataDepth+cfg.detailAmplitude*detail;
dataDepth(~face) = 0;
depth = worldsheetFilter(dataDepth,cfg);
depth(~face) = 0;
depth = max(depth,0);

[nx,ny,nz] = surfaceNormals(depth,cfg.normalScale);
surface = struct();
surface.x = x;
surface.y = y;
surface.face = face;
surface.ears = ears;
surface.neck = neck;
surface.shoulders = shoulders;
surface.depth = depth;
surface.nx = nx;
surface.ny = ny;
surface.nz = nz;
surface.worldsheetResponse = normalize01(abs(del2(depth)));
end

function depth = worldsheetFilter(dataDepth,cfg)
[H,W] = size(dataDepth);
[fx,fy] = meshgrid(0:W-1,0:H-1);
lambda = 4*sin(pi*fx/W).^2 + 4*sin(pi*fy/H).^2;
den = 1+cfg.stringTension*lambda+cfg.bendingWeight*lambda.^2;
depth = real(ifft2(fft2(dataDepth)./den));
end

function variation = candidateVariation(k,cfg)
t = (k-(cfg.candidateCount+1)/2)/((cfg.candidateCount-1)/2);
variation.index = k;
variation.t = t;
variation.melaninShift = 0.055*t;
variation.hemoglobinShift = 0.030*sin(k*1.7);
variation.lightYaw = 0.18*t;
variation.lightHeight = 0.05*cos(k*1.3);
variation.hairWarmth = 0.035*sin(k*0.9);
variation.irisMix = 0.5+0.35*sin(k*1.1);
variation.roughness = 0.86+0.08*cos(k*1.4);
end

function [rgb,aux] = renderColorPortrait(surface,z2,source,v,cfg)
x = surface.x; y = surface.y;
face = surface.face; ears = surface.ears;
neck = surface.neck; shoulders = surface.shoulders;

bgVignette = exp(-0.65*(x.^2+y.^2));
background = zeros(cfg.N,cfg.N,3,'single');
background(:,:,1) = 0.018+0.028*bgVignette;
background(:,:,2) = 0.026+0.040*bgVignette;
background(:,:,3) = 0.040+0.060*bgVignette;
rgbLinear = background;

clothBase = [0.035 0.050 0.078];
clothTexture = 0.80+0.20*source.structured;
for c = 1:3
    layer = rgbLinear(:,:,c);
    channel = clothBase(c)*clothTexture;
    layer(shoulders) = channel(shoulders);
    rgbLinear(:,:,c) = layer;
end

skinBase = [0.47 0.275 0.195];
skinBase = skinBase .* (1-v.melaninShift) + ...
    [0.035 0.012 0.006]*v.hemoglobinShift;
skinBase = max(skinBase,0.08);
skinTexture = 1+0.035*(z2-0.5)+0.018*source.high;

L1 = normalizeVector([-0.48+v.lightYaw -0.34+v.lightHeight 0.81]);
L2 = normalizeVector([0.55+0.4*v.lightYaw 0.05 0.83]);
L3 = normalizeVector([0.05 0.68 0.73]);
diffuse = 0.24+0.50*max(0,dotNormals(surface,L1))+ ...
    0.18*max(0,dotNormals(surface,L2))+ ...
    0.08*max(0,dotNormals(surface,L3));
halfVector = normalizeVector(L1+[0 0 1]);
specular = 0.10*max(0,dotNormals(surface,halfVector)).^(34*v.roughness);
curvatureShade = 1-0.18*surface.worldsheetResponse;
shade = clamp01(diffuse.*curvatureShade);

skinMask = face | ears | neck;
for c = 1:3
    skinChannel = skinBase(c)*skinTexture.*shade+specular;
    layer = rgbLinear(:,:,c);
    layer(skinMask) = skinChannel(skinMask);
    rgbLinear(:,:,c) = layer;
end

% Hair and beard fields are derived from the second visual forecast.
hairline = -0.50+0.055*cos(3*pi*x)+0.025*(z2-0.5);
topHairAlpha = sigmoid((hairline-y)/0.018);
sideHairAlpha = sigmoid((abs(x)-0.425)/0.020).* ...
    sigmoid((0.025-y)/0.030).*sigmoid((y+0.56)/0.030);
hairAlpha = single(face).*clamp01(max(topHairAlpha,sideHairAlpha));
hairMask = hairAlpha > 0.08;
strand = 0.55+0.45*cos(58*hypot(0.9*x,y+0.52)+ ...
    7*atan2(y+0.52,x)+4*z2);
hairBase = max([0.030 0.014 0.007]+ ...
    v.hairWarmth*[0.10 0.045 0.012],0.004);
for c = 1:3
    hairChannel = hairBase(c).*(0.62+0.38*strand).* ...
        (0.65+0.35*shade);
    rgbLinear(:,:,c) = rgbLinear(:,:,c).*(1-hairAlpha)+ ...
        hairChannel.*hairAlpha;
end

beardBoundary = 1-(x/0.455).^2-((y-0.40)/0.34).^2;
beardSupport = sigmoid(beardBoundary/0.075).* ...
    sigmoid((y-0.15)/0.045).*sigmoid((0.70-y)/0.040);
beardShape = face & beardSupport > 0.08;
beardDensity = clamp01(0.30+0.28*normalize01(source.high)+ ...
    0.18*normalize01(z2-imgaussfilt(z2,5)));
beardAlpha = single(face).*beardSupport.*beardDensity*0.42;
moustacheAlpha = 0.32*exp(-((abs(x)-0.075)/0.075).^2- ...
    ((y-0.235)/0.040).^2).*single(face);
beardAlpha = clamp01(beardAlpha+moustacheAlpha);
for c = 1:3
    rgbLinear(:,:,c) = rgbLinear(:,:,c).*(1-beardAlpha)+ ...
        hairBase(c)*(0.7+0.3*strand).*beardAlpha;
end

% Eyes, irises, pupils, lids, eyebrows, lips, and nostrils.
rgbLinear = paintEyes(rgbLinear,x,y,source,v);
rgbLinear = paintFacialDetails(rgbLinear,x,y,source,hairBase);

% Small forecast-driven pore response only inside skin.
pores = normalizeSigned(source.high-imgaussfilt(source.high,1.4));
poreGain = 1+0.018*pores.*skinMask;
rgbLinear = rgbLinear.*repmat(poreGain,1,1,3);

rgbLinear = clamp01(rgbLinear);
rgb = clamp01(rgbLinear.^(1/2.2));
aux = struct('hairMask',hairMask,'beardMask',beardShape, ...
    'skinMask',skinMask,'shade',shade,'specular',specular, ...
    'linearRGB',rgbLinear);
end

function rgb = paintEyes(rgb,x,y,source,v)
centers = [-0.185 -0.165; 0.185 -0.165];
scleraColor = [0.58 0.55 0.50];
irisA = [0.055 0.025 0.010];
irisB = [0.020 0.060 0.055];
irisColor = (1-v.irisMix)*irisA+v.irisMix*irisB;
for j = 1:2
    cx = centers(j,1); cy = centers(j,2);
    e = ((x-cx)/0.100).^2+((y-cy)/0.031).^2;
    eyeAlpha = sigmoid((1-e)/0.050);
    for c = 1:3
        rgb(:,:,c) = rgb(:,:,c).*(1-eyeAlpha)+scleraColor(c)*eyeAlpha;
    end
    iris = sigmoid((1-(((x-cx)/0.024).^2+ ...
        ((y-cy)/0.024).^2))/0.055).*eyeAlpha;
    for c = 1:3
        rgb(:,:,c) = rgb(:,:,c).*(1-iris)+irisColor(c)*iris;
    end
    pupil = sigmoid((1-(((x-cx)/0.010).^2+ ...
        ((y-cy)/0.010).^2))/0.055).*eyeAlpha;
    rgb = rgb.*(1-repmat(0.92*pupil,1,1,3));
    catchlight = exp(-((x-(cx-0.007))/0.0045).^2- ...
        ((y-(cy-0.007))/0.0045).^2).*eyeAlpha;
    rgb = rgb.*(1-repmat(0.8*catchlight,1,1,3))+ ...
        repmat(0.8*catchlight,1,1,3);
    upperLid = exp(-((x-cx)/0.108).^2-((y-(cy-0.031))/0.010).^2);
    lowerLid = exp(-((x-cx)/0.100).^2-((y-(cy+0.031))/0.009).^2);
    lid = clamp01(0.28*upperLid+0.10*lowerLid);
    rgb(:,:,1) = rgb(:,:,1).*(1-lid)+0.12*lid;
    rgb(:,:,2) = rgb(:,:,2).*(1-lid)+0.050*lid;
    rgb(:,:,3) = rgb(:,:,3).*(1-lid)+0.025*lid;
end
% Local source modulation keeps the two irises linked to the source field.
rgb = clamp01(rgb.*(0.99+0.01*repmat(source.phaseCoherence,1,1,3)));
end

function rgb = paintFacialDetails(rgb,x,y,source,hairColor)
brow = exp(-((abs(x)-0.19)/0.125).^2-((y+0.247)/0.022).^2);
brow = clamp01(brow).*0.68;
for c = 1:3
    rgb(:,:,c) = rgb(:,:,c).*(1-brow)+hairColor(c)*brow;
end

upper = exp(-(x/0.155).^2-((y-0.285)/0.026).^2);
lower = exp(-(x/0.165).^2-((y-0.330)/0.035).^2);
lipAlpha = clamp01(0.48*upper+0.58*lower);
lipBase = [0.29 0.075 0.060];
lipTexture = 0.92+0.08*source.structured;
for c = 1:3
    rgb(:,:,c) = rgb(:,:,c).*(1-lipAlpha)+ ...
        lipBase(c)*lipTexture.*lipAlpha;
end
seam = exp(-(x/0.17).^2-((y-0.307)/0.009).^2)*0.72;
rgb = rgb.*(1-repmat(seam,1,1,3)*0.65);

nostril = (exp(-((x-0.047)/0.022).^2-((y-0.108)/0.014).^2)+ ...
    exp(-((x+0.047)/0.022).^2-((y-0.108)/0.014).^2))*0.62;
rgb = rgb.*(1-repmat(clamp01(nostril),1,1,3)*0.68);

nasolabial = (exp(-((x-0.155)/0.025).^2-((y-0.19)/0.16).^2)+ ...
    exp(-((x+0.155)/0.025).^2-((y-0.19)/0.16).^2))*0.08;
rgb = rgb.*(1-repmat(nasolabial,1,1,3));
end

function m = summarizeCandidate(I,aux,index)
gray = rgb2gray(I);
mx = max(I,[],3); mn = min(I,[],3);
m.index = index;
m.mean_luminance = mean(gray,'all');
m.dynamic_range = max(gray,[],'all')-min(gray,[],'all');
m.mean_colorfulness = mean(mx-mn,'all');
m.clipped_fraction = mean(I <= 0.002 | I >= 0.998,'all');
m.skin_fraction = mean(aux.skinMask,'all');
m.hair_fraction = mean(aux.hairMask,'all');
m.beard_fraction = mean(aux.beardMask,'all');
m.finite = all(isfinite(I),'all');
end

function writeOutputs(outDir,primary,candidates,z0,z1,z2,surface,aux, ...
    source,forecast,candidateMetrics,~)
imwrite(primary,fullfile(outDir,'01_primary_color_portrait.png'));
imwrite(makeGrid(candidates,3),fullfile(outDir,'02_candidate_grid.png'));
for k = 1:size(candidates,4)
    imwrite(candidates(:,:,:,k),fullfile(outDir, ...
        sprintf('candidate_%02d.png',k)));
end
imwrite(z0,fullfile(outDir,'03_visual_state_zero.png'));
imwrite(z1,fullfile(outDir,'04_visual_forecast_first.png'));
imwrite(z2,fullfile(outDir,'05_visual_forecast_second.png'));
imwrite(normalize01(surface.depth),fullfile(outDir,'06_depth.png'));
normalRGB = clamp01(cat(3,0.5*(surface.nx+1), ...
    0.5*(surface.ny+1),0.5*(surface.nz+1)));
imwrite(normalRGB,fullfile(outDir,'07_normals.png'));
imwrite(surface.worldsheetResponse,fullfile(outDir,'08_worldsheet_response.png'));
imwrite(source.precision,fullfile(outDir,'09_precision_map.png'));

h5file = fullfile(outDir,'11_visual_of_visual_fields.h5');
writeH5(h5file,'/forecast/z0',single(z0));
writeH5(h5file,'/forecast/z1',single(z1));
writeH5(h5file,'/forecast/z2',single(z2));
writeH5(h5file,'/surface/depth',single(surface.depth));
writeH5(h5file,'/surface/normals',single(cat(3, ...
    surface.nx,surface.ny,surface.nz)));
writeH5(h5file,'/surface/face_mask',uint8(surface.face));
writeH5(h5file,'/source/precision',single(source.precision));
writeH5(h5file,'/source/structured',single(source.structured));
writeH5(h5file,'/render/primary_linear_rgb',single(aux.linearRGB));

writeJSON(fullfile(outDir,'12_forecast_diagnostics.json'),forecast);
writeJSON(fullfile(outDir,'13_candidate_metrics.json'),candidateMetrics);

formula = [ ...
    "z1 = T(z0,u0)"; ...
    "z2 = T(z1,u1)"; ...
    "T(z,u) = (I+dt*(alpha*L+beta*L^2))^-1"; ...
    "         *(z+dt*(B*u+gamma*tanh(W*z+b)+0.5*H[z,z]))"; ...
    "Ews(X) = Ts*trace(X'*Lcot*X)+kappa*norm(Lcot*X,F)^2"; ...
    "Final image selection: Yehoshua" ];
fid = fopen(fullfile(outDir,'14_equations.txt'),'w');
assert(fid >= 0,'Cannot create equation file.');
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(formula)
    fprintf(fid,'%s\n',formula(k));
end
clear cleanup
end

function metrics = validateOutputs(outDir,primary,candidates,z0,z1,z2, ...
    surface,forecast,candidateMetrics,cfg)
metrics = struct();
metrics.image_size = size(primary);
metrics.candidate_count = size(candidates,4);
metrics.primary_candidate_index = cfg.primaryCandidate;
metrics.all_finite = all(isfinite(candidates),'all') && ...
    all(isfinite(surface.depth),'all');
metrics.range_valid = min(candidates,[],'all') >= 0 && ...
    max(candidates,[],'all') <= 1;
metrics.visual_zero_first_change = mean(abs(z1-z0),'all');
metrics.visual_first_second_change = mean(abs(z2-z1),'all');
metrics.visual_zero_second_correlation = correlation01(z0,z2);
metrics.visual_first_second_correlation = correlation01(z1,z2);
metrics.face_coverage = mean(surface.face,'all');
metrics.depth_range = [min(surface.depth(surface.face)) ...
    max(surface.depth(surface.face))];
metrics.normal_unit_error = mean(abs(sqrt(surface.nx.^2+ ...
    surface.ny.^2+surface.nz.^2)-1),'all');
gray = rgb2gray(primary);
metrics.primary_dynamic_range = max(gray,[],'all')-min(gray,[],'all');
metrics.primary_colorfulness = mean(max(primary,[],3)-min(primary,[],3),'all');
metrics.primary_clipped_fraction = mean(primary <= 0.002 | ...
    primary >= 0.998,'all');
metrics.forecast = forecast;
metrics.candidates = candidateMetrics;
required = {'01_primary_color_portrait.png','02_candidate_grid.png', ...
    '03_visual_state_zero.png','04_visual_forecast_first.png', ...
    '05_visual_forecast_second.png','06_depth.png','07_normals.png', ...
    '08_worldsheet_response.png','09_precision_map.png', ...
    '11_visual_of_visual_fields.h5','12_forecast_diagnostics.json', ...
    '13_candidate_metrics.json','14_equations.txt'};
metrics.required_files_present = all(cellfun(@(f) ...
    isfile(fullfile(outDir,f)),required));
metrics.validation_pass = metrics.all_finite && metrics.range_valid && ...
    metrics.candidate_count == cfg.candidateCount && ...
    metrics.visual_zero_first_change > 1e-5 && ...
    metrics.visual_first_second_change > 1e-5 && ...
    metrics.primary_dynamic_range > 0.25 && ...
    metrics.primary_colorfulness > 0.025 && ...
    metrics.face_coverage > 0.25 && metrics.face_coverage < 0.75 && ...
    metrics.normal_unit_error < 1e-5 && metrics.required_files_present;
end

function d = dotNormals(surface,L)
d = surface.nx*L(1)+surface.ny*L(2)+surface.nz*L(3);
end

function v = normalizeVector(v)
v = v./max(norm(v),eps);
end

function [nx,ny,nz] = surfaceNormals(z,scale)
[zx,zy] = gradient(z);
nx = -scale*zx; ny = -scale*zy; nz = ones(size(z),'like',z);
n = sqrt(nx.^2+ny.^2+nz.^2)+eps;
nx = nx./n; ny = ny./n; nz = nz./n;
end

function y = sigmoid(x)
x = min(max(x,-40),40);
y = 1./(1+exp(-x));
end

function y = robust01(x)
x = double(x);
v = x(isfinite(x));
if isempty(v)
    y = zeros(size(x));
    return;
end
lo = prctile(v,1); hi = prctile(v,99);
if hi <= lo
    y = zeros(size(x));
else
    y = min(max((x-lo)/(hi-lo),0),1);
end
y(~isfinite(y)) = 0;
end

function y = normalize01(x)
x = real(single(x));
lo = min(x,[],'all'); hi = max(x,[],'all');
y = (x-lo)/(hi-lo+eps('single'));
y = clamp01(y);
end

function y = normalizeSigned(x)
x = real(single(x));
s = max(abs(x),[],'all');
y = x/(s+eps('single'));
end

function y = clamp01(x)
y = min(max(single(x),0),1);
end

function c = correlation01(a,b)
a = double(a(:)); b = double(b(:));
a = a-mean(a); b = b-mean(b);
c = (a'*b)/(norm(a)*norm(b)+eps);
end

function grid = makeGrid(images,ncol)
[H,W,C,K] = size(images);
nrow = ceil(K/ncol);
gap = 8;
grid = zeros(nrow*H+(nrow-1)*gap, ...
    ncol*W+(ncol-1)*gap,C,'like',images);
for k = 1:K
    r = floor((k-1)/ncol); c = mod(k-1,ncol);
    rr = r*(H+gap)+(1:H); cc = c*(W+gap)+(1:W);
    grid(rr,cc,:) = images(:,:,:,k);
end
end

function writeH5(file,path,data)
chunk = min(size(data),128);
if ~ismatrix(data)
    chunk(3) = min(size(data,3),3);
end
h5create(file,path,size(data),'Datatype',class(data), ...
    'ChunkSize',chunk,'Deflate',4);
h5write(file,path,data);
end

function writeJSON(file,value)
fid = fopen(file,'w');
assert(fid >= 0,'Cannot create JSON file: %s',file);
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,PrettyPrint=true),'char');
fwrite(fid,newline,'char');
clear cleanup
end

function hash = sha256File(file)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(file,'rb');
assert(fid >= 0,'Cannot open file for SHA256: %s',file);
cleanup = onCleanup(@() fclose(fid));
while true
    bytes = fread(fid,1024*1024,'*uint8');
    if isempty(bytes)
        break;
    end
    md.update(typecast(bytes,'int8'));
end
clear cleanup
d = typecast(md.digest(),'uint8');
hash = lower(reshape(dec2hex(d,2).',1,[]));
end
