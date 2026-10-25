function lf = build_leadfield(cfg, space)
%BUILD_LEADFIELD Deterministic dipole-like leadfield (channels x components).
%   Free mode: 3 columns per source (x/y/z dipole axes). Scalar mode: one
%   column per source along the radial direction. Gain falls with distance
%   (1/r^2), so deep sources are weaker. Not a physical head model.
nch = size(space.electrode_pos,1);
ns = size(space.pos,1);
free = strcmp(cfg.synthetic.orientation_mode,'free');
if free, L = zeros(nch,3*ns); else, L = zeros(nch,ns); end
for j = 1:ns
    v = space.electrode_pos - space.pos(j,:);
    r = sqrt(sum(v.^2,2));
    if any(r <= eps)
        error('eegsl:Synthetic:Geometry','Source and electrode positions must not coincide.');
    end
    if free
        axes3 = eye(3);
    else
        axes3 = space.pos(j,:) / max(norm(space.pos(j,:)),eps);
    end
    cols = (v * axes3.') ./ r.^3;
    L(:,(size(cols,2)*(j-1)+1):(size(cols,2)*j)) = cols;
end
L = L ./ max(sqrt(sum(L.^2,1)));
lf = struct('leadfield',L,'orientation',cfg.synthetic.orientation_mode, ...
    'source_space_id',eegsl.common.content_hash(space.pos), ...
    'label',{arrayfun(@(k)sprintf('E%d',k),1:nch,'UniformOutput',false)'});
lf.leadfield_id = eegsl.common.cache_key('synthetic_leadfield',L,lf.source_space_id);
end
