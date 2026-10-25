function source = apply_inverse(operator, data)
%APPLY_INVERSE Apply a frozen inverse operator without side effects.
if nargin < 2, error('eegsl:Inverse:MissingData','data is required.'); end
if ~isstruct(operator) || ~isfield(operator,'matrix')
    error('eegsl:Inverse:OperatorFormat','operator.matrix is required.');
end
M = operator.matrix;
if isnumeric(data)
    check_channels(data,operator);
    source = M*double(data);
    return;
end
if ~isstruct(data)
    error('eegsl:Inverse:DataFormat','Expected numeric data or a FieldTrip-like data struct.');
end
check_labels(data,operator);
if isfield(data,'trial') && iscell(data.trial)
    source = data;
    source.trial = cell(size(data.trial));
    for k = 1:numel(data.trial)
        check_channels(data.trial{k},operator);
        source.trial{k} = M*double(data.trial{k});
    end
    source.label = source_labels(size(M,1));
elseif isfield(data,'avg')
    check_channels(data.avg,operator);
    source = data;
    source.avg = M*double(data.avg);
    source.label = source_labels(size(M,1));
elseif isfield(data,'data')
    check_channels(data.data,operator);
    source = data;
    source.data = M*double(data.data);
    source.label = source_labels(size(M,1));
else
    error('eegsl:Inverse:DataFormat','Expected data.trial, data.avg, or data.data.');
end
source.inverse_operator_id = operator.operator_id;
end

function check_channels(X,operator)
if ~ismatrix(X) || size(X,1) ~= operator.n_channels
    error('eegsl:Inverse:ApplyChannels','Data channel count differs from operator.');
end
end

function check_labels(data,operator)
if isfield(operator,'label') && ~isempty(operator.label) && isfield(data,'label') && ...
        ~isequal(data.label(:),operator.label(:))
    error('eegsl:Inverse:ChannelOrder', ...
        'Data channel labels or order differ from the operator; select/reorder channels before apply (for example, with ft_selectdata).');
end
end

function labels = source_labels(n)
labels = arrayfun(@(k)sprintf('source_%d',k),1:n,'UniformOutput',false)';
end
