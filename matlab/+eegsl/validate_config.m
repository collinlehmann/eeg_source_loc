function cfg = validate_config(cfg)
%VALIDATE_CONFIG Validate and normalize the canonical root configuration.
if nargin == 0 || isempty(cfg), cfg = struct(); end
if ~isstruct(cfg), error('eegsl:Config:Type','cfg must be a struct.'); end
cfg = merge_struct(eegsl.default_config(),cfg);

cfg.schema_version = require_text(cfg.schema_version,'schema_version');
if ~isempty(cfg.seed), cfg.seed = nonnegative_integer(cfg.seed,'seed'); end
cfg.paradigm = normalize_enum(cfg.paradigm,'paradigm',{'task','resting'},true);
cfg.subject_id = optional_text(cfg.subject_id,'subject_id');
cfg.session_id = optional_text(cfg.session_id,'session_id');
cfg.execution.mode = normalize_enum(cfg.execution.mode,'execution.mode', ...
    {'interactive-offline','automated-offline','realtime'},false);
cfg.execution.headless = require_logical(cfg.execution.headless,'execution.headless');
cfg.execution.realtime = require_logical(cfg.execution.realtime,'execution.realtime');
if strcmp(cfg.execution.mode,'realtime') ~= cfg.execution.realtime
    error('eegsl:Config:ExecutionMismatch','execution.realtime must agree with execution.mode.');
end
if strcmp(cfg.execution.mode,'interactive-offline') && cfg.execution.headless
    error('eegsl:Config:InteractiveHeadless','interactive-offline cannot be configured as headless.');
end

cfg.source.mode = normalize_enum(cfg.source.mode,'source.mode',{'wholebrain','cortical'},false);
cfg.source.min_points = positive_integer(cfg.source.min_points,'source.min_points');
cfg.source.max_points = positive_integer(cfg.source.max_points,'source.max_points');
if cfg.source.max_points < cfg.source.min_points
    error('eegsl:Config:SourcePointRange','source.max_points must be >= min_points.');
end
if ~isempty(cfg.source.target_points), cfg.source.target_points = positive_integer(cfg.source.target_points,'source.target_points'); end
cfg.source.symmetry = require_logical(cfg.source.symmetry,'source.symmetry');
cfg.source.symmetry_mode = normalize_enum(cfg.source.symmetry_mode, ...
    'source.symmetry_mode',{'lattice','enforce'},false);
if ~isempty(cfg.source.spacing_mm)
    if ~isscalar(cfg.source.spacing_mm)
        error('eegsl:Source:AnisotropicSpacing','source.spacing_mm must be scalar.');
    end
    cfg.source.spacing_mm = positive_scalar(cfg.source.spacing_mm,'source.spacing_mm');
end
if ischar(cfg.source.midsagittal_x) || (isstring(cfg.source.midsagittal_x) && isscalar(cfg.source.midsagittal_x))
    cfg.source.midsagittal_x = lower(char(cfg.source.midsagittal_x));
    if ~strcmp(cfg.source.midsagittal_x,'mask_centroid')
        error('eegsl:Config:SourceMidline','source.midsagittal_x must be numeric or mask_centroid.');
    end
elseif isnumeric(cfg.source.midsagittal_x) && isscalar(cfg.source.midsagittal_x) && isfinite(cfg.source.midsagittal_x)
    cfg.source.midsagittal_x = double(cfg.source.midsagittal_x);
else
    error('eegsl:Config:SourceMidline','source.midsagittal_x must be numeric or mask_centroid.');
end
cfg.source.neighbor_continuity = require_logical(cfg.source.neighbor_continuity,'source.neighbor_continuity');
cfg.source.neighbor_min = positive_integer(cfg.source.neighbor_min,'source.neighbor_min');
cfg.source.neighbor_passes = positive_integer(cfg.source.neighbor_passes,'source.neighbor_passes');
cfg.source.cortical_representation = normalize_enum(cfg.source.cortical_representation, ...
    'source.cortical_representation',{'volume','surface'},false);

cfg.forward.engine = normalize_enum(cfg.forward.engine,'forward.engine',{'simbio','duneuro','analytic'},false);
cfg.forward.orientation = normalize_enum(cfg.forward.orientation,'forward.orientation',{'auto','free','fixed','surface-normal'},false);
cfg.forward.require_fieldtrip = require_logical(cfg.forward.require_fieldtrip,'forward.require_fieldtrip');
cfg.forward.parallel.enabled = require_logical(cfg.forward.parallel.enabled,'forward.parallel.enabled');
if ~isempty(cfg.forward.parallel.workers), cfg.forward.parallel.workers = positive_integer(cfg.forward.parallel.workers,'forward.parallel.workers'); end

cfg.reference.rank_tolerance = positive_scalar(cfg.reference.rank_tolerance,'reference.rank_tolerance');
cfg.reference.apply_to_leadfield = require_logical(cfg.reference.apply_to_leadfield,'reference.apply_to_leadfield');
if ~isempty(cfg.reference.projector), validate_square_matrix(cfg.reference.projector,'reference.projector'); end

cfg.noise.route = normalize_enum(cfg.noise.route,'noise.route',{'','baseline','emptyroom','diagonal','uniform_null'},false);
cfg.noise.tol = positive_scalar(cfg.noise.tol,'noise.tol');
cfg.noise.sigma_method = normalize_enum(cfg.noise.sigma_method, ...
    'noise.sigma_method',{'closed_form','bisection'},false);
cfg.noise.max_iterations = positive_integer(cfg.noise.max_iterations,'noise.max_iterations');
cfg.noise.reg.method = normalize_enum(cfg.noise.reg.method,'noise.reg.method',{'none','shrinkage','loading'},false);
if ~isempty(cfg.noise.reg.value), cfg.noise.reg.value = nonnegative_scalar(cfg.noise.reg.value,'noise.reg.value'); end
if strcmp(cfg.paradigm,'resting') && strcmp(cfg.noise.route,'baseline'), error('eegsl:Config:RestingBaseline','A baseline noise route is invalid for resting data.'); end
if strcmp(cfg.noise.route,'baseline') && isempty(cfg.noise.baseline), error('eegsl:Config:MissingBaseline','noise.baseline is required for the baseline route.'); end
if ~isempty(cfg.noise.baseline), validate_window(cfg.noise.baseline,'noise.baseline'); end

cfg.inverse.method = normalize_enum(cfg.inverse.method,'inverse.method',{'wmne','eloreta','sloreta','lcmv'},false);
cfg.inverse.reduction = normalize_enum(cfg.inverse.reduction,'inverse.reduction',{'','norm','dominant','vector'},false);
if ~isempty(cfg.inverse.lambda), cfg.inverse.lambda = positive_scalar(cfg.inverse.lambda,'inverse.lambda'); end
if ~isempty(cfg.inverse.lambda_default), cfg.inverse.lambda_default = positive_scalar(cfg.inverse.lambda_default,'inverse.lambda_default'); end
cfg.inverse.depth_exponent = nonnegative_scalar(cfg.inverse.depth_exponent,'inverse.depth_exponent');
if ~isempty(cfg.inverse.representative_window), validate_window(cfg.inverse.representative_window,'inverse.representative_window'); end

cfg.normalization.enabled = require_logical(cfg.normalization.enabled,'normalization.enabled');
cfg.normalization.subsamples = positive_integer(cfg.normalization.subsamples,'normalization.subsamples');
cfg.normalization.minimum_samples = positive_integer(cfg.normalization.minimum_samples,'normalization.minimum_samples');
cfg.normalization.stable_state_fraction_warning = bounded_scalar(cfg.normalization.stable_state_fraction_warning,'normalization.stable_state_fraction_warning',0,1);
cfg.normalization.scale_floor = positive_scalar(cfg.normalization.scale_floor,'normalization.scale_floor');
if ~isempty(cfg.normalization.window), validate_window(cfg.normalization.window,'normalization.window'); end

cfg.cache.root = optional_text(cfg.cache.root,'cache.root');
cfg.cache.version = require_text(cfg.cache.version,'cache.version');
cfg.cache.enabled = require_logical(cfg.cache.enabled,'cache.enabled');
cfg.cache.read_only = require_logical(cfg.cache.read_only,'cache.read_only');
cfg.cache.overwrite = require_logical(cfg.cache.overwrite,'cache.overwrite');
cfg.cache.cleanup_temp_files = require_logical(cfg.cache.cleanup_temp_files,'cache.cleanup_temp_files');
cfg.cache.lock_timeout_seconds = positive_scalar(cfg.cache.lock_timeout_seconds,'cache.lock_timeout_seconds');
cfg.cache.stale_lock_seconds = positive_scalar(cfg.cache.stale_lock_seconds,'cache.stale_lock_seconds');
if cfg.cache.read_only && cfg.cache.overwrite, error('eegsl:Config:CacheMode','cache.read_only and cache.overwrite cannot both be true.'); end
if cfg.cache.enabled && isempty(cfg.cache.root)
    warning('eegsl:Config:CacheRoot','Caching is enabled but cache.root is empty; cache operations will fail until configured.');
end
cfg.progress.enabled = require_logical(cfg.progress.enabled,'progress.enabled');
cfg.progress.interval_seconds = nonnegative_scalar(cfg.progress.interval_seconds,'progress.interval_seconds');

cfg.synthetic.n_channels = positive_integer(cfg.synthetic.n_channels,'synthetic.n_channels');
cfg.synthetic.n_sources = positive_integer(cfg.synthetic.n_sources,'synthetic.n_sources');
cfg.synthetic = validate_synthetic_extension(cfg.synthetic);
cfg.synthetic.sensor_orientation = normalize_enum(cfg.synthetic.sensor_orientation, ...
    'synthetic.sensor_orientation',{'channels_by_samples','samples_by_channels'},false);
cfg.synthetic.source_orientation = normalize_enum(cfg.synthetic.source_orientation, ...
    'synthetic.source_orientation',{'components_by_samples','samples_by_components'},false);
cfg.synthetic.noise_std = nonnegative_scalar(cfg.synthetic.noise_std,'synthetic.noise_std');
if ~isempty(cfg.synthetic.seed), cfg.synthetic.seed = nonnegative_integer(cfg.synthetic.seed,'synthetic.seed'); end
if ~isfield(cfg.synthetic,'normalization') || ~isstruct(cfg.synthetic.normalization)
    cfg.synthetic.normalization = struct('enabled',false);
end
cfg.synthetic.normalization.enabled = require_logical(cfg.synthetic.normalization.enabled,'synthetic.normalization.enabled');
if ~isfield(cfg.synthetic,'active_sources') || isempty(cfg.synthetic.active_sources)
    error('eegsl:Config:SyntheticActiveSources','synthetic.active_sources must contain at least one source index.');
end
if ~(isnumeric(cfg.synthetic.active_sources) && isvector(cfg.synthetic.active_sources))
    error('eegsl:Config:SyntheticActiveSources','synthetic.active_sources must be a numeric vector.');
end
cfg.synthetic.active_sources = unique(round(double(cfg.synthetic.active_sources(:)')));
if any(cfg.synthetic.active_sources < 1) || any(cfg.synthetic.active_sources > cfg.synthetic.n_sources)
    error('eegsl:Config:SyntheticActiveSourceRange','synthetic.active_sources must be within [1, synthetic.n_sources].');
end
cfg.synthetic.deep_source_index = positive_integer(cfg.synthetic.deep_source_index,'synthetic.deep_source_index');
if cfg.synthetic.deep_source_index > cfg.synthetic.n_sources
    error('eegsl:Config:SyntheticDeepSourceRange','synthetic.deep_source_index must be within [1, synthetic.n_sources].');
end
cfg.synthetic.cache_prefix = require_text(cfg.synthetic.cache_prefix,'synthetic.cache_prefix');
end

function s = validate_synthetic_extension(s)
% n_time and n_samples are aliases; whichever is empty follows the other (default 600).
s.enabled = synth_logical(s.enabled,'enabled');
if isempty(s.n_time) && isempty(s.n_samples), s.n_time = 600; end
if isempty(s.n_time), s.n_time = s.n_samples; end
if isempty(s.n_samples), s.n_samples = s.n_time; end
s.n_time = synth_integer(s.n_time,'n_time');
s.n_samples = synth_integer(s.n_samples,'n_samples');
if s.n_time ~= s.n_samples
    error('eegsl:Config:SyntheticDimension','synthetic.n_time (%d) and synthetic.n_samples (%d) must agree.',s.n_time,s.n_samples);
end
if ~(isnumeric(s.sample_rate_hz)&&isscalar(s.sample_rate_hz)&&isfinite(s.sample_rate_hz)&&s.sample_rate_hz>0)
    error('eegsl:Config:SyntheticSampleRate','synthetic.sample_rate_hz must be a positive scalar.');
end
s.sample_rate_hz = double(s.sample_rate_hz);
if ~isempty(s.snr_db)
    if ~(isnumeric(s.snr_db)&&isscalar(s.snr_db)&&isfinite(s.snr_db))
        error('eegsl:Config:SyntheticSNR','synthetic.snr_db must be a finite scalar (dB) or empty.');
    end
    s.snr_db = double(s.snr_db);
end
s.orientation_mode = synth_enum(s.orientation_mode,'orientation_mode',{'free','scalar'},'eegsl:Config:SyntheticOrientationMode');
s.noise_model = synth_enum(s.noise_model,'noise_model',{'white'},'eegsl:Config:SyntheticNoiseModel');
s.include_deep_source = synth_logical(s.include_deep_source,'include_deep_source');
end
function x = synth_logical(x,name)
if ~(islogical(x)&&isscalar(x)), error('eegsl:Config:SyntheticLogical','synthetic.%s must be scalar logical.',name); end
end
function x = synth_integer(x,name)
if ~(isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0&&x==round(x))
    error('eegsl:Config:SyntheticInteger','synthetic.%s must be a positive integer.',name);
end
x = double(x);
end
function x = synth_enum(x,name,allowed,id)
if isstring(x), x = char(x); end
if ~(ischar(x)&&isrow(x)&&ismember(lower(x),allowed))
    error(id,'synthetic.%s must be one of: %s.',name,strjoin(allowed,', '));
end
x = lower(x);
end

function out = merge_struct(base,override)
out = base;
for f = fieldnames(override)'
    n=f{1}; if isstruct(override.(n)) && isfield(out,n) && isstruct(out.(n)), out.(n)=merge_struct(out.(n),override.(n)); else, out.(n)=override.(n); end
end
end
function x=require_text(x,name), if isstring(x), x=char(x); end; if ~ischar(x)||size(x,1)~=1, error('eegsl:Config:Text','%s must be text.',name); end; end
function x=optional_text(x,name), if isempty(x), x=''; else, x=require_text(x,name); end; end
function x=normalize_enum(x,name,allowed,required), if isempty(x)&&~required, x=''; return; end; x=lower(require_text(x,name)); if ~ismember(x,allowed), error('eegsl:Config:Enum','Invalid %s: %s.',name,x); end; end
function x=require_logical(x,name), if ~(islogical(x)&&isscalar(x)), error('eegsl:Config:Logical','%s must be scalar logical.',name); end; end
function x=positive_scalar(x,name), if ~(isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0), error('eegsl:Config:Positive','%s must be positive.',name); end; x=double(x); end
function x=nonnegative_scalar(x,name), if ~(isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=0), error('eegsl:Config:Nonnegative','%s must be nonnegative.',name); end; x=double(x); end
function x=positive_integer(x,name), x=positive_scalar(x,name); if x~=round(x), error('eegsl:Config:Integer','%s must be an integer.',name); end; x=round(x); end
function x=nonnegative_integer(x,name), x=nonnegative_scalar(x,name); if x~=round(x), error('eegsl:Config:Integer','%s must be an integer.',name); end; x=round(x); end
function x=bounded_scalar(x,name,lo,hi), x=nonnegative_scalar(x,name); if x<lo||x>hi, error('eegsl:Config:Bounds','%s must be between %g and %g.',name,lo,hi); end; end
function validate_square_matrix(x,name), if ~(isnumeric(x)&&ismatrix(x)&&size(x,1)==size(x,2)&&all(isfinite(x(:)))), error('eegsl:Config:Matrix','%s must be a finite square numeric matrix.',name); end; end
function validate_window(x,name), if ~(isnumeric(x)&&numel(x)==2&&all(isfinite(x))&&x(1)<x(2)), error('eegsl:Config:Window','%s must be [start end] with start < end.',name); end; end
