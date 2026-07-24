%% project_geodesic_velocity_VectorVision_UNIFIED
% Unified H5 SSOT -> Geodesic Velocity -> VectorVision
%
% Source of truth:
% /MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5

clear; clc; close all;

%% =========================
%  0. FIXED SSOT PATH
% ==========================

PROJECT_NAME = "project_geodesic_velocity_VectorVision_UNIFIED";

H5_FILE = "jsonhotel_unified_001_002_SAFE_20260628_181406.h5";
H5_PATH = fullfile("/MATLAB Drive", "modelTRAINING", H5_FILE);

if ~isfile(H5_PATH)
    error("SSOT H5 not found: %s", H5_PATH);
end

timestamp = string(datetime("now","Format","yyyyMMdd_HHmmss"));
OUT_DIR = fullfile("/MATLAB Drive", "modelTRAINING", ...
    "VectorVision_geodesic_velocity_" + timestamp);
FRAME_DIR = fullfile(OUT_DIR, "frames");

mkdir(OUT_DIR);
mkdir(FRAME_DIR);

fprintf("\n=== %s ===\n", PROJECT_NAME);
fprintf("SSOT H5:\n%s\n\n", H5_PATH);
fprintf("Output folder:\n%s\n\n", OUT_DIR);

%% =========================
%  1. CONFIG
% ==========================

OUT_SIZE = [1024 1024];

T = 48;
SAVE_EVERY = 4;

W.physical_preserve = 0.58;
W.symmetry          = 0.18;
W.harmonic_smooth   = 0.12;
W.geodesic_flow     = 0.12;

EPS0 = 1e-9;

C_LIGHT = 299792458;
C2 = C_LIGHT^2;

MIN_SIGNIFICANT_RATIO = 10;
MIN_SUPPORT_FRACTION = 0.001;

%% =========================
%  2. READ H5 CONTENT
% ==========================

info = h5info(H5_PATH);
allDatasets = list_numeric_h5_datasets(info);

if isempty(allDatasets)
    error("No numeric datasets found inside SSOT H5.");
end

selected = select_ssot_datasets(allDatasets);

fprintf("Numeric datasets found: %d\n", numel(allDatasets));
fprintf("Selected datasets for computation:\n");
for k = 1:numel(selected)
    fprintf("  %02d | %s | size=%s | score=%.3f\n", ...
        k, selected(k).path, mat2str(selected(k).size), selected(k).score);
end

datasetTable = struct2table(selected);
writetable(datasetTable, fullfile(OUT_DIR, "0000_h5_dataset_selection.csv"));

%% =========================
%  3. BUILD SSOT FIELD
% ==========================

maps = cell(1, numel(selected));

for k = 1:numel(selected)
    raw = h5read(H5_PATH, selected(k).path);
    maps{k} = numeric_to_map(raw, OUT_SIZE);
end

F0 = combine_maps(maps);
F0 = normalize01(F0);

P0 = structure_layer(F0);

[H, Wd] = size(F0);
[x, y] = meshgrid(linspace(-1,1,Wd), linspace(-1,1,H));

r = sqrt(x.^2 + y.^2);
theta = atan2(y,x);

rNorm = normalize01(r);
thetaNorm = normalize01(theta + pi);

[Fx0, Fy0] = gradient(F0);
gradMag0 = normalize01(sqrt(Fx0.^2 + Fy0.^2));

metric = 1 ./ (EPS0 + 0.20 + 0.45 .* P0 + 0.35 .* gradMag0);
metric = normalize01(metric);

geoPotential = normalize01( ...
    0.45 .* F0 + ...
    0.30 .* P0 + ...
    0.15 .* (1 - rNorm) + ...
    0.10 .* thetaNorm ...
);

[Vx, Vy] = gradient(geoPotential);
vmag = sqrt(Vx.^2 + Vy.^2) + EPS0;
Vx = Vx ./ vmag;
Vy = Vy ./ vmag;

velocityMagnitude = normalize01(sqrt(Vx.^2 + Vy.^2) .* (0.25 + metric));

fprintf("\nSSOT field built.\n");
fprintf("Field size: %dx%d\n\n", H, Wd);

imwrite(F0, fullfile(OUT_DIR, "0100_ssot_scalar_field.png"));
imwrite(P0, fullfile(OUT_DIR, "0200_ssot_structure_layer.png"));
imwrite(metric, fullfile(OUT_DIR, "0300_ssot_geodesic_metric.png"));
imwrite(velocityMagnitude, fullfile(OUT_DIR, "0400_ssot_velocity_magnitude.png"));

%% =========================
%  4. TEMPORAL GEODESIC ORGANIZATION
% ==========================

F = F0;

for t = 0:T

    tau = t / max(T,1);

    if mod(t, SAVE_EVERY) == 0 || t == 0 || t == T
        frameRGB = render_vectorvision_rgb(F, Vx, Vy, metric, thetaNorm, rNorm);
        frameName = sprintf("frame_%03d.png", t);
        imwrite(frameRGB, fullfile(FRAME_DIR, frameName));
    end

    if t == T
        break;
    end

    S = symmetry_field(F);
    Hs = gaussian_blur2(F, 1.25 + 1.75*tau);

    [Fx, Fy] = gradient(F);
    flowPush = Vx .* Fx + Vy .* Fy;
    G = normalize01(F + 0.15 .* flowPush .* (0.25 + metric));

    radialWeight = exp(-2.0 .* rNorm) .* (0.65 + 0.35 .* sin(2*pi*tau + theta).^2);
    timeField = normalize01((1 - radialWeight).*F + radialWeight.*G);

    Fnext = ...
        W.physical_preserve .* F0 + ...
        W.symmetry          .* S + ...
        W.harmonic_smooth   .* Hs + ...
        W.geodesic_flow     .* timeField;

    F = normalize01(Fnext);
end

VectorVision = render_vectorvision_rgb(F, Vx, Vy, metric, thetaNorm, rNorm);

imwrite(VectorVision, fullfile(OUT_DIR, "1111_VectorVision_final.png"));
imwrite(F, fullfile(OUT_DIR, "1112_VectorVision_final_scalar.png"));

%% =========================
%  5. PROJECTION / SHADOW LAW TESTS FROM H5 FIELD
% ==========================

projectionTests = run_projection_law_tests(Vx, Vy, x, y, Fx0, Fy0);
writetable(projectionTests, fullfile(OUT_DIR, "2222_projection_law_tests_from_h5.csv"));

%% =========================
%  6. GEODESIC VELOCITY SQUARED VS C^2
% ==========================

lightReport = test_geodesic_velocity_squared_vs_light( ...
    H5_PATH, Vx, Vy, metric, C2, ...
    MIN_SIGNIFICANT_RATIO, MIN_SUPPORT_FRACTION);

write_json(fullfile(OUT_DIR, "3333_geodesic_velocity_squared_vs_c2_report.json"), lightReport);

fprintf("\n%s\n\n", lightReport.conclusion);

%% =========================
%  7. METRICS + MANIFEST
% ==========================

metrics = struct();
metrics.project = PROJECT_NAME;
metrics.h5_path = H5_PATH;
metrics.h5_sha256 = sha256_file_safe(H5_PATH);
metrics.output_folder = OUT_DIR;
metrics.field_size = [H Wd];
metrics.time_steps = T;
metrics.selected_dataset_count = numel(selected);
metrics.metric_mean = mean(metric(:), "omitnan");
metrics.metric_std = std(metric(:), 0, "omitnan");
metrics.velocity_magnitude_mean = mean(velocityMagnitude(:), "omitnan");
metrics.velocity_magnitude_max = max(velocityMagnitude(:));
metrics.final_scalar_mean = mean(F(:), "omitnan");
metrics.final_scalar_std = std(F(:), 0, "omitnan");
metrics.light_speed_status = lightReport.status;
metrics.light_speed_conclusion = lightReport.conclusion;

write_json(fullfile(OUT_DIR, "4444_VectorVision_metrics.json"), metrics);

fid = fopen(fullfile(OUT_DIR, "6666_manifest_sha256.txt"), "w");
fprintf(fid, "PROJECT=%s\n", PROJECT_NAME);
fprintf(fid, "H5_PATH=%s\n", H5_PATH);
fprintf(fid, "H5_SHA256=%s\n", metrics.h5_sha256);
fprintf(fid, "OUT_DIR=%s\n", OUT_DIR);
fclose(fid);

fprintf("DONE.\n");
fprintf("VectorVision created.\n\n");
fprintf("Main output:\n%s\n", fullfile(OUT_DIR, "1111_VectorVision_final.png"));
fprintf("Folder:\n%s\n", OUT_DIR);

%% ============================================================
%  LOCAL FUNCTIONS
% ============================================================

function datasets = list_numeric_h5_datasets(info)
    datasets = struct("path", {}, "size", {}, "rank", {}, "numel", {}, "class", {}, "score", {});
    datasets = walk_group(info, datasets);
end

function datasets = walk_group(groupInfo, datasets)

    for i = 1:numel(groupInfo.Datasets)
        ds = groupInfo.Datasets(i);

        dsPath = h5_join(groupInfo.Name, ds.Name);
        dsSize = double(ds.Dataspace.Size);
        if isempty(dsSize)
            dsSize = 1;
        end

        dsClass = "";
        try
            dsClass = string(ds.Datatype.Class);
        catch
            dsClass = "UNKNOWN";
        end

        isNumeric = contains(upper(dsClass), "FLOAT") || ...
                    contains(upper(dsClass), "INTEGER") || ...
                    contains(upper(dsClass), "FIXED");

        n = prod(dsSize);

        if isNumeric && n >= 16 && n <= 2e7
            rec.path = string(dsPath);
            rec.size = dsSize;
            rec.rank = numel(dsSize);
            rec.numel = n;
            rec.class = dsClass;
            rec.score = 0;
            datasets(end+1) = rec; %#ok<AGROW>
        end
    end

    for g = 1:numel(groupInfo.Groups)
        datasets = walk_group(groupInfo.Groups(g), datasets);
    end
end

function selected = select_ssot_datasets(datasets)

    for k = 1:numel(datasets)
        p = lower(string(datasets(k).path));
        sz = datasets(k).size;
        rank = datasets(k).rank;
        n = datasets(k).numel;

        score = 0;

        if rank >= 2
            score = score + 10;
        end

        if any(sz >= 128)
            score = score + 4;
        end

        if n >= 1e5
            score = score + 3;
        end

        keywords = ["field","map","data","image","pattern","composite","matrix","surface","grid","n_5","1000","projection","vector","eta","phase","time"];

        for j = 1:numel(keywords)
            if contains(p, keywords(j))
                score = score + 1.25;
            end
        end

        if contains(p, "label") || contains(p, "name") || contains(p, "index")
            score = score - 2;
        end

        datasets(k).score = score;
    end

    scores = [datasets.score];
    [~, idx] = sort(scores, "descend");

    maxTake = min(8, numel(idx));
    selected = datasets(idx(1:maxTake));
end

function M = numeric_to_map(raw, outSize)

    A = raw;

    if ~isnumeric(A) && ~islogical(A)
        error("Dataset is not numeric after h5read.");
    end

    A = double(A);

    if ~isreal(A)
        A = abs(A);
    end

    A = squeeze(A);

    if isvector(A)
        v = A(:);
        n = floor(sqrt(numel(v)));
        if n < 4
            M = zeros(outSize);
            return;
        end
        v = v(1:n*n);
        A = reshape(v, n, n);
    elseif ndims(A) > 2
        sz = size(A);
        A = reshape(A, sz(1), sz(2), []);
        A = mean(A, 3, "omitnan");
    end

    A(~isfinite(A)) = 0;
    A = normalize01(A);
    M = resize2(A, outSize);
    M = normalize01(M);
end

function F = combine_maps(maps)

    F = zeros(size(maps{1}));
    wsum = 0;

    for k = 1:numel(maps)
        M = normalize01(maps{k});
        [Mx, My] = gradient(M);
        energy = mean(sqrt(Mx.^2 + My.^2), "all", "omitnan");
        w = 1 + energy;
        F = F + w .* M;
        wsum = wsum + w;
    end

    F = F ./ max(wsum, eps);
    F = normalize01(F);
end

function P = structure_layer(F)

    [Fx, Fy] = gradient(F);
    G = sqrt(Fx.^2 + Fy.^2);

    L = del2(F);
    L = abs(L);

    P = normalize01(0.65 .* normalize01(G) + 0.35 .* normalize01(L));
    P = gaussian_blur2(P, 0.75);
    P = normalize01(P);
end

function S = symmetry_field(F)

    A = F;

    S1 = 0.25 .* (A + fliplr(A) + flipud(A) + rot90(A,2));

    if size(A,1) == size(A,2)
        D1 = A.';
        D2 = fliplr(flipud(A.'));
        S2 = 0.5 .* (D1 + D2);
        S = 0.70 .* S1 + 0.30 .* S2;
    else
        S = S1;
    end

    S = normalize01(S);
end

function RGB = render_vectorvision_rgb(F, Vx, Vy, metric, thetaNorm, rNorm)

    F = normalize01(F);
    M = normalize01(metric);

    V = normalize01(sqrt(Vx.^2 + Vy.^2));

    hue = normalize01(0.62 .* thetaNorm + 0.20 .* F + 0.18 .* M);
    sat = normalize01(0.35 + 0.45 .* M + 0.20 .* V);
    val = normalize01(0.20 + 0.62 .* F + 0.18 .* (1-rNorm));

    RGB = hsv2rgb(cat(3, hue, sat, val));

    grayLayer = repmat(F, 1, 1, 3);
    RGB = normalize01(0.72 .* RGB + 0.28 .* grayLayer);
end

function TBL = run_projection_law_tests(Vx, Vy, x, y, Fx, Fy)

    speed2 = Vx.^2 + Vy.^2;

    cases = {};

    ux1 = Vx;
    uy1 = Vy;
    [ux1, uy1] = normalize_vec(ux1, uy1);
    cases{end+1} = {"CASE_1_H5_self_aligned_velocity", ux1, uy1};

    ux2 = x;
    uy2 = y;
    [ux2, uy2] = normalize_vec(ux2, uy2);
    cases{end+1} = {"CASE_2_H5_radial_direction", ux2, uy2};

    ux3 = Fx;
    uy3 = Fy;
    [ux3, uy3] = normalize_vec(ux3, uy3);
    cases{end+1} = {"CASE_3_H5_gradient_direction", ux3, uy3};

    rows = [];

    for i = 1:numel(cases)
        caseName = string(cases{i}{1});
        ux = cases{i}{2};
        uy = cases{i}{3};

        scalarCoef = Vx .* ux + Vy .* uy;
        shadowNorm2 = scalarCoef.^2 .* (ux.^2 + uy.^2);
        signedComponentSquared = scalarCoef.^2;

        rows = [rows; make_projection_row(caseName, "H1_scalar_coef_equals_speed2", scalarCoef, speed2)]; %#ok<AGROW>
        rows = [rows; make_projection_row(caseName, "H2_shadow_norm2_equals_speed2", shadowNorm2, speed2)]; %#ok<AGROW>
        rows = [rows; make_projection_row(caseName, "H3_signed_component_squared_equals_speed2", signedComponentSquared, speed2)]; %#ok<AGROW>
    end

    TBL = struct2table(rows);
end

function row = make_projection_row(caseName, candidate, A, B)

    valid = isfinite(A) & isfinite(B);

    Av = A(valid);
    Bv = B(valid);

    err = Av - Bv;

    maxAbsError = max(abs(err));
    relativeRMSE = sqrt(mean(err.^2)) / max(sqrt(mean(Bv.^2)), eps);

    if std(Av) < eps || std(Bv) < eps
        corrVal = NaN;
    else
        C = corrcoef(Av, Bv);
        corrVal = C(1,2);
    end

    if maxAbsError < 1e-9 && relativeRMSE < 1e-9
        status = "EXACT_PASS";
    elseif relativeRMSE < 0.05 && corrVal > 0.95
        status = "APPROX_PASS";
    else
        status = "FAIL_OR_CONDITIONAL";
    end

    row = struct();
    row.CaseName = caseName;
    row.Candidate = string(candidate);
    row.MaxAbsError = maxAbsError;
    row.RelativeRMSE = relativeRMSE;
    row.Correlation = corrVal;
    row.Status = status;
end

function report = test_geodesic_velocity_squared_vs_light( ...
    h5Path, Vx, Vy, metric, c2, minSignificantRatio, minSupportFraction)

    cal = read_h5_space_time_calibration(h5Path);

    report = struct();
    report.equation = "v_g^2 = metric(x,y) * ((Vx*dx_m/dt_s)^2 + (Vy*dx_m/dt_s)^2)";
    report.compare_to = "c^2";
    report.c_m_per_s = sqrt(c2);
    report.c_squared = c2;
    report.min_significant_ratio = minSignificantRatio;
    report.min_support_fraction = minSupportFraction;
    report.physical_calibration_found_in_h5 = cal.ok;

    if ~cal.ok
        dimless_vg2 = metric .* (Vx.^2 + Vy.^2);
        dimless_vg2 = dimless_vg2(isfinite(dimless_vg2));

        report.status = "NO_H5_PHYSICAL_CALIBRATION";
        report.dx_m = NaN;
        report.dt_s = NaN;
        report.dimensionless_vg2_max = max(dimless_vg2);
        report.dimensionless_vg2_p99 = prctile(dimless_vg2, 99);
        report.conclusion = "RESULT: H5 field was computed, but c^2 comparison was not physically evaluated because dx_m and dt_s were not found inside the H5.";
        return;
    end

    dx_m = cal.dx_m;
    dt_s = cal.dt_s;

    vx_mps = Vx .* dx_m ./ dt_s;
    vy_mps = Vy .* dx_m ./ dt_s;

    vg2 = metric .* (vx_mps.^2 + vy_mps.^2);
    ratio = vg2 ./ c2;

    valid = isfinite(ratio) & isfinite(vg2);
    ratioVals = ratio(valid);

    ratio_max = max(ratioVals);
    ratio_p99 = prctile(ratioVals, 99);
    ratio_p95 = prctile(ratioVals, 95);
    ratio_median = median(ratioVals);

    support_above_c2 = mean(ratioVals > 1);
    support_significant = mean(ratioVals > minSignificantRatio);

    report.dx_m = dx_m;
    report.dt_s = dt_s;
    report.ratio_max = ratio_max;
    report.ratio_p99 = ratio_p99;
    report.ratio_p95 = ratio_p95;
    report.ratio_median = ratio_median;
    report.support_fraction_above_c2 = support_above_c2;
    report.support_fraction_significant = support_significant;

    if ratio_p99 >= minSignificantRatio && support_significant >= minSupportFraction
        report.status = "SIGNIFICANT_EXCEEDS_C2";
        report.conclusion = sprintf( ...
            "MATHEMATICAL RESULT: geodesic velocity squared exceeds c^2 significantly. p99(v_g^2/c^2)=%.6g, max=%.6g, support=%.6g.", ...
            ratio_p99, ratio_max, support_significant);
    elseif ratio_max > 1
        report.status = "LOCAL_EXCEEDS_C2";
        report.conclusion = sprintf( ...
            "MATHEMATICAL RESULT: geodesic velocity squared exceeds c^2 locally, but not significantly by threshold. p99=%.6g, max=%.6g, support=%.6g.", ...
            ratio_p99, ratio_max, support_above_c2);
    else
        report.status = "DOES_NOT_EXCEED_C2";
        report.conclusion = sprintf( ...
            "MATHEMATICAL RESULT: geodesic velocity squared does not exceed c^2. max(v_g^2/c^2)=%.6g.", ...
            ratio_max);
    end
end

function cal = read_h5_space_time_calibration(h5Path)

    info = h5info(h5Path);

    dxNames = [
        "dx_m"
        "pixel_size_m"
        "meter_per_pixel"
        "meters_per_pixel"
        "spatial_step_m"
        "x_step_m"
    ];

    dtNames = [
        "dt_s"
        "time_step_s"
        "seconds_per_step"
        "seconds_per_frame"
        "sample_period_s"
        "temporal_step_s"
    ];

    dx = find_h5_attribute_recursive(h5Path, info, dxNames);
    dt = find_h5_attribute_recursive(h5Path, info, dtNames);

    cal = struct();
    cal.dx_m = dx;
    cal.dt_s = dt;
    cal.ok = ~isempty(dx) && ~isempty(dt) && isfinite(dx) && isfinite(dt) && dx > 0 && dt > 0;
end

function value = find_h5_attribute_recursive(h5Path, groupInfo, candidateNames)

    value = [];

    value = scan_attrs(h5Path, groupInfo.Name, groupInfo.Attributes, candidateNames);
    if ~isempty(value); return; end

    for k = 1:numel(groupInfo.Datasets)
        dsPath = h5_join(groupInfo.Name, groupInfo.Datasets(k).Name);
        value = scan_attrs(h5Path, dsPath, groupInfo.Datasets(k).Attributes, candidateNames);
        if ~isempty(value); return; end
    end

    for k = 1:numel(groupInfo.Groups)
        value = find_h5_attribute_recursive(h5Path, groupInfo.Groups(k), candidateNames);
        if ~isempty(value); return; end
    end
end

function value = scan_attrs(h5Path, objPath, attrs, candidateNames)

    value = [];

    for i = 1:numel(attrs)
        attrName = string(attrs(i).Name);

        if any(strcmpi(attrName, candidateNames))
            raw = h5readatt(h5Path, objPath, attrs(i).Name);
            value = scalar_numeric(raw);
            return;
        end
    end
end

function y = scalar_numeric(x)

    if isnumeric(x)
        y = double(x(1));
        return;
    end

    if isstring(x) || ischar(x)
        y = str2double(string(x));
        return;
    end

    y = [];
end

function [ux, uy] = normalize_vec(x, y)

    mag = sqrt(x.^2 + y.^2);
    mag(mag < eps) = 1;

    ux = x ./ mag;
    uy = y ./ mag;

    ux(~isfinite(ux)) = 0;
    uy(~isfinite(uy)) = 0;
end

function B = resize2(A, outSize)

    if exist("imresize", "file") == 2
        B = imresize(A, outSize, "bilinear");
        return;
    end

    [h, w] = size(A);
    [x, y] = meshgrid(1:w, 1:h);
    [xq, yq] = meshgrid(linspace(1,w,outSize(2)), linspace(1,h,outSize(1)));
    B = interp2(x, y, A, xq, yq, "linear", 0);
end

function B = gaussian_blur2(A, sigma)

    sigma = max(double(sigma), 0.01);

    if exist("imgaussfilt", "file") == 2
        B = imgaussfilt(A, sigma);
        return;
    end

    radius = max(1, ceil(3*sigma));
    x = -radius:radius;
    g = exp(-(x.^2) ./ (2*sigma^2));
    g = g ./ sum(g);

    B = conv2(conv2(A, g, "same"), g.', "same");
end

function Y = normalize01(X)

    X = double(X);
    X(~isfinite(X)) = NaN;

    mn = min(X(:), [], "omitnan");
    mx = max(X(:), [], "omitnan");

    if isempty(mn) || isempty(mx) || ~isfinite(mn) || ~isfinite(mx) || abs(mx-mn) < eps
        Y = zeros(size(X));
        return;
    end

    Y = (X - mn) ./ (mx - mn);
    Y(~isfinite(Y)) = 0;
    Y = min(max(Y, 0), 1);
end

function p = h5_join(parent, child)

    parent = char(parent);
    child = char(child);

    if strcmp(parent, "/")
        p = ["/" child];
    else
        p = [parent "/" child];
    end
end

function write_json(path, data)

    try
        txt = jsonencode(data, "PrettyPrint", true);
    catch
        txt = jsonencode(data);
    end

    fid = fopen(path, "w");
    fprintf(fid, "%s", txt);
    fclose(fid);
end

function h = sha256_file_safe(path)

    try
        md = java.security.MessageDigest.getInstance("SHA-256");
        fis = java.io.FileInputStream(java.io.File(char(path)));
        buffer = zeros(1, 8192, "uint8");

        while true
            n = fis.read(buffer, 0, numel(buffer));
            if n == -1
                break;
            end
            md.update(buffer(1:n));
        end

        fis.close();
        hash = typecast(md.digest(), "uint8");
        h = lower(reshape(dec2hex(hash).', 1, []));
        h = string(h);

    catch
        h = "SHA256_UNAVAILABLE";
    end
end