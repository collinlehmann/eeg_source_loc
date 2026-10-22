function quality = quality_monitor(data,cfg)
%QUALITY_MONITOR Produce a runtime quality signal without changing data.
if nargin < 2 || isempty(cfg), cfg = struct(); end
if isfield(cfg,'callback') && isa(cfg.callback,'function_handle')
    quality = cfg.callback(data,cfg);
    if ~isfield(quality,'pass'), quality.pass = false; end
    return;
end
X = numeric_samples(data);
if isempty(X)
    quality = struct('pass',false,'reason','no_numeric_samples');
    return;
end
X = double(X);
quality = struct();
quality.pass = all(isfinite(X(:)));
quality.reason = ternary(quality.pass,'default_finite_check_failed', 'nonfinite_samples');
quality.n_samples = size(X,2);
quality.n_channels = size(X,1);
quality.channel_rms = sqrt(mean(X.^2,2));
quality.global_rms = sqrt(mean(X(:).^2));
quality.artifact_rate = NaN;
quality.impedance = NaN;
end
function X = numeric_samples(data)
if isnumeric(data), X = data; return; end
if isstruct(data) && isfield(data,'data'), X = data.data; return; end
if isstruct(data) && isfield(data,'avg'), X = data.avg; return; end
if isstruct(data) && isfield(data,'trial') && iscell(data.trial)
    X = data.trial{1}; return;
end
X = [];
end
function y = ternary(c,a,b)
if c, y = a; else, y = b; end
end
