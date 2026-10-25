function tests = test_source_space()
%TEST_SOURCE_SPACE Dependency-free source-space tests.
mask = true(12,12,12);
anatomy = struct('mask',mask,'unit','mm','transform',eye(4));
elec = struct('chanpos',zeros(64,3));
cfg = struct('source',struct('target_points',[], 'min_points',20, ...
    'max_points',100, 'symmetry',true, 'neighbor_continuity',false));
[s,info] = eegsl.source.build_source_space(anatomy,elec,cfg);
tests.nonempty = ~isempty(s.pos);
tests.fieldtrip_shape = isfield(s,'pos') && isfield(s,'inside') && isfield(s,'label');
tests.free_orientation = strcmp(s.orientation,'free');
tests.metadata = isfield(info,'source_space_id') && ~isempty(info.source_space_id);

h = eegsl.source.electrode_density_heuristic(256,struct('min_points',3000,'max_points',6000));
tests.density_clamped = h.target_points == 3072;
assert_test_checks(tests,'test_source_space');
tests.all_passed = true;
end