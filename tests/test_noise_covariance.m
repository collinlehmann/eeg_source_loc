function tests = test_noise_covariance()
%TEST_NOISE_COVARIANCE Synthetic tests for covariance routes and PSD behavior.
rng(7);
X = randn(8,1500);
data = struct('data',X,'label',arrayfun(@(k)sprintf('E%d',k),1:8,'UniformOutput',false));
lf = struct('leadfield',{{randn(8,3),randn(8,3),randn(8,3)}});

cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.noise.route = 'uniform_null';
cfg.noise.max_iterations = 30;
[N,info] = eegsl.noise.estimate_noise_cov(cfg,data,lf,struct());
tests.uniform_shape = isequal(size(N),[8 8]);
tests.uniform_psd = min(eig((N+N')/2)) >= -1e-8;
tests.uniform_metadata = strcmp(info.route,'uniform_null') && isfield(info.route_details,'sigma_max');

cfg.noise.route = 'diagonal';
[Nd,~] = eegsl.noise.estimate_noise_cov(cfg,data,[],struct());
tests.diagonal = norm(Nd-diag(diag(Nd)),'fro') < 1e-12;

cfg.paradigm = 'task';
cfg.noise.route = 'baseline';
cfg.baseline = [-0.2 0.2];
data.trial = {X}; data.time = {linspace(-1,1,size(X,2))};
[Nb,~] = eegsl.noise.estimate_noise_cov(cfg,data,[],struct());
tests.baseline_shape = isequal(size(Nb),[8 8]);

tests.all_passed = all(structfun(@(x)logical(x),tests));
if ~tests.all_passed, error('eegsl:Tests:NoiseFailure','Noise covariance test failed.'); end
end
