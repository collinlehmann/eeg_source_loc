function tests = test_petra()
%TEST_PETRA Dependency-free fail-closed PETRA QC tests.
labels=zeros(6,6,6); labels(2:5,2:5,2:5)=7;
charm=struct('labels',labels,'conformed_t1',struct('image','synthetic'));
root=eegsl.default_config();
[out,disabled]=eegsl.petra.refine_skull_with_petra(root,charm,rand(6,6,6));
tests.disabled_default=isequal(out,labels)&&strcmp(disabled.reason,'disabled')&& ...
    ~isempty(disabled.identity);

[out,noPetra]=eegsl.petra.refine_skull_with_petra(struct('petra', ...
    struct('enabled',true)),charm,[]);
tests.no_petra=isequal(out,labels)&&strcmp(noPetra.reason,'no_petra')&& ...
    ~isempty(noPetra.identity);

cfg=struct('petra',struct('enabled',true,'allow_fallback',false, ...
    'registration_callback',@register_identity, ...
    'segmentation_callback',@segment_synthetic, ...
    'skull_label',7,'compact_label',8,'cancellous_label',9, ...
    'qc',struct('dice_min',0.8,'surface_distance95_max',2.0), ...
    'qc_callback',@qc_pass));
[out,info]=eegsl.petra.refine_skull_with_petra(cfg,charm,rand(6,6,6));
tests.callback_path=info.used&&any(out(:)==8)&&any(out(:)==9)&&info.qc.pass;

qcUnavailable=cfg; qcUnavailable.petra=rmfield(qcUnavailable.petra,'qc_callback');
qcUnavailable.petra.allow_fallback=true;
[out,info]=eegsl.petra.refine_skull_with_petra(qcUnavailable,charm,rand(6,6,6));
tests.qc_unavailable=isequal(out,labels)&&strcmp(info.reason,'qc_unavailable');

qcFailed=cfg; qcFailed.petra.qc_callback=@qc_fail;
[out,info]=eegsl.petra.refine_skull_with_petra(qcFailed,charm,rand(6,6,6));
tests.qc_failed=isequal(out,labels)&&strcmp(info.reason,'qc_failed');

partial=cfg; partial.petra.segmentation_callback=@segment_incomplete;
[out,info]=eegsl.petra.refine_skull_with_petra(partial,charm,rand(6,6,6));
tests.incomplete_coverage=isequal(out,labels)&&strcmp(info.reason,'mask_error')&& ...
    strcmp(info.mask_error,'incomplete_coverage');

strict=qcUnavailable; strict.petra.allow_fallback=false;
caught=false;
try
    eegsl.petra.refine_skull_with_petra(strict,charm,rand(6,6,6));
catch err
    caught=strcmp(err.identifier,'eegsl:PETRA:QcUnavailable');
end
tests.no_fallback_errors=caught;
assert_test_checks(tests,'test_petra');
tests.all_passed=true;
end
function [out,info]=register_identity(vol,~,~)
out=vol; info=struct('backend','synthetic-identity');
end
function [compact,cancellous,info]=segment_synthetic(~,charm,~)
skull=charm.labels==7; compact=false(size(skull)); cancellous=false(size(skull));
compact(2:3,2:5,2:5)=true; cancellous=skull&~compact;
info=struct('method','synthetic');
end
function [compact,cancellous,info]=segment_incomplete(varargin)
[compact,cancellous,info]=segment_synthetic(varargin{:});
cancellous(:)=false;
end
function qc=qc_pass(varargin)
qc=struct('dice',0.9,'surface_distance95',1.0,'surface_distance_mean',0.5);
end
function qc=qc_fail(varargin)
qc=struct('dice',0.5,'surface_distance95',1.0);
end
