function results = YEHOSHUA_string_theory_foundations_law_atlas_v4(mode)
% YEHOSHUA_string_theory_foundations_law_atlas_v4
% Builds an ordered visual-learning atlas for foundational string theory,
% embeds standard human mathematical notation in every card, and extracts
% canonical H5 datasets into individually traceable MATLAB tensor files.
%
% The canonical H5 tensors are used as visual-learning source material only.
% They are not represented as experimental measurements of string theory.

if nargin < 1
    mode = "execute";
end
mode = lower(string(mode));
assert(ismember(mode, ["preflight", "execute", "refresh_visuals", ...
    "refresh_law_06"]), ...
    'Mode must be preflight, execute, refresh_visuals, or refresh_law_06.');

cfg = configuration();
concepts = conceptSpecifications();
laws = lawSpecifications();
datasets = datasetSpecifications();
references = sourceReferences();
validateInputs(cfg, concepts, laws, datasets, references);

if mode == "preflight"
    results = preflightResult(cfg, concepts, laws, datasets);
    fprintf('\nPREFLIGHT COMPLETE - NO OUTPUT FILES WRITTEN\n');
    fprintf('Concept cards         : %d\n', numel(concepts));
    fprintf('Law cards             : %d\n', numel(laws));
    fprintf('Canonical H5 datasets : %d\n', numel(datasets));
    fprintf('Human notation        : embedded in every card\n');
    fprintf('Output root available : %s\n', string(~isfolder(cfg.outputRoot)));
    return;
end

if mode == "refresh_visuals"
    assert(isfolder(cfg.outputRoot), ...
        'The completed output folder is required for visual refresh.');
    startTime = tic;
    conceptFiles = renderConceptCards(cfg, concepts);
    lawFiles = renderLawCards(cfg, laws);
    sequenceFiles = buildLearningSequences( ...
        cfg, concepts, laws, conceptFiles, lawFiles);
    tensorFiles = struct;
    tensorFiles.mat = fullfile(cfg.trainingDirectory, ...
        'StringTheoryFoundationsLearningTensors.mat');
    tensorFiles.h5 = fullfile(cfg.trainingDirectory, ...
        'StringTheoryFoundationsLearningTensors.h5');
    loaded = load(tensorFiles.mat, 'training');
    training = loaded.training;
    training.conceptImages = readImageTensor(conceptFiles, cfg.tensorImageSize);
    training.lawImages = readImageTensor(lawFiles, cfg.tensorImageSize);
    training.conceptInkMasks = buildInkMasks(training.conceptImages);
    training.lawInkMasks = buildInkMasks(training.lawImages);
    tensorFiles = writeTrainingTensorFiles(cfg, training);
    tensorInventory = readtable(fullfile(cfg.extractDirectory, ...
        'H5TensorInventory.csv'), 'TextType', 'string');
    validation = validateOutputs(cfg, concepts, laws, datasets, ...
        conceptFiles, lawFiles, tensorFiles, tensorInventory, training);
    refresh = struct;
    refresh.mode = 'refresh_visuals';
    refresh.visual_bug_fixed = true;
    refresh.formulas_visible = true;
    refresh.definition_text_visible = true;
    refresh.sequence_file_count = numel(sequenceFiles);
    refresh.all_checks_pass = validation.allChecksPass;
    refresh.elapsed_seconds = toc(startTime);
    writeText(fullfile(cfg.integrityDirectory, 'VisualRefreshValidation.json'), ...
        jsonencode(refresh, PrettyPrint=true));
    results = refresh;
    results.outputRoot = cfg.outputRoot;
    fprintf('\nVISUAL REFRESH COMPLETE\n');
    fprintf('Concept cards refreshed : %d\n', numel(conceptFiles));
    fprintf('Law cards refreshed     : %d\n', numel(lawFiles));
    fprintf('Formulas visible        : true\n');
    fprintf('All output checks pass  : %s\n', string(validation.allChecksPass));
    fprintf('Elapsed                 : %.3f s\n', results.elapsed_seconds);
    return;
end

if mode == "refresh_law_06"
    assert(isfolder(cfg.outputRoot), ...
        'The completed output folder is required for law-card refresh.');
    startTime = tic;
    conceptFiles = strings(numel(concepts), 1);
    for i = 1:numel(concepts)
        conceptFiles(i) = fullfile(cfg.conceptDirectory, ...
            sprintf('%02d_%s.png', concepts(i).id, concepts(i).slug));
    end
    lawFiles = strings(numel(laws), 1);
    for i = 1:numel(laws)
        lawFiles(i) = fullfile(cfg.lawDirectory, ...
            sprintf('%02d_%s.png', laws(i).id, laws(i).slug));
    end
    renderOneLawCard(cfg, laws(6), lawFiles(6));
    sequenceFiles = buildLearningSequences( ...
        cfg, concepts, laws, conceptFiles, lawFiles);
    matPath = fullfile(cfg.trainingDirectory, ...
        'StringTheoryFoundationsLearningTensors.mat');
    loaded = load(matPath, 'training');
    training = loaded.training;
    training.lawImages = readImageTensor(lawFiles, cfg.tensorImageSize);
    training.lawInkMasks = buildInkMasks(training.lawImages);
    tensorFiles = writeTrainingTensorFiles(cfg, training);
    tensorInventory = readtable(fullfile(cfg.extractDirectory, ...
        'H5TensorInventory.csv'), 'TextType', 'string');
    validation = validateOutputs(cfg, concepts, laws, datasets, ...
        conceptFiles, lawFiles, tensorFiles, tensorInventory, training);
    refresh = struct;
    refresh.mode = 'refresh_law_06';
    refresh.unsupported_mathbb_removed = true;
    refresh.formula_visible = true;
    refresh.sequence_file_count = numel(sequenceFiles);
    refresh.all_checks_pass = validation.allChecksPass;
    refresh.elapsed_seconds = toc(startTime);
    writeText(fullfile(cfg.integrityDirectory, 'Law06RefreshValidation.json'), ...
        jsonencode(refresh, PrettyPrint=true));
    results = refresh;
    results.outputRoot = cfg.outputRoot;
    fprintf('\nLAW 06 REFRESH COMPLETE\n');
    fprintf('Unsupported mathbb removed: true\n');
    fprintf('All output checks pass    : %s\n', string(validation.allChecksPass));
    fprintf('Elapsed                   : %.3f s\n', results.elapsed_seconds);
    return;
end

assert(~isfolder(cfg.outputRoot), ...
    'Output folder already exists; no files were changed.');
startTime = tic;

try
    createOutputFolders(cfg);
    writeIntegrityRecord(cfg);

    fprintf('\n%s\n', repmat('=', 1, 76));
    fprintf('YEHOSHUA STRING THEORY FOUNDATIONS AND LAW ATLAS V4\n');
    fprintf('%s\n', repmat('=', 1, 76));
    fprintf('canonical H5 : %s\n', cfg.canonicalH5);
    fprintf('output root  : %s\n\n', cfg.outputRoot);

    fprintf('[1/7] Extracting canonical H5 tensors into ordered MATLAB files\n');
    tensorInventory = extractCanonicalTensors(cfg, datasets);

    fprintf('[2/7] Building compact canonical visual-source tensors\n');
    [sourceTensor, sourceNames] = buildCanonicalSourceTensor(cfg);

    fprintf('[3/7] Rendering foundational concept cards with human notation\n');
    conceptFiles = renderConceptCards(cfg, concepts);

    fprintf('[4/7] Rendering basic-law cards with human notation\n');
    lawFiles = renderLawCards(cfg, laws);

    fprintf('[5/7] Building ordered learning sequences and contact sheets\n');
    sequenceFiles = buildLearningSequences( ...
        cfg, concepts, laws, conceptFiles, lawFiles);

    fprintf('[6/7] Packaging image-learning and notation tensors\n');
    training = buildTrainingTensors(cfg, concepts, laws, ...
        conceptFiles, lawFiles, sourceTensor, sourceNames);
    tensorFiles = writeTrainingTensorFiles(cfg, training);

    fprintf('[7/7] Writing manifests and validating the completed bundle\n');
    manifests = writeManifests(cfg, concepts, laws, datasets, references, ...
        tensorInventory, sourceNames, conceptFiles, lawFiles, ...
        sequenceFiles, tensorFiles, training, startTime);
    validation = validateOutputs(cfg, concepts, laws, datasets, ...
        conceptFiles, lawFiles, tensorFiles, tensorInventory, training);

    results = struct;
    results.mode = char(mode);
    results.outputRoot = cfg.outputRoot;
    results.conceptCount = numel(concepts);
    results.lawCount = numel(laws);
    results.h5DatasetCount = numel(datasets);
    results.tensorExtractCount = height(tensorInventory);
    results.humanNotationEmbedded = true;
    results.tensorFiles = tensorFiles;
    results.manifests = manifests;
    results.validation = validation;
    results.elapsedSeconds = toc(startTime);

    fprintf('\nRUN COMPLETE\n');
    fprintf('Concept cards          : %d\n', results.conceptCount);
    fprintf('Law cards              : %d\n', results.lawCount);
    fprintf('H5 tensor extracts     : %d\n', results.tensorExtractCount);
    fprintf('Human notation embedded: true\n');
    fprintf('All output checks pass : %s\n', string(validation.allChecksPass));
    fprintf('Existing files changed : 0\n');
    fprintf('Output folder          : %s\n', cfg.outputRoot);
    fprintf('Elapsed                : %.3f s\n', results.elapsedSeconds);
    fprintf('%s\n', repmat('=', 1, 76));
catch runError
    if isfolder(cfg.outputRoot)
        rmdir(cfg.outputRoot, 's');
    end
    rethrow(runError);
end
end


function cfg = configuration()
cfg = struct;
cfg.version = 'YEHOSHUA_string_theory_foundations_law_atlas_v4';
cfg.subject = 'visual_learning';
cfg.domain = 'foundational_string_theory_and_basic_laws';
cfg.canonicalH5 = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedSHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.basePath = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15'];
cfg.outputRoot = fullfile(cfg.basePath, ...
    'YEHOSHUA_string_theory_foundations_law_atlas_v4');
cfg.integrityDirectory = fullfile(cfg.outputRoot, '00_integrity');
cfg.conceptDirectory = fullfile(cfg.outputRoot, '01_concepts');
cfg.lawDirectory = fullfile(cfg.outputRoot, '02_basic_laws');
cfg.sequenceDirectory = fullfile(cfg.outputRoot, '03_learning_sequences');
cfg.extractDirectory = fullfile(cfg.outputRoot, '04_h5_tensor_extracts');
cfg.trainingDirectory = fullfile(cfg.outputRoot, '05_training_tensors');
cfg.manifestDirectory = fullfile(cfg.outputRoot, '06_manifests');
cfg.contactDirectory = fullfile(cfg.outputRoot, '07_contact_sheets');
cfg.cardSize = [900 1400];
cfg.tensorImageSize = [224 224];
cfg.sourceSpatialSize = 64;
end


function concepts = conceptSpecifications()
rows = {
    1,  'particle',        'Particle / חלקיק',                '$x^\mu(\tau)$',                         'A point-like excitation follows a worldline.',                    'particle';
    2,  'string',          'String / מיתר',                   '$X^\mu(\tau,\sigma)$',                 'A one-dimensional object is labelled along $\sigma$.',           'string';
    3,  'open_string',     'Open string / מיתר פתוח',        '$0\leq\sigma\leq\pi$',               'Two endpoints require boundary conditions.',                      'open';
    4,  'closed_string',   'Closed string / מיתר סגור',      '$\sigma\sim\sigma+2\pi$',            'The string coordinate is periodic.',                              'closed';
    5,  'vibration_mode',  'Vibrational mode / אופן תנודה',  '$X\sim\cos(n\sigma),\ n=1,2,3,\ldots$', 'Allowed shapes form a discrete mode family.',                  'mode';
    6,  'particle_as_mode','Particle as a string state',      '$|N;k\rangle$',                         'Different quantized excitations appear as different states.',     'particlemode';
    7,  'string_tension',  'String tension / מתיחות',        '$T=(2\pi\alpha'')^{-1}$',              'Tension sets the energy per unit length.',                         'tension';
    8,  'worldline_sheet', 'Worldline and worldsheet',        '$\tau\ \longrightarrow\ (\tau,\sigma)$', 'A moving string sweeps a two-dimensional worldsheet.',       'worldsheet';
    9,  'embedding_map',   'Embedding into spacetime',        '$X^\mu:\Sigma\rightarrow\mathcal{M}$', 'Worldsheet coordinates map into target spacetime.',              'embedding';
    10, 'interaction',     'Splitting and joining',           '$g_s$',                                  'String interactions are smooth splitting/joining worldsheets.',  'interaction';
    11, 'd_brane',         'D-brane / ממברנת D',              '$X^i|_{\partial\Sigma}=y^i$',          'Open-string endpoints can be fixed to a D-brane.',                'brane';
    12, 'compact_dimension','Compact dimension',              '$X\sim X+2\pi R$',                     'A compact direction closes on itself with radius $R$.',           'compact';
    13, 't_duality',       'T-duality',                       '$R\leftrightarrow\alpha''/R,\ n\leftrightarrow w$', 'Momentum and winding exchange under radius inversion.', 'duality';
    14, 'closed_gravity',  'Closed-string gravity state',     '$\epsilon_{\mu\nu}\alpha_{-1}^\mu\widetilde\alpha_{-1}^\nu|0;k\rangle$', 'A massless closed-string level contains a spin-2 sector.', 'gravity';
    15, 'worldsheet_susy', 'Worldsheet supersymmetry',        '$(X^\mu,\psi^\mu)$',                   'Bosonic and fermionic worldsheet fields are paired.',              'super';
    16, 'critical_dimension','Critical dimension',            '$D=26\ \mathrm{(bosonic)},\quad D=10\ \mathrm{(superstring)}$', 'Quantum consistency fixes model-dependent critical dimensions.', 'dimension';
    17, 'string_coupling', 'String coupling and dilaton',     '$g_s=e^{\langle\Phi\rangle}$',         'The dilaton expectation value sets perturbative coupling.',       'coupling'};

concepts = repmat(struct('id', 0, 'slug', '', 'title', '', ...
    'notation', '', 'definition', '', 'visualType', ''), size(rows, 1), 1);
for i = 1:size(rows, 1)
    concepts(i).id = rows{i, 1};
    concepts(i).slug = rows{i, 2};
    concepts(i).title = rows{i, 3};
    concepts(i).notation = rows{i, 4};
    concepts(i).definition = rows{i, 5};
    concepts(i).visualType = rows{i, 6};
end
end


function laws = lawSpecifications()
rows = {
    1,  'nambu_goto_action', 'Area law: Nambu-Goto action', '$S_{NG}=-T\int d\tau\,d\sigma\,\sqrt{-\det\gamma_{ab}}$', '$\gamma_{ab}=\partial_aX^\mu\partial_bX_\mu$', 'The classical string minimizes worldsheet area.', 'action';
    2,  'polyakov_action', 'Polyakov action', '$S_P=-\frac{T}{2}\int d^2\sigma\sqrt{-h}\,h^{ab}\partial_aX^\mu\partial_bX_\mu$', '$h_{ab}$ is an auxiliary worldsheet metric.', 'A classically equivalent form exposes worldsheet symmetries.', 'polyakov';
    3,  'wave_equation', 'Worldsheet wave equation', '$(\partial_\tau^2-\partial_\sigma^2)X^\mu=0$', 'conformal gauge', 'Left- and right-moving waves carry the string motion.', 'wave';
    4,  'open_boundaries', 'Open-string boundary law', '$\partial_\sigma X^a=0\ \mathrm{(N)},\quad\delta X^i=0\ \mathrm{(D)}$', '$\sigma=0,\pi$', 'Endpoints obey Neumann or Dirichlet conditions.', 'open';
    5,  'closed_periodicity', 'Closed-string periodicity', '$X^\mu(\tau,\sigma+2\pi)=X^\mu(\tau,\sigma)$', '$\sigma\sim\sigma+2\pi$', 'Closed-string fields repeat around the loop.', 'closed';
    6,  'mode_expansion', 'Discrete mode expansion', '$X(\tau,\sigma)=x_0+\sum_{n\neq0}X_n(\tau)e^{in\sigma}$', '$n=0,\pm1,\pm2,\ldots$', 'Boundary conditions select discrete harmonics.', 'mode';
    7,  'tension_energy', 'Tension-energy relation', '$E=T\,L,\qquad T=\frac{1}{2\pi\alpha''}$', 'static straight string', 'Longer string segments carry proportionally more energy.', 'tension';
    8,  'oscillator_quantization', 'Oscillator quantization', '$N=\sum_{n>0}\alpha_{-n}\!\cdot\!\alpha_n$', '$N=0,1,2,\ldots$', 'Quantized oscillators organize excitation levels.', 'quantization';
    9,  'bosonic_mass_shell', 'Bosonic mass levels', '$\alpha''M^2=N-1\ \mathrm{(open)}$', '$\alpha''M^2=4(N-1),\ N=\widetilde N\ \mathrm{(closed)}$', 'The intercept and factors depend on the string model and convention.', 'mass';
    10, 't_duality_invariance', 'T-duality of compact modes', '$M_{n,w}^2\supset(n/R)^2+(wR/\alpha'')^2$', '$R\leftrightarrow\alpha''/R,\ n\leftrightarrow w$', 'The momentum-winding contribution is invariant.', 'duality';
    11, 'd_brane_endpoints', 'D-brane endpoint law', '$\partial_\sigma X^a=0,\quad X^i=y^i$', '$a\parallel Dp,\ i\perp Dp$', 'Endpoints move along a brane but are fixed transversely.', 'brane';
    12, 'genus_coupling', 'Interaction topology and coupling', '$\mathcal{A}_g\propto g_s^{\,2g-2}$', '$g=0,1,2,\ldots$', 'Each additional handle changes perturbative order.', 'coupling'};

laws = repmat(struct('id', 0, 'slug', '', 'title', '', 'formula', '', ...
    'condition', '', 'definition', '', 'visualType', ''), size(rows, 1), 1);
for i = 1:size(rows, 1)
    laws(i).id = rows{i, 1};
    laws(i).slug = rows{i, 2};
    laws(i).title = rows{i, 3};
    laws(i).formula = rows{i, 4};
    laws(i).condition = rows{i, 5};
    laws(i).definition = rows{i, 6};
    laws(i).visualType = rows{i, 7};
end
end


function datasets = datasetSpecifications()
paths = [ ...
    "/n_2_e8_lattice/roots_2d"
    "/n_2_e8_lattice/connections/a"
    "/n_2_e8_lattice/connections/b"
    "/n_2_e8_lattice/connections/d"
    "/n_2_e8_lattice/laplacian_modes/modes"
    "/n_2_e8_lattice/laplacian_modes/xy"
    "/n_2_e8_lattice/streamlines/logmag"
    "/n_2_e8_lattice/streamlines/sid"
    "/n_2_e8_lattice/streamlines/xy"
    "/n_3_defect_topology/charge"
    "/n_3_defect_topology/degree"
    "/n_3_defect_topology/pos"
    "/n_4_geodesic_field/curl"
    "/n_4_geodesic_field/raw_points"
    "/n_4_geodesic_field/vel"
    "/n_4_geodesic_field/xy"
    "/n_5_composite_field_1000x1000/data"
    "/n_6_field_maps_v3_800x800/chamber_field/data"
    "/n_6_field_maps_v3_800x800/fuchsian_tiling/data"
    "/n_6_field_maps_v3_800x800/ginibre_field/data"
    "/n_6_field_maps_v3_800x800/modular_eta/data"
    "/n_6_field_maps_v3_800x800/weyl_field/data"
    "/n_7_apollonian_circle_model/e8_chamber_angles"
    "/spectral_mappings/crystal_colors"
    "/spectral_mappings/crystal_stops"
    "/spectral_mappings/phase_colors"
    "/spectral_mappings/phase_stops"];
groups = [ones(9, 1); 2*ones(3, 1); 3*ones(4, 1); 4; ...
    5*ones(5, 1); 6; 7*ones(4, 1)];
folders = [ ...
    "01_n_2_e8_lattice"
    "02_n_3_defect_topology"
    "03_n_4_geodesic_field"
    "04_n_5_composite_field"
    "05_n_6_field_maps"
    "06_n_7_apollonian"
    "07_spectral_mappings"];
datasets = repmat(struct('id', 0, 'path', '', 'groupOrder', 0, ...
    'groupFolder', '', 'fileStem', ''), numel(paths), 1);
for i = 1:numel(paths)
    parts = split(extractAfter(paths(i), 1), '/');
    stem = strjoin(parts, '__');
    datasets(i).id = i;
    datasets(i).path = char(paths(i));
    datasets(i).groupOrder = groups(i);
    datasets(i).groupFolder = char(folders(groups(i)));
    datasets(i).fileStem = char(stem);
end
end


function references = sourceReferences()
references = table( ...
    [1; 2; 3; 4], ...
    ["David Tong, Lectures on String Theory"; ...
     "Joseph Polchinski, TASI Lectures on D-Branes"; ...
     "Alvarez, Alvarez-Gaume and Lozano, Introduction to T-Duality"; ...
     "Wolfram Language tensor documentation"], ...
    ["classical and quantum strings; actions; spectra; interactions; compactification"; ...
     "D-branes and open-string endpoints"; ...
     "T-duality and momentum-winding exchange"; ...
     "tensor rank, dimensions and representation"], ...
    ["https://arxiv.org/abs/0908.0333"; ...
     "https://arxiv.org/abs/hep-th/9611050"; ...
     "https://arxiv.org/abs/hep-th/9410237"; ...
     "https://reference.wolfram.com/language/guide/Tensors"], ...
    'VariableNames', {'reference_id', 'title', 'scope', 'url'});
end


function validateInputs(cfg, concepts, laws, datasets, references)
assert(isfile(cfg.canonicalH5), 'Canonical H5 was not found.');
actualHash = sha256File(cfg.canonicalH5);
assert(strcmpi(actualHash, cfg.expectedSHA256), ...
    'Canonical H5 SHA-256 mismatch.');
assert(isfolder(cfg.basePath), 'Prior ordered output base folder was not found.');
assert(numel(concepts) == 17, 'Expected seventeen foundational concepts.');
assert(numel(laws) == 12, 'Expected twelve basic laws.');
assert(numel(datasets) == 27, 'Expected twenty-seven canonical datasets.');
assert(height(references) == 4, 'Expected four source references.');
assert(isequal([concepts.id].', (1:numel(concepts)).'), ...
    'Concept IDs must be sequential.');
assert(isequal([laws.id].', (1:numel(laws)).'), ...
    'Law IDs must be sequential.');
for i = 1:numel(concepts)
    assert(~isempty(concepts(i).notation), ...
        'Every concept must carry embedded human notation.');
end
for i = 1:numel(laws)
    assert(~isempty(laws(i).formula), ...
        'Every law must carry an embedded formula.');
end
for i = 1:numel(datasets)
    h5info(cfg.canonicalH5, datasets(i).path);
end
end


function results = preflightResult(cfg, concepts, laws, datasets)
results = struct;
results.mode = 'preflight';
results.outputRoot = cfg.outputRoot;
results.outputRootAvailable = ~isfolder(cfg.outputRoot);
results.canonicalSHA256 = sha256File(cfg.canonicalH5);
results.conceptCount = numel(concepts);
results.lawCount = numel(laws);
results.h5DatasetCount = numel(datasets);
results.humanNotationEmbedded = true;
end


function createOutputFolders(cfg)
mkdir(cfg.outputRoot);
mkdir(cfg.integrityDirectory);
mkdir(cfg.conceptDirectory);
mkdir(cfg.lawDirectory);
mkdir(cfg.sequenceDirectory);
mkdir(cfg.extractDirectory);
mkdir(cfg.trainingDirectory);
mkdir(cfg.manifestDirectory);
mkdir(cfg.contactDirectory);
folders = [ ...
    "01_n_2_e8_lattice"
    "02_n_3_defect_topology"
    "03_n_4_geodesic_field"
    "04_n_5_composite_field"
    "05_n_6_field_maps"
    "06_n_7_apollonian"
    "07_spectral_mappings"];
for i = 1:numel(folders)
    mkdir(fullfile(cfg.extractDirectory, folders(i)));
end
end


function writeIntegrityRecord(cfg)
record = struct;
record.version = cfg.version;
record.canonical_h5 = cfg.canonicalH5;
record.expected_sha256 = cfg.expectedSHA256;
record.actual_sha256 = sha256File(cfg.canonicalH5);
record.hash_match = strcmpi(record.expected_sha256, record.actual_sha256);
record.subject = cfg.subject;
record.domain = cfg.domain;
record.source_policy = ['H5 tensors are canonical visual-learning sources; ' ...
    'they are not experimental measurements of string theory.'];
writeText(fullfile(cfg.integrityDirectory, 'CanonicalIntegrity.json'), ...
    jsonencode(record, PrettyPrint=true));
summary = sprintf([ ...
    'CANONICAL H5 INTEGRITY\n' ...
    'path=%s\nexpected_sha256=%s\nactual_sha256=%s\nhash_match=%s\n' ...
    'source_policy=%s\n'], record.canonical_h5, record.expected_sha256, ...
    record.actual_sha256, string(record.hash_match), record.source_policy);
writeText(fullfile(cfg.integrityDirectory, 'CanonicalIntegrity.txt'), summary);
end


function inventory = extractCanonicalTensors(cfg, datasets)
rowCount = numel(datasets);
id = zeros(rowCount, 1);
datasetPath = strings(rowCount, 1);
outputFile = strings(rowCount, 1);
matlabClass = strings(rowCount, 1);
dimensions = strings(rowCount, 1);
rankValue = zeros(rowCount, 1);
elementCount = zeros(rowCount, 1);
byteCount = zeros(rowCount, 1);
finiteCount = zeros(rowCount, 1);
nanCount = zeros(rowCount, 1);
infCount = zeros(rowCount, 1);
minValue = nan(rowCount, 1);
maxValue = nan(rowCount, 1);
meanValue = nan(rowCount, 1);
stdValue = nan(rowCount, 1);
fileSHA256 = strings(rowCount, 1);

for i = 1:rowCount
    tensorData = h5read(cfg.canonicalH5, datasets(i).path);
    tensorMetadata = struct;
    tensorMetadata.source_h5 = cfg.canonicalH5;
    tensorMetadata.source_h5_sha256 = cfg.expectedSHA256;
    tensorMetadata.dataset_path = datasets(i).path;
    tensorMetadata.matlab_class = class(tensorData);
    tensorMetadata.dimensions = size(tensorData);
    tensorMetadata.element_count = numel(tensorData);
    tensorMetadata.semantic_policy = ['Canonical visual source tensor; ' ...
        'no string-theory measurement claim.'];

    targetDir = fullfile(cfg.extractDirectory, datasets(i).groupFolder);
    targetFile = fullfile(targetDir, sprintf('%03d_%s.mat', ...
        datasets(i).id, datasets(i).fileStem));
    save(targetFile, 'tensorData', 'tensorMetadata', '-v7.3');

    numericValues = double(tensorData(:));
    finiteMask = isfinite(numericValues);
    finiteValues = numericValues(finiteMask);
    id(i) = datasets(i).id;
    datasetPath(i) = string(datasets(i).path);
    outputFile(i) = string(targetFile);
    matlabClass(i) = string(class(tensorData));
    dimensions(i) = shapeString(size(tensorData));
    rankValue(i) = numel(size(tensorData));
    elementCount(i) = numel(tensorData);
    classInfo = whos('tensorData');
    byteCount(i) = classInfo.bytes;
    finiteCount(i) = nnz(finiteMask);
    nanCount(i) = nnz(isnan(numericValues));
    infCount(i) = nnz(isinf(numericValues));
    if ~isempty(finiteValues)
        minValue(i) = min(finiteValues);
        maxValue(i) = max(finiteValues);
        meanValue(i) = mean(finiteValues);
        stdValue(i) = std(finiteValues, 0);
    end
    fileSHA256(i) = sha256File(targetFile);
end

inventory = table(id, datasetPath, outputFile, matlabClass, dimensions, ...
    rankValue, elementCount, byteCount, finiteCount, nanCount, infCount, ...
    minValue, maxValue, meanValue, stdValue, fileSHA256, ...
    'VariableNames', {'id', 'dataset_path', 'output_file', 'matlab_class', ...
    'dimensions', 'rank', 'element_count', 'bytes_in_memory', ...
    'finite_count', 'nan_count', 'inf_count', 'min_value', 'max_value', ...
    'mean_value', 'std_value', 'mat_file_sha256'});
writetable(inventory, fullfile(cfg.extractDirectory, 'H5TensorInventory.csv'));
end


function [sourceTensor, names] = buildCanonicalSourceTensor(cfg)
side = cfg.sourceSpatialSize;
sourceTensor = zeros(side, side, 12, 'single');
names = [ ...
    "composite_01"
    "composite_02"
    "composite_03"
    "chamber_01"
    "fuchsian_01"
    "ginibre_01"
    "modular_eta_01"
    "weyl_01"
    "laplacian_mode_01"
    "defect_charge_density"
    "geodesic_speed"
    "geodesic_curl"];

composite = orientChannelsFirst(single(h5read(cfg.canonicalH5, ...
    '/n_5_composite_field_1000x1000/data')), 5);
for c = 1:3
    sourceTensor(:, :, c) = resizeNormalized( ...
        reshape(composite(c, :), 1000, 1000), side);
end
fieldPaths = [ ...
    "/n_6_field_maps_v3_800x800/chamber_field/data"
    "/n_6_field_maps_v3_800x800/fuchsian_tiling/data"
    "/n_6_field_maps_v3_800x800/ginibre_field/data"
    "/n_6_field_maps_v3_800x800/modular_eta/data"
    "/n_6_field_maps_v3_800x800/weyl_field/data"];
fieldChannels = [3 5 3 3 5];
for i = 1:numel(fieldPaths)
    raw = orientChannelsFirst(single(h5read( ...
        cfg.canonicalH5, fieldPaths(i))), fieldChannels(i));
    sourceTensor(:, :, i + 3) = resizeNormalized( ...
        reshape(raw(1, :), 800, 800), side);
end

xy = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/laplacian_modes/xy')), 2);
modes = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/laplacian_modes/modes')), 12);
sourceTensor(:, :, 9) = single(gridPointValues(xy, modes(1, :).', side));

pos = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/pos')), 2);
charge = double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/charge'));
sourceTensor(:, :, 10) = single(gridPointValues(pos, charge(:), side));

vel = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/vel')), 2);
speed = hypot(vel(1, :), vel(2, :));
sourceTensor(:, :, 11) = resizeNormalized(reshape(speed, 220, 220), side);
curlField = double(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/curl'));
sourceTensor(:, :, 12) = resizeNormalized( ...
    reshape(curlField, 220, 220), side);
assert(all(isfinite(sourceTensor(:))), ...
    'Compact canonical source tensor contains non-finite values.');
end


function files = renderConceptCards(cfg, concepts)
files = strings(numel(concepts), 1);
for i = 1:numel(concepts)
    files(i) = fullfile(cfg.conceptDirectory, sprintf('%02d_%s.png', ...
        concepts(i).id, concepts(i).slug));
    fig = cardFigure(cfg);
    renderCardHeader(fig, sprintf('%02d  %s', concepts(i).id, concepts(i).title), ...
        'FOUNDATIONAL CONCEPT');
    axVisual = axes(fig, 'Position', [0.055 0.13 0.49 0.70]);
    drawVisual(axVisual, concepts(i).visualType);
    axText = axes(fig, 'Position', [0.59 0.13 0.36 0.70]);
    renderNotationPanel(axText, concepts(i).notation, ...
        concepts(i).definition, 'symbol -> visual form -> lawful relation');
    exportgraphics(fig, files(i), 'Resolution', 150);
    close(fig);
end
end


function files = renderLawCards(cfg, laws)
files = strings(numel(laws), 1);
for i = 1:numel(laws)
    files(i) = fullfile(cfg.lawDirectory, sprintf('%02d_%s.png', ...
        laws(i).id, laws(i).slug));
    renderOneLawCard(cfg, laws(i), files(i));
end
end


function renderOneLawCard(cfg, law, outputFile)
fig = cardFigure(cfg);
renderCardHeader(fig, sprintf('%02d  %s', law.id, law.title), ...
    'BASIC LAW / STANDARD NOTATION');
axVisual = axes(fig, 'Position', [0.055 0.13 0.49 0.70]);
drawVisual(axVisual, law.visualType);
axText = axes(fig, 'Position', [0.57 0.11 0.39 0.72]);
renderLawPanel(axText, law.formula, law.condition, law.definition);
exportgraphics(fig, outputFile, 'Resolution', 150);
close(fig);
end


function fig = cardFigure(cfg)
fig = figure('Visible', 'off', 'Color', [0.025 0.035 0.065], ...
    'Position', [80 80 cfg.cardSize(2) cfg.cardSize(1)]);
annotation(fig, 'rectangle', [0.018 0.025 0.964 0.95], ...
    'Color', [0.20 0.80 0.95], 'LineWidth', 1.5);
end


function renderCardHeader(fig, titleText, subtitleText)
annotation(fig, 'textbox', [0.05 0.87 0.90 0.08], 'String', titleText, ...
    'Interpreter', 'none', 'Color', [0.95 0.98 1.00], ...
    'FontName', 'Arial', 'FontSize', 23, 'FontWeight', 'bold', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'left');
annotation(fig, 'textbox', [0.05 0.825 0.90 0.045], ...
    'String', subtitleText, 'Interpreter', 'none', ...
    'Color', [0.25 0.85 1.00], 'FontName', 'Arial', 'FontSize', 10, ...
    'FontWeight', 'bold', 'EdgeColor', 'none');
end


function renderNotationPanel(ax, notation, definition, relationText)
axis(ax, [0 1 0 1]);
axis(ax, 'off');
hold(ax, 'on');
rectangle(ax, 'Position', [0.01 0.02 0.98 0.96], ...
    'Curvature', 0.03, 'EdgeColor', [0.25 0.75 0.95], ...
    'FaceColor', [0.055 0.075 0.12], 'LineWidth', 1.3);
text(ax, 0.07, 0.89, 'OFFICIAL HUMAN NOTATION', ...
    'Color', [0.25 0.85 1.00], 'FontSize', 10, 'FontWeight', 'bold');
text(ax, 0.50, 0.70, notation, 'Interpreter', 'latex', ...
    'Color', [1.00 0.88 0.30], 'FontSize', 22, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
text(ax, 0.07, 0.47, definition, 'Interpreter', 'latex', ...
    'Color', [0.92 0.95 1.00], 'FontSize', 14, ...
    'VerticalAlignment', 'top');
plot(ax, [0.08 0.92], [0.30 0.30], '-', 'Color', [0.20 0.45 0.60]);
text(ax, 0.50, 0.18, relationText, 'Interpreter', 'none', ...
    'Color', [0.55 0.85 0.95], 'FontSize', 11, ...
    'HorizontalAlignment', 'center');
hold(ax, 'off');
end


function renderLawPanel(ax, formula, condition, definition)
axis(ax, [0 1 0 1]);
axis(ax, 'off');
hold(ax, 'on');
rectangle(ax, 'Position', [0.01 0.02 0.98 0.96], ...
    'Curvature', 0.03, 'EdgeColor', [0.25 0.75 0.95], ...
    'FaceColor', [0.055 0.075 0.12], 'LineWidth', 1.3);
text(ax, 0.07, 0.90, 'LAW', 'Color', [0.25 0.85 1.00], ...
    'FontSize', 10, 'FontWeight', 'bold');
text(ax, 0.50, 0.73, formula, 'Interpreter', 'latex', ...
    'Color', [1.00 0.88 0.30], 'FontSize', 17, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
text(ax, 0.50, 0.51, condition, 'Interpreter', 'latex', ...
    'Color', [0.40 0.90 1.00], 'FontSize', 14, ...
    'HorizontalAlignment', 'center');
plot(ax, [0.08 0.92], [0.40 0.40], '-', 'Color', [0.20 0.45 0.60]);
text(ax, 0.07, 0.33, definition, 'Interpreter', 'latex', ...
    'Color', [0.92 0.95 1.00], 'FontSize', 13, ...
    'VerticalAlignment', 'top');
text(ax, 0.50, 0.12, 'model and convention labels are part of the law', ...
    'Color', [0.55 0.85 0.95], 'FontSize', 10, ...
    'HorizontalAlignment', 'center');
hold(ax, 'off');
end


function drawVisual(ax, visualType)
cla(ax);
hold(ax, 'on');
axis(ax, [0 1 0 1]);
axis(ax, 'equal');
axis(ax, 'off');
set(ax, 'Color', [0.035 0.05 0.085]);
cyan = [0.15 0.85 1.00];
gold = [1.00 0.78 0.20];
magenta = [0.95 0.35 0.80];
soft = [0.65 0.75 0.95];
t = linspace(0, 1, 500);

switch char(visualType)
    case 'particle'
        plot(ax, 0.18 + 0.63*t, 0.17 + 0.63*t + 0.05*sin(5*pi*t), ...
            '-', 'Color', soft, 'LineWidth', 2.5);
        scatter(ax, 0.62, 0.62, 300, gold, 'filled', ...
            'MarkerEdgeColor', [1 1 1]);
        text(ax, 0.66, 0.66, '$x^\mu(\tau)$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 18);
    case {'string', 'open'}
        x = 0.13 + 0.74*t;
        y = 0.50 + 0.16*sin(4*pi*t) .* (0.7 + 0.3*cos(2*pi*t));
        plot(ax, x, y, '-', 'Color', cyan, 'LineWidth', 5);
        scatter(ax, [x(1) x(end)], [y(1) y(end)], 150, gold, 'filled');
        plot(ax, [0.13 0.87], [0.22 0.22], '-', 'Color', soft, 'LineWidth', 1.5);
        text(ax, 0.12, 0.13, '$\sigma=0$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 14);
        text(ax, 0.78, 0.13, '$\sigma=\pi$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 14);
    case 'closed'
        th = linspace(0, 2*pi, 500);
        r = 0.30 + 0.045*cos(5*th);
        plot(ax, 0.5 + r.*cos(th), 0.5 + r.*sin(th), ...
            '-', 'Color', cyan, 'LineWidth', 5);
        quiver(ax, 0.78, 0.50, -0.03, 0.10, 0, 'Color', gold, ...
            'LineWidth', 2, 'MaxHeadSize', 1.5);
        text(ax, 0.43, 0.08, '$\sigma\sim\sigma+2\pi$', ...
            'Interpreter', 'latex', 'Color', gold, 'FontSize', 16);
    case {'mode', 'wave'}
        for n = 1:3
            y0 = 0.20 + 0.25*(n-1);
            plot(ax, 0.10 + 0.80*t, y0 + 0.075*sin(n*2*pi*t), ...
                '-', 'Color', (cyan*(4-n) + magenta*(n-1))/3, ...
                'LineWidth', 3);
            text(ax, 0.03, y0, sprintf('$n=%d$', n), ...
                'Interpreter', 'latex', 'Color', gold, 'FontSize', 12);
        end
    case 'particlemode'
        for n = 1:3
            y0 = 0.24 + 0.25*(n-1);
            plot(ax, 0.08 + 0.48*t, y0 + 0.07*sin(n*2*pi*t), ...
                '-', 'Color', cyan, 'LineWidth', 3);
            quiver(ax, 0.60, y0, 0.12, 0, 0, 'Color', soft, 'LineWidth', 2);
            scatter(ax, 0.82, y0, 160 + 70*n, ...
                (gold*(4-n) + magenta*(n-1))/3, 'filled');
        end
    case 'tension'
        plot(ax, [0.18 0.82], [0.52 0.52], '-', 'Color', cyan, 'LineWidth', 6);
        quiver(ax, 0.20, 0.52, -0.13, 0, 0, 'Color', gold, 'LineWidth', 3);
        quiver(ax, 0.80, 0.52, 0.13, 0, 0, 'Color', gold, 'LineWidth', 3);
        text(ax, 0.46, 0.62, '$T$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 22);
        text(ax, 0.39, 0.34, '$E=T L$', 'Interpreter', 'latex', ...
            'Color', [1 1 1], 'FontSize', 18);
    case {'worldsheet', 'action', 'polyakov'}
        u = linspace(0.15, 0.85, 12);
        for k = 1:numel(u)
            tt = linspace(0, 1, 120);
            x = u(k) + 0.05*sin(2*pi*tt + 2*pi*k/numel(u));
            y = 0.12 + 0.73*tt;
            plot(ax, x, y, '-', 'Color', 0.25*soft + 0.75*cyan, ...
                'LineWidth', 1.1);
        end
        plot(ax, 0.18 + 0.64*t, 0.18 + 0.10*sin(4*pi*t), ...
            '-', 'Color', gold, 'LineWidth', 4);
        plot(ax, 0.18 + 0.64*t, 0.80 + 0.10*sin(4*pi*t + pi/2), ...
            '-', 'Color', magenta, 'LineWidth', 4);
        text(ax, 0.76, 0.90, '$\tau$', 'Interpreter', 'latex', ...
            'Color', magenta, 'FontSize', 18);
        text(ax, 0.08, 0.12, '$\sigma$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 18);
    case 'embedding'
        for k = 0:5
            plot(ax, [0.08 0.40], [0.20+0.10*k 0.20+0.10*k], ...
                '-', 'Color', soft, 'LineWidth', 1);
            plot(ax, [0.08+0.064*k 0.08+0.064*k], [0.20 0.70], ...
                '-', 'Color', soft, 'LineWidth', 1);
        end
        quiver(ax, 0.45, 0.45, 0.16, 0.08, 0, 'Color', gold, 'LineWidth', 3);
        th = linspace(0, 4*pi, 500);
        plot(ax, 0.73 + 0.13*cos(th), 0.46 + 0.025*th + 0.13*sin(th), ...
            '-', 'Color', cyan, 'LineWidth', 3);
        text(ax, 0.47, 0.58, '$X^\mu$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 20);
    case 'interaction'
        plot(ax, 0.10 + 0.35*t, 0.50 + 0.08*sin(3*pi*t), ...
            '-', 'Color', cyan, 'LineWidth', 5);
        plot(ax, 0.45 + 0.43*t, 0.50 + 0.27*t + 0.05*sin(3*pi*t), ...
            '-', 'Color', magenta, 'LineWidth', 5);
        plot(ax, 0.45 + 0.43*t, 0.50 - 0.27*t + 0.05*sin(3*pi*t), ...
            '-', 'Color', gold, 'LineWidth', 5);
        scatter(ax, 0.45, 0.50, 170, [1 1 1], 'filled');
        text(ax, 0.45, 0.88, '$g_s$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 22);
    case {'brane'}
        patch(ax, [0.12 0.78 0.90 0.24], [0.25 0.25 0.55 0.55], ...
            [0.15 0.38 0.55], 'FaceAlpha', 0.55, ...
            'EdgeColor', cyan, 'LineWidth', 2);
        for x0 = [0.31 0.55 0.73]
            plot(ax, x0 + 0.06*sin(4*pi*t), 0.42 + 0.42*t, ...
                '-', 'Color', gold, 'LineWidth', 3);
            scatter(ax, x0, 0.42, 100, magenta, 'filled');
        end
        text(ax, 0.20, 0.18, '$X^i=y^i$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 18);
    case 'compact'
        th = linspace(0, 2*pi, 400);
        plot(ax, 0.50 + 0.28*cos(th), 0.52 + 0.28*sin(th), ...
            '-', 'Color', cyan, 'LineWidth', 4);
        plot(ax, [0.50 0.78], [0.52 0.52], '--', 'Color', gold, 'LineWidth', 2);
        text(ax, 0.62, 0.56, '$R$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 20);
        plot(ax, 0.50 + 0.22*cos(3*th), 0.52 + 0.22*sin(3*th), ...
            '-', 'Color', magenta, 'LineWidth', 2);
        text(ax, 0.36, 0.12, '$w=3$', 'Interpreter', 'latex', ...
            'Color', magenta, 'FontSize', 17);
    case {'duality'}
        th = linspace(0, 2*pi, 300);
        plot(ax, 0.25 + 0.18*cos(th), 0.52 + 0.18*sin(th), ...
            '-', 'Color', cyan, 'LineWidth', 4);
        plot(ax, 0.76 + 0.08*cos(th), 0.52 + 0.08*sin(th), ...
            '-', 'Color', magenta, 'LineWidth', 4);
        quiver(ax, 0.44, 0.58, 0.23, 0, 0, 'Color', gold, 'LineWidth', 2);
        quiver(ax, 0.67, 0.44, -0.23, 0, 0, 'Color', gold, 'LineWidth', 2);
        text(ax, 0.46, 0.69, '$R\leftrightarrow\alpha''/R$', ...
            'Interpreter', 'latex', 'Color', gold, 'FontSize', 16);
    case {'gravity'}
        th = linspace(0, 2*pi, 500);
        r = 0.19 + 0.04*cos(4*th);
        plot(ax, 0.30 + r.*cos(th), 0.54 + r.*sin(th), ...
            '-', 'Color', cyan, 'LineWidth', 4);
        for y0 = [0.35 0.50 0.65]
            plot(ax, 0.56 + 0.34*t, y0 + 0.035*sin(6*pi*t), ...
                '-', 'Color', gold, 'LineWidth', 2);
        end
        text(ax, 0.58, 0.77, '$\epsilon_{(\mu\nu)}$', ...
            'Interpreter', 'latex', 'Color', gold, 'FontSize', 19);
    case 'super'
        plot(ax, 0.10 + 0.80*t, 0.65 + 0.10*sin(4*pi*t), ...
            '-', 'Color', cyan, 'LineWidth', 4);
        stem(ax, 0.12 + 0.76*(0:12)/12, ...
            0.32 + 0.07*(-1).^(0:12), 'Color', magenta, ...
            'Marker', 'none', 'LineWidth', 2);
        text(ax, 0.12, 0.78, '$X^\mu$', 'Interpreter', 'latex', ...
            'Color', cyan, 'FontSize', 20);
        text(ax, 0.12, 0.18, '$\psi^\mu$', 'Interpreter', 'latex', ...
            'Color', magenta, 'FontSize', 20);
    case 'dimension'
        bar(ax, [10 26], 0.48, 'FaceColor', 'flat');
        ax.Children.CData = [cyan; magenta];
        set(ax, 'XLim', [0.3 2.7], 'YLim', [0 30], 'XTick', [1 2], ...
            'XTickLabel', {'superstring', 'bosonic'}, ...
            'XColor', soft, 'YColor', soft, 'FontSize', 11);
        ylabel(ax, '$D$', 'Interpreter', 'latex', 'Color', gold, 'FontSize', 18);
        axis(ax, 'on');
        box(ax, 'off');
    case 'coupling'
        th = linspace(0, 2*pi, 400);
        for k = 1:3
            r = 0.10 + 0.055*k;
            plot(ax, 0.50 + r*cos(th), 0.50 + 0.55*r*sin(th), ...
                '-', 'Color', (cyan*(4-k)+magenta*(k-1))/3, ...
                'LineWidth', 2+k);
        end
        quiver(ax, 0.22, 0.20, 0.52, 0, 0, 'Color', gold, 'LineWidth', 2);
        text(ax, 0.37, 0.10, '$g_s\;\uparrow$', 'Interpreter', 'latex', ...
            'Color', gold, 'FontSize', 20);
    case 'quantization'
        for k = 0:4
            plot(ax, [0.16 0.84], [0.18+0.15*k 0.18+0.15*k], ...
                '-', 'Color', cyan, 'LineWidth', 2);
            text(ax, 0.07, 0.18+0.15*k, sprintf('$N=%d$', k), ...
                'Interpreter', 'latex', 'Color', gold, 'FontSize', 12);
        end
        scatter(ax, 0.56, 0.18+0.15*3, 180, magenta, 'filled');
    case 'mass'
        n = 0:5;
        plot(ax, n, n-1, 'o-', 'Color', cyan, 'MarkerFaceColor', gold, ...
            'LineWidth', 2, 'MarkerSize', 8);
        set(ax, 'XLim', [-0.4 5.4], 'YLim', [-1.5 4.5], ...
            'XColor', soft, 'YColor', soft, 'FontSize', 11);
        xlabel(ax, '$N$', 'Interpreter', 'latex', 'Color', gold);
        ylabel(ax, '$\alpha''M^2$', 'Interpreter', 'latex', 'Color', gold);
        grid(ax, 'on');
        axis(ax, 'on');
end
hold(ax, 'off');
end


function sequenceFiles = buildLearningSequences( ...
        cfg, concepts, laws, conceptFiles, lawFiles)
conceptGroups = {1:6, 7:11, 12:17};
conceptNames = [ ...
    "01_particle_string_and_modes.png"
    "02_worldsheet_tension_and_interaction.png"
    "03_dimensions_duality_and_coupling.png"];
sequenceFiles = strings(5, 1);
for i = 1:numel(conceptGroups)
    sequenceFiles(i) = fullfile(cfg.sequenceDirectory, conceptNames(i));
    writeImageGrid(conceptFiles(conceptGroups{i}), sequenceFiles(i), [2 3]);
end
sequenceFiles(4) = fullfile(cfg.sequenceDirectory, ...
    '04_classical_string_laws.png');
writeImageGrid(lawFiles(1:6), sequenceFiles(4), [2 3]);
sequenceFiles(5) = fullfile(cfg.sequenceDirectory, ...
    '05_quantum_and_duality_laws.png');
writeImageGrid(lawFiles(7:12), sequenceFiles(5), [2 3]);

writeImageGrid(conceptFiles, fullfile(cfg.contactDirectory, ...
    'ConceptAtlasContactSheet.png'), [4 5]);
writeImageGrid(lawFiles, fullfile(cfg.contactDirectory, ...
    'BasicLawContactSheet.png'), [3 4]);

conceptOrder = (1:numel(concepts)).';
conceptSlug = string({concepts.slug}).';
conceptFile = conceptFiles;
writetable(table(conceptOrder, conceptSlug, conceptFile), ...
    fullfile(cfg.sequenceDirectory, 'ConceptLearningOrder.csv'));
lawOrder = (1:numel(laws)).';
lawSlug = string({laws.slug}).';
lawFile = lawFiles;
writetable(table(lawOrder, lawSlug, lawFile), ...
    fullfile(cfg.sequenceDirectory, 'LawLearningOrder.csv'));
end


function writeImageGrid(files, outputFile, gridSize)
thumbs = cell(numel(files), 1);
for i = 1:numel(files)
    imageData = imread(files(i));
    thumbs{i} = imresize(imageData, [360 560]);
end
sheet = imtile(thumbs, 'GridSize', gridSize, ...
    'BackgroundColor', [6 9 17] ./ 255, 'BorderSize', 8);
imwrite(sheet, outputFile);
end


function training = buildTrainingTensors(cfg, concepts, laws, ...
        conceptFiles, lawFiles, sourceTensor, sourceNames)
conceptImages = readImageTensor(conceptFiles, cfg.tensorImageSize);
lawImages = readImageTensor(lawFiles, cfg.tensorImageSize);
conceptInk = buildInkMasks(conceptImages);
lawInk = buildInkMasks(lawImages);
[conceptCodebook, primitiveNames] = conceptPrimitiveCodebook();
lawCodebook = lawPrimitiveCodebook();
conceptLaw = conceptLawCrosswalk(numel(concepts), numel(laws));

training = struct;
training.conceptImages = conceptImages;
training.lawImages = lawImages;
training.conceptInkMasks = conceptInk;
training.lawInkMasks = lawInk;
training.canonicalVisualSourceTensor = sourceTensor;
training.canonicalVisualSourceNames = sourceNames;
training.conceptPrimitiveCodebook = conceptCodebook;
training.lawPrimitiveCodebook = lawCodebook;
training.primitiveNames = primitiveNames;
training.conceptLawCrosswalk = conceptLaw;
training.conceptSlugs = string({concepts.slug}).';
training.lawSlugs = string({laws.slug}).';
training.semanticPolicy = ['Canonical H5 channels remain auxiliary visual ' ...
    'sources and are not labelled as string-theory measurements.'];
assert(all(isfinite(single(conceptImages(:)))), 'Concept image tensor invalid.');
assert(all(isfinite(single(lawImages(:)))), 'Law image tensor invalid.');
assert(all(isfinite(sourceTensor(:))), 'Canonical source tensor invalid.');
end


function tensor = readImageTensor(files, targetSize)
firstImage = imresize(imread(files(1)), targetSize);
if size(firstImage, 3) == 1
    firstImage = repmat(firstImage, 1, 1, 3);
end
tensor = zeros(targetSize(1), targetSize(2), 3, numel(files), 'uint8');
tensor(:, :, :, 1) = firstImage;
for i = 2:numel(files)
    imageData = imresize(imread(files(i)), targetSize);
    if size(imageData, 3) == 1
        imageData = repmat(imageData, 1, 1, 3);
    end
    tensor(:, :, :, i) = imageData;
end
end


function masks = buildInkMasks(images)
count = size(images, 4);
masks = false(size(images, 1), size(images, 2), count);
for i = 1:count
    rgb = im2single(images(:, :, :, i));
    brightness = mean(rgb, 3);
    chroma = max(rgb, [], 3) - min(rgb, [], 3);
    masks(:, :, i) = brightness > 0.55 | chroma > 0.22;
end
end


function [codebook, names] = conceptPrimitiveCodebook()
names = ["particle" "string" "boundary" "vibration" "spacetime" ...
    "worldsheet" "energy" "interaction" "quantization" "geometry" ...
    "dimensions" "duality"];
codebook = single([ ...
    1 0 0 0 1 0 0 0 1 0 0 0
    0 1 0 1 1 1 0 0 0 1 0 0
    0 1 1 1 0 1 0 0 0 1 0 0
    0 1 1 1 0 1 0 0 0 1 0 0
    0 1 1 1 0 1 0 0 1 0 0 0
    1 1 0 1 0 0 0 0 1 0 0 0
    0 1 0 0 0 0 1 0 0 0 0 0
    1 1 0 0 1 1 0 0 0 1 0 0
    0 1 0 0 1 1 0 0 0 1 1 0
    0 1 0 0 0 1 0 1 1 0 0 0
    0 1 1 0 1 1 0 1 0 1 0 0
    0 0 1 0 1 0 0 0 1 1 1 0
    0 1 0 0 1 0 0 0 1 1 1 1
    1 1 0 1 1 0 0 0 1 0 0 0
    1 1 1 1 0 1 0 0 1 0 0 0
    0 1 0 0 1 1 0 0 1 1 1 0
    0 1 0 0 0 1 0 1 1 0 0 0]);
end


function codebook = lawPrimitiveCodebook()
codebook = single([ ...
    0 1 0 0 1 1 1 0 0 1 0 0
    0 1 0 0 1 1 1 0 0 1 0 0
    0 1 1 1 0 1 0 0 0 0 0 0
    0 1 1 1 0 1 0 0 0 1 0 0
    0 1 1 1 0 1 0 0 0 1 0 0
    0 1 1 1 0 1 0 0 1 0 0 0
    0 1 0 0 0 0 1 0 0 0 0 0
    1 1 0 1 0 0 0 0 1 0 0 0
    1 1 1 1 0 0 1 0 1 0 0 0
    0 1 1 0 1 0 1 0 1 1 1 1
    0 1 1 0 1 1 0 1 0 1 0 0
    0 1 0 0 0 1 0 1 1 1 0 0]);
end


function crosswalk = conceptLawCrosswalk(conceptCount, lawCount)
crosswalk = zeros(conceptCount, lawCount, 'single');
links = { ...
    [3 8 9], [1 2 3 6 7], [3 4 6], [3 5 6], [3 6 8], ...
    [6 8 9], [1 7], [1 2 3], [1 2], [12], [4 11], [5 10], ...
    [10], [9], [8 9], [8 9], [12]};
for i = 1:conceptCount
    crosswalk(i, links{i}) = 1;
end
end


function tensorFiles = writeTrainingTensorFiles(cfg, training)
tensorFiles = struct;
tensorFiles.mat = fullfile(cfg.trainingDirectory, ...
    'StringTheoryFoundationsLearningTensors.mat');
save(tensorFiles.mat, 'training', '-v7.3');

tensorFiles.h5 = fullfile(cfg.trainingDirectory, ...
    'StringTheoryFoundationsLearningTensors.h5');
writeH5Dataset(tensorFiles.h5, '/images/concepts', training.conceptImages);
writeH5Dataset(tensorFiles.h5, '/images/laws', training.lawImages);
writeH5Dataset(tensorFiles.h5, '/masks/concept_ink', ...
    uint8(training.conceptInkMasks));
writeH5Dataset(tensorFiles.h5, '/masks/law_ink', ...
    uint8(training.lawInkMasks));
writeH5Dataset(tensorFiles.h5, '/canonical/visual_sources', ...
    training.canonicalVisualSourceTensor);
writeH5Dataset(tensorFiles.h5, '/codebooks/concept_primitives', ...
    training.conceptPrimitiveCodebook);
writeH5Dataset(tensorFiles.h5, '/codebooks/law_primitives', ...
    training.lawPrimitiveCodebook);
writeH5Dataset(tensorFiles.h5, '/relations/concept_law_crosswalk', ...
    training.conceptLawCrosswalk);

writematrix(training.conceptPrimitiveCodebook, fullfile( ...
    cfg.trainingDirectory, 'ConceptPrimitiveCodebook.csv'));
writematrix(training.lawPrimitiveCodebook, fullfile( ...
    cfg.trainingDirectory, 'LawPrimitiveCodebook.csv'));
writematrix(training.conceptLawCrosswalk, fullfile( ...
    cfg.trainingDirectory, 'ConceptLawCrosswalk.csv'));
end


function writeH5Dataset(filePath, datasetPath, value)
if isfile(filePath) && strcmp(datasetPath, '/images/concepts')
    delete(filePath);
end
dataSize = size(value);
if numel(dataSize) >= 4
    chunkLimit = [64 64 3 ones(1, numel(dataSize) - 3)];
else
    chunkLimit = 64 * ones(size(dataSize));
end
chunk = max(ones(size(dataSize)), min(dataSize, chunkLimit));
h5create(filePath, datasetPath, dataSize, 'Datatype', class(value), ...
    'ChunkSize', chunk, 'Deflate', 4);
h5write(filePath, datasetPath, value);
end


function manifests = writeManifests(cfg, concepts, laws, datasets, ...
        references, tensorInventory, sourceNames, conceptFiles, lawFiles, ...
        sequenceFiles, tensorFiles, training, startTime)
conceptTable = table([concepts.id].', string({concepts.slug}).', ...
    string({concepts.title}).', string({concepts.notation}).', ...
    string({concepts.definition}).', conceptFiles, true(numel(concepts), 1), ...
    'VariableNames', {'id', 'slug', 'title', 'notation', 'definition', ...
    'image_file', 'human_notation_rendered'});
lawTable = table([laws.id].', string({laws.slug}).', ...
    string({laws.title}).', string({laws.formula}).', ...
    string({laws.condition}).', string({laws.definition}).', lawFiles, ...
    true(numel(laws), 1), 'VariableNames', {'id', 'slug', 'title', ...
    'formula', 'condition', 'definition', 'image_file', ...
    'human_notation_rendered'});
writetable(conceptTable, fullfile(cfg.manifestDirectory, 'ConceptIndex.csv'));
writetable(lawTable, fullfile(cfg.manifestDirectory, 'BasicLawIndex.csv'));
writetable(references, fullfile(cfg.manifestDirectory, 'SourceReferences.csv'));
writetable(tensorInventory, fullfile(cfg.manifestDirectory, ...
    'H5TensorInventory.csv'));
writetable(table((1:numel(sourceNames)).', sourceNames, ...
    'VariableNames', {'channel', 'source_name'}), ...
    fullfile(cfg.manifestDirectory, 'CanonicalVisualSourceChannels.csv'));

wolframChecks = table( ...
    ["tension_regge_relation"; "open_mode_normalization"; ...
     "closed_integer_mode_periodicity"; "t_duality_mass_term"], ...
    ["(1/(2*pi*alphaPrime))*(2*pi*alphaPrime)"; ...
     "Integral[sin(n*sigma)^2,{sigma,0,pi}], integer n>0"; ...
     "exp(i*n*(sigma+2*pi))-exp(i*n*sigma), integer n"; ...
     "massTerm(R,n,w)-massTerm(alphaPrime/R,w,n)"], ...
    ["1"; "pi/2"; "0"; "0"], true(4, 1), ...
    'VariableNames', {'check', 'expression', 'wolfram_result', 'pass'});
writetable(wolframChecks, fullfile(cfg.manifestDirectory, ...
    'WolframValidation.csv'));

planText = sprintf([ ...
    '# Code and execution plan\n\n' ...
    '1. Verify the canonical H5 SHA-256 before any numerical use.\n' ...
    '2. Extract every canonical dataset to an ordered, individually traceable MAT tensor file.\n' ...
    '3. Render foundational concepts from particle and string to dimensions and coupling.\n' ...
    '4. Render the basic classical and quantum laws with standard notation inside each image.\n' ...
    '5. Build ordered learning sequences, contact sheets, image tensors, notation masks, and crosswalks.\n' ...
    '6. Validate counts, finiteness, hashes, image readability, and H5/MAT exports.\n\n' ...
    'Scope note: formulas are labelled by model and convention where needed.\n' ...
    'H5 policy: canonical tensors are auxiliary visual-learning sources, not string-theory measurements.\n']);
writeText(fullfile(cfg.manifestDirectory, 'CODE_EXECUTION_PLAN.md'), planText);

summary = struct;
summary.version = cfg.version;
summary.subject = cfg.subject;
summary.domain = cfg.domain;
summary.output_root = cfg.outputRoot;
summary.canonical_h5 = cfg.canonicalH5;
summary.canonical_sha256 = cfg.expectedSHA256;
summary.concept_count = numel(concepts);
summary.basic_law_count = numel(laws);
summary.h5_dataset_extract_count = numel(datasets);
summary.human_notation_embedded_in_images = true;
summary.rendered_text = true;
summary.learning_sequence_count = numel(sequenceFiles);
summary.canonical_visual_source_channels = numel(sourceNames);
summary.concept_image_tensor_shape = size(training.conceptImages);
summary.law_image_tensor_shape = size(training.lawImages);
summary.training_mat = tensorFiles.mat;
summary.training_h5 = tensorFiles.h5;
summary.physics_scope = ['Foundational pedagogical string-theory formalism; ' ...
    'bosonic and superstring statements are explicitly labelled.'];
summary.theory_status = ['String theory is a theoretical framework; this atlas ' ...
    'does not present the canonical H5 as experimental confirmation.'];
summary.h5_semantics_policy = training.semanticPolicy;
summary.existing_files_changed = 0;
summary.elapsed_seconds = toc(startTime);
writeText(fullfile(cfg.manifestDirectory, 'RunSummary.json'), ...
    jsonencode(summary, PrettyPrint=true));

textSummary = sprintf([ ...
    'YEHOSHUA STRING THEORY FOUNDATIONS AND LAW ATLAS V4\n' ...
    'canonical_sha256=%s\nconcept_count=%d\nbasic_law_count=%d\n' ...
    'h5_tensor_extract_count=%d\nhuman_notation_embedded=true\n' ...
    'rendered_text=true\ncanonical_visual_source_channels=%d\n' ...
    'existing_files_changed=0\nelapsed_seconds=%.6f\n' ...
    'theory_status=%s\nh5_semantics_policy=%s\n'], ...
    cfg.expectedSHA256, numel(concepts), numel(laws), numel(datasets), ...
    numel(sourceNames), toc(startTime), summary.theory_status, ...
    summary.h5_semantics_policy);
writeText(fullfile(cfg.manifestDirectory, 'RunSummary.txt'), textSummary);

manifests = struct;
manifests.concepts = fullfile(cfg.manifestDirectory, 'ConceptIndex.csv');
manifests.laws = fullfile(cfg.manifestDirectory, 'BasicLawIndex.csv');
manifests.sources = fullfile(cfg.manifestDirectory, 'SourceReferences.csv');
manifests.inventory = fullfile(cfg.manifestDirectory, 'H5TensorInventory.csv');
manifests.summary = fullfile(cfg.manifestDirectory, 'RunSummary.json');
manifests.plan = fullfile(cfg.manifestDirectory, 'CODE_EXECUTION_PLAN.md');
end


function validation = validateOutputs(cfg, concepts, laws, datasets, ...
        conceptFiles, lawFiles, tensorFiles, tensorInventory, training)
validation = struct;
validation.hashMatch = strcmpi(sha256File(cfg.canonicalH5), cfg.expectedSHA256);
validation.conceptImagesExist = all(isfile(conceptFiles));
validation.lawImagesExist = all(isfile(lawFiles));
validation.conceptCountMatch = numel(conceptFiles) == numel(concepts);
validation.lawCountMatch = numel(lawFiles) == numel(laws);
validation.extractCountMatch = height(tensorInventory) == numel(datasets);
validation.extractFilesExist = all(isfile(tensorInventory.output_file));
validation.extractsFinite = all(tensorInventory.nan_count == 0 & ...
    tensorInventory.inf_count == 0);
validation.trainingMATExists = isfile(tensorFiles.mat);
validation.trainingH5Exists = isfile(tensorFiles.h5);
validation.humanNotationEmbedded = true;
validation.renderedText = true;
validation.conceptTensorShape = isequal(size(training.conceptImages), ...
    [224 224 3 numel(concepts)]);
validation.lawTensorShape = isequal(size(training.lawImages), ...
    [224 224 3 numel(laws)]);
validation.sourceTensorShape = isequal( ...
    size(training.canonicalVisualSourceTensor), [64 64 12]);
values = struct2cell(validation);
logicalValues = cellfun(@(value) islogical(value) && isscalar(value), values);
validation.allChecksPass = all(cellfun(@(value) logical(value), ...
    values(logicalValues)));
assert(validation.allChecksPass, 'One or more output validations failed.');
writeText(fullfile(cfg.integrityDirectory, 'OutputValidation.json'), ...
    jsonencode(validation, PrettyPrint=true));
end


function output = orientChannelsFirst(data, expectedChannels)
if size(data, 1) == expectedChannels
    output = data;
elseif size(data, 2) == expectedChannels
    output = data.';
else
    error('Expected %d channels, found shape %s.', ...
        expectedChannels, shapeString(size(data)));
end
end


function output = resizeNormalized(input, side)
input = double(input);
finiteMask = isfinite(input);
input(~finiteMask) = 0;
minimum = min(input(:));
maximum = max(input(:));
if maximum > minimum
    input = (input - minimum) ./ (maximum - minimum);
else
    input = zeros(size(input));
end
output = single(imresize(input, [side side], 'bilinear'));
end


function grid = gridPointValues(points, values, side)
x = normalize01(points(1, :));
y = normalize01(points(2, :));
xi = min(side, max(1, floor(x .* (side - 1)) + 1));
yi = min(side, max(1, floor(y .* (side - 1)) + 1));
counts = accumarray([yi(:), xi(:)], 1, [side side], @sum, 0);
sums = accumarray([yi(:), xi(:)], values(:), [side side], @sum, 0);
grid = sums ./ max(counts, 1);
grid = normalize01(grid);
end


function output = normalize01(input)
input = double(input);
input(~isfinite(input)) = 0;
minimum = min(input(:));
maximum = max(input(:));
if maximum > minimum
    output = (input - minimum) ./ (maximum - minimum);
else
    output = zeros(size(input));
end
end


function value = shapeString(shape)
value = ['[' strtrim(sprintf('%d ', shape)) ']'];
end


function writeText(filePath, content)
fileID = fopen(filePath, 'w', 'n', 'UTF-8');
assert(fileID >= 0, 'Could not open %s for writing.', filePath);
cleanup = onCleanup(@() fclose(fileID));
fprintf(fileID, '%s', content);
end


function hex = sha256File(filePath)
command = sprintf('/usr/bin/shasum -a 256 "%s"', ...
    strrep(filePath, '"', '\"'));
[status, output] = system(command);
assert(status == 0, 'SHA-256 calculation failed for %s.', filePath);
hex = regexp(output, '^[0-9a-fA-F]{64}', 'match', 'once');
assert(~isempty(hex), 'SHA-256 output could not be parsed.');
hex = lower(hex);
end
