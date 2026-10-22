function info = provenance(stage, details)
%PROVENANCE Create a small, serializable provenance record.
if nargin < 2 || isempty(details), details = struct(); end
info = details;
info.stage = char(stage);
info.created_utc = char(datetime('now','TimeZone','UTC','Format', ...
    'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
info.toolbox = 'eeg_source_loc';
end
