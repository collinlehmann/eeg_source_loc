function result = run_synthetic_validation(cfg)
%RUN_SYNTHETIC_VALIDATION Deprecated alias for validate_synthetic_e2e.
if nargin < 1, cfg = struct(); end
warning('eegsl:Deprecated:RunSyntheticValidation', ...
    'eegsl.run_synthetic_validation is deprecated; use eegsl.validate_synthetic_e2e.');
result = eegsl.validate_synthetic_e2e(cfg);
end
