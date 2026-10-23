function hash = cache_config_hash(cfg)
%CACHE_CONFIG_HASH Hash computation-relevant configuration only.
%   Cache location and concurrency policy are excluded so moving a cache or
%   changing overwrite/lock settings does not invalidate scientific artifacts.
if nargin < 1 || isempty(cfg), cfg = eegsl.default_config(); end
if ~isstruct(cfg), error('eegsl:Cache:Config','cfg must be a struct.'); end
fingerprint = cfg;
if isfield(fingerprint,'cache')
    excluded = {'root','enabled','read_only','overwrite','lock_timeout_seconds', ...
        'stale_lock_seconds','cleanup_temp_files'};
    for k=1:numel(excluded)
        if isfield(fingerprint.cache,excluded{k}), fingerprint.cache=rmfield(fingerprint.cache,excluded{k}); end
    end
end
hash = eegsl.common.content_hash(fingerprint);
end
