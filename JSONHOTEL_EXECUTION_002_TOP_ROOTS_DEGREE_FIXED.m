function result = JSONHOTEL_EXECUTION_002_TOP_ROOTS_DEGREE_FIXED(h5file, outdir, topN)
% JSONHOTEL_EXECUTION_002_TOP_ROOTS_DEGREE_FIXED
% Fast learning sprint:
%   Extract top roots by graph degree and create a focused visual.
%
% Meaning:
%   degree(root) = number of measured connection endpoints touching that root.
%
% Outputs:
%   execution_002_top_roots_degree.png
%   execution_002_top_roots_degree.csv
%   execution_002_metrics.csv
%   execution_002_result.json

if nargin < 1 || isempty(h5file)
    h5file = 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
end
if nargin < 2 || isempty(outdir)
    outdir = 'EXECUTION_002_TOP_ROOTS_DEGREE_OUTPUT';
end
if nargin < 3 || isempty(topN)
    topN = 10;
end
if ~exist(outdir, 'dir'), mkdir(outdir); end

fprintf('\n=== EXECUTION 002 FIXED: TOP ROOTS BY DEGREE ===\n');
fprintf('H5: %s\n', h5file);
fprintf('Output: %s\n', outdir);
fprintf('Top N: %d\n', topN);

% ---------- Load ----------
roots = read_xy_dataset(h5file, '/n_2_e8_lattice/roots_2d');
xy    = read_xy_dataset(h5file, '/n_2_e8_lattice/laplacian_modes/xy');
connA = read_xy_dataset(h5file, '/n_2_e8_lattice/connections/a');
connB = read_xy_dataset(h5file, '/n_2_e8_lattice/connections/b');
connD = double(h5read(h5file, '/n_2_e8_lattice/connections/d')); connD = connD(:);

nRoots = size(roots,1);
nEdges = size(connA,1);

% ---------- Basic checks ----------
roots_xy_max_abs_diff = max(abs(roots(:) - xy(:)));
computedD = sqrt(sum((connA - connB).^2, 2));
connection_distance_max_abs_diff = max(abs(computedD - connD));
connection_distance_mean_abs_diff = mean(abs(computedD - connD));

% ---------- Endpoint coordinate -> nearest root ----------
idxA = nearest_root_indices(connA, roots);
idxB = nearest_root_indices(connB, roots);

endpointA_error = sqrt(sum((connA - roots(idxA,:)).^2, 2));
endpointB_error = sqrt(sum((connB - roots(idxB,:)).^2, 2));
endpoint_match_max_error = max([endpointA_error; endpointB_error]);
endpoint_match_mean_error = mean([endpointA_error; endpointB_error]);

% ---------- Degree ----------
degree = zeros(nRoots,1);
for i = 1:nEdges
    degree(idxA(i)) = degree(idxA(i)) + 1;
    degree(idxB(i)) = degree(idxB(i)) + 1;
end

[degreeSorted, order] = sort(degree, 'descend');
topN = min(topN, nRoots);
topIdx = order(1:topN);
topDegree = degree(topIdx);
topX = roots(topIdx,1);
topY = roots(topIdx,2);
topRank = (1:topN).';

% Deterministic category by degree
degreeBand = strings(topN,1);
for i=1:topN
    degreeBand(i) = degree_band_label(topDegree(i));
end

Ttop = table(topRank, topIdx, topX, topY, topDegree, degreeBand, ...
    'VariableNames', {'rank','root_index','x','y','degree','degree_band'});
writetable(Ttop, fullfile(outdir, 'execution_002_top_roots_degree.csv'));

% ---------- Degree distribution ----------
uniqueDeg = unique(degree);
countDeg = zeros(size(uniqueDeg));
for i=1:numel(uniqueDeg)
    countDeg(i) = sum(degree == uniqueDeg(i));
end
Tdist = table(uniqueDeg, countDeg, 'VariableNames', {'degree','root_count'});
writetable(Tdist, fullfile(outdir, 'execution_002_degree_distribution.csv'));

% ---------- Metrics ----------
metric = {
    'roots_count';
    'edges_count';
    'roots_xy_max_abs_diff';
    'connection_distance_max_abs_diff';
    'connection_distance_mean_abs_diff';
    'endpoint_match_max_error';
    'endpoint_match_mean_error';
    'mean_root_degree';
    'median_root_degree';
    'max_root_degree';
    'min_root_degree';
    'topN'
};
value = [
    nRoots;
    nEdges;
    roots_xy_max_abs_diff;
    connection_distance_max_abs_diff;
    connection_distance_mean_abs_diff;
    endpoint_match_max_error;
    endpoint_match_mean_error;
    mean(degree);
    median(degree);
    max(degree);
    min(degree);
    topN
];
Tmetrics = table(metric, value);
writetable(Tmetrics, fullfile(outdir, 'execution_002_metrics.csv'));

% ---------- Deterministic colors for degree ----------
rootRGB = zeros(nRoots,3);
for i=1:nRoots
    rootRGB(i,:) = degree_color(degree(i));
end

% ---------- Visual ----------
f = figure('Visible','off','Color','w','Position',[100 80 1550 950]);

subplot(1,2,1);
hold on;
for i=1:nEdges
    plot([connA(i,1), connB(i,1)], [connA(i,2), connB(i,2)], '-', ...
        'Color', [0.82 0.90 1.00], 'LineWidth', 0.18);
end
scatter(roots(:,1), roots(:,2), 20, rootRGB, 'filled', ...
    'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.15);
scatter(topX, topY, 125, 'w', 'LineWidth', 1.5);
scatter(topX, topY, 80, rootRGB(topIdx,:), 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.2);

for i=1:topN
    text(topX(i)+0.025, topY(i)+0.025, sprintf('#%d d=%d', i, topDegree(i)), ...
        'FontSize', 8, 'FontWeight','bold', 'BackgroundColor', [1 1 1]);
end

axis equal tight; grid on;
title('Top roots by degree');
xlabel('x'); ylabel('y');

subplot(1,2,2);
barh(1:topN, topDegree);
yticklabels_text = strings(topN,1);
for ii = 1:topN
    yticklabels_text(ii) = sprintf('#%d | root %d', topRank(ii), topIdx(ii));
end
set(gca, 'YTick', 1:topN, 'YTickLabel', yticklabels_text);
set(gca, 'YDir', 'reverse'); % rank #1 appears at the top
xlabel('degree = number of connected endpoints');
ylabel('rank | root index');
title('Top root degrees');
grid on;

annotation('textbox', [0.54 0.04 0.42 0.14], 'String', sprintf([ ...
    'Measured facts:\\n' ...
    'roots = %d, edges = %d\\n' ...
    'mean degree = %.4f, median = %.4f, max = %d\\n' ...
    'roots_xy_max_abs_diff = %.3g\\n' ...
    'connection_distance_max_abs_diff = %.3g'], ...
    nRoots, nEdges, mean(degree), median(degree), max(degree), ...
    roots_xy_max_abs_diff, connection_distance_max_abs_diff), ...
    'FitBoxToText','on', 'BackgroundColor',[0.96 0.96 0.96], 'FontSize', 10);

sgtitle('Execution 002 — Degree as first learnable graph concept');
exportgraphics(f, fullfile(outdir, 'execution_002_top_roots_degree.png'), 'Resolution', 180);
close(f);

% ---------- Result ----------
result = struct();
result.status = 'PASS';
result.h5file = h5file;
result.outdir = outdir;
result.roots_count = nRoots;
result.edges_count = nEdges;
result.roots_xy_max_abs_diff = roots_xy_max_abs_diff;
result.connection_distance_max_abs_diff = connection_distance_max_abs_diff;
result.endpoint_match_max_error = endpoint_match_max_error;
result.mean_root_degree = mean(degree);
result.median_root_degree = median(degree);
result.max_root_degree = max(degree);
result.min_root_degree = min(degree);
result.topN = topN;
result.visual = fullfile(outdir, 'execution_002_top_roots_degree.png');
result.top_roots_csv = fullfile(outdir, 'execution_002_top_roots_degree.csv');
result.metrics_csv = fullfile(outdir, 'execution_002_metrics.csv');
result.degree_distribution_csv = fullfile(outdir, 'execution_002_degree_distribution.csv');

write_simple_json(result, fullfile(outdir, 'execution_002_result.json'));

fprintf('\nDONE.\n');
fprintf('Visual: %s\n', result.visual);
fprintf('Top roots CSV: %s\n', result.top_roots_csv);
fprintf('Metrics CSV: %s\n', result.metrics_csv);
fprintf('\nTop roots:\n');
disp(Ttop);

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
    error('Expected shape 2xN or Nx2 at %s', path);
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

function label = degree_band_label(d)
if d == 0
    label = "0";
elseif d <= 5
    label = "1-5";
elseif d <= 10
    label = "6-10";
elseif d <= 15
    label = "11-15";
elseif d <= 20
    label = "16-20";
elseif d <= 25
    label = "21-25";
elseif d <= 30
    label = "26-30";
elseif d <= 35
    label = "31-35";
else
    label = "36+";
end
end

function rgb = degree_color(d)
if d == 0
    rgb = [0.00 0.00 0.00];
elseif d <= 5
    rgb = [0.00 0.00 0.50];
elseif d <= 10
    rgb = [0.00 0.35 1.00];
elseif d <= 15
    rgb = [0.00 0.80 1.00];
elseif d <= 20
    rgb = [0.00 0.75 0.20];
elseif d <= 25
    rgb = [1.00 0.90 0.00];
elseif d <= 30
    rgb = [1.00 0.60 0.00];
elseif d <= 35
    rgb = [1.00 0.20 0.00];
else
    rgb = [1.00 1.00 1.00];
end
end

function write_simple_json(S, outpath)
fid = fopen(outpath,'w');
fprintf(fid,'{\n');
fields = fieldnames(S);
for i = 1:numel(fields)
    k = fields{i}; v = S.(k);
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
    fprintf(fid,'\n');
end
fprintf(fid,'}\n');
fclose(fid);
end
