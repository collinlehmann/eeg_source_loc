function path = artifact_path(cfg, kind, key)
%ARTIFACT_PATH Return a platform-independent cache artifact path.
%   Uses fullfile and never assumes a path separator or shell command.
if nargin < 3 || isempty(key), error('eegsl:Cache:MissingKey','Artifact key is required.'); end
if nargin < 2 || isempty(kind), error('eegsl:Cache:MissingKind','Artifact kind is required.'); end
if ~isstruct(cfg) || ~isfield(cfg,'cache') || ~isstruct(cfg.cache)
    error('eegsl:Cache:Config','Canonical cfg.cache configuration is required.');
end
root = cfg.cache.root;
if isempty(root), error('eegsl:Cache:Root','cfg.cache.root must be configured.'); end
root = char(root);
kind = sanitize_component(kind,'kind');
key = sanitize_component(key,'key');
path = fullfile(root,kind,[key '.mat']);
end

function value = sanitize_component(value,name)
value = char(value);
if isempty(value) || any(value == char(0)) || any(value == '/' | value == '\') || ...
        any(value == ':') || any(value == '*') || any(value == '?') || ...
        any(value == '"') || any(value == '<') || any(value == '>') || any(value == '|')
    error('eegsl:Cache:PathComponent','Invalid %s for a cache path.',name);
end
end
