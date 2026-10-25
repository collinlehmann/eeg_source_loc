function space = build_source_space(cfg)
%BUILD_SOURCE_SPACE Deterministic synthetic source space (arbitrary units).
%   Sources lie on a fibonacci sphere with graded depth. When
%   cfg.synthetic.include_deep_source is true, source deep_source_index is
%   moved close to the origin. Geometry is purely illustrative.
n = cfg.synthetic.n_sources;
pos = fib_sphere(n) .* linspace(0.9,0.55,n)';
deepIdx = [];
if cfg.synthetic.include_deep_source
    deepIdx = cfg.synthetic.deep_source_index;
    if deepIdx > n
        error('eegsl:Synthetic:DeepSourceRange','deep_source_index %d exceeds n_sources %d.',deepIdx,n);
    end
    pos(deepIdx,:) = pos(deepIdx,:) .* 0.3;
end
space = struct('pos',pos,'deep_source_index',deepIdx,'unit','au', ...
    'orientation_mode',cfg.synthetic.orientation_mode, ...
    'electrode_pos',1.1*fib_sphere(cfg.synthetic.n_channels));
end

function p = fib_sphere(n)
k = (0:n-1)';
theta = 2*pi*k/((1+sqrt(5))/2);
z = 1 - 2*(k+0.5)/n;
r = sqrt(max(0,1-z.^2));
p = [r.*cos(theta), r.*sin(theta), z];
end
