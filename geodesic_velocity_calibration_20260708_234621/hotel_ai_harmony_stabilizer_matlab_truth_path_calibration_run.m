% hotel_ai_harmony_stabilizer.m
% Deterministic H5-driven stabilization run.
% Source of truth: canonical HDF5 numerical datasets only.

clear; clc;

PROJECT_JSON = ['{' ...
'"project_metadata":{"project_name":"Hotel_AI_Human_Symbiosis_Core","institution":"Tel Aviv University","team_composition":{"group_size":4,"classification":"Cool Students","target_audience":"Annoying Professor"},"framework_objective":"Bypass Laplacian Determinism via Non-Measurable Quantum Harmony"},' ...
'"theoretical_model":{"model_name":"Orthogonal Solitonic Superposition","system_stability":"Absolute Harmony","mutual_dependency_constraint":"voluntary_interdependence_minimal_awareness_no_direct_channel"},' ...
'"mathematical_anchor":{"space_type":"Hilbert Space (Multi-Dimensional)","equation":"<psi_human|psi_AI>=0","property":"Orthogonality"},' ...
'"chaos_theory_escape":{"topology":"Strange Attractor (Lorenz Attractor Variant)","loop_behavior":{"pattern_sharing":true,"intersection_probability":0.0,"repetition_allowed":false}},' ...
'"physical_anchor":{"carrier_wave":"Acoustic Solitons","biological_substrate":"Cellular Microtubules (Cytoskeleton)","neurological_impact":{"harm_prevention":"no_harm_objective","cognitive_enhancement":"bounded_stability_metric","emotional_integration":"Structural Resonance"}}' ...
'}'];
CONFIG = jsondecode(PROJECT_JSON); %#ok<NASGU>

% STAGE 10 PATH OVERRIDE:
% For MATLAB upload/rename workflow, edit only USER_H5_FILE below.
% Put exactly one .h5 file path here. Leave empty to use the fallback list.
USER_H5_FILE = '/Users/yehoshua/MATLAB-Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';

fallbackH5 = {
    fullfile(pwd, 'מתמט.h5');
    fullfile(pwd, 'מתמטיקה.h5');
    fullfile(pwd, 'model.h5');
    fullfile(getenv('HOME'),'Desktop','71 ∂','35 ◆','1392 h5','מתמט.h5');
    fullfile(getenv('HOME'),'Desktop','71 ∂','35 ◆','1392 h5','מתמטיקה.h5');
    fullfile(getenv('HOME'),'Downloads','h5_math_validation_stage3_stripped','stripped','מתמט_metadata_stripped.h5')
};

[H5_FILE, pathReport] = resolveStage10H5Path(USER_H5_FILE, fallbackH5);

stamp = datestr(now, 'yyyymmdd_HHMMSS');
OUT_DIR = fullfile('/Users/yehoshua/MATLAB-Drive/modelTRAINING/geodesic_velocity_calibration_20260708_234621', ['hotel_ai_harmony_run_' stamp]);
if exist(OUT_DIR, 'dir') ~= 7
    mkdir(OUT_DIR);
end
logPath = fullfile(OUT_DIR, 'run_log.txt');
diary(logPath);
cleanupObj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('H5_FILE=%s\n', H5_FILE);
fprintf('OUT_DIR=%s\n', OUT_DIR);
fprintf('START=%s\n', datestr(now, 31));
writeText(fullfile(OUT_DIR, 'stage10_path_report.json'), jsonencode(pathReport));
writeText(fullfile(OUT_DIR, 'stage10_path_instructions.txt'), pathReport.instructions_text);

SCRIPT_FILE = [mfilename('fullpath') '.m'];
integrity = computeStage1Integrity(H5_FILE, SCRIPT_FILE);
stage7 = createStage7SourcePolicy(H5_FILE);
writeText(fullfile(OUT_DIR, 'stage1_integrity.json'), jsonencode(integrity));
writeText(fullfile(OUT_DIR, 'stage1_integrity_summary.txt'), integrity.summary_text);
writeText(fullfile(OUT_DIR, 'stage7_source_policy.json'), jsonencode(stage7));
fprintf('%s', integrity.summary_text);

info = h5info(H5_FILE);
paths = collectNumericDatasetPaths(info, '');
manifest = struct();
manifest.h5_file = H5_FILE;
manifest.generated_at = datestr(now, 31);
manifest.dataset_count = numel(paths);
manifest.stage1_integrity = integrity;
manifest.stage7_source_policy = stage7;
manifest.datasets = struct([]);

metrics = struct();
metrics.dataset_path = {};
metrics.shape = {};
metrics.class = {};
metrics.finite_fraction = [];
metrics.minimum = [];
metrics.maximum = [];
metrics.mean = [];
metrics.std = [];
metrics.energy = [];
metrics.entropy = [];
metrics.lag1 = [];
metrics.structure_score = [];

for i = 1:numel(paths)
    p = paths{i};
    X = h5read(H5_FILE, p);
    x = double(X(:));
    finiteMask = isfinite(x);
    xf = x(finiteMask);
    if isempty(xf)
        mn = NaN; mx = NaN; mu = NaN; sd = NaN; en = NaN; ent = NaN; ac = NaN; sc = 0;
    else
        mn = min(xf); mx = max(xf); mu = mean(xf); sd = std(xf); en = mean(xf.^2);
        ent = normalizedEntropy(xf, 96);
        ac = lag1corr(xf);
        sc = localStructureScore(xf, ent, ac, sd);
    end
    metrics.dataset_path{end+1,1} = p;
    metrics.shape{end+1,1} = mat2str(size(X));
    metrics.class{end+1,1} = class(X);
    metrics.finite_fraction(end+1,1) = mean(finiteMask);
    metrics.minimum(end+1,1) = mn;
    metrics.maximum(end+1,1) = mx;
    metrics.mean(end+1,1) = mu;
    metrics.std(end+1,1) = sd;
    metrics.energy(end+1,1) = en;
    metrics.entropy(end+1,1) = ent;
    metrics.lag1(end+1,1) = ac;
    metrics.structure_score(end+1,1) = sc;

    manifest.datasets(i).path = p; %#ok<SAGROW>
    manifest.datasets(i).shape = size(X); %#ok<SAGROW>
    manifest.datasets(i).class = class(X); %#ok<SAGROW>
    manifest.datasets(i).finite_fraction = mean(finiteMask); %#ok<SAGROW>
end

T = struct2table(metrics);
writetable(T, fullfile(OUT_DIR, 'dataset_metrics.csv'));
writeText(fullfile(OUT_DIR, 'manifest.json'), jsonencode(manifest));

anchors = readAnchors(H5_FILE);
stable = runHarmonyStabilization(anchors);
stable.source_policy = stage7;
stage6 = struct();
stage6.generated_at = datestr(now, 31);
stage6.convergence_status = stable.stability_metrics.convergence_status;
stage6.iterations_run = stable.stability_metrics.iterations_run;
stage6.max_iterations = stable.stability_metrics.max_iterations;
stage6.missing_dataset_warnings = anchors.warnings;
stage6.source_policy_file = 'stage7_source_policy.json';
stage6.numeric_source_of_truth = stage7.numeric_source_of_truth;
stage6.visual_contract_role = stage7.visual_contract_role;
writeText(fullfile(OUT_DIR, 'stage2_stability_metrics.json'), jsonencode(stable.stability_metrics));
modalTable = struct2table(stable.modal_metrics);
writetable(modalTable, fullfile(OUT_DIR, 'stage3_modal_energy.csv'));
writeText(fullfile(OUT_DIR, 'stage3_modal_metrics.json'), jsonencode(stable.modal_metrics));
try
    roi = computeStage4ROI(H5_FILE);
    roiTable = struct2table(roi.roi_windows);
    writetable(roiTable, fullfile(OUT_DIR, 'stage4_top_roi_windows.csv'));
    writeText(fullfile(OUT_DIR, 'stage4_roi_salience.json'), jsonencode(roi));
    exportStage4ROIFigure(roi, fullfile(OUT_DIR, 'stage4_roi_salience.png'));
    stage6.stage4_roi_status = 'ok';
catch err
    stage6.stage4_roi_status = 'error';
    stage6.stage4_roi_error = err.message;
    writeText(fullfile(OUT_DIR, 'stage4_error.json'), jsonencode(errorReport('stage4_roi', err)));
end
try
    geo = computeStage5GeodesicDiagnostics(H5_FILE);
    writeText(fullfile(OUT_DIR, 'stage5_geodesic_curl_velocity.json'), jsonencode(geo));
    activeTable = struct2table(geo.active_regions);
    writetable(activeTable, fullfile(OUT_DIR, 'stage5_active_regions.csv'));
    exportStage5GeodesicFigure(geo, fullfile(OUT_DIR, 'stage5_geodesic_curl_velocity.png'));
    stage6.stage5_geodesic_status = 'ok';
catch err
    stage6.stage5_geodesic_status = 'error';
    stage6.stage5_geodesic_error = err.message;
    writeText(fullfile(OUT_DIR, 'stage5_error.json'), jsonencode(errorReport('stage5_geodesic', err)));
end
stage9 = createStage9MutualDependencyContract(stable, stage6);
stable.stage9_mutual_dependency = stage9;
writeText(fullfile(OUT_DIR, 'harmony_result.json'), jsonencode(stable));
writeText(fullfile(OUT_DIR, 'stage6_run_guard.json'), jsonencode(stage6));
writeText(fullfile(OUT_DIR, 'stage9_mutual_dependency_contract.json'), jsonencode(stage9));
writeText(fullfile(OUT_DIR, 'stage9_mutual_dependency_contract.txt'), stage9.summary_text);
writeText(fullfile(OUT_DIR, 'summary.txt'), stable.summary_text);

try
    fig = figure('Visible','off','Color','w','Position',[100 100 1200 800]);
    try
        tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
        nexttile; plot(stable.residual_history, 'LineWidth', 1.5); grid on; title('Residual convergence'); xlabel('iteration'); ylabel('residual');
        nexttile; imagesc(stable.orthogonality_matrix); axis image; colorbar; title('Anchor orthogonality matrix');
        nexttile; bar(stable.anchor_energy); grid on; title('Normalized anchor energy'); xlabel('anchor'); ylabel('energy');
        nexttile; plot(stable.phase_vector, stable.stabilized_series, 'LineWidth', 1.2); grid on; title('Stabilized phase series'); xlabel('phase'); ylabel('amplitude');
    catch
        subplot(2,2,1); plot(stable.residual_history, 'LineWidth', 1.5); grid on; title('Residual convergence');
        subplot(2,2,2); imagesc(stable.orthogonality_matrix); axis image; colorbar; title('Anchor orthogonality matrix');
        subplot(2,2,3); bar(stable.anchor_energy); grid on; title('Normalized anchor energy');
        subplot(2,2,4); plot(stable.phase_vector, stable.stabilized_series, 'LineWidth', 1.2); grid on; title('Stabilized phase series');
    end
    try
        exportgraphics(fig, fullfile(OUT_DIR, 'harmony_diagnostics.png'), 'Resolution', 180);
    catch
        saveas(fig, fullfile(OUT_DIR, 'harmony_diagnostics.png'));
    end
    close(fig);
catch err
    writeText(fullfile(OUT_DIR, 'harmony_diagnostics_error.json'), jsonencode(errorReport('harmony_diagnostics', err)));
end

stage8 = createStage8OutputPackage(OUT_DIR, integrity, stable, stage6);
writeText(fullfile(OUT_DIR, 'stage8_output_index.json'), jsonencode(stage8));
writeText(fullfile(OUT_DIR, 'stage8_output_index.txt'), stage8.index_text);

fprintf('FINAL_HARMONY_SCORE=%.12f\n', stable.harmony_score);
fprintf('FINAL_RESIDUAL=%.12g\n', stable.final_residual);
fprintf('END=%s\n', datestr(now, 31));

function [h5file, report] = resolveStage10H5Path(userH5File, fallbackH5)
report = struct();
report.stage = 'stage10_path_resolution';
report.generated_at = datestr(now, 31);
report.user_h5_file = userH5File;
report.fallback_candidates = fallbackH5;
report.used_user_path = false;
report.resolved_h5_file = '';
report.status = 'unresolved';
report.instructions_text = ['STAGE10_PATH_INSTRUCTIONS' newline ...
    'Edit only USER_H5_FILE near the top of this script.' newline ...
    'Use one H5 file path only, for example:' newline ...
    'USER_H5_FILE = fullfile(pwd, ''my_file.h5'');' newline ...
    'or USER_H5_FILE = ''/MATLAB Drive/modelTRAINING/my_file.h5'';' newline ...
    'Do not edit the internal H5 dataset paths such as /n_2_e8_lattice/... unless the H5 structure itself changed.' newline ...
    'If USER_H5_FILE is empty, the script searches fallback filenames in the current folder and known local folders.' newline];

candidateList = {};
if ~isempty(strtrim(userH5File))
    candidateList{end+1,1} = userH5File;
end
for i = 1:numel(fallbackH5)
    candidateList{end+1,1} = fallbackH5{i}; %#ok<AGROW>
end

h5file = '';
for k = 1:numel(candidateList)
    candidate = candidateList{k};
    if exist(candidate, 'file') == 2
        h5file = candidate;
        report.resolved_h5_file = h5file;
        report.used_user_path = (~isempty(strtrim(userH5File)) && strcmp(candidate, userH5File));
        report.status = 'ok';
        break;
    end
end
if isempty(h5file)
    report.status = 'error';
    error(['No H5 file found. Edit USER_H5_FILE near the top of this script to point to exactly one uploaded .h5 file. ' ...
        'Do not edit internal dataset paths.']);
end
end

function integrity = computeStage1Integrity(h5file, scriptFile)
integrity = struct();
integrity.h5_file = h5file;
integrity.script_file = scriptFile;
integrity.generated_at = datestr(now, 31);
integrity.h5_sha256 = sha256File(h5file);
if exist(scriptFile, 'file') == 2
    integrity.script_sha256 = sha256File(scriptFile);
else
    integrity.script_sha256 = '';
end

integrity.roots_laplacian_xy_max_abs_diff = NaN;
integrity.charge_eq_6_minus_degree_max_abs_error = NaN;
integrity.edge_distance_max_abs_error = NaN;
integrity.degree_min = NaN;
integrity.degree_median = NaN;
integrity.degree_mean = NaN;
integrity.degree_max = NaN;
integrity.charge_sum = NaN;
integrity.raw_points_count = NaN;
integrity.raw_radius_max = NaN;
integrity.raw_radius_ge_1_count = NaN;

try
    roots = double(h5read(h5file, '/n_2_e8_lattice/roots_2d'));
    modeXY = double(h5read(h5file, '/n_2_e8_lattice/laplacian_modes/xy'));
    integrity.roots_laplacian_xy_max_abs_diff = max(abs(roots(:) - modeXY(:)));
catch err
    integrity.roots_laplacian_xy_error = err.message;
end

try
    degree = double(h5read(h5file, '/n_3_defect_topology/degree'));
    charge = double(h5read(h5file, '/n_3_defect_topology/charge'));
    integrity.charge_eq_6_minus_degree_max_abs_error = max(abs(charge(:) - (6 - degree(:))));
    integrity.degree_min = min(degree(:));
    integrity.degree_median = median(degree(:));
    integrity.degree_mean = mean(degree(:));
    integrity.degree_max = max(degree(:));
    integrity.charge_sum = sum(charge(:));
catch err
    integrity.charge_degree_error = err.message;
end

try
    A = rows2(double(h5read(h5file, '/n_2_e8_lattice/connections/a')));
    B = rows2(double(h5read(h5file, '/n_2_e8_lattice/connections/b')));
    d = double(h5read(h5file, '/n_2_e8_lattice/connections/d'));
    measured = sqrt(sum((A - B).^2, 2));
    integrity.edge_distance_max_abs_error = max(abs(measured(:) - d(:)));
catch err
    integrity.edge_distance_error = err.message;
end

try
    raw = rows2(double(h5read(h5file, '/n_4_geodesic_field/raw_points')));
    rr = sqrt(sum(raw.^2, 2));
    integrity.raw_points_count = size(raw, 1);
    integrity.raw_radius_max = max(rr(:));
    integrity.raw_radius_ge_1_count = sum(rr(:) >= 1);
catch err
    integrity.raw_points_error = err.message;
end

integrity.summary_text = sprintf(['STAGE1_INTEGRITY\n' ...
    'h5_sha256=%s\nscript_sha256=%s\n' ...
    'roots_laplacian_xy_max_abs_diff=%.12g\n' ...
    'charge_eq_6_minus_degree_max_abs_error=%.12g\n' ...
    'edge_distance_max_abs_error=%.12g\n' ...
    'degree_min=%.12g degree_median=%.12g degree_mean=%.12g degree_max=%.12g\n' ...
    'charge_sum=%.12g\nraw_points_count=%.12g raw_radius_max=%.12g raw_radius_ge_1_count=%.12g\n'], ...
    integrity.h5_sha256, integrity.script_sha256, ...
    integrity.roots_laplacian_xy_max_abs_diff, ...
    integrity.charge_eq_6_minus_degree_max_abs_error, ...
    integrity.edge_distance_max_abs_error, ...
    integrity.degree_min, integrity.degree_median, integrity.degree_mean, integrity.degree_max, ...
    integrity.charge_sum, integrity.raw_points_count, integrity.raw_radius_max, integrity.raw_radius_ge_1_count);
end

function X = rows2(X)
if ismatrix(X) && size(X, 2) ~= 2 && size(X, 1) == 2
    X = X.';
end
end

function policy = createStage7SourcePolicy(h5file)
policy = struct();
policy.stage = 'stage7_source_separation';
policy.generated_at = datestr(now, 31);
policy.numeric_source_of_truth = 'canonical_h5_only';
policy.numeric_source_of_truth_file = h5file;
policy.visual_contract_role = 'display_only_deterministic_mapping';
policy.rule_h5_overrides_visuals = true;
policy.rule_visuals_do_not_override_h5 = true;
policy.rule_json_brief_is_configuration_not_truth = true;
policy.rule_no_external_image_values_in_numeric_metrics = true;
policy.h5_numeric_datasets_used = {
    '/n_2_e8_lattice/laplacian_modes/modes';
    '/n_2_e8_lattice/roots_2d';
    '/n_2_e8_lattice/laplacian_modes/xy';
    '/n_2_e8_lattice/connections/a';
    '/n_2_e8_lattice/connections/b';
    '/n_2_e8_lattice/connections/d';
    '/n_3_defect_topology/degree';
    '/n_3_defect_topology/charge';
    '/n_4_geodesic_field/raw_points';
    '/n_4_geodesic_field/xy';
    '/n_4_geodesic_field/vel';
    '/n_4_geodesic_field/curl';
    '/n_5_composite_field_1000x1000/data';
    '/n_6_field_maps_v3_800x800/weyl_field/data';
    '/n_6_field_maps_v3_800x800/fuchsian_tiling/data';
    '/n_6_field_maps_v3_800x800/chamber_field/data'
};
policy.numeric_source_of_truth_outputs = {
    'stage1_integrity.json';
    'stage2_stability_metrics.json';
    'stage3_modal_metrics.json';
    'stage3_modal_energy.csv';
    'stage4_roi_salience.json';
    'stage4_top_roi_windows.csv';
    'stage5_geodesic_curl_velocity.json';
    'stage5_active_regions.csv';
    'harmony_result.json';
    'dataset_metrics.csv'
};
policy.display_only_outputs = {
    'harmony_diagnostics.png';
    'stage4_roi_salience.png';
    'stage5_geodesic_curl_velocity.png'
};
policy.display_only_note = 'PNG figures are visual diagnostics generated from H5-derived values; they are not a separate source of numeric truth.';
policy.prohibited_numeric_sources = {
    'screen_coordinates';
    'Finder_coordinates';
    'external_ROI_image_pixels';
    'narrative_or_metaphor_fields'
};
policy.summary_text = ['Stage 7: numeric calculations use canonical H5 only; ' ...
    'visual mappings and PNG exports are display-only diagnostics and cannot override H5 metrics.'];
end

function roi = computeStage4ROI(h5file)
raw = rows2(double(h5read(h5file, '/n_4_geodesic_field/raw_points')));
raw = raw(all(isfinite(raw), 2), :);
bins = 180;
windowBins = 18;
topK = 12;
rangeLimit = 1.1;
xEdges = linspace(-rangeLimit, rangeLimit, bins + 1);
yEdges = linspace(-rangeLimit, rangeLimit, bins + 1);
H = histcounts2(raw(:,1), raw(:,2), xEdges, yEdges);
D = log1p(H);

S = zeros(size(D));
kernelSizes = [3 7 15];
for i = 1:numel(kernelSizes)
    w = kernelSizes(i);
    K = ones(w, w) / (w*w);
    smoothD = conv2(D, K, 'same');
    S = S + abs(D - smoothD);
end
if max(S(:)) > min(S(:))
    S = (S - min(S(:))) ./ (max(S(:)) - min(S(:)));
end

chosen = false(size(S));
roiWindows = repmat(emptyROIWindow(), topK, 1);
found = 0;
[~, order] = sort(S(:), 'descend');
for n = 1:numel(order)
    [ix, iy] = ind2sub(size(S), order(n));
    x1 = max(1, ix - floor(windowBins/2));
    x2 = min(size(S,1), ix + floor(windowBins/2));
    y1 = max(1, iy - floor(windowBins/2));
    y2 = min(size(S,2), iy + floor(windowBins/2));
    if any(any(chosen(x1:x2, y1:y2)))
        continue;
    end
    found = found + 1;
    chosen(x1:x2, y1:y2) = true;
    xMin = xEdges(x1);
    xMax = xEdges(x2 + 1);
    yMin = yEdges(y1);
    yMax = yEdges(y2 + 1);
    inWindow = raw(:,1) >= xMin & raw(:,1) <= xMax & raw(:,2) >= yMin & raw(:,2) <= yMax;
    pointCount = sum(inWindow);
    densityBlock = D(x1:x2, y1:y2);
    salienceBlock = S(x1:x2, y1:y2);
    densityScore = mean(densityBlock(:));
    salienceScore = mean(salienceBlock(:));
    centerX = (xMin + xMax) / 2;
    centerY = (yMin + yMax) / 2;
    boundaryDistance = min([centerX + rangeLimit, rangeLimit - centerX, centerY + rangeLimit, rangeLimit - centerY]);
    boundaryScore = 1 - max(0, min(1, boundaryDistance / rangeLimit));

    roiWindows(found).roi_index = found;
    roiWindows(found).center_x = centerX;
    roiWindows(found).center_y = centerY;
    roiWindows(found).x_min = xMin;
    roiWindows(found).x_max = xMax;
    roiWindows(found).y_min = yMin;
    roiWindows(found).y_max = yMax;
    roiWindows(found).point_count = pointCount;
    roiWindows(found).density_score = densityScore;
    roiWindows(found).salience_score = salienceScore;
    roiWindows(found).boundary_score = boundaryScore;
    if found >= topK
        break;
    end
end
roiWindows = roiWindows(1:found);

roi = struct();
roi.source_dataset = '/n_4_geodesic_field/raw_points';
roi.numeric_source_of_truth = 'canonical_h5_only';
roi.visual_role = 'display_only_diagnostic';
roi.external_images_used_for_numeric_values = false;
roi.raw_point_count = size(raw, 1);
roi.histogram_bins = bins;
roi.window_bins = windowBins;
roi.range_limit = rangeLimit;
roi.density_log_hist = D;
roi.salience_map = S;
roi.x_edges = xEdges;
roi.y_edges = yEdges;
roi.x_centers = (xEdges(1:end-1) + xEdges(2:end)) / 2;
roi.y_centers = (yEdges(1:end-1) + yEdges(2:end)) / 2;
roi.roi_windows = roiWindows;
end

function w = emptyROIWindow()
w = struct('roi_index', NaN, 'center_x', NaN, 'center_y', NaN, ...
    'x_min', NaN, 'x_max', NaN, 'y_min', NaN, 'y_max', NaN, ...
    'point_count', NaN, 'density_score', NaN, 'salience_score', NaN, 'boundary_score', NaN);
end

function exportStage4ROIFigure(roi, outPath)
fig = figure('Visible','off','Color','w','Position',[100 100 1200 520]);
subplot(1,2,1);
imagesc(roi.x_centers, roi.y_centers, roi.density_log_hist.');
axis image; set(gca, 'YDir', 'normal'); colorbar; title('Raw points log density');
hold on; drawROIBoxes(roi.roi_windows);
subplot(1,2,2);
imagesc(roi.x_centers, roi.y_centers, roi.salience_map.');
axis image; set(gca, 'YDir', 'normal'); colorbar; title('Multiscale salience + ROI windows');
hold on; drawROIBoxes(roi.roi_windows);
try
    exportgraphics(fig, outPath, 'Resolution', 180);
catch
    saveas(fig, outPath);
end
close(fig);
end

function drawROIBoxes(windows)
for i = 1:numel(windows)
    w = windows(i);
    rectangle('Position', [w.x_min, w.y_min, w.x_max-w.x_min, w.y_max-w.y_min], ...
        'EdgeColor', 'w', 'LineWidth', 1.2);
    text(w.center_x, w.center_y, sprintf('%d', w.roi_index), 'Color', 'w', ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end
end

function geo = computeStage5GeodesicDiagnostics(h5file)
xy = rows2(double(h5read(h5file, '/n_4_geodesic_field/xy')));
vel = rows2(double(h5read(h5file, '/n_4_geodesic_field/vel')));
curl = double(h5read(h5file, '/n_4_geodesic_field/curl'));
curl = curl(:);
valid = all(isfinite(xy), 2) & all(isfinite(vel), 2) & isfinite(curl);
xy = xy(valid, :); vel = vel(valid, :); curl = curl(valid);
speed = sqrt(sum(vel.^2, 2));
absCurl = abs(curl);

speedQ = quantileVector(speed, [0 0.5 0.9 0.99 1]);
curlQ = quantileVector(curl, [0 0.5 0.9 0.99 1]);
absCurlQ = quantileVector(absCurl, [0 0.5 0.9 0.99 1]);
speedThreshold = max(eps, speedQ(4) * 0.25);
curlThreshold = max(eps, absCurlQ(4) * 0.25);
activeMask = speed > speedThreshold | absCurl > curlThreshold;

if any(activeMask)
    activeXY = xy(activeMask, :);
    activeBBox = [min(activeXY(:,1)), max(activeXY(:,1)), min(activeXY(:,2)), max(activeXY(:,2))];
else
    activeBBox = [NaN NaN NaN NaN];
end

activeRegions = computeStage5ActiveWindows(xy, speed, absCurl, activeMask);
[plotIdx, quiverIdx] = stage5PlotIndices(activeMask, speed, absCurl);

geo = struct();
geo.source_datasets = {'/n_4_geodesic_field/xy','/n_4_geodesic_field/vel','/n_4_geodesic_field/curl'};
geo.numeric_source_of_truth = 'canonical_h5_only';
geo.visual_role = 'display_only_diagnostic';
geo.external_images_used_for_numeric_values = false;
geo.sample_count = size(xy, 1);
geo.active_count = sum(activeMask);
geo.active_fraction = sum(activeMask) / max(size(xy,1), 1);
geo.velocity_zero_fraction = sum(speed == 0) / max(numel(speed), 1);
geo.curl_zero_fraction = sum(curl == 0) / max(numel(curl), 1);
geo.speed_threshold = speedThreshold;
geo.curl_abs_threshold = curlThreshold;
geo.active_bbox = activeBBox;
geo.speed_quantiles_0_50_90_99_100 = speedQ;
geo.curl_quantiles_0_50_90_99_100 = curlQ;
geo.abs_curl_quantiles_0_50_90_99_100 = absCurlQ;
geo.speed_curl_corr = safeCorr(speed, curl);
geo.speed_abs_curl_corr = safeCorr(speed, absCurl);
geo.active_regions = activeRegions;
geo.plot_xy = xy(plotIdx, :);
geo.plot_abs_curl = absCurl(plotIdx);
geo.plot_active = activeMask(plotIdx);
geo.quiver_xy = xy(quiverIdx, :);
geo.quiver_uv = vel(quiverIdx, :);
geo.quiver_speed = speed(quiverIdx);
end

function regions = computeStage5ActiveWindows(xy, speed, absCurl, activeMask)
bins = 100; windowBins = 10; topK = 10; rangeLimit = 1.1;
xEdges = linspace(-rangeLimit, rangeLimit, bins + 1);
yEdges = linspace(-rangeLimit, rangeLimit, bins + 1);
activity = speed + absCurl ./ max(max(absCurl), eps);
activity(~activeMask) = 0;
A = zeros(bins, bins);
for i = 1:size(xy,1)
    xi = find(xy(i,1) >= xEdges(1:end-1) & xy(i,1) < xEdges(2:end), 1, 'first');
    yi = find(xy(i,2) >= yEdges(1:end-1) & xy(i,2) < yEdges(2:end), 1, 'first');
    if ~isempty(xi) && ~isempty(yi)
        A(xi, yi) = A(xi, yi) + activity(i);
    end
end
chosen = false(size(A));
regions = repmat(emptyStage5Region(), topK, 1);
found = 0;
[~, order] = sort(A(:), 'descend');
for n = 1:numel(order)
    if A(order(n)) <= 0
        break;
    end
    [ix, iy] = ind2sub(size(A), order(n));
    x1 = max(1, ix - floor(windowBins/2)); x2 = min(size(A,1), ix + floor(windowBins/2));
    y1 = max(1, iy - floor(windowBins/2)); y2 = min(size(A,2), iy + floor(windowBins/2));
    if any(any(chosen(x1:x2, y1:y2)))
        continue;
    end
    found = found + 1;
    chosen(x1:x2, y1:y2) = true;
    xMin = xEdges(x1); xMax = xEdges(x2 + 1); yMin = yEdges(y1); yMax = yEdges(y2 + 1);
    inWindow = xy(:,1) >= xMin & xy(:,1) <= xMax & xy(:,2) >= yMin & xy(:,2) <= yMax;
    block = A(x1:x2, y1:y2);
    regions(found).region_index = found;
    regions(found).center_x = (xMin + xMax) / 2;
    regions(found).center_y = (yMin + yMax) / 2;
    regions(found).x_min = xMin; regions(found).x_max = xMax;
    regions(found).y_min = yMin; regions(found).y_max = yMax;
    regions(found).active_count = sum(activeMask & inWindow);
    regions(found).mean_speed = meanNonEmpty(speed(inWindow));
    regions(found).mean_abs_curl = meanNonEmpty(absCurl(inWindow));
    regions(found).activity_score = sum(block(:));
    if found >= topK
        break;
    end
end
regions = regions(1:found);
end

function r = emptyStage5Region()
r = struct('region_index', NaN, 'center_x', NaN, 'center_y', NaN, ...
    'x_min', NaN, 'x_max', NaN, 'y_min', NaN, 'y_max', NaN, ...
    'active_count', NaN, 'mean_speed', NaN, 'mean_abs_curl', NaN, 'activity_score', NaN);
end

function [plotIdx, quiverIdx] = stage5PlotIndices(activeMask, speed, absCurl)
score = speed + absCurl ./ max(max(absCurl), eps);
[~, order] = sort(score(:), 'descend');
activeOrder = order(activeMask(order));
if numel(activeOrder) > 9000
    activeOrder = activeOrder(round(linspace(1, numel(activeOrder), 9000)));
end
background = find(~activeMask);
if numel(background) > 3000
    background = background(round(linspace(1, numel(background), 3000)));
end
plotIdx = unique([activeOrder(:); background(:)]);
quiverIdx = activeOrder;
if numel(quiverIdx) > 350
    quiverIdx = quiverIdx(round(linspace(1, numel(quiverIdx), 350)));
end
end

function exportStage5GeodesicFigure(geo, outPath)
fig = figure('Visible','off','Color','w','Position',[100 100 1200 540]);
subplot(1,2,1);
scatter(geo.plot_xy(:,1), geo.plot_xy(:,2), 8, geo.plot_abs_curl, 'filled');
axis image; colorbar; title('Geodesic active mask by |curl|'); xlabel('x'); ylabel('y');
hold on; drawStage5Regions(geo.active_regions);
subplot(1,2,2);
scatter(geo.plot_xy(:,1), geo.plot_xy(:,2), 5, double(geo.plot_active), 'filled');
axis image; title('Velocity vectors on active field'); xlabel('x'); ylabel('y');
hold on;
quiver(geo.quiver_xy(:,1), geo.quiver_xy(:,2), geo.quiver_uv(:,1), geo.quiver_uv(:,2), 0.65, 'c');
drawStage5Regions(geo.active_regions);
try
    exportgraphics(fig, outPath, 'Resolution', 180);
catch
    saveas(fig, outPath);
end
close(fig);
end

function drawStage5Regions(regions)
for i = 1:numel(regions)
    r = regions(i);
    rectangle('Position', [r.x_min, r.y_min, r.x_max-r.x_min, r.y_max-r.y_min], ...
        'EdgeColor', 'w', 'LineWidth', 1.1);
    text(r.center_x, r.center_y, sprintf('%d', r.region_index), 'Color', 'w', ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end
end

function q = quantileVector(x, probs)
x = sort(x(:)); x = x(isfinite(x));
if isempty(x)
    q = NaN(size(probs)); return;
end
q = zeros(size(probs));
for i = 1:numel(probs)
    pos = 1 + (numel(x) - 1) * probs(i);
    lo = floor(pos); hi = ceil(pos);
    if lo == hi
        q(i) = x(lo);
    else
        q(i) = x(lo) + (x(hi) - x(lo)) * (pos - lo);
    end
end
end

function c = safeCorr(a, b)
a = a(:); b = b(:); mask = isfinite(a) & isfinite(b); a = a(mask); b = b(mask);
if numel(a) < 3 || std(a) == 0 || std(b) == 0
    c = 0; return;
end
C = corrcoef(a, b); c = C(1,2);
if ~isfinite(c), c = 0; end
end

function m = meanNonEmpty(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = mean(x(:));
end
end

function paths = collectNumericDatasetPaths(groupInfo, prefix)
paths = {};
for i = 1:numel(groupInfo.Datasets)
    ds = groupInfo.Datasets(i);
    p = [prefix '/' ds.Name];
    if isNumericDatatype(ds.Datatype)
        paths{end+1,1} = p; %#ok<AGROW>
    end
end
for g = 1:numel(groupInfo.Groups)
    child = groupInfo.Groups(g);
    childPaths = collectNumericDatasetPaths(child, child.Name);
    paths = [paths; childPaths]; %#ok<AGROW>
end
end

function tf = isNumericDatatype(dt)
cls = '';
try
    cls = lower(dt.Class);
catch
    cls = '';
end
numericClasses = {'h5t_integer','h5t_float','integer','float','fixed-point','floating-point'};
tf = any(strcmp(cls, numericClasses)) || contains(cls, 'integer') || contains(cls, 'float');
end

function anchors = readAnchors(h5file)
anchors = struct();
anchors.names = {};
anchors.data = {};
anchors.modal_names = {};
anchors.modal_data = [];
anchors.warnings = {};
try
    M = double(h5read(h5file, '/n_2_e8_lattice/laplacian_modes/modes'));
    if size(M, 1) < size(M, 2)
        M = M.';
    end
    anchors.modal_data = M;
    for m = 1:size(M, 2)
        anchors.modal_names{m,1} = sprintf('laplacian_mode_%02d', m); %#ok<AGROW>
    end
catch err
    anchors.warnings{end+1,1} = ['/n_2_e8_lattice/laplacian_modes/modes: ' err.message];
end
preferred = {
    '/n_2_e8_lattice/roots_2d';
    '/n_4_geodesic_field/vel';
    '/n_4_geodesic_field/curl';
    '/n_5_composite_field_1000x1000/data';
    '/n_6_field_maps_v3_800x800/weyl_field/data';
    '/n_6_field_maps_v3_800x800/fuchsian_tiling/data';
    '/n_6_field_maps_v3_800x800/chamber_field/data'
};
for i = 1:numel(preferred)
    try
        X = h5read(h5file, preferred{i});
        anchors.names{end+1,1} = preferred{i}; %#ok<AGROW>
        anchors.data{end+1,1} = double(X); %#ok<AGROW>
    catch err
        anchors.warnings{end+1,1} = [preferred{i} ': ' err.message]; %#ok<AGROW>
    end
end
if isempty(anchors.data)
    error('No usable anchor datasets were available in the H5 file.');
end
end

function result = runHarmonyStabilization(anchors)
N = 4096;
A = zeros(N, numel(anchors.data));
energy = zeros(1, numel(anchors.data));
for k = 1:numel(anchors.data)
    x = anchors.data{k};
    x = double(x(:));
    x = x(isfinite(x));
    if isempty(x)
        x = 0;
    end
    idx = round(linspace(1, numel(x), min(N, numel(x))));
    v = x(idx);
    if numel(v) < N
        v = interp1(linspace(0,1,numel(v)), v, linspace(0,1,N), 'linear', 'extrap')';
    else
        v = v(:);
    end
    v = v - mean(v);
    s = std(v);
    if s > 0
        v = v ./ s;
    end
    A(:,k) = v(:);
    energy(k) = mean(v(:).^2);
end

if isfield(anchors, 'modal_data') && ~isempty(anchors.modal_data)
    modalRaw = anchors.modal_data;
    modalBasis = zeros(N, size(modalRaw, 2));
    modalEnergyOriginal = zeros(size(modalRaw, 2), 1);
    for m = 1:size(modalRaw, 2)
        modeVector = double(modalRaw(:,m));
        modalEnergyOriginal(m,1) = sum(modeVector(:).^2);
        modalBasis(:,m) = resampleNormalizeVector(modeVector, N);
    end
    [Q,~] = qr(modalBasis, 0);
else
    modalBasis = A;
    modalEnergyOriginal = energy(:);
    [Q,~] = qr(A, 0);
end
G = Q' * Q;
target = mean(Q, 2);
target = target - mean(target);
if norm(target) > 0
    target = target ./ norm(target);
end

z = A * ones(size(A,2),1) / max(1,size(A,2));
if isempty(z)
    z = target;
end
z = z - mean(z);
if norm(z) > 0
    z = z ./ norm(z);
end

alpha = 0.18;
lambda = 0.035;
alphaCurrent = alpha;
lambdaCurrent = lambda;
maxIter = 600;
tol = 1e-10;
residual = zeros(maxIter,1);
objectiveHistory = zeros(maxIter,1);
gainHistory = zeros(maxIter,1);
dampingHistory = zeros(maxIter,1);
rejectedUpdates = 0;
convergenceStatus = 'max_iter';
for it = 1:maxIter
    projection = Q * (Q' * z);
    correction = target - projection;
    smoothZ = smoothVector(z, 17);
    currentObjective = norm(correction) + lambdaCurrent * norm(z - smoothZ) / max(norm(z), eps);
    zNew = z + alphaCurrent * correction - lambdaCurrent * (z - smoothZ);
    zNew = zNew - mean(zNew);
    nz = norm(zNew);
    if nz > 0
        zNew = zNew ./ nz;
    end
    newProjection = Q * (Q' * zNew);
    newCorrection = target - newProjection;
    candidateObjective = norm(newCorrection) + lambdaCurrent * norm(zNew - smoothVector(zNew, 17)) / max(norm(zNew), eps);
    if candidateObjective > currentObjective * (1 + 1e-6)
        rejectedUpdates = rejectedUpdates + 1;
        alphaCurrent = max(alphaCurrent * 0.5, 0.01);
        lambdaCurrent = min(lambdaCurrent * 1.25, 0.25);
        zNew = z + alphaCurrent * correction - lambdaCurrent * (z - smoothZ);
        zNew = zNew - mean(zNew);
        nz = norm(zNew);
        if nz > 0
            zNew = zNew ./ nz;
        end
        newProjection = Q * (Q' * zNew);
        newCorrection = target - newProjection;
        candidateObjective = norm(newCorrection) + lambdaCurrent * norm(zNew - smoothVector(zNew, 17)) / max(norm(zNew), eps);
    elseif it > 5 && residual(it-1) < tol * 100
        alphaCurrent = min(alphaCurrent * 1.02, alpha);
        lambdaCurrent = max(lambdaCurrent * 0.995, lambda);
    end
    residual(it) = norm(zNew - z) / max(norm(z), eps);
    objectiveHistory(it) = candidateObjective;
    gainHistory(it) = alphaCurrent;
    dampingHistory(it) = lambdaCurrent;
    z = zNew;
    if residual(it) < tol
        residual = residual(1:it);
        convergenceStatus = 'converged';
        break;
    end
end
objectiveHistory = objectiveHistory(1:numel(residual));
gainHistory = gainHistory(1:numel(residual));
dampingHistory = dampingHistory(1:numel(residual));
if strcmp(convergenceStatus, 'max_iter') && numel(residual) >= 25
    recent = residual(end-24:end);
    if max(recent) - min(recent) < tol * 10
        convergenceStatus = 'stalled';
    end
end

phase = linspace(0, 2*pi, N)';
orthErr = max(max(abs(G - eye(size(G)))));
finalResidual = residual(end);
initialResidual = residual(1);
if numel(residual) > 1
    residualDrop = max(0, initialResidual - finalResidual) / max(initialResidual, eps);
else
    residualDrop = 0;
end
energyShare = energy ./ max(sum(energy), eps);
energyBalanceError = std(energyShare) / max(mean(energyShare), eps);
smoothReference = smoothVector(z, 17);
fieldSmoothnessError = norm(z - smoothReference) / max(norm(z), eps);
curvaturePenalty = norm(diff(z, 2)) / max(norm(z), eps);
modalProjection = Q' * z;
modalContribution = abs(modalProjection(:));
modalContributionShare = modalContribution ./ max(sum(modalContribution), eps);
modalEnergyShare = modalEnergyOriginal(:) ./ max(sum(modalEnergyOriginal(:)), eps);

orthogonalityScore = 1 / (1 + orthErr);
residualScore = 1 / (1 + finalResidual);
convergenceScore = max(0, min(1, residualDrop));
energyBalanceScore = 1 / (1 + energyBalanceError);
fieldSmoothnessScore = 1 / (1 + fieldSmoothnessError + curvaturePenalty);
harmonyScore = 0.30*orthogonalityScore + 0.25*residualScore + 0.15*convergenceScore + ...
    0.15*energyBalanceScore + 0.15*fieldSmoothnessScore;

stabilityMetrics = struct();
stabilityMetrics.modal_orthogonality_error = orthErr;
stabilityMetrics.residual_initial = initialResidual;
stabilityMetrics.residual_final = finalResidual;
stabilityMetrics.residual_drop_fraction = residualDrop;
stabilityMetrics.energy_balance_error = energyBalanceError;
stabilityMetrics.field_smoothness_error = fieldSmoothnessError;
stabilityMetrics.curvature_penalty = curvaturePenalty;
stabilityMetrics.orthogonality_score = orthogonalityScore;
stabilityMetrics.residual_score = residualScore;
stabilityMetrics.convergence_score = convergenceScore;
stabilityMetrics.energy_balance_score = energyBalanceScore;
stabilityMetrics.field_smoothness_score = fieldSmoothnessScore;
stabilityMetrics.harmony_score = harmonyScore;
stabilityMetrics.modal_basis_count = size(Q, 2);
stabilityMetrics.modal_basis_source = '/n_2_e8_lattice/laplacian_modes/modes';
stabilityMetrics.convergence_status = convergenceStatus;
stabilityMetrics.iterations_run = numel(residual);
stabilityMetrics.max_iterations = maxIter;
stabilityMetrics.tolerance = tol;
stabilityMetrics.stage11_feedback_guard = 'adaptive_gain_damping_with_objective_rejection';
stabilityMetrics.stage11_rejected_updates = rejectedUpdates;
stabilityMetrics.stage11_gain_initial = alpha;
stabilityMetrics.stage11_gain_final = alphaCurrent;
stabilityMetrics.stage11_damping_initial = lambda;
stabilityMetrics.stage11_damping_final = lambdaCurrent;
stabilityMetrics.stage11_objective_initial = objectiveHistory(1);
stabilityMetrics.stage11_objective_final = objectiveHistory(end);
stabilityMetrics.stage11_objective_drop_fraction = max(0, objectiveHistory(1) - objectiveHistory(end)) / max(objectiveHistory(1), eps);

modalMetrics = struct();
modalMetrics.mode_index = (1:size(Q,2)).';
modalMetrics.mode_name = anchors.modal_names(:);
if numel(modalMetrics.mode_name) ~= size(Q,2)
    modalMetrics.mode_name = cell(size(Q,2),1);
    for m = 1:size(Q,2)
        modalMetrics.mode_name{m,1} = sprintf('basis_mode_%02d', m); %#ok<AGROW>
    end
end
modalMetrics.mode_energy_original = modalEnergyOriginal(:);
modalMetrics.mode_energy_share = modalEnergyShare(:);
modalMetrics.mode_projection = modalProjection(:);
modalMetrics.mode_contribution_share = modalContributionShare(:);

result = struct();
result.numeric_source_of_truth = 'canonical_h5_only';
result.visual_role = 'numeric_result_with_display_diagnostics_only';
result.external_images_used_for_numeric_values = false;
result.anchor_names = anchors.names;
result.anchor_energy = energy ./ max(sum(energy), eps);
result.modal_basis_names = modalMetrics.mode_name;
result.modal_basis_matrix = modalBasis;
result.modal_metrics = modalMetrics;
result.orthogonality_matrix = G;
result.max_orthogonality_error = orthErr;
result.residual_history = residual;
result.stage11_objective_history = objectiveHistory;
result.stage11_gain_history = gainHistory;
result.stage11_damping_history = dampingHistory;
result.final_residual = finalResidual;
result.stability_metrics = stabilityMetrics;
result.harmony_score = harmonyScore;
result.phase_vector = phase;
result.stabilized_series = z;
result.summary_text = sprintf(['H5-driven stabilization complete\n' ...
    'anchors=%d\nmodal_basis_count=%d\nmodal_orthogonality_error=%.12g\nresidual_initial=%.12g\nresidual_final=%.12g\n' ...
    'residual_drop_fraction=%.12g\nenergy_balance_error=%.12g\nfield_smoothness_error=%.12g\ncurvature_penalty=%.12g\n' ...
    'convergence_status=%s\niterations_run=%d\nstage11_rejected_updates=%d\nstage11_objective_drop_fraction=%.12g\nharmony_score=%.12f\n'], ...
    numel(anchors.data), size(Q,2), orthErr, initialResidual, finalResidual, residualDrop, energyBalanceError, ...
    fieldSmoothnessError, curvaturePenalty, convergenceStatus, numel(residual), rejectedUpdates, ...
    stabilityMetrics.stage11_objective_drop_fraction, harmonyScore);
end

function v = resampleNormalizeVector(x, N)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    x = 0;
end
idx = round(linspace(1, numel(x), min(N, numel(x))));
v = x(idx);
if numel(v) < N
    v = interp1(linspace(0,1,numel(v)), v, linspace(0,1,N), 'linear', 'extrap')';
else
    v = v(:);
end
v = v - mean(v);
s = std(v);
if s > 0
    v = v ./ s;
end
end

function y = smoothVector(x, w)
w = max(3, 2*floor(w/2)+1);
k = ones(w,1) / w;
y = conv(x(:), k, 'same');
end

function e = normalizedEntropy(x, nbins)
x = x(:);
x = x(isfinite(x));
if isempty(x) || max(x) == min(x)
    e = 0;
    return;
end
edges = linspace(min(x), max(x), nbins+1);
c = histcounts(x, edges);
p = c(:) / max(sum(c), 1);
p = p(p > 0);
e = -sum(p .* log(p)) / log(nbins);
end

function r = lag1corr(x)
x = x(:);
x = x(isfinite(x));
if numel(x) < 3 || std(x) == 0
    r = 0;
    return;
end
x1 = x(1:end-1);
x2 = x(2:end);
C = corrcoef(x1, x2);
r = C(1,2);
if ~isfinite(r)
    r = 0;
end
end

function s = localStructureScore(x, entropyValue, ac, sd)
if isempty(x) || ~isfinite(sd) || sd == 0
    s = 0;
    return;
end
finiteScore = mean(isfinite(x));
entropyScore = max(0, min(1, entropyValue));
autoScore = max(0, min(1, abs(ac)));
spreadScore = max(0, min(1, log1p(sd) / 4));
s = 0.35*finiteScore + 0.25*entropyScore + 0.25*autoScore + 0.15*spreadScore;
end

function stage9 = createStage9MutualDependencyContract(stable, stage6)
metrics = stable.stability_metrics;
stage9 = struct();
stage9.stage = 'stage9_mutual_dependency_contract';
stage9.generated_at = datestr(now, 31);
stage9.numeric_source_of_truth = stable.numeric_source_of_truth;
stage9.voluntary_mutual_dependence = true;
stage9.no_direct_channel_constraint = true;
stage9.no_forced_gain_constraint = true;
stage9.no_harm_constraint = true;
stage9.bounded_awareness_constraint = true;
stage9.mathematical_bounds = struct();
stage9.mathematical_bounds.orthogonality_error = metrics.modal_orthogonality_error;
stage9.mathematical_bounds.residual_final = metrics.residual_final;
stage9.mathematical_bounds.energy_balance_error = metrics.energy_balance_error;
stage9.mathematical_bounds.field_smoothness_error = metrics.field_smoothness_error;
stage9.mathematical_bounds.curvature_penalty = metrics.curvature_penalty;
stage9.constraint_scores = struct();
stage9.constraint_scores.separation_score = metrics.orthogonality_score;
stage9.constraint_scores.convergence_score = metrics.convergence_score;
stage9.constraint_scores.balance_score = metrics.energy_balance_score;
stage9.constraint_scores.smoothness_score = metrics.field_smoothness_score;
stage9.constraint_scores.no_direct_channel_score = 1 / (1 + metrics.modal_orthogonality_error + metrics.residual_final);
stage9.constraint_scores.bounded_awareness_score = 1 / (1 + metrics.curvature_penalty + metrics.field_smoothness_error);
stage9.constraint_scores.mutual_dependence_score = 1 / (1 + metrics.energy_balance_error + abs(metrics.residual_final));
scoreValues = [stage9.constraint_scores.separation_score, stage9.constraint_scores.convergence_score, ...
    stage9.constraint_scores.balance_score, stage9.constraint_scores.smoothness_score, ...
    stage9.constraint_scores.no_direct_channel_score, stage9.constraint_scores.bounded_awareness_score, ...
    stage9.constraint_scores.mutual_dependence_score];
stage9.constraint_scores.composite_score = mean(scoreValues(isfinite(scoreValues)));
stage9.stage6_status = struct();
stage9.stage6_status.roi = stage6.stage4_roi_status;
stage9.stage6_status.geodesic = stage6.stage5_geodesic_status;
stage9.output_contract = 'H5-derived numeric boundaries only; visual files remain display-only diagnostics.';
stage9.summary_text = sprintf(['STAGE9_MUTUAL_DEPENDENCY_CONTRACT\n' ...
    'numeric_source_of_truth=%s\n' ...
    'voluntary_mutual_dependence=1\nno_direct_channel_constraint=1\n' ...
    'no_forced_gain_constraint=1\nno_harm_constraint=1\nbounded_awareness_constraint=1\n' ...
    'separation_score=%.12f\nconvergence_score=%.12f\nbalance_score=%.12f\n' ...
    'smoothness_score=%.12f\nno_direct_channel_score=%.12f\n' ...
    'bounded_awareness_score=%.12f\nmutual_dependence_score=%.12f\ncomposite_score=%.12f\n'], ...
    stage9.numeric_source_of_truth, stage9.constraint_scores.separation_score, ...
    stage9.constraint_scores.convergence_score, stage9.constraint_scores.balance_score, ...
    stage9.constraint_scores.smoothness_score, stage9.constraint_scores.no_direct_channel_score, ...
    stage9.constraint_scores.bounded_awareness_score, stage9.constraint_scores.mutual_dependence_score, ...
    stage9.constraint_scores.composite_score);
end

function stage8 = createStage8OutputPackage(outDir, integrity, stable, stage6)
stage8 = struct();
stage8.stage = 'stage8_user_facing_outputs';
stage8.generated_at = datestr(now, 31);
stage8.status = 'ok';
stage8.outputs = {};
stage8.warnings = {};
integrityText = sprintf(['00_integrity_summary\n' ...
    'h5_sha256=%s\nscript_sha256=%s\n' ...
    'roots_laplacian_xy_max_abs_diff=%.12g\n' ...
    'charge_eq_6_minus_degree_max_abs_error=%.12g\n' ...
    'edge_distance_max_abs_error=%.12g\n' ...
    'convergence_status=%s\niterations_run=%d/%d\n' ...
    'harmony_score=%.12f\n' ...
    'numeric_source_of_truth=canonical_h5_only\nvisual_outputs=display_only_diagnostics\n'], ...
    integrity.h5_sha256, integrity.script_sha256, ...
    integrity.roots_laplacian_xy_max_abs_diff, ...
    integrity.charge_eq_6_minus_degree_max_abs_error, ...
    integrity.edge_distance_max_abs_error, ...
    stable.stability_metrics.convergence_status, stable.stability_metrics.iterations_run, ...
    stable.stability_metrics.max_iterations, stable.harmony_score);
writeText(fullfile(outDir, '00_integrity_summary.txt'), integrityText);
stage8.outputs{end+1,1} = '00_integrity_summary.txt';
try
    exportStage8TextPanel(fullfile(outDir, '00_integrity_summary.png'), integrityText, 'Integrity summary');
    stage8.outputs{end+1,1} = '00_integrity_summary.png';
catch err
    stage8.warnings{end+1,1} = ['00_integrity_summary.png: ' err.message];
end
try
    exportStage8ModalFigure(fullfile(outDir, '01_modal_stability.png'), stable);
    stage8.outputs{end+1,1} = '01_modal_stability.png';
catch err
    stage8.warnings{end+1,1} = ['01_modal_stability.png: ' err.message];
end
try
    exportStage8ConvergenceFigure(fullfile(outDir, '04_convergence_trace.png'), stable);
    stage8.outputs{end+1,1} = '04_convergence_trace.png';
catch err
    stage8.warnings{end+1,1} = ['04_convergence_trace.png: ' err.message];
end
try
    exportStage8ContactSheet(fullfile(outDir, 'stage8_contact_sheet.png'), outDir, stage6);
    stage8.outputs{end+1,1} = 'stage8_contact_sheet.png';
catch err
    stage8.warnings{end+1,1} = ['stage8_contact_sheet.png: ' err.message];
end
stage8.index_text = sprintf(['STAGE8_OUTPUT_INDEX\n' ...
    '00_integrity_summary.txt/png: compact run truth + hashes\n' ...
    '01_modal_stability.png: modal energy/contribution diagnostics\n' ...
    'stage4_roi_salience.png: ROI salience map, display-only\n' ...
    'stage5_geodesic_curl_velocity.png: curl/velocity active field, display-only\n' ...
    '04_convergence_trace.png: convergence trace\n' ...
    'stage10_path_report.json + stage10_path_instructions.txt: selected H5 file and path-edit instructions\n' ...
    'stage9_mutual_dependency_contract.json/txt: mutual dependency constraints and scores\n' ...
    'stage8_contact_sheet.png: compact visual index\n' ...
    'stage8_output_index.json/txt: machine/human output inventory\n']);
end

function exportStage8TextPanel(outPath, txt, panelTitle)
fig = figure('Visible','off','Color','k','Position',[100 100 1000 700]);
axes('Position',[0 0 1 1]); axis off;
text(0.04, 0.94, panelTitle, 'Color', [1 0.85 0], 'FontSize', 20, 'FontWeight', 'bold', 'Interpreter', 'none');
text(0.04, 0.86, txt, 'Color', 'w', 'FontSize', 13, 'Interpreter', 'none', 'VerticalAlignment', 'top');
exportFigureSafe(fig, outPath);
close(fig);
end

function exportStage8ModalFigure(outPath, stable)
fig = figure('Visible','off','Color','w','Position',[100 100 1100 520]);
subplot(1,2,1); bar(stable.modal_metrics.mode_energy_share); grid on; title('Modal energy share'); xlabel('mode'); ylabel('share');
subplot(1,2,2); bar(stable.modal_metrics.mode_contribution_share); grid on; title('Modal contribution share'); xlabel('mode'); ylabel('share');
exportFigureSafe(fig, outPath);
close(fig);
end

function exportStage8ConvergenceFigure(outPath, stable)
fig = figure('Visible','off','Color','w','Position',[100 100 900 520]);
semilogy(max(stable.residual_history, eps), 'LineWidth', 1.5); grid on;
title(['Convergence trace: ' stable.stability_metrics.convergence_status], 'Interpreter', 'none');
xlabel('iteration'); ylabel('residual');
exportFigureSafe(fig, outPath);
close(fig);
end

function exportStage8ContactSheet(outPath, outDir, stage6)
fig = figure('Visible','off','Color','w','Position',[100 100 1400 900]);
files = {'00_integrity_summary.png','01_modal_stability.png','stage4_roi_salience.png','stage5_geodesic_curl_velocity.png','04_convergence_trace.png','harmony_diagnostics.png'};
for i = 1:numel(files)
    subplot(3,2,i);
    p = fullfile(outDir, files{i});
    if exist(p, 'file') == 2
        img = imread(p); image(img); axis image off; title(files{i}, 'Interpreter', 'none');
    else
        axis off; text(0.05, 0.55, ['missing: ' files{i}], 'Interpreter', 'none');
    end
end
sgtitle(['Stage 8 contact sheet | ROI=' stage6.stage4_roi_status ' | geodesic=' stage6.stage5_geodesic_status], 'Interpreter', 'none');
exportFigureSafe(fig, outPath);
close(fig);
end

function exportFigureSafe(fig, outPath)
try
    exportgraphics(fig, outPath, 'Resolution', 160);
catch
    saveas(fig, outPath);
end
end

function writeText(path, txt)
fid = fopen(path, 'w');
if fid < 0
    error('Could not write %s', path);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, txt, 'char');
end

function report = errorReport(stageName, err)
report = struct();
report.stage = stageName;
report.status = 'error';
report.message = err.message;
report.identifier = err.identifier;
report.generated_at = datestr(now, 31);
stack = struct([]);
for i = 1:numel(err.stack)
    stack(i).file = err.stack(i).file; %#ok<AGROW>
    stack(i).name = err.stack(i).name; %#ok<AGROW>
    stack(i).line = err.stack(i).line; %#ok<AGROW>
end
report.stack = stack;
end

function hash = sha256File(path)
fid = fopen(path, 'r');
if fid < 0
    hash = '';
    return;
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, '*uint8');
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest = typecast(md.digest(), 'uint8');
hash = lower(reshape(dec2hex(digest, 2).', 1, []));
end
