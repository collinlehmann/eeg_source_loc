function tests = test_petra()
%TEST_PETRA Dependency-free tests for PETRA fallback and callback seams.
labels = zeros(6,6,6);
labels(2:5,2:5,2:5) = 7;
charm = struct('labels',labels,'conformed_t1',struct('image','synthetic'));

[out,info] = eegsl.petra.refine_skull_with_petra(struct('enabled',true),charm,[]);
tests.missing_fallback = isequal(out,labels) && strcmp(info.reason,'no_petra');

cfg = struct('enabled',true,'allow_fallback',false, ...
    'registration_callback',@register_identity, ...
    'segmentation_callback',@segment_synthetic, ...
    'skull_label',7,'compact_label',8,'cancellous_label',9, ...
    'qc_callback',@qc_pass);
[out,info] = eegsl.petra.refine_skull_with_petra(cfg,charm,rand(6,6,6));
tests.callback_path = info.used && any(out(:)==8) && any(out(:)==9);

assert_test_checks(tests,'test_petra');
tests.all_passed = true;
end
function [out,info] = register_identity(vol,~,~), out = vol; info = struct('backend','synthetic-identity'); end
function [compact,cancellous,info] = segment_synthetic(~,charm,~)
skull = charm.labels == 7;
compact = false(size(skull)); cancellous = false(size(skull));
compact(2:3,2:5,2:5) = true;
cancellous = skull & ~compact;
info = struct('method','synthetic');
end
function qc = qc_pass(varargin), qc = struct('pass',true,'dice',1); end
