addpath(genpath(fullfile(pwd, 'matlab')));
addpath(fullfile(pwd, 'tests'));
addpath(fullfile(pwd, 'tests','helpers'));
cd '/Users/collinlehmann/eeg-source-loc/eeg_source_loc/tests'
files = dir('test*');
testNames = erase({files.name},'.m'); 

for k = 1:numel(testNames)
    result = feval(testNames{k});
    assert(result.all_passed, '%s failed', testNames{k});
    fprintf('%s: passed\n', testNames{k});
end
cd '/Users/collinlehmann/eeg-source-loc/eeg_source_loc'