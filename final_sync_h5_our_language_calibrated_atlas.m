function final_sync_h5_our_language_calibrated_atlas()
% FINAL_SYNC_H5_OUR_LANGUAGE_CALIBRATED_ATLAS
%
% New clean continuation script.
%
% Authority split:
%   H5 = numerical source of truth.
%   Our_Language = deterministic human visual contract only.
%
% MATLAB Online usage:
%   1. Put the canonical H5 in /MATLAB Drive/modelTRAINING/.
%   2. Run: final_sync_h5_our_language_calibrated_atlas
%   3. A fresh timestamped folder is created; old outputs are not overwritten.

clc;

TRUTH_DIR = '/MATLAB Drive/modelTRAINING';
H5_FILE = fullfile(TRUTH_DIR, 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5');
RUN_STAMP = datestr(now, 'yyyymmdd_HHMMSS');
OUT_DIR = fullfile(TRUTH_DIR, ['FINAL_SYNC_H5_OUR_LANGUAGE_CALIBRATED_ATLAS_' RUN_STAMP]);
IMG_DIR = fullfile(OUT_DIR, 'images');
META_DIR = fullfile(OUT_DIR, 'metadata');
CONTACT_DIR = fullfile(OUT_DIR, 'contact_sheets');

ensure_dir(OUT_DIR);
ensure_dir(IMG_DIR);
ensure_dir(META_DIR);
ensure_dir(CONTACT_DIR);

assert(exist(H5_FILE, 'file') == 2, 'Canonical H5 not found: %s', H5_FILE);
diary(fullfile(OUT_DIR, 'run_log.txt'));
diary_cleanup = onCleanup(@() diary('off')); %#ok<NASGU>

C = our_language_contract();

fprintf('\n=== FINAL SYNC: H5 + OUR_LANGUAGE CLEAN CONTINUATION ===\n');
fprintf('TRUTH_DIR: %s\n', TRUTH_DIR);
fprintf('H5:        %s\n', H5_FILE);
fprintf('OUT:       %s\n\n', OUT_DIR);

% -------------------------
% Canonical H5 reads
% -------------------------
roots = as_points(h5read(H5_FILE, '/n_2_e8_lattice/roots_2d'));
A = as_points(h5read(H5_FILE, '/n_2_e8_lattice/connections/a'));
B = as_points(h5read(H5_FILE, '/n_2_e8_lattice/connections/b'));
edge_d = double(h5read(H5_FILE, '/n_2_e8_lattice/connections/d')); edge_d = edge_d(:);

lap_xy = as_points(h5read(H5_FILE, '/n_2_e8_lattice/laplacian_modes/xy'));
modes = orient_modes(double(h5read(H5_FILE, '/n_2_e8_lattice/laplacian_modes/modes')), size(roots,1));

stream_xy = as_points(h5read(H5_FILE, '/n_2_e8_lattice/streamlines/xy'));
stream_sid = double(h5read(H5_FILE, '/n_2_e8_lattice/streamlines/sid')); stream_sid = stream_sid(:);
stream_logmag = double(h5read(H5_FILE, '/n_2_e8_lattice/streamlines/logmag')); stream_logmag = stream_logmag(:);

charge = double(h5read(H5_FILE, '/n_3_defect_topology/charge')); charge = charge(:);
defect_degree = double(h5read(H5_FILE, '/n_3_defect_topology/degree')); defect_degree = defect_degree(:);
defect_pos = as_points(h5read(H5_FILE, '/n_3_defect_topology/pos'));

geo_xy = as_points(h5read(H5_FILE, '/n_4_geodesic_field/xy'));
geo_vel = as_points(h5read(H5_FILE, '/n_4_geodesic_field/vel'));
geo_curl = double(h5read(H5_FILE, '/n_4_geodesic_field/curl')); geo_curl = geo_curl(:);
raw_points = as_points(h5read(H5_FILE, '/n_4_geodesic_field/raw_points'));

composite = as_channel_rows(h5read(H5_FILE, '/n_5_composite_field_1000x1000/data'), 5);
field_chamber = as_channel_rows(h5read(H5_FILE, '/n_6_field_maps_v3_800x800/chamber_field/data'), 3);
field_fuchsian = as_channel_rows(h5read(H5_FILE, '/n_6_field_maps_v3_800x800/fuchsian_tiling/data'), 5);
field_ginibre = as_channel_rows(h5read(H5_FILE, '/n_6_field_maps_v3_800x800/ginibre_field/data'), 3);
field_modular = as_channel_rows(h5read(H5_FILE, '/n_6_field_maps_v3_800x800/modular_eta/data'), 3);
field_weyl = as_channel_rows(h5read(H5_FILE, '/n_6_field_maps_v3_800x800/weyl_field/data'), 5);

% -------------------------
% Integrity quantities
% -------------------------
root_degree = root_degrees_from_edges(roots, A, B);
edge_distance_error = max(abs(sqrt(sum((A - B).^2, 2)) - edge_d));
roots_lap_error = max(abs(roots(:) - lap_xy(:)));
charge_relation_error = max(abs(charge - (6 - defect_degree)));
raw_radius = sqrt(sum(raw_points.^2, 2));

fprintf('roots=%d edges=%d raw_points=%d stream_points=%d\n', size(roots,1), size(A,1), size(raw_points,1), size(stream_xy,1));
fprintf('edge_distance_error=%.12g roots_lap_error=%.12g charge_relation_error=%.12g\n\n', edge_distance_error, roots_lap_error, charge_relation_error);

panels = {};
panels{end+1} = panel_root_degree_edges(IMG_DIR, META_DIR, C, roots, A, B, root_degree, edge_d);
panels{end+1} = panel_density_salience(IMG_DIR, META_DIR, C, raw_points);
panels{end+1} = panel_defect_charge(IMG_DIR, META_DIR, C, defect_pos, charge, defect_degree);
panels{end+1} = panel_laplacian_modes(IMG_DIR, META_DIR, C, roots, modes);
panels{end+1} = panel_streamlines(IMG_DIR, META_DIR, C, stream_xy, stream_sid, stream_logmag);
panels{end+1} = panel_geodesic(IMG_DIR, META_DIR, C, geo_xy, geo_vel, geo_curl);
panels{end+1} = panel_composite(IMG_DIR, META_DIR, C, composite);
panels{end+1} = panel_field_maps(IMG_DIR, META_DIR, C, field_chamber, field_fuchsian, field_ginibre, field_modular, field_weyl);
panels{end+1} = panel_integrity(IMG_DIR, META_DIR, edge_distance_error, roots_lap_error, charge_relation_error, root_degree, charge, raw_radius);

contact_path = render_contact_sheet(CONTACT_DIR, panels);
write_index(OUT_DIR, H5_FILE, panels, contact_path, edge_distance_error, roots_lap_error, charge_relation_error);

fprintf('=== DONE ===\n');
fprintf('Output:        %s\n', OUT_DIR);
fprintf('Contact sheet: %s\n', contact_path);
fprintf('Index:         %s\n', fullfile(OUT_DIR, 'index_summary.json'));
end

% ============================================================
% Our_Language deterministic contract
% ============================================================

function C = our_language_contract()
C.root_degree_edges = [0 0; 1 5; 6 10; 11 15; 16 20; 21 25; 26 30; 31 35; 36 inf];
C.root_degree_rgb = [
    0.00 0.00 0.00
    0.00 0.00 0.50
    0.00 0.35 1.00
    0.00 0.80 1.00
    0.00 0.75 0.20
    1.00 0.90 0.00
    1.00 0.60 0.00
    1.00 0.20 0.00
    1.00 1.00 1.00];

C.raw_density_edges = [0 0; 1 9; 10 24; 25 49; 50 99; 100 199; 200 inf];
C.raw_density_rgb = [
    0.00 0.00 0.00
    0.00 0.00 0.45
    0.00 0.40 1.00
    0.00 0.75 0.20
    1.00 0.90 0.00
    1.00 0.45 0.00
    1.00 1.00 1.00];

C.charge_values = [-4 -3 -2 -1 0 1 2 3];
C.charge_rgb = [
    0.20 0.00 0.35
    0.45 0.00 0.60
    0.00 0.20 0.80
    0.00 0.75 1.00
    0.65 0.65 0.65
    1.00 0.95 0.10
    1.00 0.55 0.00
    0.90 0.00 0.00];

C.salience_edges = [0.00 0.20; 0.20 0.40; 0.40 0.60; 0.60 0.80; 0.80 1.00];
C.salience_rgb = [
    0.00 0.00 0.00
    0.40 0.00 0.00
    0.85 0.25 0.00
    1.00 0.85 0.00
    1.00 1.00 1.00];
end

% ============================================================
% Panels
% ============================================================

function item = panel_root_degree_edges(img_dir, meta_dir, C, roots, A, B, degree, edge_d)
name = '01_root_degree_edges_clean';
img_path = fullfile(img_dir, [name '.png']);
fig = make_fig(); ax = axes(fig); hold(ax, 'on'); set_dark(ax);
lo = min(edge_d); hi = max(edge_d);
for i = 1:size(A,1)
    v = norm01_scalar(edge_d(i), lo, hi);
    plot(ax, [A(i,1) B(i,1)], [A(i,2) B(i,2)], '-', 'Color', [0.10+0.45*v 0.55+0.35*v 0.80], 'LineWidth', 0.25);
end
rgb = colors_from_bands(degree, C.root_degree_edges, C.root_degree_rgb);
glow_scatter(ax, roots(:,1), roots(:,2), rgb, 76);
scatter(ax, roots(:,1), roots(:,2), 30, rgb, 'filled', 'MarkerEdgeColor', [0.08 0.08 0.08], 'LineWidth', 0.35);
axis(ax, 'equal'); xlim(ax, [-1.08 1.08]); ylim(ax, [-1.08 1.08]);
title_panel(ax, 'H5 roots + measured edges', 'root colors = Our_Language degree bands; edge tint = measured d');
safe_export(fig, img_path, 220); close(fig);
item = save_meta(meta_dir, name, 'Root degree and measured edges', '/n_2_e8_lattice', 'degree(v)=endpoint count; edge color=normalized h5 distance d', img_path);
end

function item = panel_density_salience(img_dir, meta_dir, C, raw_points)
name = '02_raw_density_salience_roi';
img_path = fullfile(img_dir, [name '.png']);
nb = 900;
edges = linspace(-1.05, 1.05, nb+1);
centers = (edges(1:end-1) + edges(2:end)) / 2;
N = histcounts2(raw_points(:,2), raw_points(:,1), edges, edges);
D = log1p(N);
S = optical_salience_from_scalar(D);
[roi_rows, roi_cols, roi_scores] = top_salience_rois(S, 3, 180);
fig = make_fig(); tl = tiledlayout(fig, 1, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
ax = nexttile(tl);
RGB = min(max(0.50*colors_from_bands(N, C.raw_density_edges, C.raw_density_rgb) + 0.75*colors_from_bands(S, C.salience_edges, C.salience_rgb), 0), 1);
image(ax, [-1.05 1.05], [-1.05 1.05], RGB); set(ax, 'YDir', 'normal'); axis(ax, 'image', 'off'); title(ax, 'global density→salience', 'Color', [1 1 1]);
for r = 1:3
    ax = nexttile(tl); hold(ax, 'on'); rr = roi_rows{r}; cc = roi_cols{r};
    RGBroi = RGB(rr,cc,:);
    image(ax, [centers(cc(1)) centers(cc(end))], [centers(rr(1)) centers(rr(end))], RGBroi); set(ax, 'YDir', 'normal'); axis(ax, 'image'); set_dark(ax);
    contour(ax, centers(cc), centers(rr), S(rr,cc), [0.35 0.50 0.65 0.80 0.92], 'LineColor', [1 1 1], 'LineWidth', 0.45);
    title(ax, sprintf('ROI %d | %.3f', r, roi_scores(r)), 'Color', [1 1 1]);
end
sgtitle(fig, 'H5 raw_points: density + compact salience ROIs', 'Color', [1 1 1], 'FontWeight', 'bold');
safe_export(fig, img_path, 220); close(fig);
item = save_meta(meta_dir, name, 'Raw-point density and salience ROIs', '/n_4_geodesic_field/raw_points', 'D=log(1+hist2(raw_points)); S=multiscale salience(D); ROI=top salience windows', img_path);
end

function item = panel_defect_charge(img_dir, meta_dir, C, pos, charge, degree)
name = '03_defect_charge_degree';
img_path = fullfile(img_dir, [name '.png']);
rgb = colors_from_values(charge, C.charge_values, C.charge_rgb);
sz = 20 + 26 * abs(charge);
fig = make_fig(); ax = axes(fig); hold(ax, 'on'); set_dark(ax);
glow_scatter(ax, pos(:,1), pos(:,2), rgb, sz*2.7);
scatter(ax, pos(:,1), pos(:,2), sz, rgb, 'filled', 'MarkerEdgeColor', [0.12 0.12 0.12], 'LineWidth', 0.35);
axis(ax, 'equal'); title_panel(ax, 'Defect topology', 'color=charge; size=|charge|; check charge=6-degree');
text(ax, 0.02, 0.04, sprintf('sites=%d | mismatch=%g | charge_sum=%g', numel(charge), max(abs(charge-(6-degree))), sum(charge)), 'Units', 'normalized', 'Color', [1 1 1], 'FontWeight', 'bold');
safe_export(fig, img_path, 220); close(fig);
item = save_meta(meta_dir, name, 'Defect charge-degree topology', '/n_3_defect_topology', 'charge=6-degree; palette=Our_Language charge_value', img_path);
end

function item = panel_laplacian_modes(img_dir, meta_dir, C, roots, modes)
name = '04_laplacian_modes_salience';
img_path = fullfile(img_dir, [name '.png']);
fig = make_fig(); tl = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
for k = 1:6
    ax = nexttile(tl); set_dark(ax);
    v = modes(:,k); s = norm01_array(abs(v)); rgb = colors_from_bands(s, C.salience_edges, C.salience_rgb);
    scatter(ax, roots(:,1), roots(:,2), 34, rgb, 'filled'); axis(ax, 'equal', 'off');
    title(ax, sprintf('mode %d | salience(|phi|)', k), 'Color', [1 1 1]);
end
sgtitle(fig, 'Laplacian modes on root geometry', 'Color', [1 1 1], 'FontWeight', 'bold');
safe_export(fig, img_path, 220); close(fig);
item = save_meta(meta_dir, name, 'Laplacian mode salience', '/n_2_e8_lattice/laplacian_modes', 'color=Our_Language salience(abs(mode))', img_path);
end

function item = panel_streamlines(img_dir, meta_dir, C, xy, sid, logmag)
name = '05_streamline_logmag_salience';
img_path = fullfile(img_dir, [name '.png']);
fig = make_fig(); ax = axes(fig); hold(ax, 'on'); set_dark(ax);
ids = unique(sid); step = max(1, floor(numel(ids)/180)); ids = ids(1:step:end);
lo = min(logmag); hi = max(logmag);
for i = 1:numel(ids)
    m = sid == ids(i); val = mean(logmag(m));
    plot(ax, xy(m,1), xy(m,2), '-', 'Color', salience_color(C, norm01_scalar(val, lo, hi)), 'LineWidth', 0.65);
end
axis(ax, 'equal'); xlim(ax, [-1.05 1.05]); ylim(ax, [-1.05 1.05]);
title_panel(ax, 'Streamline logmag salience', 'sid groups; color=salience(mean logmag)');
safe_export(fig, img_path, 220); close(fig);
item = save_meta(meta_dir, name, 'Streamline logmag salience', '/n_2_e8_lattice/streamlines', 'color=salience(normalized mean logmag per sid)', img_path);
end

function item = panel_geodesic(img_dir, meta_dir, C, xy, vel, curlv)
name = '06_geodesic_curl_velocity';
img_path = fullfile(img_dir, [name '.png']);
[X,Y,Curl] = grid_from_points_values(xy, curlv);
[~,~,U] = grid_from_points_values(xy, vel(:,1));
[~,~,V] = grid_from_points_values(xy, vel(:,2));
S = optical_salience_from_scalar(Curl);
RGB = colors_from_bands(S, C.salience_edges, C.salience_rgb);
fig = make_fig(); ax = axes(fig); hold(ax, 'on'); set_dark(ax);
image(ax, [min(X(:)) max(X(:))], [min(Y(:)) max(Y(:))], RGB); set(ax, 'YDir', 'normal');
skip = 10;
quiver(ax, X(1:skip:end,1:skip:end), Y(1:skip:end,1:skip:end), U(1:skip:end,1:skip:end), V(1:skip:end,1:skip:end), 1.3, 'Color', [0.65 1 1], 'LineWidth', 0.6);
axis(ax, 'equal', 'tight'); title_panel(ax, 'Geodesic curl + velocity', 'background=salience(curl); arrows=velocity');
safe_export(fig, img_path, 220); close(fig);
item = save_meta(meta_dir, name, 'Geodesic curl velocity', '/n_4_geodesic_field', 'salience from curl; vector overlay from velocity', img_path);
end

function item = panel_composite(img_dir, meta_dir, C, X)
name = '07_composite_field_signature';
img_path = fullfile(img_dir, [name '.png']);
side = sqrt(size(X,1)); assert(abs(side-round(side))<1e-9, 'composite rows are not square'); side = round(side);
A = reshape(X, side, side, 5);
S = optical_salience_from_multichannel(A);
RGB = fuse_channels(A, S, C);
[roi_rows, roi_cols, roi_scores] = top_salience_rois(S, 3, 190);
fig = make_fig(); tl = tiledlayout(fig, 1, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
ax = nexttile(tl); image(ax, downsample_rgb(RGB, 2)); axis(ax, 'image', 'off'); title(ax, 'global C(x,y)', 'Color', [1 1 1]);
for r = 1:3
    ax = nexttile(tl); rr = roi_rows{r}; cc = roi_cols{r};
    image(ax, RGB(rr,cc,:)); axis(ax, 'image', 'off'); title(ax, sprintf('ROI %d | %.3f', r, roi_scores(r)), 'Color', [1 1 1]);
end
sgtitle(fig, 'Composite H5 field: channel fusion + salience ROIs', 'Color', [1 1 1], 'FontWeight', 'bold');
safe_export(fig, img_path, 180); close(fig);
item = save_meta(meta_dir, name, 'Composite field signature', '/n_5_composite_field_1000x1000/data', 'RGB=f(channels); S=multiscale salience(mean channels); ROI=top salience windows', img_path);
end

function item = panel_field_maps(img_dir, meta_dir, C, chamber, fuchsian, ginibre, modular, weyl)
name = '08_field_maps_signature';
img_path = fullfile(img_dir, [name '.png']);
sets = {chamber, fuchsian, ginibre, modular, weyl};
labels = {'chamber', 'fuchsian', 'ginibre', 'modular_eta', 'weyl'};
fig = make_fig(); tl = tiledlayout(fig, 5, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
for i = 1:5
    X = channel_cube(sets{i});
    S = optical_salience_from_multichannel(X);
    RGB = fuse_channels(X, S, C);
    [roi_rows, roi_cols, roi_scores] = top_salience_rois(S, 1, 170);
    ax = nexttile(tl); image(ax, downsample_rgb(RGB, 3)); axis(ax, 'image', 'off'); title(ax, [labels{i} ' global'], 'Color', [1 1 1], 'Interpreter', 'none');
    rr = roi_rows{1}; cc = roi_cols{1};
    ax = nexttile(tl); image(ax, RGB(rr,cc,:)); axis(ax, 'image', 'off'); title(ax, sprintf('%s ROI | %.3f', labels{i}, roi_scores(1)), 'Color', [1 1 1], 'Interpreter', 'none');
end
sgtitle(fig, 'H5 field maps: global context + strongest mathematical ROI', 'Color', [1 1 1], 'FontWeight', 'bold');
safe_export(fig, img_path, 160); close(fig);
item = save_meta(meta_dir, name, 'Field-map signatures', '/n_6_field_maps_v3_800x800', 'For each field: RGB=f(channels); ROI=top salience window', img_path);
end

function item = panel_integrity(img_dir, meta_dir, edge_err, roots_err, charge_err, degree, charge, radius)
name = '09_integrity_summary';
img_path = fullfile(img_dir, [name '.png']);
fig = make_fig(); ax = axes(fig); set_dark(ax); axis(ax, 'off');
lines = {
    'FINAL SYNC CLEAN CONTINUATION'
    'H5 is the only numerical authority'
    'Our_Language supplies deterministic human visual mappings'
    ''
    sprintf('edge distance max error: %.12g', edge_err)
    sprintf('roots/laplacian xy max error: %.12g', roots_err)
    sprintf('charge=6-degree max error: %.12g', charge_err)
    ''
    sprintf('root degree min=%d median=%.1f mean=%.4f max=%d', min(degree), median(degree), mean(degree), max(degree))
    sprintf('charge sum=%g nonzero=%d', sum(charge), nnz(charge))
    sprintf('raw radius max=%.12g | count radius>=1: %d', max(radius), nnz(radius>=1))
    ''
    'No Finder/screen coordinates. Mathematical coordinates only.'
};
y = 0.93;
for i = 1:numel(lines)
    if i == 1; fs = 22; col = [1 0.85 0.2]; fw = 'bold'; else; fs = 13; col = [0.92 0.92 0.92]; fw = 'normal'; end
    text(ax, 0.05, y, lines{i}, 'Color', col, 'FontSize', fs, 'FontWeight', fw, 'Interpreter', 'none'); y = y - 0.06;
end
safe_export(fig, img_path, 220); close(fig);
item = save_meta(meta_dir, name, 'Integrity summary', 'H5 + Our_Language contract', 'deterministic integrity checks and run summary', img_path);
end

% ============================================================
% Core math + utilities
% ============================================================

function S = optical_salience_from_scalar(X)
X = double(X); Xn = norm01_array(X);
[Gx,Gy] = gradient(Xn);
grad = sqrt(Gx.^2 + Gy.^2);
blur5 = smooth2(Xn, 5);
blur13 = smooth2(Xn, 13);
blur31 = smooth2(Xn, 31);
hp5 = abs(Xn - blur5);
hp13 = abs(Xn - blur13);
hp31 = abs(Xn - blur31);
loc9 = smooth2((Xn - blur13).^2, 9);
[Gxx,~] = gradient(Gx); [~,Gyy] = gradient(Gy);
lap = abs(Gxx + Gyy);
ridge = abs(hp5 .* grad + 0.5*lap);
S = 0.18*norm01_array(abs(Xn - median(Xn(:)))) + ...
    0.22*norm01_array(grad) + ...
    0.18*norm01_array(hp5) + ...
    0.16*norm01_array(hp13) + ...
    0.10*norm01_array(hp31) + ...
    0.08*norm01_array(loc9) + ...
    0.08*norm01_array(ridge);
for iter = 1:5
    smoothS = smooth2(S, 5);
    S = min(max(S + 0.38*(S - smoothS), 0), 1);
    S = norm01_array(S);
end
S = min(max(S,0),1);
end

function S = optical_salience_from_multichannel(A)
K = size(A,3); base = zeros(size(A,1), size(A,2));
for k = 1:K
    base = base + norm01_array(A(:,:,k));
end
base = base ./ K;
S = optical_salience_from_scalar(base);
end

function RGB = fuse_channels(A, S, C)
K = size(A,3);
R = norm01_array(A(:,:,1));
G = norm01_array(A(:,:,min(2,K)));
B = norm01_array(A(:,:,min(3,K)));
if K >= 5
    R = norm01_array(0.60*R + 0.40*norm01_array(A(:,:,5)));
    G = norm01_array(0.50*G + 0.50*norm01_array(A(:,:,4)));
    B = norm01_array(0.72*B + 0.28*norm01_array(A(:,:,5)));
end
baseRGB = cat(3, R, G, B);
salRGB = colors_from_bands(S, C.salience_edges, C.salience_rgb);
glow = smooth2(S, 17);
glowRGB = cat(3, glow, 0.55*glow, 0.18*glow);
RGB = min(max(0.48*baseRGB + 0.34*salRGB + 0.18*glowRGB, 0), 1);
RGB = min(max(RGB .^ 0.72, 0), 1);
end

function ensure_dir(p)
if exist(p, 'dir') ~= 7
    [ok, msg] = mkdir(p);
    assert(ok, 'Could not create directory: %s | %s', p, msg);
end
end

function fig = make_fig()
fig = figure('Visible', 'off', 'Color', [0.025 0.025 0.035], 'Position', [80 80 1800 1300]);
end

function set_dark(ax)
set(ax, 'Color', [0.025 0.025 0.035], 'XColor', [0.82 0.82 0.82], 'YColor', [0.82 0.82 0.82]);
grid(ax, 'on'); ax.GridAlpha = 0.20;
end

function title_panel(ax, title_text, formula_text)
title(ax, sprintf('%s\n%s', title_text, formula_text), 'Color', [1 1 1], 'FontWeight', 'bold', 'Interpreter', 'none');
end

function P = as_points(raw)
X = double(raw); s = size(X);
if numel(s) ~= 2; error('Expected 2D point array'); end
if s(2) == 2
    P = X;
elseif s(1) == 2
    P = X.';
else
    error('Cannot orient points: [%s]', num2str(s));
end
end

function X = as_channel_rows(raw, ch)
A = double(raw); s = size(A);
if s(2) == ch
    X = A;
elseif s(1) == ch
    X = A.';
else
    error('Cannot orient channel matrix: [%s] ch=%d', num2str(s), ch);
end
end

function A = channel_cube(X)
side = sqrt(size(X,1)); assert(abs(side-round(side))<1e-9, 'rows are not square'); side = round(side);
A = reshape(X, side, side, size(X,2));
end

function M = orient_modes(raw, n)
if size(raw,1) == n
    M = raw;
elseif size(raw,2) == n
    M = raw.';
else
    error('Cannot orient modes');
end
end

function deg = root_degrees_from_edges(roots, A, B)
deg = zeros(size(roots,1),1);
for i = 1:size(A,1)
    ia = nearest_idx(roots, A(i,:));
    ib = nearest_idx(roots, B(i,:));
    deg(ia) = deg(ia) + 1;
    deg(ib) = deg(ib) + 1;
end
end

function idx = nearest_idx(P, p)
[~, idx] = min(sum((P-p).^2,2));
end

function glow_scatter(ax, x, y, rgb, sizes)
if isscalar(sizes)
    s1 = sizes; s2 = sizes*2.4; s3 = sizes*5.2;
else
    s1 = sizes(:); s2 = s1*2.4; s3 = s1*5.2;
end
base = rgb;
if size(base,1) == 1 && numel(x) > 1
    base = repmat(base, numel(x), 1);
end
scatter(ax, x, y, s3, min(base*0.35 + 0.05, 1), 'filled', 'MarkerFaceAlpha', 0.08, 'MarkerEdgeAlpha', 0.02);
scatter(ax, x, y, s2, min(base*0.65 + 0.08, 1), 'filled', 'MarkerFaceAlpha', 0.14, 'MarkerEdgeAlpha', 0.04);
scatter(ax, x, y, s1, base, 'filled', 'MarkerFaceAlpha', 0.75, 'MarkerEdgeAlpha', 0.15);
end

function [roi_rows, roi_cols, scores] = top_salience_rois(S, count, half_width)
S = double(S); Swork = S;
roi_rows = cell(count,1); roi_cols = cell(count,1); scores = zeros(count,1);
[h,w] = size(S);
for k = 1:count
    [~, idx] = max(Swork(:));
    [r,c] = ind2sub(size(Swork), idx);
    r1 = max(1, r-half_width); r2 = min(h, r+half_width);
    c1 = max(1, c-half_width); c2 = min(w, c+half_width);
    roi_rows{k} = r1:r2; roi_cols{k} = c1:c2;
    scores(k) = mean(S(r1:r2,c1:c2), 'all');
    sr1 = max(1, r-2*half_width); sr2 = min(h, r+2*half_width);
    sc1 = max(1, c-2*half_width); sc2 = min(w, c+2*half_width);
    Swork(sr1:sr2, sc1:sc2) = -inf;
end
end

function RGB2 = downsample_rgb(RGB, step)
RGB2 = RGB(1:step:end, 1:step:end, :);
end

function safe_export(fig, path, resolution)
try
    exportgraphics(fig, path, 'Resolution', resolution);
catch
    try
        drawnow;
        print(fig, path, '-dpng', ['-r' num2str(resolution)]);
    catch
        frame = getframe(fig);
        imwrite(frame.cdata, path);
    end
end
end

function [Xg,Yg,Vg] = grid_from_points_values(xy, vals)
xs = unique(xy(:,1)); ys = unique(xy(:,2));
[Xg,Yg] = meshgrid(xs,ys);
Vg = nan(numel(ys),numel(xs));
[~,xi] = ismember(xy(:,1),xs); [~,yi] = ismember(xy(:,2),ys);
for i = 1:numel(vals)
    Vg(yi(i),xi(i)) = vals(i);
end
end

function RGB = colors_from_bands(V, edges, colors)
V = double(V);
is_vector_input = isvector(V);
if is_vector_input
    v = V(:);
    RGB = zeros(numel(v), 3);
    for k = 1:size(edges,1)
        if isinf(edges(k,2))
            mask = v >= edges(k,1);
        else
            mask = v >= edges(k,1) & v <= edges(k,2);
        end
        RGB(mask, :) = repmat(colors(k,:), nnz(mask), 1);
    end
else
    sz = size(V);
    RGB = zeros([sz 3]);
    for k = 1:size(edges,1)
        if isinf(edges(k,2))
            mask = V >= edges(k,1);
        else
            mask = V >= edges(k,1) & V <= edges(k,2);
        end
        for c = 1:3
            tmp = RGB(:,:,c);
            tmp(mask) = colors(k,c);
            RGB(:,:,c) = tmp;
        end
    end
end
end

function RGB = colors_from_values(V, values, colors)
V = double(V); RGB = zeros([numel(V) 3]);
for k = 1:numel(values)
    m = V(:) == values(k);
    RGB(m,:) = repmat(colors(k,:), nnz(m), 1);
end
end

function col = salience_color(C, s)
RGB = colors_from_bands(s, C.salience_edges, C.salience_rgb);
col = reshape(RGB, 1, 3);
end

function Y = norm01_array(X)
X = double(X);
lo = prctile(X(:), 1); hi = prctile(X(:), 99);
if hi <= lo
    Y = zeros(size(X));
else
    Y = min(max((X-lo)./(hi-lo), 0), 1);
end
end

function y = norm01_scalar(x, lo, hi)
if hi <= lo
    y = 0.5;
else
    y = min(max((x-lo)/(hi-lo),0),1);
end
end

function B = smooth2(A, w)
K = ones(w,w)/(w*w);
B = conv2(A,K,'same');
end

function item = save_meta(meta_dir, name, title_txt, source, formula, img_path)
item = struct('name', name, 'title', title_txt, 'source', source, 'formula', formula, 'image_path', img_path, 'policy', 'H5 authority + Our_Language deterministic human visual contract');
write_json(fullfile(meta_dir, [name '.json']), item);
fid = fopen(fullfile(meta_dir, [name '.txt']), 'w');
fprintf(fid, '%s\nsource: %s\nformula: %s\nimage: %s\n', title_txt, source, formula, img_path);
fclose(fid);
end

function contact_path = render_contact_sheet(contact_dir, panels)
contact_path = fullfile(contact_dir, 'FINAL_SYNC_OUR_LANGUAGE_CLEAN_CONTACT_SHEET.png');
fig = figure('Visible', 'off', 'Color', [0.025 0.025 0.035], 'Position', [60 60 2600 1800]);
tl = tiledlayout(fig, 3, 3, 'Padding', 'compact', 'TileSpacing', 'compact'); %#ok<NASGU>
for i = 1:numel(panels)
    ax = nexttile;
    im = imread(panels{i}.image_path);
    image(ax, im); axis(ax, 'image', 'off');
    title(ax, panels{i}.title, 'Color', [1 1 1], 'Interpreter', 'none', 'FontSize', 8);
end
sgtitle(fig, 'FINAL SYNC CLEAN — H5 + Our_Language calibrated signatures', 'Color', [1 0.85 0.2], 'FontWeight', 'bold', 'FontSize', 18);
safe_export(fig, contact_path, 150); close(fig);
end

function write_index(out_dir, h5_file, panels, contact_path, e1, e2, e3)
S = struct();
S.stage = 'final_sync_h5_our_language_clean_continuation';
S.authority = 'canonical H5 only';
S.h5_file = h5_file;
S.our_language_role = 'deterministic human color/shape/salience contract';
S.panel_count = numel(panels);
S.panels = panels;
S.contact_sheet = contact_path;
S.integrity = struct('edge_distance_max_error', e1, 'roots_laplacian_xy_max_error', e2, 'charge_relation_max_error', e3);
write_json(fullfile(out_dir, 'index_summary.json'), S);
fid = fopen(fullfile(out_dir, 'index_summary.txt'), 'w');
fprintf(fid, 'FINAL SYNC CLEAN H5 + OUR_LANGUAGE CALIBRATED ATLAS\nH5: %s\nContact: %s\nPanels: %d\n', h5_file, contact_path, numel(panels));
fclose(fid);
end

function write_json(path, S)
try
    txt = jsonencode(S, 'PrettyPrint', true);
catch
    txt = jsonencode(S);
end
fid = fopen(path, 'w');
assert(fid > 0, 'Could not open JSON output: %s', path);
fprintf(fid, '%s\n', txt);
fclose(fid);
end
