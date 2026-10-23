function result = run_synthetic_validation(cfg)
%RUN_SYNTHETIC_VALIDATION Public entrypoint for deterministic synthetic E2E validation.
if nargin < 1, cfg = struct(); end
result = eegsl.pipeline.run_synthetic_validation(cfg);
end
