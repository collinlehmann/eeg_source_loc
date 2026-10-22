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

tests.all_passed = all(structfun(@(x) logical(x),tests));
if ~tests.all_passed
    error('eegsl:Tests:CoreFailure','One or more core utility tests failed.');
end
end
