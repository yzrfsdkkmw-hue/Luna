function R = YEHOSHUA_wavefunction_superposition_gradient_online_v2()
% YEHOSHUA_wavefunction_superposition_gradient_online_v2
%
% MATLAB Online headless version:
%   - Reads only from the canonical SSOT H5.
%   - Creates no figures or live graphics.
%   - Saves numerical results and individual PNG outputs.
%
% Main structure:
%   I(x,y)          -> normalized source field
%   A(x,y)          = sqrt(I)
%   eta(x,y)        = gradient-dependent phase
%   psi1, psi2      = two complex wave-function states
%   psi             = normalized superposition
%   |psi|^2         = probability density
%   grad(psi)       = wave-function gradient
%   J               = phase-dependent flow field

clc;
close all force;

fprintf('\n');
fprintf('YEHOSHUA wave-function processing started.\n');
fprintf('Graphics mode: disabled.\n\n');

%% ================================================================
%  1. CANONICAL SOURCE
%  ================================================================

ssotFile = ...
    '/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';

datasetPath = ...
    '/n_5_composite_field_1000x1000/data';

outputDir = fullfile( ...
    fileparts(ssotFile), ...
    'YEHOSHUA_wavefunction_superposition_gradient_online_v2_output');

%% ================================================================
%  2. PARAMETERS
%  ================================================================

mixingAngle = pi / 4;
relativePhase = pi / 3;

carrierX1 = 4 * pi;
carrierY1 = 1 * pi;

carrierX2 = -3 * pi;
carrierY2 = 2 * pi;

shiftFractionY = 0.04;
shiftFractionX = 0.08;

smoothingSigma = 1.2;

%% ================================================================
%  3. OUTPUT DIRECTORY
%  ================================================================

if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end

fprintf('Output directory:\n%s\n\n', outputDir);

%% ================================================================
%  4. READ H5 SOURCE
%  ================================================================

fprintf('[1/8] Reading canonical H5 dataset...\n');

if exist(ssotFile, 'file') ~= 2
    error('Canonical SSOT H5 file was not found:\n%s', ssotFile);
end

raw = h5read(ssotFile, datasetPath);
raw = squeeze(double(raw));
raw = real(raw);

if ~ismatrix(raw)
    error('The selected H5 dataset is not a single two-dimensional field.');
end

if any(~isfinite(raw(:)))
    error('The selected H5 dataset contains NaN or Inf values.');
end

[ny, nx] = size(raw);

if ny < 3 || nx < 3
    error('The H5 field must contain at least 3-by-3 samples.');
end

fprintf('      Field size: %d x %d\n', ny, nx);

%% ================================================================
%  5. NORMALIZATION AND SMOOTHING
%  ================================================================

fprintf('[2/8] Normalizing and smoothing source field...\n');

I = normalize01(raw);

if smoothingSigma > 0

    radius = ceil(3 * smoothingSigma);

    [kernelX, kernelY] = meshgrid( ...
        -radius:radius, ...
        -radius:radius);

    gaussianKernel = exp( ...
        -(kernelX.^2 + kernelY.^2) ./ ...
        (2 * smoothingSigma^2));

    gaussianKernel = ...
        gaussianKernel ./ sum(gaussianKernel(:));

    I = conv2(I, gaussianKernel, 'same');
    I = normalize01(I);
end

clear raw gaussianKernel kernelX kernelY;

%% ================================================================
%  6. COORDINATES AND SOURCE GRADIENT
%  ================================================================

fprintf('[3/8] Computing source gradient and local phase...\n');

x = linspace(-1, 1, nx);
y = linspace(-1, 1, ny);

[X, Y] = meshgrid(x, y);

dx = x(2) - x(1);
dy = y(2) - y(1);

[dIdx, dIdy] = gradient(I, dx, dy);

inputGradientMagnitude = hypot(dIdx, dIdy);
inputGradientPhase = atan2(dIdy, dIdx);

phaseWeight = normalize01(inputGradientMagnitude);

etaFromImage = ...
    phaseWeight .* inputGradientPhase;

%% ================================================================
%  7. BUILD TWO WAVE-FUNCTION STATES
%  ================================================================

fprintf('[4/8] Building two wave-function states...\n');

A1 = sqrt(I + eps);

shiftY = round(shiftFractionY * ny);
shiftX = round(shiftFractionX * nx);

shiftedDensity = circshift(I, [shiftY, shiftX]);
A2 = sqrt(shiftedDensity + eps);

eta1 = ...
    etaFromImage + ...
    carrierX1 .* X + ...
    carrierY1 .* Y + ...
    1.5 * pi .* (X.^2 + Y.^2);

eta2 = ...
    -etaFromImage + ...
    carrierX2 .* X + ...
    carrierY2 .* Y - ...
    0.75 * pi .* (X.^2 + Y.^2);

psi1 = A1 .* exp(1i .* eta1);
psi2 = A2 .* exp(1i .* eta2);

psi1 = normalizePsi(psi1, dx, dy);
psi2 = normalizePsi(psi2, dx, dy);

%% ================================================================
%  8. SUPERPOSITION
%  ================================================================

fprintf('[5/8] Computing normalized superposition...\n');

c1 = cos(mixingAngle);

c2 = ...
    sin(mixingAngle) .* ...
    exp(1i .* relativePhase);

psiRaw = ...
    c1 .* psi1 + ...
    c2 .* psi2;

rawSuperpositionNorm = ...
    stateNorm(psiRaw, dx, dy);

if rawSuperpositionNorm <= eps || ...
        ~isfinite(rawSuperpositionNorm)

    error('Superposition normalization failed.');
end

psi = psiRaw ./ rawSuperpositionNorm;

component1 = ...
    c1 .* psi1 ./ rawSuperpositionNorm;

component2 = ...
    c2 .* psi2 ./ rawSuperpositionNorm;

%% ================================================================
%  9. PROBABILITY AND INTERFERENCE
%  ================================================================

probability1 = abs(component1).^2;
probability2 = abs(component2).^2;

probabilityIncoherent = ...
    probability1 + probability2;

probability = abs(psi).^2;

interference = ...
    2 .* real(conj(component1) .* component2);

superpositionResidual = ...
    probability - ...
    probabilityIncoherent - ...
    interference;

waveAmplitude = abs(psi);
wavePhase = angle(psi);

%% ================================================================
%  10. COMPLEX GRADIENT AND FLOW
%  ================================================================

fprintf('[6/8] Computing wave-function gradients and flow...\n');

[dPsidx, dPsidy] = ...
    gradient(psi, dx, dy);

waveGradientMagnitude = sqrt( ...
    abs(dPsidx).^2 + ...
    abs(dPsidy).^2);

[dPdx, dPdy] = ...
    gradient(probability, dx, dy);

probabilityGradientMagnitude = ...
    hypot(dPdx, dPdy);

Jx = imag(conj(psi) .* dPsidx);
Jy = imag(conj(psi) .* dPsidy);

Jmagnitude = hypot(Jx, Jy);

%% ================================================================
%  11. METRICS
%  ================================================================

overlap = ...
    sum(conj(psi1(:)) .* psi2(:)) .* ...
    abs(dx * dy);

metrics = struct();

metrics.field_height = ny;
metrics.field_width = nx;

metrics.mixing_angle = mixingAngle;
metrics.relative_phase = relativePhase;

metrics.state1_norm = ...
    stateNorm(psi1, dx, dy);

metrics.state2_norm = ...
    stateNorm(psi2, dx, dy);

metrics.superposition_norm = ...
    stateNorm(psi, dx, dy);

metrics.probability_integral = ...
    sum(probability(:)) .* abs(dx * dy);

metrics.overlap_real = real(overlap);
metrics.overlap_imag = imag(overlap);
metrics.overlap_absolute = abs(overlap);
metrics.overlap_phase = angle(overlap);

metrics.input_gradient_mean = ...
    mean(inputGradientMagnitude(:));

metrics.input_gradient_max = ...
    max(inputGradientMagnitude(:));

metrics.wave_gradient_mean = ...
    mean(waveGradientMagnitude(:));

metrics.wave_gradient_max = ...
    max(waveGradientMagnitude(:));

metrics.gradient_energy = ...
    sum(waveGradientMagnitude(:).^2) .* ...
    abs(dx * dy);

metrics.probability_gradient_mean = ...
    mean(probabilityGradientMagnitude(:));

metrics.probability_gradient_max = ...
    max(probabilityGradientMagnitude(:));

metrics.flow_mean = ...
    mean(Jmagnitude(:));

metrics.flow_max = ...
    max(Jmagnitude(:));

metrics.interference_mean = ...
    mean(interference(:));

metrics.interference_std = ...
    std(interference(:));

metrics.interference_energy = ...
    sum(interference(:).^2) .* ...
    abs(dx * dy);

metrics.superposition_residual_max = ...
    max(abs(superpositionResidual(:)));

%% ================================================================
%  12. SAVE PNG OUTPUTS
%  ================================================================

fprintf('[7/8] Saving individual PNG files...\n');

writeGray16( ...
    probability, ...
    fullfile( ...
        outputDir, ...
        '04_probability_density.png'));

writeGray16( ...
    waveGradientMagnitude, ...
    fullfile( ...
        outputDir, ...
        '05_wavefunction_gradient.png'));

writeGray16( ...
    probabilityGradientMagnitude, ...
    fullfile( ...
        outputDir, ...
        '06_probability_gradient.png'));

writeGray16( ...
    Jmagnitude, ...
    fullfile( ...
        outputDir, ...
        '07_phase_flow_magnitude.png'));

maximumInterference = ...
    max(abs(interference(:)));

if maximumInterference > eps

    signedInterferenceImage = ...
        0.5 + ...
        0.5 .* ...
        interference ./ maximumInterference;

else

    signedInterferenceImage = ...
        0.5 .* ones(size(interference));

end

signedInterferenceImage = ...
    min(max(signedInterferenceImage, 0), 1);

imwrite( ...
    uint16(round(65535 .* signedInterferenceImage)), ...
    fullfile( ...
        outputDir, ...
        '08_signed_interference.png'));

phaseHue = ...
    mod((wavePhase + pi) ./ (2 * pi), 1);

phaseValue = ...
    normalize01(waveAmplitude);

phaseRGB = hsv2rgb(cat( ...
    3, ...
    phaseHue, ...
    ones(size(phaseHue)), ...
    phaseValue));

imwrite( ...
    uint8(round(255 .* phaseRGB)), ...
    fullfile( ...
        outputDir, ...
        '09_phase_amplitude_rgb.png'));

%% ================================================================
%  13. RESULT STRUCTURE
%  ================================================================

R = struct();

R.version = ...
    'YEHOSHUA_wavefunction_superposition_gradient_online_v2';

R.source_file = ssotFile;
R.dataset_path = datasetPath;
R.output_directory = outputDir;

R.x = x;
R.y = y;

R.input = I;

R.input_gradient_x = dIdx;
R.input_gradient_y = dIdy;

R.input_gradient_magnitude = ...
    inputGradientMagnitude;

R.input_gradient_phase = ...
    inputGradientPhase;

R.phase_weight = phaseWeight;
R.eta_from_image = etaFromImage;

R.amplitude1 = A1;
R.amplitude2 = A2;

R.eta1 = eta1;
R.eta2 = eta2;

R.psi1 = psi1;
R.psi2 = psi2;
R.psi = psi;

R.component1 = component1;
R.component2 = component2;

R.probability1 = probability1;
R.probability2 = probability2;

R.probability_incoherent = ...
    probabilityIncoherent;

R.probability = probability;
R.interference = interference;

R.superposition_residual = ...
    superpositionResidual;

R.wave_amplitude = waveAmplitude;
R.wave_phase = wavePhase;

R.wave_gradient_x = dPsidx;
R.wave_gradient_y = dPsidy;

R.wave_gradient_magnitude = ...
    waveGradientMagnitude;

R.probability_gradient_x = dPdx;
R.probability_gradient_y = dPdy;

R.probability_gradient_magnitude = ...
    probabilityGradientMagnitude;

R.flow_x = Jx;
R.flow_y = Jy;
R.flow_magnitude = Jmagnitude;

R.metrics = metrics;

%% ================================================================
%  14. SAVE MAT FILE
%  ================================================================

fprintf('[8/8] Saving MAT file and numerical report...\n');

matFile = fullfile( ...
    outputDir, ...
    'YEHOSHUA_wavefunction_superposition_gradient_online_v2.mat');

save(matFile, 'R', '-v7.3');

%% ================================================================
%  15. SAVE TEXT REPORT
%  ================================================================

reportFile = fullfile( ...
    outputDir, ...
    'YEHOSHUA_wavefunction_superposition_gradient_report.txt');

fid = fopen(reportFile, 'w');

if fid < 0
    error('Could not create the numerical report.');
end

cleanupObject = onCleanup(@() fclose(fid));

fprintf(fid, ...
    'YEHOSHUA Wave-Function Superposition Gradient Report\n');

fprintf(fid, ...
    '===================================================\n\n');

fprintf(fid, ...
    'Version: %s\n', ...
    R.version);

fprintf(fid, ...
    'Source H5: %s\n', ...
    ssotFile);

fprintf(fid, ...
    'Dataset: %s\n', ...
    datasetPath);

fprintf(fid, ...
    'Output directory: %s\n\n', ...
    outputDir);

fprintf(fid, ...
    'Field size: %d x %d\n', ...
    ny, nx);

fprintf(fid, ...
    'Mixing angle: %.15g rad\n', ...
    mixingAngle);

fprintf(fid, ...
    'Relative phase: %.15g rad\n\n', ...
    relativePhase);

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
    'Overlap real: %.15g\n', ...
    metrics.overlap_real);

fprintf(fid, ...
    'Overlap imaginary: %.15g\n', ...
    metrics.overlap_imag);

fprintf(fid, ...
    'Overlap absolute: %.15g\n', ...
    metrics.overlap_absolute);

fprintf(fid, ...
    'Overlap phase: %.15g rad\n\n', ...
    metrics.overlap_phase);

fprintf(fid, ...
    'Mean input gradient: %.15g\n', ...
    metrics.input_gradient_mean);

fprintf(fid, ...
    'Maximum input gradient: %.15g\n\n', ...
    metrics.input_gradient_max);

fprintf(fid, ...
    'Mean wave-function gradient: %.15g\n', ...
    metrics.wave_gradient_mean);

fprintf(fid, ...
    'Maximum wave-function gradient: %.15g\n', ...
    metrics.wave_gradient_max);

fprintf(fid, ...
    'Gradient energy: %.15g\n\n', ...
    metrics.gradient_energy);

fprintf(fid, ...
    'Mean probability gradient: %.15g\n', ...
    metrics.probability_gradient_mean);

fprintf(fid, ...
    'Maximum probability gradient: %.15g\n\n', ...
    metrics.probability_gradient_max);

fprintf(fid, ...
    'Mean flow magnitude: %.15g\n', ...
    metrics.flow_mean);

fprintf(fid, ...
    'Maximum flow magnitude: %.15g\n\n', ...
    metrics.flow_max);

fprintf(fid, ...
    'Interference mean: %.15g\n', ...
    metrics.interference_mean);

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
%  16. FINAL SUMMARY
%  ================================================================

fprintf('\n');
fprintf('Processing completed successfully.\n\n');

fprintf('Saved files:\n');
fprintf('  04_probability_density.png\n');
fprintf('  05_wavefunction_gradient.png\n');
fprintf('  06_probability_gradient.png\n');
fprintf('  07_phase_flow_magnitude.png\n');
fprintf('  08_signed_interference.png\n');
fprintf('  09_phase_amplitude_rgb.png\n');
fprintf('  YEHOSHUA_wavefunction_superposition_gradient_online_v2.mat\n');
fprintf('  YEHOSHUA_wavefunction_superposition_gradient_report.txt\n\n');

fprintf('Integral of |psi|^2: %.12f\n', ...
    metrics.probability_integral);

fprintf('Superposition norm: %.12f\n', ...
    metrics.superposition_norm);

fprintf('Mean |grad psi|: %.12f\n', ...
    metrics.wave_gradient_mean);

fprintf('Interference energy: %.12f\n', ...
    metrics.interference_energy);

fprintf('Maximum residual: %.3e\n\n', ...
    metrics.superposition_residual_max);

fprintf('Output directory:\n%s\n\n', outputDir);

end

%% =================================================================
%  LOCAL FUNCTIONS
%  =================================================================

function X01 = normalize01(X)

X = double(real(X));

minimumValue = min(X(:));
maximumValue = max(X(:));

valueRange = ...
    maximumValue - minimumValue;

referenceScale = ...
    max(abs([minimumValue, maximumValue, 1]));

if valueRange <= eps(referenceScale)

    X01 = zeros(size(X));

else

    X01 = ...
        (X - minimumValue) ./ valueRange;

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
    abs(dx * dy));

end

function writeGray16(field, outputFile)

normalizedField = normalize01(field);

image16 = ...
    uint16(round(65535 .* normalizedField));

imwrite(image16, outputFile);

end