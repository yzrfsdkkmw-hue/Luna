function result = YEHOSHUA_SSOT_EXISTING_REGULARITY_DISCOVERY_v3_FINAL_COHERENCE(varargin)
% YEHOSHUA_SSOT_EXISTING_REGULARITY_DISCOVERY_v3_FINAL_COHERENCE
%
% Final single-file MATLAB implementation for discovery of stable mathematical
% regularities inside the unified H5 source of truth.
%
% Runtime input policy:
%   - Reads only the unified SSOT H5 file.
%   - Does not read PNG/JPEG/CSV/derived-H5/weight files.
%   - Uses /n_5_composite_field_1000x1000/data as the primary observed field.
%   - Uses other mathematical datasets inside the same H5 only as internal
%     witnesses/calibrators.
%
% Usage:
%   result = YEHOSHUA_SSOT_EXISTING_REGULARITY_DISCOVERY_v3_FINAL_COHERENCE();
%
% Optional configuration override:
%   cfg = struct;
%   cfg.requireHashMatch = false;
%   result = YEHOSHUA_SSOT_EXISTING_REGULARITY_DISCOVERY_v3_FINAL_COHERENCE(cfg);
%
% The function writes numerical artifacts first. Figures are views of arrays
% already saved numerically and are rejected when blank or structurally invalid.

    cfg = defaultConfiguration();
    if nargin >= 1
        if ~isstruct(varargin{1})
            error('Optional input must be a configuration struct.');
        end
        cfg = mergeStructRecursive(cfg, varargin{1});
    end

    timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    outputDir = fullfile(cfg.outputParent, ...
        "YEHOSHUA_SSOT_EXISTING_REGULARITY_DISCOVERY_v3_FINAL_COHERENCE_output_" + string(timestamp));
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    logPath = fullfile(outputDir, '20_run_log.txt');
    logFid = fopen(logPath, 'w');
    if logFid < 0
        error('Could not open run log: %s', logPath);
    end
    logCleanup = onCleanup(@() fclose(logFid)); 

    logLine(logFid, 'Run started: %s', timestamp);
    logLine(logFid, 'SSOT file: %s', cfg.ssotFile);
    logLine(logFid, 'Primary dataset: %s', cfg.primaryDataset);

    try
        %% 1. Lock source, verify hash, inventory, registry, and shape/index audit
        ssot = lockUnifiedH5(cfg, logFid);
        inventory = enumerateH5Datasets(ssot.info);
        registry = buildSSOTDatasetRegistry(inventory, cfg);

        writeJSON(fullfile(outputDir, '00_ssot_registry.json'), ...
            struct('file', ssot.file, 'sha256', ssot.sha256, ...
                   'expected_sha256', cfg.expectedSHA256, ...
                   'hash_match', ssot.hashMatch, ...
                   'dataset_count', height(registry), ...
                   'datasets', tableToStructArray(registry)));

        writetable(registry, fullfile(outputDir, '02_dataset_role_registry.csv'));

        audit = auditShapesAndIndexMappings(registry, cfg, logFid);
        writeJSON(fullfile(outputDir, '01_shape_index_audit.json'), audit);

        %% 2. Read primary field and internal reference datasets
        [X, raw] = readPrimaryCompositeField(ssot.file, cfg, audit, logFid);
        references = readInternalReferenceDatasets(ssot.file, registry, cfg, logFid);

        %% 3. Intrinsic field family
        fields = buildIntrinsicFieldFamily(X, raw, cfg, logFid);

        %% 4. Coarse/fine temporal hierarchy and blind TimeKernel
        coarse = discoverCoarseSalience(raw, fields, cfg, logFid);
        coarseEvents = discoverCoarseSalienceEvents(coarse, cfg);
        fine = discoverHighResolutionSalience(raw, fields, coarseEvents, cfg, logFid);
        timeKernel = discoverTimeKernelBlind(fine, cfg, logFid);

        anchors = extractHighConfidenceAnchorLayer(fine, cfg, logFid);
        events = extractTimeKernelEventLayer(timeKernel, cfg, logFid);
        alignment = alignAnchorAndEventLayers(anchors, events, cfg);

        writetable(alignment, fullfile(outputDir, '03_coarse_fine_event_alignment.csv'));
        writetable(anchors, fullfile(outputDir, '04_anchor_layer_12.csv'));
        writetable(events, fullfile(outputDir, '05_event_layer_53.csv'));

        %% 5. Complex anchor/phase maps
        phaseMaps = buildComplexAnchorPhaseMaps(anchors, events, alignment, ...
            cfg.primaryShape(1:2), cfg, logFid);

        writePhaseH5Artifacts(outputDir, phaseMaps);

        %% 6. Topology: ridges, phase cores, Y junctions
        topology = discoverCoresRidgesAndYJunctions(fields, phaseMaps, cfg, logFid);

        %% 7. Validated hierarchical graph
        graphData = buildValidatedHierarchicalGraph(anchors, events, topology, ...
            references, cfg, logFid);

        writetable(graphData.nodes, fullfile(outputDir, '10_hierarchical_graph_nodes.csv'));
        writetable(graphData.edges, fullfile(outputDir, '11_hierarchical_graph_edges.csv'));
        save(fullfile(outputDir, '12_graph_laplacian.mat'), ...
            'graphData', '-v7.3');
        writeJSON(fullfile(outputDir, '13_graph_validity.json'), graphData.validity);

        %% 8. Intrinsic geometry, manifold, knowledge quanta
        geometry = discoverIntrinsicGeometry(fields, topology, references, cfg, logFid);
        manifold = discoverIntrinsicManifold(fields, references, cfg, logFid);
        quanta = quantizeKnowledge(fields, phaseMaps, topology, graphData, cfg, logFid);

        %% 9. Internal reference comparisons and eight final bridges
        internalComparisons = compareInternalReferenceDatasets(fields, topology, ...
            graphData, geometry, manifold, references, cfg, logFid);

        bridges = evaluateFinalEightBridges(fields, phaseMaps, topology, graphData, ...
            geometry, manifold, quanta, coarse, fine, timeKernel, ...
            internalComparisons, cfg, logFid);

        writeJSONL(fullfile(outputDir, '14_internal_reference_comparisons.jsonl'), ...
            internalComparisons);
        writeJSONL(fullfile(outputDir, '15_event_conditioned_bridges.jsonl'), bridges);

        %% 10. Coherence ledger
        ledger = buildCoherenceLedger(bridges, graphData, phaseMaps, ...
            coarse, fine, timeKernel, cfg);
        writeJSONL(fullfile(outputDir, '16_coherence_ledger.jsonl'), ledger);

        %% 11. Numerical support artifacts
        writeAuxiliaryNumericalArtifacts(outputDir, coarse, coarseEvents, fine, ...
            fields, timeKernel, topology, geometry, manifold, quanta, cfg);

        %% 12. Final contact sheet and quality gates
        contactSheetPath = fullfile(outputDir, '18_final_contact_sheet.png');
        createFinalContactSheet(contactSheetPath, fields, coarse, fine, ...
            timeKernel, phaseMaps, topology, graphData, geometry, manifold, cfg);

        quality = runFinalOutputQualityGates(ssot, audit, X, anchors, events, ...
            phaseMaps, topology, graphData, ledger, contactSheetPath, ...
            outputDir, cfg, logFid);
        writeJSON(fullfile(outputDir, '17_output_quality_report.json'), quality);

        %% 13. Manifest
        manifest = buildRunManifest(cfg, ssot, registry, audit, coarse, fine, ...
            timeKernel, anchors, events, topology, graphData, bridges, ...
            ledger, quality, outputDir, timestamp);
        writeJSON(fullfile(outputDir, '19_run_manifest.json'), manifest);

        result = struct;
        result.version = cfg.version;
        result.output_directory = outputDir;
        result.ssot_file = ssot.file;
        result.ssot_sha256 = ssot.sha256;
        result.hash_match = ssot.hashMatch;
        result.primary_dataset = cfg.primaryDataset;
        result.anchor_count = height(anchors);
        result.event_count = height(events);
        result.core_count = height(topology.cores);
        result.y_junction_count = height(topology.junctions);
        result.graph_node_count = height(graphData.nodes);
        result.graph_edge_count = height(graphData.edges);
        result.graph_valid = graphData.validity.is_valid;
        result.bridge_count = numel(bridges);
        result.quality_pass = quality.pass;
        result.manifest = fullfile(outputDir, '19_run_manifest.json');

        logLine(logFid, 'Run completed. Output: %s', outputDir);
        logLine(logFid, 'Quality pass: %d', quality.pass);

    catch ME
        logLine(logFid, 'RUN FAILED: %s', ME.message);
        logLine(logFid, '%s', getReport(ME, 'extended', 'hyperlinks', 'off'));
        failure = struct;
        failure.status = 'INVALID_OUTPUT';
        failure.identifier = ME.identifier;
        failure.message = ME.message;
        failure.stack = ME.stack;
        failure.timestamp = timestamp;
        writeJSON(fullfile(outputDir, 'RUN_FAILURE.json'), failure);
        rethrow(ME);
    end
end


%% ========================================================================
function cfg = defaultConfiguration()

    cfg.version = 'v3_FINAL_COHERENCE';

    cfg.ssotFile = ...
        '/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5';
    cfg.primaryDataset = '/n_5_composite_field_1000x1000/data';
    cfg.expectedSHA256 = ...
        '5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013';
    cfg.requireHashMatch = true;
    cfg.outputParent = '/MATLAB Drive/modelTRAINING';

    cfg.primaryShape = [1000 1000 5];
    cfg.referenceShape = [800 800];

    cfg.field.scales = [1 2 4 7 11 17];
    cfg.field.robustLow = 0.01;
    cfg.field.robustHigh = 0.99;
    cfg.field.pcaSampleCount = 100000;

    cfg.coarse.steps = 2000;
    cfg.coarse.weights = [0.45 0.35 0.20];
    cfg.coarse.memoryLambda = 0.85;
    cfg.coarse.eventCount = 8;
    cfg.coarse.eventMinDistance = 25;

    cfg.fine.windowLength = 39511;
    cfg.fine.weights = [0.35 0.25 0.25 0.15];
    cfg.fine.memoryLambda = 0.88;
    cfg.fine.multiscaleWindows = [5 25 101 501];
    cfg.fine.anchorCount = 12;
    cfg.fine.anchorMinDistanceSamples = 250;

    cfg.timeKernel.mappedDurationSec = 30;
    cfg.timeKernel.replayRateHz = 60;
    cfg.timeKernel.maxLag = 8000;
    cfg.timeKernel.minPeriod = 200;
    cfg.timeKernel.maxPeriod = 4000;
    cfg.timeKernel.periodCandidateCount = 12;
    cfg.timeKernel.eventMinDistanceFraction = 0.20;
    cfg.timeKernel.eventThresholdQuantile = 0.88;
    cfg.timeKernel.maxEvents = 128;
    cfg.timeKernel.regressionPeriodSamples = 1000;
    cfg.timeKernel.regressionPhaseConcentration = 0.6678182;
    cfg.timeKernel.regressionMeanPhaseRad = 1.787982;

    cfg.phase.kernelSigmaPixels = 8;
    cfg.phase.kernelRadiusSigma = 4;
    cfg.phase.windingThreshold = 0.45;

    cfg.topology.ridgeQuantile = 0.985;
    cfg.topology.maxCores = 96;
    cfg.topology.maxJunctions = 64;
    cfg.topology.minFeatureDistancePixels = 12;
    cfg.topology.minBranchLengthPixels = 10;
    cfg.topology.maxBranches = 250;

    cfg.graph.kNearest = 4;
    cfg.graph.maximumRadiusPixels = 180;
    cfg.graph.phaseGateRad = 0.85*pi;
    cfg.graph.maxDefectReferenceNodes = 32;
    cfg.graph.minimumNodes = 2;
    cfg.graph.minimumEdges = 1;

    cfg.manifold.gridSize = [25 25];
    cfg.manifold.kNearest = 8;
    cfg.manifold.sigmaScale = 1.0;

    cfg.discovery.minIntrinsicScore = 0.55;
    cfg.discovery.minCrossScore = 0.45;
    cfg.discovery.maxRelativeResidual = 0.15;
    cfg.discovery.minScaleStability = 0.65;
    cfg.discovery.minTemporalStability = 0.55;

    cfg.quality.minimumOccupiedPixelRatio = 0.002;
    cfg.quality.minimumFigureObjects = 4;
    cfg.quality.requireNonemptyGraph = true;
    cfg.quality.requireFinitePhaseMaps = true;
    cfg.quality.requireNonemptyAnchors = true;

    cfg.runtime.writeLargeFieldFamily = true;
    cfg.runtime.includeReferenceNodes = true;
    cfg.runtime.randomSeed = 26072026;
    cfg.runtime.verbose = true;
end


%% ========================================================================
function ssot = lockUnifiedH5(cfg, logFid)

    if ~isfile(cfg.ssotFile)
        error('SSOT file not found: %s', cfg.ssotFile);
    end

    ssot = struct;
    ssot.file = cfg.ssotFile;
    ssot.info = h5info(cfg.ssotFile);
    ssot.sha256 = computeSHA256(cfg.ssotFile);
    ssot.hashMatch = strcmpi(ssot.sha256, cfg.expectedSHA256);

    logLine(logFid, 'Computed SHA256: %s', ssot.sha256);
    logLine(logFid, 'Hash match: %d', ssot.hashMatch);

    if cfg.requireHashMatch && ~ssot.hashMatch
        error('SSOT SHA256 mismatch. Expected %s, got %s.', ...
            cfg.expectedSHA256, ssot.sha256);
    end
end


%% ========================================================================
function hash = computeSHA256(filePath)
    hash = '';

    if ispc
        cmd = sprintf('certutil -hashfile "%s" SHA256', filePath);
        [status, out] = system(cmd);
        if status == 0
            tokens = regexp(out, '[A-Fa-f0-9]{64}', 'match');
            if ~isempty(tokens)
                hash = lower(tokens{1});
                return;
            end
        end
    else
        [status, out] = system(sprintf('sha256sum "%s"', filePath));
        if status == 0
            tokens = regexp(out, '[A-Fa-f0-9]{64}', 'match');
            if ~isempty(tokens)
                hash = lower(tokens{1});
                return;
            end
        end

        [status, out] = system(sprintf('shasum -a 256 "%s"', filePath));
        if status == 0
            tokens = regexp(out, '[A-Fa-f0-9]{64}', 'match');
            if ~isempty(tokens)
                hash = lower(tokens{1});
                return;
            end
        end
    end

    % Java fallback.
    md = java.security.MessageDigest.getInstance('SHA-256');
    fis = java.io.FileInputStream(java.io.File(filePath));
    cleanup = onCleanup(@() fis.close()); %#ok<NASGU>
    buffer = zeros(1, 1024*1024, 'int8');

    while true
        n = fis.read(buffer, 0, numel(buffer));
        if n < 0
            break;
        end
        md.update(buffer(1:n));
    end

    digest = typecast(md.digest(), 'uint8');
    hash = lower(reshape(dec2hex(digest,2).', 1, []));
end


%% ========================================================================
function inventory = enumerateH5Datasets(rootInfo)
    rows = recurseGroup(rootInfo);
    if isempty(rows)
        inventory = table(string.empty(0,1), string.empty(0,1), ...
            cell(0,1), string.empty(0,1), ...
            'VariableNames', {'dataset_path','datatype','dataspace_size','group_path'});
        return;
    end
    inventory = struct2table(rows);
end


function rows = recurseGroup(groupInfo)
    rows = struct('dataset_path', {}, 'datatype', {}, ...
                  'dataspace_size', {}, 'group_path', {});

    for i = 1:numel(groupInfo.Datasets)
        ds = groupInfo.Datasets(i);
        if strcmp(groupInfo.Name, '/')
            fullPath = ['/' ds.Name];
        else
            fullPath = [groupInfo.Name '/' ds.Name];
        end

        entry.dataset_path = string(fullPath);
        if isfield(ds, 'Datatype') && isfield(ds.Datatype, 'Class')
            entry.datatype = string(ds.Datatype.Class);
        else
            entry.datatype = "unknown";
        end
        if isfield(ds, 'Dataspace') && isfield(ds.Dataspace, 'Size')
            entry.dataspace_size = {double(ds.Dataspace.Size)};
        else
            entry.dataspace_size = {[]};
        end
        entry.group_path = string(groupInfo.Name);
        rows(end+1) = entry; %#ok<AGROW>
    end

    for g = 1:numel(groupInfo.Groups)
        childRows = recurseGroup(groupInfo.Groups(g));
        if ~isempty(childRows)
            rows = [rows childRows]; %#ok<AGROW>
        end
    end
end


%% ========================================================================
function registry = buildSSOTDatasetRegistry(inventory, cfg)

    paths = inventory.dataset_path;
    roles = strings(height(inventory),1);
    required = false(height(inventory),1);
    useAsInput = false(height(inventory),1);

    for i = 1:height(inventory)
        p = char(paths(i));
        if strcmp(p, cfg.primaryDataset)
            roles(i) = "PRIMARY_OBSERVED_FIELD";
            required(i) = true;
            useAsInput(i) = true;
        elseif startsWith(p, '/n_2_e8_lattice/')
            roles(i) = "INTERNAL_GRAPH_SPECTRAL_REFERENCE";
            useAsInput(i) = true;
        elseif startsWith(p, '/n_3_defect_topology/')
            roles(i) = "INTERNAL_DEFECT_TOPOLOGY_REFERENCE";
            useAsInput(i) = true;
        elseif startsWith(p, '/n_4_geodesic_field/')
            roles(i) = "INTERNAL_GEODESIC_REFERENCE";
            useAsInput(i) = true;
        elseif startsWith(p, '/n_6_field_maps_v3_800x800/')
            roles(i) = "INTERNAL_FIELD_BASIS_REFERENCE";
            useAsInput(i) = true;
        elseif startsWith(p, '/n_7_apollonian_circle_model/')
            roles(i) = "INTERNAL_CIRCULAR_MANIFOLD_REFERENCE";
            useAsInput(i) = true;
        elseif startsWith(p, '/spectral_mappings/')
            roles(i) = "VISUALIZATION_ONLY_MAPPING";
            useAsInput(i) = false;
        else
            roles(i) = "UNCLASSIFIED_INTERNAL_DATASET";
        end
    end

    registry = inventory;
    registry.role = roles;
    registry.required = required;
    registry.runtime_numeric_input = useAsInput;

    if ~any(registry.dataset_path == string(cfg.primaryDataset))
        error('Primary dataset is absent from H5 registry: %s', cfg.primaryDataset);
    end
end


%% ========================================================================
function audit = auditShapesAndIndexMappings(registry, cfg, logFid)

    idx = find(registry.dataset_path == string(cfg.primaryDataset), 1);
    primarySize = registry.dataspace_size{idx};

    expectedSet = sort(double([cfg.primaryShape(3), prod(cfg.primaryShape(1:2))]));
    observedSet = sort(double(primarySize(:).'));

    shapeCompatible = isequal(expectedSet, observedSet);

    H = cfg.primaryShape(1);
    W = cfg.primaryShape(2);
    testSamples = unique(round(linspace(1, H*W, 41)));
    [r, c] = ind2sub([H W], testSamples);
    roundTrip = sub2ind([H W], r, c);
    roundTripValid = all(roundTrip == testSamples);

    audit = struct;
    audit.primary_dataset = cfg.primaryDataset;
    audit.observed_h5_shape = primarySize;
    audit.expected_matlab_field_shape = cfg.primaryShape;
    audit.shape_compatible = shapeCompatible;
    audit.indexing = 'MATLAB_COLUMN_MAJOR';
    audit.test_source_samples = testSamples;
    audit.test_rows = r;
    audit.test_columns = c;
    audit.round_trip_valid = roundTripValid;
    audit.mapping_equation = ...
        'sourceSample n <-> [row,column]=ind2sub([1000,1000],n)';

    logLine(logFid, 'Primary H5 size: %s', mat2str(primarySize));
    logLine(logFid, 'Shape compatible: %d', shapeCompatible);
    logLine(logFid, 'Index round trip valid: %d', roundTripValid);

    if ~shapeCompatible
        error('Primary dataset shape is incompatible with expected [5 x 1000000].');
    end
    if ~roundTripValid
        error('MATLAB source-index mapping audit failed.');
    end
end


%% ========================================================================
function [X, raw] = readPrimaryCompositeField(h5File, cfg, audit, logFid)

    if ~audit.shape_compatible
        error('Primary field cannot be read before shape audit passes.');
    end

    rawRead = h5read(h5File, cfg.primaryDataset);
    rawRead = single(rawRead);

    C = cfg.primaryShape(3);
    N = prod(cfg.primaryShape(1:2));

    if isequal(size(rawRead), [C N])
        raw = rawRead;
    elseif isequal(size(rawRead), [N C])
        raw = rawRead.';
    elseif numel(rawRead) == C*N
        raw = reshape(rawRead, [C N]);
    else
        error('Unexpected primary field read shape: %s', mat2str(size(rawRead)));
    end

    if any(~isfinite(raw(:)))
        error('Primary field contains non-finite values.');
    end
    if var(double(raw(:))) <= 0
        error('Primary field has zero variance.');
    end

    H = cfg.primaryShape(1);
    W = cfg.primaryShape(2);
    X = zeros(H, W, C, 'single');

    for c = 1:C
        X(:,:,c) = reshape(raw(c,:), [H W]);
    end

    logLine(logFid, 'Primary field decoded: %s', mat2str(size(X)));
    logLine(logFid, 'Primary range: [%g, %g]', min(X(:)), max(X(:)));
end


%% ========================================================================
function refs = readInternalReferenceDatasets(h5File, registry, cfg, logFid)

    refs = struct;

    refs.e8.roots = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/roots_2d');
    refs.e8.connectionA = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/connections/a');
    refs.e8.connectionB = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/connections/b');
    refs.e8.connectionD = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/connections/d');
    refs.e8.modes = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/laplacian_modes/modes');
    refs.e8.modeXY = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/laplacian_modes/xy');
    refs.e8.streamXY = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/streamlines/xy');
    refs.e8.streamSID = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/streamlines/sid');
    refs.e8.streamLogMag = readDatasetIfPresent(h5File, registry, ...
        '/n_2_e8_lattice/streamlines/logmag');

    refs.defects.pos = readDatasetIfPresent(h5File, registry, ...
        '/n_3_defect_topology/pos');
    refs.defects.charge = readDatasetIfPresent(h5File, registry, ...
        '/n_3_defect_topology/charge');
    refs.defects.degree = readDatasetIfPresent(h5File, registry, ...
        '/n_3_defect_topology/degree');

    refs.geodesic.xy = readDatasetIfPresent(h5File, registry, ...
        '/n_4_geodesic_field/xy');
    refs.geodesic.vel = readDatasetIfPresent(h5File, registry, ...
        '/n_4_geodesic_field/vel');
    refs.geodesic.curl = readDatasetIfPresent(h5File, registry, ...
        '/n_4_geodesic_field/curl');
    refs.geodesic.rawPoints = readDatasetIfPresent(h5File, registry, ...
        '/n_4_geodesic_field/raw_points');

    refs.fieldMaps.chamber = readFieldMapIfPresent(h5File, registry, ...
        '/n_6_field_maps_v3_800x800/chamber_field/data', cfg.referenceShape);
    refs.fieldMaps.fuchsian = readFieldMapIfPresent(h5File, registry, ...
        '/n_6_field_maps_v3_800x800/fuchsian_tiling/data', cfg.referenceShape);
    refs.fieldMaps.ginibre = readFieldMapIfPresent(h5File, registry, ...
        '/n_6_field_maps_v3_800x800/ginibre_field/data', cfg.referenceShape);
    refs.fieldMaps.modularEta = readFieldMapIfPresent(h5File, registry, ...
        '/n_6_field_maps_v3_800x800/modular_eta/data', cfg.referenceShape);
    refs.fieldMaps.weyl = readFieldMapIfPresent(h5File, registry, ...
        '/n_6_field_maps_v3_800x800/weyl_field/data', cfg.referenceShape);

    refs.apollonian.angles = readDatasetIfPresent(h5File, registry, ...
        '/n_7_apollonian_circle_model/e8_chamber_angles');

    logLine(logFid, 'Internal reference datasets loaded from the same H5.');
end


function data = readDatasetIfPresent(h5File, registry, path)
    if any(registry.dataset_path == string(path))
        data = h5read(h5File, path);
    else
        data = [];
    end
end


function field = readFieldMapIfPresent(h5File, registry, path, spatialShape)
    data = readDatasetIfPresent(h5File, registry, path);
    if isempty(data)
        field = [];
        return;
    end

    H = spatialShape(1);
    W = spatialShape(2);
    data = single(data);

    if size(data,2) == H*W
        C = size(data,1);
        raw = data;
    elseif size(data,1) == H*W
        C = size(data,2);
        raw = data.';
    else
        C = numel(data)/(H*W);
        if abs(C-round(C)) > 0
            error('Could not decode internal field map %s.', path);
        end
        C = round(C);
        raw = reshape(data, [C H*W]);
    end

    field = zeros(H,W,C,'single');
    for c = 1:C
        field(:,:,c) = reshape(raw(c,:), [H W]);
    end
end


%% ========================================================================
function fields = buildIntrinsicFieldFamily(X, raw, cfg, logFid)

    rng(cfg.runtime.randomSeed);

    [H,W,C] = size(X);
    N = H*W;

    channelMean = squeeze(mean(mean(X,1),2));
    channelStd = squeeze(std(reshape(X,[],C),0,1)).';

    Xz = zeros(size(X), 'single');
    for c = 1:C
        s = max(channelStd(c), 1e-6);
        Xz(:,:,c) = (X(:,:,c)-channelMean(c))/s;
    end

    Y = reshape(Xz, [N C]);
    sampleCount = min(cfg.field.pcaSampleCount, N);
    sampleIdx = unique(round(linspace(1,N,sampleCount)));
    Ysample = double(Y(sampleIdx,:));
    mu = mean(Ysample,1);
    Ysample = Ysample - mu;

    [~,~,V] = svd(Ysample, 'econ');
    pcaBasis = V;
    score = double(Y) - mu;
    pcaScores = score * pcaBasis(:,1:min(3,C));

    pcaMaps = zeros(H,W,min(3,C),'single');
    for k = 1:size(pcaMaps,3)
        pcaMaps(:,:,k) = reshape(single(pcaScores(:,k)), [H W]);
    end

    composite = normalizeRobust(single(pcaMaps(:,:,1)), ...
        cfg.field.robustLow, cfg.field.robustHigh);
    composite = composite - mean(composite(:));

    [gx,gy] = gradient(double(composite));
    gx = single(gx);
    gy = single(gy);
    gradMag = hypot(gx,gy);

    [gxx,gxy1] = gradient(double(gx));
    [gyx,gyy] = gradient(double(gy));
    gxx = single(gxx);
    gyy = single(gyy);
    gxy = single(0.5*(gxy1+gyx));
    laplacian = gxx + gyy;

    bestCoherence = zeros(H,W,'single');
    bestRidge = zeros(H,W,'single');
    bestOrientation = zeros(H,W,'single');
    bestL1 = zeros(H,W,'single');
    bestL2 = zeros(H,W,'single');
    bestJxx = zeros(H,W,'single');
    bestJxy = zeros(H,W,'single');
    bestJyy = zeros(H,W,'single');
    bestScale = zeros(H,W,'single');

    scaleRows = cell(numel(cfg.field.scales), 8);

    for sIdx = 1:numel(cfg.field.scales)
        sigma = cfg.field.scales(sIdx);

        Jxx = gaussianBlur2D(gx.^2, sigma);
        Jxy = gaussianBlur2D(gx.*gy, sigma);
        Jyy = gaussianBlur2D(gy.^2, sigma);

        traceJ = Jxx + Jyy;
        discJ = sqrt(max((Jxx-Jyy).^2 + 4*Jxy.^2, 0));
        l1 = 0.5*(traceJ + discJ);
        l2 = 0.5*(traceJ - discJ);
        coherence = discJ ./ (traceJ + 1e-6);

        orientation = 0.5*atan2(2*Jxy, Jxx-Jyy);

        Hxx = gaussianBlur2D(single(gxx), sigma);
        Hxy = gaussianBlur2D(single(gxy), sigma);
        Hyy = gaussianBlur2D(single(gyy), sigma);
        traceH = Hxx+Hyy;
        discH = sqrt(max((Hxx-Hyy).^2 + 4*Hxy.^2,0));
        h1 = 0.5*(traceH+discH);
        h2 = 0.5*(traceH-discH);
        ridge = max(abs(h1),abs(h2)).*coherence;
        ridge = normalizeRobust(ridge, 0.01, 0.995);

        update = ridge > bestRidge;
        bestRidge(update) = ridge(update);
        bestCoherence(update) = coherence(update);
        bestOrientation(update) = orientation(update);
        bestL1(update) = l1(update);
        bestL2(update) = l2(update);
        bestJxx(update) = Jxx(update);
        bestJxy(update) = Jxy(update);
        bestJyy(update) = Jyy(update);
        bestScale(update) = sigma;

        scaleRows(sIdx,:) = {sigma, mean(ridge(:)), std(ridge(:)), ...
            mean(coherence(:)), std(coherence(:)), ...
            quantileLocal(ridge(:),0.95), ...
            quantileLocal(ridge(:),0.99), ...
            mean(gradMag(:))};
    end

    scaleStats = cell2table(scaleRows, ...
        'VariableNames', {'sigma','ridge_mean','ridge_std', ...
        'coherence_mean','coherence_std','ridge_q95', ...
        'ridge_q99','gradient_mean'});

    % Analytic/phase field from two spatial quadratures.
    centered = double(composite) - mean(double(composite(:)));
    qx = imag(analyticSignalFFT(centered, 2));
    qy = imag(analyticSignalFFT(centered, 1));
    quadrature = (qx+qy)/sqrt(2);
    Z = centered + 1i*quadrature;
    phase = angle(Z);
    amplitude = abs(Z);
    phaseCoherenceLocal = normalizeRobust(gaussianBlur2D(single(amplitude),4),0.01,0.99);

    baseSalience = normalizeRobust( ...
        0.35*normalizeRobust(gradMag,0.01,0.99) + ...
        0.30*bestRidge + ...
        0.20*bestCoherence + ...
        0.15*phaseCoherenceLocal, 0.01, 0.995);

    % Intrinsic metric from the strongest structure-tensor scale.
    epsMetric = 1e-3;
    theta = bestOrientation;
    cth = cos(theta);
    sth = sin(theta);
    invL1 = 1./(bestL1+epsMetric);
    invL2 = 1./(bestL2+epsMetric);
    g11 = invL1.*cth.^2 + invL2.*sth.^2;
    g22 = invL1.*sth.^2 + invL2.*cth.^2;
    g12 = (invL1-invL2).*cth.*sth;

    fields = struct;
    fields.X = X;
    fields.raw = raw;
    fields.channelMean = channelMean;
    fields.channelStd = channelStd;
    fields.pcaBasis = pcaBasis;
    fields.pcaMaps = pcaMaps;
    fields.composite = single(composite);
    fields.gx = gx;
    fields.gy = gy;
    fields.gradientMagnitude = single(gradMag);
    fields.laplacian = single(laplacian);
    fields.ridge = single(bestRidge);
    fields.coherence = single(bestCoherence);
    fields.orientation = single(bestOrientation);
    fields.structureLambda1 = single(bestL1);
    fields.structureLambda2 = single(bestL2);
    fields.structureJxx = single(bestJxx);
    fields.structureJxy = single(bestJxy);
    fields.structureJyy = single(bestJyy);
    fields.bestScale = single(bestScale);
    fields.metricG11 = single(g11);
    fields.metricG12 = single(g12);
    fields.metricG22 = single(g22);
    fields.phase = single(phase);
    fields.phaseAmplitude = single(amplitude);
    fields.phaseCoherenceLocal = single(phaseCoherenceLocal);
    fields.salienceBase = single(baseSalience);
    fields.scaleStats = scaleStats;

    logLine(logFid, 'Intrinsic field family built.');
    logLine(logFid, 'PCA basis first vector: %s', mat2str(pcaBasis(:,1).',5));
end


%% ========================================================================
function coarse = discoverCoarseSalience(raw, fields, cfg, logFid)

    Y = double(raw.');
    N = size(Y,1);

    mu = mean(Y,1);
    Yc = Y-mu;
    [~,~,V] = svd(Yc(round(linspace(1,N,min(N,100000))),:), 'econ');
    w = V(:,1);

    projectionRaw = abs(Yc*w);
    speedRaw = [0; sqrt(sum(diff(Y,1,1).^2,2))];
    structureRaw = double(fields.salienceBase(:));

    projection = blockReduce(projectionRaw, cfg.coarse.steps, 'max');
    temporal = blockReduce(speedRaw, cfg.coarse.steps, 'max');
    structure = blockReduce(structureRaw, cfg.coarse.steps, 'max');

    projectionNorm = normalizeRobust(projection,0.01,0.995);
    temporalNorm = normalizeRobust(temporal,0.01,0.995);
    structureNorm = normalizeRobust(structure,0.01,0.995);

    wgt = cfg.coarse.weights(:).';
    combinedRaw = wgt(1)*projectionNorm + ...
                  wgt(2)*temporalNorm + ...
                  wgt(3)*structureNorm;
    combinedNorm = normalizeRobust(combinedRaw,0,1);

    memoryRaw = zeros(size(combinedNorm));
    for t = 2:numel(memoryRaw)
        memoryRaw(t) = cfg.coarse.memoryLambda*memoryRaw(t-1) + ...
            (1-cfg.coarse.memoryLambda)*combinedNorm(t);
    end
    memoryNorm = normalizeRobust(memoryRaw,0,1);

    edges = round(linspace(1,N+1,cfg.coarse.steps+1));
    sourceCenter = zeros(cfg.coarse.steps,1);
    sourceStart = zeros(cfg.coarse.steps,1);
    sourceEnd = zeros(cfg.coarse.steps,1);
    for i = 1:cfg.coarse.steps
        sourceStart(i) = edges(i);
        sourceEnd(i) = max(edges(i),edges(i+1)-1);
        sourceCenter(i) = round((sourceStart(i)+sourceEnd(i))/2);
    end

    coarse = table;
    coarse.index = (1:cfg.coarse.steps).';
    coarse.t_step = (0:cfg.coarse.steps-1).';
    coarse.tau = coarse.t_step/max(1,cfg.coarse.steps-1);
    coarse.source_start = sourceStart;
    coarse.source_end = sourceEnd;
    coarse.source_center = sourceCenter;
    coarse.projection_norm = projectionNorm(:);
    coarse.temporal_norm = temporalNorm(:);
    coarse.structure_norm = structureNorm(:);
    coarse.combined_norm = combinedNorm(:);
    coarse.memory_norm = memoryNorm(:);

    [~,peakIdx] = max(coarse.combined_norm);
    [~,memoryIdx] = max(coarse.memory_norm);
    logLine(logFid, 'Coarse global peak t_step=%d, source≈%d, value=%g.', ...
        coarse.t_step(peakIdx), coarse.source_center(peakIdx), ...
        coarse.combined_norm(peakIdx));
    logLine(logFid, 'Coarse memory peak lag=%d steps.', ...
        coarse.t_step(memoryIdx)-coarse.t_step(peakIdx));
end


function events = discoverCoarseSalienceEvents(coarse, cfg)
    idx = selectPeaks(coarse.combined_norm, cfg.coarse.eventCount, ...
        cfg.coarse.eventMinDistance, 0.70);
    events = coarse(idx,:);
    events.event_order = (1:height(events)).';
    events = movevars(events,'event_order','Before',1);
end


%% ========================================================================
function fine = discoverHighResolutionSalience(raw, fields, coarseEvents, cfg, logFid)

    N = size(raw,2);
    if isempty(coarseEvents)
        center = round(N/2);
    else
        [~,best] = max(coarseEvents.combined_norm);
        center = coarseEvents.source_center(best);
    end

    L = min(cfg.fine.windowLength,N);
    startIdx = max(1, center-floor(L/2));
    endIdx = min(N, startIdx+L-1);
    startIdx = max(1,endIdx-L+1);

    sourceSample = (startIdx:endIdx).';
    segment = double(raw(:,startIdx:endIdx).');
    segmentCentered = segment-mean(segment,1);

    [~,~,V] = svd(segmentCentered,'econ');
    projectionRaw = abs(segmentCentered*V(:,1));
    speedRaw = [0; sqrt(sum(diff(segment,1,1).^2,2))];
    accelRaw = [0; diff(speedRaw)];
    jerkRaw = [0; diff(accelRaw)];

    multiscale = zeros(numel(sourceSample),1);
    for w = cfg.fine.multiscaleWindows
        m1 = movmean(projectionRaw,w,'Endpoints','shrink');
        m2 = movmean(projectionRaw.^2,w,'Endpoints','shrink');
        localStd = sqrt(max(m2-m1.^2,0));
        multiscale = multiscale + normalizeRobust(localStd,0.01,0.99);
    end
    multiscale = multiscale/numel(cfg.fine.multiscaleWindows);

    fieldStructure = double(fields.salienceBase(sourceSample));

    projectionNorm = normalizeRobust(projectionRaw,0.01,0.995);
    temporalNorm = normalizeRobust(speedRaw+0.25*abs(accelRaw)+0.1*abs(jerkRaw),0.01,0.995);
    multiscaleNorm = normalizeRobust(multiscale,0.01,0.995);
    fieldNorm = normalizeRobust(fieldStructure,0.01,0.995);

    wgt = cfg.fine.weights;
    preMemory = wgt(1)*projectionNorm + ...
                wgt(2)*temporalNorm + ...
                wgt(3)*multiscaleNorm + ...
                wgt(4)*fieldNorm;

    memoryRaw = zeros(size(preMemory));
    for t = 2:numel(memoryRaw)
        memoryRaw(t) = cfg.fine.memoryLambda*memoryRaw(t-1) + ...
            (1-cfg.fine.memoryLambda)*preMemory(t);
    end
    memoryNorm = normalizeRobust(memoryRaw,0,1);

    combined = normalizeRobust(0.85*preMemory+0.15*memoryNorm,0.01,0.999);

    fine = table;
    fine.local_index = (1:numel(sourceSample)).';
    fine.source_sample = sourceSample;
    fine.t_step = (0:numel(sourceSample)-1).';
    fine.tau = fine.t_step/max(1,numel(sourceSample)-1);
    fine.projection_norm = projectionNorm;
    fine.temporal_norm = temporalNorm;
    fine.multiscale_norm = multiscaleNorm;
    fine.field_structure_norm = fieldNorm;
    fine.memory_norm = memoryNorm;
    fine.combined_norm = combined;
    fine.speed = speedRaw;
    fine.accel = accelRaw;
    fine.jerk = jerkRaw;

    [mx,idx] = max(combined);
    logLine(logFid, 'Fine window: [%d,%d], length=%d.', ...
        startIdx,endIdx,height(fine));
    logLine(logFid, 'Fine global peak source=%d, value=%g.', ...
        fine.source_sample(idx),mx);
end


%% ========================================================================
function tk = discoverTimeKernelBlind(fine, cfg, logFid)

    x = double(fine.combined_norm(:));
    x = x-mean(x);
    maxLag = min(cfg.timeKernel.maxLag,numel(x)-1);

    acf = normalizedAutocorrelationFFT(x,maxLag);
    lag = (0:maxLag).';

    minP = max(2,cfg.timeKernel.minPeriod);
    maxP = min(maxLag,cfg.timeKernel.maxPeriod);
    candidateRegion = acf(minP+1:maxP+1);

    candidateLocal = localMaxima(candidateRegion);
    candidateLags = candidateLocal + minP - 1;
    if isempty(candidateLags)
        [~,ord] = sort(candidateRegion,'descend');
        candidateLags = ord(1:min(cfg.timeKernel.periodCandidateCount,numel(ord))) + minP - 1;
    end

    % FFT power used only to score period candidates.
    nfft = 2^nextpow2(numel(x));
    powerSpectrum = abs(fft(x,nfft)).^2;
    half = floor(nfft/2);
    powerSpectrum = powerSpectrum(1:half);
    frequency = (0:half-1).'/nfft;

    candidateScores = zeros(numel(candidateLags),5);
    for i = 1:numel(candidateLags)
        P = candidateLags(i);
        acfScore = max(0,acf(P+1));

        f0 = 1/P;
        [~,fi] = min(abs(frequency-f0));
        spectralScore = powerSpectrum(fi)/(max(powerSpectrum)+eps);

        harmonic = 0;
        count = 0;
        for h = 2:4
            lagH = round(h*P);
            if lagH <= maxLag
                harmonic = harmonic + max(0,acf(lagH+1));
                count = count+1;
            end
        end
        if count > 0
            harmonic = harmonic/count;
        end

        candidateScores(i,:) = [P,acfScore,spectralScore,harmonic, ...
            0.50*acfScore+0.30*spectralScore+0.20*harmonic];
    end

    [~,order] = sort(candidateScores(:,5),'descend');
    order = order(1:min(numel(order),cfg.timeKernel.periodCandidateCount));
    candidateScores = candidateScores(order,:);
    dominantPeriod = round(candidateScores(1,1));

    eventMinDist = max(5,round(cfg.timeKernel.eventMinDistanceFraction*dominantPeriod));
    peakThreshold = quantileLocal(fine.combined_norm, ...
        cfg.timeKernel.eventThresholdQuantile);
    peakIdx = selectPeaks(fine.combined_norm, cfg.timeKernel.maxEvents, ...
        eventMinDist, peakThreshold);

    peakIdx = sort(peakIdx(:));
    if isempty(peakIdx)
        [~,peakIdx] = max(fine.combined_norm);
    end

    mappedDuration = cfg.timeKernel.mappedDurationSec;
    sourceStart = fine.source_sample(1);
    sourceEnd = fine.source_sample(end);
    sourceRate = (sourceEnd-sourceStart)/mappedDuration;

    sourceSamples = fine.source_sample(peakIdx);
    peakValues = fine.combined_norm(peakIdx);
    firstPeak = sourceSamples(1);

    targetTime = (sourceSamples-sourceStart)/sourceRate;
    cycleId = floor((sourceSamples-firstPeak)/dominantPeriod);
    phaseRad = 2*pi*mod(sourceSamples-firstPeak,dominantPeriod)/dominantPeriod;

    nextIntervalSamples = [diff(sourceSamples); NaN];
    nextIntervalSec = nextIntervalSamples/sourceRate;

    phaseConcentration = abs(sum(double(peakValues).*exp(1i*double(phaseRad)))) / ...
        (sum(double(peakValues))+eps);
    meanPhase = angle(sum(double(peakValues).*exp(1i*double(phaseRad))));

    replayTime = (0:1/cfg.timeKernel.replayRateHz:mappedDuration).';
    replay = zeros(size(replayTime));
    localIntervals = nextIntervalSec;
    validIntervals = localIntervals(isfinite(localIntervals) & localIntervals>0);
    if isempty(validIntervals)
        fallbackWidth = 0.05;
    else
        fallbackWidth = max(1/cfg.timeKernel.replayRateHz,0.12*median(validIntervals));
    end

    for j = 1:numel(targetTime)
        prevInt = fallbackWidth;
        nextInt = fallbackWidth;
        if j>1
            prevInt = max(fallbackWidth,targetTime(j)-targetTime(j-1));
        end
        if j<numel(targetTime)
            nextInt = max(fallbackWidth,targetTime(j+1)-targetTime(j));
        end
        sigma = max(1/cfg.timeKernel.replayRateHz,0.12*min(prevInt,nextInt));
        replay = replay + double(peakValues(j))* ...
            exp(-0.5*((replayTime-targetTime(j))/sigma).^2);
    end
    replay = replay/(max(replay)+eps);

    tk = struct;
    tk.lag = lag;
    tk.autocorrelation = acf;
    tk.frequency = frequency;
    tk.powerSpectrum = powerSpectrum;
    tk.periodCandidates = array2table(candidateScores, ...
        'VariableNames', {'period_samples','acf_score','spectral_score', ...
        'harmonic_score','combined_score'});
    tk.dominantPeriodSamples = dominantPeriod;
    tk.sourceRateSamplesPerSec = sourceRate;
    tk.dominantPeriodSec = dominantPeriod/sourceRate;
    tk.dominantFrequencyHz = sourceRate/dominantPeriod;
    tk.peakLocalIndex = peakIdx;
    tk.peakSourceSample = sourceSamples;
    tk.peakValue = peakValues;
    tk.targetTimeSec = targetTime;
    tk.cycleId = cycleId;
    tk.phaseRad = phaseRad;
    tk.nextIntervalSamples = nextIntervalSamples;
    tk.nextIntervalSec = nextIntervalSec;
    tk.phaseConcentration = phaseConcentration;
    tk.circularMeanPhase = meanPhase;
    tk.replayTimeSec = replayTime;
    tk.replaySignal = replay;
    tk.sourceStart = sourceStart;
    tk.sourceEnd = sourceEnd;
    tk.mappedDurationSec = mappedDuration;

    logLine(logFid, 'TimeKernel period=%d samples, f=%g Hz, events=%d.', ...
        dominantPeriod,tk.dominantFrequencyHz,numel(peakIdx));
    logLine(logFid, 'TimeKernel phase concentration=%g, mean phase=%g.', ...
        phaseConcentration,meanPhase);
end


%% ========================================================================
function anchors = extractHighConfidenceAnchorLayer(fine, cfg, logFid)

    idx = selectPeaks(fine.combined_norm, cfg.fine.anchorCount, ...
        cfg.fine.anchorMinDistanceSamples, 0.75);

    if numel(idx) < cfg.fine.anchorCount
        [~,order] = sort(fine.combined_norm,'descend');
        for k = 1:numel(order)
            if isempty(idx) || all(abs(order(k)-idx) >= cfg.fine.anchorMinDistanceSamples)
                idx(end+1,1) = order(k); %#ok<AGROW>
                if numel(idx) >= cfg.fine.anchorCount
                    break;
                end
            end
        end
    end

    [~,order] = sort(fine.combined_norm(idx),'descend');
    idx = idx(order);
    idx = idx(1:min(cfg.fine.anchorCount,numel(idx)));

    anchors = table;
    anchors.anchor_id = "A" + compose('%03d',(1:numel(idx)).');
    anchors.local_index = fine.local_index(idx);
    anchors.source_sample = fine.source_sample(idx);
    anchors.salience = fine.combined_norm(idx);
    anchors.projection = fine.projection_norm(idx);
    anchors.temporal = fine.temporal_norm(idx);
    anchors.multiscale = fine.multiscale_norm(idx);
    anchors.memory = fine.memory_norm(idx);

    [row,col] = ind2sub(cfg.primaryShape(1:2),anchors.source_sample);
    anchors.row = row;
    anchors.column = col;

    logLine(logFid, 'Anchor layer count: %d.', height(anchors));
end


function events = extractTimeKernelEventLayer(tk, cfg, logFid)

    n = numel(tk.peakSourceSample);
    events = table;
    events.event_id = "E" + compose('%03d',(1:n).');
    events.peak_order = (1:n).';
    events.source_sample = tk.peakSourceSample(:);
    events.target_time_sec = tk.targetTimeSec(:);
    events.phase_rad = tk.phaseRad(:);
    events.cycle_id = tk.cycleId(:);
    events.salience = tk.peakValue(:);
    events.next_interval_samples = tk.nextIntervalSamples(:);
    events.next_interval_sec = tk.nextIntervalSec(:);

    [row,col] = ind2sub(cfg.primaryShape(1:2),events.source_sample);
    events.row = row;
    events.column = col;

    logLine(logFid, 'Event layer count: %d.', height(events));
end


function alignment = alignAnchorAndEventLayers(anchors, events, cfg)

    nA = height(anchors);
    alignment = table;

    anchorId = strings(nA,1);
    eventId = strings(nA,1);
    sourceResidual = zeros(nA,1);
    phaseResidual = zeros(nA,1);
    salienceResidual = zeros(nA,1);
    totalCost = zeros(nA,1);

    P0 = max(1,median(events.next_interval_samples,'omitnan'));
    if ~isfinite(P0)
        P0 = cfg.timeKernel.regressionPeriodSamples;
    end

    for i = 1:nA
        dn = abs(double(events.source_sample)-double(anchors.source_sample(i)))/P0;
        ds = abs(double(events.salience)-double(anchors.salience(i)));
        % Anchor phase is assigned from the nearest source event during matching.
        cost = 0.70*dn + 0.30*ds;
        [totalCost(i),j] = min(cost);

        anchorId(i) = anchors.anchor_id(i);
        eventId(i) = events.event_id(j);
        sourceResidual(i) = double(events.source_sample(j))-double(anchors.source_sample(i));
        phaseResidual(i) = events.phase_rad(j);
        salienceResidual(i) = double(events.salience(j))-double(anchors.salience(i));
    end

    alignment.anchor_id = anchorId;
    alignment.event_id = eventId;
    alignment.source_residual_samples = sourceResidual;
    alignment.assigned_phase_rad = phaseResidual;
    alignment.salience_residual = salienceResidual;
    alignment.total_cost = totalCost;
end


%% ========================================================================
function maps = buildComplexAnchorPhaseMaps(anchors, events, alignment, ...
    spatialShape, cfg, logFid)

    H = spatialShape(1);
    W = spatialShape(2);

    Zevent = complex(zeros(H,W,'single'));
    Devent = zeros(H,W,'single');
    Zanchor = complex(zeros(H,W,'single'));
    Danchor = zeros(H,W,'single');

    sigma = cfg.phase.kernelSigmaPixels;
    radius = ceil(cfg.phase.kernelRadiusSigma*sigma);

    for j = 1:height(events)
        amp = single(events.salience(j));
        phase = single(events.phase_rad(j));
        [kernel, rr, cc] = localizedGaussian(events.row(j),events.column(j), ...
            H,W,sigma,radius);
        Zevent(rr,cc) = Zevent(rr,cc) + amp*kernel*exp(1i*phase);
        Devent(rr,cc) = Devent(rr,cc) + amp*kernel;
    end

    for i = 1:height(anchors)
        match = find(alignment.anchor_id == anchors.anchor_id(i),1);
        phase = single(alignment.assigned_phase_rad(match));
        amp = single(anchors.salience(i));
        [kernel, rr, cc] = localizedGaussian(anchors.row(i),anchors.column(i), ...
            H,W,sigma,radius);
        Zanchor(rr,cc) = Zanchor(rr,cc) + amp*kernel*exp(1i*phase);
        Danchor(rr,cc) = Danchor(rr,cc) + amp*kernel;
    end

    Zcombined = Zevent+Zanchor;
    Dcombined = Devent+Danchor;

    maps = struct;
    maps.anchorAmplitude = single(abs(Zanchor));
    maps.eventAmplitude = single(abs(Zevent));
    maps.combinedAmplitude = single(abs(Zcombined));
    maps.cosMap = single(real(Zcombined));
    maps.sinMap = single(imag(Zcombined));
    maps.coherenceMap = single(abs(Zcombined)./(Dcombined+eps('single')));
    maps.denominator = single(Dcombined);
    maps.complexReal = single(real(Zcombined));
    maps.complexImag = single(imag(Zcombined));

    if any(~isfinite(maps.combinedAmplitude(:))) || ...
       any(~isfinite(maps.cosMap(:))) || ...
       any(~isfinite(maps.sinMap(:))) || ...
       any(~isfinite(maps.coherenceMap(:)))
        error('Complex anchor-phase maps contain non-finite values.');
    end

    logLine(logFid, 'Complex anchor-phase maps built.');
end


function [kernel, rr, cc] = localizedGaussian(row,col,H,W,sigma,radius)
    r0 = max(1,row-radius);
    r1 = min(H,row+radius);
    c0 = max(1,col-radius);
    c1 = min(W,col+radius);
    rr = r0:r1;
    cc = c0:c1;
    [C,R] = meshgrid(cc,rr);
    kernel = single(exp(-((R-row).^2+(C-col).^2)/(2*sigma^2)));
end


function writePhaseH5Artifacts(outputDir, maps)

    mainPath = fullfile(outputDir,'06_complex_anchor_phase_maps.h5');
    cosPath = fullfile(outputDir,'07_phase_cos_map.h5');
    sinPath = fullfile(outputDir,'08_phase_sin_map.h5');
    cohPath = fullfile(outputDir,'09_phase_coherence_map.h5');

    deleteIfExists(mainPath);
    deleteIfExists(cosPath);
    deleteIfExists(sinPath);
    deleteIfExists(cohPath);

    createAndWriteH5(mainPath,'/anchor/amplitude',maps.anchorAmplitude);
    createAndWriteH5(mainPath,'/event/amplitude',maps.eventAmplitude);
    createAndWriteH5(mainPath,'/combined/amplitude',maps.combinedAmplitude);
    createAndWriteH5(mainPath,'/phase/cos',maps.cosMap);
    createAndWriteH5(mainPath,'/phase/sin',maps.sinMap);
    createAndWriteH5(mainPath,'/phase/coherence',maps.coherenceMap);
    createAndWriteH5(mainPath,'/phase/real',maps.complexReal);
    createAndWriteH5(mainPath,'/phase/imag',maps.complexImag);

    createAndWriteH5(cosPath,'/phase_cos',maps.cosMap);
    createAndWriteH5(sinPath,'/phase_sin',maps.sinMap);
    createAndWriteH5(cohPath,'/phase_coherence',maps.coherenceMap);
end


%% ========================================================================
function topology = discoverCoresRidgesAndYJunctions(fields, phaseMaps, cfg, logFid)

    H = size(fields.composite,1);
    W = size(fields.composite,2);

    ridgeThreshold = quantileLocal(fields.ridge(:),cfg.topology.ridgeQuantile);
    ridgeMask = fields.ridge >= ridgeThreshold;

    if exist('bwskel','file') == 2
        skeleton = bwskel(ridgeMask,'MinBranchLength',cfg.topology.minBranchLengthPixels);
    elseif exist('bwmorph','file') == 2
        skeleton = bwmorph(ridgeMask,'skel',Inf);
        skeleton = bwmorph(skeleton,'spur',2);
    else
        skeleton = ridgeMask;
    end

    % Phase winding on elementary plaquettes.
    p = double(fields.phase);
    a = p(1:end-1,1:end-1);
    b = p(1:end-1,2:end);
    c = p(2:end,2:end);
    d = p(2:end,1:end-1);
    winding = (wrapAngle(b-a)+wrapAngle(c-b)+ ...
               wrapAngle(d-c)+wrapAngle(a-d))/(2*pi);

    ampCell = 0.25*(fields.phaseAmplitude(1:end-1,1:end-1) + ...
                    fields.phaseAmplitude(1:end-1,2:end) + ...
                    fields.phaseAmplitude(2:end,2:end) + ...
                    fields.phaseAmplitude(2:end,1:end-1));
    salCell = 0.25*(fields.salienceBase(1:end-1,1:end-1) + ...
                    fields.salienceBase(1:end-1,2:end) + ...
                    fields.salienceBase(2:end,2:end) + ...
                    fields.salienceBase(2:end,1:end-1));

    coreScore = abs(winding).*normalizeRobust(ampCell,0.01,0.99).*salCell;
    coreCandidates = find(abs(winding)>=cfg.phase.windingThreshold);
    [coreRows,coreCols] = ind2sub([H-1,W-1],coreCandidates);
    coreRows = coreRows+1;
    coreCols = coreCols+1;
    coreScores = coreScore(coreCandidates);

    coreSel = selectSpatialFeatures(coreRows,coreCols,coreScores, ...
        cfg.topology.maxCores,cfg.topology.minFeatureDistancePixels);

    cores = table;
    cores.core_id = "C" + compose('%03d',(1:numel(coreSel)).');
    cores.row = coreRows(coreSel);
    cores.column = coreCols(coreSel);
    cores.source_sample = sub2ind([H W],cores.row,cores.column);
    cores.winding = winding(coreCandidates(coreSel));
    cores.score = coreScores(coreSel);
    cores.phase = fields.phase(cores.source_sample);
    cores.amplitude = fields.phaseAmplitude(cores.source_sample);
    cores.salience = fields.salienceBase(cores.source_sample);

    neighborCount = conv2(single(skeleton),ones(3,'single'),'same')-single(skeleton);
    branchRaw = skeleton & neighborCount>=3;
    branchIdx = find(branchRaw);
    [jr,jc] = ind2sub([H W],branchIdx);
    junctionBaseScore = fields.coherence(branchIdx).* ...
        phaseMaps.coherenceMap(branchIdx).*fields.salienceBase(branchIdx);

    jSelInitial = selectSpatialFeatures(jr,jc,junctionBaseScore, ...
        max(4*cfg.topology.maxJunctions,cfg.topology.maxJunctions), ...
        cfg.topology.minFeatureDistancePixels);

    jr = jr(jSelInitial);
    jc = jc(jSelInitial);
    junctionBaseScore = junctionBaseScore(jSelInitial);

    angleCount = zeros(numel(jr),1);
    angleSeparationScore = zeros(numel(jr),1);
    balanceResidual = zeros(numel(jr),1);

    for i = 1:numel(jr)
        [angleCount(i),angleSeparationScore(i),balanceResidual(i)] = ...
            estimateJunctionDirections(skeleton,jr(i),jc(i));
    end

    junctionScore = junctionBaseScore .* ...
        min(angleCount/3,1) .* angleSeparationScore .* exp(-balanceResidual);

    valid = angleCount>=3;
    jr = jr(valid);
    jc = jc(valid);
    angleCount = angleCount(valid);
    angleSeparationScore = angleSeparationScore(valid);
    balanceResidual = balanceResidual(valid);
    junctionScore = junctionScore(valid);

    jFinal = selectSpatialFeatures(jr,jc,junctionScore, ...
        cfg.topology.maxJunctions,cfg.topology.minFeatureDistancePixels);

    junctions = table;
    junctions.junction_id = "Y" + compose('%03d',(1:numel(jFinal)).');
    junctions.row = jr(jFinal);
    junctions.column = jc(jFinal);
    junctions.source_sample = sub2ind([H W],junctions.row,junctions.column);
    junctions.branch_count = angleCount(jFinal);
    junctions.angle_separation_score = angleSeparationScore(jFinal);
    junctions.balance_residual = balanceResidual(jFinal);
    junctions.score = junctionScore(jFinal);
    junctions.phase = fields.phase(junctions.source_sample);
    junctions.salience = fields.salienceBase(junctions.source_sample);

    branches = extractSkeletonBranches(skeleton,junctions,fields,cfg);

    topology = struct;
    topology.ridgeThreshold = ridgeThreshold;
    topology.ridgeMask = ridgeMask;
    topology.skeleton = skeleton;
    topology.winding = single(winding);
    topology.cores = cores;
    topology.junctions = junctions;
    topology.branches = branches;

    logLine(logFid, 'Topology: cores=%d, Y-junctions=%d, branches=%d.', ...
        height(cores),height(junctions),height(branches));
end


function [count,sepScore,balanceResidual] = estimateJunctionDirections(skeleton,row,col)

    H = size(skeleton,1);
    W = size(skeleton,2);
    rMin = 4;
    rMax = 14;

    r0 = max(1,row-rMax);
    r1 = min(H,row+rMax);
    c0 = max(1,col-rMax);
    c1 = min(W,col+rMax);

    [C,R] = meshgrid(c0:c1,r0:r1);
    mask = skeleton(r0:r1,c0:c1);
    dr = R-row;
    dc = C-col;
    radius = hypot(dr,dc);
    mask = mask & radius>=rMin & radius<=rMax;

    angles = atan2(dr(mask),dc(mask));
    if numel(angles)<3
        count = 0;
        sepScore = 0;
        balanceResidual = 1;
        return;
    end

    nBins = 36;
    edges = linspace(-pi,pi,nBins+1);
    h = histcounts(angles,edges);
    h = conv([h h h],[1 2 3 2 1],'same');
    h = h(nBins+1:2*nBins);

    peakBins = localMaxima(h(:));
    if isempty(peakBins)
        count = 0;
        sepScore = 0;
        balanceResidual = 1;
        return;
    end

    [~,ord] = sort(h(peakBins),'descend');
    selected = [];
    minSepBins = 5;
    for k = 1:numel(ord)
        b = peakBins(ord(k));
        if isempty(selected) || all(circularBinDistance(b,selected,nBins)>=minSepBins)
            selected(end+1) = b; %#ok<AGROW>
            if numel(selected)>=3
                break;
            end
        end
    end

    count = numel(selected);
    if count<3
        sepScore = count/3;
        balanceResidual = 1;
        return;
    end

    theta = -pi + (selected-0.5)*(2*pi/nBins);
    theta = theta(1:3);
    v = [cos(theta(:)) sin(theta(:))];
    vectorSum = sum(v,1);
    balanceResidual = norm(vectorSum)/3;

    pairSep = [];
    for i = 1:3
        for j = i+1:3
            pairSep(end+1) = abs(wrapAngle(theta(i)-theta(j))); %#ok<AGROW>
        end
    end
    target = 2*pi/3;
    sepScore = exp(-mean(abs(pairSep-target))/target);
end


function d = circularBinDistance(b,selected,nBins)
    d0 = abs(selected-b);
    d = min(d0,nBins-d0);
end


function branches = extractSkeletonBranches(skeleton,junctions,fields,cfg)

    cut = skeleton;
    if ~isempty(junctions)
        for i = 1:height(junctions)
            r = junctions.row(i);
            c = junctions.column(i);
            rr = max(1,r-1):min(size(cut,1),r+1);
            cc = max(1,c-1):min(size(cut,2),c+1);
            cut(rr,cc) = false;
        end
    end

    components = binaryComponents(cut);
    rows = {};
    cols = {};
    euclideanLength = [];
    metricLength = [];
    curvatureEnergy = [];
    phaseCoherence = [];
    compatibility = [];

    count = 0;
    for k = 1:numel(components)
        idx = components{k};
        if numel(idx)<cfg.topology.minBranchLengthPixels
            continue;
        end
        [r,c] = ind2sub(size(cut),idx);
        [r,c] = orderSkeletonComponent(r,c);
        orderedIdx = sub2ind(size(cut),r,c);
        if numel(r)<cfg.topology.minBranchLengthPixels
            continue;
        end

        count = count+1;
        if count>cfg.topology.maxBranches
            break;
        end

        dr = diff(double(r));
        dc = diff(double(c));
        ds = hypot(dr,dc);
        L0 = sum(ds);

        g11 = double(fields.metricG11(orderedIdx(1:end-1)));
        g12 = double(fields.metricG12(orderedIdx(1:end-1)));
        g22 = double(fields.metricG22(orderedIdx(1:end-1)));
        metricElement = sqrt(max(g11.*dr.^2 + 2*g12.*dr.*dc + g22.*dc.^2,0));
        Lg = sum(metricElement);

        tangent = [dr dc];
        tangentNorm = hypot(tangent(:,1),tangent(:,2))+eps;
        tangent = tangent./tangentNorm;
        if size(tangent,1)>=2
            dtheta = acos(max(-1,min(1,sum(tangent(1:end-1,:).*tangent(2:end,:),2))));
            curv = mean(dtheta.^2);
        else
            curv = NaN;
        end

        ph = double(fields.phase(orderedIdx));
        phCoh = abs(mean(exp(1i*ph)));

        comp = exp(-nanToZero(curv))*phCoh* ...
            mean(double(fields.coherence(orderedIdx)));

        rows{count,1} = r; %#ok<AGROW>
        cols{count,1} = c; %#ok<AGROW>
        euclideanLength(count,1) = L0; %#ok<AGROW>
        metricLength(count,1) = Lg; %#ok<AGROW>
        curvatureEnergy(count,1) = curv; %#ok<AGROW>
        phaseCoherence(count,1) = phCoh; %#ok<AGROW>
        compatibility(count,1) = comp; %#ok<AGROW>
    end

    branchId = "B" + compose('%04d',(1:count).');
    branches = table(branchId,rows,cols,euclideanLength,metricLength, ...
        curvatureEnergy,phaseCoherence,compatibility, ...
        'VariableNames', {'branch_id','rows','columns', ...
        'euclidean_length','metric_length','curvature_energy', ...
        'phase_coherence','intrinsic_geodesic_compatibility'});
end


%% ========================================================================
function graphData = buildValidatedHierarchicalGraph(anchors, events, topology, ...
    references, cfg, logFid)

    [H,W] = deal(cfg.primaryShape(1),cfg.primaryShape(2));

    nodeType = strings(0,1);
    row = zeros(0,1);
    column = zeros(0,1);
    sourceSample = zeros(0,1);
    phase = zeros(0,1);
    amplitude = zeros(0,1);
    timeSec = zeros(0,1);
    cycle = zeros(0,1);
    referenceCharge = zeros(0,1);
    referenceDegree = zeros(0,1);
    externalId = strings(0,1);

    % Anchors
    n = height(anchors);
    nodeType = [nodeType; repmat("ANCHOR",n,1)];
    row = [row; anchors.row];
    column = [column; anchors.column];
    sourceSample = [sourceSample; anchors.source_sample];
    amplitude = [amplitude; anchors.salience];
    phase = [phase; nan(n,1)];
    timeSec = [timeSec; nan(n,1)];
    cycle = [cycle; nan(n,1)];
    referenceCharge = [referenceCharge; nan(n,1)];
    referenceDegree = [referenceDegree; nan(n,1)];
    externalId = [externalId; anchors.anchor_id];

    % Events
    n = height(events);
    nodeType = [nodeType; repmat("TIME_EVENT",n,1)];
    row = [row; events.row];
    column = [column; events.column];
    sourceSample = [sourceSample; events.source_sample];
    amplitude = [amplitude; events.salience];
    phase = [phase; events.phase_rad];
    timeSec = [timeSec; events.target_time_sec];
    cycle = [cycle; events.cycle_id];
    referenceCharge = [referenceCharge; nan(n,1)];
    referenceDegree = [referenceDegree; nan(n,1)];
    externalId = [externalId; events.event_id];

    % Cores
    n = height(topology.cores);
    nodeType = [nodeType; repmat("PHASE_CORE",n,1)];
    row = [row; topology.cores.row];
    column = [column; topology.cores.column];
    sourceSample = [sourceSample; topology.cores.source_sample];
    amplitude = [amplitude; topology.cores.score];
    phase = [phase; topology.cores.phase];
    timeSec = [timeSec; nan(n,1)];
    cycle = [cycle; nan(n,1)];
    referenceCharge = [referenceCharge; topology.cores.winding];
    referenceDegree = [referenceDegree; nan(n,1)];
    externalId = [externalId; topology.cores.core_id];

    % Y-junctions
    n = height(topology.junctions);
    nodeType = [nodeType; repmat("Y_JUNCTION",n,1)];
    row = [row; topology.junctions.row];
    column = [column; topology.junctions.column];
    sourceSample = [sourceSample; topology.junctions.source_sample];
    amplitude = [amplitude; topology.junctions.score];
    phase = [phase; topology.junctions.phase];
    timeSec = [timeSec; nan(n,1)];
    cycle = [cycle; nan(n,1)];
    referenceCharge = [referenceCharge; nan(n,1)];
    referenceDegree = [referenceDegree; topology.junctions.branch_count];
    externalId = [externalId; topology.junctions.junction_id];

    % Optional internal defect reference nodes.
    if cfg.runtime.includeReferenceNodes && ~isempty(references.defects.pos)
        pos = double(references.defects.pos);
        if size(pos,1)~=2
            pos = pos.';
        end
        charge = double(references.defects.charge(:));
        degree = double(references.defects.degree(:));
        importance = abs(charge).*degree;
        [~,ord] = sort(importance,'descend');
        ord = ord(1:min(cfg.graph.maxDefectReferenceNodes,numel(ord)));

        x = pos(1,ord);
        y = pos(2,ord);
        x = 1+(x-min(x))/(max(x)-min(x)+eps)*(W-1);
        y = 1+(y-min(y))/(max(y)-min(y)+eps)*(H-1);

        n = numel(ord);
        nodeType = [nodeType; repmat("DEFECT_REFERENCE",n,1)];
        row = [row; round(y(:))];
        column = [column; round(x(:))];
        sourceSample = [sourceSample; sub2ind([H W],round(y(:)),round(x(:)))];
        amplitude = [amplitude; normalizeRobust(importance(ord),0,1)];
        phase = [phase; nan(n,1)];
        timeSec = [timeSec; nan(n,1)];
        cycle = [cycle; nan(n,1)];
        referenceCharge = [referenceCharge; charge(ord)];
        referenceDegree = [referenceDegree; degree(ord)];
        externalId = [externalId; "D" + compose('%03d',(1:n).')];
    end

    nodeCount = numel(row);
    nodeId = "N" + compose('%04d',(1:nodeCount).');

    nodes = table(nodeId,externalId,nodeType,row,column,sourceSample,phase, ...
        amplitude,timeSec,cycle,referenceCharge,referenceDegree, ...
        'VariableNames', {'node_id','external_id','node_type','row', ...
        'column','source_sample','phase_rad','amplitude','time_sec', ...
        'cycle_id','reference_charge','reference_degree'});

    % Spatial kNN edges.
    coords = [double(row) double(column)];
    D = pairwiseEuclidean(coords);
    D(1:nodeCount+1:end) = Inf;

    edgeS = [];
    edgeT = [];
    edgeType = strings(0,1);
    edgeWeight = [];
    edgeDistance = [];
    edgePhase = [];
    edgeTime = [];

    for i = 1:nodeCount
        [dist,ord] = sort(D(i,:),'ascend');
        ord = ord(1:min(cfg.graph.kNearest,numel(ord)));
        dist = dist(1:numel(ord));
        for k = 1:numel(ord)
            j = ord(k);
            if ~isfinite(dist(k)) || dist(k)>cfg.graph.maximumRadiusPixels
                continue;
            end

            phaseDiff = circularDifference(phase(i),phase(j));
            if isfinite(phaseDiff) && phaseDiff>cfg.graph.phaseGateRad
                continue;
            end

            phaseFactor = 1;
            if isfinite(phaseDiff)
                phaseFactor = (1+cos(phaseDiff))/2;
            end
            timeDiff = abs(timeSec(i)-timeSec(j));
            timeFactor = 1;
            if isfinite(timeDiff)
                timeFactor = exp(-timeDiff/max(1,medianFinite(diff(events.target_time_sec))));
            end
            w = exp(-dist(k)^2/(2*(cfg.graph.maximumRadiusPixels/2)^2))* ...
                phaseFactor*timeFactor;

            [edgeS,edgeT,edgeType,edgeWeight,edgeDistance,edgePhase,edgeTime] = ...
                appendEdge(edgeS,edgeT,edgeType,edgeWeight,edgeDistance, ...
                edgePhase,edgeTime,i,j,"SPATIAL",w,dist(k),phaseDiff,timeDiff);
        end
    end

    % Consecutive event edges.
    eventNode = find(nodes.node_type=="TIME_EVENT");
    [~,ordEvent] = sort(nodes.time_sec(eventNode));
    eventNode = eventNode(ordEvent);
    for k = 1:numel(eventNode)-1
        i = eventNode(k);
        j = eventNode(k+1);
        dist = D(i,j);
        phaseDiff = circularDifference(phase(i),phase(j));
        timeDiff = abs(timeSec(i)-timeSec(j));
        w = exp(-timeDiff/(medianFinite(diff(events.target_time_sec))+eps))* ...
            ((1+cos(nanToZero(phaseDiff)))/2);
        [edgeS,edgeT,edgeType,edgeWeight,edgeDistance,edgePhase,edgeTime] = ...
            appendEdge(edgeS,edgeT,edgeType,edgeWeight,edgeDistance, ...
            edgePhase,edgeTime,i,j,"TEMPORAL",w,dist,phaseDiff,timeDiff);
    end

    % Anchor-event explicit edges by nearest source sample.
    anchorNode = find(nodes.node_type=="ANCHOR");
    for a = anchorNode(:).'
        residual = abs(double(nodes.source_sample(eventNode))-double(nodes.source_sample(a)));
        [best,jj] = min(residual);
        j = eventNode(jj);
        phaseDiff = circularDifference(phase(a),phase(j));
        timeDiff = NaN;
        w = exp(-best/max(1,medianFinite(events.next_interval_samples)));
        [edgeS,edgeT,edgeType,edgeWeight,edgeDistance,edgePhase,edgeTime] = ...
            appendEdge(edgeS,edgeT,edgeType,edgeWeight,edgeDistance, ...
            edgePhase,edgeTime,a,j,"ANCHOR_EVENT",w,D(a,j),phaseDiff,timeDiff);
    end

    % Deduplicate unordered node pairs per edge type.
    [edgeS,edgeT,edgeType,edgeWeight,edgeDistance,edgePhase,edgeTime] = ...
        deduplicateEdges(edgeS,edgeT,edgeType,edgeWeight,edgeDistance,edgePhase,edgeTime);

    edgeId = "G" + compose('%05d',(1:numel(edgeS)).');
    sourceNode = nodes.node_id(edgeS);
    targetNode = nodes.node_id(edgeT);
    edges = table(edgeId,sourceNode,targetNode,edgeType,edgeWeight, ...
        edgeDistance,edgePhase,edgeTime, ...
        'VariableNames', {'edge_id','source_node','target_node', ...
        'edge_type','weight','distance_pixels','phase_difference_rad', ...
        'time_difference_sec'});

    A = sparse([edgeS;edgeT],[edgeT;edgeS],[edgeWeight;edgeWeight], ...
        nodeCount,nodeCount);
    degree = sum(A,2);
    L = spdiags(degree,0,nodeCount,nodeCount)-A;

    comp = connectedComponentsSparse(A);
    if isempty(comp)
        largest = 0;
    else
        counts = accumarray(comp(:),1);
        largest = max(counts);
    end

    if nodeCount<=600
        eigVals = sort(real(eig(full(L))));
    else
        kEig = min(32,nodeCount-1);
        eigVals = sort(real(eigs(L,kEig,'smallestreal')));
    end

    validity = struct;
    validity.node_count = nodeCount;
    validity.edge_count = height(edges);
    validity.largest_connected_component = largest;
    validity.finite_node_table = all(isfinite(nodes.row)) && all(isfinite(nodes.column));
    validity.finite_laplacian_spectrum = all(isfinite(eigVals));
    validity.is_valid = nodeCount>=cfg.graph.minimumNodes && ...
        height(edges)>=cfg.graph.minimumEdges && largest>=2 && ...
        validity.finite_laplacian_spectrum;
    if validity.is_valid
        validity.status = 'VALID_GRAPH';
    else
        validity.status = 'GRAPH_INVALID_EMPTY';
    end

    if cfg.quality.requireNonemptyGraph && ~validity.is_valid
        error('GRAPH_INVALID_EMPTY: graph validity gates failed.');
    end

    graphData = struct;
    graphData.nodes = nodes;
    graphData.edges = edges;
    graphData.adjacency = A;
    graphData.laplacian = L;
    graphData.eigenvalues = eigVals;
    graphData.component_id = comp;
    graphData.validity = validity;

    logLine(logFid, 'Graph: nodes=%d, edges=%d, largest component=%d.', ...
        nodeCount,height(edges),largest);
end


%% ========================================================================
function geometry = discoverIntrinsicGeometry(fields, topology, references, ~, logFid)

    branches = topology.branches;
    if isempty(branches)
        intrinsicMean = 0;
        intrinsicMedian = 0;
        scaleStability = 0;
    else
        values = branches.intrinsic_geodesic_compatibility;
        intrinsicMean = mean(values,'omitnan');
        intrinsicMedian = median(values,'omitnan');
        scaleStability = 1-std(values,'omitnan')/(abs(mean(values,'omitnan'))+eps);
        scaleStability = max(0,min(1,scaleStability));
    end

    % Projection relation q = a*p^2 + b*p + d.
    sal = double(fields.salienceBase(:));
    [~,ord] = sort(sal,'descend');
    sampleCount = min(100000,numel(ord));
    idx = ord(1:sampleCount);

    vx = double(fields.gx(idx));
    vy = double(fields.gy(idx));
    theta = double(fields.orientation(idx));
    ux = cos(theta);
    uy = sin(theta);

    g11 = double(fields.metricG11(idx));
    g12 = double(fields.metricG12(idx));
    g22 = double(fields.metricG22(idx));

    p = ux.*(g11.*vx+g12.*vy) + uy.*(g12.*vx+g22.*vy);
    q = vx.*(g11.*vx+g12.*vy) + vy.*(g12.*vx+g22.*vy);

    design = [p.^2 p ones(size(p))];
    coeff = design\q;
    qHat = design*coeff;
    projectionResidual = norm(q-qHat)/(norm(q)+eps);
    projectionCorrelation = correlationSafe(q,p.^2);

    % Self projection baseline.
    normV = sqrt(max(q,eps));
    uxSelf = vx./(sqrt(vx.^2+vy.^2)+eps);
    uySelf = vy./(sqrt(vx.^2+vy.^2)+eps);
    selfP = uxSelf.*(g11.*vx+g12.*vy)+uySelf.*(g12.*vx+g22.*vy);
    selfBaselineResidual = norm(q-selfP.^2)/(norm(q)+eps);

    % Phase-conditioned projection coefficients.
    phase = double(fields.phase(idx));
    phaseEdges = linspace(-pi,pi,9);
    phaseCoeff = nan(8,4);
    for b = 1:8
        m = phase>=phaseEdges(b) & phase<phaseEdges(b+1);
        if nnz(m)>=50
            cb = design(m,:)\q(m);
            rb = norm(q(m)-design(m,:)*cb)/(norm(q(m))+eps);
            phaseCoeff(b,:) = [cb(:).' rb];
        end
    end

    % Cross comparison with internal geodesic reference.
    crossGeo = 0;
    refCurlQuantileDistance = NaN;
    if ~isempty(references.geodesic.curl)
        refCurl = abs(double(references.geodesic.curl(:)));
        branchCurv = branches.curvature_energy;
        branchCurv = branchCurv(isfinite(branchCurv));
        if ~isempty(branchCurv)
            qA = quantileVector(normalizeRobust(branchCurv,0,1),21);
            qB = quantileVector(normalizeRobust(refCurl,0.01,0.99),21);
            refCurlQuantileDistance = mean(abs(qA-qB));
            crossGeo = exp(-refCurlQuantileDistance);
        end
    end

    geometry = struct;
    geometry.branchTable = branches;
    geometry.intrinsicGeodesicMean = intrinsicMean;
    geometry.intrinsicGeodesicMedian = intrinsicMedian;
    geometry.branchScaleStability = scaleStability;
    geometry.projectionCoefficients = coeff(:).';
    geometry.projectionEquation = sprintf('q = %.12g*p^2 + %.12g*p + %.12g', ...
        coeff(1),coeff(2),coeff(3));
    geometry.projectionResidual = projectionResidual;
    geometry.projectionCorrelation = projectionCorrelation;
    geometry.selfProjectionBaselineResidual = selfBaselineResidual;
    geometry.phaseConditionedProjection = phaseCoeff;
    geometry.crossGeodesicScore = crossGeo;
    geometry.referenceCurlQuantileDistance = refCurlQuantileDistance;

    logLine(logFid, 'Geometry: intrinsic mean=%g, projection residual=%g.', ...
        intrinsicMean,projectionResidual);
end


%% ========================================================================
function manifold = discoverIntrinsicManifold(fields, references, cfg, logFid)

    H = size(fields.composite,1);
    W = size(fields.composite,2);
    rr = round(linspace(1,H,cfg.manifold.gridSize(1)));
    cc = round(linspace(1,W,cfg.manifold.gridSize(2)));
    [Cgrid,Rgrid] = meshgrid(cc,rr);
    idx = sub2ind([H W],Rgrid(:),Cgrid(:));

    F = [ ...
        double(fields.composite(idx)), ...
        double(fields.gradientMagnitude(idx)), ...
        double(fields.coherence(idx)), ...
        double(fields.ridge(idx)), ...
        cos(double(fields.phase(idx))), ...
        sin(double(fields.phase(idx))), ...
        double(fields.salienceBase(idx))];

    F = standardizeColumns(F);
    D = pairwiseEuclidean(F);
    n = size(F,1);

    A = sparse(n,n);
    finiteD = D(isfinite(D) & D>0);
    sigma = cfg.manifold.sigmaScale*median(finiteD);
    if ~isfinite(sigma) || sigma<=0
        sigma = 1;
    end

    for i = 1:n
        [dist,ord] = sort(D(i,:),'ascend');
        ord = ord(2:min(cfg.manifold.kNearest+1,n));
        dist = dist(2:numel(ord)+1);
        w = exp(-(dist.^2)/(2*sigma^2));
        A(i,ord) = w;
    end
    A = max(A,A.');
    degree = sum(A,2);
    Dinv = spdiags(1./sqrt(degree+eps),0,n,n);
    Lnorm = speye(n)-Dinv*A*Dinv;

    try
        [V,E] = eigs(Lnorm,4,'smallestreal');
        [eigVals,ord] = sort(real(diag(E)));
        V = real(V(:,ord));
    catch
        [Vall,Eall] = eig(full(Lnorm));
        [eigVals,ord] = sort(real(diag(Eall)));
        V = real(Vall(:,ord(1:4)));
        eigVals = eigVals(1:4);
    end

    embedding = V(:,2:3);
    embedding = embedding-mean(embedding,1);

    radius = hypot(embedding(:,1),embedding(:,2));
    angle = atan2(embedding(:,2),embedding(:,1));

    try
        hull = convhull(embedding(:,1),embedding(:,2));
        hullRadius = radius(hull);
        diskScore = 1-std(hullRadius)/(mean(hullRadius)+eps);
        diskScore = max(0,min(1,diskScore));
    catch
        hull = (1:numel(radius)).';
        diskScore = 0;
    end

    sortedAngle = sort(angle);
    if isempty(sortedAngle)
        angularCoverage = 0;
    else
        circularGaps = diff([sortedAngle; sortedAngle(1)+2*pi]);
        angularCoverage = 1-max(circularGaps)/(2*pi);
    end
    angularCoverage = max(0,min(1,angularCoverage));

    neighborPreservation = neighborhoodJaccard([Rgrid(:) Cgrid(:)], ...
        embedding,cfg.manifold.kNearest);

    apollonianScore = 0;
    if ~isempty(references.apollonian.angles)
        refAngles = mod(double(references.apollonian.angles(:)),2*pi);
        bins = linspace(-pi,pi,19);
        hEmbed = histcounts(angle,bins,'Normalization','probability');
        hRef = histcounts(wrapAngle(refAngles),bins,'Normalization','probability');
        apollonianScore = max(0,correlationSafe(hEmbed(:),hRef(:)));
    end

    manifold = struct;
    manifold.sampleRows = Rgrid(:);
    manifold.sampleColumns = Cgrid(:);
    manifold.features = F;
    manifold.embedding = embedding;
    manifold.eigenvalues = eigVals;
    manifold.diskScore = diskScore;
    manifold.angularCoverage = angularCoverage;
    manifold.neighborPreservation = neighborPreservation;
    manifold.apollonianAngularScore = apollonianScore;
    manifold.combinedScore = mean([diskScore,angularCoverage, ...
        neighborPreservation,apollonianScore]);

    logLine(logFid, 'Manifold: disk=%g, neighbor=%g, apollonian=%g.', ...
        diskScore,neighborPreservation,apollonianScore);
end


%% ========================================================================
function quanta = quantizeKnowledge(fields, phaseMaps, topology, graphData, cfg, logFid)

    nodeCount = height(graphData.nodes);
    type = graphData.nodes.node_type;
    p = [graphData.nodes.row graphData.nodes.column];
    amp = graphData.nodes.amplitude;
    eta = graphData.nodes.phase_rad;
    tau = graphData.nodes.time_sec;
    cycle = graphData.nodes.cycle_id;

    mu = zeros(nodeCount,1);
    chi = strings(nodeCount,1);

    for i = 1:nodeCount
        switch type(i)
            case "PHASE_CORE"
                mu(i) = graphData.nodes.reference_charge(i);
                chi(i) = "core";
            case "Y_JUNCTION"
                mu(i) = graphData.nodes.reference_degree(i);
                chi(i) = "Y_junction";
            case "ANCHOR"
                mu(i) = phaseMaps.coherenceMap(graphData.nodes.source_sample(i));
                chi(i) = "anchor";
            case "TIME_EVENT"
                mu(i) = graphData.nodes.cycle_id(i);
                chi(i) = "time_event";
            case "DEFECT_REFERENCE"
                mu(i) = graphData.nodes.reference_charge(i);
                chi(i) = "defect_reference";
            otherwise
                chi(i) = "unknown";
        end
    end

    kappaId = "K" + compose('%05d',(1:nodeCount).');
    quantaTable = table(kappaId,p(:,1),p(:,2),amp,eta,mu,tau,cycle,chi, ...
        'VariableNames', {'kappa_id','row','column','amplitude', ...
        'phase','mu','tau','cycle_id','topological_type'});

    % Core families discovered without physical labels.
    coreFeatures = [];
    coreFamily = [];
    familyScore = 0;
    if ~isempty(topology.cores)
        coreFeatures = [ ...
            double(topology.cores.score), ...
            double(topology.cores.winding), ...
            double(topology.cores.amplitude), ...
            double(topology.cores.salience), ...
            cos(double(topology.cores.phase)), ...
            sin(double(topology.cores.phase))];
        coreFeatures = standardizeColumns(coreFeatures);
        k = min(4,max(1,floor(size(coreFeatures,1)/5)));
        [coreFamily,~,familyScore] = simpleKmeansStable(coreFeatures,k,10, ...
            cfg.runtime.randomSeed);
    end

    quanta = struct;
    quanta.table = quantaTable;
    quanta.coreFeatures = coreFeatures;
    quanta.coreFamilyId = coreFamily;
    quanta.coreFamilyScore = familyScore;
    quanta.adjacency = graphData.adjacency;
    quanta.laplacian = graphData.laplacian;

    logLine(logFid, 'Knowledge quanta: %d nodes; core family score=%g.', ...
        height(quantaTable),familyScore);
end


%% ========================================================================
function comparisons = compareInternalReferenceDatasets(fields, topology, ...
    graphData, geometry, manifold, refs, cfg, logFid)

    comparisons = struct([]);

    % 1. Geodesic/curl distribution.
    c = struct;
    c.comparison_id = 'REF_GEODESIC_001';
    c.family = 'branch_geometry_vs_internal_geodesic';
    c.source_datasets = {cfg.primaryDataset, ...
        '/n_4_geodesic_field/vel','/n_4_geodesic_field/curl'};
    c.score = geometry.crossGeodesicScore;
    c.residual = geometry.referenceCurlQuantileDistance;
    c.status = statusFromScore(c.score,cfg.discovery.minCrossScore);
    comparisons(end+1) = c; 

    % 2. Core charge/degree distribution vs defect topology.
    defectScore = 0;
    defectResidual = NaN;
    if ~isempty(topology.cores) && ~isempty(refs.defects.charge)
        a = normalizeRobust(abs(double(topology.cores.winding)),0,1);
        b = normalizeRobust(abs(double(refs.defects.charge(:))),0,1);
        qA = quantileVector(a,21);
        qB = quantileVector(b,21);
        defectResidual = mean(abs(qA-qB));
        defectScore = exp(-defectResidual);
    end

    c = struct;
    c.comparison_id = 'REF_DEFECT_001';
    c.family = 'phase_core_vs_defect_topology';
    c.source_datasets = {cfg.primaryDataset, ...
        '/n_3_defect_topology/charge','/n_3_defect_topology/degree'};
    c.score = defectScore;
    c.residual = defectResidual;
    c.status = statusFromScore(c.score,cfg.discovery.minCrossScore);
    comparisons(end+1) = c; %#ok<AGROW>

    % 3. Latent field basis vs n6 internal field maps.
    [basisScore,basisDetails] = compareLatentBasisToFieldMaps(fields,refs,cfg);
    c = struct;
    c.comparison_id = 'REF_FIELDS_001';
    c.family = 'latent_basis_vs_internal_field_maps';
    c.source_datasets = {cfg.primaryDataset, ...
        '/n_6_field_maps_v3_800x800/*/data'};
    c.score = basisScore;
    c.residual = 1-basisScore;
    c.details = basisDetails;
    c.status = statusFromScore(c.score,cfg.discovery.minCrossScore);
    comparisons(end+1) = c; %#ok<AGROW>

    % 4. Circular manifold vs Apollonian angles.
    c = struct;
    c.comparison_id = 'REF_CIRCULAR_001';
    c.family = 'intrinsic_manifold_vs_apollonian_angles';
    c.source_datasets = {cfg.primaryDataset, ...
        '/n_7_apollonian_circle_model/e8_chamber_angles'};
    c.score = manifold.apollonianAngularScore;
    c.residual = 1-manifold.apollonianAngularScore;
    c.status = statusFromScore(c.score,cfg.discovery.minCrossScore);
    comparisons(end+1) = c; %#ok<AGROW>

    % 5. Graph spectral shape vs E8 Laplacian modes.
    e8Score = 0;
    e8Residual = NaN;
    if ~isempty(refs.e8.modes) && ~isempty(graphData.eigenvalues)
        sv = svd(double(refs.e8.modes),'econ');
        sv = normalizeRobust(sv(:),0,1);
        ev = graphData.eigenvalues(:);
        ev = ev(ev>1e-10);
        if ~isempty(ev)
            ev = normalizeRobust(ev,0,1);
            m = min([numel(sv),numel(ev),12]);
            e8Residual = mean(abs(sort(sv(1:m))-sort(ev(1:m))));
            e8Score = exp(-e8Residual);
        end
    end

    c = struct;
    c.comparison_id = 'REF_E8_001';
    c.family = 'knowledge_graph_spectrum_vs_e8_modes';
    c.source_datasets = {cfg.primaryDataset, ...
        '/n_2_e8_lattice/laplacian_modes/modes'};
    c.score = e8Score;
    c.residual = e8Residual;
    c.status = statusFromScore(c.score,cfg.discovery.minCrossScore);
    comparisons(end+1) = c; %#ok<AGROW>

    logLine(logFid, 'Internal comparisons built: %d.',numel(comparisons));
end


function [score,details] = compareLatentBasisToFieldMaps(fields,refs,cfg)

    names = {'chamber','fuchsian','ginibre','modularEta','weyl'};
    primary = fields.pcaMaps;
    primarySmall = zeros(100,100,size(primary,3));
    for i = 1:size(primary,3)
        primarySmall(:,:,i) = resize2D(primary(:,:,i),[100 100]);
    end

    allScores = [];
    details = struct;

    for n = 1:numel(names)
        name = names{n};
        ref = refs.fieldMaps.(name);
        if isempty(ref)
            details.(name) = NaN;
            continue;
        end

        refPca = spatialPCA(ref,min(3,size(ref,3)));
        refSmall = zeros(100,100,size(refPca,3));
        for j = 1:size(refPca,3)
            refSmall(:,:,j) = resize2D(refPca(:,:,j),[100 100]);
        end

        C = zeros(size(primarySmall,3),size(refSmall,3));
        for i = 1:size(primarySmall,3)
            for j = 1:size(refSmall,3)
                C(i,j) = abs(correlationSafe(primarySmall(:,:,i),refSmall(:,:,j)));
            end
        end
        vals = sort(C(:),'descend');
        thisScore = mean(vals(1:min(3,numel(vals))));
        details.(name) = thisScore;
        allScores(end+1) = thisScore; %#ok<AGROW>
    end

    if isempty(allScores)
        score = 0;
    else
        score = mean(allScores);
    end
end


%% ========================================================================
function bridges = evaluateFinalEightBridges(fields, phaseMaps, topology, ...
    graphData, geometry, manifold, quanta, coarse, ~, tk, ...
    comparisons, cfg, logFid)

    bridges = struct([]);

    % Shared stability terms.
    scaleStability = max(0,min(1,1-std(fields.scaleStats.ridge_q99)/ ...
        (mean(fields.scaleStats.ridge_q99)+eps)));
    temporalStability = max(0,min(1,tk.phaseConcentration));
    graphSupport = double(graphData.validity.is_valid);
    phaseSupport = mean(double(phaseMaps.coherenceMap(phaseMaps.denominator>0)),'omitnan');
    if ~isfinite(phaseSupport)
        phaseSupport = 0;
    end

    % 1. Visual branch <-> intrinsic geodesic compatibility.
    b = baseBridge('BRIDGE_01','visual_branch_geodesic', ...
        'intrinsic_geodesic_compatibility = exp(-curvature_energy)*phase_coherence*orientation_coherence');
    b.source_datasets = {cfg.primaryDataset,'/n_4_geodesic_field/vel', ...
        '/n_4_geodesic_field/curl'};
    b.intrinsic_score = clamp01(geometry.intrinsicGeodesicMean);
    b.cross_dataset_score = comparisonScore(comparisons,'branch_geometry_vs_internal_geodesic');
    b.scale_stability = scaleStability;
    b.temporal_stability = temporalStability;
    b.graph_support = graphSupport;
    b.phase_support = phaseSupport;
    b.residual = 1-b.intrinsic_score;
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    % 2. Projection <-> squared norm.
    b = baseBridge('BRIDGE_02','projection_squared_norm',geometry.projectionEquation);
    b.source_datasets = {cfg.primaryDataset,'/n_4_geodesic_field/vel'};
    b.intrinsic_score = clamp01(0.5*(max(0,geometry.projectionCorrelation)+ ...
        exp(-5*geometry.projectionResidual)));
    b.cross_dataset_score = clamp01(exp(-5*geometry.selfProjectionBaselineResidual));
    b.scale_stability = scaleStability;
    b.temporal_stability = phaseCoefficientStability(geometry.phaseConditionedProjection);
    b.graph_support = graphSupport;
    b.phase_support = phaseSupport;
    b.residual = geometry.projectionResidual;
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    % 3. Dimensionless rate family.
    intervals = tk.nextIntervalSamples(isfinite(tk.nextIntervalSamples) & ...
        tk.nextIntervalSamples>0);
    ratios = intervals/tk.dominantPeriodSamples;
    [rationalResidual,rationalDetails] = rationalFamilyResidual(ratios);
    b = baseBridge('BRIDGE_03','dimensionless_rate_family', ...
        'rho_j = peak_interval_j / carrier_period');
    b.source_datasets = {cfg.primaryDataset};
    b.intrinsic_score = clamp01(exp(-4*rationalResidual));
    b.cross_dataset_score = 0;
    b.scale_stability = scaleStability;
    b.temporal_stability = clamp01(1-std(ratios)/(mean(ratios)+eps));
    b.graph_support = graphSupport;
    b.phase_support = temporalStability;
    b.residual = rationalResidual;
    b.details = rationalDetails;
    b.physical_v_over_c = [];
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    % 4. Intrinsic disk/manifold.
    b = baseBridge('BRIDGE_04','intrinsic_disk_manifold', ...
        'S_disk = mean(disk_score, angular_coverage, neighborhood_preservation)');
    b.source_datasets = {cfg.primaryDataset, ...
        '/n_7_apollonian_circle_model/e8_chamber_angles', ...
        '/n_6_field_maps_v3_800x800/fuchsian_tiling/data'};
    b.intrinsic_score = clamp01(mean([manifold.diskScore, ...
        manifold.angularCoverage,manifold.neighborPreservation]));
    b.cross_dataset_score = comparisonScore(comparisons, ...
        'intrinsic_manifold_vs_apollonian_angles');
    b.scale_stability = scaleStability;
    b.temporal_stability = temporalStability;
    b.graph_support = graphSupport;
    b.phase_support = phaseSupport;
    b.residual = 1-b.intrinsic_score;
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    % 5. Stable core family.
    b = baseBridge('BRIDGE_05','stable_core_family', ...
        'kappa_i = (p_i,a_i,eta_i,mu_i,tau_i,chi_i)');
    b.source_datasets = {cfg.primaryDataset, ...
        '/n_3_defect_topology/charge','/n_3_defect_topology/degree'};
    coreCountFactor = min(1,height(topology.cores)/max(1,cfg.topology.maxCores/2));
    b.intrinsic_score = clamp01(0.5*coreCountFactor+0.5*quanta.coreFamilyScore);
    b.cross_dataset_score = comparisonScore(comparisons, ...
        'phase_core_vs_defect_topology');
    b.scale_stability = scaleStability;
    b.temporal_stability = temporalStability;
    b.graph_support = graphSupport;
    b.phase_support = phaseSupport;
    b.residual = 1-b.intrinsic_score;
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    % 6. Latent basis alignment.
    basisScore = comparisonScore(comparisons,'latent_basis_vs_internal_field_maps');
    orthResidual = norm(fields.pcaBasis.'*fields.pcaBasis-eye(size(fields.pcaBasis,2)),'fro');
    b = baseBridge('BRIDGE_06','latent_basis_alignment', ...
        'U = W^T X; compare subspaces by correlation and Procrustes residual');
    b.source_datasets = {cfg.primaryDataset, ...
        '/n_6_field_maps_v3_800x800/*/data'};
    b.intrinsic_score = clamp01(exp(-orthResidual));
    b.cross_dataset_score = basisScore;
    b.scale_stability = scaleStability;
    b.temporal_stability = temporalStability;
    b.graph_support = graphSupport;
    b.phase_support = phaseSupport;
    b.residual = 1-mean([b.intrinsic_score,b.cross_dataset_score]);
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    % 7. Internal center/fixed-point anchor.
    centerMetrics = calculateCenterMetrics(fields,topology,phaseMaps);
    b = baseBridge('BRIDGE_07','center_fixed_point', ...
        'center_score = mean(attention_extremum,path_density,rotation_symmetry,phase_coherence)');
    b.source_datasets = {cfg.primaryDataset};
    b.intrinsic_score = centerMetrics.combined;
    b.cross_dataset_score = 0;
    b.scale_stability = scaleStability;
    b.temporal_stability = temporalStability;
    b.graph_support = graphSupport;
    b.phase_support = centerMetrics.phaseCoherence;
    b.residual = 1-b.intrinsic_score;
    b.details = centerMetrics;
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    % 8. Internal mass-energy/binding scaling.
    massEnergy = discoverInternalMassEnergyScaling(graphData,cfg);
    b = baseBridge('BRIDGE_08','internal_mass_energy_scaling', ...
        massEnergy.equation);
    b.source_datasets = {cfg.primaryDataset};
    b.intrinsic_score = massEnergy.score;
    b.cross_dataset_score = 0;
    b.scale_stability = scaleStability;
    b.temporal_stability = temporalStability;
    b.graph_support = graphSupport;
    b.phase_support = phaseSupport;
    b.residual = massEnergy.residual;
    b.details = massEnergy;
    b.status = bridgeStatus(b,cfg);
    bridges(end+1) = b; %#ok<AGROW>

    logLine(logFid, 'Final bridges evaluated: %d.',numel(bridges));
end


function b = baseBridge(id,family,equation)
    b = struct;
    b.relation_id = id;
    b.family = family;
    b.equation = equation;
    b.source_datasets = {};
    b.intrinsic_score = 0;
    b.cross_dataset_score = 0;
    b.scale_stability = 0;
    b.channel_stability = 0;
    b.region_stability = 0;
    b.temporal_stability = 0;
    b.graph_support = 0;
    b.phase_support = 0;
    b.residual = NaN;
    b.status = 'NON_CANONICAL';
    b.canonical = false;
end


function status = bridgeStatus(b,cfg)
    if ~isfinite(b.residual)
        status = 'INSUFFICIENT_STRUCTURE';
    elseif b.intrinsic_score>=cfg.discovery.minIntrinsicScore && ...
           b.cross_dataset_score>=cfg.discovery.minCrossScore
        status = 'CROSS_DATASET_CORROBORATED';
    elseif b.intrinsic_score>=cfg.discovery.minIntrinsicScore
        status = 'INTRINSIC_DISCOVERY';
    else
        status = 'INSUFFICIENT_STRUCTURE';
    end
end


function score = comparisonScore(comparisons,family)
    score = 0;
    for i = 1:numel(comparisons)
        if strcmp(comparisons(i).family,family)
            score = comparisons(i).score;
            return;
        end
    end
end


function s = phaseCoefficientStability(P)
    valid = all(isfinite(P),2);
    P = P(valid,:);
    if size(P,1)<2
        s = 0;
        return;
    end
    coeff = P(:,1:3);
    cv = mean(std(coeff,0,1)./(abs(mean(coeff,1))+eps));
    s = clamp01(1-cv);
end


function [residual,details] = rationalFamilyResidual(ratios)
    if isempty(ratios)
        residual = 1;
        details = struct('ratios',[],'numerator',[],'denominator',[]);
        return;
    end

    numerator = zeros(size(ratios));
    denominator = zeros(size(ratios));
    approx = zeros(size(ratios));
    for i = 1:numel(ratios)
        [n,d] = rat(ratios(i),1e-2);
        if d>12
            bestErr = Inf;
            bestN = 0;
            bestD = 1;
            for dd = 1:12
                nn = round(ratios(i)*dd);
                err = abs(ratios(i)-nn/dd);
                if err<bestErr
                    bestErr = err;
                    bestN = nn;
                    bestD = dd;
                end
            end
            n = bestN;
            d = bestD;
        end
        numerator(i) = n;
        denominator(i) = d;
        approx(i) = n/d;
    end
    residual = mean(abs(ratios-approx));
    details = struct('ratios',ratios,'numerator',numerator, ...
        'denominator',denominator,'approximation',approx);
end


function center = calculateCenterMetrics(fields,topology,phaseMaps)
    H = size(fields.composite,1);
    W = size(fields.composite,2);
    r0 = round((H+1)/2);
    c0 = round((W+1)/2);
    radius = 20;

    [C,R] = meshgrid(1:W,1:H);
    centerMask = hypot(R-r0,C-c0)<=radius;

    attentionExtremum = mean(double(fields.salienceBase(centerMask))) / ...
        (mean(double(fields.salienceBase(:)))+eps);
    attentionExtremum = clamp01(attentionExtremum/3);

    pathDensity = nnz(topology.skeleton(centerMask))/(nnz(topology.skeleton)+eps);
    expectedArea = nnz(centerMask)/(H*W);
    pathDensity = clamp01(pathDensity/(expectedArea+eps)/5);

    rotated = rot90(fields.composite,2);
    rotationSymmetry = max(0,correlationSafe(fields.composite,rotated));

    phaseCoherence = mean(double(phaseMaps.coherenceMap(centerMask)),'omitnan');
    if ~isfinite(phaseCoherence)
        phaseCoherence = 0;
    end

    center = struct;
    center.row = r0;
    center.column = c0;
    center.attentionExtremum = attentionExtremum;
    center.pathDensity = pathDensity;
    center.rotationSymmetry = rotationSymmetry;
    center.phaseCoherence = phaseCoherence;
    center.combined = clamp01(mean([attentionExtremum,pathDensity, ...
        rotationSymmetry,phaseCoherence]));
end


function out = discoverInternalMassEnergyScaling(graphData,cfg)
    nodes = graphData.nodes;
    keep = nodes.node_type~="DEFECT_REFERENCE";
    idx = find(keep);

    if numel(idx)<8
        out = struct('equation','E_b = alpha*DeltaM + beta', ...
            'alpha',NaN,'beta',NaN,'exponent',NaN, ...
            'residual',NaN,'score',0,'cluster_count',0);
        return;
    end

    features = [ ...
        double(nodes.row(idx))/max(nodes.row), ...
        double(nodes.column(idx))/max(nodes.column), ...
        normalizeRobust(double(nodes.amplitude(idx)),0,1), ...
        cos(nanToZero(double(nodes.phase_rad(idx)))), ...
        sin(nanToZero(double(nodes.phase_rad(idx))))];

    k = min(6,max(3,round(sqrt(numel(idx)/5))));
    [cluster,~,~] = simpleKmeansStable(features,k,10,cfg.runtime.randomSeed);

    deltaM = zeros(k,1);
    binding = zeros(k,1);

    nodeToLocal = zeros(height(nodes),1);
    nodeToLocal(idx) = 1:numel(idx);

    for c = 1:k
        local = find(cluster==c);
        globalIdx = idx(local);
        amp = max(0,double(nodes.amplitude(globalIdx)));
        ph = nanToZero(double(nodes.phase_rad(globalIdx)));
        separatedMass = sum(amp);
        coupledMass = abs(sum(amp.*exp(1i*ph)));
        deltaM(c) = max(0,separatedMass-coupledMass);

        maskS = ismember(graphData.edges.source_node,nodes.node_id(globalIdx));
        maskT = ismember(graphData.edges.target_node,nodes.node_id(globalIdx));
        internalEdge = maskS & maskT;
        binding(c) = sum(double(graphData.edges.weight(internalEdge)));
    end

    valid = deltaM>0 & binding>=0 & isfinite(deltaM) & isfinite(binding);
    if nnz(valid)<2 || norm(binding(valid))<eps
        out = struct('equation','E_b = alpha*DeltaM + beta', ...
            'alpha',NaN,'beta',NaN,'exponent',NaN, ...
            'residual',NaN,'score',0,'cluster_count',k, ...
            'deltaM',deltaM,'bindingEnergy',binding);
        return;
    end

    A = [deltaM(valid) ones(nnz(valid),1)];
    coeff = A\binding(valid);
    pred = A*coeff;
    residual = norm(binding(valid)-pred)/(norm(binding(valid))+eps);
    score = clamp01(exp(-5*residual));

    exponent = NaN;
    pos = deltaM(valid)>0 & binding(valid)>0;
    if nnz(pos)>=2
        x = log(deltaM(valid));
        y = log(binding(valid));
        pp = [x ones(size(x))]\y;
        exponent = pp(1);
    end

    out = struct;
    out.equation = sprintf('E_b = %.12g*DeltaM + %.12g',coeff(1),coeff(2));
    out.alpha = coeff(1);
    out.beta = coeff(2);
    out.exponent = exponent;
    out.residual = residual;
    out.score = score;
    out.cluster_count = k;
    out.deltaM = deltaM;
    out.bindingEnergy = binding;
end


%% ========================================================================
function ledger = buildCoherenceLedger(bridges, graphData, phaseMaps, ...
    coarse, fine, tk, cfg)

    ledger = bridges;

    channelStability = channelCorrelationStability(fine);
    regionStability = regionalStability(phaseMaps.combinedAmplitude);
    coarseFineStability = coarseFineAgreement(coarse,fine);

    for i = 1:numel(ledger)
        ledger(i).channel_stability = channelStability;
        ledger(i).region_stability = regionStability;
        ledger(i).coarse_fine_alignment = coarseFineStability;
        ledger(i).timekernel_period_samples = tk.dominantPeriodSamples;
        ledger(i).timekernel_frequency_hz = tk.dominantFrequencyHz;
        ledger(i).phase_concentration = tk.phaseConcentration;
        ledger(i).graph_node_count = graphData.validity.node_count;
        ledger(i).graph_edge_count = graphData.validity.edge_count;
        ledger(i).canonical = false;

        scores = [ledger(i).intrinsic_score,ledger(i).cross_dataset_score, ...
            ledger(i).scale_stability,ledger(i).channel_stability, ...
            ledger(i).region_stability,ledger(i).temporal_stability, ...
            ledger(i).graph_support,ledger(i).phase_support];
        scores = scores(isfinite(scores) & scores>=0);
        if isempty(scores)
            ledger(i).coherence_score = 0;
        else
            ledger(i).coherence_score = exp(mean(log(max(scores,1e-6))));
        end
    end
end


function s = channelCorrelationStability(fine)
    M = [fine.projection_norm fine.temporal_norm fine.multiscale_norm ...
         fine.field_structure_norm fine.memory_norm];
    C = corrcoef(M);
    vals = abs(C(triu(true(size(C)),1)));
    s = median(vals,'omitnan');
    if ~isfinite(s), s=0; end
end


function s = regionalStability(map)
    H = size(map,1);
    W = size(map,2);
    means = zeros(4,1);
    means(1) = mean(map(1:floor(H/2),1:floor(W/2)),'all');
    means(2) = mean(map(1:floor(H/2),floor(W/2)+1:end),'all');
    means(3) = mean(map(floor(H/2)+1:end,1:floor(W/2)),'all');
    means(4) = mean(map(floor(H/2)+1:end,floor(W/2)+1:end),'all');
    s = clamp01(1-std(means)/(mean(means)+eps));
end


function s = coarseFineAgreement(coarse,fine)
    coarsePeak = coarse.source_center(coarse.combined_norm==max(coarse.combined_norm));
    finePeak = fine.source_sample(fine.combined_norm==max(fine.combined_norm));
    coarsePeak = coarsePeak(1);
    finePeak = finePeak(1);
    scale = max(fine.source_sample)-min(fine.source_sample)+1;
    s = clamp01(exp(-abs(double(coarsePeak)-double(finePeak))/scale));
end


%% ========================================================================
function writeAuxiliaryNumericalArtifacts(outputDir, coarse, coarseEvents, fine, ...
    fields, tk, topology, geometry, manifold, quanta, cfg)

    writetable(coarse,fullfile(outputDir,'coarse_salience.csv'));
    writetable(coarseEvents,fullfile(outputDir,'coarse_salience_events.csv'));
    writetable(fine,fullfile(outputDir,'high_resolution_salience.csv'));
    writetable(tk.periodCandidates,fullfile(outputDir,'timekernel_period_candidates.csv'));

    peakSchedule = table;
    peakSchedule.peak_order = (1:numel(tk.peakSourceSample)).';
    peakSchedule.source_sample = tk.peakSourceSample;
    peakSchedule.target_time_sec = tk.targetTimeSec;
    peakSchedule.phase_rad = tk.phaseRad;
    peakSchedule.cycle_id = tk.cycleId;
    peakSchedule.salience = tk.peakValue;
    peakSchedule.next_interval_samples = tk.nextIntervalSamples;
    peakSchedule.next_interval_sec = tk.nextIntervalSec;
    writetable(peakSchedule,fullfile(outputDir,'timekernel_peak_schedule.csv'));

    replayTable = table(tk.replayTimeSec,tk.replaySignal, ...
        'VariableNames',{'time_sec','timekernel_signal'});
    writetable(replayTable,fullfile(outputDir,'timekernel_replay_signal.csv'));

    acfPath = fullfile(outputDir,'timekernel_autocorrelation.h5');
    deleteIfExists(acfPath);
    createAndWriteH5(acfPath,'/lag',single(tk.lag));
    createAndWriteH5(acfPath,'/autocorrelation',single(tk.autocorrelation));
    createAndWriteH5(acfPath,'/frequency',single(tk.frequency));
    createAndWriteH5(acfPath,'/power_spectrum',single(tk.powerSpectrum));

    writetable(topology.cores,fullfile(outputDir,'phase_cores.csv'));
    writetable(topology.junctions,fullfile(outputDir,'y_junctions.csv'));
    branchSummary = geometry.branchTable;
    if ~isempty(branchSummary)
        branchPaths = branchSummary(:,{'branch_id','rows','columns'});
        save(fullfile(outputDir,'branch_paths.mat'),'branchPaths','-v7.3');
        branchSummary = removevars(branchSummary,{'rows','columns'});
    end
    writetable(branchSummary,fullfile(outputDir,'branch_geometry.csv'));

    manifoldTable = table(manifold.sampleRows,manifold.sampleColumns, ...
        manifold.embedding(:,1),manifold.embedding(:,2), ...
        'VariableNames',{'row','column','embedding_1','embedding_2'});
    writetable(manifoldTable,fullfile(outputDir,'manifold_embedding.csv'));

    writetable(quanta.table,fullfile(outputDir,'knowledge_quanta.csv'));

    if cfg.runtime.writeLargeFieldFamily
        fieldPath = fullfile(outputDir,'intrinsic_field_family.h5');
        deleteIfExists(fieldPath);
        createAndWriteH5(fieldPath,'/composite',fields.composite);
        createAndWriteH5(fieldPath,'/gradient_magnitude',fields.gradientMagnitude);
        createAndWriteH5(fieldPath,'/ridge',fields.ridge);
        createAndWriteH5(fieldPath,'/coherence',fields.coherence);
        createAndWriteH5(fieldPath,'/orientation',fields.orientation);
        createAndWriteH5(fieldPath,'/phase',fields.phase);
        createAndWriteH5(fieldPath,'/phase_amplitude',fields.phaseAmplitude);
        createAndWriteH5(fieldPath,'/salience_base',fields.salienceBase);
        createAndWriteH5(fieldPath,'/metric/g11',fields.metricG11);
        createAndWriteH5(fieldPath,'/metric/g12',fields.metricG12);
        createAndWriteH5(fieldPath,'/metric/g22',fields.metricG22);
        h5create(fieldPath,'/metadata/shape',[1 3],'Datatype','double');
        h5write(fieldPath,'/metadata/shape',double(cfg.primaryShape));
        writetable(fields.scaleStats,fullfile(outputDir,'field_scale_statistics.csv'));
    end
end


%% ========================================================================
function createFinalContactSheet(path, fields, coarse, fine, tk, phaseMaps, ...
    topology, graphData, geometry, manifold, cfg)

    fig = figure('Visible','off','Color','w','Position',[100 100 1800 1200]);
    cleanup = onCleanup(@() close(fig)); 

    subplot(3,4,1);
    imagesc(fields.composite); axis image off; colormap(gca,gray);
    title('Source H5 composite');

    subplot(3,4,2);
    imagesc(fields.salienceBase); axis image off;
    title('Intrinsic salience');

    subplot(3,4,3);
    imagesc(fields.ridge); axis image off;
    title('Ridge response');

    subplot(3,4,4);
    imagesc(fields.coherence,[0 1]); axis image off;
    title('Orientation coherence');

    subplot(3,4,5);
    plot(coarse.t_step,coarse.combined_norm,'k','LineWidth',1); hold on;
    plot(coarse.t_step,coarse.memory_norm,'LineWidth',1);
    xlabel('coarse t step'); ylabel('normalized');
    title('Coarse salience + memory');
    legend({'combined','memory'},'Location','best');

    subplot(3,4,6);
    plot(fine.source_sample,fine.combined_norm,'k'); hold on;
    plot(fine.source_sample,fine.memory_norm);
    xlabel('source sample'); ylabel('normalized');
    title('High-resolution salience');

    subplot(3,4,7);
    plot(tk.lag,tk.autocorrelation,'LineWidth',1);
    xlim([0 min(max(tk.lag),cfg.timeKernel.maxLag)]);
    xlabel('lag samples'); ylabel('autocorrelation');
    title(sprintf('TimeKernel period = %d',tk.dominantPeriodSamples));

    subplot(3,4,8);
    plot(tk.replayTimeSec,tk.replaySignal,'LineWidth',1);
    xlabel('time seconds'); ylabel('pulse');
    title('Executable replay signal');

    subplot(3,4,9);
    imagesc(phaseMaps.combinedAmplitude); axis image off;
    title('Complex anchor amplitude');

    subplot(3,4,10);
    imagesc(phaseMaps.cosMap); axis image off;
    title('Phase cos');

    subplot(3,4,11);
    imagesc(phaseMaps.sinMap); axis image off;
    title('Phase sin');

    subplot(3,4,12);
    imagesc(fields.composite); axis image off; hold on;
    if ~isempty(topology.cores)
        plot(topology.cores.column,topology.cores.row,'o','MarkerSize',4);
    end
    if ~isempty(topology.junctions)
        plot(topology.junctions.column,topology.junctions.row,'x','MarkerSize',6);
    end
    title(sprintf('Cores %d | Y %d | graph %d/%d', ...
        height(topology.cores),height(topology.junctions), ...
        graphData.validity.node_count,graphData.validity.edge_count));

    sgtitle(sprintf('YEHOSHUA v3 FINAL COHERENCE | geo %.3f | disk %.3f', ...
        geometry.intrinsicGeodesicMean,manifold.diskScore));

    exportgraphics(fig,path,'Resolution',180);
end


%% ========================================================================
function quality = runFinalOutputQualityGates(ssot, audit, X, anchors, events, ...
    phaseMaps, ~, graphData, ledger, contactSheetPath, outputDir, ...
    cfg, logFid)

    gates = struct;
    gates.hash_match = ssot.hashMatch || ~cfg.requireHashMatch;
    gates.shape_audit = audit.shape_compatible && audit.round_trip_valid;
    gates.finite_primary_field = all(isfinite(X(:)));
    gates.source_variance_positive = var(double(X(:)))>0;
    gates.nonempty_anchors = height(anchors)>0;
    gates.nonempty_events = height(events)>0;
    gates.finite_phase_real = all(isfinite(phaseMaps.cosMap(:)));
    gates.finite_phase_imag = all(isfinite(phaseMaps.sinMap(:)));
    gates.finite_phase_coherence = all(isfinite(phaseMaps.coherenceMap(:)));
    gates.nonempty_anchor_map = max(phaseMaps.combinedAmplitude(:))>0;
    gates.graph_valid = graphData.validity.is_valid;
    gates.finite_ledger = all(arrayfun(@(x) ...
        isfinite(x.intrinsic_score) && isfinite(x.coherence_score),ledger));
    gates.contact_sheet_exists = isfile(contactSheetPath);

    occupiedPixelRatio = 0;
    if gates.contact_sheet_exists
        img = imread(contactSheetPath);
        if ndims(img)==3
            background = reshape(img(1,1,:),1,1,[]);
            delta = max(abs(double(img)-double(background)),[],3);
        else
            delta = abs(double(img)-double(img(1,1)));
        end
        occupiedPixelRatio = nnz(delta>2)/numel(delta);
    end
    gates.contact_sheet_occupied = occupiedPixelRatio >= ...
        cfg.quality.minimumOccupiedPixelRatio;

    artifactFiles = dir(outputDir);
    gates.artifact_count = nnz(~[artifactFiles.isdir]);
    gates.artifact_count_sufficient = gates.artifact_count>=15;

    passValues = [ ...
        gates.hash_match, ...
        gates.shape_audit, ...
        gates.finite_primary_field, ...
        gates.source_variance_positive, ...
        gates.nonempty_anchors, ...
        gates.nonempty_events, ...
        gates.finite_phase_real, ...
        gates.finite_phase_imag, ...
        gates.finite_phase_coherence, ...
        gates.nonempty_anchor_map, ...
        gates.graph_valid, ...
        gates.finite_ledger, ...
        gates.contact_sheet_exists, ...
        gates.contact_sheet_occupied, ...
        gates.artifact_count_sufficient];

    quality = struct;
    quality.pass = all(passValues);
    quality.gates = gates;
    quality.contact_sheet_occupied_pixel_ratio = occupiedPixelRatio;
    quality.status = ternary(quality.pass,'VALIDATED_OUTPUT','INVALID_OUTPUT');

    logLine(logFid, 'Quality status: %s.',quality.status);

    if ~quality.pass
        error('INVALID_OUTPUT: one or more final quality gates failed.');
    end
end


%% ========================================================================
function manifest = buildRunManifest(cfg, ssot, registry, audit, coarse, fine, ...
    tk, anchors, events, topology, graphData, bridges, ledger, quality, ...
    outputDir, timestamp)

    manifest = struct;
    manifest.version = cfg.version;
    manifest.timestamp = timestamp;
    manifest.output_directory = outputDir;
    manifest.source = struct( ...
        'file',ssot.file, ...
        'sha256',ssot.sha256, ...
        'hash_match',ssot.hashMatch, ...
        'primary_dataset',cfg.primaryDataset, ...
        'input_policy','UNIFIED_H5_ONLY');
    manifest.dataset_registry_count = height(registry);
    manifest.shape_audit = audit;
    manifest.coarse = struct( ...
        'steps',height(coarse), ...
        'peak_source_sample',coarse.source_center( ...
            find(coarse.combined_norm==max(coarse.combined_norm),1)));
    manifest.fine = struct( ...
        'window_start',fine.source_sample(1), ...
        'window_end',fine.source_sample(end), ...
        'sample_count',height(fine), ...
        'peak_source_sample',fine.source_sample( ...
            find(fine.combined_norm==max(fine.combined_norm),1)));
    manifest.timekernel = struct( ...
        'dominant_period_samples',tk.dominantPeriodSamples, ...
        'dominant_period_sec',tk.dominantPeriodSec, ...
        'dominant_frequency_hz',tk.dominantFrequencyHz, ...
        'event_count',numel(tk.peakSourceSample), ...
        'phase_concentration',tk.phaseConcentration, ...
        'circular_mean_phase_rad',tk.circularMeanPhase);
    manifest.counts = struct( ...
        'anchors',height(anchors), ...
        'events',height(events), ...
        'phase_cores',height(topology.cores), ...
        'y_junctions',height(topology.junctions), ...
        'branches',height(topology.branches), ...
        'graph_nodes',height(graphData.nodes), ...
        'graph_edges',height(graphData.edges), ...
        'bridges',numel(bridges), ...
        'ledger_entries',numel(ledger));
    manifest.graph_validity = graphData.validity;
    manifest.quality = quality;
    manifest.canonical = false;
    manifest.status = 'NON_CANONICAL';
end


%% ========================================================================
% Generic numerical helpers
% ========================================================================

function y = normalizeRobust(x,qLow,qHigh)
    originalSize = size(x);
    x = double(x);
    finite = x(isfinite(x));
    if isempty(finite)
        y = zeros(originalSize,'single');
        return;
    end

    lo = quantileLocal(finite,qLow);
    hi = quantileLocal(finite,qHigh);
    if hi<=lo
        lo = min(finite);
        hi = max(finite);
    end
    if hi<=lo
        y = zeros(originalSize,'single');
        return;
    end

    y = (x-lo)/(hi-lo);
    y = min(max(y,0),1);
    y(~isfinite(y)) = 0;
    y = reshape(single(y),originalSize);
end


function q = quantileLocal(x,p)
    x = sort(double(x(isfinite(x))));
    if isempty(x)
        q = NaN;
        return;
    end
    p = min(max(double(p),0),1);
    pos = 1+p*(numel(x)-1);
    lo = floor(pos);
    hi = ceil(pos);
    if lo==hi
        q = x(lo);
    else
        q = x(lo)+(pos-lo)*(x(hi)-x(lo));
    end
end


function qv = quantileVector(x,n)
    probs = linspace(0,1,n);
    qv = zeros(n,1);
    for i = 1:n
        qv(i) = quantileLocal(x,probs(i));
    end
end


function y = gaussianBlur2D(x,sigma)
    if sigma<=0
        y = x;
        return;
    end
    radius = max(1,ceil(4*sigma));
    t = -radius:radius;
    k = exp(-(t.^2)/(2*sigma^2));
    k = k/sum(k);
    y = conv2(conv2(single(x),single(k),'same'),single(k.'),'same');
end


function z = analyticSignalFFT(x,dim)
    x = double(x);
    n = size(x,dim);
    X = fft(x,[],dim);

    h = zeros(n,1);
    if mod(n,2)==0
        h(1) = 1;
        h(n/2+1) = 1;
        h(2:n/2) = 2;
    else
        h(1) = 1;
        h(2:(n+1)/2) = 2;
    end

    shape = ones(1,ndims(x));
    shape(dim) = n;
    h = reshape(h,shape);
    z = ifft(X.*h,[],dim);
end


function reduced = blockReduce(x,nBlocks,mode)
    x = double(x(:));
    N = numel(x);
    edges = round(linspace(1,N+1,nBlocks+1));
    reduced = zeros(nBlocks,1);
    for i = 1:nBlocks
        a = edges(i);
        b = max(a,edges(i+1)-1);
        segment = x(a:b);
        switch lower(mode)
            case 'max'
                reduced(i) = max(segment);
            case 'mean'
                reduced(i) = mean(segment);
            case 'median'
                reduced(i) = median(segment);
            otherwise
                error('Unknown block reduction mode.');
        end
    end
end


function idx = selectPeaks(signal,maxCount,minDistance,threshold)
    x = double(signal(:));
    candidates = localMaxima(x);
    if threshold<=1
        if threshold<0
            thresholdValue = -Inf;
        elseif threshold>min(x) && threshold<max(x)
            thresholdValue = threshold;
        else
            thresholdValue = quantileLocal(x,threshold);
        end
    else
        thresholdValue = threshold;
    end
    candidates = candidates(x(candidates)>=thresholdValue);

    [~,ord] = sort(x(candidates),'descend');
    selected = [];
    for k = 1:numel(ord)
        c = candidates(ord(k));
        if isempty(selected) || all(abs(c-selected)>=minDistance)
            selected(end+1,1) = c; %#ok<AGROW>
            if numel(selected)>=maxCount
                break;
            end
        end
    end
    idx = selected;
end


function idx = localMaxima(x)
    x = double(x(:));
    if numel(x)<3
        [~,idx] = max(x);
        return;
    end
    idx = find(x(2:end-1)>=x(1:end-2) & x(2:end-1)>x(3:end))+1;
end


function acf = normalizedAutocorrelationFFT(x,maxLag)
    x = double(x(:));
    x = x-mean(x);
    nfft = 2^nextpow2(2*numel(x)-1);
    f = fft(x,nfft);
    ac = real(ifft(abs(f).^2));
    ac = ac(1:maxLag+1);
    ac = ac/(ac(1)+eps);
    acf = ac(:);
end


function sel = selectSpatialFeatures(rows,cols,scores,maxCount,minDistance)
    if isempty(rows)
        sel = [];
        return;
    end
    [~,ord] = sort(scores,'descend');
    selected = [];
    for k = 1:numel(ord)
        i = ord(k);
        if isempty(selected)
            selected = i;
        else
            d = hypot(double(rows(i)-rows(selected)),double(cols(i)-cols(selected)));
            if all(d>=minDistance)
                selected(end+1) = i; %#ok<AGROW>
            end
        end
        if numel(selected)>=maxCount
            break;
        end
    end
    sel = selected(:);
end


function components = binaryComponents(B)
    B = logical(B);
    if exist('bwconncomp','file') == 2
        cc = bwconncomp(B,8);
        components = cc.PixelIdxList(:);
        return;
    end
    [H,W] = size(B);
    visited = false(H,W);
    components = {};
    neighbor = [-1 -1;-1 0;-1 1;0 -1;0 1;1 -1;1 0;1 1];

    candidates = find(B);
    for n = 1:numel(candidates)
        start = candidates(n);
        if visited(start)
            continue;
        end

        queue = start;
        visited(start) = true;
        component = zeros(0,1);
        head = 1;

        while head<=numel(queue)
            idx = queue(head);
            head = head+1;
            component(end+1,1) = idx; %#ok<AGROW>
            [r,c] = ind2sub([H W],idx);

            for k = 1:8
                rr = r+neighbor(k,1);
                cc = c+neighbor(k,2);
                if rr>=1 && rr<=H && cc>=1 && cc<=W
                    ii = sub2ind([H W],rr,cc);
                    if B(ii) && ~visited(ii)
                        visited(ii) = true;
                        queue(end+1,1) = ii; %#ok<AGROW>
                    end
                end
            end
        end
        components{end+1,1} = component; %#ok<AGROW>
    end
end


function [rOrdered,cOrdered] = orderSkeletonComponent(r,c)
    n = numel(r);
    if n<=2
        rOrdered = r;
        cOrdered = c;
        return;
    end

    coord = [r(:) c(:)];
    if n>2000
        centered = coord-mean(coord,1);
        [~,~,V] = svd(centered,'econ');
        projection = centered*V(:,1);
        [~,ord] = sort(projection);
        rOrdered = r(ord);
        cOrdered = c(ord);
        return;
    end
    D = pairwiseEuclidean(coord);
    adjacency = D>0 & D<=sqrt(2)+1e-6;
    degree = sum(adjacency,2);
    endpoints = find(degree<=1);
    if isempty(endpoints)
        current = 1;
    else
        current = endpoints(1);
    end

    visited = false(n,1);
    order = zeros(n,1);
    for k = 1:n
        order(k) = current;
        visited(current) = true;
        nbr = find(adjacency(current,:) & ~visited.');
        if isempty(nbr)
            remaining = find(~visited);
            if isempty(remaining)
                order = order(1:k);
                break;
            end
            [~,jj] = min(D(current,remaining));
            current = remaining(jj);
        else
            [~,jj] = min(D(current,nbr));
            current = nbr(jj);
        end
    end

    rOrdered = r(order);
    cOrdered = c(order);
end


function D = pairwiseEuclidean(X)
    X = double(X);
    s = sum(X.^2,2);
    D2 = max(0,s+s.'-2*(X*X.'));
    D = sqrt(D2);
end


function [s,t,type,w,d,pd,td] = appendEdge(s,t,type,w,d,pd,td, ...
    i,j,newType,newWeight,newDistance,newPhase,newTime)
    if i==j
        return;
    end
    s(end+1,1) = i;
    t(end+1,1) = j;
    type(end+1,1) = newType;
    w(end+1,1) = newWeight;
    d(end+1,1) = newDistance;
    pd(end+1,1) = newPhase;
    td(end+1,1) = newTime;
end


function [s,t,type,w,d,pd,td] = deduplicateEdges(s,t,type,w,d,pd,td)
    if isempty(s)
        return;
    end
    lo = min(s,t);
    hi = max(s,t);
    key = string(lo)+"_"+string(hi)+"_"+type;
    [~,~,group] = unique(key,'stable');

    keepS = zeros(max(group),1);
    keepT = zeros(max(group),1);
    keepType = strings(max(group),1);
    keepW = zeros(max(group),1);
    keepD = zeros(max(group),1);
    keepPD = zeros(max(group),1);
    keepTD = zeros(max(group),1);

    for g = 1:max(group)
        idx = find(group==g);
        [~,best] = max(w(idx));
        ii = idx(best);
        keepS(g) = s(ii);
        keepT(g) = t(ii);
        keepType(g) = type(ii);
        keepW(g) = w(ii);
        keepD(g) = d(ii);
        keepPD(g) = pd(ii);
        keepTD(g) = td(ii);
    end
    s=keepS; t=keepT; type=keepType; w=keepW; d=keepD; pd=keepPD; td=keepTD;
end


function comp = connectedComponentsSparse(A)
    n = size(A,1);
    comp = zeros(n,1);
    cid = 0;
    for i = 1:n
        if comp(i)~=0
            continue;
        end
        cid = cid+1;
        queue = i;
        comp(i) = cid;
        head = 1;
        while head<=numel(queue)
            u = queue(head);
            head = head+1;
            nbr = find(A(u,:)>0);
            for v = nbr
                if comp(v)==0
                    comp(v)=cid;
                    queue(end+1)=v; %#ok<AGROW>
                end
            end
        end
    end
end


function d = circularDifference(a,b)
    if ~isfinite(a) || ~isfinite(b)
        d = NaN;
    else
        d = abs(wrapAngle(a-b));
    end
end


function x = wrapAngle(x)
    x = atan2(sin(x),cos(x));
end


function m = medianFinite(x)
    x = x(isfinite(x));
    if isempty(x)
        m = 1;
    else
        m = median(x);
    end
end


function c = correlationSafe(a,b)
    a = double(a(:));
    b = double(b(:));
    valid = isfinite(a) & isfinite(b);
    a = a(valid); b = b(valid);
    if numel(a)<2 || std(a)==0 || std(b)==0
        c = 0;
    else
        C = corrcoef(a,b);
        c = C(1,2);
        if ~isfinite(c), c=0; end
    end
end


function Xs = standardizeColumns(X)
    X = double(X);
    mu = mean(X,1,'omitnan');
    sd = std(X,0,1,'omitnan');
    sd(sd<eps)=1;
    Xs = (X-mu)./sd;
    Xs(~isfinite(Xs))=0;
end


function score = neighborhoodJaccard(X,Y,k)
    DX = pairwiseEuclidean(X);
    DY = pairwiseEuclidean(Y);
    n = size(X,1);
    vals = zeros(n,1);
    for i = 1:n
        [~,ox] = sort(DX(i,:),'ascend');
        [~,oy] = sort(DY(i,:),'ascend');
        nx = ox(2:min(k+1,n));
        ny = oy(2:min(k+1,n));
        vals(i) = numel(intersect(nx,ny))/max(1,numel(union(nx,ny)));
    end
    score = mean(vals);
end


function pcaMaps = spatialPCA(field,k)
    [H,W,C] = size(field);
    Y = reshape(field,[],C);
    Y = double(Y);
    Y = Y-mean(Y,1);
    [~,~,V] = svd(Y(round(linspace(1,size(Y,1),min(100000,size(Y,1)))),:),'econ');
    scores = Y*V(:,1:k);
    pcaMaps = zeros(H,W,k,'single');
    for i = 1:k
        pcaMaps(:,:,i)=reshape(single(scores(:,i)),H,W);
    end
end


function out = resize2D(in,newSize)
    in = double(in);
    [H,W] = size(in);
    [Xq,Yq] = meshgrid(linspace(1,W,newSize(2)),linspace(1,H,newSize(1)));
    [X,Y] = meshgrid(1:W,1:H);
    out = interp2(X,Y,in,Xq,Yq,'linear',0);
end


function [labels,centers,score] = simpleKmeansStable(X,k,restarts,seed)
    rng(seed);
    X = double(X);
    n = size(X,1);
    if k<=1 || n<=k
        labels = ones(n,1);
        centers = mean(X,1);
        score = 1;
        return;
    end

    bestObjective = Inf;
    bestLabels = ones(n,1);
    bestCenters = [];

    for r = 1:restarts
        init = randperm(n,k);
        centersR = X(init,:);
        labelsR = ones(n,1);

        for iter = 1:100
            D = zeros(n,k);
            for j = 1:k
                diff = X-centersR(j,:);
                D(:,j)=sum(diff.^2,2);
            end
            [~,newLabels] = min(D,[],2);
            if iter>1 && all(newLabels==labelsR)
                break;
            end
            labelsR = newLabels;
            for j = 1:k
                if any(labelsR==j)
                    centersR(j,:)=mean(X(labelsR==j,:),1);
                else
                    centersR(j,:)=X(randi(n),:);
                end
            end
        end

        objective = 0;
        for j = 1:k
            diff = X(labelsR==j,:)-centersR(j,:);
            objective = objective+sum(diff(:).^2);
        end

        if objective<bestObjective
            bestObjective=objective;
            bestLabels=labelsR;
            bestCenters=centersR;
        end
    end

    total = sum((X-mean(X,1)).^2,'all')+eps;
    labels = bestLabels;
    centers = bestCenters;
    score = clamp01(1-bestObjective/total);
end


function status = statusFromScore(score,threshold)
    if ~isfinite(score)
        status = 'INSUFFICIENT_STRUCTURE';
    elseif score>=threshold
        status = 'CROSS_DATASET_CORROBORATED';
    else
        status = 'INSUFFICIENT_STRUCTURE';
    end
end


function y = nanToZero(x)
    y = x;
    y(~isfinite(y))=0;
end


function y = clamp01(x)
    y = max(0,min(1,double(x)));
    if ~isfinite(y), y=0; end
end


function result = ternary(condition,a,b)
    if condition
        result = a;
    else
        result = b;
    end
end


%% ========================================================================
% File-output helpers
% ========================================================================

function createAndWriteH5(filePath,datasetPath,data)
    data = single(data);
    h5create(filePath,datasetPath,size(data),'Datatype','single', ...
        'ChunkSize',chooseChunkSize(size(data)),'Deflate',4);
    h5write(filePath,datasetPath,data);
end


function chunk = chooseChunkSize(sz)
    sz = double(sz);
    if numel(sz)==2 && any(sz==1)
        chunk = [min(sz(1),65536) min(sz(2),65536)];
        chunk(chunk<1)=1;
        return;
    end

    chunk = sz;
    if numel(sz)>=1
        chunk(1)=min(sz(1),128);
    end
    if numel(sz)>=2
        chunk(2)=min(sz(2),128);
    end
    if numel(sz)>=3
        chunk(3)=min(sz(3),1);
    end
    chunk(chunk<1)=1;
end

function deleteIfExists(path)
    if isfile(path)
        delete(path);
    end
end


function writeJSON(path,data)
    data = sanitizeForJSON(data);
    try
        txt = jsonencode(data,'PrettyPrint',true);
    catch
        txt = jsonencode(data);
    end
    fid = fopen(path,'w');
    if fid<0, error('Could not write JSON: %s',path); end
    cleanup = onCleanup(@() fclose(fid)); 
    fwrite(fid,txt,'char');
end


function writeJSONL(path,items)
    fid = fopen(path,'w');
    if fid<0, error('Could not write JSONL: %s',path); end
    cleanup = onCleanup(@() fclose(fid)); 
    for i = 1:numel(items)
        line = jsonencode(sanitizeForJSON(items(i)));
        fprintf(fid,'%s\n',line);
    end
end


function out = sanitizeForJSON(in)
    if istable(in)
        out = tableToStructArray(in);
    elseif isstruct(in)
        out = in;
        fields = fieldnames(out);
        for i = 1:numel(out)
            for f = 1:numel(fields)
                out(i).(fields{f}) = sanitizeForJSON(out(i).(fields{f}));
            end
        end
    elseif iscell(in)
        out = cellfun(@sanitizeForJSON,in,'UniformOutput',false);
    elseif isnumeric(in)
        out = in;
        out(~isfinite(out)) = NaN;
    elseif isstring(in)
        out = cellstr(in);
    else
        out = in;
    end
end


function s = tableToStructArray(T)
    if isempty(T)
        s = struct([]);
        return;
    end
    s = table2struct(T);
end


function logLine(fid,format,varargin)
    stamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
    msg = sprintf(format,varargin{:});
    fprintf(fid,'[%s] %s\n',stamp,msg);
    fprintf('[%s] %s\n',stamp,msg);
end


function out = mergeStructRecursive(base,override)
    out = base;
    names = fieldnames(override);
    for i = 1:numel(names)
        name = names{i};
        if isfield(out,name) && isstruct(out.(name)) && isstruct(override.(name))
            out.(name)=mergeStructRecursive(out.(name),override.(name));
        else
            out.(name)=override.(name);
        end
    end
end
