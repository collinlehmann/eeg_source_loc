function results = run_tests()
%RUN_TESTS Run every tests/test*.m suite; error at the end if any failed.
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(genpath(fullfile(root,'matlab')));
addpath(here);
addpath(fullfile(here,'helpers'));
files = dir(fullfile(here,'test*.m'));
names = erase({files.name},'.m');
results = struct('name',names,'passed',false,'message','');
for k = 1:numel(names)
    try
        r = feval(names{k});
        results(k).passed = isstruct(r) && isfield(r,'all_passed') && r.all_passed;
        if ~results(k).passed
            results(k).message = 'Suite returned all_passed=false or no all_passed field.';
        end
    catch err
        results(k).message = sprintf('%s: %s',err.identifier,err.message);
    end
    if results(k).passed
        fprintf('PASS %s\n',names{k});
    else
        fprintf(2,'FAIL %s  %s\n',names{k},results(k).message);
    end
end
failed = names(~[results.passed]);
if ~isempty(failed)
    error('eegsl:Tests:Failed','Failed suites: %s',strjoin(failed,', '));
end
end
