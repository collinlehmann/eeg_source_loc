function info = assert_coordinates(varargin)
%ASSERT_COORDINATES Validate coordinate metadata at stage boundaries.
requireUnit = false;
requireCoordsys = false;
args = varargin;
optionStart = numel(args)+1;
if numel(args) >= 2 && is_name(args{end-1})
    optionStart = numel(args)-1;
    while optionStart > 2 && is_name(args{optionStart-2})
        optionStart = optionStart-2;
    end
    options = args(optionStart:end);
    args = args(1:optionStart-1);
    for k = 1:2:numel(options)
        name = lower(char(options{k}));
        switch name
            case 'require_unit'
                requireUnit = require_flag(options{k+1},name);
            case 'require_coordsys'
                requireCoordsys = require_flag(options{k+1},name);
            otherwise
                error('eegsl:Coordinates:Option','Unknown coordinate option: %s.',name);
        end
    end
end
units = {};
coordsys = {};
checked = 0;
for k = 1:numel(args)
    x = args{k};
    if isempty(x), continue; end
    if ~isstruct(x) || ~isscalar(x)
        error('eegsl:Coordinates:Input','Coordinate inputs must be scalar structs or empty.');
    end
    checked = checked+1;
    if ~isfield(x,'unit') || isempty(x.unit)
        if requireUnit, error('eegsl:Coordinates:MissingUnit','A coordinate input is missing its unit.'); end
    else
        units{end+1} = lower(char(x.unit)); %#ok<AGROW>
    end
    if ~isfield(x,'coordsys') || isempty(x.coordsys)
        if requireCoordsys
            error('eegsl:Coordinates:MissingCoordsys','A coordinate input is missing its coordsys.');
        end
    else
        coordsys{end+1} = lower(char(x.coordsys)); %#ok<AGROW>
    end
end
if ~isempty(units) && any(~strcmp(units,units{1}))
    error('eegsl:Coordinates:UnitMismatch','Coordinate units do not match.');
end
if ~isempty(coordsys) && any(~strcmp(coordsys,coordsys{1}))
    error('eegsl:Coordinates:CoordsysMismatch','Coordinate systems do not match.');
end
unit = 'unknown'; if ~isempty(units), unit = units{1}; end
cs = 'unknown'; if ~isempty(coordsys), cs = coordsys{1}; end
info = struct('units',unit,'coordsys',cs,'checked_inputs',checked);
end

function tf = is_name(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end
function tf = require_flag(value,name)
if ~(islogical(value) && isscalar(value))
    error('eegsl:Coordinates:Option','%s must be scalar logical.',name);
end
tf = value;
end
