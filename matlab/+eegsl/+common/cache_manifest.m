function info = cache_manifest(cfg)
%CACHE_MANIFEST Summarize cache contents using platform-independent APIs.
if ~isstruct(cfg) || ~isfield(cfg,'cache'), error('eegsl:Cache:Config','Canonical cache config is required.'); end
root = cfg.cache.root;
info = struct('root',root,'exists',false,'artifacts',struct('kind',{},'path',{},'bytes',{}));
if isempty(root) || ~isfolder(root), return; end
info.exists = true;
files = dir(fullfile(root,'**','*.mat'));
items = repmat(struct('kind','','path','','bytes',0),0,1);
for k = 1:numel(files)
    item = struct('kind','','path',fullfile(files(k).folder,files(k).name),'bytes',files(k).bytes);
    relative = strrep(item.path,[char(root) filesep],'');
    parts = strsplit(relative,filesep);
    if numel(parts) >= 2, item.kind = parts{1}; end
    items(end+1,1) = item; %#ok<AGROW>
end
info.artifacts = items;
end
