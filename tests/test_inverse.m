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
tests.all_passed = all(structfun(@(x)logical(x),tests));
if ~tests.all_passed, error('eegsl:Tests:InverseFailure','Inverse test failed.'); end
end
