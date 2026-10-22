function key = cache_key(kind, varargin)
%CACHE_KEY Build a deterministic cache key from artifact kind and inputs.
if nargin < 1 || isempty(kind)
    error('eegsl:Cache:MissingKind','A cache artifact kind is required.');
end
payload = struct('kind',char(kind),'inputs',{varargin});
key = sprintf('%s-%s',lower(char(kind)),eegsl.common.content_hash(payload));
end
