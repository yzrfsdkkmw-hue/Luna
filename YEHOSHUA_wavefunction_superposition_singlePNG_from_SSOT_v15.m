function YEHOSHUA_wavefunction_superposition_singlePNG_from_SSOT_v15()
% YEHOSHUA_wavefunction_superposition_singlePNG_from_SSOT_v15
%
% PURPOSE:
%   Build one single PNG only.
%   The PNG should look like a compressed short video / long temporal phase signature
%   of a wave-function superposition.
%
% MAIN OUTPUT:
%   yehoshua_v15_wave_a01_wavefunction_temporal_singlepng.png
%
% OPTIONAL:
%   You may set SAVE_MAT = true if you also want a .mat pack for inspection.
%
% SOURCE OF TRUTH:
%   /MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%   dataset: /n_5_composite_field_1000x1000/data
%
% STATUS:
%   Draft only. Not executed here.

    clc;
    close all;

    %% ============================================================
    % 0) User-tunable parameters
    % =============================================================
    SAVE_MAT = false;        % set true only if you want the numeric layers too

    cfg.ssot_h5 = '/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
    cfg.dataset = '/n_5_composite_field_1000x1000/data';

    cfg.N = 1024;            % canvas height
    cfg.M = 1024;            % canvas width

    cfg.T = 360;             % temporal length: higher = longer signature
    cfg.omega1 = 0.30;       % phase speed 1
    cfg.omega2 = -0.27;      % phase speed 2

    cfg.out_png = 'yehoshua_v15_wave_a01_wavefunction_temporal_singlepng.png';
    cfg.out_mat = 'yehoshua_v15_wave_a01_wavefunction_temporal_singlepng_pack.mat';

    %% ============================================================
    % 1) Read canonical SSOT only
    % =============================================================
    if ~isfile(cfg.ssot_h5)
        error('SSOT file not found: %s', cfg.ssot_h5);
    end

    raw = h5read(cfg.ssot_h5, cfg.dataset);
    field2d = local_make_2d_field(raw);

    if isempty(field2d) || ~ismatrix(field2d)
        error('Could not derive a usable 2D field from SSOT.');
    end

    field2d = double(field2d);
    field2d = local_normalize01(field2d);
    field2d = imresize(field2d, [cfg.N cfg.M], 'bicubic');
    field2d = local_normalize01(field2d);

    %% ============================================================
    % 2) Coordinates
    % =============================================================
    x = linspace(-1,1,cfg.M);
    y = linspace(-1,1,cfg.N);
    [X,Y] = meshgrid(x,y);

    %% ============================================================
    % 3) Multi-scale signatures from SSOT
    % =============================================================
    f_smooth = imgaussfilt(field2d, 22);
    f_mid    = imgaussfilt(field2d, 8);
    f_fine   = field2d - imgaussfilt(field2d, 2.0);

    f_smooth = local_normalize01(f_smooth);
    f_mid    = local_normalize01(f_mid);
    f_fine   = local_normalize01(f_fine);

    sig1 = mean(f_mid, 1);
    sig1 = smoothdata(sig1, 'gaussian', 71);
    sig1 = local_normalize01(sig1);
    sig1 = 2*sig1 - 1;

    sig2 = std(f_mid, 0, 1);
    sig2 = smoothdata(sig2, 'gaussian', 81);
    sig2 = local_normalize01(sig2);
    sig2 = 2*sig2 - 1;

    sig3 = gradient(sig1);
    sig3 = smoothdata(sig3, 'gaussian', 61);
    sig3 = local_normalize01(sig3);
    sig3 = 2*sig3 - 1;

    SIG1 = repmat(sig1, cfg.N, 1);
    SIG2 = repmat(sig2, cfg.N, 1);
    SIG3 = repmat(sig3, cfg.N, 1);

    %% ============================================================
    % 4) Build two structured wave packets
    % =============================================================
    % Centerlines: curved + SSOT-driven
    y1 =  0.34*sin(2.4*X + 0.38*SIG1) ...
        - 0.18*X ...
        + 0.11*SIG2 ...
        + 0.05*cos(2.6*X - 0.7*Y);

    y2 = -0.30*sin(2.1*X - 0.28*SIG1 + 0.55) ...
        + 0.16*X ...
        - 0.10*SIG3 ...
        + 0.04*sin(2.3*X + 0.9*Y);

    d1 = abs(Y - y1);
    d2 = abs(Y - y2);

    s1 = 0.13 + 0.06*(0.5 + 0.5*SIG2);
    s2 = 0.13 + 0.06*(0.5 + 0.5*SIG1);

    A1 = exp(-(d1.^2) ./ (2*s1.^2));
    A2 = exp(-(d2.^2) ./ (2*s2.^2));

    % Amplify with SSOT field signatures
    A1 = A1 .* (0.62 + 0.58*f_smooth + 0.24*abs(f_fine));
    A2 = A2 .* (0.60 + 0.54*f_mid    + 0.22*abs(f_fine));

    A1 = local_normalize01(A1);
    A2 = local_normalize01(A2);

    %% ============================================================
    % 5) Temporal accumulation
    %    One final PNG only; time is compressed into the image
    % =============================================================
    rho_sum    = zeros(cfg.N, cfg.M);
    rho_sum2   = zeros(cfg.N, cfg.M);
    rho_max    = zeros(cfg.N, cfg.M);
    inter_sum  = zeros(cfg.N, cfg.M);
    trail_acc  = zeros(cfg.N, cfg.M);
    phase_acc  = complex(zeros(cfg.N, cfg.M));
    pulse_acc  = zeros(cfg.N, cfg.M);

    for k = 1:cfg.T
        tau = (k-1) / max(cfg.T-1,1);     % normalized time in [0,1]
        t = 2*pi*tau;

        % Stronger temporal breathing / living modulation
        breathe1 = 0.80 + 0.20*sin(2.0*t + 3.2*X);
        breathe2 = 0.80 + 0.20*cos(1.7*t - 2.8*Y);

        % Time-dependent phases
        theta1 = ...
              7.2*X ...
            + 2.6*Y ...
            + 3.4*SIG1 ...
            + 1.2*sin(3.0*X + 0.85*t) ...
            + 1.1*cos(2.4*Y - 0.50*t) ...
            + 1.6*f_smooth .* sin(1.6*t + 3.0*X) ...
            + 1.1*f_mid    .* cos(1.1*t - 2.2*Y) ...
            + cfg.omega1 * 18 * t;

        theta2 = ...
             -6.3*X ...
             +2.1*Y ...
             -3.0*SIG2 ...
             +1.4*cos(2.8*X - 0.55*t) ...
             -1.2*sin(2.3*Y + 0.75*t) ...
             +1.7*f_mid    .* cos(1.3*t - 2.6*X) ...
             +1.0*f_smooth .* sin(1.0*t + 2.9*Y) ...
             +cfg.omega2 * 18 * t;

        psi1 = (A1 .* breathe1) .* exp(1i * theta1);
        psi2 = (A2 .* breathe2) .* exp(1i * theta2);

        psi_total = psi1 + psi2;

        rho   = abs(psi_total).^2;
        inter = 2*real(conj(psi1).*psi2);
        phi   = angle(psi_total);

        rho_sum   = rho_sum  + rho;
        rho_sum2  = rho_sum2 + rho.^2;
        rho_max   = max(rho_max, rho);
        inter_sum = inter_sum + inter;

        % Long temporal trail: later frames receive more weight
        w = (tau)^1.6;
        trail_acc = trail_acc + (0.35 + 1.25*w) * local_normalize01(rho);

        % Weighted phase memory
        phase_acc = phase_acc + exp(1i*phi) .* (0.25 + 0.75*local_normalize01(rho));

        % Pulse accumulation for "alive" hotspots
        pulse_acc = pulse_acc + local_normalize01(abs(psi1) + abs(psi2));
    end

    %% ============================================================
    % 6) Derived maps
    % =============================================================
    rho_mean = rho_sum / cfg.T;
    rho_std  = sqrt(max(rho_sum2 / cfg.T - rho_mean.^2, 0));
    inter_mean = inter_sum / cfg.T;

    rho_mean = local_normalize01(rho_mean);
    rho_std  = local_normalize01(rho_std);
    rho_max  = local_normalize01(rho_max);
    trail_map = local_normalize01(trail_acc);
    pulse_map = local_normalize01(pulse_acc);

    phase_map = angle(phase_acc);

    inter_norm = inter_mean;
    inter_norm = inter_norm / (max(abs(inter_norm(:))) + eps);   % [-1,1]

    %% ============================================================
    % 7) Build one "single PNG with long temporal phase signature"
    % =============================================================
    % Value / brightness:
    % more weight to trail_map so it feels like compressed time
    V = ...
        0.20 * rho_mean + ...
        0.18 * rho_max  + ...
        0.24 * rho_std  + ...
        0.38 * trail_map + ...
        0.10 * pulse_map;

    V = local_normalize01(V);
    V = V .^ 0.86;

    % Hue from phase + interference
    H = mod((phase_map + pi)/(2*pi) + 0.10*inter_norm + 0.05*pulse_map, 1);

    % Saturation from temporal richness
    S = 0.34 + 0.66 * local_normalize01(0.52*rho_std + 0.28*abs(inter_norm) + 0.20*trail_map);
    S = min(max(S,0),1);

    img_hsv = hsv2rgb(cat(3,H,S,V));

    % Add heat-style layer
    heat = ind2rgb(uint8(255*V), turbo(256));

    % Blend both
    img = 0.48 * img_hsv + 0.52 * heat;

    % Strong glow
    glow = imgaussfilt(local_normalize01(0.52*rho_max + 0.48*trail_map), 1.6);
    img(:,:,1) = min(1, img(:,:,1) + 0.22*glow);
    img(:,:,2) = min(1, img(:,:,2) + 0.10*glow);
    img(:,:,3) = min(1, img(:,:,3) + 0.08*glow);

    % Dark background / vivid finish
    bg = local_normalize01(1 - V);
    bg = bg .^ 1.6;
    for c = 1:3
        img(:,:,c) = img(:,:,c) .* (0.80 + 0.20*(1-bg));
    end

    % Slight sharpened energy from fine structure
    fine_boost = imgaussfilt(local_normalize01(abs(f_fine)), 0.8);
    img(:,:,1) = min(1, img(:,:,1) + 0.06*fine_boost);
    img(:,:,2) = min(1, img(:,:,2) + 0.03*fine_boost);

    img = local_normalize01_rgb(img);
    img_uint8 = uint8(255 * img);

    %% ============================================================
    % 8) Save only the single PNG
    % =============================================================
    imwrite(img_uint8, cfg.out_png);

    %% ============================================================
    % 9) Optional numeric pack
    % =============================================================
    if SAVE_MAT
        metadata = struct();
        metadata.ssot_h5 = cfg.ssot_h5;
        metadata.dataset = cfg.dataset;
        metadata.canvas = [cfg.N cfg.M];
        metadata.T = cfg.T;
        metadata.omega1 = cfg.omega1;
        metadata.omega2 = cfg.omega2;
        metadata.description = 'Single-PNG temporal wavefunction superposition';

        save(cfg.out_mat, ...
            'A1','A2', ...
            'rho_mean','rho_std','rho_max', ...
            'trail_map','pulse_map', ...
            'phase_map','inter_mean','inter_norm', ...
            'img_uint8','metadata', '-v7.3');
    end

    fprintf('Done.\n');
    fprintf('Saved PNG:\n  %s\n', cfg.out_png);
    if SAVE_MAT
        fprintf('Saved MAT:\n  %s\n', cfg.out_mat);
    end
end

%% ========================================================================
function field2d = local_make_2d_field(raw)
    arr = double(raw);
    dims = size(arr);

    switch ndims(arr)
        case 2
            field2d = arr;

        case 3
            if dims(3) <= 4
                field2d = mean(arr, 3);
            elseif dims(1) <= 4
                field2d = squeeze(mean(arr, 1));
            else
                k = round(dims(3)/2);
                field2d = arr(:,:,k);
            end

        otherwise
            vec = arr(:);
            L = numel(vec);
            side = floor(sqrt(L));
            side = max(side, 256);
            usable = min(L, side*side);
            field2d = reshape(vec(1:usable), side, side);
    end

    if min(size(field2d)) < 32
        vec = arr(:);
        L = numel(vec);
        side = floor(sqrt(L));
        usable = side * side;
        field2d = reshape(vec(1:usable), side, side);
    end

    field2d(~isfinite(field2d)) = 0;
end

%% ========================================================================
function a = local_normalize01(a)
    a = double(a);
    a(~isfinite(a)) = 0;
    mn = min(a(:));
    mx = max(a(:));
    if mx <= mn
        a = zeros(size(a));
    else
        a = (a - mn) / (mx - mn);
    end
end

%% ========================================================================
function img = local_normalize01_rgb(img)
    img = double(img);
    mn = min(img(:));
    mx = max(img(:));
    if mx <= mn
        img = zeros(size(img));
    else
        img = (img - mn) / (mx - mn);
    end
end