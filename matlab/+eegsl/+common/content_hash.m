function key = content_hash(value)
%CONTENT_HASH SHA-256 fingerprint of MATLAB's serialized value.
bytes = uint8(getByteStreamFromArray(value));
try
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes);
    digest = typecast(md.digest(),'uint8');
    key = lower(reshape(dec2hex(digest,2).',1,[]));
catch err
    error('eegsl:Common:NoSHA256', ...
        'content_hash requires the JVM (SHA-256); start MATLAB without -nojvm. %s',err.message);
end
end
