function source = apply_inverse(operator, data)
%APPLY_INVERSE Apply a frozen inverse operator without side effects.
%   This function is intentionally a silent matrix projection. It does not
%   estimate covariance, select parameters, normalize, or emit progress.
if nargin < 2, error('eegsl:Inverse:MissingData','data is required.'); end
if ~isstruct(operator) || ~isfield(operator,'matrix')
    error('eegsl:Inverse:OperatorFormat','operator.matrix is required.');
end
X = extract_samples(data);
if size(X,1) ~= size(operator.matrix,2)
    error('eegsl:Inverse:ApplyChannels','Data channel count differs from operator.');
end
Y = operator.matrix * double(X);
source = format_output(Y,data,operator);
end

function X = extract_samples(data)
if isnumeric(data), X = data; return; end
if isstruct(data) && isfield(data,'data'), X = data.data; return; end
if isstruct(data) && isfield(data,'avg'), X = data.avg; return; end
if isstruct(data) && isfield(data,'trial') && iscell(data.trial)
    if numel(data.trial) ~= 1
        X = cellfun(@(x)double(x),data.trial,'UniformOutput',false); return;
    end
    X = data.trial{1}; return;
end
error('eegsl:Inverse:DataFormat','Expected numeric data or a FieldTrip-like data struct.');
end

function source = format_output(Y,data,operator)
if isstruct(data) && isfield(data,'trial') && iscell(data.trial) && numel(data.trial) > 1
    source = data;
    source.trial = cell(size(data.trial));
    for k = 1:numel(data.trial)
        source.trial{k} = operator.matrix * double(data.trial{k});
    end
    source.label = source_labels(size(operator.matrix,1));
    source.inverse_operator_id = operator.operator_id;
else
    source = Y;
end
end
function labels = source_labels(n)
labels = arrayfun(@(k)sprintf('source_%d',k),1:n,'UniformOutput',false)';
end
