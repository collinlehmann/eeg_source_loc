function tf = has_fieldtrip()
%HAS_FIELDTRIP Return true when a required FieldTrip symbol is available.
tf = exist('ft_datatype_raw','file') == 2 || exist('ft_prepare_leadfield','file') == 2;
end
