function seed = resolve_seed(cfg)
%RESOLVE_SEED Seed for the synthetic workflow (synthetic.seed, then seed, then 1).
seed = [];
if isfield(cfg,'synthetic') && isfield(cfg.synthetic,'seed'), seed = cfg.synthetic.seed; end
if isempty(seed) && isfield(cfg,'seed'), seed = cfg.seed; end
if isempty(seed), seed = 1; end
end
