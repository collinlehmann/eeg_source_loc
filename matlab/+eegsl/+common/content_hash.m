function key = content_hash(value)
%CONTENT_HASH Deterministic dependency-light content fingerprint.
%   Uses SHA-256 when Java is available and a stable textual fallback otherwise.
bytes = uint8(getByteStreamFromArray(value));
try
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes);
    digest = typecast(md.digest(),'uint8');
    key = lower(reshape(dec2hex(digest,2).',1,[]));
catch
    x = double(bytes(:));
    h = mod(sum(x .* (1:numel(x))'), 2^53-1);
    key = sprintf('fallback-%016x',uint64(h));
end
end
