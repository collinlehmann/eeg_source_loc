function src = generate_sources(cfg, space, lf)
%GENERATE_SOURCES Deterministic source time series (components x samples).
%   Active sources (plus the deep source when enabled) carry sinusoids with
%   distinct frequencies; phases and free-orientation directions come from
%   a seed-derived RandStream.
nt = cfg.synthetic.n_samples;
ncomp = size(lf.leadfield,2);
if ncomp ~= eegsl.synthetic.n_components(cfg)
    error('eegsl:Synthetic:LeadfieldComponents','Leadfield has %d components; expected %d.', ...
        ncomp,eegsl.synthetic.n_components(cfg));
end
active = cfg.synthetic.active_sources(:)';
if ~isempty(space.deep_source_index), active = unique([active space.deep_source_index]); end
t = (0:nt-1)/cfg.synthetic.sample_rate_hz;
rs = eegsl.synthetic.stream_for(cfg,1);
X = zeros(ncomp,nt);
free = strcmp(cfg.synthetic.orientation_mode,'free');
for k = 1:numel(active)
    idx = active(k);
    wave = sin(2*pi*(6+3*k)*t + 2*pi*rand(rs));
    if free
        d = randn(rs,3,1); d = d/norm(d);
        X((3*idx-2):(3*idx),:) = d*wave;
    else
        X(idx,:) = wave;
    end
end
src = struct('source',X,'active_sources',active,'time',t,'orientation_mode',cfg.synthetic.orientation_mode);
end
