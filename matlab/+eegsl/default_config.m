function cfg = default_config()
%DEFAULT_CONFIG Return conservative defaults for the EEG source pipeline.
%   External tools and FieldTrip are never assumed to be installed.

cfg = struct();
cfg.paradigm = '';
cfg.source = struct('mode','wholebrain', 'spacing_mm',[], ...
    'target_points',[], 'min_points',3000, 'max_points',6000, ...
    'symmetry',true, 'neighbor_continuity',false);
cfg.forward = struct('engine','simbio', 'orientation','auto', ...
    'require_fieldtrip',true);
cfg.inverse = struct('method','wmne', 'reduction','norm', ...
    'regularization','fixed', 'lambda',[], 'depth_exponent',0.8);
cfg.noise = struct('route','', 'tol',1e-10, 'max_iterations',60, ...
    'reg',struct('method','none','value',[]));
cfg.normalization = struct('enabled',false, 'subsamples',20, ...
    'subsample_size',[], 'exponent',0.2887, 'shift',3, 'scale',3);
cfg.cache = struct('root','', 'version','v1');
cfg.progress = struct('enabled',true, 'log_file','', 'interval_seconds',1);
cfg.petra = struct('enabled',false, 'allow_fallback',true);
end
