function report = YEHOSHUA_knowledge_quantization_structural_visual_learning_v1(mode)
% YEHOSHUA_KNOWLEDGE_QUANTIZATION_STRUCTURAL_VISUAL_LEARNING_V1
%
% A deterministic MATLAB visual-learning package for the workflow principle
% of knowledge quantization. Human notation is rasterized as geometry and is
% embedded into masks, carriers, projection maps, and temporal motion. It is
% never added as a caption or post-hoc text overlay.
%
% Modes:
%   "preflight"  - validate all immutable inputs; perform no writes.
%   "execute"    - build the complete organized package once.
%
% Scope note:
%   The canonical H5 supplies the numerical visual field. The symbols and
%   workflow are derived educational encodings. Their appearance is not a
%   claim that semantic symbols or knowledge were found inside the H5 file.

if nargin < 1
    mode = "execute";
end
mode = lower(string(mode));

cfg = build_config();
report = run_preflight(cfg);

if mode == "preflight"
    disp(jsonencode(report, PrettyPrint=true));
    return;
elseif mode ~= "execute"
    error('Mode must be "preflight" or "execute".');
end

if isfolder(cfg.outputRoot) || isfolder(cfg.stagingRoot)
    error('Output or staging folder already exists. Refusing to overwrite: %s', cfg.outputRoot);
end

fprintf('Preflight passed. Building knowledge-quantization visual package.\n');
mkdir(cfg.stagingRoot);

dirs = create_output_tree(cfg.stagingRoot);
write_text(fullfile(dirs.integrity, 'canonical_sha256.txt'), ...
    sprintf('%s  %s\n', cfg.expectedHash, cfg.canonicalH5));

[CH, layoutNote] = read_canonical_channels(cfg);
[stageFields, aux] = derive_workflow_fields(CH, cfg.imageSize);
[styleBank, referenceIndex] = read_reference_style_bank(cfg.referenceImages, cfg.imageSize);

stages = workflow_stages();
symbols = symbol_dictionary();
numStages = numel(stages);
numFrames = cfg.numFrames;
trainSize = cfg.trainingSize;

structuralTensor = zeros(trainSize, trainSize, 3, numStages, 'uint8');
maskTensor = zeros(trainSize, trainSize, numStages, 'single');
projectionTensor = zeros(trainSize, trainSize, numStages, 'single');
motionTensor = zeros(trainSize, trainSize, numStages, 'single');
deltaTensor = zeros(trainSize, trainSize, numStages, 'single');
temporalTensor = zeros(trainSize, trainSize, 3, numFrames, numStages, 'uint8');
stageCodebook = zeros(numStages, numel(symbols), 'single');
metricTemplate = struct( ...
    'stage_index', 0, ...
    'stage_slug', '', ...
    'human_notation', '', ...
    'mask_density', 0, ...
    'relation_density', 0, ...
    'carrier_energy', 0, ...
    'motion_energy', 0, ...
    'temporal_delta', 0, ...
    'structure_preservation', 0, ...
    'projected_gain', 0);
stageMetrics = repmat(metricTemplate, numStages, 1);
layerRows = cell(0, 9);
structuralImages = cell(numStages, 1);

for s = 1:numStages
    stage = stages(s);
    fprintf('Stage %02d/%02d: %s\n', s, numStages, stage.slug);

    stageDir = fullfile(dirs.stages, sprintf('%02d_%s', s, stage.slug));
    mkdir(stageDir);

    base = stageFields{s};
    style = styleBank(:,:,:,mod(s-1, size(styleBank,4))+1);
    sourceRGB = render_source_rgb(base, aux, style, s);

    [mainMask, relationMask, carrier, placements] = ...
        build_structural_symbol_field(base, stage.tokens, cfg);
    [visibleRGB, balancedRGB, structuralRGB] = ...
        embed_three_levels(sourceRGB, base, mainMask, relationMask, carrier);
    [frames, projectionMap, motionEnergy, temporalDelta] = ...
        temporal_projection(structuralRGB, base, mainMask, relationMask, carrier, cfg);

    maskRGB = render_mask(mainMask, relationMask, carrier);
    projectionRGB = render_scalar(projectionMap, "projection");
    motionRGB = render_scalar(motionEnergy, "motion");
    deltaRGB = render_scalar(temporalDelta, "delta");
    frameSheet = frame_sheet(frames);

    fileMap = struct();
    fileMap.base = fullfile(stageDir, '00_base.png');
    fileMap.visible = fullfile(stageDir, '01_visible.png');
    fileMap.balanced = fullfile(stageDir, '02_balanced.png');
    fileMap.structural = fullfile(stageDir, '03_structural.png');
    fileMap.mask = fullfile(stageDir, '04_mask.png');
    fileMap.projection = fullfile(stageDir, '05_projection_map.png');
    fileMap.motion = fullfile(stageDir, '06_motion_energy.png');
    fileMap.delta = fullfile(stageDir, '07_temporal_delta.png');
    fileMap.frames = fullfile(stageDir, '08_framesheet.png');
    fileMap.patch = fullfile(stageDir, '09_temporal_patch.mat');

    imwrite(sourceRGB, fileMap.base);
    imwrite(visibleRGB, fileMap.visible);
    imwrite(balancedRGB, fileMap.balanced);
    imwrite(structuralRGB, fileMap.structural);
    imwrite(maskRGB, fileMap.mask);
    imwrite(projectionRGB, fileMap.projection);
    imwrite(motionRGB, fileMap.motion);
    imwrite(deltaRGB, fileMap.delta);
    imwrite(frameSheet, fileMap.frames);

    stagePatch = struct( ...
        'stageIndex', s, ...
        'stageSlug', stage.slug, ...
        'humanNotation', stage.notation, ...
        'tokens', {stage.tokens}, ...
        'placementsXY', single(placements), ...
        'mainMask', single(mainMask), ...
        'relationMask', single(relationMask), ...
        'carrier', single(carrier), ...
        'projectionMap', single(projectionMap), ...
        'motionEnergy', single(motionEnergy), ...
        'temporalDelta', single(temporalDelta), ...
        'framesRGB', frames, ...
        'scopeNote', cfg.scopeNote);
    save(fileMap.patch, '-struct', 'stagePatch', '-v7.3');

    structuralTensor(:,:,:,s) = im2uint8(imresize(structuralRGB, [trainSize trainSize]));
    maskTensor(:,:,s) = single(imresize(mainMask, [trainSize trainSize]));
    projectionTensor(:,:,s) = single(imresize(projectionMap, [trainSize trainSize]));
    motionTensor(:,:,s) = single(imresize(motionEnergy, [trainSize trainSize]));
    deltaTensor(:,:,s) = single(imresize(temporalDelta, [trainSize trainSize]));
    for t = 1:numFrames
        temporalTensor(:,:,:,t,s) = im2uint8(imresize(frames(:,:,:,t), [trainSize trainSize]));
    end

    for k = 1:numel(stage.tokens)
        idx = find(strcmp({symbols.token}, stage.tokens{k}), 1);
        if ~isempty(idx)
            stageCodebook(s,idx) = stageCodebook(s,idx) + 1;
        end
    end

    m = struct();
    m.stage_index = s;
    m.stage_slug = stage.slug;
    m.human_notation = stage.notation;
    m.mask_density = mean(mainMask(:) > 0.15);
    m.relation_density = mean(relationMask(:) > 0.12);
    m.carrier_energy = mean(carrier(:).^2);
    m.motion_energy = mean(motionEnergy(:));
    m.temporal_delta = mean(temporalDelta(:));
    m.structure_preservation = corr_safe(base, rgb_luma(structuralRGB));
    m.projected_gain = mean(projectionMap(:)) / max(mean(mainMask(:)), eps);
    stageMetrics(s) = m;
    structuralImages{s} = structuralRGB;

    names = {'base','visible','balanced','structural','mask','projection','motion','delta','frames','patch'};
    roles = {'numeric visual source','high visibility embedding','balanced embedding', ...
        'base-preserving structural embedding','human-symbol structural mask', ...
        'temporal projection map','motion energy','temporal delta', ...
        'eight-frame temporal sheet','numeric temporal training patch'};
    for q = 1:numel(names)
        p = fileMap.(names{q});
        layerRows(end+1,:) = {s, stage.slug, stage.notation, names{q}, roles{q}, ...
            relative_path(p, cfg.stagingRoot), file_sha256(p), file_size(p), cfg.scopeNote}; %#ok<AGROW>
    end
end

fprintf('Writing symbol dictionary, tensors, manifests, and contact sheets.\n');
symbolRows = write_symbol_dictionary(symbols, dirs.symbols, cfg);
write_training_artifacts(dirs.tensors, CH, structuralTensor, maskTensor, ...
    projectionTensor, motionTensor, deltaTensor, temporalTensor, stageCodebook, stages, cfg);

stageAdjacency = diag(ones(numStages-1,1),1);
stageAdjacency = stageAdjacency + stageAdjacency.';
save(fullfile(dirs.tensors, 'knowledge_quantization_training_bundle_v1.mat'), ...
    'structuralTensor', 'maskTensor', 'projectionTensor', 'motionTensor', ...
    'deltaTensor', 'temporalTensor', 'stageCodebook', 'stageAdjacency', ...
    'stageMetrics', 'layoutNote', '-v7.3');

write_stage_manifest(stages, stageMetrics, fullfile(dirs.manifests, 'WorkflowStages.csv'));
write_cell_csv(layerRows, {'stage_index','stage_slug','human_notation','layer', ...
    'role','relative_path','sha256','bytes','scope_note'}, ...
    fullfile(dirs.manifests, 'VisualLayerIndex.csv'));
write_cell_csv(referenceIndex, {'reference_index','name','absolute_path','sha256', ...
    'height','width','channels','role'}, ...
    fullfile(dirs.manifests, 'ReferenceStyleIndex.csv'));
write_cell_csv(symbolRows, {'symbol_index','token','human_symbol','visual_role', ...
    'construction','mask_file','sha256'}, ...
    fullfile(dirs.manifests, 'HumanSymbolPatternDictionary.csv'));

stageSheet = image_cell_sheet(structuralImages, 4, 4, [0.015 0.02 0.04]);
imwrite(stageSheet, fullfile(dirs.contacts, 'KnowledgeQuantization_14Stage_Structural_ContactSheet.png'));
write_plan_document(fullfile(dirs.manifests, 'CODE_EXECUTION_PLAN.md'), cfg, stages, layoutNote);

validation = validate_package(cfg.stagingRoot, numStages, numFrames, ...
    structuralTensor, maskTensor, projectionTensor, temporalTensor, stageMetrics);
write_json(fullfile(dirs.integrity, 'OutputValidation.json'), validation);

summary = struct();
summary.package_name = cfg.packageName;
summary.created_utc = char(datetime('now', 'TimeZone','UTC', 'Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
summary.canonical_h5 = cfg.canonicalH5;
summary.canonical_sha256 = cfg.expectedHash;
summary.canonical_dataset = cfg.datasetPath;
summary.canonical_layout = layoutNote;
summary.reference_images = {cfg.referenceImages{:}};
summary.stage_count = numStages;
summary.symbol_count = numel(symbols);
summary.temporal_frames_per_stage = numFrames;
summary.embedding_levels = {'visible','balanced','structural'};
summary.training_tensor_size = size(structuralTensor);
summary.temporal_tensor_size = size(temporalTensor);
summary.validation = validation;
summary.scope_note = cfg.scopeNote;
write_json(fullfile(dirs.manifests, 'RunSummary.json'), summary);

movefile(cfg.stagingRoot, cfg.outputRoot);

report.output_root = cfg.outputRoot;
report.stage_count = numStages;
report.symbol_count = numel(symbols);
report.validation = validation;
report.status = 'complete';
report.write_performed = true;
report.output_exists = true;
report.staging_exists = false;
fprintf('COMPLETE: %s\n', cfg.outputRoot);

end

%% Configuration and preflight
function cfg = build_config()

base = '/Users/yehoshua/Desktop/YEHOSHUA_projection_temporal_formula_from_SSOT_v15';
cfg.packageName = 'YEHOSHUA_knowledge_quantization_structural_visual_learning_v1';
cfg.outputRoot = fullfile(base, cfg.packageName);
cfg.stagingRoot = [cfg.outputRoot '_BUILDING'];
cfg.canonicalH5 = '/Users/yehoshua/MATLAB-Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
cfg.expectedHash = '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.datasetPath = '/n_5_composite_field_1000x1000/data';
refRoot = fullfile(base, 'YEHOSHUA_wave_function_string_foundations_tensor_training_bundle_v1', ...
    'images', 'string_foundations');
cfg.referenceImages = { ...
    fullfile(refRoot, 'String.png'), ...
    fullfile(refRoot, 'Brane.png'), ...
    fullfile(refRoot, 'CompactDimension.png'), ...
    fullfile(refRoot, 'OpenString.png'), ...
    fullfile(refRoot, 'ModeSpectrum.png'), ...
    fullfile(refRoot, 'Worldsheet.png')};
cfg.v15Script = '/Users/yehoshua/MATLAB-Drive/modelTRAINING/YEHOSHUA_formula_embedding_from_SSOT_v13.m';
cfg.v16Script = '/Users/yehoshua/MATLAB-Drive/modelTRAINING/YEHOSHUA_calc1_projection_temporal_from_SSOT_v16_2_candidate.m';
cfg.imageSize = 512;
cfg.trainingSize = 128;
cfg.numFrames = 8;
cfg.scopeNote = ['Derived visual-learning workflow. The canonical H5 supplies the numeric field; ' ...
    'human notation is intentionally constructed as structural geometry and is not claimed to exist semantically in the source H5.'];

end

function report = run_preflight(cfg)

assert(isfile(cfg.canonicalH5), 'Canonical H5 is missing.');
actualHash = file_sha256(cfg.canonicalH5);
assert(strcmpi(actualHash, cfg.expectedHash), 'Canonical H5 SHA-256 mismatch.');

info = h5info(cfg.canonicalH5, cfg.datasetPath);
assert(prod(double(info.Dataspace.Size)) == 5000000, 'Canonical dataset must contain 5,000,000 values.');

assert(isfile(cfg.v15Script), 'v15 structural reference script is missing.');
assert(isfile(cfg.v16Script), 'v16 temporal projection reference script is missing.');

reference = repmat(struct(), numel(cfg.referenceImages), 1);
for k = 1:numel(cfg.referenceImages)
    p = cfg.referenceImages{k};
    assert(isfile(p), 'Reference image is missing: %s', p);
    im = imfinfo(p);
    assert(im.Width == 512 && im.Height == 512, 'Reference image must be 512x512: %s', p);
    reference(k).path = p;
    reference(k).sha256 = file_sha256(p);
    reference(k).width = im.Width;
    reference(k).height = im.Height;
end

report = struct();
report.status = 'preflight_passed';
report.write_performed = false;
report.canonical_h5 = cfg.canonicalH5;
report.canonical_sha256 = actualHash;
report.dataset = cfg.datasetPath;
report.dataset_size = info.Dataspace.Size;
report.v15_reference = cfg.v15Script;
report.v16_reference = cfg.v16Script;
report.reference_images = reference;
report.output_root = cfg.outputRoot;
report.output_exists = isfolder(cfg.outputRoot);
report.staging_exists = isfolder(cfg.stagingRoot);

end

function dirs = create_output_tree(root)

dirs.integrity = fullfile(root, '00_integrity');
dirs.stages = fullfile(root, '01_workflow_stages');
dirs.symbols = fullfile(root, '02_symbol_dictionary');
dirs.tensors = fullfile(root, '03_training_tensors');
dirs.manifests = fullfile(root, '04_manifests');
dirs.contacts = fullfile(root, '05_contact_sheets');
names = fieldnames(dirs);
for k = 1:numel(names)
    mkdir(dirs.(names{k}));
end

end

%% Workflow definition
function stages = workflow_stages()

rows = { ...
    'source_field',             'I_0(x,y)',                         {'I','0'}; ...
    'display_transform',        'I_A = T_A[I_0]',                   {'I','A','=','T','A','I','0'}; ...
    'multiscale_field',         'G_{sigma_k} * I_0',                {'G','sigma','kappa','*','I','0'}; ...
    'gradient_field',           'nabla I_0',                        {'nabla','I','0'}; ...
    'laplacian_curvature',      'Delta I_0',                        {'delta','I','0'}; ...
    'spectral_projection',      'F{I_0}',                           {'F','{','I','0','}'}; ...
    'oriented_features',        'F_V1(theta,s)',                    {'F','V','1','theta','sigma'}; ...
    'salience_energy',          'E(x,y)',                           {'E','(','x','y',')'}; ...
    'phase_winding',            'omega = integral nabla phi dl',    {'omega','=','nabla','phi','d','l'}; ...
    'knowledge_quanta',         'K = {kappa_i}',                    {'K','=','{','kappa','I','}'}; ...
    'relation_graph',           'E = {r_ij}',                       {'E','=','{','R','I','J','}'}; ...
    'integrated_state',         'Sigma',                            {'sigma_sum'}; ...
    'human_symbol_calibration', 's_i in {Sigma,Omega,partial,nabla,oplus}', ...
                                                                    {'sigma_sum','omega','partial','nabla','oplus'}; ...
    'quantized_knowledge_state','Q_K = (K,E,Sigma)',                {'Q','K','=','(','K','E','sigma_sum',')'} ...
    };

stages = repmat(struct('index',0,'slug','','notation','','tokens',{{}}), size(rows,1), 1);
for k = 1:size(rows,1)
    stages(k).index = k;
    stages(k).slug = rows{k,1};
    stages(k).notation = rows{k,2};
    stages(k).tokens = rows{k,3};
end

end

function symbols = symbol_dictionary()

rows = { ...
    'I','I','field/sample identity'; ...
    '0','0','source index'; ...
    'A','A','display transform state'; ...
    '=','=','relation/equivalence'; ...
    'T','T','transform operator'; ...
    'G','G','multiscale kernel'; ...
    'sigma','sigma','scale parameter'; ...
    'kappa','kappa','knowledge quantum / curvature role'; ...
    '*','*','convolution/composition'; ...
    'nabla','nabla','gradient flow'; ...
    'delta','Delta','Laplacian/curvature'; ...
    'F','F','spectral or feature projection'; ...
    '{','{','set boundary'; ...
    '}','}','set boundary'; ...
    'V','V','visual feature bank'; ...
    '1','1','feature-bank index'; ...
    'theta','theta','orientation parameter'; ...
    'E','E','energy or relation set'; ...
    '(','(','group boundary'; ...
    'x','x','spatial coordinate'; ...
    'y','y','spatial coordinate'; ...
    ')',')','group boundary'; ...
    'omega','Omega/omega','winding or global-order role'; ...
    'phi','phi','phase field'; ...
    'd','d','differential element'; ...
    'l','l','path coordinate'; ...
    'K','K','knowledge-quanta set'; ...
    'R','r','relation identity'; ...
    'J','j','relation index'; ...
    'sigma_sum','Sigma','integrated state'; ...
    'partial','partial','local change'; ...
    'oplus','oplus','coupling/integration'; ...
    'Q','Q','quantized state' ...
    };

symbols = repmat(struct('token','','human','','role',''), size(rows,1), 1);
for k = 1:size(rows,1)
    symbols(k).token = rows{k,1};
    symbols(k).human = rows{k,2};
    symbols(k).role = rows{k,3};
end

end

%% Canonical data and derived workflow fields
function [CH, layoutNote] = read_canonical_channels(cfg)

raw = h5read(cfg.canonicalH5, cfg.datasetPath);
A = single(squeeze(raw));
A(~isfinite(A)) = 0;
assert(numel(A) == 5000000, 'Unexpected canonical data length.');
v = A(:);

candidates = cell(3,1);
candidates{1} = reshape(v, 1000, 1000, 5);
candidates{2} = permute(reshape(v, 5, 1000, 1000), [2 3 1]);
candidates{3} = permute(reshape(v, 1000, 5, 1000), [1 3 2]);
notes = {'layout_A reshape(v,1000,1000,5)', ...
    'layout_B reshape(v,5,1000,1000)->HxWxC', ...
    'layout_C reshape(v,1000,5,1000)->HxWxC'};
scores = zeros(3,1);
for k = 1:3
    candidates{k} = normalize_channels(candidates{k});
    B = mean(candidates{k},3);
    rough = mean(abs(diff(B,1,1)),'all') + mean(abs(diff(B,1,2)),'all');
    scores(k) = std(B(:)) / max(rough, eps('single')) + ...
        0.25*corr_safe(B(:,1:end-1),B(:,2:end)) + ...
        0.25*corr_safe(B(1:end-1,:),B(2:end,:));
end
[best, idx] = max(scores);
CH = candidates{idx};
layoutNote = sprintf('%s | selected by locality score %.6f', notes{idx}, best);

end

function CHn = normalize_channels(CH)

CHn = zeros(size(CH), 'single');
for c = 1:size(CH,3)
    CHn(:,:,c) = robust_norm(CH(:,:,c));
end

end

function [fields, aux] = derive_workflow_fields(CH, N)

small = zeros(N,N,5,'single');
for c = 1:5
    small(:,:,c) = single(imresize(CH(:,:,c), [N N], 'bicubic'));
end

w = single([0.24 0.22 0.20 0.18 0.16]);
I0 = zeros(N,N,'single');
for c = 1:5
    I0 = I0 + w(c)*small(:,:,c);
end
I0 = robust_norm(I0);
displayField = robust_norm(I0.^0.72 + 0.12*small(:,:,1) - 0.05*small(:,:,5));

g2 = imgaussfilt(I0, 2.0, 'FilterSize', 13);
g7 = imgaussfilt(I0, 7.0, 'FilterSize', 43);
dog = robust_norm(abs(g2-g7));
[gx,gy] = gradient(imgaussfilt(I0,1.0));
gradMag = robust_norm(hypot(gx,gy));
lap = robust_norm(abs(del2(imgaussfilt(I0,1.2))));
spec = robust_norm(log1p(abs(fftshift(fft2(I0)))));

orientation = zeros(N,N,'single');
for theta = linspace(0,pi,8)
    response = abs(cos(theta)*gx + sin(theta)*gy);
    orientation = max(orientation, single(response));
end
orientation = robust_norm(0.7*orientation + 0.3*dog);

salience = robust_norm(0.30*gradMag + 0.25*dog + 0.20*lap + ...
    0.15*orientation + 0.10*robust_norm(small(:,:,4)-small(:,:,2)));
phase = atan2(gy,gx);
phaseX = angle(exp(1i*circshift(phase,[0 -1])).*exp(-1i*phase));
phaseY = angle(exp(1i*circshift(phase,[-1 0])).*exp(-1i*phase));
winding = robust_norm(abs(phaseX-phaseY) .* (0.35+0.65*salience));

threshold = percentile_value(salience(:), 98.7);
maxima = salience == imdilate(salience, ones(9,'single'));
cores = single(maxima & salience >= threshold);
coreDensity = robust_norm(imgaussfilt(cores, 8.0) + 0.30*winding);
relation = relation_field_from_cores(cores, salience);
integrated = robust_norm(0.36*salience + 0.24*coreDensity + 0.22*relation + 0.18*orientation);
calibration = robust_norm(0.55*integrated + 0.25*winding + 0.20*gradMag);
quantized = robust_norm(0.42*integrated + 0.28*coreDensity + 0.20*relation + 0.10*calibration.^2);

fields = {I0, displayField, dog, gradMag, lap, spec, orientation, salience, ...
    winding, coreDensity, relation, integrated, calibration, quantized};
aux = struct('channels',small,'gradient',gradMag,'dog',dog,'laplacian',lap, ...
    'spectral',spec,'orientation',orientation,'salience',salience, ...
    'winding',winding,'cores',cores,'relation',relation,'integrated',integrated);

end

function R = relation_field_from_cores(cores, salience)

[yy,xx] = find(cores > 0);
if isempty(xx)
    R = robust_norm(salience);
    return;
end
scores = salience(sub2ind(size(salience),yy,xx));
[~,ord] = sort(scores,'descend');
keep = ord(1:min(28,numel(ord)));
xx = xx(keep); yy = yy(keep);
[X,Y] = meshgrid(1:size(salience,2),1:size(salience,1));
R = zeros(size(salience),'single');

for i = 1:numel(xx)
    d2 = (double(xx)-double(xx(i))).^2 + (double(yy)-double(yy(i))).^2;
    d2(i) = inf;
    [~,neighbors] = mink(d2,min(2,numel(xx)-1));
    for j = neighbors(:).'
        R = draw_line(R,X,Y,xx(i),yy(i),xx(j),yy(j),1.25,0.85);
    end
end
R = robust_norm(imgaussfilt(R,1.1) + 0.45*imgaussfilt(single(cores),3.0));

end

function [bank, rows] = read_reference_style_bank(paths, N)

bank = zeros(N,N,3,numel(paths),'single');
rows = cell(numel(paths),8);
for k = 1:numel(paths)
    rgb = im2single(imread(paths{k}));
    if size(rgb,3) == 1
        rgb = repmat(rgb,1,1,3);
    end
    bank(:,:,:,k) = imresize(rgb,[N N]);
    info = imfinfo(paths{k});
    [~,name,ext] = fileparts(paths{k});
    rows(k,:) = {k,[name ext],paths{k},file_sha256(paths{k}), ...
        info.Height,info.Width,size(rgb,3),'color/texture calibration only'};
end

end

%% Structural symbol construction and embedding
function [mainMask, relationMask, carrier, placements] = build_structural_symbol_field(base, tokens, cfg)

N = cfg.imageSize;
[X,Y] = meshgrid(1:N,1:N);
baseSmooth = imgaussfilt(single(base), 9.0);

pathY = zeros(1,N);
for x = 1:N
    [~,pathY(x)] = max(baseSmooth(:,x));
end
pathY = smooth_vector(pathY, 51);
pathY = 0.52*pathY + 0.48*(N/2 + 48*sin(linspace(0,3*pi,N)));
pathY = min(N-70,max(70,pathY));

motif = tokens;
while numel(motif) < 8
    motif = [motif tokens]; %#ok<AGROW>
end
motif = motif(1:min(12,numel(motif)));
n = numel(motif);
xs = linspace(48,N-48,n);
ys = zeros(1,n);
angles = zeros(1,n);
for k = 1:n
    xi = round(xs(k));
    ys(k) = pathY(xi) + 24*sin(2*pi*(k-1)/max(n,1));
    x0 = max(1,xi-3); x1 = min(N,xi+3);
    angles(k) = atan2(pathY(x1)-pathY(x0),x1-x0);
end

mainMask = zeros(N,N,'single');
relationMask = zeros(N,N,'single');
placements = zeros(n,4,'single');
glyphScale = max(12,min(21,230/n));

for k = 1:n
    localScale = glyphScale*(0.90+0.12*sin(0.7*k));
    mainMask = draw_glyph(mainMask,X,Y,motif{k},xs(k),ys(k), ...
        localScale,angles(k),2.0,1.0);
    placements(k,:) = single([xs(k),ys(k),localScale,angles(k)]);
end

for k = 1:n-1
    p1 = [xs(k) ys(k)];
    p2 = [xs(k+1) ys(k+1)];
    pc = (p1+p2)/2 + [0 -18*cos(0.8*k)];
    relationMask = draw_bezier(relationMask,X,Y,p1,pc,p2,1.05,0.76);
end
for k = 1:3:n-3
    p1 = [xs(k) ys(k)];
    p2 = [xs(k+3) ys(k+3)];
    pc = (p1+p2)/2 + [0 30*(-1)^k];
    relationMask = draw_bezier(relationMask,X,Y,p1,pc,p2,0.8,0.48);
end

mainMask = robust_norm(imgaussfilt(mainMask,0.55));
relationMask = robust_norm(imgaussfilt(relationMask,0.75));
ridge = local_ridge(base);
curv = robust_norm(abs(del2(imgaussfilt(base,1.2))));
carrier = robust_norm((0.72*mainMask + 0.28*relationMask) .* ...
    (0.28 + 0.42*ridge + 0.30*curv) + 0.16*relationMask.*base);

end

function [visible, balanced, structural] = embed_three_levels(source, base, mainMask, relationMask, carrier)

accent = cat(3, ...
    robust_norm(0.75*carrier + 0.25*mainMask), ...
    robust_norm(0.45*carrier + 0.55*relationMask), ...
    robust_norm(0.65*mainMask + 0.35*(1-base)));

soft = imgaussfilt(mainMask,4.0);
alphaVisible = clamp01(0.78*carrier + 0.40*soft + 0.20*relationMask);
alphaBalanced = clamp01(0.54*carrier + 0.24*soft + 0.14*relationMask);
alphaStructural = clamp01(0.34*carrier + 0.12*soft + 0.10*relationMask);

visible = blend_rgb(source,accent,alphaVisible);
balanced = blend_rgb(source,accent,alphaBalanced);
structural = blend_rgb(source,accent,alphaStructural);
structural = clamp01(0.76*structural + 0.24*source);

end

function [frames, projection, motion, delta] = temporal_projection(source, base, mainMask, relationMask, carrier, cfg)

N = cfg.imageSize;
T = cfg.numFrames;
frames = zeros(N,N,3,T,'single');
projection = zeros(N,N,'single');
motion = zeros(N,N,'single');
delta = zeros(N,N,'single');
prev = [];

accentBase = cat(3,robust_norm(carrier),robust_norm(0.55*mainMask+0.45*base), ...
    robust_norm(0.60*relationMask+0.40*(1-base)));

for t = 1:T
    phase = 2*pi*(t-1)/T;
    dx = round(7*sin(phase));
    dy = round(4*cos(phase));
    shiftedCarrier = circshift(carrier,[dy dx]);
    shiftedMain = circshift(mainMask,[dy dx]);
    shiftedRelation = circshift(relationMask,[round(dy/2) round(dx/2)]);
    wave = 0.5+0.5*sin(phase + 5*base);
    alpha = clamp01((0.24+0.10*wave).*shiftedCarrier + ...
        0.08*shiftedMain + 0.06*shiftedRelation);
    accent = circshift(accentBase,[dy dx 0]);
    frames(:,:,:,t) = blend_rgb(source,accent,alpha);
    projection = max(projection,shiftedCarrier);
    if ~isempty(prev)
        d = abs(rgb_luma(frames(:,:,:,t))-rgb_luma(prev));
        motion = motion + d;
        delta = max(delta,d);
    end
    prev = frames(:,:,:,t);
end

motion = robust_norm(motion/max(T-1,1));
delta = robust_norm(delta);
projection = robust_norm(projection);

end

function rgb = render_source_rgb(base, aux, style, stageIndex)

ridge = local_ridge(base);
curv = robust_norm(abs(del2(imgaussfilt(base,1.2))));
c1 = aux.channels(:,:,mod(stageIndex-1,5)+1);
c2 = aux.channels(:,:,mod(stageIndex+1,5)+1);
r = robust_norm(0.58*base + 0.25*curv + 0.17*c1);
g = robust_norm(0.54*base + 0.30*ridge + 0.16*c2);
b = robust_norm(0.48*base + 0.34*ridge + 0.18*(1-curv));
numericRGB = cat(3,r,g,b);
styleEdges = local_ridge(rgb_luma(style));
styled = 0.78*numericRGB + 0.16*style + 0.06*repmat(styleEdges,1,1,3);
rgb = clamp01(styled);

end

function rgb = render_mask(mainMask, relationMask, carrier)

rgb = clamp01(cat(3,0.82*mainMask+0.18*carrier, ...
    0.72*relationMask+0.28*carrier,0.82*carrier+0.18*mainMask));

end

function rgb = render_scalar(F, mode)

F = robust_norm(F);
ridge = local_ridge(F);
switch string(mode)
    case "projection"
        rgb = cat(3,0.25*F,0.78*F+0.22*ridge,F);
    case "motion"
        rgb = cat(3,F,0.34*F+0.35*ridge,0.10*F+0.25*ridge);
    otherwise
        rgb = cat(3,0.88*F,0.46*F+0.38*ridge,0.72*ridge+0.16*F);
end
rgb = clamp01(rgb);

end

%% Manual human-symbol geometry
function mask = draw_glyph(mask,X,Y,token,cx,cy,s,angle,thick,val)

segments = glyph_segments(token);
for k = 1:size(segments,1)
    [x1,y1] = local_to_global(segments(k,1),segments(k,2),cx,cy,s,angle);
    [x2,y2] = local_to_global(segments(k,3),segments(k,4),cx,cy,s,angle);
    mask = draw_line(mask,X,Y,x1,y1,x2,y2,thick,val);
end

end

function segments = glyph_segments(token)

token = char(string(token));
switch token
    case 'I'
        segments = [-0.55 -0.85 0.55 -0.85; 0 -0.85 0 0.85; -0.55 0.85 0.55 0.85];
    case '0'
        segments = arc_segments(0,0,0.58,0.86,0,360,18);
    case '1'
        segments = [-0.25 -0.55 0 -0.85; 0 -0.85 0 0.85; -0.42 0.85 0.42 0.85];
    case 'A'
        segments = [-0.70 0.85 0 -0.85; 0 -0.85 0.70 0.85; -0.42 0.25 0.42 0.25];
    case 'T'
        segments = [-0.72 -0.85 0.72 -0.85; 0 -0.85 0 0.85];
    case 'G'
        segments = [arc_segments(0,0,0.68,0.82,35,325,16); 0.05 0.10 0.68 0.10; 0.68 0.10 0.68 0.68];
    case 'F'
        segments = [-0.50 -0.85 -0.50 0.85; -0.50 -0.85 0.65 -0.85; -0.50 0 0.45 0];
    case 'V'
        segments = [-0.68 -0.85 0 0.85; 0 0.85 0.68 -0.85];
    case 'E'
        segments = [-0.55 -0.85 -0.55 0.85; -0.55 -0.85 0.62 -0.85; -0.55 0 0.42 0; -0.55 0.85 0.62 0.85];
    case 'K'
        segments = [-0.52 -0.85 -0.52 0.85; -0.52 0 0.62 -0.85; -0.52 0 0.62 0.85];
    case 'Q'
        segments = [arc_segments(0,-0.05,0.62,0.76,0,360,18); 0.18 0.38 0.72 0.90];
    case 'R'
        segments = [-0.52 -0.85 -0.52 0.85; arc_segments(-0.05,-0.42,0.55,0.43,-90,270,13); -0.10 0 0.68 0.85];
    case 'J'
        segments = [-0.58 -0.85 0.58 -0.85; 0.36 -0.85 0.36 0.48; 0.36 0.48 0.05 0.82; 0.05 0.82 -0.42 0.62];
    case 'x'
        segments = [-0.62 -0.65 0.62 0.65; -0.62 0.65 0.62 -0.65];
    case 'y'
        segments = [-0.62 -0.68 0 0; 0.62 -0.68 0 0; 0 0 0 0.85];
    case 'd'
        segments = [arc_segments(-0.05,0.15,0.52,0.55,0,360,14); 0.45 -0.85 0.45 0.70];
    case 'l'
        segments = [0 -0.85 0 0.85; 0 0.85 0.35 0.85];
    case '='
        segments = [-0.72 -0.24 0.72 -0.24; -0.72 0.24 0.72 0.24];
    case '*'
        segments = [-0.62 0 0.62 0; -0.45 -0.58 0.45 0.58; -0.45 0.58 0.45 -0.58];
    case '(' 
        segments = arc_segments(0.34,0,0.55,0.95,110,250,10);
    case ')'
        segments = arc_segments(-0.34,0,0.55,0.95,-70,70,10);
    case '{'
        segments = [-0.10 -0.90 -0.42 -0.70; -0.42 -0.70 -0.42 -0.18; -0.42 -0.18 -0.72 0; -0.72 0 -0.42 0.18; -0.42 0.18 -0.42 0.70; -0.42 0.70 -0.10 0.90];
    case '}'
        segments = [0.10 -0.90 0.42 -0.70; 0.42 -0.70 0.42 -0.18; 0.42 -0.18 0.72 0; 0.72 0 0.42 0.18; 0.42 0.18 0.42 0.70; 0.42 0.70 0.10 0.90];
    case 'nabla'
        segments = [-0.72 -0.70 0.72 -0.70; 0.72 -0.70 0 0.82; 0 0.82 -0.72 -0.70];
    case 'delta'
        segments = [0 -0.86 0.72 0.78; 0.72 0.78 -0.72 0.78; -0.72 0.78 0 -0.86];
    case 'sigma'
        segments = [arc_segments(-0.15,0.12,0.62,0.58,20,330,13); 0.42 -0.42 0.42 0.78];
    case 'kappa'
        segments = [-0.50 -0.85 -0.50 0.85; -0.50 0.05 0.58 -0.68; -0.50 0.05 0.62 0.82];
    case 'theta'
        segments = [arc_segments(0,0.05,0.58,0.78,0,360,18); -0.55 0 0.55 0];
    case 'omega'
        segments = [arc_segments(0,0.10,0.64,0.78,180,360,12); -0.64 0.10 -0.48 0.72; 0.64 0.10 0.48 0.72; -0.48 0.72 -0.12 0.72; 0.12 0.72 0.48 0.72];
    case 'phi'
        segments = [arc_segments(0,0,0.58,0.58,0,360,16); 0 -0.92 0 0.92];
    case 'sigma_sum'
        segments = [-0.62 -0.82 0.62 -0.82; 0.62 -0.82 -0.48 0; -0.48 0 0.62 0.82; 0.62 0.82 -0.62 0.82];
    case 'partial'
        segments = [arc_segments(-0.05,0.18,0.56,0.58,-40,320,15); -0.48 -0.70 0.35 -0.92; 0.35 -0.92 0.60 -0.58];
    case 'oplus'
        segments = [arc_segments(0,0,0.72,0.72,0,360,18); -0.45 0 0.45 0; 0 -0.45 0 0.45];
    otherwise
        segments = [-0.55 0 0.55 0; 0 -0.55 0 0.55];
end

end

function seg = arc_segments(cx,cy,rx,ry,deg1,deg2,n)

t = linspace(deg1*pi/180,deg2*pi/180,n+1);
seg = zeros(n,4);
for i = 1:n
    seg(i,:) = [cx+rx*cos(t(i)),cy+ry*sin(t(i)), ...
        cx+rx*cos(t(i+1)),cy+ry*sin(t(i+1))];
end

end

function [xg,yg] = local_to_global(x,y,cx,cy,s,angle)

ca = cos(angle); sa = sin(angle);
xg = cx+s*(ca*x-sa*y);
yg = cy+s*(sa*x+ca*y);

end

function mask = draw_line(mask,X,Y,x1,y1,x2,y2,thick,val)

vx = x2-x1; vy = y2-y1;
den = vx*vx+vy*vy+eps;
t = ((X-x1)*vx+(Y-y1)*vy)/den;
t = min(1,max(0,t));
px = x1+t*vx; py = y1+t*vy;
dist2 = (X-px).^2+(Y-py).^2;
sigma = max(0.7,thick*0.65);
stroke = single(val)*exp(-dist2/(2*sigma*sigma));
mask = max(mask,single(stroke));

end

function mask = draw_bezier(mask,X,Y,p1,pc,p2,thick,val)

steps = 28;
prev = p1;
for i = 1:steps
    t = i/steps;
    p = (1-t)^2*p1+2*(1-t)*t*pc+t^2*p2;
    mask = draw_line(mask,X,Y,prev(1),prev(2),p(1),p(2),thick,val);
    prev = p;
end

end

%% Artifact generation
function rows = write_symbol_dictionary(symbols, outDir, cfg)

N = cfg.imageSize;
[X,Y] = meshgrid(1:N,1:N);
tiles = cell(numel(symbols),1);
rows = cell(numel(symbols),7);
for k = 1:numel(symbols)
    mask = zeros(N,N,'single');
    mask = draw_glyph(mask,X,Y,symbols(k).token,N/2,N/2,92,0,4.2,1.0);
    mask = robust_norm(imgaussfilt(mask,0.6));
    rgb = render_mask(mask,0.2*mask,mask);
    p = fullfile(outDir,sprintf('%02d_%s.png',k,safe_slug(symbols(k).token)));
    imwrite(rgb,p);
    tiles{k} = rgb;
    rows(k,:) = {k,symbols(k).token,symbols(k).human,symbols(k).role, ...
        'manual line/arc geometry; no text overlay',relative_path(p,fileparts(outDir)),file_sha256(p)};
end
imwrite(image_cell_sheet(tiles,6,6,[0.01 0.015 0.03]), ...
    fullfile(outDir,'HumanSymbolPatternDictionary_ContactSheet.png'));

end

function write_training_artifacts(outDir, CH, structural, masks, projection, motion, delta, temporal, codebook, stages, cfg)

h5Path = fullfile(outDir,'knowledge_quantization_training_bundle_v1.h5');
source128 = zeros(cfg.trainingSize,cfg.trainingSize,5,'single');
for c = 1:5
    source128(:,:,c) = single(imresize(CH(:,:,c),[cfg.trainingSize cfg.trainingSize]));
end

h5write_dataset(h5Path,'/source/canonical_channels',source128);
h5write_dataset(h5Path,'/visual/structural_rgb_uint8',structural);
h5write_dataset(h5Path,'/visual/symbol_masks',masks);
h5write_dataset(h5Path,'/visual/projection_maps',projection);
h5write_dataset(h5Path,'/visual/motion_energy',motion);
h5write_dataset(h5Path,'/visual/temporal_delta',delta);
h5write_dataset(h5Path,'/temporal/frames_rgb_uint8',temporal);
h5write_dataset(h5Path,'/semantic/stage_symbol_codebook',codebook);
adjacency = single(diag(ones(numel(stages)-1,1),1));
adjacency = adjacency+adjacency.';
h5write_dataset(h5Path,'/semantic/workflow_adjacency',adjacency);
h5writeatt(h5Path,'/','canonical_source_sha256',cfg.expectedHash);
h5writeatt(h5Path,'/','scope_note',cfg.scopeNote);
h5writeatt(h5Path,'/','stage_order','01..14 follows WorkflowStages.csv');

end

function h5write_dataset(path,dataset,data)

dims = size(data);
chunk = dims;
chunk(1) = min(chunk(1),64);
if numel(chunk) >= 2, chunk(2) = min(chunk(2),64); end
if numel(chunk) >= 3, chunk(3) = min(chunk(3),3); end
if numel(chunk) >= 4, chunk(4) = min(chunk(4),2); end
if numel(chunk) >= 5, chunk(5) = min(chunk(5),2); end
h5create(path,dataset,dims,'Datatype',class(data),'ChunkSize',max(chunk,1),'Deflate',4);
h5write(path,dataset,data);

end

function write_stage_manifest(stages, metrics, path)

rows = cell(numel(stages),10);
for k = 1:numel(stages)
    rows(k,:) = {k,stages(k).slug,stages(k).notation,strjoin(stages(k).tokens,'|'), ...
        metrics(k).mask_density,metrics(k).relation_density,metrics(k).carrier_energy, ...
        metrics(k).motion_energy,metrics(k).temporal_delta,metrics(k).structure_preservation};
end
write_cell_csv(rows,{'stage_index','stage_slug','human_notation','tokens', ...
    'mask_density','relation_density','carrier_energy','motion_energy', ...
    'temporal_delta','structure_preservation'},path);

end

function write_plan_document(path,cfg,stages,layoutNote)

lines = { ...
    '# Knowledge Quantization Structural Visual Learning v1'; ...
    ''; ...
    '## Purpose'; ...
    ''; ...
    'A MATLAB-derived visual-learning workflow in which official mathematical notation is built as geometry inside masks, carriers, projections, and temporal motion.'; ...
    ''; ...
    '## Integrity'; ...
    ''; ...
    ['- Canonical H5: `' cfg.canonicalH5 '`']; ...
    ['- Canonical SHA-256: `' cfg.expectedHash '`']; ...
    ['- Dataset: `' cfg.datasetPath '`']; ...
    ['- Layout: ' layoutNote]; ...
    '- References: six supplied 512x512 string-foundation images, plus the established v15/v16 structural-projection conventions.'; ...
    ''; ...
    '## Ordered workflow'; ...
    ''};
for k = 1:numel(stages)
    lines{end+1} = sprintf('%d. `%s` - `%s`',k,stages(k).slug,stages(k).notation); %#ok<AGROW>
end
lines = [lines; {''; '## Visual layers'; ''; ...
    '- `visible`: maximum symbol legibility.'; ...
    '- `balanced`: notation and source field share the image.'; ...
    '- `structural`: notation is coupled to ridges/curvature while preserving the source field.'; ...
    '- Every stage also contains its mask, projection map, motion energy, temporal delta, eight-frame sheet, and numeric temporal patch.'; ...
    ''; '## Scope boundary'; ''; ['> ' cfg.scopeNote]}];
write_text(path,strjoin(lines,newline));

end

function validation = validate_package(root,numStages,numFrames,structural,masks,projection,temporal,metrics)

pngs = dir(fullfile(root,'**','*.png'));
mats = dir(fullfile(root,'**','*.mat'));
csvs = dir(fullfile(root,'**','*.csv'));
h5s = dir(fullfile(root,'**','*.h5'));

validation = struct();
validation.all_finite = all(isfinite(single(structural(:)))) && ...
    all(isfinite(masks(:))) && all(isfinite(projection(:)));
validation.stage_count = numStages;
validation.frames_per_stage = numFrames;
validation.png_count = numel(pngs);
validation.mat_count = numel(mats);
validation.csv_count = numel(csvs);
validation.h5_count = numel(h5s);
validation.structural_tensor_size = size(structural);
validation.mask_tensor_size = size(masks);
validation.temporal_tensor_size = size(temporal);
validation.nonempty_masks = all(squeeze(sum(sum(masks,1),2)) > 0);
validation.nonempty_projection = all(squeeze(sum(sum(projection,1),2)) > 0);
validation.structure_preservation_min = min([metrics.structure_preservation]);
validation.structure_preservation_mean = mean([metrics.structure_preservation]);
validation.expected_stage_pngs_present = numel(dir(fullfile(root,'01_workflow_stages','**','*.png'))) == numStages*9;
validation.pass = validation.all_finite && validation.nonempty_masks && ...
    validation.nonempty_projection && validation.expected_stage_pngs_present && ...
    validation.png_count >= numStages*9+2 && validation.mat_count >= numStages+1 && validation.h5_count == 1;
assert(validation.pass,'Output validation failed.');

end

%% Image sheets and numeric utilities
function sheet = frame_sheet(frames)

tiles = cell(size(frames,4),1);
for k = 1:size(frames,4), tiles{k} = frames(:,:,:,k); end
sheet = image_cell_sheet(tiles,2,4,[0.01 0.015 0.03]);

end

function sheet = image_cell_sheet(images,rows,cols,bg)

assert(numel(images) <= rows*cols);
if isempty(images), sheet = zeros(1,1,3,'single'); return; end
[h,w,~] = size(images{1});
gap = 8;
sheet = zeros(rows*h+(rows+1)*gap,cols*w+(cols+1)*gap,3,'single');
for c = 1:3, sheet(:,:,c) = bg(c); end
for k = 1:numel(images)
    r = floor((k-1)/cols)+1;
    c = mod(k-1,cols)+1;
    y = gap+(r-1)*(h+gap)+(1:h);
    x = gap+(c-1)*(w+gap)+(1:w);
    sheet(y,x,:) = im2single(images{k});
end

end

function rgb = blend_rgb(a,b,alpha)

alpha3 = repmat(clamp01(single(alpha)),1,1,3);
rgb = clamp01((1-alpha3).*single(a)+alpha3.*single(b));

end

function y = rgb_luma(rgb)

y = 0.2126*single(rgb(:,:,1))+0.7152*single(rgb(:,:,2))+0.0722*single(rgb(:,:,3));

end

function R = local_ridge(F)

F = single(F);
R = robust_norm(max(0,F-imgaussfilt(F,4.0)) + 0.35*abs(del2(imgaussfilt(F,1.0))));

end

function y = robust_norm(x)

x = single(x); x(~isfinite(x)) = 0;
lo = percentile_value(x(:),1.0);
hi = percentile_value(x(:),99.0);
if hi <= lo+eps('single')
    lo = min(x(:)); hi = max(x(:));
end
y = (x-lo)/max(hi-lo,eps('single'));
y = clamp01(y);

end

function q = percentile_value(v,p)

v = sort(single(v(isfinite(v))));
if isempty(v), q = single(0); return; end
idx = 1+(numel(v)-1)*p/100;
lo = floor(idx); hi = ceil(idx);
if lo == hi, q = v(lo); else, q = v(lo)+(idx-lo)*(v(hi)-v(lo)); end

end

function y = clamp01(x)

y = min(1,max(0,single(x)));

end

function y = smooth_vector(x,w)

k = ones(1,w)/w;
y = conv([repmat(x(1),1,w) x repmat(x(end),1,w)],k,'same');
y = y(w+(1:numel(x)));

end

function r = corr_safe(a,b)

a = double(a(:)); b = double(b(:));
a = a-mean(a); b = b-mean(b);
den = sqrt(sum(a.^2)*sum(b.^2));
if den <= eps, r = 0; else, r = sum(a.*b)/den; end

end

%% File and manifest utilities
function write_cell_csv(rows,headers,path)

fid = fopen(path,'w');
assert(fid >= 0,'Could not open CSV for writing: %s',path);
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',strjoin(cellfun(@csv_escape,headers,'UniformOutput',false),','));
for r = 1:size(rows,1)
    values = cell(1,size(rows,2));
    for c = 1:size(rows,2)
        v = rows{r,c};
        if isnumeric(v) || islogical(v)
            values{c} = sprintf('%.12g',double(v));
        else
            values{c} = char(string(v));
        end
        values{c} = csv_escape(values{c});
    end
    fprintf(fid,'%s\n',strjoin(values,','));
end

end

function s = csv_escape(s)

s = char(string(s));
s = strrep(s,'"','""');
if contains(s,{',','"',newline})
    s = ['"' s '"'];
end

end

function write_json(path,value)

try
    text = jsonencode(value,PrettyPrint=true);
catch
    text = jsonencode(value);
end
write_text(path,text);

end

function write_text(path,text)

fid = fopen(path,'w');
assert(fid >= 0,'Could not open file for writing: %s',path);
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid,char(text),'char');

end

function hash = file_sha256(path)

fid = fopen(path,'r');
assert(fid >= 0,'Could not read file for SHA-256: %s',path);
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
md = java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes = fread(fid,1024*1024,'*uint8');
    if ~isempty(bytes), md.update(typecast(bytes,'int8')); end
end
digest = typecast(md.digest(),'uint8');
hash = lower(reshape(dec2hex(digest,2).',1,[]));

end

function bytes = file_size(path)

d = dir(path); bytes = d.bytes;

end

function rel = relative_path(path,root)

prefix = [char(root) filesep];
rel = char(path);
if startsWith(rel,prefix), rel = rel(numel(prefix)+1:end); end

end

function slug = safe_slug(token)

slug = lower(regexprep(char(string(token)),'[^a-zA-Z0-9]+','_'));
if isempty(slug), slug = 'symbol'; end

end
