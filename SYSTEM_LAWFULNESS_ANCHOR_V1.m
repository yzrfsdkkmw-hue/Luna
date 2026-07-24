%% SYSTEM_LAWFULNESS_ANCHOR_V1
% Purpose:
% Build a measured "system lawfulness document" before any project action.
%
% Core rule:
% We do not force meaning.
% We define variables, test equations, measure errors, and only then decide.
%
% Main hypothesis:
% "Shadow of a vector in a vector field = geodesic speed squared"
%
% Status:
% HYPOTHESIS_TO_TEST, not a proven claim.

clear; clc; close all;

%% =========================
% 0. Output folder
% =========================

RUN_ID = ['lawfulness_anchor_v1_' datestr(now,'yyyymmdd_HHMMSS')];
OUTDIR = fullfile(pwd, RUN_ID);

if ~exist(OUTDIR, 'dir')
    mkdir(OUTDIR);
end

fprintf('\nSYSTEM LAWfulness anchor run started.\n');
fprintf('Output folder:\n%s\n\n', OUTDIR);

%% =========================
% 1. Chronological law chain
% =========================

Step = (1:13)';

Stage = {
    'Algebra: combining like terms'
    'Algebra: distributive law'
    'Algebra: coefficient extraction'
    'Vector: dot product'
    'Vector: projection coefficient'
    'Vector: projected vector'
    'Vector: residual / leftover'
    'Vector field'
    'Path / curve'
    'Velocity / tangent'
    'Metric speed squared'
    'Hypothesis candidate'
    'Action rule'
};

Formula = {
    '3x + 4x + 7 + 2x - 5 = 9x + 2'
    '5(x + 2) + 3x - 4 = 8x + 6'
    'a*x + b*x = (a+b)*x'
    'dot(v,u) = sum(v_i*u_i)'
    'coef = dot(v,u)/dot(u,u)'
    'proj_u(v) = coef*u'
    'residual = v - proj_u(v), and dot(residual,u)=0'
    'F(x,y) = [F1(x,y), F2(x,y)]'
    'gamma(t) = [x(t), y(t)]'
    'u(t) = gamma_prime(t)'
    'speed2(t) = dot(u(t),u(t)) under Euclidean metric'
    'shadow_norm2(F,u) ?= speed2'
    'Only continue if variables, dimensions, error, and counterexample are checked'
};

Meaning = {
    'Same-type objects may be collected'
    'A rule expands structure without changing value'
    'Coefficient is the scalar weight of a direction'
    'Dot product measures directional agreement'
    'Coefficient measures how much v lives in direction u'
    'Projection is the shadow of v on u'
    'Residual checks whether projection was mathematically clean'
    'A vector is attached to every point'
    'A path selects points inside the field'
    'Velocity gives the local movement direction'
    'Speed squared is the metric length of movement'
    'The proposed sentence becomes measurable'
    'No action without MATLAB anchor'
};

Status = {
    'ANCHOR'
    'ANCHOR'
    'ANCHOR'
    'ANCHOR'
    'ANCHOR'
    'ANCHOR'
    'CHECK'
    'MODEL_OBJECT'
    'MODEL_OBJECT'
    'MODEL_OBJECT'
    'MEASURE'
    'HYPOTHESIS_TO_TEST'
    'GATEKEEPER'
};

law_chain = table(Step, Stage, Formula, Meaning, Status);

law_csv = fullfile(OUTDIR, '3333_law_chain.csv');
writetable(law_chain, law_csv);

%% =========================
% 2. Define test domain
% =========================

N = 600;
t = linspace(-1, 3, N)';

%% =========================
% 3. Case A: Euclidean geodesic line
% gamma(t) = [t, 0.5t]
% F(gamma(t)) = gamma'(t)
% Here shadow_norm2 should equal speed2 exactly.
% =========================

gamma_line = [t, 0.5*t];
u_line     = [ones(N,1), 0.5*ones(N,1)];
F_line     = u_line;

caseA = runProjectionCase( ...
    'CASE_A_exact_euclidean_geodesic_line', ...
    'Euclidean geodesic line', ...
    t, gamma_line, u_line, F_line);

%% =========================
% 4. Case B: Curved diagnostic path
% gamma(t) = [t, sin(t)]
% F(gamma(t)) = gamma'(t)
%
% This tests projection-speed relation,
% but it is NOT a Euclidean geodesic line.
% =========================

gamma_curve = [t, sin(t)];
u_curve     = [ones(N,1), cos(t)];
F_curve     = u_curve;

caseB = runProjectionCase( ...
    'CASE_B_exact_curved_path_not_geodesic', ...
    'Curved diagnostic path', ...
    t, gamma_curve, u_curve, F_curve);

%% =========================
% 5. Case C: Perturbed field
% Same curved path,
% but the vector field is not equal to the path velocity.
% This is the counterexample / failure test.
% =========================

F_perturbed = [ ...
    ones(N,1) + 0.20*sin(2*t), ...
    cos(t)   - 0.25*cos(3*t) ...
];

caseC = runProjectionCase( ...
    'CASE_C_perturbed_field_counterexample', ...
    'Curved path with perturbed field', ...
    t, gamma_curve, u_curve, F_perturbed);

%% =========================
% 6. Collect metrics
% =========================

results = [
    caseA.metrics
    caseB.metrics
    caseC.metrics
];

results_csv = fullfile(OUTDIR, '4444_projection_tests.csv');
writetable(results, results_csv);

%% =========================
% 7. Plot cases
% =========================

plotProjectionCase(caseA, fullfile(OUTDIR, '5555_case_A_geodesic_line_projection.png'));
plotProjectionCase(caseB, fullfile(OUTDIR, '5556_case_B_curved_path_projection.png'));
plotProjectionCase(caseC, fullfile(OUTDIR, '5557_case_C_perturbed_counterexample.png'));

plotMetricSummary(results, fullfile(OUTDIR, '5558_metric_summary.png'));

%% =========================
% 8. Build JSON summary
% =========================

summary = struct();

summary.run_id = RUN_ID;
summary.status = 'ANCHOR_CREATED';
summary.main_sentence = 'Shadow of vector in vector field = geodesic speed squared';
summary.main_sentence_status = 'HYPOTHESIS_TO_TEST';

summary.definitions.projection_coefficient = 'coef = dot(v,u)/dot(u,u)';
summary.definitions.projected_vector = 'proj_u(v) = coef*u';
summary.definitions.shadow_norm2 = 'dot(proj_u(v), proj_u(v))';
summary.definitions.speed2 = 'dot(gamma_prime(t), gamma_prime(t)) under Euclidean metric';

summary.important_distinction = ...
    'Scalar coefficient is generally NOT equal to speed squared. Squared projection length can equal speed squared only under defined compatibility conditions.';

summary.lawful_gate = struct();
summary.lawful_gate.no_hidden_claims = true;
summary.lawful_gate.no_external_data_used = true;
summary.lawful_gate.counterexample_required = true;
summary.lawful_gate.geodesic_not_assumed = true;
summary.lawful_gate.continue_only_after_numeric_anchor = true;

summary.files.law_chain_csv = '3333_law_chain.csv';
summary.files.projection_tests_csv = '4444_projection_tests.csv';
summary.files.document_md = '1111_system_lawfulness_document.md';
summary.files.metrics_json = '2222_hypothesis_metrics.json';
summary.files.manifest_sha256 = '6666_manifest_sha256.txt';

summary.metrics_table_note = ...
    'See 4444_projection_tests.csv for exact error, relative RMSE, correlation, and status.';

json_path = fullfile(OUTDIR, '2222_hypothesis_metrics.json');
writeTextFile(json_path, jsonencode(summary));

%% =========================
% 9. Build Markdown lawfulness document
% =========================

doc_path = fullfile(OUTDIR, '1111_system_lawfulness_document.md');
fid = fopen(doc_path, 'w', 'n', 'UTF-8');

fprintf(fid, '# System Lawfulness Anchor V1\n\n');

fprintf(fid, '## Status\n\n');
fprintf(fid, '`HYPOTHESIS_TO_TEST` — not a conclusion.\n\n');

fprintf(fid, '## Door-knock protocol\n\n');
fprintf(fid, 'We do not break, force, or invent structure.\n\n');
fprintf(fid, 'We define variables, test lawful equations, measure errors, and only then continue.\n\n');

fprintf(fid, '## Chronological mathematical chain\n\n');

for i = 1:height(law_chain)
    fprintf(fid, '%02d. **%s**  \n', law_chain.Step(i), law_chain.Stage{i});
    fprintf(fid, '    `%s`  \n', law_chain.Formula{i});
    fprintf(fid, '    Meaning: %s  \n', law_chain.Meaning{i});
    fprintf(fid, '    Status: `%s`\n\n', law_chain.Status{i});
end

fprintf(fid, '## Projection anchor\n\n');
fprintf(fid, 'Given vector `v` and target direction `u`:\n\n');
fprintf(fid, '```text\n');
fprintf(fid, 'coef = dot(v,u) / dot(u,u)\n');
fprintf(fid, 'proj_u(v) = coef * u\n');
fprintf(fid, 'residual = v - proj_u(v)\n');
fprintf(fid, 'dot(residual,u) should be approximately 0\n');
fprintf(fid, '```\n\n');

fprintf(fid, '## Proposed sentence\n\n');
fprintf(fid, '> Shadow of vector in vector field = geodesic speed squared\n\n');

fprintf(fid, 'This sentence is split into measurable candidates:\n\n');
fprintf(fid, '1. `coef == speed2`\n');
fprintf(fid, '2. `norm(proj_u(F))^2 == speed2`\n');
fprintf(fid, '3. `signed_component(F along unit tangent)^2 == speed2`\n\n');

fprintf(fid, '## Interpretation rule\n\n');
fprintf(fid, '- If only candidate 1 passes: unusual; inspect units.\n');
fprintf(fid, '- If candidate 2 or 3 passes: projection-speed compatibility exists.\n');
fprintf(fid, '- If curvature/geodesic check fails: do not call it geodesic yet.\n');
fprintf(fid, '- If counterexample fails: the rule is conditional, not universal.\n\n');

fprintf(fid, '## Result files\n\n');
fprintf(fid, '- `3333_law_chain.csv`\n');
fprintf(fid, '- `4444_projection_tests.csv`\n');
fprintf(fid, '- `2222_hypothesis_metrics.json`\n');
fprintf(fid, '- `5555_case_A_geodesic_line_projection.png`\n');
fprintf(fid, '- `5556_case_B_curved_path_projection.png`\n');
fprintf(fid, '- `5557_case_C_perturbed_counterexample.png`\n');
fprintf(fid, '- `5558_metric_summary.png`\n');
fprintf(fid, '- `6666_manifest_sha256.txt`\n\n');

fprintf(fid, '## Final gate\n\n');
fprintf(fid, 'Continue only if the next action has:\n\n');
fprintf(fid, '1. Defined variables\n');
fprintf(fid, '2. Defined formula\n');
fprintf(fid, '3. Numeric check\n');
fprintf(fid, '4. Counterexample\n');
fprintf(fid, '5. Reproducible output\n\n');

fclose(fid);

%% =========================
% 10. Manifest hash
% =========================

manifest_path = fullfile(OUTDIR, '6666_manifest_sha256.txt');

files_to_hash = {
    '1111_system_lawfulness_document.md'
    '2222_hypothesis_metrics.json'
    '3333_law_chain.csv'
    '4444_projection_tests.csv'
    '5555_case_A_geodesic_line_projection.png'
    '5556_case_B_curved_path_projection.png'
    '5557_case_C_perturbed_counterexample.png'
    '5558_metric_summary.png'
};

fid = fopen(manifest_path, 'w', 'n', 'UTF-8');
fprintf(fid, 'SYSTEM_LAWFULNESS_ANCHOR_V1\n');
fprintf(fid, 'RUN_ID: %s\n\n', RUN_ID);

for i = 1:numel(files_to_hash)
    fp = fullfile(OUTDIR, files_to_hash{i});
    h = sha256File(fp);
    fprintf(fid, '%s  %s\n', h, files_to_hash{i});
end

fclose(fid);

%% =========================
% 11. Console summary
% =========================

fprintf('\nDONE.\n');
fprintf('System lawfulness document created.\n\n');

fprintf('Main files:\n');
fprintf('1111_system_lawfulness_document.md\n');
fprintf('2222_hypothesis_metrics.json\n');
fprintf('3333_law_chain.csv\n');
fprintf('4444_projection_tests.csv\n');
fprintf('6666_manifest_sha256.txt\n\n');

fprintf('Folder:\n%s\n\n', OUTDIR);

disp('Quick result table:');
disp(results(:, {'CaseName','Candidate','MaxAbsError','RelativeRMSE','Correlation','Status'}));

%% ============================================================
% Local functions
% ============================================================

function S = runProjectionCase(caseName, pathType, t, gamma, u, F)

    dotFu = sum(F .* u, 2);
    dotuu = sum(u .* u, 2);

    coef = dotFu ./ dotuu;
    P = coef .* u;
    R = F - P;

    speed2 = dotuu;

    speed = sqrt(speed2);
    Tunit = u ./ speed;

    signed_component = sum(F .* Tunit, 2);

    H1 = coef;
    H2 = sum(P .* P, 2);
    H3 = signed_component .^ 2;

    residual_orthogonality = abs(sum(R .* u, 2));

    curvature_abs = estimateCurvature(t, gamma, u);
    curvature_max = max(curvature_abs);

    candidates = {
        'H1_scalar_coef_equals_speed2'
        'H2_shadow_norm2_equals_speed2'
        'H3_signed_component_squared_equals_speed2'
    };

    predicted = {H1, H2, H3};

    CaseName = cell(3,1);
    PathType = cell(3,1);
    Candidate = cell(3,1);
    MaxAbsError = zeros(3,1);
    RelativeRMSE = zeros(3,1);
    Correlation = zeros(3,1);
    ResidualOrthogonalityMax = zeros(3,1);
    CurvatureMax = zeros(3,1);
    Status = cell(3,1);

    for k = 1:3
        y = predicted{k};
        err = y - speed2;

        max_abs_err = max(abs(err));
        rmse = sqrt(mean(err.^2));
        denom = max(1e-12, sqrt(mean(speed2.^2)));
        rel_rmse = rmse / denom;
        corr_val = safeCorr(y, speed2);

        CaseName{k} = caseName;
        PathType{k} = pathType;
        Candidate{k} = candidates{k};

        MaxAbsError(k) = max_abs_err;
        RelativeRMSE(k) = rel_rmse;
        Correlation(k) = corr_val;
        ResidualOrthogonalityMax(k) = max(residual_orthogonality);
        CurvatureMax(k) = curvature_max;

        if max_abs_err < 1e-9
            Status{k} = 'EXACT_PASS';
        elseif rel_rmse < 0.05
            Status{k} = 'APPROX_PASS';
        elseif ~isnan(corr_val) && corr_val > 0.98 && rel_rmse < 0.15
            Status{k} = 'SHAPE_SIMILAR_ONLY';
        else
            Status{k} = 'FAIL_OR_CONDITIONAL';
        end
    end

    metrics = table( ...
        CaseName, PathType, Candidate, ...
        MaxAbsError, RelativeRMSE, Correlation, ...
        ResidualOrthogonalityMax, CurvatureMax, Status);

    S = struct();
    S.caseName = caseName;
    S.pathType = pathType;
    S.t = t;
    S.gamma = gamma;
    S.u = u;
    S.F = F;
    S.P = P;
    S.R = R;
    S.speed2 = speed2;
    S.coef = coef;
    S.signed_component = signed_component;
    S.curvature_abs = curvature_abs;
    S.metrics = metrics;
end

function curvature_abs = estimateCurvature(t, gamma, u)

    ux = u(:,1);
    uy = u(:,2);

    ax = gradient(ux, t);
    ay = gradient(uy, t);

    speed = sqrt(sum(u .* u, 2));

    numerator = abs(ux .* ay - uy .* ax);
    denominator = max(speed.^3, 1e-12);

    curvature_abs = numerator ./ denominator;

    % If numerical gradient creates tiny noise for straight lines:
    curvature_abs(abs(curvature_abs) < 1e-12) = 0;
end

function c = safeCorr(a, b)

    a = a(:);
    b = b(:);

    if std(a) < 1e-12 || std(b) < 1e-12
        c = NaN;
        return;
    end

    C = corrcoef(a, b);
    c = C(1,2);
end

function plotProjectionCase(S, outfile)

    fig = figure('Color','w', 'Position', [100 100 1100 750]);

    idx = round(linspace(1, numel(S.t), 30));

    plot(S.gamma(:,1), S.gamma(:,2), 'LineWidth', 2);
    hold on;

    quiver( ...
        S.gamma(idx,1), S.gamma(idx,2), ...
        S.F(idx,1), S.F(idx,2), ...
        0.35, 'LineWidth', 1);

    quiver( ...
        S.gamma(idx,1), S.gamma(idx,2), ...
        S.P(idx,1), S.P(idx,2), ...
        0.35, 'LineWidth', 1.5);

    grid on;
    axis equal;

    xlabel('x');
    ylabel('y');

    title(strrep(S.caseName, '_', ' '), 'Interpreter','none');

    legend( ...
        'path gamma(t)', ...
        'field vector F at path', ...
        'projection shadow proj_u(F)', ...
        'Location', 'best');

    text( ...
        min(S.gamma(:,1)), max(S.gamma(:,2)), ...
        ['Path type: ' S.pathType], ...
        'Interpreter','none', ...
        'FontSize', 10, ...
        'VerticalAlignment','top');

    saveFigureSafe(fig, outfile);
    close(fig);
end

function plotMetricSummary(results, outfile)

    fig = figure('Color','w', 'Position', [100 100 1200 650]);

    labels = strcat(results.CaseName, " | ", results.Candidate);
    y = results.RelativeRMSE;

    bar(y);
    grid on;

    ylabel('Relative RMSE against speed^2');
    title('Hypothesis metric summary');

    xticks(1:numel(y));
    xticklabels(labels);
    xtickangle(35);

    saveFigureSafe(fig, outfile);
    close(fig);
end

function saveFigureSafe(fig, outfile)

    try
        exportgraphics(fig, outfile, 'Resolution', 180);
    catch
        saveas(fig, outfile);
    end
end

function writeTextFile(path, txt)

    fid = fopen(path, 'w', 'n', 'UTF-8');
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function h = sha256File(filepath)

    fid = fopen(filepath, 'r');
    data = fread(fid, Inf, '*uint8')';
    fclose(fid);

    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(data);

    digest = typecast(md.digest(), 'uint8');
    h = lower(reshape(dec2hex(digest)', 1, []));
end