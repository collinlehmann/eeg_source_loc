function cfg = validate_config(cfg)
%VALIDATE_CONFIG Validate and normalize the canonical root configuration.
%   This function intentionally validates contracts, not scientific choices.
%   Unresolved scientific defaults remain explicit configuration fields.
if nargin == 0 || isempty(cfg), cfg = struct(); end
if ~isstruct(cfg), error('eegsl:Config:Type','cfg must be a struct.'); end
cfg = merge_struct(eegsl.default_config(),cfg);

cfg.schema_version = require_text(cfg.schema_version,'schema_version');
cfg.paradigm = normalize_enum(cfg.paradigm,'paradigm',{'task','resting'},true);
cfg.subject_id = optional_text(cfg.subject_id,'subject_id');
cfg.session_id = optional_text(cfg.session_id,'session_id');

cfg.execution.mode = normalize_enum(cfg.execution.mode,'execution.mode', ...
    {'interactive-offline','automated-offline','realtime'},false);
cfg.execution.headless = require_logical(cfg.execution.headless,'execution.headless');
cfg.execution.realtime = require_logical(cfg.execution.realtime,'execution.realtime');
if strcmp(cfg.execution.mode,'realtime') ~= cfg.execution.realtime
    error('eegsl:Config:ExecutionMismatch', ...
        'execution.realtime must agree with execution.mode.');
end
if strcmp(cfg.execution.mode,'interactive-offline') && cfg.execution.headless
    error('eegsl:Config:InteractiveHeadless', ...
        'interactive-offline cannot be configured as headless.');
end

cfg.source.mode = normalize_enum(cfg.source.mode,'source.mode', ...
    {'wholebrain','cortical'},false);
cfg.source.min_points = positive_integer(cfg.source.min_points,'source.min_points');
cfg.source.max_points = positive_integer(cfg.source.max_points,'source.max_points');
if cfg.source.max_points < cfg.source.min_points
    error('eegsl:Config:SourcePointRange','source.max_points must be >= min_points.');
end
if ~isempty(cfg.source.target_points)
    cfg.source.target_points = positive_integer(cfg.source.target_points,'source.target_points');
end
cfg.source.symmetry = require_logical(cfg.source.symmetry,'source.symmetry');
cfg.source.neighbor_continuity = require_logical(cfg.source.neighbor_continuity,'source.neighbor_continuity');

cfg.forward.engine = normalize_enum(cfg.forward.engine,'forward.engine', ...
    {'simbio','duneuro','analytic'},false);
cfg.forward.orientation = normalize_enum(cfg.forward.orientation,'forward.orientation', ...
    {'auto','free','fixed','surface-normal'},false);
cfg.forward.require_fieldtrip = require_logical(cfg.forward.require_fieldtrip,'forward.require_fieldtrip');
cfg.forward.parallel.enabled = require_logical(cfg.forward.parallel.enabled,'forward.parallel.enabled');
if ~isempty(cfg.forward.parallel.workers)
    cfg.forward.parallel.workers = positive_integer(cfg.forward.parallel.workers,'forward.parallel.workers');
end

cfg.reference.rank_tolerance = positive_scalar(cfg.reference.rank_tolerance,'reference.rank_tolerance');
cfg.reference.apply_to_leadfield = require_logical(cfg.reference.apply_to_leadfield,'reference.apply_to_leadfield');
if ~isempty(cfg.reference.projector)
    validate_square_matrix(cfg.reference.projector,'reference.projector');
end

cfg.noise.route = normalize_enum(cfg.noise.route,'noise.route', ...
    {'','baseline','emptyroom','diagonal','uniform_null'},false);
cfg.noise.tol = positive_scalar(cfg.noise.tol,'noise.tol');
cfg.noise.max_iterations = positive_integer(cfg.noise.max_iterations,'noise.max_iterations');
cfg.noise.reg.method = normalize_enum(cfg.noise.reg.method,'noise.reg.method', ...
    {'none','shrinkage','loading'},false);
if ~isempty(cfg.noise.reg.value), cfg.noise.reg.value = nonnegative_scalar(cfg.noise.reg.value,'noise.reg.value'); end
if strcmp(cfg.paradigm,'task') && strcmp(cfg.noise.route,'uniform_null')
    warning('eegsl:Config:TaskUniformNull','uniform_null is permitted for task data but is not the task default.');
end
if strcmp(cfg.paradigm,'resting') && strcmp(cfg.noise.route,'baseline')
    error('eegsl:Config:RestingBaseline','A baseline noise route is invalid for resting data.');
end
if strcmp(cfg.noise.route,'baseline') && isempty(cfg.noise.baseline)
    error('eegsl:Config:MissingBaseline','noise.baseline is required for the baseline route.');
end
if ~isempty(cfg.noise.baseline)
    validate_window(cfg.noise.baseline,'noise.baseline');
end

cfg.inverse.method = normalize_enum(cfg.inverse.method,'inverse.method', ...
    {'wmne','eloreta','sloreta','lcmv'},false);
cfg.inverse.reduction = normalize_enum(cfg.inverse.reduction,'inverse.reduction', ...
    {'norm','dominant','vector'},false);
if ~isempty(cfg.inverse.lambda), cfg.inverse.lambda = positive_scalar(cfg.inverse.lambda,'inverse.lambda'); end
if ~isempty(cfg.inverse.lambda_default), cfg.inverse.lambda_default = positive_scalar(cfg.inverse.lambda_default,'inverse.lambda_default'); end
if isempty(cfg.inverse.lambda) && strcmp(cfg.inverse.regularization,'fixed') && strcmp(cfg.inverse.method,'wmne')
    % The implementation can derive a scale-based value; record that choice.
    cfg.inverse.regularization = 'fixed-derived';
end
cfg.inverse.depth_exponent = nonnegative_scalar(cfg.inverse.depth_exponent,'inverse.depth_exponent');
if ~isempty(cfg.inverse.representative_window), validate_window(cfg.inverse.representative_window,'inverse.representative_window'); end

cfg.normalization.enabled = require_logical(cfg.normalization.enabled,'normalization.enabled');
cfg.normalization.orientation = normalize_enum(cfg.normalization.orientation,'normalization.orientation',{'free','scalar'},false);
cfg.normalization.subsamples = positive_integer(cfg.normalization.subsamples,'normalization.subsamples');
cfg.normalization.minimum_samples = positive_integer(cfg.normalization.minimum_samples,'normalization.minimum_samples');
cfg.normalization.stable_state_fraction_warning = bounded_scalar(cfg.normalization.stable_state_fraction_warning,'normalization.stable_state_fraction_warning',0,1);
cfg.normalization.scale_floor = positive_scalar(cfg.normalization.scale_floor,'normalization.scale_floor');
cfg.normalization.exponent = positive_scalar(cfg.normalization.exponent,'normalization.exponent');
cfg.normalization.shift = nonnegative_scalar(cfg.normalization.shift,'normalization.shift');
cfg.normalization.scale = positive_scalar(cfg.normalization.scale,'normalization.scale');
if ~isempty(cfg.normalization.window), validate_window(cfg.normalization.window,'normalization.window'); end

cfg.cache.root = optional_text(cfg.cache.root,'cache.root');
cfg.cache.version = require_text(cfg.cache.version,'cache.version');
cfg.cache.enabled = require_logical(cfg.cache.enabled,'cache.enabled');
cfg.cache.read_only = require_logical(cfg.cache.read_only,'cache.read_only');
cfg.cache.overwrite = require_logical(cfg.cache.overwrite,'cache.overwrite');
if cfg.cache.read_only && cfg.cache.overwrite
    error('eegsl:Config:CacheMode','cache.read_only and cache.overwrite cannot both be true.');
end
cfg.progress.enabled = require_logical(cfg.progress.enabled,'progress.enabled');
cfg.progress.log_file = optional_text(cfg.progress.log_file,'progress.log_file');
cfg.progress.interval_seconds = nonnegative_scalar(cfg.progress.interval_seconds,'progress.interval_seconds');
end

function out = merge_struct(base,override)
out = base;
for f = fieldnames(override)'
    n = f{1};
    if isstruct(override.(n)) && isfield(out,n) && isstruct(out.(n))
        out.(n) = merge_struct(out.(n),override.(n));
    else, out.(n) = override.(n); end
end
end
function x = require_text(x,name)
if isstring(x), x = char(x); end
if ~ischar(x) || size(x,1) ~= 1, error('eegsl:Config:Text','%s must be text.',name); end
end
function x = optional_text(x,name)
if isempty(x), x = ''; else, x = require_text(x,name); end
end
function x = normalize_enum(x,name,allowed,required)
if isempty(x) && ~required, x = ''; return; end
x = lower(require_text(x,name));
if ~ismember(x,allowed), error('eegsl:Config:Enum','Invalid %s: %s.',name,x); end
end
function x = require_logical(x,name)
if ~(islogical(x) && isscalar(x)), error('eegsl:Config:Logical','%s must be scalar logical.',name); end
end
function x = positive_scalar(x,name)
if ~(isnumeric(x) && isscalar(x) && isfinite(x) && x > 0), error('eegsl:Config:Positive','%s must be positive.',name); end
x = double(x);
end
function x = nonnegative_scalar(x,name)
if ~(isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0), error('eegsl:Config:Nonnegative','%s must be nonnegative.',name); end
x = double(x);
end
function x = positive_integer(x,name)
x = positive_scalar(x,name);
if x ~= round(x), error('eegsl:Config:Integer','%s must be an integer.',name); end
x = round(x);
end
function x = bounded_scalar(x,name,lo,hi)
x = positive_or_zero(x,name);
if x < lo || x > hi, error('eegsl:Config:Bounds','%s must be between %g and %g.',name,lo,hi); end
end
function x = positive_or_zero(x,name)
if ~(isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0), error('eegsl:Config:Nonnegative','%s must be nonnegative.',name); end
x = double(x);
end
function validate_square_matrix(x,name)
if ~(isnumeric(x) && ismatrix(x) && size(x,1) == size(x,2) && all(isfinite(x(:))))
    error('eegsl:Config:Matrix','%s must be a finite square numeric matrix.',name);
end
end
function validate_window(x,name)
if ~(isnumeric(x) && numel(x) == 2 && all(isfinite(x)) && x(1) < x(2))
    error('eegsl:Config:Window','%s must be [start end] with start < end.',name);
end
end
