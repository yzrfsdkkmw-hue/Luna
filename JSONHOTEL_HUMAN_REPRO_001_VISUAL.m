function result = JSONHOTEL_HUMAN_REPRO_001_VISUAL(h5file, outdir)
% JSONHOTEL_HUMAN_REPRO_001_VISUAL
% Human reproduction test for calibration_set_v1.
%
% Goal:
%   Extract measured numeric structures from the unified H5 and translate
%   them into visual outputs that a human can inspect and reproduce.
%
% Source of truth:
%   jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%
% Usage in MATLAB, inside the folder containing the H5:
%   result = JSONHOTEL_HUMAN_REPRO_001_VISUAL();
%
% Or with explicit paths:
%   result = JSONHOTEL_HUMAN_REPRO_001_VISUAL('jsonhotel_unified_001_002_SAFE_20260628_181406.h5', 'HUMAN_REPRO_001_OUTPUT');
%
% Outputs:
%   HUMAN_REPRO_001_OUTPUT/human_repro_001_visual.png
%   HUMAN_REPRO_001_OUTPUT/human_repro_001_metrics.csv
%   HUMAN_REPRO_001_OUTPUT/human_repro_001_result.json
%
% Meaning of this test:
%   Visual representation -> measurement -> numeric/ordinary representation
%   -> repeatable action/understanding.

if nargin < 1 || isempty(h5file)
    h5file = 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
end
if nargin < 2 || isempty(outdir)
    outdir = 'HUMAN_REPRO_001_OUTPUT';
end
if ~exist(h5file, 'file')
    error('H5 file not found: %s', h5file);
end
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

fprintf('\n=== JSONHOTEL HUMAN REPRO 001 VISUAL ===\n');
fprintf('H5: %s\n', h5file);
fprintf('Output: %s\n', outdir);

% ---------- Read numeric datasets ----------
roots = normalize_xy(h5read(h5file, '/n_2_e8_lattice/roots_2d'));
xy    = normalize_xy(h5read(h5file, '/n_2_e8_lattice/laplacian_modes/xy'));
modes = normalize_modes(h5read(h5file, '/n_2_e8_lattice/laplacian_modes/modes'), size(roots,1));
A     = normalize_xy(h5read(h5file, '/n_2_e8_lattice/connections/a'));
B     = normalize_xy(h5read(h5file, '/n_2_e8_lattice/connections/b'));
d_h5  = double(h5read(h5file, '/n_2_e8_lattice/connections/d'));
d_h5  = d_h5(:);
charge = double(h5read(h5file, '/n_3_defect_topology/charge'));
charge = charge(:);
degree = double(h5read(h5file, '/n_3_defect_topology/degree'));
degree = degree(:);
defpos = normalize_xy(h5read(h5file, '/n_3_defect_topology/pos'));
rawpts = normalize_xy(h5read(h5file, '/n_4_geodesic_field/raw_points'));

% ---------- Measurement checks ----------
roots_xy_max_abs_diff = max(abs(double(roots(:)) - double(xy(:))));

d_calc = hypot(double(A(:,1)-B(:,1)), double(A(:,2)-B(:,2)));
connection_distance_max_abs_diff = max(abs(d_calc - d_h5));
connection_distance_mean_abs_diff = mean(abs(d_calc - d_h5));

charge_expected = 6 - degree;
charge_mismatch_count = nnz(charge ~= charge_expected);
charge_sum = sum(charge);
charge_nonzero_count = nnz(charge ~= 0);

raw_radius = hypot(double(rawpts(:,1)), double(rawpts(:,2)));
raw_radius_ge_1_count = nnz(raw_radius >= 1);

% ---------- Visual translation ----------
% Figure panels:
% 1) roots + graph edges: numeric coordinates become visible structure.
% 2) roots colored by first Laplacian mode: numeric mode becomes visual field.
% 3) defect positions colored by charge: topology table becomes visual map.
% 4) raw geodesic points: measured trajectory samples become visible distribution.
fig = figure('Color','w', 'Position', [80 80 1500 1100]);

subplot(2,2,1);
hold on;
for i = 1:size(A,1)
    plot([A(i,1) B(i,1)], [A(i,2) B(i,2)], '-', 'LineWidth', 0.25);
end
scatter(roots(:,1), roots(:,2), 18, 'filled');
axis equal tight;
grid on;
title('E8 roots + 1832 measured edges');
xlabel('x'); ylabel('y');
hold off;

subplot(2,2,2);
mode1 = double(modes(:,1));
scatter(roots(:,1), roots(:,2), 35, mode1, 'filled');
axis equal tight;
grid on;
colorbar;
title('Same 240 roots colored by Laplacian mode 1');
xlabel('x'); ylabel('y');

subplot(2,2,3);
scatter(defpos(:,1), defpos(:,2), 10, charge, 'filled');
axis equal tight;
grid on;
colorbar;
title(sprintf('Defect topology: charge, nonzero=%d, sum=%g', charge_nonzero_count, charge_sum));
xlabel('x'); ylabel('y');

subplot(2,2,4);
step = max(1, floor(size(rawpts,1) / 20000));
idx = 1:step:size(rawpts,1);
scatter(rawpts(idx,1), rawpts(idx,2), 2, '.');
axis equal tight;
grid on;
title(sprintf('Raw geodesic points sample: %d of %d', numel(idx), size(rawpts,1)));
xlabel('x'); ylabel('y');

visual_png = fullfile(outdir, 'human_repro_001_visual.png');
exportgraphics(fig, visual_png, 'Resolution', 180);

% ---------- Save result files ----------
metric_name = {
    'roots_count';
    'edges_count';
    'roots_xy_max_abs_diff';
    'connection_distance_max_abs_diff';
    'connection_distance_mean_abs_diff';
    'charge_mismatch_count';
    'charge_sum';
    'charge_nonzero_count';
    'raw_points_count';
    'raw_radius_ge_1_count'
};
metric_value = [
    size(roots,1);
    size(A,1);
    roots_xy_max_abs_diff;
    connection_distance_max_abs_diff;
    connection_distance_mean_abs_diff;
    charge_mismatch_count;
    charge_sum;
    charge_nonzero_count;
    size(rawpts,1);
    raw_radius_ge_1_count
];
T = table(metric_name, metric_value);
metrics_csv = fullfile(outdir, 'human_repro_001_metrics.csv');
writetable(T, metrics_csv);

result = struct();
result.test_id = 'human_repro_001_visual';
result.h5file = h5file;
result.visual_png = visual_png;
result.metrics_csv = metrics_csv;
result.roots_count = size(roots,1);
result.edges_count = size(A,1);
result.roots_xy_max_abs_diff = roots_xy_max_abs_diff;
result.connection_distance_max_abs_diff = connection_distance_max_abs_diff;
result.connection_distance_mean_abs_diff = connection_distance_mean_abs_diff;
result.charge_mismatch_count = charge_mismatch_count;
result.charge_sum = charge_sum;
result.charge_nonzero_count = charge_nonzero_count;
result.raw_points_count = size(rawpts,1);
result.raw_radius_ge_1_count = raw_radius_ge_1_count;
result.pass = roots_xy_max_abs_diff == 0 && ...
              connection_distance_max_abs_diff < 1e-6 && ...
              charge_mismatch_count == 0 && ...
              raw_radius_ge_1_count == 0;

json_path = fullfile(outdir, 'human_repro_001_result.json');
fid = fopen(json_path, 'w');
fprintf(fid, '%s', jsonencode(result, 'PrettyPrint', true));
fclose(fid);
result.result_json = json_path;

fprintf('\n--- RESULT ---\n');
fprintf('roots_count = %d\n', result.roots_count);
fprintf('edges_count = %d\n', result.edges_count);
fprintf('roots_xy_max_abs_diff = %.12g\n', result.roots_xy_max_abs_diff);
fprintf('connection_distance_max_abs_diff = %.12g\n', result.connection_distance_max_abs_diff);
fprintf('charge_mismatch_count = %d\n', result.charge_mismatch_count);
fprintf('charge_sum = %.12g\n', result.charge_sum);
fprintf('charge_nonzero_count = %d\n', result.charge_nonzero_count);
fprintf('raw_points_count = %d\n', result.raw_points_count);
fprintf('raw_radius_ge_1_count = %d\n', result.raw_radius_ge_1_count);
fprintf('PASS = %d\n', result.pass);
fprintf('\nSaved visual: %s\n', visual_png);
fprintf('Saved metrics: %s\n', metrics_csv);
fprintf('Saved JSON: %s\n', json_path);
end

function XY = normalize_xy(X)
% Return Nx2 regardless of MATLAB/HDF5 orientation.
X = single(X);
sz = size(X);
if numel(sz) ~= 2
    error('Expected 2D numeric matrix for XY data.');
end
if sz(2) == 2
    XY = X;
elseif sz(1) == 2
    XY = X.';
else
    error('Cannot normalize XY matrix of size [%s]. Expected Nx2 or 2xN.', num2str(sz));
end
end

function M = normalize_modes(X, n_roots)
% Return n_roots x n_modes regardless of orientation.
X = single(X);
if size(X,1) == n_roots
    M = X;
elseif size(X,2) == n_roots
    M = X.';
else
    error('Cannot normalize modes. Expected one dimension to equal n_roots=%d.', n_roots);
end
end
