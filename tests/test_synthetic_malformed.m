function tests = test_synthetic_malformed()
%TEST_SYNTHETIC_MALFORMED Malformed config/dimensions fail with clear identifiers.
[cfg, root] = synthetic_e2e_cfg(3);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>

tests.bad_orientation_mode = errid(@()set_and_validate(cfg,'orientation_mode','diagonal')) == "eegsl:Config:SyntheticOrientationMode";
tests.bad_noise_model = errid(@()set_and_validate(cfg,'noise_model','pink')) == "eegsl:Config:SyntheticNoiseModel";
tests.bad_sample_rate = errid(@()set_and_validate(cfg,'sample_rate_hz',-1)) == "eegsl:Config:SyntheticSampleRate";
tests.bad_n_samples = errid(@()set_and_validate(cfg,'n_samples',2.5)) == "eegsl:Config:SyntheticInteger";
tests.bad_enabled = errid(@()set_and_validate(cfg,'enabled','yes')) == "eegsl:Config:SyntheticLogical";
tests.bad_snr = errid(@()set_and_validate(cfg,'snr_db',[1 2])) == "eegsl:Config:SyntheticSNR";
tests.bad_include_deep = errid(@()set_and_validate(cfg,'include_deep_source',1)) == "eegsl:Config:SyntheticLogical";
tests.n_time_samples_mismatch = errid(@()set_and_validate(cfg,'n_time',100)) == "eegsl:Config:SyntheticDimension";
tests.e2e_rejects_bad_config = errid(@()run_e2e_with(cfg,'orientation_mode','x')) == "eegsl:Config:SyntheticOrientationMode";

tests.dim_transpose_adapts = isequal(size(eegsl.synthetic.normalize_dimensions(zeros(30,4),4,'samples_by_channels','x')),[4 30]);
tests.dim_mismatch = errid(@()eegsl.synthetic.normalize_dimensions(zeros(5,30),4,'channels_by_samples','x')) == "eegsl:Synthetic:DimensionMismatch";
tests.dim_bad_orientation = errid(@()eegsl.synthetic.normalize_dimensions(zeros(4,30),4,'bogus','x')) == "eegsl:Synthetic:Orientation";
tests.dim_bad_type = errid(@()eegsl.synthetic.normalize_dimensions('abc',3,'channels_by_samples','x')) == "eegsl:Synthetic:DataType";

space = eegsl.synthetic.build_source_space(eegsl.validate_config(cfg));
lf = eegsl.synthetic.build_leadfield(eegsl.validate_config(cfg),space);
src = struct('source',zeros(7,20),'active_sources',1);
vcfg = eegsl.validate_config(cfg);
tests.forward_mismatch = errid(@()eegsl.synthetic.project_and_noise(vcfg,lf,src)) == "eegsl:Synthetic:ForwardDimension";

assert_test_checks(tests,'test_synthetic_malformed');
tests.all_passed = true;
end

function run_e2e_with(cfg,field,value)
cfg.synthetic.(field) = value;
eegsl.validate_synthetic_e2e(cfg);
end

function set_and_validate(cfg,field,value)
cfg.synthetic.(field) = value;
eegsl.validate_config(cfg);
end

function id = errid(fcn)
id = "none";
try
    fcn();
catch err
    id = string(err.identifier);
end
end
