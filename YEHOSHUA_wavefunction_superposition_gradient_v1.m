function R = YEHOSHUA_wavefunction_superposition_gradient_v1()
% YEHOSHUA_wavefunction_superposition_gradient_v1
%
% Gradient image -> amplitude + phase -> two wave-function states
% -> normalized superposition -> interference and gradient analysis.
%
% Canonical default:
%   Reads only from the verified SSOT H5.
%
% Main relations:
%   A(x,y)       = sqrt(I(x,y))
%   psi          = A .* exp(1i*eta)
%   Psi          = c1*psi1 + c2*psi2
%   probability  = |Psi|^2
%   gradPsi      = gradient(Psi)
%   J            = imag(conj(Psi) .* gradient(Psi))

clc;
close all;

%% ================================================================
%  1. CONFIGURATION
%  ================================================================

sourceMode = "H5";       % "H5" or "IMAGE"

% Canonical YEHOSHUA SSOT
ssotFile = ...
    '/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';

datasetPath = '/n_5_composite_field_1000x1000/data';

% Used only when sourceMode = "IMAGE"
imageFile = 'gradient_input.png';

outputDir = 'YEHOSHUA_wavefunction_superposition_gradient_v1_output';

% Equal superposition when mixingAngle = pi/4
mixingAngle = pi/4;

% Relative phase between the two states
relativePhase = pi/3;

% Spatial phase-carrier parameters
carrierX1 = 4*pi;
carrierY1 = 1*pi;

carrierX2 = -3*pi;
carrierY2 = 2*pi;

% Displacement of the second amplitude field
shiftFractionY = 0.04;
shiftFractionX = 0.08;

% Light deterministic smoothing
smoothingSigma = 1.2;

% Produce an eight-step relative-phase comparison
makePhaseSweep = true;

%% ================================================================
%  2. OUTPUT DIRECTORY
%  ================================================================

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% ================================================================
%  3. READ SOURCE
%  ================================================================

switch upper(sourceMode)

    case "H5"

        if exist(ssotFile, 'file') ~= 2
            error('SSOT H5 was not found:\n%s', ssotFile);
        end

        raw = h5read(ssotFile, datasetPath);
        raw = squeeze(double(raw));

        if ~ismatrix(raw)
            error('The selected H5 dataset is not a single 2-D field.');
        end

    case "IMAGE"

        if exist(imageFile, 'file') ~= 2
            error('Input image was not found:\n%s', imageFile);
        end

        rawImage = imread(imageFile);

        if ndims(rawImage) == 3
            raw = ...
                0.2989 * double(rawImage(:,:,1)) + ...
                0.5870 * double(rawImage(:,:,2)) + ...
                0.1140 * double(rawImage(:,:,3));
        else
            raw = double(rawImage);
        end

    otherwise

        error('Unsupported sourceMode: %s', char(sourceMode));
end

raw = real(raw);

if any(~isfinite(raw(:)))
    error('The source contains NaN or Inf values.');
end

%% ================================================================
%  4. NORMALIZE AND SMOOTH INPUT FIELD
%  ================================================================

I = normalize01(raw);

if smoothingSigma > 0
    radius = ceil(3 * smoothingSigma);

    [kernelX, kernelY] = meshgrid(-radius:radius, -radius:radius);

    gaussianKernel = exp( ...
        -(kernelX.^2 + kernelY.^2) / ...
        (2 * smoothingSigma^2));

    gaussianKernel = gaussianKernel / sum(gaussianKernel(:));

    I = conv2(I, gaussianKernel, 'same');
    I = normalize01(I);
end

[ny, nx] = size(I);

if nx < 3 || ny < 3
    error('The input must contain at least 3-by-3 samples.');
end

%% ================================================================
%  5. COORDINATE FIELD
%  ================================================================

x = linspace(-1, 1, nx);
y = linspace(-1, 1, ny);

[X, Y] = meshgrid(x, y);

dx = x(2) - x(1);
dy = y(2) - y(1);

%% ================================================================
%  6. IMAGE GRADIENT -> LOCAL PHASE
%  ================================================================

[dIdx, dIdy] = gradient(I, dx, dy);

inputGradientMagnitude = hypot(dIdx, dIdy);

% Gradient orientation becomes a local phase field.
etaGradient = atan2(dIdy, dIdx);

% Gradient strength controls how strongly the input phase is expressed.
phaseWeight = normalize01(inputGradientMagnitude);

etaFromImage = phaseWeight .* etaGradient;

%% ================================================================
%  7. BUILD TWO WAVE-FUNCTION STATES
%  ================================================================

% Because I represents density, amplitude is sqrt(I).
A1 = sqrt(I + eps);

shiftY = round(shiftFractionY * ny);
shiftX = round(shiftFractionX * nx);

shiftedDensity = circshift(I, [shiftY, shiftX]);
A2 = sqrt(shiftedDensity + eps);

% State 1 phase:
% local gradient orientation + linear/quadratic carrier
eta1 = ...
    etaFromImage + ...
    carrierX1 .* X + ...
    carrierY1 .* Y + ...
    1.5*pi .* (X.^2 + Y.^2);

% State 2 phase:
% reversed gradient phase + a different spatial carrier
eta2 = ...
    -etaFromImage + ...
    carrierX2 .* X + ...
    carrierY2 .* Y - ...
    0.75*pi .* (X.^2 + Y.^2);

psi1 = A1 .* exp(1i .* eta1);
psi2 = A2 .* exp(1i .* eta2);

% Normalize each state independently.
psi1 = normalizePsi(psi1, dx, dy);
psi2 = normalizePsi(psi2, dx, dy);

%% ================================================================
%  8. COMPLEX SUPERPOSITION
%  ================================================================

c1 = cos(mixingAngle);
c2 = sin(mixingAngle) .* exp(1i .* relativePhase);

psiRaw = c1 .* psi1 + c2 .* psi2;

rawSuperpositionNorm = stateNorm(psiRaw, dx, dy);

% Normalize the complete superposition.
psi = psiRaw ./ rawSuperpositionNorm;

% Components after the same global normalization.
component1 = c1 .* psi1 ./ rawSuperpositionNorm;
component2 = c2 .* psi2 ./ rawSuperpositionNorm;

%% ================================================================
%  9. PROBABILITY AND INTERFERENCE
%  ================================================================

probability1 = abs(component1).^2;
probability2 = abs(component2).^2;

probabilityIncoherent = probability1 + probability2;

probability = abs(psi).^2;

% Cross term:
% 2*Re(conj(component1)*component2)
interference = ...
    2 .* real(conj(component1) .* component2);

% Numerical consistency map:
superpositionResidual = ...
    probability - probabilityIncoherent - interference;

waveAmplitude = abs(psi);
wavePhase = angle(psi);

%% ================================================================
%  10. GRADIENTS OF PSI AND PROBABILITY
%  ================================================================

[dPsidx, dPsidy] = gradient(psi, dx, dy);

waveGradientMagnitude = sqrt( ...
    abs(dPsidx).^2 + ...
    abs(dPsidy).^2);

[dPdx, dPdy] = gradient(probability, dx, dy);

probabilityGradientMagnitude = hypot(dPdx, dPdy);

%% ================================================================
%  11. PHASE-DEPENDENT FLOW FIELD
%  ================================================================

Jx = imag(conj(psi) .* dPsidx);
Jy = imag(conj(psi) .* dPsidy);

Jmagnitude = hypot(Jx, Jy);

%% ================================================================
%  12. OVERLAP AND SUMMARY METRICS
%  ================================================================

overlap = ...
    sum(conj(psi1(:)) .* psi2(:)) .* dx .* dy;

probabilityIntegral = ...
    sum(probability(:)) .* dx .* dy;

gradientEnergy = ...
    sum(waveGradientMagnitude(:).^2) .* dx .* dy;

interferenceEnergy = ...
    sum(interference(:).^2) .* dx .* dy;

residualMaximum = max(abs(superpositionResidual(:)));

metrics = struct();

metrics.state1_norm = stateNorm(psi1, dx, dy);
metrics.state2_norm = stateNorm(psi2, dx, dy);
metrics.superposition_norm = stateNorm(psi, dx, dy);

metrics.probability_integral = probabilityIntegral;

metrics.overlap_real = real(overlap);
metrics.overlap_imag = imag(overlap);
metrics.overlap_absolute = abs(overlap);
metrics.overlap_phase = angle(overlap);

metrics.relative_phase = relativePhase;
metrics.mixing_angle = mixingAngle;

metrics.wave_gradient_mean = mean(waveGradientMagnitude(:));
metrics.wave_gradient_max = max(waveGradientMagnitude(:));
metrics.gradient_energy = gradientEnergy;

metrics.probability_gradient_mean = ...
    mean(probabilityGradientMagnitude(:));

metrics.flow_mean = mean(Jmagnitude(:));
metrics.flow_max = max(Jmagnitude(:));

metrics.interference_mean = mean(interference(:));
metrics.interference_std = std(interference(:));
metrics.interference_energy = interferenceEnergy;

metrics.superposition_residual_max = residualMaximum;

%% ================================================================
%  13. MAIN VISUAL OUTPUT
%  ================================================================

fig = figure( ...
    'Name', 'YEHOSHUA Wave-Function Superposition Gradient', ...
    'Color', 'w', ...
    'Position', [80 80 1680 840]);

layout = tiledlayout(fig, 2, 4, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

% ------------------------------------------------
nexttile;
imagesc(x, y, I);
axis image off;
set(gca, 'YDir', 'normal');
title('Input field I(x,y)');
colorbar;

% ------------------------------------------------
nexttile;
imagesc(x, y, inputGradientMagnitude);
axis image off;
set(gca, 'YDir', 'normal');
title('|grad I|');
colorbar;

% ------------------------------------------------
nexttile;
imagesc(x, y, waveAmplitude);
axis image off;
set(gca, 'YDir', 'normal');
title('|psi|');
colorbar;

% ------------------------------------------------
nexttile;
imagesc(x, y, wavePhase);
axis image off;
set(gca, 'YDir', 'normal');
title('phase eta = angle(psi)');
colorbar;
caxis([-pi pi]);

% ------------------------------------------------
nexttile;
imagesc(x, y, probability);
axis image off;
set(gca, 'YDir', 'normal');
title('|psi|^2');
colorbar;

% ------------------------------------------------
nexttile;
imagesc(x, y, interference);
axis image off;
set(gca, 'YDir', 'normal');
title('Interference cross term');
colorbar;

% ------------------------------------------------
nexttile;
imagesc(x, y, waveGradientMagnitude);
axis image off;
set(gca, 'YDir', 'normal');
title('|grad psi|');
colorbar;

% ------------------------------------------------
nexttile;
imagesc(x, y, probability);
axis image off;
set(gca, 'YDir', 'normal');
hold on;

sampleStep = max(1, round(min(nx, ny) / 28));

sampleX = 1:sampleStep:nx;
sampleY = 1:sampleStep:ny;

quiver( ...
    x(sampleX), ...
    y(sampleY), ...
    Jx(sampleY, sampleX), ...
    Jy(sampleY, sampleX), ...
    1.4, ...
    'w', ...
    'LineWidth', 0.8);

title('Phase flow J over |psi|^2');

sgtitle(layout, ...
    'Gradient Image -> Wave Function -> Superposition', ...
    'FontWeight', 'bold');

mainFigureFile = fullfile( ...
    outputDir, ...
    '01_wavefunction_superposition_gradient.png');

exportgraphics(fig, mainFigureFile, 'Resolution', 180);

%% ================================================================
%  14. SAVE INDIVIDUAL FIELDS
%  ================================================================

imwrite( ...
    normalize01(I), ...
    fullfile(outputDir, '02_input_field.png'));

imwrite( ...
    normalize01(inputGradientMagnitude), ...
    fullfile(outputDir, '03_input_gradient_magnitude.png'));

imwrite( ...
    normalize01(probability), ...
    fullfile(outputDir, '04_probability_density.png'));

imwrite( ...
    normalize01(waveGradientMagnitude), ...
    fullfile(outputDir, '05_wavefunction_gradient.png'));

imwrite( ...
    normalize01(probabilityGradientMagnitude), ...
    fullfile(outputDir, '06_probability_gradient.png'));

imwrite( ...
    normalize01(Jmagnitude), ...
    fullfile(outputDir, '07_phase_flow_magnitude.png'));

% Preserve zero interference at middle gray.
maximumInterference = max(abs(interference(:)));

if maximumInterference > eps
    interferenceImage = ...
        0.5 + 0.5 .* interference ./ maximumInterference;
else
    interferenceImage = 0.5 .* ones(size(interference));
end

imwrite( ...
    interferenceImage, ...
    fullfile(outputDir, '08_signed_interference.png'));

% Phase encoded as hue and amplitude encoded as brightness.
phaseHue = mod((wavePhase + pi) ./ (2*pi), 1);

phaseRGB = hsv2rgb(cat( ...
    3, ...
    phaseHue, ...
    ones(size(waveAmplitude)), ...
    normalize01(waveAmplitude)));

imwrite( ...
    phaseRGB, ...
    fullfile(outputDir, '09_phase_amplitude_rgb.png'));

%% ================================================================
%  15. RELATIVE-PHASE SWEEP
%  ================================================================

if makePhaseSweep

    phaseSweepFigure = figure( ...
        'Name', 'Relative Phase Sweep', ...
        'Color', 'w', ...
        'Position', [100 100 1500 760]);

    phaseLayout = tiledlayout( ...
        phaseSweepFigure, 2, 4, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    phaseValues = 2*pi .* (0:7) ./ 8;

    phaseSweepProbability = zeros(ny, nx, numel(phaseValues));

    for phaseIndex = 1:numel(phaseValues)

        currentPhase = phaseValues(phaseIndex);

        currentC2 = ...
            sin(mixingAngle) .* exp(1i .* currentPhase);

        currentPsi = ...
            c1 .* psi1 + currentC2 .* psi2;

        currentPsi = normalizePsi(currentPsi, dx, dy);

        currentProbability = abs(currentPsi).^2;

        phaseSweepProbability(:,:,phaseIndex) = ...
            currentProbability;

        nexttile;

        imagesc(x, y, currentProbability);
        axis image off;
        set(gca, 'YDir', 'normal');

        title(sprintf( ...
            '\\Delta\\eta = %.2f\\pi', ...
            currentPhase / pi));

        colorbar;
    end

    sgtitle(phaseLayout, ...
        'Effect of Relative Phase on the Superposition', ...
        'FontWeight', 'bold');

    phaseSweepFile = fullfile( ...
        outputDir, ...
        '10_relative_phase_sweep.png');

    exportgraphics( ...
        phaseSweepFigure, ...
        phaseSweepFile, ...
        'Resolution', 180);

else

    phaseValues = [];
    phaseSweepProbability = [];

end

%% ================================================================
%  16. RESULT STRUCTURE
%  ================================================================

R = struct();

R.source_mode = sourceMode;
R.ssot_file = ssotFile;
R.dataset_path = datasetPath;

R.x = x;
R.y = y;

R.input = I;

R.input_gradient_x = dIdx;
R.input_gradient_y = dIdy;
R.input_gradient_magnitude = inputGradientMagnitude;
R.input_gradient_phase = etaGradient;

R.amplitude1 = A1;
R.amplitude2 = A2;

R.eta1 = eta1;
R.eta2 = eta2;

R.psi1 = psi1;
R.psi2 = psi2;
R.psi = psi;

R.probability1 = probability1;
R.probability2 = probability2;
R.probability_incoherent = probabilityIncoherent;
R.probability = probability;

R.interference = interference;
R.superposition_residual = superpositionResidual;

R.wave_gradient_x = dPsidx;
R.wave_gradient_y = dPsidy;
R.wave_gradient_magnitude = waveGradientMagnitude;

R.probability_gradient_x = dPdx;
R.probability_gradient_y = dPdy;
R.probability_gradient_magnitude = probabilityGradientMagnitude;

R.flow_x = Jx;
R.flow_y = Jy;
R.flow_magnitude = Jmagnitude;

R.phase_values = phaseValues;
R.phase_sweep_probability = phaseSweepProbability;

R.metrics = metrics;

save( ...
    fullfile(outputDir, ...
    'YEHOSHUA_wavefunction_superposition_gradient_v1.mat'), ...
    'R', ...
    '-v7.3');

%% ================================================================
%  17. TEXT REPORT
%  ================================================================

reportFile = fullfile( ...
    outputDir, ...
    'YEHOSHUA_wavefunction_superposition_gradient_report.txt');

fid = fopen(reportFile, 'w');

if fid < 0
    error('Could not create the report file.');
end

cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, ...
    'YEHOSHUA Wave-Function Superposition Gradient Report\n');

fprintf(fid, ...
    '===================================================\n\n');

fprintf(fid, 'Source mode: %s\n', char(sourceMode));
fprintf(fid, 'SSOT file: %s\n', ssotFile);
fprintf(fid, 'Dataset: %s\n\n', datasetPath);

fprintf(fid, 'Field size: %d x %d\n', ny, nx);
fprintf(fid, 'Mixing angle: %.12g rad\n', mixingAngle);
fprintf(fid, 'Relative phase: %.12g rad\n\n', relativePhase);

fprintf(fid, ...
    'State 1 norm: %.15g\n', ...
    metrics.state1_norm);

fprintf(fid, ...
    'State 2 norm: %.15g\n', ...
    metrics.state2_norm);

fprintf(fid, ...
    'Superposition norm: %.15g\n', ...
    metrics.superposition_norm);

fprintf(fid, ...
    'Probability integral: %.15g\n\n', ...
    metrics.probability_integral);

fprintf(fid, ...
    'Overlap absolute: %.15g\n', ...
    metrics.overlap_absolute);

fprintf(fid, ...
    'Overlap phase: %.15g rad\n\n', ...
    metrics.overlap_phase);

fprintf(fid, ...
    'Mean |grad psi|: %.15g\n', ...
    metrics.wave_gradient_mean);

fprintf(fid, ...
    'Maximum |grad psi|: %.15g\n', ...
    metrics.wave_gradient_max);

fprintf(fid, ...
    'Gradient energy: %.15g\n\n', ...
    metrics.gradient_energy);

fprintf(fid, ...
    'Mean flow magnitude: %.15g\n', ...
    metrics.flow_mean);

fprintf(fid, ...
    'Maximum flow magnitude: %.15g\n\n', ...
    metrics.flow_max);

fprintf(fid, ...
    'Interference standard deviation: %.15g\n', ...
    metrics.interference_std);

fprintf(fid, ...
    'Interference energy: %.15g\n\n', ...
    metrics.interference_energy);

fprintf(fid, ...
    'Maximum decomposition residual: %.15g\n', ...
    metrics.superposition_residual_max);

clear cleanupObject;

%% ================================================================
%  18. COMMAND-WINDOW SUMMARY
%  ================================================================

fprintf('\n');
fprintf('YEHOSHUA wave-function processing completed.\n');
fprintf('Output folder:\n%s\n\n', outputDir);

fprintf('Integral of |psi|^2: %.12f\n', ...
    metrics.probability_integral);

fprintf('|<psi1|psi2>|: %.12f\n', ...
    metrics.overlap_absolute);

fprintf('Mean |grad psi|: %.12f\n', ...
    metrics.wave_gradient_mean);

fprintf('Interference energy: %.12f\n', ...
    metrics.interference_energy);

fprintf('Maximum residual: %.3e\n\n', ...
    metrics.superposition_residual_max);

end

%% =================================================================
%  LOCAL FUNCTIONS
%  =================================================================

function X01 = normalize01(X)

X = double(real(X));

minimumValue = min(X(:));
maximumValue = max(X(:));

valueRange = maximumValue - minimumValue;

if valueRange <= eps(max(abs([minimumValue, maximumValue, 1])))
    X01 = zeros(size(X));
else
    X01 = (X - minimumValue) ./ valueRange;
end

X01 = min(max(X01, 0), 1);

end

function psiNormalized = normalizePsi(psi, dx, dy)

currentNorm = stateNorm(psi, dx, dy);

if ~isfinite(currentNorm) || currentNorm <= eps
    error('Wave-function normalization failed.');
end

psiNormalized = psi ./ currentNorm;

end

function value = stateNorm(psi, dx, dy)

value = sqrt( ...
    sum(abs(psi(:)).^2) .* ...
    abs(dx .* dy));

end