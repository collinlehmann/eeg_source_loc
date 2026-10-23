function cleanup_cache_temps(cfg, folder)
%CLEANUP_CACHE_TEMPS Remove stale temporary cache files.
if nargin < 2 || isempty(folder), folder = cfg.cache.root; end
if ~cfg.cache.cleanup_temp_files || ~isfolder(folder), return; end
files = dir(fullfile(folder,'*.tmp-*.mat'));
for k=1:numel(files)
    if (now-files(k).datenum)*86400 > cfg.cache.stale_lock_seconds
        try, delete(fullfile(files(k).folder,files(k).name)); catch, end
    end
end
end
