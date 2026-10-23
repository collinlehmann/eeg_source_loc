function release_cache_lock(lock_path)
%RELEASE_CACHE_LOCK Release a cache directory lock.
if nargin < 1 || isempty(lock_path), return; end
if isfolder(lock_path)
    try, rmdir(lock_path,'s'); catch, end
end
end
