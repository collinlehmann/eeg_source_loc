function tests = test_synthetic_no_fieldtrip()
%TEST_SYNTHETIC_NO_FIELDTRIP Synthetic path must succeed with FieldTrip off the path.
removed = {};
for name = {'ft_datatype_raw','ft_prepare_leadfield'}
    loc = which(name{1});
    if ~isempty(loc)
        folder = fileparts(loc);
        rmpath(folder);
        removed{end+1} = folder; %#ok<AGROW>
    end
end
restore = onCleanup(@()cellfun(@addpath,removed)); %#ok<NASGU>
tests.fieldtrip_absent = ~eegsl.common.has_fieldtrip();

[cfg, root] = synthetic_e2e_cfg(5);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
cfg.forward.require_fieldtrip = false;
r = eegsl.validate_synthetic_e2e(cfg);
tests.runs = isfield(r,'metrics') && isfinite(r.metrics.sensor_rmse);
tests.provenance_flag = ~r.provenance.fieldtrip_required;

assert_test_checks(tests,'test_synthetic_no_fieldtrip');
tests.all_passed = true;
end
