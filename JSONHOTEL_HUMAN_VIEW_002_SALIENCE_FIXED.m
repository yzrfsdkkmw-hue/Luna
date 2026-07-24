function result = JSONHOTEL_HUMAN_VIEW_002_SALIENCE_FIXED(h5file, outdir)
% JSONHOTEL_HUMAN_VIEW_002_SALIENCE_FIXED
% Beginner-friendly human visual view for JSONHotel calibration.
%
% Fix from previous version:
% /n_2_e8_lattice/connections/a and /b are endpoint COORDINATES, not root indices.
% This script plots them as coordinates and only uses nearest-root matching
% when it wants to estimate connection degree per root.

if nargin < 1 || isempty(h5file)
    h5file = 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
end
if nargin < 2 || isempty(outdir)
    outdir = 'HUMAN_VIEW_002_OUTPUT_FIXED';
end
if ~exist(outdir, 'dir'), mkdir(outdir); end

fprintf('\n=== JSONHOTEL HUMAN VIEW 002 FIXED ===\n');
fprintf('H5: %s\n', h5file);
fprintf('Output: %s\n', outdir);

% --- Read datasets ---
roots = read_xy_dataset(h5file, '/n_2_e8_lattice/roots_2d');              % 240 x 2
xy    = read_xy_dataset(h5file, '/n_2_e8_lattice/laplacian_modes/xy');    % 240 x 2

connA = read_xy_dataset(h5file, '/n_2_e8_lattice/connections/a');         % 1832 x 2 endpoint coords
connB = read_xy_dataset(h5file, '/n_2_e8_lattice/connections/b');         % 1832 x 2 endpoint coords
connD = double(h5read(h5file, '/n_2_e8_lattice/connections/d')); connD = connD(:);

def_pos = read_xy_dataset(h5file, '/n_3_defect_topology/pos');            % 2500 x 2
charge  = double(h5read(h5file, '/n_3_defect_topology/charge')); charge = charge(:);

raw = read_xy_dataset(h5file, '/n_4_geodesic_field/raw_points');          % 194527 x 2

% --- Numeric checks ---
nRoots = size(roots,1);
nEdges = size(connA,1);

roots_xy_max_abs_diff = max(abs(roots(:) - xy(:)));

computedD = sqrt(sum((connA - connB).^2, 2));
connection_distance_max_abs_diff = max(abs(computedD - connD));
connection_distance_mean_abs_diff = mean(abs(computedD - connD));

raw_radius = sqrt(sum(raw.^2, 2));
raw_radius_ge_1_count = sum(raw_radius >= 1);

defMask = charge ~= 0;

% --- Estimate root degree from coordinate endpoints ---
% Since connA/connB are coordinates, we map each endpoint to the nearest root.
idxA = nearest_root_indices(connA, roots);
idxB = nearest_root_indices(connB, roots);

degree = zeros(nRoots,1);
for i = 1:nEdges
    degree(idxA(i)) = degree(idxA(i)) + 1;
    degree(idxB(i)) = degree(idxB(i)) + 1;
end

endpoint_match_max_error = max([
    sqrt(sum((connA - roots(idxA,:)).^2,2));
    sqrt(sum((connB - roots(idxB,:)).^2,2))
]);

% --- Salience map ---
% Simple beginner salience:
% root density + raw geodesic point density + nonzero charge density.
N = 320;
xedges = linspace(-1.35, 1.35, N+1);
yedges = linspace(-1.35, 1.35, N+1);

rootDensity = histcounts2(roots(:,2), roots(:,1), yedges, xedges);
rawDensity  = histcounts2(raw(:,2), raw(:,1), yedges, xedges);
defDensity  = histcounts2(def_pos(defMask,2), def_pos(defMask,1), yedges, xedges);

rootDensity = norm01(log1p(rootDensity));
rawDensity  = norm01(log1p(rawDensity));
defDensity  = norm01(log1p(defDensity));

salience = norm01(0.30*rootDensity + 0.35*rawDensity + 0.35*defDensity);

salience_threshold_high = 0.75;
salience_pixels_high = nnz(salience >= salience_threshold_high);

salience_threshold_medium = 0.50;
salience_pixels_medium_or_higher = nnz(salience >= salience_threshold_medium);

% --- Save metrics CSV ---
metrics = {
    'roots_count', nRoots;
    'edges_count', nEdges;
    'roots_xy_max_abs_diff', roots_xy_max_abs_diff;
    'connection_distance_max_abs_diff', connection_distance_max_abs_diff;
    'connection_distance_mean_abs_diff', connection_distance_mean_abs_diff;
    'endpoint_match_max_error', endpoint_match_max_error;
    'defects_nonzero_count', sum(defMask);
    'charge_sum', sum(charge);
    'raw_points_count', size(raw,1);
    'raw_radius_ge_1_count', raw_radius_ge_1_count;
    'mean_root_degree', mean(degree);
    'max_root_degree', max(degree);
    'salience_threshold_high', salience_threshold_high;
    'salience_pixels_high', salience_pixels_high;
    'salience_threshold_medium', salience_threshold_medium;
    'salience_pixels_medium_or_higher', salience_pixels_medium_or_higher
};
T = cell2table(metrics, 'VariableNames', {'metric','value'});
writetable(T, fullfile(outdir,'human_view_002_fixed_metrics.csv'));

% --- Visual page ---
f1 = figure('Visible','off','Color','w','Position',[100 100 1450 1050]);

subplot(2,2,1);
hold on;
for i = 1:nEdges
    plot([connA(i,1), connB(i,1)], [connA(i,2), connB(i,2)], '-', ...
        'Color', [0.70 0.85 1.00], 'LineWidth', 0.25);
end
scatter(roots(:,1), roots(:,2), 16, 'k', 'filled');
axis equal tight; grid on;
title('1. Roots + connections');
xlabel('x'); ylabel('y');
text(-1.32, 1.22, sprintf('roots = %d\nedges = %d', nRoots, nEdges), ...
    'FontSize', 10, 'BackgroundColor', [1 1 1]);

subplot(2,2,2);
scatter(roots(:,1), roots(:,2), 45, degree, 'filled');
axis equal tight; grid on; colorbar;
colormap(gca, parula);
title('2. Root salience by connection count');
xlabel('x'); ylabel('y');
text(-1.32, 1.22, sprintf('mean degree = %.2f\nmax degree = %d', mean(degree), max(degree)), ...
    'FontSize', 10, 'BackgroundColor', [1 1 1]);

subplot(2,2,3);
imagesc(xedges, yedges, salience);
axis xy equal tight; colorbar;
colormap(gca, hot);
hold on;
scatter(roots(:,1), roots(:,2), 7, 'c', 'filled');
title('3. Combined salience map');
xlabel('x'); ylabel('y');
text(-1.32, 1.22, sprintf('high salience pixels >= %.2f: %d', ...
    salience_threshold_high, salience_pixels_high), ...
    'FontSize', 10, 'BackgroundColor', [1 1 1]);

subplot(2,2,4);
scatter(def_pos(:,1), def_pos(:,2), 10, charge, 'filled');
axis equal tight; grid on; colorbar;
colormap(gca, parula);
title('4. Defect charge map');
xlabel('x'); ylabel('y');
text(-1.32, 1.22, sprintf('nonzero charges = %d\ncharge sum = %d', sum(defMask), sum(charge)), ...
    'FontSize', 10, 'BackgroundColor', [1 1 1]);

sgtitle('JSONHotel Human View 002 FIXED — measured visual salience');
exportgraphics(f1, fullfile(outdir,'human_view_002_fixed_visual.png'), 'Resolution', 180);
close(f1);

% --- Legend page ---
f2 = figure('Visible','off','Color','w','Position',[100 100 1300 780]);
axis off;
text(0.02,0.93,'How to read HUMAN_VIEW_002_FIXED', 'FontSize', 22, 'FontWeight','bold');

text(0.02,0.83, ...
    ['Panel 1: black dots are roots. Pale blue lines are measured connection endpoints.' newline ...
     'Panel 2: each root is colored by how many measured connections touch it.' newline ...
     'Panel 3: salience map = root density + geodesic raw-point density + nonzero-charge density.' newline ...
     'Panel 4: each defect point is colored by charge value.'], ...
     'FontSize', 15);

text(0.02,0.58, ...
    ['Simple salience scale:' newline ...
     '0.00-0.25 = low / dark' newline ...
     '0.25-0.50 = mild' newline ...
     '0.50-0.75 = medium/high' newline ...
     '0.75-1.00 = high / yellow-white'], ...
     'FontSize', 16);

text(0.02,0.32, sprintf([ ...
    'Measured facts:\n' ...
    'roots_count = %d\n' ...
    'edges_count = %d\n' ...
    'roots_xy_max_abs_diff = %.12g\n' ...
    'connection_distance_max_abs_diff = %.12g\n' ...
    'endpoint_match_max_error = %.12g\n' ...
    'defects_nonzero_count = %d\n' ...
    'raw_points_count = %d\n' ...
    'raw_radius_ge_1_count = %d'], ...
    nRoots, nEdges, roots_xy_max_abs_diff, connection_distance_max_abs_diff, ...
    endpoint_match_max_error, sum(defMask), size(raw,1), raw_radius_ge_1_count), ...
    'FontSize', 15, 'BackgroundColor', [0.95 0.95 0.95]);

exportgraphics(f2, fullfile(outdir,'human_view_002_fixed_legend.png'), 'Resolution', 180);
close(f2);

% --- Result struct + JSON ---
result = struct();
result.status = 'PASS';
result.h5file = h5file;
result.outdir = outdir;
result.roots_count = nRoots;
result.edges_count = nEdges;
result.roots_xy_max_abs_diff = roots_xy_max_abs_diff;
result.connection_distance_max_abs_diff = connection_distance_max_abs_diff;
result.connection_distance_mean_abs_diff = connection_distance_mean_abs_diff;
result.endpoint_match_max_error = endpoint_match_max_error;
result.defects_nonzero_count = sum(defMask);
result.charge_sum = sum(charge);
result.raw_points_count = size(raw,1);
result.raw_radius_ge_1_count = raw_radius_ge_1_count;
result.mean_root_degree = mean(degree);
result.max_root_degree = max(degree);
result.salience_pixels_high = salience_pixels_high;
result.visual = fullfile(outdir,'human_view_002_fixed_visual.png');
result.legend = fullfile(outdir,'human_view_002_fixed_legend.png');
result.metrics = fullfile(outdir,'human_view_002_fixed_metrics.csv');

write_simple_json(result, fullfile(outdir,'human_view_002_fixed_result.json'));

fprintf('\nDONE.\n');
fprintf('Visual:  %s\n', result.visual);
fprintf('Legend:  %s\n', result.legend);
fprintf('Metrics: %s\n', result.metrics);
end

function xy = read_xy_dataset(h5file, path)
A = double(h5read(h5file, path));
sz = size(A);
if numel(sz) ~= 2
    error('Expected 2D dataset at %s', path);
end
if sz(1) == 2
    xy = A.';
elseif sz(2) == 2
    xy = A;
else
    error('Expected shape 2xN or Nx2 at %s, got [%s]', path, num2str(sz));
end
end

function idx = nearest_root_indices(points, roots)
n = size(points,1);
idx = zeros(n,1);
for i = 1:n
    dif = roots - points(i,:);
    dist2 = sum(dif.^2, 2);
    [~, idx(i)] = min(dist2);
end
end

function y = norm01(x)
x = double(x);
lo = min(x(:));
hi = max(x(:));
if hi <= lo
    y = zeros(size(x));
else
    y = (x - lo) ./ (hi - lo);
end
end

function write_simple_json(S, outpath)
fid = fopen(outpath,'w');
fprintf(fid,'{\n');
fields = fieldnames(S);
for i = 1:numel(fields)
    k = fields{i};
    v = S.(k);
    if isnumeric(v)
        if isscalar(v)
            fprintf(fid,'  "%s": %.15g', k, v);
        else
            fprintf(fid,'  "%s": "%s"', k, mat2str(v));
        end
    else
        v = strrep(char(v), '\', '\\');
        v = strrep(v, '"', '\"');
        fprintf(fid,'  "%s": "%s"', k, v);
    end
    if i < numel(fields)
        fprintf(fid, ',');
    end
    fprintf(fid, '\n');
end
fprintf(fid,'}\n');
fclose(fid);
end
