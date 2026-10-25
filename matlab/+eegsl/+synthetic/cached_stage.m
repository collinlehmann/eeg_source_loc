function [artifact, info] = cached_stage(cfg, stage, keyParts, computeFcn, dims)
%CACHED_STAGE Load a stage artifact on cache hit, otherwise compute and save.
%   Metadata records stage name, seed, dimensions and a config hash (added
%   by save_artifact). Artifacts are stored under kind 'synthetic'.
seed = eegsl.synthetic.resolve_seed(cfg);
key = eegsl.common.cache_key('synthetic','e2e',stage,seed,cfg.synthetic,keyParts{:});
kind = 'synthetic';
if cfg.cache.enabled && eegsl.common.has_artifact(cfg,kind,key)
    [artifact, metadata] = eegsl.common.load_artifact(cfg,kind,key);
    info = struct('stage',stage,'key',key,'cache_hit',true,'metadata',metadata);
    return;
end
artifact = computeFcn();
metadata = struct('stage',stage,'seed',seed,'dimensions',dims, ...
    'orientation_mode',cfg.synthetic.orientation_mode, ...
    'config_hash',eegsl.common.content_hash(cfg.synthetic));
if cfg.cache.enabled && ~cfg.cache.read_only
    eegsl.common.save_artifact(cfg,kind,key,artifact,metadata);
end
info = struct('stage',stage,'key',key,'cache_hit',false,'metadata',metadata);
end
