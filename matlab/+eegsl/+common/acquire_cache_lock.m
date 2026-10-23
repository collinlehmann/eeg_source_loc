function lock_path = acquire_cache_lock(cfg, target_path)
%ACQUIRE_CACHE_LOCK Acquire a cross-platform directory lock.
%   mkdir is atomic enough for the lock-claim operation on local Windows and
%   macOS filesystems. A stale lock is removed after the configured age.
lock_path = [target_path '.lock'];
timeout = cfg.cache.lock_timeout_seconds;
stale_age = cfg.cache.stale_lock_seconds;
t0 = tic;
while true
    if isfolder(lock_path)
        d = dir(lock_path);
        if ~isempty(d) && (now - d(1).datenum)*86400 > stale_age
            try, rmdir(lock_path,'s'); catch, end
        end
    end
    if ~isfolder(lock_path)
        [ok,~,~] = mkdir(lock_path);
        if ok && isfolder(lock_path), return; end
    end
    if toc(t0) >= timeout
        error('eegsl:Cache:LockTimeout','Timed out acquiring cache lock: %s',lock_path);
    end
    pause(min(0.1,max(0.01,timeout/100)));
end
end
