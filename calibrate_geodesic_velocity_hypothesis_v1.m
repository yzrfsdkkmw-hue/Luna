%% calibrate_geodesic_velocity_hypothesis_v1
% SSOT H5 -> calibration search -> projection/shadow tests -> vg^2/c^2 test
%
% Reads ONLY:
% /MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5
%
% Writes outputs only to a new folder.

clear; clc; close all;

%% =========================
%  0. FIXED SSOT PATH
% ==========================

PROJECT_NAME = 'calibrate_geodesic_velocity_hypothesis_v1';

H5_FILE = 'jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
H5_PATH = fullfile('/MATLAB Drive', 'modelTRAINING', H5_FILE);

if ~isfile(H5_PATH)
    error('SSOT H5 not found: %s', H5_PATH);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');

OUT_DIR = fullfile('/MATLAB Drive', 'modelTRAINING', ...
    ['geodesic_velocity_calibration_' timestamp]);

if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

fprintf('\n=== %s ===\n', PROJECT_NAME);
fprintf('SSOT H5:\n%s\n\n', H5_PATH);
fprintf('Output folder:\n%s\n\n', OUT_DIR);

%% =========================
%  1. CONFIG
% ==========================

OUT_SIZE = [1024 1024];

C_LIGHT = 299792458;
C2 = C_LIGHT^2;

MIN_SIGNIFICANT_RATIO = 10;
MIN_SUPPORT_FRACTION = 0.001;

EPS0 = 1e-12;

% Optional manual override.
% Default = disabled. The script first tries to read calibration from H5.
CALIBRATION_OVERRIDE_ENABLED = false;
DX_M_OVERRIDE = NaN;
DT_S_OVERRIDE = NaN;

%% =========================
%  2. READ H5 + SELECT NUMERIC MAPS
% ==========================

info = h5info(H5_PATH);
allDatasets = list_numeric_h5_datasets(info);

if isempty(allDatasets)
    error('No numeric datasets found inside H5.');
end

selected = select_ssot_datasets(allDatasets);

fprintf('Numeric datasets found: %d\n', numel(allDatasets));
fprintf('Selected datasets:\n');

for k = 1:numel(selected)
    fprintf('  %02d | %s | size=%s | score=%.3f\n', ...
        k, selected(k).path, size_to_string(selected(k).size), selected(k).score);
end

write_dataset_selection_csv(fullfile(OUT_DIR, '0000_h5_dataset_selection.csv'), selected);

%% =========================
%  3. BUILD H5 FIELD
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

% Raw geodesic direction/magnitude in grid units per computational step.
[Vx_raw, Vy_raw] = gradient(geoPotential);

rawSpeed2 = Vx_raw.^2 + Vy_raw.^2;

% Unit vector version for direction-only projection tests.
rawMag = sqrt(rawSpeed2) + EPS0;
Vx_unit = Vx_raw ./ rawMag;
Vy_unit = Vy_raw ./ rawMag;

Vx_unit(~isfinite(Vx_unit)) = 0;
Vy_unit(~isfinite(Vy_unit)) = 0;

% Candidate dimensionless geodesic velocity squared.
vg2_dimless_raw  = metric .* rawSpeed2;
vg2_dimless_unit = metric .* (Vx_unit.^2 + Vy_unit.^2);

imwrite(F0, fullfile(OUT_DIR, '0100_ssot_scalar_field.png'));
imwrite(P0, fullfile(OUT_DIR, '0200_structure_layer.png'));
imwrite(metric, fullfile(OUT_DIR, '0300_geodesic_metric.png'));
imwrite(normalize01(vg2_dimless_raw), fullfile(OUT_DIR, '0400_vg2_dimless_raw_map.png'));
imwrite(normalize01(vg2_dimless_unit), fullfile(OUT_DIR, '0500_vg2_dimless_unit_map.png'));

fprintf('\nH5 field built.\n');
fprintf('Field size: %dx%d\n\n', H, Wd);

%% =========================
%  4. CALIBRATION DISCOVERY
% ==========================

calH5 = discover_h5_calibration(H5_PATH);

cal = calH5;

if CALIBRATION_OVERRIDE_ENABLED
    cal.dx_m = DX_M_OVERRIDE;
    cal.dt_s = DT_S_OVERRIDE;
    cal.source = 'MANUAL_OVERRIDE';
    cal.ok = isfinite(DX_M_OVERRIDE) && isfinite(DT_S_OVERRIDE) && ...
             DX_M_OVERRIDE > 0 && DT_S_OVERRIDE > 0;
end

write_json(fullfile(OUT_DIR, '1111_calibration_discovery.json'), calH5);

%% =========================
%  5. PROJECTION / SHADOW HYPOTHESIS TESTS
% ==========================

projectionReport = run_projection_hypothesis_tests( ...
    Vx_raw, Vy_raw, Vx_unit, Vy_unit, x, y, Fx0, Fy0, metric);

write_projection_csv(fullfile(OUT_DIR, '2222_projection_shadow_hypothesis_tests.csv'), projectionReport);

%% =========================
%  6. CALIBRATED vg^2 / c^2 TEST
% ==========================

testRaw = test_vg2_against_c2( ...
    'RAW_GRADIENT_GEODESIC_VELOCITY', ...
    vg2_dimless_raw, cal, C2, MIN_SIGNIFICANT_RATIO, MIN_SUPPORT_FRACTION);

testUnit = test_vg2_against_c2( ...
    'UNIT_DIRECTION_GEODESIC_VELOCITY', ...
    vg2_dimless_unit, cal, C2, MIN_SIGNIFICANT_RATIO, MIN_SUPPORT_FRACTION);

thresholdRaw = compute_required_calibration_thresholds( ...
    vg2_dimless_raw, C_LIGHT, MIN_SIGNIFICANT_RATIO);

thresholdUnit = compute_required_calibration_thresholds( ...
    vg2_dimless_unit, C_LIGHT, MIN_SIGNIFICANT_RATIO);

finalReport = struct();
finalReport.project = PROJECT_NAME;
finalReport.h5_path = H5_PATH;
finalReport.h5_sha256 = sha256_file_safe(H5_PATH);
finalReport.output_folder = OUT_DIR;
finalReport.field_height = H;
finalReport.field_width = Wd;
finalReport.calibration_used = cal;
finalReport.test_raw_gradient = testRaw;
finalReport.test_unit_direction = testUnit;
finalReport.required_threshold_raw_gradient = thresholdRaw;
finalReport.required_threshold_unit_direction = thresholdUnit;
finalReport.projection_summary = projectionReport;
finalReport.rule = 'Physical comparison to c^2 is valid only if dx_m and dt_s are found in H5 or explicitly supplied by override.';

write_json(fullfile(OUT_DIR, '3333_geodesic_velocity_c2_calibration_report.json'), finalReport);

%% =========================
%  7. SUMMARY MD
% ==========================

summaryPath = fullfile(OUT_DIR, '4444_calibration_summary.md');
fid = fopen(summaryPath, 'w');

fprintf(fid, '# Geodesic Velocity Calibration Summary\n\n');
fprintf(fid, 'Project: `%s`\n\n', PROJECT_NAME);
fprintf(fid, 'H5: `%s`\n\n', H5_PATH);
fprintf(fid, 'H5 SHA256: `%s`\n\n', finalReport.h5_sha256);

fprintf(fid, '## Calibration\n\n');
fprintf(fid, '- calibration_found: `%d`\n', cal.ok);
fprintf(fid, '- calibration_source: `%s`\n', cal.source);
fprintf(fid, '- dx_m: `%.17g`\n', cal.dx_m);
fprintf(fid, '- dt_s: `%.17g`\n\n', cal.dt_s);

fprintf(fid, '## Raw-gradient vg^2/c^2 test\n\n');
fprintf(fid, '- status: `%s`\n', testRaw.status);
fprintf(fid, '- conclusion: %s\n\n', testRaw.conclusion);

fprintf(fid, '## Unit-direction vg^2/c^2 test\n\n');
fprintf(fid, '- status: `%s`\n', testUnit.status);
fprintf(fid, '- conclusion: %s\n\n', testUnit.conclusion);

fprintf(fid, '## Required dx/dt thresholds if calibration is missing\n\n');
fprintf(fid, 'Raw-gradient candidate:\n\n');
fprintf(fid, '- required dx/dt for vg^2 > c^2 at p99: `%.17g m/s`\n', thresholdRaw.required_dx_over_dt_for_c2_p99);
fprintf(fid, '- required dx/dt for significant threshold: `%.17g m/s`\n\n', thresholdRaw.required_dx_over_dt_for_significant_p99);

fprintf(fid, 'Unit-direction candidate:\n\n');
fprintf(fid, '- required dx/dt for vg^2 > c^2 at p99: `%.17g m/s`\n', thresholdUnit.required_dx_over_dt_for_c2_p99);
fprintf(fid, '- required dx/dt for significant threshold: `%.17g m/s`\n\n', thresholdUnit.required_dx_over_dt_for_significant_p99);

fprintf(fid, '## Interpretation\n\n');
if cal.ok
    fprintf(fid, 'A physical comparison was performed because dx_m and dt_s were available.\n');
else
    fprintf(fid, 'The H5 field was computed, but physical comparison to c^2 was not finalized because dx_m and dt_s were not found inside the H5 and manual override was disabled.\n');
end

fclose(fid);

%% =========================
%  8. MANIFEST
% ==========================

fid = fopen(fullfile(OUT_DIR, '6666_manifest.txt'), 'w');
fprintf(fid, 'PROJECT=%s\n', PROJECT_NAME);
fprintf(fid, 'H5_PATH=%s\n', H5_PATH);
fprintf(fid, 'H5_SHA256=%s\n', finalReport.h5_sha256);
fprintf(fid, 'OUT_DIR=%s\n', OUT_DIR);
fprintf(fid, 'CALIBRATION_OK=%d\n', cal.ok);
fprintf(fid, 'CALIBRATION_SOURCE=%s\n', cal.source);
fprintf(fid, 'RAW_STATUS=%s\n', testRaw.status);
fprintf(fid, 'UNIT_STATUS=%s\n', testUnit.status);
fclose(fid);

fprintf('\nDONE.\n');
fprintf('Calibration report created.\n\n');
fprintf('Main report:\n%s\n', fullfile(OUT_DIR, '3333_geodesic_velocity_c2_calibration_report.json'));
fprintf('Summary:\n%s\n', summaryPath);
fprintf('Folder:\n%s\n', OUT_DIR);

%% ============================================================
%  LOCAL FUNCTIONS
% ============================================================

function datasets = list_numeric_h5_datasets(info)
    datasets = struct('path', {}, 'size', {}, 'rank', {}, 'numel', {}, 'class', {}, 'score', {});
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

        dsClass = 'UNKNOWN';
        try
            dsClass = char(ds.Datatype.Class);
        catch
            dsClass = 'UNKNOWN';
        end

        dsClassUpper = upper(dsClass);

        isNumeric = ~isempty(strfind(dsClassUpper, 'FLOAT')) || ...
                    ~isempty(strfind(dsClassUpper, 'INTEGER')) || ...
                    ~isempty(strfind(dsClassUpper, 'FIXED'));

        n = prod(dsSize);

        if isNumeric && n >= 16 && n <= 2e7
            rec.path = dsPath;
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
        p = lower(char(datasets(k).path));

        sz = double(datasets(k).size);
        rankVal = double(datasets(k).rank);
        n = double(datasets(k).numel);

        score = 0;

        if rankVal >= 2
            score = score + 10;
        end

        if any(sz >= 128)
            score = score + 4;
        end

        if n >= 1e5
            score = score + 3;
        end

        keywords = { ...
            'field','map','data','image','pattern','composite', ...
            'matrix','surface','grid','n_5','1000','projection', ...
            'vector','eta','phase','time','sample','roi' ...
        };

        for j = 1:numel(keywords)
            if ~isempty(strfind(p, keywords{j})) %#ok<STREMP>
                score = score + 1.25;
            end
        end

        negativeKeywords = {'label','name','index'};

        for j = 1:numel(negativeKeywords)
            if ~isempty(strfind(p, negativeKeywords{j})) %#ok<STREMP>
                score = score - 2;
            end
        end

        datasets(k).score = score;
    end

    scores = [datasets.score];
    [~, idx] = sort(scores, 'descend');

    selected = datasets(idx(1:min(8, numel(idx))));
end

function M = numeric_to_map(raw, outSize)

    A = raw;

    if ~isnumeric(A) && ~islogical(A)
        error('Dataset is not numeric after h5read.');
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
        A = nanmean_local(A, 3);
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
        energy = nanmean_local(sqrt(Mx.^2 + My.^2));
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

function cal = discover_h5_calibration(h5Path)

    info = h5info(h5Path);

    dxDirect = { ...
        'dx_m', 'pixel_size_m', 'meter_per_pixel', 'meters_per_pixel', ...
        'spatial_step_m', 'x_step_m', 'resolution_m_per_pixel' ...
    };

    dxMM = { ...
        'dx_mm', 'pixel_size_mm', 'millimeter_per_pixel', 'millimeters_per_pixel' ...
    };

    dxUM = { ...
        'dx_um', 'pixel_size_um', 'micrometer_per_pixel', 'micrometers_per_pixel', ...
        'micron_per_pixel', 'microns_per_pixel' ...
    };

    dtDirect = { ...
        'dt_s', 'time_step_s', 'seconds_per_step', 'seconds_per_frame', ...
        'sample_period_s', 'temporal_step_s', 'period_s' ...
    };

    dtMS = { ...
        'dt_ms', 'time_step_ms', 'milliseconds_per_step', 'milliseconds_per_frame' ...
    };

    rateHz = { ...
        'sample_rate_hz', 'sampling_rate_hz', 'frame_rate_hz', 'fps', 'frequency_hz' ...
    };

    dx_m = [];
    dx_source = '';

    [v, src] = find_h5_named_scalar(h5Path, info, dxDirect);
    if ~isempty(v)
        dx_m = v;
        dx_source = src;
    else
        [v, src] = find_h5_named_scalar(h5Path, info, dxMM);
        if ~isempty(v)
            dx_m = v * 1e-3;
            dx_source = [src ' *1e-3'];
        else
            [v, src] = find_h5_named_scalar(h5Path, info, dxUM);
            if ~isempty(v)
                dx_m = v * 1e-6;
                dx_source = [src ' *1e-6'];
            end
        end
    end

    dt_s = [];
    dt_source = '';

    [v, src] = find_h5_named_scalar(h5Path, info, dtDirect);
    if ~isempty(v)
        dt_s = v;
        dt_source = src;
    else
        [v, src] = find_h5_named_scalar(h5Path, info, dtMS);
        if ~isempty(v)
            dt_s = v * 1e-3;
            dt_source = [src ' *1e-3'];
        else
            [v, src] = find_h5_named_scalar(h5Path, info, rateHz);
            if ~isempty(v) && v > 0
                dt_s = 1 / v;
                dt_source = ['1 / ' src];
            end
        end
    end

    cal = struct();
    cal.ok = ~isempty(dx_m) && ~isempty(dt_s) && ...
             isfinite(dx_m) && isfinite(dt_s) && dx_m > 0 && dt_s > 0;
    cal.dx_m = value_or_nan(dx_m);
    cal.dt_s = value_or_nan(dt_s);
    cal.dx_source = dx_source;
    cal.dt_source = dt_source;

    if cal.ok
        cal.source = 'H5_DISCOVERED';
        cal.dx_over_dt_m_per_s = cal.dx_m / cal.dt_s;
    else
        cal.source = 'NOT_FOUND_IN_H5';
        cal.dx_over_dt_m_per_s = NaN;
    end
end

function [value, source] = find_h5_named_scalar(h5Path, groupInfo, names)

    value = [];
    source = '';

    [value, source] = scan_attrs_for_names(h5Path, groupInfo.Name, groupInfo.Attributes, names);
    if ~isempty(value)
        return;
    end

    for k = 1:numel(groupInfo.Datasets)
        ds = groupInfo.Datasets(k);
        dsPath = h5_join(groupInfo.Name, ds.Name);
        dsPathLower = lower(dsPath);

        [value, source] = scan_attrs_for_names(h5Path, dsPath, ds.Attributes, names);
        if ~isempty(value)
            return;
        end

        for j = 1:numel(names)
            if ~isempty(strfind(dsPathLower, lower(names{j}))) %#ok<STREMP>
                try
                    if prod(double(ds.Dataspace.Size)) <= 16
                        raw = h5read(h5Path, dsPath);
                        v = scalar_numeric(raw);
                        if ~isempty(v) && isfinite(v)
                            value = v;
                            source = ['dataset:' dsPath];
                            return;
                        end
                    end
                catch
                end
            end
        end
    end

    for g = 1:numel(groupInfo.Groups)
        [value, source] = find_h5_named_scalar(h5Path, groupInfo.Groups(g), names);
        if ~isempty(value)
            return;
        end
    end
end

function [value, source] = scan_attrs_for_names(h5Path, objPath, attrs, names)

    value = [];
    source = '';

    for i = 1:numel(attrs)
        attrName = attrs(i).Name;

        for j = 1:numel(names)
            if strcmpi(attrName, names{j})
                raw = h5readatt(h5Path, objPath, attrs(i).Name);
                v = scalar_numeric(raw);
                if ~isempty(v) && isfinite(v)
                    value = v;
                    source = ['attr:' objPath ':' attrName];
                    return;
                end
            end
        end
    end
end

function rows = run_projection_hypothesis_tests( ...
    Vx_raw, Vy_raw, Vx_unit, Vy_unit, x, y, Fx, Fy, metric)

    rows = struct( ...
        'CaseName', {}, ...
        'Candidate', {}, ...
        'MaxAbsError', {}, ...
        'RelativeRMSE', {}, ...
        'Correlation', {}, ...
        'Status', {} ...
    );

    speed2_raw = Vx_raw.^2 + Vy_raw.^2;
    vg2_metric_raw = metric .* speed2_raw;

    ux1 = Vx_unit;
    uy1 = Vy_unit;

    ux2 = x;
    uy2 = y;
    [ux2, uy2] = normalize_vec(ux2, uy2);

    ux3 = Fx;
    uy3 = Fy;
    [ux3, uy3] = normalize_vec(ux3, uy3);

    caseNames = { ...
        'CASE_1_self_aligned_velocity', ...
        'CASE_2_radial_direction', ...
        'CASE_3_gradient_direction' ...
    };

    uxList = {ux1, ux2, ux3};
    uyList = {uy1, uy2, uy3};

    for i = 1:numel(caseNames)

        caseName = caseNames{i};
        ux = uxList{i};
        uy = uyList{i};

        scalarCoef = Vx_raw .* ux + Vy_raw .* uy;
        shadowNorm2 = scalarCoef.^2 .* (ux.^2 + uy.^2);
        signedComponentSquared = scalarCoef.^2;
        metricShadow2 = metric .* shadowNorm2;

        rows(end+1) = make_projection_row(caseName, 'H1_scalar_coef_equals_speed2_raw', scalarCoef, speed2_raw); %#ok<AGROW>
        rows(end+1) = make_projection_row(caseName, 'H2_shadow_norm2_equals_speed2_raw', shadowNorm2, speed2_raw); %#ok<AGROW>
        rows(end+1) = make_projection_row(caseName, 'H3_signed_component_squared_equals_speed2_raw', signedComponentSquared, speed2_raw); %#ok<AGROW>
        rows(end+1) = make_projection_row(caseName, 'H4_metric_shadow2_equals_metric_speed2', metricShadow2, vg2_metric_raw); %#ok<AGROW>
    end
end

function row = make_projection_row(caseName, candidate, A, B)

    valid = isfinite(A) & isfinite(B);

    Av = A(valid);
    Bv = B(valid);

    if isempty(Av) || isempty(Bv)
        maxAbsError = NaN;
        relativeRMSE = NaN;
        corrVal = NaN;
        status = 'NO_VALID_DATA';
    else
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
            status = 'EXACT_PASS';
        elseif relativeRMSE < 0.05 && isfinite(corrVal) && corrVal > 0.95
            status = 'APPROX_PASS';
        else
            status = 'FAIL_OR_CONDITIONAL';
        end
    end

    row = struct();
    row.CaseName = caseName;
    row.Candidate = candidate;
    row.MaxAbsError = maxAbsError;
    row.RelativeRMSE = relativeRMSE;
    row.Correlation = corrVal;
    row.Status = status;
end

function report = test_vg2_against_c2( ...
    name, vg2_dimless, cal, c2, minSignificantRatio, minSupportFraction)

    vals = vg2_dimless(isfinite(vg2_dimless));

    report = struct();
    report.name = name;
    report.equation = 'vg2_physical = vg2_dimless * (dx_m/dt_s)^2';
    report.compare_to = 'c^2';
    report.calibration_ok = cal.ok;
    report.calibration_source = cal.source;

    if isempty(vals)
        report.status = 'NO_VALID_VALUES';
        report.conclusion = 'No valid vg2 values were computed.';
        return;
    end

    report.vg2_dimless_max = max(vals);
    report.vg2_dimless_p99 = percentile_local(vals, 99);
    report.vg2_dimless_p95 = percentile_local(vals, 95);
    report.vg2_dimless_median = median(vals);

    if ~cal.ok
        report.status = 'CALIBRATION_REQUIRED';
        report.dx_m = NaN;
        report.dt_s = NaN;
        report.conclusion = 'H5 field was computed, but physical vg2/c2 comparison requires dx_m and dt_s.';
        return;
    end

    dx_over_dt = cal.dx_m / cal.dt_s;

    vg2_physical = vals .* (dx_over_dt^2);
    ratio = vg2_physical ./ c2;

    report.dx_m = cal.dx_m;
    report.dt_s = cal.dt_s;
    report.dx_over_dt_m_per_s = dx_over_dt;

    report.ratio_max = max(ratio);
    report.ratio_p99 = percentile_local(ratio, 99);
    report.ratio_p95 = percentile_local(ratio, 95);
    report.ratio_median = median(ratio);

    report.support_fraction_above_c2 = mean(ratio > 1);
    report.support_fraction_significant = mean(ratio > minSignificantRatio);

    if report.ratio_p99 >= minSignificantRatio && ...
       report.support_fraction_significant >= minSupportFraction

        report.status = 'SIGNIFICANT_EXCEEDS_C2';
        report.conclusion = sprintf( ...
            'MATHEMATICAL RESULT: %s exceeds c^2 significantly. p99=%.6g, max=%.6g, support=%.6g.', ...
            name, report.ratio_p99, report.ratio_max, report.support_fraction_significant);

    elseif report.ratio_max > 1

        report.status = 'LOCAL_EXCEEDS_C2';
        report.conclusion = sprintf( ...
            'MATHEMATICAL RESULT: %s exceeds c^2 locally, but not significantly by threshold. p99=%.6g, max=%.6g.', ...
            name, report.ratio_p99, report.ratio_max);

    else

        report.status = 'DOES_NOT_EXCEED_C2';
        report.conclusion = sprintf( ...
            'MATHEMATICAL RESULT: %s does not exceed c^2. max=%.6g.', ...
            name, report.ratio_max);
    end
end

function th = compute_required_calibration_thresholds(vg2_dimless, c, minSignificantRatio)

    vals = vg2_dimless(isfinite(vg2_dimless));
    vals = vals(vals > 0);

    th = struct();

    if isempty(vals)
        th.status = 'NO_VALID_POSITIVE_VALUES';
        th.vg2_dimless_p99 = NaN;
        th.required_dx_over_dt_for_c2_p99 = Inf;
        th.required_dx_over_dt_for_significant_p99 = Inf;
        return;
    end

    q99 = percentile_local(vals, 99);
    q95 = percentile_local(vals, 95);
    qmax = max(vals);

    th.status = 'OK';
    th.vg2_dimless_p99 = q99;
    th.vg2_dimless_p95 = q95;
    th.vg2_dimless_max = qmax;

    th.required_dx_over_dt_for_c2_p99 = c / sqrt(max(q99, eps));
    th.required_dx_over_dt_for_significant_p99 = ...
        c * sqrt(minSignificantRatio / max(q99, eps));

    th.required_dx_over_dt_for_c2_max = c / sqrt(max(qmax, eps));
    th.required_dx_over_dt_for_significant_max = ...
        c * sqrt(minSignificantRatio / max(qmax, eps));
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

    if exist('imresize', 'file') == 2
        B = imresize(A, outSize, 'bilinear');
        return;
    end

    [h, w] = size(A);

    if h < 2 || w < 2
        B = zeros(outSize);
        return;
    end

    [x, y] = meshgrid(1:w, 1:h);
    [xq, yq] = meshgrid(linspace(1,w,outSize(2)), linspace(1,h,outSize(1)));

    B = interp2(x, y, A, xq, yq, 'linear', 0);
end

function B = gaussian_blur2(A, sigma)

    sigma = max(double(sigma), 0.01);

    if exist('imgaussfilt', 'file') == 2
        B = imgaussfilt(A, sigma);
        return;
    end

    radius = max(1, ceil(3*sigma));
    x = -radius:radius;

    g = exp(-(x.^2) ./ (2*sigma^2));
    g = g ./ sum(g);

    B = conv2(conv2(A, g, 'same'), g.', 'same');
end

function Y = normalize01(X)

    X = double(X);
    finiteVals = X(isfinite(X));

    if isempty(finiteVals)
        Y = zeros(size(X));
        return;
    end

    mn = min(finiteVals);
    mx = max(finiteVals);

    if ~isfinite(mn) || ~isfinite(mx) || abs(mx-mn) < eps
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

    if strcmp(parent, '/')
        p = ['/' child];
    else
        p = [parent '/' child];
    end
end

function y = scalar_numeric(x)

    y = [];

    if isnumeric(x)
        y = double(x(1));
        return;
    end

    if ischar(x)
        y = str2double(x);
        return;
    end

    try
        y = str2double(char(x));
    catch
        y = [];
    end
end

function v = value_or_nan(x)
    if isempty(x)
        v = NaN;
    else
        v = x;
    end
end

function write_json(path, data)

    try
        txt = jsonencode(data, 'PrettyPrint', true);
    catch
        txt = jsonencode(data);
    end

    fid = fopen(path, 'w');
    fprintf(fid, '%s', txt);
    fclose(fid);
end

function write_projection_csv(path, rows)

    fid = fopen(path, 'w');
    fprintf(fid, 'CaseName,Candidate,MaxAbsError,RelativeRMSE,Correlation,Status\n');

    for k = 1:numel(rows)
        fprintf(fid, '"%s","%s",%.17g,%.17g,%.17g,"%s"\n', ...
            rows(k).CaseName, ...
            rows(k).Candidate, ...
            rows(k).MaxAbsError, ...
            rows(k).RelativeRMSE, ...
            rows(k).Correlation, ...
            rows(k).Status);
    end

    fclose(fid);
end

function write_dataset_selection_csv(path, selected)

    fid = fopen(path, 'w');
    fprintf(fid, 'rank,path,size,numel,class,score\n');

    for k = 1:numel(selected)
        fprintf(fid, '%d,"%s","%s",%.0f,"%s",%.6f\n', ...
            selected(k).rank, ...
            selected(k).path, ...
            size_to_string(selected(k).size), ...
            selected(k).numel, ...
            selected(k).class, ...
            selected(k).score);
    end

    fclose(fid);
end

function h = sha256_file_safe(path)

    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        fis = java.io.FileInputStream(java.io.File(path));
        buffer = zeros(1, 8192, 'uint8');

        while true
            n = fis.read(buffer, 0, numel(buffer));
            if n == -1
                break;
            end
            md.update(buffer(1:n));
        end

        fis.close();

        hash = typecast(md.digest(), 'uint8');
        h = lower(reshape(dec2hex(hash).', 1, []));

    catch
        h = 'SHA256_UNAVAILABLE';
    end
end

function m = nanmean_local(X, dim)

    if nargin < 2
        x = X(:);
        x = x(isfinite(x));
        if isempty(x)
            m = NaN;
        else
            m = mean(x);
        end
        return;
    end

    mask = isfinite(X);
    X2 = X;
    X2(~mask) = 0;

    count = sum(mask, dim);
    total = sum(X2, dim);

    m = total ./ max(count, 1);
    m(count == 0) = NaN;
end

function q = percentile_local(x, p)

    x = x(:);
    x = x(isfinite(x));

    if isempty(x)
        q = NaN;
        return;
    end

    x = sort(x);
    n = numel(x);

    if n == 1
        q = x(1);
        return;
    end

    pos = 1 + (p/100) * (n - 1);
    lo = floor(pos);
    hi = ceil(pos);

    if lo == hi
        q = x(lo);
    else
        q = x(lo) + (pos - lo) * (x(hi) - x(lo));
    end
end

function s = size_to_string(sz)

    if isempty(sz)
        s = '[]';
        return;
    end

    parts = cell(1, numel(sz));

    for i = 1:numel(sz)
        parts{i} = num2str(sz(i));
    end

    s = ['[' strjoin(parts, 'x') ']'];
end