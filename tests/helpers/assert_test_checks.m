function assert_test_checks(tests, suiteName)
%ASSERT_TEST_CHECKS Fail with explicit failed-check names.
%   tests: struct of logical/scalar-pass checks (excluding aggregate fields)
%   suiteName: short suite label for error messages

if nargin < 2 || isempty(suiteName)
    suiteName = 'TestSuite';
end
if ~isstruct(tests)
    error('eegsl:Tests:InvalidChecks','assert_test_checks expects a struct.');
end

names = fieldnames(tests);
ok = false(size(names));

for k = 1:numel(names)
    v = tests.(names{k});
    ok(k) = islogical(v) && isscalar(v) && v;
end

if ~all(ok)
    failed = names(~ok);
    error('eegsl:Tests:CheckFailed', '[%s] Failed checks: %s', ...
        suiteName, strjoin(failed, ', '));
end
end