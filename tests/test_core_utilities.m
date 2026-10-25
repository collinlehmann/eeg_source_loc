function tests = test_core_utilities()
%TEST_CORE_UTILITIES Dependency-free smoke tests for core utilities.
tests = struct();

cfg = eegsl.validate_config(struct('paradigm','task'));
tests.config_default = strcmp(cfg.paradigm,'task');

same1 = eegsl.common.content_hash(struct('a',1,'b',[2 3]));
same2 = eegsl.common.content_hash(struct('a',1,'b',[2 3]));
tests.hash_deterministic = strcmp(same1,same2);

coord = eegsl.common.assert_coordinates(struct('unit','mm'),struct('unit','mm'));
tests.coordinate_check = strcmp(coord.units,'mm');
missing = false;
try
    eegsl.common.assert_coordinates(struct(), 'require_unit',true);
catch err
    missing = strcmp(err.identifier,'eegsl:Coordinates:MissingUnit');
end
tests.missing_unit = missing;
coordsysMismatch = false;
try
    eegsl.common.assert_coordinates(struct('coordsys','ras'), ...
        struct('coordsys','mni'));
catch err
    coordsysMismatch = strcmp(err.identifier,'eegsl:Coordinates:CoordsysMismatch');
end
tests.coordsys_mismatch = coordsysMismatch;
missingCoordsys = false;
try
    eegsl.common.assert_coordinates(struct('unit','mm'), ...
        'require_coordsys',true);
catch err
    missingCoordsys = strcmp(err.identifier,'eegsl:Coordinates:MissingCoordsys');
end
tests.missing_coordsys = missingCoordsys;

assert_test_checks(tests,'test_core_utilities');
tests.all_passed = true;
end
