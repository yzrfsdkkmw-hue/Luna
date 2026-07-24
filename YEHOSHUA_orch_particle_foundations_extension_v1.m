function results = YEHOSHUA_orch_particle_foundations_extension_v1(mode)
% YEHOSHUA_ORCH_PARTICLE_FOUNDATIONS_EXTENSION_V1
% Build, validate, and package a deterministic particle-foundations visual
% learning extension without modifying the canonical H5 or source bundle.
%
% Public modes:
%   preflight     - read-only verification; default
%   execute       - one staged write followed by atomic publication
%   validate_only - read-only validation of the completed bundle

if nargin < 1
    mode = "preflight";
end
mode = lower(string(mode));
assert(ismember(mode, ["preflight", "execute", "validate_only"]), ...
    'Mode must be preflight, execute, or validate_only.');

cfg = configuration();
particles = particleSpecifications();
datasets = datasetSpecifications();
references = sourceReferences();
validateStaticSpecifications(cfg, particles, datasets, references);

if mode == "preflight"
    results = runPreflight(cfg, particles, datasets, references);
    printPreflight(results);
    return;
end

if mode == "validate_only"
    assert(isfolder(cfg.outputRoot), ...
        'Completed output root was not found: %s', cfg.outputRoot);
    results = validateCompletedBundle(cfg, particles, datasets);
    fprintf('\nVALIDATE_ONLY COMPLETE - NO OUTPUT FILES WRITTEN\n');
    fprintf('All checks pass : %s\n', string(results.allChecksPass));
    fprintf('Output root     : %s\n', cfg.outputRoot);
    return;
end

assert(~isfolder(cfg.outputRoot) && ~isfile(cfg.outputRoot), ...
    'Output root already exists; no files were changed.');
assert(~isfolder(cfg.stagingRoot) && ~isfile(cfg.stagingRoot), ...
    'Staging root already exists; no files were changed.');

startTime = tic;
sourceSnapshot = snapshotTree(cfg.sourceBundleRoot);
try
    folders = createStagingTree(cfg, particles);
    writetable(sourceSnapshot, fullfile(folders.integrity, ...
        'SourceV1Snapshot.csv'));
    writeCanonicalIntegrity(cfg, folders.integrity, sourceSnapshot);

    fprintf('\n%s\n', repmat('=', 1, 78));
    fprintf('YEHOSHUA ORCH PARTICLE FOUNDATIONS EXTENSION V1\n');
    fprintf('%s\n', repmat('=', 1, 78));
    fprintf('canonical H5 : %s\n', cfg.canonicalH5);
    fprintf('staging root : %s\n\n', cfg.stagingRoot);

    fprintf('[1/7] Extracting 27 canonical H5 datasets\n');
    tensorInventory = extractCanonicalTensors(cfg, datasets, folders);

    fprintf('[2/7] Building 12-channel canonical visual-source tensor\n');
    [sourceTensor, sourceNames] = buildCanonicalSourceTensor(cfg);

    fprintf('[3/7] Copying anchors and rendering 20 companions\n');
    [artifacts, anchorHashes] = buildParticleTriplets( ...
        cfg, particles, sourceTensor, folders);

    fprintf('[4/7] Building MAT/H5 training tensors\n');
    training = buildTrainingTensors(cfg, particles, artifacts, sourceTensor);
    tensorFiles = writeTrainingTensorFiles(cfg, training, folders);

    fprintf('[5/7] Building the ordered 5-by-6 contact sheet\n');
    contactSheet = writeContactSheet(cfg, artifacts, folders);

    fprintf('[6/7] Writing manifests and run records\n');
    manifests = writeManifests(cfg, particles, references, tensorInventory, ...
        sourceNames, artifacts, anchorHashes, tensorFiles, contactSheet, ...
        training, folders, sourceSnapshot, startTime);

    fprintf('[7/7] Validating staging and atomically publishing output\n');
    validation = validateBundleAtRoot(cfg, particles, datasets, ...
        cfg.stagingRoot, false);
    assert(validation.all_checks_pass, ...
        'One or more staging validation checks failed.');
    writeText(fullfile(folders.integrity, 'OutputValidation.json'), ...
        jsonencode(validation, PrettyPrint=true));

    sourceSnapshotAfter = snapshotTree(cfg.sourceBundleRoot);
    assert(compareSnapshots(sourceSnapshot, sourceSnapshotAfter), ...
        'The source v1 tree changed during execution.');
    assert(strcmpi(sha256File(cfg.canonicalH5), cfg.expectedH5SHA256), ...
        'Canonical H5 changed during execution.');

    [moved, message] = movefile(cfg.stagingRoot, cfg.outputRoot);
    assert(moved, 'Atomic publication failed: %s', message);

    finalValidation = validateBundleAtRoot(cfg, particles, datasets, ...
        cfg.outputRoot, true);
    assert(finalValidation.all_checks_pass, ...
        'Published bundle failed read-only validation.');

    results = struct;
    results.mode = char(mode);
    results.outputRoot = cfg.outputRoot;
    results.canonicalSHA256 = cfg.expectedH5SHA256;
    results.sourceAnchorHashes = anchorHashes;
    results.counts = struct('anchors', 10, 'companions', 20, ...
        'layerFiles', 60, 'h5Extracts', 27, 'sourceChannels', 12);
    results.tensorShapes = expectedTensorShapes();
    results.manifests = manifests;
    results.validation = finalValidation;
    results.allChecksPass = finalValidation.all_checks_pass;
    results.elapsedSeconds = toc(startTime);
catch exception
    fprintf(2, '\nEXECUTION FAILED. Staging is preserved when present:\n%s\n', ...
        cfg.stagingRoot);
    rethrow(exception);
end

fprintf('\nEXECUTION COMPLETE\n');
fprintf('Output root      : %s\n', results.outputRoot);
fprintf('Generated images : 20 companions + 10 byte-identical anchors\n');
fprintf('H5 extracts      : 27 MAT files\n');
fprintf('All checks pass  : %s\n', string(results.allChecksPass));
fprintf('Elapsed seconds  : %.3f\n', results.elapsedSeconds);
end


function cfg = configuration()
cfg = struct;
cfg.version = 'YEHOSHUA_orch_particle_foundations_extension_v1';
cfg.parentRoot = ['/Users/yehoshua/Desktop/' ...
    'YEHOSHUA_projection_temporal_formula_from_SSOT_v15'];
cfg.sourceBundleRoot = fullfile(cfg.parentRoot, ...
    'YEHOSHUA_Orch_tensor_training_bundle_v1');
cfg.anchorRoot = fullfile(cfg.sourceBundleRoot, 'images', 'particles');
cfg.canonicalH5 = ['/Users/yehoshua/MATLAB-Drive/modelTRAINING/' ...
    'jsonhotel_unified_001_002_SAFE_20260628_181406.h5'];
cfg.expectedH5SHA256 = ...
    '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
cfg.outputRoot = fullfile(cfg.parentRoot, ...
    'YEHOSHUA_Orch_tensor_training_bundle_v1_particle_foundations_extension_v1');
cfg.stagingRoot = [cfg.outputRoot '_BUILDING'];
cfg.imageSize = 640;
cfg.tensorImageSize = 224;
cfg.sourceSpatialSize = 64;
cfg.semanticPolicy = ['Canonical H5 values are auxiliary numeric visual-source ' ...
    'tensors only; they are not particle measurements, evidence, or observations.'];
cfg.accessDate = '2026-07-19';
end


function particles = particleSpecifications()
anchorRows = {
    1, 'photon', 'Photon.png', 'Photon / פוטון', ...
        '82ba537cb4c6505f2dccc703adc4addd7f916a662d71308338e9d83446829aa3';
    2, 'electron', 'Electron.png', 'Electron / אלקטרון', ...
        'd5376f9612a0c81ecb2ebcde30cf6873c54914b20e990c45cfe88ca7c2840702';
    3, 'neutrino', 'Neutrino.png', 'Neutrino / נייטרינו', ...
        '4ac5ce0d0e8dc3f7d28f8224fddbbecd3ca9da1d37c7686ead33ba82626c50bb';
    4, 'quarks', 'Quarks.png', 'Quarks / קווארקים', ...
        '4fcdea54a8c623fdb8cb6194e4c30ed1b55fda6682522da40a384cec4b915821';
    5, 'gluon', 'Gluon.png', 'Gluon / גלואון', ...
        '07e207c6f8ac9b2e85bf57909a71c1b68721bc28b2ea742361b547916a9ab527';
    6, 'proton', 'Proton.png', 'Proton / פרוטון', ...
        'b178d9c778df1340b22ef604a137d9bb376f78f964373b16208c17886256c9f2';
    7, 'neutron', 'Neutron.png', 'Neutron / נייטרון', ...
        '3ffb57083e793ecc822c890eb0da2fe97652a47774a3907b2622518b257d3584';
    8, 'weak_bosons', 'WeakBosons.png', 'Weak bosons / בוזונים חלשים', ...
        '703c4103e0c95c2a26041becb1d71fcb60e0bfb6fc833a5a3e84533c20cae809';
    9, 'higgs_boson', 'HiggsBoson.png', 'Higgs boson / בוזון היגס', ...
        '65862d6889e4bcedf2f407c4029d62f6e4d76ad696f70bbd8bcbdfa0be36b059';
    10, 'nucleus', 'Nucleus.png', 'Nucleus / גרעין', ...
        '8927ff9a6d2c4718490f45d0ad67a717a83ad37031f0ef58f0d23d029dfbc47d'};

companionRows = {
    1, 1, '01_transverse_electromagnetic_wave.png', ...
        'Transverse electromagnetic wave', 'classical_field_bridge', ...
        'E perpendicular B perpendicular k; c = lambda nu', ...
        'Classical electromagnetic-field representation; not a photon trajectory.', ...
        'Propagation arrow k with mutually transverse electric and magnetic field oscillations.', ...
        ["E","perpendicular","B"], '1;7';
    1, 2, '02_energy_momentum_wavelength.png', ...
        'Energy, momentum, and wavelength', 'foundational_quantum_relation', ...
        'E = h nu = h c / lambda; p = h / lambda; E = p c', ...
        'Single-photon relations in vacuum.', ...
        'Aligned wavelength and frequency states mapped to energy and momentum.', ...
        ["E","equals","p"], '1;7';
    2, 1, '01_electric_force_and_acceleration.png', ...
        'Electric force and acceleration', 'classical_bridge', ...
        'F = q E; q = -e; a = F / m_e', ...
        'Classical point-particle approximation.', ...
        'A negative charge in a uniform electric field with force opposite the field direction.', ...
        ["F","equals","q"], '1;7';
    2, 2, '02_lorentz_deflection.png', ...
        'Lorentz deflection', 'classical_relativistic_bridge', ...
        'F = q(E + v times B); r = p / (|q| B)', ...
        'Uniform field and perpendicular-motion case for the radius relation.', ...
        'An electron path bends in a uniform magnetic field with velocity, force, and curvature directions.', ...
        ["F","times","B"], '1;7';
    3, 1, '01_neutrino_flavor_triplet.png', ...
        'Neutrino flavor triplet', 'foundational_quantum_identity', ...
        'nu_e, nu_mu, nu_tau; q_nu = 0', ...
        'Electrically neutral flavor states; not classical species paths.', ...
        'Three linked flavor lanes represent electron, muon, and tau neutrino states.', ...
        ["nu","e","mu"], '5';
    3, 2, '02_flavor_oscillation_baseline.png', ...
        'Flavor oscillation baseline', 'quantum_only', ...
        'P(nu_alpha -> nu_beta) = sin^2(2 theta) sin^2(Delta m^2 L / (4 E))', ...
        'Two-flavor vacuum approximation with natural units and alpha not equal to beta.', ...
        'A baseline L connects source and detector while the flavor composition changes.', ...
        ["theta","arrow","E"], '5';
    4, 1, '01_quark_flavor_charge_pattern.png', ...
        'Quark flavor and charge pattern', 'foundational_quantum_identity', ...
        'u,c,t: +2e/3; d,s,b: -e/3', ...
        'Electric charges; visual colors are labels, not literal QCD color.', ...
        'Two structural rows encode repeated up-type and down-type fractional charges.', ...
        ["q","plus","e"], '6';
    4, 2, '02_baryon_composition_and_charge.png', ...
        'Baryon composition and charge', 'foundational_quantum_composition', ...
        'p = uud; n = udd; Q_p/e = 1; Q_n/e = 0', ...
        'Valence-quark bookkeeping; sea quarks and gluons remain part of the physical description.', ...
        'Two color-neutral triplets map valence composition to proton and neutron charge.', ...
        ["p","equals","q"], '2;6';
    5, 1, '01_color_charge_exchange.png', ...
        'Color-charge exchange', 'quantum_only', ...
        'q -> q + g', ...
        'Schematic QCD color flow; displayed colors are representational labels.', ...
        'A quark line changes its color label while a gluon carries a color-anticolor link.', ...
        ["q","arrow","plus"], '2';
    5, 2, '02_confining_flux_tube.png', ...
        'Confining flux tube', 'introductory_quantum_field_bridge', ...
        'V(r) approximately kappa r at large r', ...
        'Qualitative long-distance confinement model, not a universal all-distance potential.', ...
        'A narrowing flux tube links separating color sources as stored field energy increases.', ...
        ["V","equals","r"], '2;6';
    6, 1, '01_positive_charge_far_field.png', ...
        'Positive-charge far field', 'classical_far_field_bridge', ...
        'E(r) = e r_hat / (4 pi epsilon_0 r^2)', ...
        'Far-field classical approximation; does not depict proton internal structure.', ...
        'A radial electric field surrounds a localized positive source.', ...
        ["E","equals","e"], '1;7';
    6, 2, '02_uud_charge_bookkeeping.png', ...
        'uud charge bookkeeping', 'foundational_quantum_composition', ...
        '2/3 + 2/3 - 1/3 = +1', ...
        'Valence-quark charge bookkeeping.', ...
        'A triangular uud composition closes to one positive elementary charge.', ...
        ["plus","minus","equals"], '6';
    7, 1, '01_udd_neutral_charge_bookkeeping.png', ...
        'udd neutral-charge bookkeeping', 'foundational_quantum_composition', ...
        '2/3 - 1/3 - 1/3 = 0', ...
        'Electrical neutrality does not mean absence of internal charged constituents.', ...
        'A triangular udd composition closes to zero net charge.', ...
        ["minus","equals","q"], '6';
    7, 2, '02_free_neutron_beta_decay.png', ...
        'Free-neutron beta decay', 'quantum_weak_process', ...
        'n -> p + e^- + anti-nu_e', ...
        'Free-neutron beta decay; a neutron bound in a stable nucleus is not treated as freely decaying.', ...
        'A free neutron transforms into a proton, electron, and electron antineutrino.', ...
        ["N","arrow","plus"], '3;9';
    8, 1, '01_weak_mediator_family.png', ...
        'Weak mediator family', 'foundational_quantum_identity', ...
        'Q(W+) = +e; Q(W-) = -e; Q(Z0) = 0', ...
        'Massive electroweak gauge bosons; no classical force-particle trajectory claim.', ...
        'Three linked mediator nodes show W+, W-, and Z0 with distinct charge labels.', ...
        ["W","plus","minus"], '3';
    8, 2, '02_beta_decay_weak_vertex_chain.png', ...
        'Beta-decay weak-vertex chain', 'quantum_weak_process', ...
        'd -> u + W^-; W^- -> e^- + anti-nu_e', ...
        'Schematic interaction bookkeeping, not a resolved classical time sequence.', ...
        'Two linked vertices connect a down quark to an up quark and a W- decay pair.', ...
        ["W","arrow","e"], '3;9';
    9, 1, '01_higgs_scalar_field_potential.png', ...
        'Higgs scalar-field potential', 'classical_field_bridge_to_quantum_theory', ...
        'V(phi) = -mu^2 |phi|^2 + lambda |phi|^4', ...
        'Schematic Higgs-potential convention; parameters and normalization are stated.', ...
        'A symmetric scalar-field potential marks a vacuum ring and radial excitation direction.', ...
        ["V","phi","mu"], '4';
    9, 2, '02_higgs_excitation_and_yukawa_mass.png', ...
        'Higgs excitation and Yukawa mass', 'foundational_quantum_field_relation', ...
        'm_f = y_f v / sqrt(2)', ...
        'Fermion Yukawa mass relation; this does not supply most proton or neutron mass.', ...
        'A small excitation about the vacuum maps to the fermion mass-coupling relation.', ...
        ["m","equals","v"], '4';
    10, 1, '01_nuclide_composition.png', ...
        'Nuclide composition', 'foundational_nuclear_bookkeeping', ...
        'A = Z + N; nuclide = superscript A subscript Z X', ...
        'Z is proton number, N is neutron number, and A is nucleon number.', ...
        'A proton-neutron cluster maps to standard nuclide notation.', ...
        ["A","equals","N"], '8';
    10, 2, '02_binding_energy_mass_defect.png', ...
        'Binding energy and mass defect', 'foundational_nuclear_relation', ...
        'Delta m = Z m_p + N m_n - m_nucleus > 0; E_b = Delta m c^2', ...
        'Binding energy uses the stated positive mass-defect convention.', ...
        'Separated nucleons converge to a bound nucleus while an energy carrier leaves.', ...
        ["delta","m","equals"], '7;8'};

particles = repmat(struct('id', 0, 'slug', '', 'anchorFile', '', ...
    'title', '', 'expectedSHA256', '', 'companions', []), 10, 1);
for i = 1:10
    particles(i).id = anchorRows{i, 1};
    particles(i).slug = anchorRows{i, 2};
    particles(i).anchorFile = anchorRows{i, 3};
    particles(i).title = anchorRows{i, 4};
    particles(i).expectedSHA256 = anchorRows{i, 5};
    rows = companionRows([companionRows{:, 1}] == i, :);
    companions = repmat(struct('index', 0, 'file', '', 'title', '', ...
        'level', '', 'formula', '', 'scope', '', 'definition', '', ...
        'tokens', strings(1, 0), 'sourceIDs', ''), 2, 1);
    for j = 1:2
        companions(j).index = rows{j, 2};
        companions(j).file = rows{j, 3};
        companions(j).title = rows{j, 4};
        companions(j).level = rows{j, 5};
        companions(j).formula = rows{j, 6};
        companions(j).scope = rows{j, 7};
        companions(j).definition = rows{j, 8};
        companions(j).tokens = rows{j, 9};
        companions(j).sourceIDs = rows{j, 10};
    end
    particles(i).companions = companions;
end
end


function datasets = datasetSpecifications()
rows = {
    '/n_2_e8_lattice/roots_2d', [2 240], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/connections/a', [2 1832], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/connections/b', [2 1832], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/connections/d', [1832 1], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/laplacian_modes/modes', [12 240], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/laplacian_modes/xy', [2 240], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/streamlines/logmag', [278629 1], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/streamlines/sid', [278629 1], '01_n_2_e8_lattice';
    '/n_2_e8_lattice/streamlines/xy', [2 278629], '01_n_2_e8_lattice';
    '/n_3_defect_topology/charge', [2500 1], '02_n_3_defect_topology';
    '/n_3_defect_topology/degree', [2500 1], '02_n_3_defect_topology';
    '/n_3_defect_topology/pos', [2 2500], '02_n_3_defect_topology';
    '/n_4_geodesic_field/curl', [48400 1], '03_n_4_geodesic_field';
    '/n_4_geodesic_field/raw_points', [2 194527], '03_n_4_geodesic_field';
    '/n_4_geodesic_field/vel', [2 48400], '03_n_4_geodesic_field';
    '/n_4_geodesic_field/xy', [2 48400], '03_n_4_geodesic_field';
    '/n_5_composite_field_1000x1000/data', [5 1000000], ...
        '04_n_5_composite_field';
    '/n_6_field_maps_v3_800x800/chamber_field/data', [3 640000], ...
        '05_n_6_field_maps';
    '/n_6_field_maps_v3_800x800/fuchsian_tiling/data', [5 640000], ...
        '05_n_6_field_maps';
    '/n_6_field_maps_v3_800x800/ginibre_field/data', [3 640000], ...
        '05_n_6_field_maps';
    '/n_6_field_maps_v3_800x800/modular_eta/data', [3 640000], ...
        '05_n_6_field_maps';
    '/n_6_field_maps_v3_800x800/weyl_field/data', [5 640000], ...
        '05_n_6_field_maps';
    '/n_7_apollonian_circle_model/e8_chamber_angles', [9 1], ...
        '06_n_7_apollonian';
    '/spectral_mappings/crystal_colors', [9 7], '07_spectral_mappings';
    '/spectral_mappings/crystal_stops', [9 1], '07_spectral_mappings';
    '/spectral_mappings/phase_colors', [6 7], '07_spectral_mappings';
    '/spectral_mappings/phase_stops', [6 1], '07_spectral_mappings'};

datasets = repmat(struct('id', 0, 'path', '', 'expectedSize', [], ...
    'groupFolder', '', 'fileStem', ''), size(rows, 1), 1);
for i = 1:size(rows, 1)
    datasets(i).id = i;
    datasets(i).path = rows{i, 1};
    datasets(i).expectedSize = rows{i, 2};
    datasets(i).groupFolder = rows{i, 3};
    parts = split(extractAfter(string(rows{i, 1}), 1), '/');
    datasets(i).fileStem = char(strjoin(parts, '__'));
end
end


function references = sourceReferences()
referenceID = (1:9).';
title = [
    "Particle Data Group, Electromagnetic Relations"
    "Particle Data Group, Quantum Chromodynamics"
    "Particle Data Group, Electroweak Model and Constraints on New Physics"
    "Particle Data Group, Status of Higgs Boson Physics"
    "Particle Data Group, Neutrino Masses, Mixing, and Oscillations"
    "Particle Data Group, Quark Model"
    "NIST, CODATA Recommended Values of the Fundamental Physical Constants"
    "IAEA, Nuclear Medicine Physics"
    "U.S. Department of Energy, DOE Explains Beta Decay"];
section = [
    "Sec. 7, Lorentz force and SI electromagnetic relations"
    "Sec. 9.1, QCD basics; quarks, gluons, and color"
    "Sec. 10.1, charged-current weak interaction"
    "Secs. 11.2.1-11.2.2, scalar potential and Yukawa Lagrangian"
    "Sec. 14.4, Eqs. 14.41-14.43, vacuum oscillations"
    "Secs. 15.1-15.2 and 15.7, quark charges and confinement models"
    "2022 CODATA values; current NIST constants database"
    "Sec. 1.3, nuclear composition and binding energy"
    "Beta-minus decay and emitted antineutrino"];
url = [
    "https://pdg.lbl.gov/2025/reviews/rpp2025-rev-electromag-relations.pdf"
    "https://pdg.lbl.gov/2025/reviews/rpp2025-rev-qcd.pdf"
    "https://pdg.lbl.gov/2025/reviews/rpp2025-rev-standard-model.pdf"
    "https://pdg.lbl.gov/2025/reviews/rpp2025-rev-higgs-boson.pdf"
    "https://pdg.lbl.gov/2025/reviews/rpp2025-rev-neutrino-mixing.pdf"
    "https://pdg.lbl.gov/2025/reviews/rpp2025-rev-quark-model.pdf"
    "https://physics.nist.gov/cuu/Constants/index.html"
    "https://www-pub.iaea.org/mtcd/publications/pdf/pub1617web-1294055.pdf"
    "https://www.energy.gov/science/doe-explainsbeta-decay"];
accessDate = repmat("2026-07-19", 9, 1);
formulaScope = [
    "Classical SI electromagnetic bridges and uniform-field Lorentz force"
    "QCD terminology and quantum color-flow boundary"
    "W and Z identities and schematic charged-current bookkeeping"
    "Higgs potential sign convention and m_f = y_f v/sqrt(2)"
    "Two-flavor vacuum transition approximation in natural units"
    "Fractional quark charges, valence bookkeeping, and qualitative confinement"
    "Values and units of c, h, e, epsilon_0, and particle masses"
    "A = Z + N and positive mass-defect binding-energy convention"
    "Free-neutron beta-minus decay products"];
references = table(referenceID, title, section, url, accessDate, ...
    formulaScope, 'VariableNames', {'reference_id', 'title', 'section', ...
    'url_or_doi', 'access_date', 'formula_scope'});
end


function validateStaticSpecifications(cfg, particles, datasets, references)
assert(isfolder(cfg.sourceBundleRoot), 'Source bundle root was not found.');
assert(isfolder(cfg.anchorRoot), 'Particle anchor root was not found.');
assert(isfile(cfg.canonicalH5), 'Canonical H5 was not found.');
assert(strcmpi(sha256File(cfg.canonicalH5), cfg.expectedH5SHA256), ...
    'Canonical H5 SHA-256 mismatch.');
assert(numel(particles) == 10, 'Expected ten particle specifications.');
assert(numel(datasets) == 27, 'Expected twenty-seven dataset specifications.');
assert(height(references) == 9, 'Expected nine authoritative references.');
assert(isequal([particles.id].', (1:10).'), ...
    'Particle IDs must be sequential.');

for i = 1:numel(particles)
    assert(numel(particles(i).companions) == 2, ...
        'Every anchor must have exactly two companions.');
    sourceFile = fullfile(cfg.anchorRoot, particles(i).anchorFile);
    assert(isfile(sourceFile), 'Missing anchor: %s', sourceFile);
    assert(strcmpi(sha256File(sourceFile), particles(i).expectedSHA256), ...
        'Anchor SHA-256 mismatch: %s', sourceFile);
    imageInfo = imfinfo(sourceFile);
    assert(imageInfo.Width == cfg.imageSize && imageInfo.Height == cfg.imageSize, ...
        'Anchor dimensions must be 640-by-640: %s', sourceFile);
    imageData = imread(sourceFile);
    assert(ndims(imageData) == 3 && size(imageData, 3) == 3, ...
        'Anchor must be RGB: %s', sourceFile);
    for j = 1:2
        companion = particles(i).companions(j);
        assert(~isempty(companion.formula) && ~isempty(companion.scope), ...
            'Every companion requires a formula and scope label.');
        assert(numel(companion.tokens) >= 3, ...
            'Every companion requires at least three structural tokens.');
        assert(~isempty(companion.sourceIDs), ...
            'Every companion requires an authoritative source mapping.');
    end
end

for i = 1:numel(datasets)
    info = h5info(cfg.canonicalH5, datasets(i).path);
    assert(isequal(double(info.Dataspace.Size), ...
        double(datasets(i).expectedSize)), ...
        'H5 dataset shape mismatch for %s. Expected %s, found %s.', ...
        datasets(i).path, shapeString(datasets(i).expectedSize), ...
        shapeString(info.Dataspace.Size));
end
end


function results = runPreflight(cfg, particles, datasets, references)
beforeOutput = pathExists(cfg.outputRoot);
beforeStaging = pathExists(cfg.stagingRoot);
sourceSnapshotBefore = snapshotTree(cfg.sourceBundleRoot);
canonicalBefore = sha256File(cfg.canonicalH5);

validateStaticSpecifications(cfg, particles, datasets, references);

sourceSnapshotAfter = snapshotTree(cfg.sourceBundleRoot);
canonicalAfter = sha256File(cfg.canonicalH5);
afterOutput = pathExists(cfg.outputRoot);
afterStaging = pathExists(cfg.stagingRoot);

results = struct;
results.mode = 'preflight';
results.canonicalH5 = cfg.canonicalH5;
results.canonicalSHA256 = canonicalAfter;
results.canonicalHashMatch = strcmpi(canonicalAfter, cfg.expectedH5SHA256);
results.canonicalUnchanged = strcmpi(canonicalBefore, canonicalAfter);
results.sourceBundleUnchanged = compareSnapshots( ...
    sourceSnapshotBefore, sourceSnapshotAfter);
results.anchorCount = numel(particles);
results.companionCount = 2 * numel(particles);
results.datasetCount = numel(datasets);
results.referenceCount = height(references);
results.outputRootAvailable = ~beforeOutput && ~afterOutput;
results.stagingRootAvailable = ~beforeStaging && ~afterStaging;
results.outputFilesWritten = 0;
results.expectedTensorShapes = expectedTensorShapes();
results.allChecksPass = results.canonicalHashMatch && ...
    results.canonicalUnchanged && results.sourceBundleUnchanged && ...
    results.outputRootAvailable && results.stagingRootAvailable;
assert(results.allChecksPass, 'Preflight validation failed.');
end


function printPreflight(results)
fprintf('\nPREFLIGHT COMPLETE - NO OUTPUT FILES WRITTEN\n');
fprintf('Canonical SHA-256 : %s\n', results.canonicalSHA256);
fprintf('Anchors verified  : %d\n', results.anchorCount);
fprintf('Companions planned: %d\n', results.companionCount);
fprintf('H5 datasets       : %d\n', results.datasetCount);
fprintf('Sources locked    : %d\n', results.referenceCount);
fprintf('Output available  : %s\n', string(results.outputRootAvailable));
fprintf('Staging available : %s\n', string(results.stagingRootAvailable));
fprintf('All checks pass   : %s\n', string(results.allChecksPass));
end


function folders = createStagingTree(cfg, particles)
mkdir(cfg.stagingRoot);
folders = struct;
folders.integrity = fullfile(cfg.stagingRoot, '00_integrity');
folders.triplets = fullfile(cfg.stagingRoot, '01_particle_learning_triplets');
folders.layers = fullfile(cfg.stagingRoot, '02_notation_masks');
folders.extracts = fullfile(cfg.stagingRoot, '03_h5_tensor_extracts');
folders.training = fullfile(cfg.stagingRoot, '04_training_tensors');
folders.manifests = fullfile(cfg.stagingRoot, '05_manifests');
folders.contacts = fullfile(cfg.stagingRoot, '06_contact_sheets');
mkdir(folders.integrity);
mkdir(folders.triplets);
mkdir(folders.layers);
mkdir(folders.extracts);
mkdir(folders.training);
mkdir(folders.manifests);
mkdir(folders.contacts);

for i = 1:numel(particles)
    mkdir(fullfile(folders.triplets, sprintf('%02d_%s', ...
        particles(i).id, particles(i).slug)));
end
for name = ["01_n_2_e8_lattice", "02_n_3_defect_topology", ...
        "03_n_4_geodesic_field", "04_n_5_composite_field", ...
        "05_n_6_field_maps", "06_n_7_apollonian", ...
        "07_spectral_mappings"]
    mkdir(fullfile(folders.extracts, char(name)));
end
end


function writeCanonicalIntegrity(cfg, integrityFolder, sourceSnapshot)
record = struct;
record.canonical_h5 = cfg.canonicalH5;
record.expected_sha256 = cfg.expectedH5SHA256;
record.actual_sha256 = sha256File(cfg.canonicalH5);
record.hash_match = strcmpi(record.actual_sha256, cfg.expectedH5SHA256);
record.source_bundle_root = cfg.sourceBundleRoot;
record.source_bundle_file_count = height(sourceSnapshot);
record.output_strategy = 'isolated sibling bundle with staging publication';
record.semantic_policy = cfg.semanticPolicy;
record.created_local_date = cfg.accessDate;
assert(record.hash_match, 'Canonical integrity record failed.');
writeText(fullfile(integrityFolder, 'CanonicalIntegrity.json'), ...
    jsonencode(record, PrettyPrint=true));
end


function inventory = extractCanonicalTensors(cfg, datasets, folders)
count = numel(datasets);
id = zeros(count, 1);
datasetPath = strings(count, 1);
outputFile = strings(count, 1);
matlabClass = strings(count, 1);
dimensions = strings(count, 1);
rankValue = zeros(count, 1);
elementCount = zeros(count, 1);
byteCount = zeros(count, 1);
finiteCount = zeros(count, 1);
nanCount = zeros(count, 1);
infCount = zeros(count, 1);
minValue = nan(count, 1);
maxValue = nan(count, 1);
meanValue = nan(count, 1);
stdValue = nan(count, 1);
matFileSHA256 = strings(count, 1);

for i = 1:count
    tensorData = h5read(cfg.canonicalH5, datasets(i).path);
    assert(isequal(size(tensorData), datasets(i).expectedSize), ...
        'Extracted tensor shape mismatch for %s.', datasets(i).path);
    tensorMetadata = struct;
    tensorMetadata.source_h5 = cfg.canonicalH5;
    tensorMetadata.source_h5_sha256 = cfg.expectedH5SHA256;
    tensorMetadata.dataset_path = datasets(i).path;
    tensorMetadata.matlab_class = class(tensorData);
    tensorMetadata.original_dimensions = size(tensorData);
    tensorMetadata.element_count = numel(tensorData);
    tensorMetadata.semantic_policy = cfg.semanticPolicy;

    fileName = sprintf('%03d_%s.mat', datasets(i).id, ...
        datasets(i).fileStem);
    relativeFile = fullfile('03_h5_tensor_extracts', ...
        datasets(i).groupFolder, fileName);
    absoluteFile = fullfile(cfg.stagingRoot, relativeFile);
    save(absoluteFile, 'tensorData', 'tensorMetadata', '-v7.3');

    numericValues = double(tensorData(:));
    finiteMask = isfinite(numericValues);
    finiteValues = numericValues(finiteMask);
    variableInfo = whos('tensorData');
    id(i) = datasets(i).id;
    datasetPath(i) = string(datasets(i).path);
    outputFile(i) = string(relativeFile);
    matlabClass(i) = string(class(tensorData));
    dimensions(i) = shapeString(size(tensorData));
    rankValue(i) = ndims(tensorData);
    elementCount(i) = numel(tensorData);
    byteCount(i) = variableInfo.bytes;
    finiteCount(i) = nnz(finiteMask);
    nanCount(i) = nnz(isnan(numericValues));
    infCount(i) = nnz(isinf(numericValues));
    if ~isempty(finiteValues)
        minValue(i) = min(finiteValues);
        maxValue(i) = max(finiteValues);
        meanValue(i) = mean(finiteValues);
        stdValue(i) = std(finiteValues, 0);
    end
    matFileSHA256(i) = sha256File(absoluteFile);
end

inventory = table(id, datasetPath, outputFile, matlabClass, dimensions, ...
    rankValue, elementCount, byteCount, finiteCount, nanCount, infCount, ...
    minValue, maxValue, meanValue, stdValue, matFileSHA256, ...
    'VariableNames', {'id', 'dataset_path', 'output_file', 'matlab_class', ...
    'dimensions', 'rank', 'element_count', 'bytes_in_memory', ...
    'finite_count', 'nan_count', 'inf_count', 'min_value', 'max_value', ...
    'mean_value', 'std_value', 'mat_file_sha256'});
writetable(inventory, fullfile(folders.manifests, 'H5TensorInventory.csv'));
end


function [sourceTensor, names] = buildCanonicalSourceTensor(cfg)
side = cfg.sourceSpatialSize;
sourceTensor = zeros(side, side, 12, 'single');
names = ["composite_01"; "composite_02"; "composite_03"; ...
    "chamber_01"; "fuchsian_01"; "ginibre_01"; "modular_eta_01"; ...
    "weyl_01"; "laplacian_mode_01"; "defect_charge_density"; ...
    "geodesic_speed"; "geodesic_curl"];

composite = orientChannelsFirst(single(h5read(cfg.canonicalH5, ...
    '/n_5_composite_field_1000x1000/data')), 5);
for channel = 1:3
    sourceTensor(:, :, channel) = resizeNormalized( ...
        reshape(composite(channel, :), 1000, 1000), side);
end

fieldPaths = [
    "/n_6_field_maps_v3_800x800/chamber_field/data"
    "/n_6_field_maps_v3_800x800/fuchsian_tiling/data"
    "/n_6_field_maps_v3_800x800/ginibre_field/data"
    "/n_6_field_maps_v3_800x800/modular_eta/data"
    "/n_6_field_maps_v3_800x800/weyl_field/data"];
fieldChannels = [3 5 3 3 5];
for i = 1:numel(fieldPaths)
    raw = orientChannelsFirst(single(h5read(cfg.canonicalH5, ...
        fieldPaths(i))), fieldChannels(i));
    sourceTensor(:, :, i + 3) = resizeNormalized( ...
        reshape(raw(1, :), 800, 800), side);
end

xy = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/laplacian_modes/xy')), 2);
modes = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_2_e8_lattice/laplacian_modes/modes')), 12);
sourceTensor(:, :, 9) = single(gridPointValues(xy, modes(1, :).', side));

positions = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/pos')), 2);
charges = double(h5read(cfg.canonicalH5, ...
    '/n_3_defect_topology/charge'));
sourceTensor(:, :, 10) = single(gridPointValues( ...
    positions, charges(:), side));

velocity = orientChannelsFirst(double(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/vel')), 2);
speed = hypot(velocity(1, :), velocity(2, :));
sourceTensor(:, :, 11) = resizeNormalized(reshape(speed, 220, 220), side);
curlField = double(h5read(cfg.canonicalH5, ...
    '/n_4_geodesic_field/curl'));
sourceTensor(:, :, 12) = resizeNormalized( ...
    reshape(curlField, 220, 220), side);
assert(all(isfinite(sourceTensor(:))), ...
    'Canonical visual-source tensor contains non-finite values.');
end


function [artifacts, anchorHashes] = buildParticleTriplets( ...
        cfg, particles, sourceTensor, folders)
artifacts = repmat(struct('anchor', '', 'companions', strings(2, 1), ...
    'notationMasks', strings(2, 1), 'relationMasks', strings(2, 1), ...
    'carrierFields', strings(2, 1), 'tokenCoordinates', {cell(2, 1)}), 10, 1);
anchorID = zeros(10, 1);
anchorFile = strings(10, 1);
sourceSHA256 = strings(10, 1);
copiedSHA256 = strings(10, 1);
hashMatch = false(10, 1);

globalCompanionID = 0;
for i = 1:numel(particles)
    tripletRelative = fullfile('01_particle_learning_triplets', ...
        sprintf('%02d_%s', particles(i).id, particles(i).slug));
    sourceAnchor = fullfile(cfg.anchorRoot, particles(i).anchorFile);
    relativeAnchor = fullfile(tripletRelative, '00_anchor_source.png');
    copiedAnchor = fullfile(cfg.stagingRoot, relativeAnchor);
    [copied, message] = copyfile(sourceAnchor, copiedAnchor);
    assert(copied, 'Anchor copy failed: %s', message);
    anchorID(i) = particles(i).id;
    anchorFile(i) = string(particles(i).anchorFile);
    sourceSHA256(i) = sha256File(sourceAnchor);
    copiedSHA256(i) = sha256File(copiedAnchor);
    hashMatch(i) = strcmpi(sourceSHA256(i), copiedSHA256(i));
    assert(hashMatch(i), 'Copied anchor hash mismatch: %s', copiedAnchor);
    artifacts(i).anchor = relativeAnchor;

    anchorImage = imread(sourceAnchor);
    for j = 1:2
        globalCompanionID = globalCompanionID + 1;
        companion = particles(i).companions(j);
        coordinates = tokenCoordinates(globalCompanionID);
        [notationMask, relationMask, carrierField] = ...
            buildStructuralLayers(companion.tokens, coordinates, ...
            cfg.imageSize, globalCompanionID, sourceTensor);
        relativeCompanion = fullfile(tripletRelative, companion.file);
        absoluteCompanion = fullfile(cfg.stagingRoot, relativeCompanion);
        renderCompanionCard(anchorImage, sourceTensor, particles(i), ...
            companion, globalCompanionID, notationMask, relationMask, ...
            carrierField, absoluteCompanion, cfg.imageSize);

        stem = sprintf('%02d_%s__%02d', particles(i).id, ...
            particles(i).slug, j);
        relativeNotation = fullfile('02_notation_masks', ...
            [stem '__notation_mask.png']);
        relativeRelation = fullfile('02_notation_masks', ...
            [stem '__relation_mask.png']);
        relativeCarrier = fullfile('02_notation_masks', ...
            [stem '__carrier_field.png']);
        imwrite(im2uint8(notationMask), fullfile(cfg.stagingRoot, relativeNotation));
        imwrite(im2uint8(relationMask), fullfile(cfg.stagingRoot, relativeRelation));
        imwrite(im2uint8(carrierField), fullfile(cfg.stagingRoot, relativeCarrier));

        artifacts(i).companions(j) = string(relativeCompanion);
        artifacts(i).notationMasks(j) = string(relativeNotation);
        artifacts(i).relationMasks(j) = string(relativeRelation);
        artifacts(i).carrierFields(j) = string(relativeCarrier);
        artifacts(i).tokenCoordinates{j} = coordinates;
    end
end
anchorHashes = table(anchorID, anchorFile, sourceSHA256, copiedSHA256, ...
    hashMatch, 'VariableNames', {'id', 'anchor_file', 'source_sha256', ...
    'copied_sha256', 'hash_match'});
writetable(anchorHashes, fullfile(folders.integrity, 'SourceAnchorHashes.csv'));
end


function training = buildTrainingTensors(cfg, particles, artifacts, sourceTensor)
training = struct;
training.anchor_images_uint8 = zeros(cfg.tensorImageSize, ...
    cfg.tensorImageSize, 3, 10, 'uint8');
training.companion_images_uint8 = zeros(cfg.tensorImageSize, ...
    cfg.tensorImageSize, 3, 2, 10, 'uint8');
training.notation_masks_single = zeros(cfg.tensorImageSize, ...
    cfg.tensorImageSize, 2, 10, 'single');
training.relation_masks_single = zeros(cfg.tensorImageSize, ...
    cfg.tensorImageSize, 2, 10, 'single');
training.carrier_fields_single = zeros(cfg.tensorImageSize, ...
    cfg.tensorImageSize, 2, 10, 'single');

for i = 1:numel(particles)
    anchor = imread(fullfile(cfg.stagingRoot, artifacts(i).anchor));
    training.anchor_images_uint8(:, :, :, i) = imresize( ...
        anchor, [cfg.tensorImageSize cfg.tensorImageSize], 'bicubic');
    for j = 1:2
        companion = imread(fullfile(cfg.stagingRoot, artifacts(i).companions(j)));
        training.companion_images_uint8(:, :, :, j, i) = imresize( ...
            companion, [cfg.tensorImageSize cfg.tensorImageSize], 'bicubic');
        training.notation_masks_single(:, :, j, i) = imresize( ...
            im2single(imread(fullfile(cfg.stagingRoot, ...
            artifacts(i).notationMasks(j)))), ...
            [cfg.tensorImageSize cfg.tensorImageSize], 'bilinear');
        training.relation_masks_single(:, :, j, i) = imresize( ...
            im2single(imread(fullfile(cfg.stagingRoot, ...
            artifacts(i).relationMasks(j)))), ...
            [cfg.tensorImageSize cfg.tensorImageSize], 'bilinear');
        training.carrier_fields_single(:, :, j, i) = imresize( ...
            im2single(imread(fullfile(cfg.stagingRoot, ...
            artifacts(i).carrierFields(j)))), ...
            [cfg.tensorImageSize cfg.tensorImageSize], 'bilinear');
    end
end

training.canonical_visual_sources_single = single(sourceTensor);
training.concept_companion_codebook_single = zeros(10, 20, 'single');
for i = 1:10
    training.concept_companion_codebook_single(i, (2*i-1):(2*i)) = 1;
end
training.triplet_adjacency_single = zeros(30, 30, 'single');
for i = 1:10
    indices = (3*i-2):(3*i);
    training.triplet_adjacency_single(indices, indices) = ...
        single(ones(3) - eye(3));
end
training.entity_order = tripletEntityOrder(particles);
training.semantic_policy = cfg.semanticPolicy;
training.canonical_h5 = cfg.canonicalH5;
training.canonical_sha256 = cfg.expectedH5SHA256;
end


function files = writeTrainingTensorFiles(cfg, training, folders)
files = struct;
files.mat = fullfile('04_training_tensors', ...
    'OrchParticleFoundationsLearningTensors.mat');
files.h5 = fullfile('04_training_tensors', ...
    'OrchParticleFoundationsLearningTensors.h5');
save(fullfile(cfg.stagingRoot, files.mat), 'training', '-v7.3');

h5File = fullfile(cfg.stagingRoot, files.h5);
writeH5Dataset(h5File, '/images/anchors', training.anchor_images_uint8, true);
writeH5Dataset(h5File, '/images/companions', ...
    training.companion_images_uint8, false);
writeH5Dataset(h5File, '/masks/notation', ...
    training.notation_masks_single, false);
writeH5Dataset(h5File, '/masks/relation', ...
    training.relation_masks_single, false);
writeH5Dataset(h5File, '/fields/carriers', ...
    training.carrier_fields_single, false);
writeH5Dataset(h5File, '/canonical/visual_sources', ...
    training.canonical_visual_sources_single, false);
writeH5Dataset(h5File, '/codebooks/concept_companion', ...
    training.concept_companion_codebook_single, false);
writeH5Dataset(h5File, '/relations/triplet_adjacency', ...
    training.triplet_adjacency_single, false);
assert(isfile(fullfile(folders.training, ...
    'OrchParticleFoundationsLearningTensors.mat')));
end


function coordinates = tokenCoordinates(companionID)
offset = 0.012 * mod(companionID - 1, 4);
coordinates = [0.15 + offset, 0.26; ...
    0.31 + offset, 0.20; ...
    0.47 + offset, 0.28];
end


function [notationMask, relationMask, carrierField] = ...
        buildStructuralLayers(tokens, coordinates, side, companionID, sourceTensor)
[xGrid, yGrid] = meshgrid(linspace(0, 1, side));
notationMask = zeros(side, side);
for i = 1:3
    notationMask = max(notationMask, glyphMask(tokens(i), ...
        coordinates(i, 1), coordinates(i, 2), 0.07, xGrid, yGrid));
end

relationMask = zeros(side, side);
relationMask = max(relationMask, arrowMask(coordinates(1, :), ...
    coordinates(2, :), 0.0055, xGrid, yGrid));
relationMask = max(relationMask, arrowMask(coordinates(2, :), ...
    coordinates(3, :), 0.0055, xGrid, yGrid));
relationMask = max(relationMask, polylineMask( ...
    [coordinates(3, :); 0.74 0.31; 0.86 0.25], ...
    0.0045, xGrid, yGrid));

channel = 1 + mod(companionID - 1, size(sourceTensor, 3));
source = imresize(sourceTensor(:, :, channel), [side side], 'bicubic');
phase = 0.37 * companionID;
waveDistance = abs(yGrid - (0.315 + 0.035 * ...
    sin(2*pi*(2.2*xGrid + phase))));
wave = exp(-0.5 .* (waveDistance ./ 0.010).^2);
radial = exp(-((xGrid - 0.76).^2 + (yGrid - 0.25).^2) ./ 0.025);
carrierField = normalize01(0.48 * double(source) + 0.38 * wave + 0.24 * radial);
carrierField(yGrid > 0.60) = 0.20 * carrierField(yGrid > 0.60);
carrierField = single(carrierField);
notationMask = single(normalize01(notationMask));
relationMask = single(normalize01(relationMask));
assert(nnz(notationMask > 0.05) > 80, 'Notation mask is unexpectedly empty.');
assert(nnz(relationMask > 0.05) > 80, 'Relation mask is unexpectedly empty.');
assert(nnz(carrierField > 0.05) > 80, 'Carrier field is unexpectedly empty.');
end


function mask = glyphMask(token, centerX, centerY, scale, xGrid, yGrid)
tokenText = string(token);
key = lower(tokenText);
width = 0.0048;
left = centerX - scale / 2;
right = centerX + scale / 2;
top = centerY - scale / 2;
bottom = centerY + scale / 2;
middleY = centerY;
middleX = centerX;

if tokenText == "E"
    mask = polylineMask([left top; left bottom], width, xGrid, yGrid);
    mask = max(mask, polylineMask([left top; right top], width, xGrid, yGrid));
    mask = max(mask, polylineMask([left middleY; right*0.98 middleY], ...
        width, xGrid, yGrid));
    mask = max(mask, polylineMask([left bottom; right bottom], width, xGrid, yGrid));
elseif tokenText == "F"
    mask = polylineMask([left bottom; left top; right top], width, xGrid, yGrid);
    mask = max(mask, polylineMask([left middleY; right*0.98 middleY], ...
        width, xGrid, yGrid));
elseif tokenText == "B"
    mask = polylineMask([left top; left bottom], width, xGrid, yGrid);
    mask = max(mask, circleMask(left + 0.020, top + 0.018, ...
        0.023, width, xGrid, yGrid));
    mask = max(mask, circleMask(left + 0.020, bottom - 0.018, ...
        0.023, width, xGrid, yGrid));
elseif tokenText == "A"
    mask = polylineMask([left bottom; middleX top; right bottom], ...
        width, xGrid, yGrid);
    mask = max(mask, polylineMask([left+0.012 middleY; right-0.012 middleY], ...
        width, xGrid, yGrid));
elseif tokenText == "N"
    mask = polylineMask([left bottom; left top; right bottom; right top], ...
        width, xGrid, yGrid);
elseif tokenText == "W"
    mask = polylineMask([left top; left+0.016 bottom; middleX top+0.018; ...
        right-0.016 bottom; right top], width, xGrid, yGrid);
elseif tokenText == "V"
    mask = polylineMask([left top; middleX bottom; right top], ...
        width, xGrid, yGrid);
else
    switch key
        case "equals"
            mask = polylineMask([left centerY-0.012; right centerY-0.012], ...
                width, xGrid, yGrid);
            mask = max(mask, polylineMask([left centerY+0.012; right centerY+0.012], ...
                width, xGrid, yGrid));
        case "plus"
            mask = polylineMask([left middleY; right middleY], width, xGrid, yGrid);
            mask = max(mask, polylineMask([middleX top; middleX bottom], ...
                width, xGrid, yGrid));
        case "minus"
            mask = polylineMask([left middleY; right middleY], width, xGrid, yGrid);
        case "times"
            mask = polylineMask([left top; right bottom], width, xGrid, yGrid);
            mask = max(mask, polylineMask([right top; left bottom], ...
                width, xGrid, yGrid));
        case "perpendicular"
            mask = polylineMask([left bottom; right bottom], width, xGrid, yGrid);
            mask = max(mask, polylineMask([middleX top; middleX bottom], ...
                width, xGrid, yGrid));
        case "arrow"
            mask = arrowMask([left middleY], [right middleY], ...
                width, xGrid, yGrid);
        case {"theta", "phi"}
            mask = circleMask(middleX, middleY, scale*0.40, ...
                width, xGrid, yGrid);
            if key == "theta"
                mask = max(mask, polylineMask([left middleY; right middleY], ...
                    width, xGrid, yGrid));
            else
                mask = max(mask, polylineMask([middleX top-0.010; ...
                    middleX bottom+0.010], width, xGrid, yGrid));
            end
        case "delta"
            mask = polylineMask([left bottom; middleX top; right bottom; left bottom], ...
                width, xGrid, yGrid);
        case "nu"
            mask = polylineMask([left top+0.012; middleX bottom; right top], ...
                width, xGrid, yGrid);
        case "mu"
            mask = polylineMask([left top; left bottom-0.015; middleX bottom; ...
                right bottom-0.015; right top; right bottom+0.012], ...
                width, xGrid, yGrid);
        case "m"
            mask = polylineMask([left bottom; left top+0.018; ...
                left+0.018 top; middleX middleY; right-0.016 top; ...
                right bottom], width, xGrid, yGrid);
        case "p"
            mask = polylineMask([left top; left bottom+0.018], width, xGrid, yGrid);
            mask = max(mask, circleMask(left+0.020, top+0.020, ...
                0.022, width, xGrid, yGrid));
        case "q"
            mask = circleMask(middleX, middleY-0.006, scale*0.36, ...
                width, xGrid, yGrid);
            mask = max(mask, polylineMask([middleX+0.012 middleY+0.012; ...
                right bottom+0.010], width, xGrid, yGrid));
        case "e"
            mask = circleMask(middleX, middleY, scale*0.36, ...
                width, xGrid, yGrid);
            mask = max(mask, polylineMask([left middleY; right middleY], ...
                width, xGrid, yGrid));
        case "r"
            mask = polylineMask([left bottom; left top; middleX middleY; ...
                right top+0.012], width, xGrid, yGrid);
        case "v"
            mask = polylineMask([left top; middleX bottom; right top], ...
                width, xGrid, yGrid);
        otherwise
            mask = circleMask(middleX, middleY, scale*0.35, ...
                width, xGrid, yGrid);
            mask = max(mask, polylineMask([middleX top; middleX bottom], ...
                width, xGrid, yGrid));
    end
end
end


function mask = arrowMask(startPoint, endPoint, width, xGrid, yGrid)
mask = polylineMask([startPoint; endPoint], width, xGrid, yGrid);
direction = endPoint - startPoint;
direction = direction ./ max(norm(direction), eps);
normal = [-direction(2), direction(1)];
headLength = 0.022;
headWidth = 0.012;
base = endPoint - headLength .* direction;
mask = max(mask, polylineMask([endPoint; base + headWidth .* normal], ...
    width, xGrid, yGrid));
mask = max(mask, polylineMask([endPoint; base - headWidth .* normal], ...
    width, xGrid, yGrid));
end


function mask = polylineMask(points, width, xGrid, yGrid)
mask = zeros(size(xGrid));
for i = 1:(size(points, 1)-1)
    distance = segmentDistance(xGrid, yGrid, points(i, :), points(i+1, :));
    mask = max(mask, exp(-0.5 .* (distance ./ width).^2));
end
end


function distance = segmentDistance(xGrid, yGrid, pointA, pointB)
vector = pointB - pointA;
denominator = sum(vector.^2);
if denominator <= eps
    distance = hypot(xGrid - pointA(1), yGrid - pointA(2));
    return;
end
projection = ((xGrid - pointA(1)) .* vector(1) + ...
    (yGrid - pointA(2)) .* vector(2)) ./ denominator;
projection = min(1, max(0, projection));
closestX = pointA(1) + projection .* vector(1);
closestY = pointA(2) + projection .* vector(2);
distance = hypot(xGrid - closestX, yGrid - closestY);
end


function mask = circleMask(centerX, centerY, radius, width, xGrid, yGrid)
distance = abs(hypot(xGrid-centerX, yGrid-centerY) - radius);
mask = exp(-0.5 .* (distance ./ width).^2);
end


function renderCompanionCard(anchorImage, sourceTensor, particle, companion, ...
        companionID, notationMask, relationMask, carrierField, outputFile, side)
base = buildBaseImage(anchorImage, sourceTensor, companionID, side);
base = overlayField(base, carrierField, [0.90 0.10 0.68], 0.20);
base = overlayField(base, relationMask, [0.05 0.88 1.00], 0.52);
base = overlayField(base, notationMask, [1.00 0.80 0.08], 0.68);
card = im2uint8(base);
card = drawMechanismRaster(card, companionID);

card = insertShape(card, 'FilledRectangle', [18 392 604 232], ...
    'Color', [8 13 38], 'Opacity', 0.94);
card = insertShape(card, 'Rectangle', [18 392 604 232], ...
    'Color', [38 218 245], 'LineWidth', 2);
card = insertText(card, [24 17], visualBilingualTitle(particle.title), ...
    'FontSize', 22, 'TextColor', [245 250 255], 'BoxOpacity', 0, ...
    'Font', 'Arial', 'AnchorPoint', 'LeftTop');
card = insertText(card, [24 53], companion.title, ...
    'FontSize', 18, 'TextColor', [50 224 255], 'BoxOpacity', 0, ...
    'Font', 'Arial', 'AnchorPoint', 'LeftTop');
card = insertText(card, [24 399], upper(strrep(companion.level, '_', ' ')), ...
    'FontSize', 11, 'TextColor', [248 204 48], 'BoxOpacity', 0, ...
    'Font', 'Arial', 'AnchorPoint', 'LeftTop');

formulaLines = wrapTextLines(companion.formula, 62);
y = 420;
for i = 1:numel(formulaLines)
    card = insertText(card, [24 y], formulaLines(i), ...
        'FontSize', 17, 'TextColor', [255 220 76], 'BoxOpacity', 0, ...
        'Font', 'Arial', 'AnchorPoint', 'LeftTop');
    y = y + 23;
end
y = y + 3;
definitionLines = wrapTextLines(companion.definition, 92);
for i = 1:numel(definitionLines)
    card = insertText(card, [24 y], definitionLines(i), ...
        'FontSize', 12, 'TextColor', [242 246 255], 'BoxOpacity', 0, ...
        'Font', 'Arial', 'AnchorPoint', 'LeftTop');
    y = y + 17;
end
y = y + 3;
scopeLines = wrapTextLines(['SCOPE: ' companion.scope], 92);
for i = 1:numel(scopeLines)
    card = insertText(card, [24 y], scopeLines(i), ...
        'FontSize', 12, 'TextColor', [239 102 211], 'BoxOpacity', 0, ...
        'Font', 'Arial', 'AnchorPoint', 'LeftTop');
    y = y + 17;
end
assert(y <= 623, 'Text layout overflow for %s.', companion.file);
if size(card, 1) ~= side || size(card, 2) ~= side
    card = imresize(card, [side side], 'bicubic');
end
assert(ndims(card) == 3 && size(card, 3) == 3, ...
    'Rendered companion must be RGB.');
imwrite(card, outputFile);
end


function displayTitle = visualBilingualTitle(logicalTitle)
% insertText lays out glyphs left-to-right, so reverse only the Hebrew run.
parts = strsplit(char(logicalTitle), ' / ');
assert(numel(parts) == 2, ...
    'Particle title must use the fixed bilingual separator.');
displayTitle = [parts{1} ' / ' fliplr(parts{2})];
end


function base = buildBaseImage(anchorImage, sourceTensor, companionID, side)
anchor = imresize(im2single(anchorImage), [side side], 'bicubic');
anchorLuma = mean(anchor, 3);
channel = 1 + mod(companionID - 1, size(sourceTensor, 3));
texture = imresize(sourceTensor(:, :, channel), [side side], 'bicubic');
[xGrid, yGrid] = meshgrid(linspace(-1, 1, side));
glow = exp(-2.8 .* (xGrid.^2 + (yGrid+0.20).^2));
base = zeros(side, side, 3, 'single');
base(:, :, 1) = 0.025 + 0.10*anchor(:, :, 1) + 0.10*texture + 0.04*glow;
base(:, :, 2) = 0.035 + 0.09*anchor(:, :, 2) + 0.14*texture + 0.09*glow;
base(:, :, 3) = 0.105 + 0.22*anchorLuma + 0.22*texture + 0.18*glow;
base = min(1, max(0, base));
end


function image = overlayField(image, field, color, strength)
field = single(normalize01(field));
for channel = 1:3
    image(:, :, channel) = min(1, image(:, :, channel) + ...
        strength .* field .* single(color(channel)));
end
end


function image = drawMechanismRaster(image, companionID)
cyan = [45 225 255];
yellow = [255 211 62];
magenta = [239 76 206];
white = [244 248 255];
orange = [255 144 50];
switch companionID
    case 1
        x = linspace(80, 550, 90);
        image = drawArrow(image, [70 235], [565 235], white, 3);
        image = drawPolylineRaster(image, x, 215+42*sin((x-80)/42), cyan, 4);
        image = drawPolylineRaster(image, x, 255+34*cos((x-80)/42), magenta, 4);
        image = addLabel(image, [515 198], 'E, B, k', yellow);
    case 2
        x = linspace(70, 570, 90);
        image = drawPolylineRaster(image, x, 230+52*sin((x-70)/48), cyan, 4);
        image = drawArrow(image, [100 330], [265 330], yellow, 4);
        image = drawArrow(image, [365 330], [540 330], magenta, 4);
        image = addLabel(image, [120 300], 'lambda, nu', white);
        image = addLabel(image, [410 300], 'E, p', white);
    case 3
        for x = 105:85:530
            image = drawArrow(image, [x 330], [x 120], cyan, 3);
        end
        image = insertShape(image, 'FilledCircle', [320 235 28], ...
            'Color', magenta, 'Opacity', 0.92);
        image = addLabel(image, [303 219], '-e', white);
        image = drawArrow(image, [320 240], [320 340], yellow, 5);
        image = addLabel(image, [340 308], 'F', yellow);
    case 4
        theta = linspace(pi, 1.52*pi, 70);
        image = drawPolylineRaster(image, 315+180*cos(theta), ...
            290+180*sin(theta), cyan, 5);
        image = drawArrow(image, [315 290], [455 290], yellow, 4);
        image = drawArrow(image, [455 290], [455 160], magenta, 4);
        for x = 95:95:570
            image = addLabel(image, [x 115], 'x', white);
        end
    case 5
        lanes = [150 235 320];
        labels = {'nu_e', 'nu_mu', 'nu_tau'};
        colors = {cyan, magenta, orange};
        for i = 1:3
            image = insertShape(image, 'Line', [95 lanes(i) 545 lanes(i)], ...
                'Color', colors{i}, 'LineWidth', 5);
            image = addLabel(image, [25 lanes(i)-15], labels{i}, white);
        end
        image = drawArrow(image, [230 150], [330 235], yellow, 3);
        image = drawArrow(image, [330 235], [430 320], yellow, 3);
    case 6
        x = linspace(85, 565, 120);
        image = drawPolylineRaster(image, x, 215+65*sin((x-85)/58), cyan, 5);
        image = drawPolylineRaster(image, x, 215+65*sin((x-85)/58+2*pi/3), ...
            magenta, 5);
        image = drawArrow(image, [70 345], [575 345], white, 3);
        image = addLabel(image, [70 315], 'source', white);
        image = addLabel(image, [500 315], 'detector', white);
    case 7
        image = drawQuarkRows(image, cyan, magenta, white);
    case 8
        image = drawBaryonTriangles(image, cyan, magenta, yellow, white);
    case 9
        image = drawArrow(image, [80 230], [250 230], cyan, 5);
        image = drawArrow(image, [390 230], [560 230], magenta, 5);
        image = drawPolylineRaster(image, linspace(250,390,40), ...
            230+32*sin(linspace(0,5*pi,40)), orange, 5);
        image = addLabel(image, [278 275], 'gluon link', white);
    case 10
        image = insertShape(image, 'FilledCircle', [100 225 30], ...
            'Color', cyan, 'Opacity', 0.95);
        image = insertShape(image, 'FilledCircle', [540 225 30], ...
            'Color', magenta, 'Opacity', 0.95);
        for offset = -18:9:18
            image = insertShape(image, 'Line', [130 225+offset 510 225+offset], ...
                'Color', orange, 'LineWidth', max(2, round(6-abs(offset)/5)));
        end
        image = addLabel(image, [245 305], 'stored field energy', white);
    case 11
        image = insertShape(image, 'FilledCircle', [320 235 32], ...
            'Color', yellow, 'Opacity', 0.95);
        for angle = 0:pi/4:(2*pi-pi/4)
            image = drawArrow(image, [320+45*cos(angle), 235+45*sin(angle)], ...
                [320+155*cos(angle), 235+155*sin(angle)], cyan, 3);
        end
        image = addLabel(image, [304 218], '+e', [20 24 45]);
    case 12
        image = drawSingleTriangle(image, {'u','u','d'}, ...
            {cyan, cyan, magenta}, white, '+1');
    case 13
        image = drawSingleTriangle(image, {'u','d','d'}, ...
            {cyan, magenta, magenta}, white, '0');
    case 14
        image = insertShape(image, 'FilledCircle', [140 230 34], ...
            'Color', white, 'Opacity', 0.94);
        image = addLabel(image, [128 214], 'n', [15 20 45]);
        image = drawArrow(image, [178 230], [320 230], yellow, 4);
        targets = [475 140; 475 230; 475 320];
        labels = {'p','e-','anti-nu_e'};
        colors = {cyan, magenta, orange};
        for i = 1:3
            image = drawArrow(image, [320 230], targets(i,:), colors{i}, 4);
            image = addLabel(image, targets(i,:)+[8 -12], labels{i}, white);
        end
    case 15
        centers = [150 230; 320 230; 490 230];
        labels = {'W+','W-','Z0'};
        colors = {cyan, magenta, yellow};
        image = insertShape(image, 'Line', [150 230 490 230], ...
            'Color', white, 'LineWidth', 3);
        for i = 1:3
            image = insertShape(image, 'FilledCircle', ...
                [centers(i,:) 42], 'Color', colors{i}, 'Opacity', 0.94);
            image = addLabel(image, centers(i,:)+[-18 -14], labels{i}, [15 20 45]);
        end
    case 16
        vertices = [105 230; 280 230; 455 230];
        image = drawArrow(image, vertices(1,:), vertices(2,:), cyan, 4);
        image = drawArrow(image, vertices(2,:), vertices(3,:), magenta, 4);
        image = drawArrow(image, vertices(3,:), [565 155], yellow, 4);
        image = drawArrow(image, vertices(3,:), [565 305], orange, 4);
        labels = {'d','u','W-','e-','anti-nu_e'};
        positions = [80 205; 250 205; 425 205; 540 125; 490 320];
        for i = 1:numel(labels)
            image = addLabel(image, positions(i,:), labels{i}, white);
        end
    case 17
        for radius = 45:25:150
            shade = uint8(min(255, 80+radius));
            image = insertShape(image, 'Circle', [320 235 radius], ...
                'Color', [shade 70 210], 'LineWidth', 3);
        end
        image = drawArrow(image, [320 235], [430 170], yellow, 4);
        image = addLabel(image, [425 140], 'vacuum ring', white);
    case 18
        image = insertShape(image, 'Circle', [320 235 120], ...
            'Color', magenta, 'LineWidth', 5);
        image = drawArrow(image, [320 235], [430 170], yellow, 5);
        image = insertShape(image, 'FilledCircle', [430 170 20], ...
            'Color', cyan, 'Opacity', 0.95);
        image = addLabel(image, [440 145], 'H excitation', white);
    case 19
        image = drawNucleusCluster(image, cyan, magenta, white);
        image = drawArrow(image, [420 235], [555 235], yellow, 4);
        image = addLabel(image, [480 200], 'A = Z + N', white);
    case 20
        starts = [90 130; 90 230; 90 330];
        startColors = {cyan, magenta, cyan};
        for i = 1:3
            image = insertShape(image, 'FilledCircle', [starts(i,:) 22], ...
                'Color', startColors{i}, 'Opacity', 0.94);
            image = drawArrow(image, starts(i,:)+[25 0], [330 230], yellow, 3);
        end
        image = drawNucleusClusterAt(image, [400 230], cyan, magenta);
        image = drawArrow(image, [445 190], [560 120], orange, 4);
        image = addLabel(image, [500 90], 'E_b', white);
end
end


function image = drawQuarkRows(image, cyan, magenta, white)
upLabels = {'u +2/3','c +2/3','t +2/3'};
downLabels = {'d -1/3','s -1/3','b -1/3'};
for i = 1:3
    x = 120 + (i-1)*190;
    image = insertShape(image, 'FilledCircle', [x 175 38], ...
        'Color', cyan, 'Opacity', 0.92);
    image = insertShape(image, 'FilledCircle', [x 290 38], ...
        'Color', magenta, 'Opacity', 0.92);
    image = addLabel(image, [x-34 160], upLabels{i}, white);
    image = addLabel(image, [x-34 275], downLabels{i}, white);
end
end


function image = drawBaryonTriangles(image, cyan, magenta, yellow, white)
image = drawTriangleAt(image, [180 235], {'u','u','d'}, ...
    {cyan,cyan,magenta}, white);
image = drawTriangleAt(image, [455 235], {'u','d','d'}, ...
    {cyan,magenta,magenta}, white);
image = addLabel(image, [145 330], 'proton +1', yellow);
image = addLabel(image, [415 330], 'neutron 0', yellow);
end


function image = drawSingleTriangle(image, labels, colors, textColor, result)
image = drawTriangleAt(image, [320 230], labels, colors, textColor);
image = addLabel(image, [285 330], ['charge ' result], textColor);
end


function image = drawTriangleAt(image, center, labels, colors, textColor)
points = center + [-75 55; 75 55; 0 -75];
image = insertShape(image, 'Line', [points(1,:) points(2,:); ...
    points(2,:) points(3,:); points(3,:) points(1,:)], ...
    'Color', textColor, 'LineWidth', 3);
for i = 1:3
    image = insertShape(image, 'FilledCircle', [points(i,:) 28], ...
        'Color', colors{i}, 'Opacity', 0.95);
    image = addLabel(image, points(i,:)+[-8 -12], labels{i}, [15 20 45]);
end
end


function image = drawNucleusCluster(image, cyan, magenta, white)
image = drawNucleusClusterAt(image, [285 235], cyan, magenta);
image = addLabel(image, [245 330], 'protons + neutrons', white);
end


function image = drawNucleusClusterAt(image, center, cyan, magenta)
offsets = [-45 -35; 0 -45; 45 -30; -48 15; 0 5; 48 15; -25 50; 28 52];
for i = 1:size(offsets, 1)
    color = cyan;
    if mod(i, 2) == 0
        color = magenta;
    end
    image = insertShape(image, 'FilledCircle', ...
        [center+offsets(i,:) 27], 'Color', color, 'Opacity', 0.94);
end
end


function image = drawPolylineRaster(image, x, y, color, lineWidth)
segments = [x(1:end-1).' y(1:end-1).' x(2:end).' y(2:end).'];
image = insertShape(image, 'Line', segments, ...
    'Color', color, 'LineWidth', lineWidth);
end


function image = drawArrow(image, startPoint, endPoint, color, lineWidth)
image = insertShape(image, 'Line', [startPoint endPoint], ...
    'Color', color, 'LineWidth', lineWidth);
direction = double(endPoint - startPoint);
direction = direction ./ max(norm(direction), eps);
normal = [-direction(2) direction(1)];
base = double(endPoint) - 18*direction;
head1 = base + 9*normal;
head2 = base - 9*normal;
image = insertShape(image, 'Line', [endPoint head1; endPoint head2], ...
    'Color', color, 'LineWidth', lineWidth);
end


function image = addLabel(image, position, label, color)
image = insertText(image, position, label, 'FontSize', 16, ...
    'TextColor', color, 'BoxOpacity', 0, 'Font', 'Arial', ...
    'AnchorPoint', 'LeftTop');
end


function lines = wrapTextLines(value, maximumCharacters)
words = split(strtrim(string(value)));
lines = strings(0, 1);
current = "";
for i = 1:numel(words)
    candidate = strtrim(current + " " + words(i));
    if strlength(candidate) > maximumCharacters && strlength(current) > 0
        lines(end+1, 1) = current; %#ok<AGROW>
        current = words(i);
    else
        current = candidate;
    end
end
if strlength(current) > 0
    lines(end+1, 1) = current;
end
end


function relativeFile = writeContactSheet(cfg, artifacts, folders)
tile = cfg.imageSize;
sheet = zeros(5*tile, 6*tile, 3, 'uint8');
for i = 1:10
    row = ceil(i/2);
    block = mod(i-1, 2);
    files = [string(artifacts(i).anchor); artifacts(i).companions(:)];
    for j = 1:3
        image = imread(fullfile(cfg.stagingRoot, files(j)));
        image = imresize(image, [tile tile], 'bicubic');
        rowRange = (row-1)*tile + (1:tile);
        column = block*3 + j;
        columnRange = (column-1)*tile + (1:tile);
        sheet(rowRange, columnRange, :) = image;
    end
end
relativeFile = fullfile('06_contact_sheets', ...
    'ParticleFoundations_10Triplets.png');
imwrite(sheet, fullfile(cfg.stagingRoot, relativeFile));
assert(isfile(fullfile(folders.contacts, ...
    'ParticleFoundations_10Triplets.png')));
end


function manifests = writeManifests(cfg, particles, references, ...
        tensorInventory, sourceNames, artifacts, anchorHashes, tensorFiles, ...
        contactSheet, training, folders, sourceSnapshot, startTime)
index = particleCompanionIndex(particles, artifacts);
writetable(index, fullfile(folders.manifests, 'ParticleCompanionIndex.csv'));

dictionary = humanPhysicsSymbolDictionary(particles);
writetable(dictionary, fullfile(folders.manifests, ...
    'HumanPhysicsSymbolDictionary.csv'));
writetable(tensorInventory, fullfile(folders.manifests, ...
    'H5TensorInventory.csv'));
writetable(canonicalVisualSourceTable(sourceNames, cfg), ...
    fullfile(folders.manifests, 'CanonicalVisualSourceChannels.csv'));
writetable(references, fullfile(folders.manifests, 'SourceReferences.csv'));
writetable(tensorShapeTable(), fullfile(folders.manifests, 'TensorShapes.csv'));

wolfram = struct;
wolfram.role = 'symbolic consistency only; not scientific source validation';
wolfram.semantic_query_result = 'No Results Found; not accepted as source validation';
wolfram.proton_uud_charge_sum_in_units_of_e = 1;
wolfram.neutron_udd_charge_sum_in_units_of_e = 0;
wolfram.photon_E_minus_pc_residual = 0;
wolfram.nuclide_mass_number_residual = 0;
wolfram.magnetic_radius_force_balance_residual = 0;
wolfram.free_neutron_beta_charge_residual = 0;
wolfram.weak_vertex_charge_residual = 0;
wolfram.higgs_yukawa_mass_residual = 0;

summary = struct;
summary.version = cfg.version;
summary.subject = 'foundational particle visual learning';
summary.output_root = cfg.outputRoot;
summary.canonical_h5 = cfg.canonicalH5;
summary.canonical_sha256 = cfg.expectedH5SHA256;
summary.anchor_count = 10;
summary.generated_companion_count = 20;
summary.layer_file_count = 60;
summary.h5_tensor_extract_count = 27;
summary.canonical_visual_source_channel_count = 12;
summary.rendered_text = true;
summary.structural_notation_required = true;
summary.anchor_images_shape = size(training.anchor_images_uint8);
summary.companion_images_shape = size(training.companion_images_uint8);
summary.notation_masks_shape = size(training.notation_masks_single);
summary.relation_masks_shape = size(training.relation_masks_single);
summary.carrier_fields_shape = size(training.carrier_fields_single);
summary.canonical_visual_sources_shape = ...
    size(training.canonical_visual_sources_single);
summary.concept_companion_codebook_shape = ...
    size(training.concept_companion_codebook_single);
summary.triplet_adjacency_shape = size(training.triplet_adjacency_single);
summary.training_mat = tensorFiles.mat;
summary.training_h5 = tensorFiles.h5;
summary.contact_sheet = contactSheet;
summary.source_bundle_file_count = height(sourceSnapshot);
summary.existing_files_changed = 0;
summary.h5_semantic_policy = cfg.semanticPolicy;
summary.wolfram_calibration = wolfram;
summary.elapsed_seconds = toc(startTime);
writeText(fullfile(folders.manifests, 'RunSummary.json'), ...
    jsonencode(summary, PrettyPrint=true));

summaryText = sprintf([ ...
    'YEHOSHUA ORCH PARTICLE FOUNDATIONS EXTENSION V1\n' ...
    'canonical_sha256=%s\nanchor_count=10\ncompanion_count=20\n' ...
    'layer_file_count=60\nh5_extract_count=27\n' ...
    'canonical_visual_source_channels=12\nrendered_text=true\n' ...
    'structural_notation=true\nexisting_files_changed=0\n' ...
    'elapsed_seconds=%.6f\nsemantic_policy=%s\n'], ...
    cfg.expectedH5SHA256, toc(startTime), cfg.semanticPolicy);
writeText(fullfile(folders.manifests, 'RunSummary.txt'), summaryText);

manifests = struct;
manifests.particleCompanionIndex = fullfile('05_manifests', ...
    'ParticleCompanionIndex.csv');
manifests.symbolDictionary = fullfile('05_manifests', ...
    'HumanPhysicsSymbolDictionary.csv');
manifests.h5Inventory = fullfile('05_manifests', 'H5TensorInventory.csv');
manifests.sourceReferences = fullfile('05_manifests', 'SourceReferences.csv');
manifests.tensorShapes = fullfile('05_manifests', 'TensorShapes.csv');
manifests.runSummary = fullfile('05_manifests', 'RunSummary.json');
manifests.anchorHashes = fullfile('00_integrity', 'SourceAnchorHashes.csv');
manifests.contactSheet = contactSheet;
assert(all(anchorHashes.hash_match), 'Anchor hash manifest contains a mismatch.');
end


function index = particleCompanionIndex(particles, artifacts)
rowCount = 20;
order = zeros(rowCount, 1);
anchorID = zeros(rowCount, 1);
anchorFile = strings(rowCount, 1);
bilingualTitle = strings(rowCount, 1);
companionIndex = zeros(rowCount, 1);
fileName = strings(rowCount, 1);
relativeFile = strings(rowCount, 1);
level = strings(rowCount, 1);
formula = strings(rowCount, 1);
scopeLabel = strings(rowCount, 1);
definition = strings(rowCount, 1);
structuralTokens = strings(rowCount, 1);
tokenXYNormalizedJSON = strings(rowCount, 1);
sourceReferenceIDs = strings(rowCount, 1);
renderedText = true(rowCount, 1);
structuralNotation = true(rowCount, 1);
notationMaskFile = strings(rowCount, 1);
relationMaskFile = strings(rowCount, 1);
carrierFieldFile = strings(rowCount, 1);

row = 0;
for i = 1:10
    for j = 1:2
        row = row + 1;
        companion = particles(i).companions(j);
        order(row) = row;
        anchorID(row) = particles(i).id;
        anchorFile(row) = string(particles(i).anchorFile);
        bilingualTitle(row) = string(particles(i).title);
        companionIndex(row) = j;
        fileName(row) = string(companion.file);
        relativeFile(row) = artifacts(i).companions(j);
        level(row) = string(companion.level);
        formula(row) = string(companion.formula);
        scopeLabel(row) = string(companion.scope);
        definition(row) = string(companion.definition);
        structuralTokens(row) = strjoin(companion.tokens, ';');
        tokenXYNormalizedJSON(row) = string(jsonencode( ...
            artifacts(i).tokenCoordinates{j}));
        sourceReferenceIDs(row) = string(companion.sourceIDs);
        notationMaskFile(row) = artifacts(i).notationMasks(j);
        relationMaskFile(row) = artifacts(i).relationMasks(j);
        carrierFieldFile(row) = artifacts(i).carrierFields(j);
    end
end
index = table(order, anchorID, anchorFile, bilingualTitle, ...
    companionIndex, fileName, relativeFile, level, formula, scopeLabel, ...
    definition, structuralTokens, tokenXYNormalizedJSON, ...
    sourceReferenceIDs, renderedText, structuralNotation, ...
    notationMaskFile, relationMaskFile, carrierFieldFile, ...
    'VariableNames', {'order', 'anchor_id', 'anchor_file', ...
    'bilingual_title', 'companion_index', 'file_name', 'relative_file', ...
    'level', 'formula', 'scope_label', 'definition', ...
    'structural_tokens', 'token_xy_normalized_json', ...
    'source_reference_ids', 'rendered_text', 'structural_notation', ...
    'notation_mask_file', 'relation_mask_file', 'carrier_field_file'});
end


function dictionary = humanPhysicsSymbolDictionary(particles)
allTokens = strings(0, 1);
for i = 1:10
    for j = 1:2
        allTokens = [allTokens; particles(i).companions(j).tokens(:)]; %#ok<AGROW>
    end
end
token = unique(allTokens, 'stable');
id = (1:numel(token)).';
geometryType = strings(numel(token), 1);
for i = 1:numel(token)
    key = lower(token(i));
    if ismember(key, ["equals","plus","minus","times","perpendicular","arrow"])
        geometryType(i) = 'operator_polyline';
    elseif ismember(key, ["theta","phi","q","e","b"])
        geometryType(i) = 'arc_and_stroke_glyph';
    else
        geometryType(i) = 'human_like_polyline_glyph';
    end
end
renderMethod = repmat("manual line and arc geometry", numel(token), 1);
semanticRole = repmat("structural notation token", numel(token), 1);
captionOnly = false(numel(token), 1);
dictionary = table(id, token, geometryType, renderMethod, semanticRole, ...
    captionOnly, 'VariableNames', {'id', 'token', 'geometry_type', ...
    'render_method', 'semantic_role', 'caption_only'});
end


function channels = canonicalVisualSourceTable(names, cfg)
channel = (1:12).';
sourceName = names;
datasetPath = [
    "/n_5_composite_field_1000x1000/data"
    "/n_5_composite_field_1000x1000/data"
    "/n_5_composite_field_1000x1000/data"
    "/n_6_field_maps_v3_800x800/chamber_field/data"
    "/n_6_field_maps_v3_800x800/fuchsian_tiling/data"
    "/n_6_field_maps_v3_800x800/ginibre_field/data"
    "/n_6_field_maps_v3_800x800/modular_eta/data"
    "/n_6_field_maps_v3_800x800/weyl_field/data"
    "/n_2_e8_lattice/laplacian_modes/modes"
    "/n_3_defect_topology/charge + /n_3_defect_topology/pos"
    "/n_4_geodesic_field/vel"
    "/n_4_geodesic_field/curl"];
transformation = [
    "reshape channel 1 to 1000x1000; normalize; resize"
    "reshape channel 2 to 1000x1000; normalize; resize"
    "reshape channel 3 to 1000x1000; normalize; resize"
    "reshape channel 1 to 800x800; normalize; resize"
    "reshape channel 1 to 800x800; normalize; resize"
    "reshape channel 1 to 800x800; normalize; resize"
    "reshape channel 1 to 800x800; normalize; resize"
    "reshape channel 1 to 800x800; normalize; resize"
    "grid first Laplacian mode by xy; normalize"
    "grid charge values by defect positions; normalize"
    "hypot of velocity components; reshape 220x220; normalize"
    "reshape curl to 220x220; normalize"];
semanticPolicy = repmat(string(cfg.semanticPolicy), 12, 1);
channels = table(channel, sourceName, datasetPath, transformation, ...
    semanticPolicy, 'VariableNames', {'channel', 'source_name', ...
    'dataset_path', 'transformation', 'semantic_policy'});
end


function shapes = tensorShapeTable()
name = [
    "anchor_images_uint8"
    "companion_images_uint8"
    "notation_masks_single"
    "relation_masks_single"
    "carrier_fields_single"
    "canonical_visual_sources_single"
    "concept_companion_codebook_single"
    "triplet_adjacency_single"];
matlabShape = [
    "[224 224 3 10]"
    "[224 224 3 2 10]"
    "[224 224 2 10]"
    "[224 224 2 10]"
    "[224 224 2 10]"
    "[64 64 12]"
    "[10 20]"
    "[30 30]"];
h5Dataset = [
    "/images/anchors"
    "/images/companions"
    "/masks/notation"
    "/masks/relation"
    "/fields/carriers"
    "/canonical/visual_sources"
    "/codebooks/concept_companion"
    "/relations/triplet_adjacency"];
shapes = table(name, matlabShape, h5Dataset, ...
    'VariableNames', {'name', 'matlab_shape', 'h5_dataset'});
end


function results = validateCompletedBundle(cfg, particles, datasets)
validation = validateBundleAtRoot(cfg, particles, datasets, ...
    cfg.outputRoot, true);
results = struct;
results.mode = 'validate_only';
results.outputRoot = cfg.outputRoot;
results.canonicalSHA256 = sha256File(cfg.canonicalH5);
results.counts = struct('anchors', 10, 'companions', 20, ...
    'layerFiles', 60, 'h5Extracts', 27, 'sourceChannels', 12);
results.tensorShapes = expectedTensorShapes();
results.validation = validation;
results.outputFilesWritten = 0;
results.allChecksPass = validation.all_checks_pass;
assert(results.allChecksPass, 'Completed bundle validation failed.');
end


function validation = validateBundleAtRoot(cfg, particles, datasets, ...
        root, requireValidationFile)
validation = struct;
validation.canonical_hash_match = strcmpi( ...
    sha256File(cfg.canonicalH5), cfg.expectedH5SHA256);
validation.source_anchor_hashes_match = true;
validation.anchor_copies_exist = true;
validation.companion_count_match = true;
validation.companion_dimensions_rgb = true;
validation.companions_nonblank = true;
validation.full_resolution_text_regions_nonblank = true;
validation.layer_count_match = true;
validation.notation_masks_nonempty = true;
validation.relation_masks_nonempty = true;
validation.carrier_fields_nonempty = true;

indexPath = fullfile(root, '05_manifests', 'ParticleCompanionIndex.csv');
indexOptions = detectImportOptions(indexPath, 'TextType', 'string');
indexOptions = setvartype(indexOptions, 'source_reference_ids', 'string');
index = readtable(indexPath, indexOptions);
validation.companion_count_match = height(index) == 20;
layerFiles = strings(0, 1);
for i = 1:numel(particles)
    sourceAnchor = fullfile(cfg.anchorRoot, particles(i).anchorFile);
    validation.source_anchor_hashes_match = ...
        validation.source_anchor_hashes_match && strcmpi( ...
        sha256File(sourceAnchor), particles(i).expectedSHA256);
    anchorCopy = fullfile(root, '01_particle_learning_triplets', ...
        sprintf('%02d_%s', particles(i).id, particles(i).slug), ...
        '00_anchor_source.png');
    validation.anchor_copies_exist = validation.anchor_copies_exist && ...
        isfile(anchorCopy) && strcmpi(sha256File(anchorCopy), ...
        particles(i).expectedSHA256);
end

for row = 1:height(index)
    companionFile = fullfile(root, index.relative_file(row));
    if ~isfile(companionFile)
        validation.companion_dimensions_rgb = false;
        validation.companions_nonblank = false;
        validation.full_resolution_text_regions_nonblank = false;
    else
        image = imread(companionFile);
        validation.companion_dimensions_rgb = ...
            validation.companion_dimensions_rgb && ...
            isequal(size(image), [640 640 3]);
        validation.companions_nonblank = validation.companions_nonblank && ...
            std(double(image(:))) > 4;
        titleRegion = image(12:82, 18:620, :);
        formulaRegion = image(392:624, 18:622, :);
        validation.full_resolution_text_regions_nonblank = ...
            validation.full_resolution_text_regions_nonblank && ...
            std(double(titleRegion(:))) > 4 && ...
            std(double(formulaRegion(:))) > 4;
    end
    rowLayers = [index.notation_mask_file(row); ...
        index.relation_mask_file(row); index.carrier_field_file(row)];
    layerFiles = [layerFiles; rowLayers]; %#ok<AGROW>
    for kind = 1:3
        layerPath = fullfile(root, rowLayers(kind));
        if ~isfile(layerPath)
            validation.notation_masks_nonempty = false;
            validation.relation_masks_nonempty = false;
            validation.carrier_fields_nonempty = false;
            continue;
        end
        layer = im2single(imread(layerPath));
        layerOK = isequal(size(layer), [640 640]) && nnz(layer > 0.05) > 80;
        if kind == 1
            validation.notation_masks_nonempty = ...
                validation.notation_masks_nonempty && layerOK;
        elseif kind == 2
            validation.relation_masks_nonempty = ...
                validation.relation_masks_nonempty && layerOK;
        else
            validation.carrier_fields_nonempty = ...
                validation.carrier_fields_nonempty && layerOK;
        end
    end
end
validation.layer_count_match = numel(unique(layerFiles)) == 60;

inventoryPath = fullfile(root, '05_manifests', 'H5TensorInventory.csv');
inventory = readtable(inventoryPath, 'TextType', 'string');
validation.h5_extract_count_match = height(inventory) == numel(datasets);
validation.h5_extract_files_exist = true;
validation.h5_extract_hashes_match = true;
validation.h5_extracts_finite = all(inventory.nan_count == 0 & ...
    inventory.inf_count == 0);
for i = 1:height(inventory)
    extractFile = fullfile(root, inventory.output_file(i));
    validation.h5_extract_files_exist = ...
        validation.h5_extract_files_exist && isfile(extractFile);
    if isfile(extractFile)
        validation.h5_extract_hashes_match = ...
            validation.h5_extract_hashes_match && strcmpi( ...
            sha256File(extractFile), inventory.mat_file_sha256(i));
    else
        validation.h5_extract_hashes_match = false;
    end
end

matFile = fullfile(root, '04_training_tensors', ...
    'OrchParticleFoundationsLearningTensors.mat');
h5File = fullfile(root, '04_training_tensors', ...
    'OrchParticleFoundationsLearningTensors.h5');
validation.training_mat_exists = isfile(matFile);
validation.training_h5_exists = isfile(h5File);
loaded = load(matFile, 'training');
training = loaded.training;
validation.anchor_tensor_shape = isequal( ...
    size(training.anchor_images_uint8), [224 224 3 10]);
validation.companion_tensor_shape = isequal( ...
    size(training.companion_images_uint8), [224 224 3 2 10]);
validation.notation_tensor_shape = isequal( ...
    size(training.notation_masks_single), [224 224 2 10]);
validation.relation_tensor_shape = isequal( ...
    size(training.relation_masks_single), [224 224 2 10]);
validation.carrier_tensor_shape = isequal( ...
    size(training.carrier_fields_single), [224 224 2 10]);
validation.source_tensor_shape = isequal( ...
    size(training.canonical_visual_sources_single), [64 64 12]);
validation.codebook_shape = isequal( ...
    size(training.concept_companion_codebook_single), [10 20]);
validation.adjacency_shape = isequal( ...
    size(training.triplet_adjacency_single), [30 30]);
validation.training_tensors_finite = allFiniteTraining(training);
validation.codebook_exact = isequal( ...
    training.concept_companion_codebook_single, expectedCodebook());
validation.triplet_adjacency_exact = isequal( ...
    training.triplet_adjacency_single, expectedAdjacency());

h5Paths = tensorShapeTable();
validation.training_h5_shapes_match = true;
for i = 1:height(h5Paths)
    info = h5info(h5File, h5Paths.h5_dataset(i));
    expected = parseShape(h5Paths.matlab_shape(i));
    validation.training_h5_shapes_match = ...
        validation.training_h5_shapes_match && ...
        isequal(double(info.Dataspace.Size), double(expected));
end

references = readtable(fullfile(root, '05_manifests', ...
    'SourceReferences.csv'), 'TextType', 'string');
validation.source_references_complete = height(references) == 9 && ...
    all(strlength(references.title) > 0) && ...
    all(strlength(references.section) > 0) && ...
    all(startsWith(references.url_or_doi, "http")) && ...
    all(strlength(references.formula_scope) > 0);
validation.formula_scopes_complete = all(strlength(index.formula) > 0) && ...
    all(strlength(index.scope_label) > 0) && ...
    all(strlength(index.source_reference_ids) > 0) && ...
    all(index.rendered_text) && all(index.structural_notation);

contact = imread(fullfile(root, '06_contact_sheets', ...
    'ParticleFoundations_10Triplets.png'));
validation.contact_sheet_shape = isequal(size(contact), [3200 3840 3]);
validation.contact_sheet_nonblank = std(double(contact(:))) > 4;

snapshotReference = readtable(fullfile(root, '00_integrity', ...
    'SourceV1Snapshot.csv'), 'TextType', 'string');
snapshotNow = snapshotTree(cfg.sourceBundleRoot);
validation.source_v1_unchanged = compareSnapshots(snapshotReference, snapshotNow);
validation.existing_files_changed_zero = validation.source_v1_unchanged;

validation.manifests_complete = all(isfile([
    string(fullfile(root, '00_integrity', 'CanonicalIntegrity.json'))
    string(fullfile(root, '00_integrity', 'SourceAnchorHashes.csv'))
    string(fullfile(root, '05_manifests', 'ParticleCompanionIndex.csv'))
    string(fullfile(root, '05_manifests', 'HumanPhysicsSymbolDictionary.csv'))
    string(fullfile(root, '05_manifests', 'H5TensorInventory.csv'))
    string(fullfile(root, '05_manifests', 'CanonicalVisualSourceChannels.csv'))
    string(fullfile(root, '05_manifests', 'SourceReferences.csv'))
    string(fullfile(root, '05_manifests', 'TensorShapes.csv'))
    string(fullfile(root, '05_manifests', 'RunSummary.json'))
    string(fullfile(root, '05_manifests', 'RunSummary.txt'))]));

validation.output_validation_present = true;
validation.stored_validation_pass = true;
if requireValidationFile
    validationFile = fullfile(root, '00_integrity', 'OutputValidation.json');
    validation.output_validation_present = isfile(validationFile);
    if validation.output_validation_present
        stored = jsondecode(fileread(validationFile));
        validation.stored_validation_pass = isfield(stored, ...
            'all_checks_pass') && logical(stored.all_checks_pass);
    else
        validation.stored_validation_pass = false;
    end
end

validation.automated_full_resolution_visual_qa = ...
    validation.companion_dimensions_rgb && validation.companions_nonblank && ...
    validation.full_resolution_text_regions_nonblank && ...
    validation.notation_masks_nonempty && validation.relation_masks_nonempty;
validation.all_checks_pass = allLogicalScalarFields(validation);
end


function pass = allFiniteTraining(training)
fields = fieldnames(training);
pass = true;
for i = 1:numel(fields)
    value = training.(fields{i});
    if isnumeric(value)
        pass = pass && all(isfinite(double(value(:))));
    end
end
end


function codebook = expectedCodebook()
codebook = zeros(10, 20, 'single');
for i = 1:10
    codebook(i, (2*i-1):(2*i)) = 1;
end
end


function adjacency = expectedAdjacency()
adjacency = zeros(30, 30, 'single');
for i = 1:10
    indices = (3*i-2):(3*i);
    adjacency(indices, indices) = single(ones(3)-eye(3));
end
end


function shape = parseShape(textValue)
numbers = sscanf(char(erase(erase(textValue, '['), ']')), '%f').';
shape = numbers;
end


function pass = allLogicalScalarFields(structure)
names = fieldnames(structure);
pass = true;
for i = 1:numel(names)
    value = structure.(names{i});
    if islogical(value) && isscalar(value)
        pass = pass && value;
    end
end
end


function shapes = expectedTensorShapes()
shapes = struct;
shapes.anchorImages = [224 224 3 10];
shapes.companionImages = [224 224 3 2 10];
shapes.notationMasks = [224 224 2 10];
shapes.relationMasks = [224 224 2 10];
shapes.carrierFields = [224 224 2 10];
shapes.canonicalVisualSources = [64 64 12];
shapes.conceptCompanionCodebook = [10 20];
shapes.tripletAdjacency = [30 30];
end


function order = tripletEntityOrder(particles)
order = strings(30, 1);
row = 0;
for i = 1:10
    row = row + 1;
    order(row) = sprintf('%02d_%s_anchor', i, particles(i).slug);
    for j = 1:2
        row = row + 1;
        order(row) = sprintf('%02d_%s_companion_%d', ...
            i, particles(i).slug, j);
    end
end
end


function writeH5Dataset(filePath, datasetPath, value, resetFile)
if resetFile && isfile(filePath)
    delete(filePath);
end
dataSize = size(value);
if numel(dataSize) >= 3
    chunkLimit = [64 64 3 ones(1, numel(dataSize)-3)];
else
    chunkLimit = 64 * ones(size(dataSize));
end
chunkSize = max(ones(size(dataSize)), min(dataSize, chunkLimit));
h5create(filePath, datasetPath, dataSize, 'Datatype', class(value), ...
    'ChunkSize', chunkSize, 'Deflate', 4);
h5write(filePath, datasetPath, value);
end


function snapshot = snapshotTree(root)
listing = dir(fullfile(root, '**', '*'));
listing = listing(~[listing.isdir]);
relativePath = strings(numel(listing), 1);
bytes = zeros(numel(listing), 1);
sha256 = strings(numel(listing), 1);
for i = 1:numel(listing)
    folderSuffix = extractAfter(string(listing(i).folder), strlength(root));
    folderSuffix = strip(folderSuffix, 'left', filesep);
    relativePath(i) = string(fullfile(folderSuffix, listing(i).name));
    bytes(i) = listing(i).bytes;
    sha256(i) = sha256File(fullfile(listing(i).folder, listing(i).name));
end
snapshot = table(relativePath, bytes, sha256, ...
    'VariableNames', {'relative_path', 'bytes', 'sha256'});
snapshot = sortrows(snapshot, 'relative_path');
end


function pass = compareSnapshots(first, second)
first = sortrows(first, 'relative_path');
second = sortrows(second, 'relative_path');
pass = height(first) == height(second) && ...
    isequal(string(first.relative_path), string(second.relative_path)) && ...
    isequal(double(first.bytes), double(second.bytes)) && ...
    isequal(string(first.sha256), string(second.sha256));
end


function exists = pathExists(path)
exists = isfile(path) || isfolder(path);
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
input = normalize01(input);
output = single(imresize(input, [side side], 'bilinear'));
end


function grid = gridPointValues(points, values, side)
x = normalize01(points(1, :));
y = normalize01(points(2, :));
xIndex = min(side, max(1, floor(x .* (side-1)) + 1));
yIndex = min(side, max(1, floor(y .* (side-1)) + 1));
counts = accumarray([yIndex(:), xIndex(:)], 1, [side side], @sum, 0);
sums = accumarray([yIndex(:), xIndex(:)], values(:), ...
    [side side], @sum, 0);
grid = normalize01(sums ./ max(counts, 1));
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
escapedPath = strrep(filePath, '"', '\"');
command = sprintf('/usr/bin/shasum -a 256 "%s"', escapedPath);
[status, output] = system(command);
assert(status == 0, 'SHA-256 calculation failed for %s.', filePath);
hex = regexp(output, '^[0-9a-fA-F]{64}', 'match', 'once');
assert(~isempty(hex), 'SHA-256 output could not be parsed.');
hex = lower(hex);
end
