function YEHOSHUA_wave_function_living_from_SSOT_v15()
% YEHOSHUA_wave_function_living_from_SSOT_v15
% Generates living 2D wave-function style images from canonical SSOT only.
%
% Canonical rule:
% Read only from the verified SSOT H5 (or same folder if needed).
%
% Outputs:
%   - wave_living_variant_01.png
%   - wave_living_variant_02.png
%   - wave_living_variant_03.png
%   - wave_living_contact_sheet.png
%
% Style goals:
%   - vivid central wave/ridge
%   - smooth energetic glow
%   - high contrast
%   - "alive" modulation
%   - close in feeling to prior YEHOSHUA visual language

    clc;
    close all;

    %% ============================================================
    % 0) Canonical SSOT
    % =============================================================
    ssot_h5 = '/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
    dataset_path = '/n_5_composite_field_1000x1000/data';

    if ~isfile(ssot_h5)
        error('SSOT H5 not found: %s', ssot_h5);
    end

    info = h5info(ssot_h5, dataset_path);
    sz = info.Dataspace.Size;

    fprintf('SSOT dataset size: %s\n', mat2str(sz));

    %% ============================================================
    % 1) Read SSOT safely and convert to a usable 2D field
    % =============================================================
    raw = h5read(ssot_h5, dataset_path);

    field2d = local_make_2d_field(raw);

    if isempty(field2d) || ~ismatrix(field2d)
        error('Could not derive a usable 2D numeric field from SSOT.');
    end

    field2d = double(field2d);
    field2d = local_normalize01(field2d);

    % Resize to working canvas
    N = 768;
    M = 768;
    field2d = imresize(field2d, [N M], 'bicubic');
    field2d = local_normalize01(field2d);

    %% ============================================================
    % 2) Build "living modulation" from SSOT
    % =============================================================
    % Smooth / medium / fine structure
    f_smooth = imgaussfilt(field2d, 18);
    f_mid    = imgaussfilt(field2d, 7);
    f_fine   = field2d - imgaussfilt(field2d, 2.0);

    f_smooth = local_normalize01(f_smooth);
    f_mid    = local_normalize01(f_mid);
    f_fine   = local_normalize01(f_fine);

    % Horizontal modulation signal extracted from SSOT
    mod_signal = mean(f_mid, 1);
    mod_signal = smoothdata(mod_signal, 'gaussian', 41);
    mod_signal = local_normalize01(mod_signal);
    mod_signal = 2*mod_signal - 1;  % now roughly [-1,1]

    % A second signal for width / halo breathing
    mod_signal2 = mean(f_smooth, 1);
    mod_signal2 = smoothdata(mod_signal2, 'gaussian', 71);
    mod_signal2 = local_normalize01(mod_signal2);

    %% ============================================================
    % 3) Coordinates
    % =============================================================
    x = linspace(0,1,M);
    y = linspace(0,1,N);
    [X,Y] = meshgrid(x,y);

    %% ============================================================
    % 4) Generate variants
    % =============================================================
    img1 = local_variant_slanted(X,Y,mod_signal,mod_signal2,f_smooth,f_fine);
    img2 = local_variant_bowl_blue(X,Y,mod_signal,mod_signal2,f_smooth,f_fine);
    img3 = local_variant_bowl_cyan(X,Y,mod_signal,mod_signal2,f_smooth,f_fine);

    %% ============================================================
    % 5) Save outputs
    % =============================================================
    out_dir = pwd;

    imwrite(img1, fullfile(out_dir, 'wave_living_variant_01.png'));
    imwrite(img2, fullfile(out_dir, 'wave_living_variant_02.png'));
    imwrite(img3, fullfile(out_dir, 'wave_living_variant_03.png'));

    % Contact sheet
    contact = uint8(255 * ones(N, 3*M + 20, 3));
    contact(:,1:M,:) = img1;
    contact(:,M+11:2*M+10,:) = img2;
    contact(:,2*M+21:3*M+20,:) = img3;
    imwrite(contact, fullfile(out_dir, 'wave_living_contact_sheet.png'));

    fprintf('Done.\nSaved:\n');
    fprintf('  %s\n', fullfile(out_dir, 'wave_living_variant_01.png'));
    fprintf('  %s\n', fullfile(out_dir, 'wave_living_variant_02.png'));
    fprintf('  %s\n', fullfile(out_dir, 'wave_living_variant_03.png'));
    fprintf('  %s\n', fullfile(out_dir, 'wave_living_contact_sheet.png'));
end

%% ========================================================================
function field2d = local_make_2d_field(raw)
% Convert SSOT content into a usable 2D field.
% Keeps things robust across common shapes.

    arr = double(raw);
    dims = size(arr);

    switch ndims(arr)
        case 2
            field2d = arr;

        case 3
            % Common case: H x W x C or C x H x W
            if dims(3) <= 4
                field2d = mean(arr, 3);
            elseif dims(1) <= 4
                field2d = squeeze(mean(arr, 1));
            else
                % fallback: take middle slice over 3rd dim
                k = round(dims(3)/2);
                field2d = arr(:,:,k);
            end

        otherwise
            % Flatten higher dimensions into a 2D slice if possible
            vec = arr(:);
            L = numel(vec);
            side = floor(sqrt(L));
            side = max(side, 256);
            usable = min(L, side*side);
            field2d = reshape(vec(1:usable), side, side);
    end

    % If field is too thin or degenerate, try rescue
    if min(size(field2d)) < 32
        vec = arr(:);
        L = numel(vec);
        side = floor(sqrt(L));
        usable = side*side;
        field2d = reshape(vec(1:usable), side, side);
    end

    field2d = double(field2d);
    field2d(~isfinite(field2d)) = 0;
end

%% ========================================================================
function img = local_variant_slanted(X,Y,mod_signal,mod_signal2,f_smooth,f_fine)
% Variant 1: slanted "living wave channel"

    [N,M] = size(X);
    x = X(1,:);

    % Central path
    y0 = 0.28 + 0.48*x ...
       + 0.055*sin(2*pi*(0.85*x + 0.15)) ...
       - 0.065*exp(-((x-0.18).^2)/(2*0.07^2)) ...
       + 0.040*exp(-((x-0.62).^2)/(2*0.09^2));

    % SSOT modulation
    y0 = y0 + 0.040*mod_signal;

    % local width / breathing
    sigma_core = 0.020 + 0.010*mod_signal2;
    sigma_halo = 0.050 + 0.018*(1-mod_signal2);

    Y0 = repmat(y0, N, 1);
    S1 = repmat(sigma_core, N, 1);
    S2 = repmat(sigma_halo, N, 1);

    D = abs(Y - Y0);

    core = exp(-(D.^2) ./ (2*S1.^2));
    halo = exp(-(D.^2) ./ (2*S2.^2));

    % Local energy pulses along the path
    pulse = 0.85 ...
          + 0.50*exp(-((x-0.10).^2)/(2*0.030^2)) ...
          + 0.55*exp(-((x-0.64).^2)/(2*0.060^2)) ...
          + 0.30*exp(-((x-0.83).^2)/(2*0.040^2));

    pulse = pulse .* (1 + 0.15*mod_signal);
    pulse = repmat(pulse, N, 1);

    % Background
    bg = 0.06 + 0.06*(1-Y).^1.3 + 0.08*f_smooth;

    % Fine "alive" shimmer near the ridge
    shimmer_mask = exp(-(D.^2)/(2*(0.085)^2));
    shimmer = 0.10 * (2*f_fine - 1) .* shimmer_mask;

    F = bg + 1.65*core.*pulse + 0.55*halo + shimmer;
    F = local_normalize01(F);

    img = ind2rgb(uint8(255*F), turbo(256));
    img = local_post_glow(img, core, halo);
end

%% ========================================================================
function img = local_variant_bowl_blue(X,Y,mod_signal,mod_signal2,f_smooth,f_fine)
% Variant 2: blue bowl / U-shaped wave

    [N,M] = size(X);
    x = X(1,:);

    y0 = 0.24 + 1.95*(x - 0.50).^2;
    y0 = y0 + 0.020*mod_signal .* exp(-((x-0.5).^2)/(2*0.28^2));

    sigma_core = 0.018 + 0.008*mod_signal2;
    sigma_halo = 0.045 + 0.014*(1-mod_signal2);

    Y0 = repmat(y0, N, 1);
    S1 = repmat(sigma_core, N, 1);
    S2 = repmat(sigma_halo, N, 1);

    D = abs(Y - Y0);

    core = exp(-(D.^2) ./ (2*S1.^2));
    halo = exp(-(D.^2) ./ (2*S2.^2));

    pulse = 1.05 + 0.10*cos(2*pi*x) + 0.12*mod_signal;
    pulse = repmat(pulse, N, 1);

    bg = 0.10 + 0.26*Y + 0.02*(1-X) + 0.04*f_smooth;

    shimmer_mask = exp(-(D.^2)/(2*(0.075)^2));
    shimmer = 0.08 * (2*f_fine - 1) .* shimmer_mask;

    F = bg + 1.80*core.*pulse + 0.50*halo + shimmer;
    F = local_normalize01(F);

    img = ind2rgb(uint8(255*F), turbo(256));
    img = local_post_glow(img, core, halo);
end

%% ========================================================================
function img = local_variant_bowl_cyan(X,Y,mod_signal,mod_signal2,f_smooth,f_fine)
% Variant 3: cyan-green bowl / more "alive"

    [N,M] = size(X);
    x = X(1,:);

    y0 = 0.26 + 1.82*(x - 0.48).^2;
    y0 = y0 + 0.018*sin(2*pi*(1.3*x + 0.07)) .* exp(-((x-0.5).^2)/(2*0.30^2));
    y0 = y0 + 0.018*mod_signal;

    sigma_core = 0.019 + 0.007*mod_signal2;
    sigma_halo = 0.048 + 0.018*(1-mod_signal2);

    Y0 = repmat(y0, N, 1);
    S1 = repmat(sigma_core, N, 1);
    S2 = repmat(sigma_halo, N, 1);

    D = abs(Y - Y0);

    core = exp(-(D.^2) ./ (2*S1.^2));
    halo = exp(-(D.^2) ./ (2*S2.^2));

    pulse = 1.00 ...
          + 0.18*exp(-((x-0.03).^2)/(2*0.030^2)) ...
          + 0.22*exp(-((x-0.98).^2)/(2*0.030^2)) ...
          + 0.12*mod_signal;
    pulse = repmat(pulse, N, 1);

    bg = 0.30 + 0.14*(1-Y) + 0.10*X + 0.05*f_smooth;

    shimmer_mask = exp(-(D.^2)/(2*(0.090)^2));
    shimmer = 0.11 * (2*f_fine - 1) .* shimmer_mask;

    F = bg + 1.72*core.*pulse + 0.54*halo + shimmer;
    F = local_normalize01(F);

    img = ind2rgb(uint8(255*F), turbo(256));
    img = local_post_glow(img, core, halo);
end

%% ========================================================================
function img = local_post_glow(img, core, halo)
% Small post effect to make it feel more vivid / alive

    img = im2double(img);

    glow = local_normalize01(0.65*core + 0.35*halo);
    glow = imgaussfilt(glow, 1.1);

    % Saturation-like lift by channel shaping
    img(:,:,1) = min(1, img(:,:,1) + 0.18*glow);
    img(:,:,2) = min(1, img(:,:,2) + 0.06*glow);
    img(:,:,3) = min(1, img(:,:,3) + 0.10*halo);

    % Slight contrast lift
    for c = 1:3
        ch = img(:,:,c);
        ch = local_normalize01(ch);
        ch = ch .^ 0.92;
        img(:,:,c) = ch;
    end

    img = uint8(255 * local_normalize01_rgb(img));
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