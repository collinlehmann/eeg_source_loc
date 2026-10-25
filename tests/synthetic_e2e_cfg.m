function [cfg, root] = synthetic_e2e_cfg(seed)
%SYNTHETIC_E2E_CFG Small deterministic config with a fresh temporary cache root.
if nargin < 1, seed = 7; end
root = tempname; mkdir(root);
cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.cache.root = root;
cfg.noise.route = 'diagonal';
cfg.inverse.lambda = 0.05;
cfg.synthetic.enabled = true;
cfg.synthetic.seed = seed;
cfg.synthetic.n_channels = 16;
cfg.synthetic.n_sources = 10;
cfg.synthetic.n_samples = 300;
cfg.synthetic.active_sources = [1 4];
cfg.synthetic.deep_source_index = 6;
end
