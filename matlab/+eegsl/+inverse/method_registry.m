function method = method_registry(requested)
%METHOD_REGISTRY Validate and canonicalize inverse method names.
if nargin < 1 || isempty(requested), requested = 'wmne'; end
method = lower(char(requested));
valid = {'wmne','eloreta','sloreta','lcmv'};
if ~ismember(method,valid)
    error('eegsl:Inverse:UnknownMethod','Unknown inverse method: %s.',method);
end
end
