function final_sync_h5_cyan_threads_only()
% FINAL_SYNC_H5_CYAN_THREADS_ONLY
%
% מטרה:
%   להוציא רק את התמונה היפה עם "החוטים" / connections בצבע תכלת זוהר,
%   לפתוח אותה ישר בסיום, ולשמור גם PNG וגם FIG.
%
% שימוש:
%   1. ודא שקובץ ה-H5 נמצא בתיקיית MATLAB Drive.
%   2. עדכן את H5_FILE אם צריך.
%   3. הרץ:
%        final_sync_h5_cyan_threads_only

clc;

% =========================
% USER SETTINGS
% =========================

TRUTH_DIR = '/MATLAB Drive/modelTRAINING';
H5_FILE = fullfile(TRUTH_DIR, 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5');

RUN_STAMP = datestr(now, 'yyyymmdd_HHMMSS');
OUT_DIR = fullfile(TRUTH_DIR, ['CYAN_THREADS_ONLY_' RUN_STAMP]);

if exist(OUT_DIR, 'dir') ~= 7
    mkdir(OUT_DIR);
end

PNG_PATH = fullfile(OUT_DIR, 'cyan_threads_e8_connections.png');
FIG_PATH = fullfile(OUT_DIR, 'cyan_threads_e8_connections.fig');

assert(exist(H5_FILE, 'file') == 2, 'H5_FILE not found: %s', H5_FILE);

fprintf('\n=== CYAN THREADS ONLY ===\n');
fprintf('H5:  %s\n', H5_FILE);
fprintf('OUT: %s\n\n', OUT_DIR);

% =========================
% READ ONLY REQUIRED H5 DATA
% =========================

roots = as_points(h5read(H5_FILE, '/n_2_e8_lattice/roots_2d'));
A = as_points(h5read(H5_FILE, '/n_2_e8_lattice/connections/a'));
B = as_points(h5read(H5_FILE, '/n_2_e8_lattice/connections/b'));
edge_d = double(h5read(H5_FILE, '/n_2_e8_lattice/connections/d'));
edge_d = edge_d(:);

root_degree = root_degrees_from_edges(roots, A, B);

fprintf('roots=%d\n', size(roots,1));
fprintf('edges=%d\n', size(A,1));

% =========================
% RENDER CYAN THREAD IMAGE
% =========================

fig = figure( ...
    'Color', [0.005 0.008 0.012], ...
    'Position', [80 80 1800 1800], ...
    'Visible', 'on');

ax = axes(fig);
hold(ax, 'on');

set(ax, ...
    'Color', [0.005 0.008 0.012], ...
    'XColor', [0.55 0.85 0.90], ...
    'YColor', [0.55 0.85 0.90]);

axis(ax, 'equal');
axis(ax, 'off');

% Dark structural underlay
for i = 1:size(A,1)
    plot(ax, [A(i,1) B(i,1)], [A(i,2) B(i,2)], ...
        '-', ...
        'Color', [0.00 0.10 0.13], ...
        'LineWidth', 2.2);
end

% Soft cyan glow layer
for i = 1:size(A,1)
    plot(ax, [A(i,1) B(i,1)], [A(i,2) B(i,2)], ...
        '-', ...
        'Color', [0.00 0.45 0.55], ...
        'LineWidth', 1.25);
end

% Bright thread core
for i = 1:size(A,1)
    d_norm = norm01_scalar(edge_d(i), min(edge_d), max(edge_d));

    cyan = [ ...
        0.00 + 0.12*d_norm, ...
        0.88 + 0.10*d_norm, ...
        1.00 ...
    ];

    plot(ax, [A(i,1) B(i,1)], [A(i,2) B(i,2)], ...
        '-', ...
        'Color', cyan, ...
        'LineWidth', 0.42);
end

% Root glow: large faint nodes
deg_norm = norm01_array(root_degree);
node_glow_size = 70 + 160 * deg_norm;
scatter(ax, roots(:,1), roots(:,2), node_glow_size, ...
    repmat([0.00 0.75 0.95], size(roots,1), 1), ...
    'filled', ...
    'MarkerFaceAlpha', 0.18, ...
    'MarkerEdgeAlpha', 0.0);

% Root cores: bright points by degree
node_core_size = 16 + 55 * deg_norm;
root_rgb = degree_to_cyan_white(root_degree);
scatter(ax, roots(:,1), roots(:,2), node_core_size, root_rgb, ...
    'filled', ...
    'MarkerEdgeColor', [0.90 1.00 1.00], ...
    'LineWidth', 0.25);

% Outer reference rings / chamber feeling
theta = linspace(0, 2*pi, 720);
for r = [0.25 0.50 0.75 1.00]
    plot(ax, r*cos(theta), r*sin(theta), ...
        '-', ...
        'Color', [0.00 0.45 0.55], ...
        'LineWidth', 0.35);
end

% Title inside MATLAB figure
title(ax, ...
    sprintf('H5 E8 Connection Threads — Cyan Optical Signature | roots=%d | edges=%d', ...
    size(roots,1), size(A,1)), ...
    'Color', [0.75 1.00 1.00], ...
    'FontWeight', 'bold', ...
    'Interpreter', 'none');

xlim(ax, [-1.08 1.08]);
ylim(ax, [-1.08 1.08]);

drawnow;

% =========================
% SAVE AND OPEN IMMEDIATELY
% =========================

savefig(fig, FIG_PATH);
exportgraphics(fig, PNG_PATH, 'Resolution', 260);

fprintf('\n=== DONE ===\n');
fprintf('PNG: %s\n', PNG_PATH);
fprintf('FIG: %s\n', FIG_PATH);
fprintf('Opening MATLAB figure now...\n\n');

% פותח את קובץ ה-FIG בפורמט MATLAB
openfig(FIG_PATH, 'new', 'visible');

% וגם מציג את ה-PNG בחלון MATLAB נוסף, אם MATLAB תומך בזה
try
    figure('Color', [0.005 0.008 0.012], 'Visible', 'on');
    imshow(imread(PNG_PATH));
    title('cyan_threads_e8_connections.png', ...
        'Color', [0.75 1.00 1.00], ...
        'Interpreter', 'none');
catch
    % אם imshow לא זמין, ה-FIG כבר פתוח וזה מספיק.
end

end

% ============================================================
% HELPERS
% ============================================================

function P = as_points(raw)
X = double(raw);
s = size(X);

if numel(s) ~= 2
    error('Expected 2D point array.');
end

if s(2) == 2
    P = X;
elseif s(1) == 2
    P = X.';
else
    error('Cannot orient point array of size [%s]', num2str(s));
end
end

function deg = root_degrees_from_edges(roots, A, B)
deg = zeros(size(roots,1), 1);

for i = 1:size(A,1)
    ia = nearest_index(roots, A(i,:));
    ib = nearest_index(roots, B(i,:));

    deg(ia) = deg(ia) + 1;
    deg(ib) = deg(ib) + 1;
end
end

function idx = nearest_index(points, p)
[~, idx] = min(sum((points - p).^2, 2));
end

function y = norm01_scalar(x, lo, hi)
if hi <= lo
    y = 0.5;
else
    y = (x - lo) / (hi - lo);
    y = min(max(y, 0), 1);
end
end

function y = norm01_array(x)
x = double(x);
lo = min(x(:));
hi = max(x(:));

if hi <= lo
    y = zeros(size(x));
else
    y = (x - lo) ./ (hi - lo);
    y = min(max(y, 0), 1);
end
end

function rgb = degree_to_cyan_white(degree)
d = norm01_array(degree(:));

rgb = zeros(numel(d), 3);
rgb(:,1) = 0.05 + 0.95 * d.^2;
rgb(:,2) = 0.78 + 0.22 * d;
rgb(:,3) = 1.00;

rgb = min(max(rgb, 0), 1);
end
