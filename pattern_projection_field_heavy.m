%% pattern_projection_field_heavy.m
% שדה השלכה דפוסי דו־ממדי + time-phase + שני תהליכים על אותו מסלול
% פלטים: PNG, height map, stereo pair, MAT, JSON, OBJ textured mesh

clear; clc; close all;

%% ===================== CONFIG =====================

cfg.N          = 2200;     % כבד. אפשר 3000+ אם רוצים ממש לדחוף.
cfg.T          = 144;      % דגימות זמן לאורך המסלול
cfg.K          = 192;      % שכבות רעש/גלים
cfg.meshN      = 480;      % רשת OBJ תלת־ממדית
cfg.meshHeight = 0.18;

cfg.timestamp  = datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF');
cfg.inputImagePath = '';   
% אפשר לשים כאן נתיב לתמונת הדולר המקורית, לדוגמה:
% cfg.inputImagePath = '/MATLAB Drive/dollar_source.png';

cfg.outRoot = ['pattern_projection_field_' datestr(now,'yyyymmdd_HHMMSS')];
mkdir(cfg.outRoot);

seed = fnv1a32(cfg.timestamp);
rng(double(mod(seed, uint32(2147483647))), 'twister');

fprintf('\nOUTPUT: %s\n', cfg.outRoot);
fprintf('TIMESTAMP: %s\n', cfg.timestamp);
fprintf('N=%d | T=%d | K=%d\n\n', cfg.N, cfg.T, cfg.K);

%% ===================== GRID =====================

N = cfg.N;

x = single(linspace(-1, 1, N));
[X,Y] = meshgrid(x,x);

R  = sqrt(X.^2 + Y.^2);
TH = atan2(Y,X);

aperture = single(1 ./ (1 + exp(95 .* (R - single(0.985)))));
edgeRing = single(exp(-((R - single(0.985)).^2) ./ (2 * single(0.0045)^2)));

%% ===================== PROJECTION MAP =====================

Z0 = single(0.22 .* R.^2 + 0.045 .* sin(5 .* TH + 8 .* R));

den = single(1.14 + 0.46 .* Y + 0.12 .* X + 0.18 .* Z0);
den = max(den, single(0.32));

U = single((X + 0.18 .* Y + 0.045 .* sin(4.5 .* Y)) ./ den);
V = single((Y - 0.11 .* X + 0.045 .* cos(3.8 .* X)) ./ den);

U = single(1.18 .* U);
V = single(1.18 .* V);

%% ===================== BASE FIELD =====================

base = single( ...
    0.42 .* sin( 7.0*pi.*U + 1.7.*cos(5.2.*V) ) + ...
    0.33 .* cos( 6.2*pi.*V + 1.1.*sin(4.4.*U) ) + ...
    0.28 .* sin( 11.0.*(U.^2 + 0.82.*V.^2) + 4.2.*sin(TH) ) + ...
    0.22 .* cos( 18.0.*R + 7.0.*sin(3.*TH) ) ...
);

%% ===================== MULTI-SCALE PATTERN NOISE =====================

fprintf('building multiscale pattern medium...\n');

medium = zeros(N,N,'single');
ampSum = single(0);

for k = 1:cfg.K
    theta = single(2*pi*rand);
    freq  = single(2^(1.2 + 6.35*rand));
    amp   = single(freq^(-0.72));
    ph    = single(2*pi*rand);

    axis1 = single(cos(theta).*U + sin(theta).*V);
    axis2 = single(cos(theta + pi/2).*U + sin(theta + pi/2).*V);

    warp = single(0.23 .* sin(0.72 .* freq .* axis2 + 0.31 .* ph));
    layer = single(sin(pi .* freq .* axis1 + ph + warp));

    medium = medium + amp .* layer;
    ampSum = ampSum + abs(amp);

    if mod(k,24)==0
        fprintf('  layer %d / %d\n', k, cfg.K);
    end
end

medium = medium ./ max(ampSum, eps('single'));

%% ===================== TIME-PHASE FROM TIMESTAMP =====================

fprintf('encoding timestamp phase...\n');

codes = double(uint8(cfg.timestamp));
timePhase = zeros(N,N,'single');
phase0 = single(double(seed) / double(intmax('uint32')) * 2*pi);

for c = 1:numel(codes)
    a = single(2*pi*(c-1)/numel(codes) + 0.37*phase0);
    q = single(cos(a).*U + sin(a).*V);

    localFreq = single(7.0 + 0.18 .* codes(c));
    offset    = single(-0.42 + 0.84*(c-1)/max(1,numel(codes)-1));
    sigma     = single(0.09 + 0.015*sin(c));

    gate = single(exp(-((q - offset).^2) ./ (2*sigma^2)));
    band = single(sin(localFreq .* q + phase0 + single(0.073*c)));

    weight = single((codes(c) - 64) / 128);
    timePhase = timePhase + weight .* gate .* band;
end

timePhase = normalize01_signed(timePhase);

%% ===================== TWO COMPUTATIONAL PROCESSES ON SAME PATH =====================

fprintf('accumulating two path processes...\n');

A_direct = zeros(N,N,'single');
A_view   = zeros(N,N,'single');
trail    = zeros(N,N,'single');
phaseFlow = zeros(N,N,'single');

for i = 1:cfg.T
    s = single((i-1) / max(1,cfg.T-1));

    gx = single(-0.82 + 1.64*s + 0.11*sin(2*pi*s + 0.4));
    gy = single( 0.38*sin(2*pi*s - 0.72) + 0.16*cos(4*pi*s + 0.3));

    dxdt = single(1.64 + 0.11*2*pi*cos(2*pi*s + 0.4));
    dydt = single(0.38*2*pi*cos(2*pi*s - 0.72) - 0.16*4*pi*sin(4*pi*s + 0.3));
    ang  = single(atan2(dydt, dxdt));

    % שכבת צפייה: אותו מסלול, עם שינוי הקרנה/זמן קטן
    vx = single(gx + 0.038*sin(2*pi*s + phase0) + 0.014*cos(9*pi*s));
    vy = single(gy + 0.030*cos(2*pi*s + phase0) - 0.012*sin(7*pi*s));

    sig1 = single(0.018 + 0.022*(0.5 + 0.5*sin(2*pi*s + 0.6)));
    sig2 = single(1.22 * sig1);

    du1 = U - gx;  dv1 = V - gy;
    du2 = U - vx;  dv2 = V - vy;

    d1 = du1.^2 + dv1.^2;
    d2 = du2.^2 + dv2.^2;

    spot1 = single(exp(-d1 ./ (2*sig1^2)));
    spot2 = single(exp(-d2 ./ (2*sig2^2)));

    p1 = single( du1.*cos(ang) + dv1.*sin(ang));
    q1 = single(-du1.*sin(ang) + dv1.*cos(ang));

    p2 = single( du2.*cos(ang + 0.035*sin(12*s)) + dv2.*sin(ang + 0.035*sin(12*s)));
    q2 = single(-du2.*sin(ang + 0.035*sin(12*s)) + dv2.*cos(ang + 0.035*sin(12*s)));

    carrier1 = single(0.72 + 0.28*cos(78*p1 + 13*pi*s + phase0));
    carrier2 = single(0.72 + 0.28*cos(78*p2 + 13*pi*s + phase0 + 0.31));

    A_direct = A_direct + spot1 .* carrier1;
    A_view   = A_view   + spot2 .* carrier2;

    ridge = single(exp(-(q1.^2)./(2*(sig1*0.55)^2)) .* exp(-(p1.^2)./(2*single(0.21)^2)));
    trail = trail + single(0.62) .* ridge .* single(cos(96*p1 + 16*pi*s + phase0));

    flowGate = single(exp(-(d1)./(2*single(0.19)^2)));
    phaseFlow = phaseFlow + flowGate .* single(sin(24*R + 7*TH + 21*s + phase0));

    if mod(i,18)==0
        fprintf('  time sample %d / %d\n', i, cfg.T);
    end
end

A_direct = normalize01(A_direct, 0.20, 99.85);
A_view   = normalize01(A_view,   0.20, 99.85);
trail    = normalize01_signed(trail);
phaseFlow = normalize01_signed(phaseFlow);

attention = normalize01( ...
    single(0.76.*A_direct + 0.92.*A_view + 0.64.*abs(A_direct - A_view)), ...
    0.25, 99.88 ...
);

%% ===================== OPTIONAL SOURCE IMAGE BLEND =====================

sourceTerm = zeros(N,N,'single');

if ~isempty(cfg.inputImagePath) && isfile(cfg.inputImagePath)
    fprintf('reading source image: %s\n', cfg.inputImagePath);
    sourceImg = readGray01(cfg.inputImagePath);
    sourceImg = resize2single(sourceImg, N, N);
    sourceImg = normalize01(sourceImg, 1.0, 99.0);
    sourceTerm = single(2 .* sourceImg - 1);
else
    fprintf('no external source image path supplied. generating standalone field.\n');
end

%% ===================== FINAL FIELD =====================

fprintf('combining final field...\n');

field = single( ...
    0.34 .* base + ...
    0.46 .* medium + ...
    0.38 .* timePhase + ...
    1.12 .* attention + ...
    0.36 .* trail + ...
    0.22 .* phaseFlow + ...
    0.28 .* sourceTerm + ...
    0.14 .* sourceTerm .* attention ...
);

field = single(field .* aperture - 0.92 .* (1 - aperture));
field = field + single(0.22 .* edgeRing);

fieldNorm = normalize01(field, 0.35, 99.72);
fieldNorm = single(fieldNorm .^ 0.86);

%% ===================== COLOR RENDER =====================

fprintf('rendering RGB texture...\n');

try
    cmap = turbo(4096);
catch
    cmap = parula(4096);
end

idx = uint16(floor(double(fieldNorm) * (size(cmap,1)-1)) + 1);

RGB = zeros(N,N,3,'single');
RGB(:,:,1) = reshape(single(cmap(idx(:),1)), N, N);
RGB(:,:,2) = reshape(single(cmap(idx(:),2)), N, N);
RGB(:,:,3) = reshape(single(cmap(idx(:),3)), N, N);
% local contrast shaping
[gx, gy] = gradient(fieldNorm);
gradMag = normalize01(single(sqrt(gx.^2 + gy.^2)), 0.30, 99.5);
shade = single(0.72 + 0.34 .* gradMag);

RGB(:,:,1) = RGB(:,:,1) .* shade;
RGB(:,:,2) = RGB(:,:,2) .* shade;
RGB(:,:,3) = RGB(:,:,3) .* shade;

RGB(:,:,1) = min(single(1), RGB(:,:,1) + single(0.16).*edgeRing);
RGB(:,:,2) = min(single(1), RGB(:,:,2) + single(0.05).*edgeRing);
RGB(:,:,3) = min(single(1), RGB(:,:,3) + single(0.01).*edgeRing);

RGB(:,:,1) = RGB(:,:,1) .* aperture;
RGB(:,:,2) = RGB(:,:,2) .* aperture;
RGB(:,:,3) = RGB(:,:,3) .* aperture;

RGB = max(single(0), min(single(1), RGB));

%% ===================== SAVE 2D OUTPUTS =====================

textureFile = fullfile(cfg.outRoot, 'pattern_projection_field_texture.png');
grayFile    = fullfile(cfg.outRoot, 'pattern_projection_field_gray.png');
heightFile  = fullfile(cfg.outRoot, 'pattern_projection_field_height_16bit.png');
matFile     = fullfile(cfg.outRoot, 'pattern_projection_field_raw.mat');
jsonFile    = fullfile(cfg.outRoot, 'pattern_projection_field_metadata.json');
stereoFile  = fullfile(cfg.outRoot, 'pattern_projection_field_stereo_pair.png');

imwrite(RGB, textureFile);
imwrite(uint16(fieldNorm * 65535), heightFile);
imwrite(uint16(normalize01(field, 0.35, 99.72) * 65535), grayFile);

shiftPx = round(0.012 * N);
leftEye  = circshift(RGB, [0, -shiftPx]);
rightEye = circshift(RGB, [0,  shiftPx]);
stereoPair = cat(2, leftEye, rightEye);
imwrite(stereoPair, stereoFile);

save(matFile, ...
    'cfg', 'field', 'fieldNorm', 'attention', 'A_direct', 'A_view', ...
    'medium', 'timePhase', 'trail', 'phaseFlow', ...
    '-v7.3');

meta = struct();
meta.timestamp = cfg.timestamp;
meta.seed = double(seed);
meta.N = cfg.N;
meta.T = cfg.T;
meta.K = cfg.K;
meta.meshN = cfg.meshN;
meta.inputImagePath = cfg.inputImagePath;
meta.outputs.texture = textureFile;
meta.outputs.height16 = heightFile;
meta.outputs.gray = grayFile;
meta.outputs.stereoPair = stereoFile;
meta.outputs.mat = matFile;
meta.model = 'I(x,y,t) -> projected pattern field -> texture/height/stereo/mesh';
meta.processA = 'direct path sample';
meta.processB = 'same path with projection-time offset';

fid = fopen(jsonFile, 'w');
fwrite(fid, jsonencode(meta, 'PrettyPrint', true), 'char');
fclose(fid);

%% ===================== TEXTURED OBJ MESH =====================

fprintf('writing textured OBJ mesh...\n');

meshN = cfg.meshN;
meshIdx = round(linspace(1,N,meshN));
Zmesh = fieldNorm(meshIdx, meshIdx);
Zmesh = single(cfg.meshHeight .* (Zmesh - 0.5));

objFile = fullfile(cfg.outRoot, 'pattern_projection_field_mesh.obj');
mtlFile = fullfile(cfg.outRoot, 'pattern_projection_field_mesh.mtl');

copyfile(textureFile, fullfile(cfg.outRoot, 'pattern_projection_field_mesh_texture.png'));
writeTexturedObj(objFile, mtlFile, Zmesh, 'pattern_projection_field_mesh_texture.png');

%% ===================== PREVIEW =====================

figure('Color','k','Name','Pattern Projection Field');
imshow_fallback(RGB);
title('pattern projection field', 'Color','w');

fprintf('\nDONE.\n');
fprintf('Texture: %s\n', textureFile);
fprintf('Height : %s\n', heightFile);
fprintf('Stereo : %s\n', stereoFile);
fprintf('OBJ    : %s\n', objFile);
fprintf('MAT    : %s\n', matFile);
fprintf('JSON   : %s\n\n', jsonFile);

%% ===================== LOCAL FUNCTIONS =====================

function h = fnv1a32(s)
    h = uint32(2166136261);
    prime = uint64(16777619);
    modv  = uint64(4294967296);
    bytes = uint8(s);
    for ii = 1:numel(bytes)
        h = bitxor(h, uint32(bytes(ii)));
        h = uint32(mod(uint64(h) * prime, modv));
    end
end

function B = normalize01(A, pLow, pHigh)
    A = single(A);
    v = double(A(:));

    maxSamples = 1500000;
    if numel(v) > maxSamples
        ids = round(linspace(1, numel(v), maxSamples));
        v = v(ids);
    end

    v = sort(v);
    n = numel(v);

    iLow  = max(1, min(n, round((pLow/100)  * (n-1)) + 1));
    iHigh = max(1, min(n, round((pHigh/100) * (n-1)) + 1));

    lo = v(iLow);
    hi = v(iHigh);

    if abs(hi-lo) < eps
        B = zeros(size(A), 'single');
    else
        B = single((double(A) - lo) ./ (hi - lo));
        B = max(single(0), min(single(1), B));
    end
end

function B = normalize01_signed(A)
    A = single(A);
    m = mean(double(A(:)));
    A = single(double(A) - m);

    v = double(abs(A(:)));
    maxSamples = 1200000;
    if numel(v) > maxSamples
        ids = round(linspace(1, numel(v), maxSamples));
        v = v(ids);
    end

    v = sort(v);
    n = numel(v);
    s = v(max(1, min(n, round(0.985*(n-1))+1)));
    if s < eps
        B = zeros(size(A), 'single');
    else
        B = single(double(A) ./ s);
        B = max(single(-1), min(single(1), B));
    end
end

function I = readGray01(path)
    raw = imread(path);

    if isa(raw,'uint8')
        raw = double(raw) ./ 255;
    elseif isa(raw,'uint16')
        raw = double(raw) ./ 65535;
    else
        raw = double(raw);
        raw = raw ./ max(eps, max(raw(:)));
    end

    if ndims(raw) == 3
        I = 0.299 .* raw(:,:,1) + 0.587 .* raw(:,:,2) + 0.114 .* raw(:,:,3);
    else
        I = raw;
    end

    I = single(max(0,min(1,I)));
end

function B = resize2single(A, newH, newW)
    A = single(A);
    [h,w] = size(A);
    [Xq,Yq] = meshgrid(linspace(1,w,newW), linspace(1,h,newH));
    B = interp2(double(A), Xq, Yq, 'linear', 0);
    B = single(B);
end

function writeTexturedObj(objFile, mtlFile, Z, texName)
    n = size(Z,1);
    [X,Y] = meshgrid(linspace(-1,1,n), linspace(-1,1,n));

    [~,mtlBase,mtlExt] = fileparts(mtlFile);
    mtlName = [mtlBase mtlExt];

    fid = fopen(mtlFile, 'w');
    fprintf(fid, 'newmtl material0\n');
    fprintf(fid, 'Ka 1.000 1.000 1.000\n');
    fprintf(fid, 'Kd 1.000 1.000 1.000\n');
    fprintf(fid, 'Ks 0.000 0.000 0.000\n');
    fprintf(fid, 'd 1.0\n');
    fprintf(fid, 'illum 2\n');
    fprintf(fid, 'map_Kd %s\n', texName);
    fclose(fid);

    fid = fopen(objFile, 'w');
    fprintf(fid, 'mtllib %s\n', mtlName);
    fprintf(fid, 'usemtl material0\n');

    for i = 1:n
        for j = 1:n
            fprintf(fid, 'v %.8f %.8f %.8f\n', X(i,j), Y(i,j), Z(i,j));
        end
    end

    for i = 1:n
        v = 1 - (i-1)/(n-1);
        for j = 1:n
            u = (j-1)/(n-1);
            fprintf(fid, 'vt %.8f %.8f\n', u, v);
        end
    end

    for i = 1:n-1
        for j = 1:n-1
            a = (i-1)*n + j;
            b = a + 1;
            c = i*n + j + 1;
            d = i*n + j;

            fprintf(fid, 'f %d/%d %d/%d %d/%d\n', a,a, b,b, c,c);
            fprintf(fid, 'f %d/%d %d/%d %d/%d\n', a,a, c,c, d,d);
        end
    end

    fclose(fid);
end

function imshow_fallback(RGB)
    image(RGB);
    axis image off;
end