function tests = test_inverse()
%TEST_INVERSE Dependency-free build/apply tests for the wMNE baseline.
rng(11);
L = randn(6,12);
leadfield = struct('leadfield',L,'orientation','free', ...
    'leadfield_id','synthetic-lf','source_space_id','synthetic-source');
N = eye(6);
cfg = struct('inverse',struct('method','wmne','lambda',0.1, ...
    'depth_exponent',0.5,'reduction','norm'));
[op,info] = eegsl.inverse.build_inverse(leadfield,N,cfg);
X = randn(6,50);
Y = eegsl.inverse.apply_inverse(op,X);
tests.operator_shape = isequal(size(op.matrix),[12 6]);
tests.apply_shape = isequal(size(Y),[12 50]);
tests.metadata = strcmp(info.method,'wmne') && op.apply_is_silent;
tests.registry = strcmp(eegsl.inverse.method_registry('LCMV'),'lcmv');
tests.reduction = isequal(size(eegsl.inverse.reduce_source(Y,'norm')),[4 50]);

caught = false;
try
    eegsl.inverse.build_inverse(leadfield,N,struct('inverse',struct('method','eloreta')));
catch err
    caught = strcmp(err.identifier,'eegsl:Inverse:NotImplemented');
end
tests.explicit_unvalidated = caught;

rs = RandStream('twister','Seed',11);
L2 = randn(rs,6,12);
N2 = randn(rs,6); N2 = N2*N2'+eye(6);
lf2 = struct('leadfield',L2,'orientation','free','label',{{'a';'b';'c';'d';'e';'f'}}, ...
    'leadfield_id','lf2','source_space_id','src2');
cfg2 = struct('inverse',struct('lambda',0.1,'depth_exponent',0.5));
[op2,~] = eegsl.inverse.build_inverse(lf2,N2,cfg2);
weights = zeros(1,12);
for k = 1:4
    cols = 3*k-2:3*k;
    weights(cols) = norm(L2(:,cols),'fro')^(-0.5);
end
Rsrc = diag(weights.^2);
Mexpected = Rsrc*L2'/(L2*Rsrc*L2'+0.1*N2);
tests.closed_form = norm(op2.matrix-Mexpected,'fro')/norm(Mexpected,'fro') < 1e-9;

Lrot = L2;
for k = 1:4
    [Q,~] = qr(randn(rs,3));
    cols = 3*k-2:3*k;
    Lrot(:,cols) = L2(:,cols)*Q;
end
lfrot = lf2; lfrot.leadfield = Lrot;
opRot = eegsl.inverse.build_inverse(lfrot,N2,cfg2);
X2 = randn(rs,6,40);
reduced = eegsl.inverse.reduce_source(op2.matrix*X2,'norm');
reducedRot = eegsl.inverse.reduce_source(opRot.matrix*X2,'norm');
tests.rotation_invariant = norm(reduced-reducedRot,'fro')/norm(reduced,'fro') < 1e-9;

cfg3 = cfg2; cfg3.inverse.depth_exponent = 0.8;
op3 = eegsl.inverse.build_inverse(lf2,N2,cfg3);
tests.id_sensitive = ~strcmp(op2.operator_id,op3.operator_id);

caught = false;
try
    eegsl.inverse.build_inverse(L2,N2,cfg2);
catch err
    caught = strcmp(err.identifier,'eegsl:Inverse:AmbiguousOrientation');
end
tests.ambiguous_numeric = caught;

trials = struct('trial',{{randn(rs,6,10),randn(rs,6,12),randn(rs,6,8)}}, ...
    'label',{{'a';'b';'c';'d';'e';'f'}});
trialOp = eegsl.inverse.build_inverse(struct('leadfield',L2,'orientation','free', ...
    'label',{trials.label}),N2,cfg2);
trialOut = eegsl.inverse.apply_inverse(trialOp,trials);
tests.multi_trial = numel(trialOut.trial) == 3 && ...
    isequal(size(trialOut.trial{1}),[12 10]) && isequal(size(trialOut.trial{3}),[12 8]);
tests.numeric_unchanged = isnumeric(eegsl.inverse.apply_inverse(trialOp,X2)) && ...
    isequal(size(eegsl.inverse.apply_inverse(trialOp,X2)),[12 40]);
badLabels = trials; badLabels.label([1 2]) = badLabels.label([2 1]);
caught = false;
try
    eegsl.inverse.apply_inverse(trialOp,badLabels);
catch err
    caught = strcmp(err.identifier,'eegsl:Inverse:ChannelOrder');
end
tests.label_mismatch = caught;

caught = false;
try
    eegsl.inverse.reduce_source(Y,'dominant');
catch err
    caught = strcmp(err.identifier,'eegsl:Inverse:DominantNotImplemented');
end
tests.dominant_not_implemented = caught;

assert_test_checks(tests,'test_inverse');
tests.all_passed = true;
end
