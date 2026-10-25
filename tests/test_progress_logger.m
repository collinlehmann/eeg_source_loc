function tests = test_progress_logger()
%TEST_PROGRESS_LOGGER Formatted progress is throttled; events bypass it.
path = tempname;
cleanup = onCleanup(@()delete_if_exists(path)); %#ok<NASGU>
logger = eegsl.common.ProgressLogger(struct('enabled',true, ...
    'log_file',path,'interval_seconds',60));
logger.log('progress %d',1);
logger.log('progress %d',2);
logger.event('event %d',1);
logger.event('event %d',2);
delete(logger);
lines = regexp(strtrim(fileread(path)),'\r\n|\n|\r','split');
tests.throttle_formatted = numel(lines)==3;
tests.events_unthrottled = contains(lines{2},'event 1')&&contains(lines{3},'event 2');
delete_if_exists(path);
assert_test_checks(tests,'test_progress_logger');
tests.all_passed = true;
end
function delete_if_exists(path)
if isfile(path), delete(path); end
end
