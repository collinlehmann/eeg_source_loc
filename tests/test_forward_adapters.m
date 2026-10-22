function tests = test_forward_adapters()
%TEST_FORWARD_ADAPTERS Dependency-free tests for adapter seams and cache keys.
mesh = struct('pnt',zeros(4,3),'tet',ones(1,4));
cond = [0.33 0.013 0.33];
elec = struct('chanpos',zeros(8,3),'unit','mm');
sourcemodel = struct('pos',zeros(10,3),'orientation','free','unit','mm');
cfg = struct('forward',struct('engine','analytic','require_fieldtrip',false));
[hm,hmInfo] = eegsl.forward.build_headmodel(mesh,cond,cfg);
[linked,projected,linkInfo] = eegsl.forward.link_sensors(hm,elec,cfg); %#ok<ASGLU>
cfg.analytic_leadfield = struct('leadfield',{randn(8,30)});
[lf,lfInfo] = eegsl.forward.build_leadfield(linked,projected,sourcemodel,cfg); %#ok<ASGLU>
keys = eegsl.forward.forward_cache_keys(mesh,cond,hm,elec,sourcemodel,cfg);
tests.adapter = isstruct(hm) && isstruct(linked) && isstruct(lf);
tests.timing = isfield(hmInfo,'elapsed_seconds') && isfield(linkInfo,'elapsed_seconds');
tests.keys = isfield(keys,'stiffness_key') && isfield(keys,'transfer_key') && isfield(keys,'leadfield_key');
tests.orientation = strcmp(lf.orientation,'free');
tests.all_passed = all(structfun(@(x) logical(x),tests));
if ~tests.all_passed, error('eegsl:Tests:ForwardFailure','Forward adapter test failed.'); end
end
