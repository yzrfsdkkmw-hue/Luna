function YEHOSHUA_wave_function_formula_embedded_from_SSOT_v15b()
% YEHOSHUA_wave_function_formula_embedded_from_SSOT_v15b
%
% Canonical rule:
% Read only from the verified SSOT H5.
%
% Generates "living" wave-function style images with:
%   1) temporal breathing
%   2) stronger projection-field signature from SSOT
%   3) eta-phase style modulation
%   5) dark Apple-display tuned output
%   + embedded formulas inside the image
%
% Outputs:
%   - wave_formula_variant_01.png
%   - wave_formula_variant_02.png
%   - wave_formula_variant_03.png
%   - wave_formula_breathing.gif

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
    % 1) Read SSOT and derive 2D field
    % =============================================================
    raw = h5read(ssot_h5, dataset_path);
    field2d = local_make_2d_field(raw);

    if isempty(field2d) || ~ismatrix(field2d)
        error('Could not derive a usable 2D numeric field from SSOT.');
    end

    field2d = double(field2d);
    field2d = local_normalize01(field2d);

    N = 768;
    M = 768;
    field2d = imresize(field2d, [N M], 'bicubic');
    field2d = local_normalize01(field2d);

    %% ============================================================
    % 2) Multi-scale SSOT signatures
    % =============================================================
    f_smooth = imgaussfilt(field2d, 22);
    f_mid    = imgaussfilt(field2d, 8);
    f_sharp  = field2d - imgaussfilt(field2d, 1.8);

    f_smooth = local_normalize01(f_smooth);
    f_mid    = local_normalize01(f_mid);
    f_sharp  = local_normalize01(f_sharp);

    % Stronger "projection-field signature"
    sigA = mean(f_mid,1);
    sigA = smoothdata(sigA, 'gaussian', 41);
    sigA = local_normalize01(sigA);
    sigA = 2*sigA - 1;  % ~[-1,1]

    sigB = mean(f_smooth,1);
    sigB = smoothdata(sigB, 'gaussian', 61);
    sigB = local_normalize01(sigB);

    % A gradient-like signature to produce more "alive" bends
    sigC = gradient(sigA);
    sigC = smoothdata(sigC, 'gaussian', 35);
    sigC = local_normalize01(sigC);
    sigC = 2*sigC - 1;

    % Another spatial signature from column energy
    sigD = std(f_mid,0,1);
    sigD = smoothdata(sigD, 'gaussian', 51);
    sigD = local_normalize01(sigD);
    sigD = 2*sigD - 1;

    %% ============================================================
    % 3) Coordinates
    % =============================================================
    x = linspace(0,1,M);
    y = linspace(0,1,N);
    [X,Y] = meshgrid(x,y);

    %% ============================================================
    % 4) Static variants
    % =============================================================
    img1 = local_variant_slanted_living(X,Y,sigA,sigB,sigC,sigD,f_smooth,f_sharp,0.0);
    img2 = local_variant_bowl_blue_living(X,Y,sigA,sigB,sigC,sigD,f_smooth,f_sharp,0.0);
    img3 = local_variant_bowl_cyan_living(X,Y,sigA,sigB,sigC,sigD,f_smooth,f_sharp,0.0);

    % Embed formulas
    img1 = local_embed_formulas(img1, 1);
    img2 = local_embed_formulas(img2, 2);
    img3 = local_embed_formulas(img3, 3);

    %% ============================================================
    % 5) Save static outputs
    % =============================================================
    out_dir = pwd;

    imwrite(img1, fullfile(out_dir, 'wave_formula_variant_01.png'));
    imwrite(img2, fullfile(out_dir, 'wave_formula_variant_02.png'));
    imwrite(img3, fullfile(out_dir, 'wave_formula_variant_03.png'));

    %% ============================================================
    % 6) Temporal breathing GIF
    % =============================================================
    gif_path = fullfile(out_dir, 'wave_formula_breathing.gif');
    T = 18;  % number of frames

    for k = 1:T
        phase_t = 2*pi*(k-1)/T;

        % You can switch which variant to animate here:
        frame_img = local_variant_bowl_cyan_living( ...
            X,Y,sigA,sigB,sigC,sigD,f_smooth,f_sharp,phase_t);

        frame_img = local_embed_formulas(frame_img, 4);

        [A,map] = rgb2ind(frame_img,256);

        if k == 1
            imwrite(A,map,gif_path,'gif','LoopCount',Inf,'DelayTime',0.08);
        else
            imwrite(A,map,gif_path,'gif','WriteMode','append','DelayTime',0.08);
        end
    end

    fprintf('Done.\nSaved:\n');
    fprintf('  %s\n', fullfile(out_dir, 'wave_formula_variant_01.png'));
    fprintf('  %s\n', fullfile(out_dir, 'wave_formula_variant_02.png'));
    fprintf('  %s\n', fullfile(out_dir, 'wave_formula_variant_03.png'));
    fprintf('  %s\n', gif_path);
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
                field2d = mean(arr,3);
            elseif dims(1) <= 4
                field2d = squeeze(mean(arr,1));
            else
                k = round(dims(3)/2);
                field2d = arr(:,:,k);
            end

        otherwise
            vec = arr(:);
            L = numel(vec);
            side = floor(sqrt(L));
            side = max(side,256);
            usable = min(L, side*side);
            field2d = reshape(vec(1:usable), side, side);
    end

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
function img = local_variant_slanted_living(X,Y,sigA,sigB,sigC,sigD,f_smooth,f_sharp,phase_t)
% Slanted energetic band with breathing and eta-phase modulation

    [N,M] = size(X);
    x = X(1,:);

    breathe = 0.5 + 0.5*sin(phase_t);
    eta_mod = 0.5*sin(2*pi*(2.3*x) + phase_t) + 0.35*cos(2*pi*(1.1*x) - 0.6*phase_t);

    y0 = 0.24 + 0.50*x ...
       + 0.060*sin(2*pi*(0.85*x + 0.15)) ...
       - 0.070*exp(-((x-0.18).^2)/(2*0.07^2)) ...
       + 0.050*exp(-((x-0.66).^2)/(2*0.10^2));

    y0 = y0 ...
       + 0.050*sigA ...
       + 0.030*sigC ...
       + 0.018*eta_mod ...
       + 0.010*breathe*sigD;

    sigma_core = 0.018 + 0.008*sigB + 0.006*breathe;
    sigma_halo = 0.050 + 0.018*(1-sigB) + 0.012*breathe;

    Y0 = repmat(y0,N,1);
    S1 = repmat(sigma_core,N,1);
    S2 = repmat(sigma_halo,N,1);

    D = abs(Y - Y0);

    core = exp(-(D.^2)./(2*S1.^2));
    halo = exp(-(D.^2)./(2*S2.^2));

    pulse = 0.95 ...
          + 0.55*exp(-((x-0.09).^2)/(2*0.030^2)) ...
          + 0.58*exp(-((x-0.65).^2)/(2*0.055^2)) ...
          + 0.25*exp(-((x-0.85).^2)/(2*0.040^2));

    pulse = pulse .* (1 + 0.18*sigA + 0.10*sigC + 0.10*sin(phase_t));
    pulse = repmat(pulse,N,1);

    bg = 0.03 + 0.03*(1-Y).^1.2 + 0.05*f_smooth;

    signature_mask = exp(-(D.^2)/(2*(0.090)^2));
    signature = 0.14*(2*f_sharp - 1).*signature_mask;

    F = bg + 1.90*core.*pulse + 0.62*halo + signature;
    F = local_normalize01(F);

    img = ind2rgb(uint8(255*F), turbo(256));
    img = local_dark_apple_finish(img, core, halo, breathe);
end

%% ========================================================================
function img = local_variant_bowl_blue_living(X,Y,sigA,sigB,sigC,sigD,f_smooth,f_sharp,phase_t)
% Blue bowl variant

    [N,M] = size(X);
    x = X(1,:);

    breathe = 0.5 + 0.5*sin(phase_t);
    eta_mod = 0.45*sin(2*pi*(1.8*x) + phase_t) + 0.25*cos(2*pi*(0.7*x) - 0.5*phase_t);

    y0 = 0.24 + 1.95*(x - 0.50).^2;
    y0 = y0 + 0.018*sigA.*exp(-((x-0.50).^2)/(2*0.30^2));
    y0 = y0 + 0.020*sigC + 0.015*eta_mod;

    sigma_core = 0.017 + 0.006*sigB + 0.005*breathe;
    sigma_halo = 0.043 + 0.014*(1-sigB) + 0.011*breathe;

    Y0 = repmat(y0,N,1);
    S1 = repmat(sigma_core,N,1);
    S2 = repmat(sigma_halo,N,1);

    D = abs(Y - Y0);

    core = exp(-(D.^2)./(2*S1.^2));
    halo = exp(-(D.^2)./(2*S2.^2));

    pulse = 1.00 + 0.09*cos(2*pi*x) + 0.11*sigA + 0.10*sin(phase_t);
    pulse = repmat(pulse,N,1);

    bg = 0.06 + 0.18*Y + 0.015*(1-X) + 0.04*f_smooth;

    signature_mask = exp(-(D.^2)/(2*(0.080)^2));
    signature = 0.11*(2*f_sharp - 1).*signature_mask;

    F = bg + 1.95*core.*pulse + 0.54*halo + signature;
    F = local_normalize01(F);

    img = ind2rgb(uint8(255*F), turbo(256));
    img = local_dark_apple_finish(img, core, halo, breathe);
end

%% ========================================================================
function img = local_variant_bowl_cyan_living(X,Y,sigA,sigB,sigC,sigD,f_smooth,f_sharp,phase_t)
% Cyan-green bowl variant

    [N,M] = size(X);
    x = X(1,:);

    breathe = 0.5 + 0.5*sin(phase_t);
    eta_mod = 0.55*sin(2*pi*(2.0*x) + 1.1*phase_t) + 0.25*cos(2*pi*(0.9*x) - 0.3*phase_t);

    y0 = 0.26 + 1.82*(x - 0.48).^2;
    y0 = y0 + 0.018*sin(2*pi*(1.3*x + 0.07)).*exp(-((x-0.5).^2)/(2*0.30^2));
    y0 = y0 + 0.020*sigA + 0.022*sigC + 0.016*eta_mod + 0.008*breathe*sigD;

    sigma_core = 0.018 + 0.006*sigB + 0.005*breathe;
    sigma_halo = 0.046 + 0.016*(1-sigB) + 0.012*breathe;

    Y0 = repmat(y0,N,1);
    S1 = repmat(sigma_core,N,1);
    S2 = repmat(sigma_halo,N,1);

    D = abs(Y - Y0);

    core = exp(-(D.^2)./(2*S1.^2));
    halo = exp(-(D.^2)./(2*S2.^2));

    pulse = 1.00 ...
          + 0.18*exp(-((x-0.03).^2)/(2*0.030^2)) ...
          + 0.22*exp(-((x-0.98).^2)/(2*0.030^2)) ...
          + 0.12*sigA ...
          + 0.10*sin(phase_t);

    pulse = repmat(pulse,N,1);

    bg = 0.18 + 0.09*(1-Y) + 0.07*X + 0.05*f_smooth;

    signature_mask = exp(-(D.^2)/(2*(0.092)^2));
    signature = 0.14*(2*f_sharp - 1).*signature_mask;

    F = bg + 1.88*core.*pulse + 0.58*halo + signature;
    F = local_normalize01(F);

    img = ind2rgb(uint8(255*F), turbo(256));
    img = local_dark_apple_finish(img, core, halo, breathe);
end

%% ========================================================================
function img = local_dark_apple_finish(img, core, halo, breathe)
% Dark / vivid / Apple-display tuned finish

    img = im2double(img);

    glow = local_normalize01(0.70*core + 0.30*halo);
    glow = imgaussfilt(glow,1.0);

    % dark-display tuning
    img(:,:,1) = min(1, 0.92*img(:,:,1) + 0.22*glow);
    img(:,:,2) = min(1, 0.88*img(:,:,2) + 0.08*glow);
    img(:,:,3) = min(1, 0.95*img(:,:,3) + 0.14*halo);

    % "alive" brightness breathing
    lift = 0.02 + 0.025*breathe;
    img = min(1, max(0, img + lift*glow));

    % contrast shaping
    for c = 1:3
        ch = img(:,:,c);
        ch = local_normalize01(ch);
        ch = ch .^ 0.90;
        img(:,:,c) = ch;
    end

    % slightly deepen the dark background
    bgmask = local_normalize01(1 - (0.70*core + 0.20*halo));
    bgmask = bgmask.^1.5;
    img = img .* (0.88 + 0.12*(1-bgmask));

    img = uint8(255 * local_normalize01_rgb(img));
end

%% ========================================================================
function img_out = local_embed_formulas(img_in, mode_id)
% Embed formulas directly inside the image without external toolboxes.
% Uses figure + text objects + getframe.

    img = im2double(img_in);
    [N,M,~] = size(img);

    f = figure('Visible','off', ...
               'Color','black', ...
               'Position',[100 100 M N], ...
               'MenuBar','none', ...
               'ToolBar','none');

    ax = axes('Parent',f);
    image(ax, img);
    axis(ax,'image');
    axis(ax,'off');
    hold(ax,'on');

    % semi-transparent text panels by drawing dark patches
    local_panel(ax, [22, 22, 340, 110], [0 0 0], 0.42, M, N);
    local_panel(ax, [24, N-140, 410, 96], [0 0 0], 0.36, M, N);

    switch mode_id
        case 1
            lines_top = { ...
                '\psi(x,t)=\langle x|\psi(t)\rangle', ...
                '|\psi|^2=\psi^*\psi', ...
                '|\psi(t)\rangle=\int \psi(x,t)|x\rangle dx' ...
                };
            lines_bottom = { ...
                'YEHOSHUA\_projection\_temporal\_formula\_from\_SSOT\_v15', ...
                'projection field  •  living wave  •  eta-phase'
                };

        case 2
            lines_top = { ...
                '\psi=\psi_1+\psi_2', ...
                '|\psi|^2=|\psi_1|^2+|\psi_2|^2+\psi_1^*\psi_2+\psi_2^*\psi_1', ...
                '\Delta\theta \rightarrow interference'
                };
            lines_bottom = { ...
                'SSOT-driven wave signature', ...
                'temporal breathing  •  curved projector field'
                };

        case 3
            lines_top = { ...
                '|\phi\rangle\langle\phi|\psi\rangle', ...
                '|v_{eff}\rangle=(I-|\psi\rangle\langle\psi|)|\dot{\psi}\rangle', ...
                'v_g^2=\langle v_{eff}|v_{eff}\rangle'
                };
            lines_bottom = { ...
                'effective navigation  •  geodesic velocity square', ...
                'embedded formula layer'
                };

        otherwise
            lines_top = { ...
                '\psi(x,t)=\langle x|\psi(t)\rangle', ...
                '\psi=\sqrt{\rho}e^{iS/\hbar}', ...
                'v_g^2=\langle v_{eff}|v_{eff}\rangle'
                };
            lines_bottom = { ...
                'breathing wave animation', ...
                'dark Apple tuned output'
                };
    end

    % Top formula block
    y0 = 36;
    dy = 28;
    for i = 1:numel(lines_top)
        text(ax, 34, y0 + (i-1)*dy, lines_top{i}, ...
            'Interpreter','tex', ...
            'Color',[0.96 0.96 0.96], ...
            'FontSize',18, ...
            'FontWeight','bold', ...
            'FontName','Helvetica', ...
            'VerticalAlignment','top');
    end

    % Bottom block
    yb = N - 118;
    for i = 1:numel(lines_bottom)
        text(ax, 34, yb + (i-1)*28, lines_bottom{i}, ...
            'Interpreter','none', ...
            'Color',[0.88 0.95 1.00], ...
            'FontSize',16, ...
            'FontWeight','bold', ...
            'FontName','Helvetica', ...
            'VerticalAlignment','top');
    end

    frame = getframe(ax);
    img_out = frame.cdata;

    close(f);

    if size(img_out,1) ~= N || size(img_out,2) ~= M
        img_out = imresize(img_out, [N M], 'bicubic');
    end
end

%% ========================================================================
function local_panel(ax, rect_px, color_rgb, alpha_val, M, N)
% rect_px = [x y w h] in image pixel coordinates
    x = rect_px(1);
    y = rect_px(2);
    w = rect_px(3);
    h = rect_px(4);

    xx = [x, x+w, x+w, x];
    yy = [y, y, y+h, y+h];

    patch(ax, xx, yy, color_rgb, ...
        'FaceAlpha', alpha_val, ...
        'EdgeColor', [1 1 1], ...
        'LineWidth', 0.5, ...
        'EdgeAlpha', 0.12);
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