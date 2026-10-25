function [values, info] = resolve_conductivity(mesh, conductivity)
%RESOLVE_CONDUCTIVITY Order FEM conductivities by mesh.tissuelabel.
if ~isstruct(mesh) || ~isfield(mesh,'tissuelabel') || isempty(mesh.tissuelabel)
    error('eegsl:Forward:MissingTissueLabel', ...
        'FEM meshes must provide mesh.tissuelabel.');
end
labels = mesh.tissuelabel;
if ischar(labels), labels = cellstr(labels); end
if isstring(labels), labels = cellstr(labels(:)); end
labels = labels(:);
if isstruct(conductivity)
    names = fieldnames(conductivity);
    values = zeros(numel(labels),1);
    for k = 1:numel(labels)
        idx = find(strcmp(names,char(labels{k})),1);
        if isempty(idx)
            error('eegsl:Forward:ConductivityMissingTissue', ...
                'No conductivity value was supplied for tissue "%s".',char(labels{k}));
        end
        value = conductivity.(names{idx});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value>0)
            error('eegsl:Forward:ConductivityValue', ...
                'Conductivity for tissue "%s" must be a positive scalar.',char(labels{k}));
        end
        values(k) = value;
    end
    extra = names(~ismember(names,labels));
    if ~isempty(extra)
        error('eegsl:Forward:ConductivityExtraTissue', ...
            'Conductivity values were supplied for absent tissue "%s".',extra{1});
    end
elseif isnumeric(conductivity) && isvector(conductivity) && ...
        numel(conductivity) == numel(labels)
    values = double(conductivity(:));
    warning('eegsl:Forward:ConductivityOrderAssumed', ...
        'Numeric conductivity order is assumed to match mesh.tissuelabel.');
else
    error('eegsl:Forward:ConductivityShape', ...
        'Conductivity must map tissue names to values or match mesh.tissuelabel length.');
end
if any(~isfinite(values)) || any(values<=0)
    error('eegsl:Forward:ConductivityValue','Conductivity values must be finite and positive.');
end
info = struct('tissuelabel',{labels},'values',values);
end
