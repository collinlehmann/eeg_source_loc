function n = n_components(cfg)
%N_COMPONENTS Source components per cfg: 3 per source (free) or 1 (scalar).
if strcmp(cfg.synthetic.orientation_mode,'free'), n = 3*cfg.synthetic.n_sources; else, n = cfg.synthetic.n_sources; end
end
