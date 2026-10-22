function out = electrode_density_heuristic(nchan, sourceCfg)
%ELECTRODE_DENSITY_HEURISTIC Derive a conservative source-grid target.
%   The mapping is intentionally exposed and easy to revise after montage
%   validation. It avoids pretending that source resolution exceeds sensor
%   information content.
if nargin < 1 || isempty(nchan), nchan = 0; end
if nargin < 2, sourceCfg = struct(); end
minPoints = get_or(sourceCfg,'min_points',3000);
maxPoints = get_or(sourceCfg,'max_points',6000);
if isfield(sourceCfg,'target_points') && ~isempty(sourceCfg.target_points)
    target = sourceCfg.target_points;
else
    effectiveChannels = max(1,double(nchan));
    target = round(12 * effectiveChannels);
    target = min(max(target,minPoints),maxPoints);
end
out = struct('nchan',nchan,'target_points',target, ...
    'min_points',minPoints,'max_points',maxPoints, ...
    'rule','clamp(round(12*nchan), min_points, max_points)', ...
    'accuracy_note','Point density does not imply equivalent localization resolution.');
end

function value = get_or(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
end
