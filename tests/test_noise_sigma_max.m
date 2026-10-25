function tests = test_noise_sigma_max()
%TEST_NOISE_SIGMA_MAX Relative-scale tests for the uniform-null bound.
rs = RandStream('twister','Seed',3);
m = 32;
H = randn(rs,m,1500);
G = H*H';
B = randn(rs,m);
R = B*B'/m + 0.5*G/trace(G)*m;
[sClosed,info] = eegsl.noise.sigma_max(R,G,zeros(m),struct('method','closed_form'));
sBisect = eegsl.noise.sigma_max(R,G,zeros(m),struct('method','bisection'));
tests.closed_matches_bisection = abs(sClosed-sBisect)/sClosed < 1e-6;
tests.tight = abs(info.min_eig_ratio) < 1e-8;
[sScaled,~] = eegsl.noise.sigma_max(1e-12*R,1e-16*G,zeros(m));
tests.scale_invariant = abs(sScaled/(100*sClosed)-1) < 1e-6;

X = randn(rs,8,1200);
lf = struct('leadfield',{{randn(rs,8,3),randn(rs,8,3),randn(rs,8,3)}});
cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.noise.route = 'uniform_null';
[~,muInfo] = eegsl.noise.estimate_noise_cov(cfg,struct('data',X),lf,[]);
[~,vInfo] = eegsl.noise.estimate_noise_cov(cfg,struct('data',1e-6*X),lf,[]);
tests.units_end_to_end = abs(vInfo.route_details.sigma/muInfo.route_details.sigma/1e-6-1) < 1e-6;

P = eye(8)-ones(8)/8;
cfg.reference.projector = P;
Xref = P*X;
[Navg,~] = eegsl.noise.estimate_noise_cov(cfg,struct('data',Xref),lf,[]);
tests.avg_reference_null = norm(Navg*ones(8,1)) <= 1e-9*norm(Navg);

caught = false;
try
    eegsl.noise.sigma_max(eye(2),zeros(2),zeros(2));
catch err
    caught = strcmp(err.identifier,'eegsl:Noise:ZeroGeometry');
end
tests.zero_geometry = caught;

assert_test_checks(tests,'test_noise_sigma_max');
tests.all_passed = true;
end
