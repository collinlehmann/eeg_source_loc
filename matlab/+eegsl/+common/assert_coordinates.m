function info = assert_coordinates(varargin)
%ASSERT_COORDINATES Validate coordinate/unit metadata at stage boundaries.
%   Inputs are FieldTrip-like structs. Every non-empty input must expose a
%   consistent unit when units are available.
units = {};
for i = 1:nargin
    x = varargin{i};
    if isempty(x), continue; end
    if isfield(x,'unit') && ~isempty(x.unit)
        units{end+1} = lower(char(x.unit)); %#ok<AGROW>
    end
end
if ~isempty(units) && any(~strcmp(units,units{1}))
    error('eegsl:Coordinates:UnitMismatch','Coordinate units do not match.');
end
if isempty(units)
    selected = 'unknown';
else
    selected = units{1};
end
info = struct('units',selected,'checked_inputs',nargin);
end
