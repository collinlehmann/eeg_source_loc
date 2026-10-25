function tests = test_forward_adapters()
%TEST_FORWARD_ADAPTERS Dependency-free tests for adapter seams and cache keys.
mesh = struct('pnt',zeros(4,3),'tet',ones(1,4),'unit','mm');
cond = [0.33 0.013 0.33];
elec = struct('chanpos',zeros(8,3),'unit','mm');
sourcemodel = struct('pos',zeros(10,3),'orientation','free','unit','mm');
cfg = struct('forward',struct('engine','analytic','require_fieldtrip',false));
[hm,hmInfo] = eegsl.forward.build_headmodel(mesh,cond,cfg);
[linked,projected,linkInfo] = eegsl.forward.link_sensors(hm,elec,cfg); %#ok<ASGLU>
cfg.forward.analytic.leadfield = struct('leadfield',{randn(8,30)});
[lf,lfInfo] = eegsl.forward.build_leadfield(linked,projected,sourcemodel,cfg); %#ok<ASGLU>
keys = eegsl.forward.forward_cache_keys(mesh,cond,elec,sourcemodel,cfg);
cfg2 = cfg; cfg2.inverse = struct('lambda',0.2);
keysStable = eegsl.forward.forward_cache_keys(mesh,cond,elec,sourcemodel,cfg2);
src2 = sourcemodel; src2.pos(1,1) = src2.pos(1,1)+1;
keysSource = eegsl.forward.forward_cache_keys(mesh,cond,elec,src2,cfg);
elec2 = elec; elec2.chanpos(1,1) = elec2.chanpos(1,1)+1;
keysElec = eegsl.forward.forward_cache_keys(mesh,cond,elec2,sourcemodel,cfg);
tests.adapter = isstruct(hm) && isstruct(linked) && isstruct(lf);
tests.timing = isfield(hmInfo,'elapsed_seconds') && isfield(linkInfo,'elapsed_seconds');
tests.keys = isfield(keys,'stiffness_key') && isfield(keys,'transfer_key') && isfield(keys,'leadfield_key');
tests.keys_stable = isequal(keys,keysStable);
tests.keys_scoped = strcmp(keys.stiffness_key,keysSource.stiffness_key) && ...
    strcmp(keys.transfer_key,keysSource.transfer_key) && ...
    ~strcmp(keys.leadfield_key,keysSource.leadfield_key) && ...
    strcmp(keys.stiffness_key,keysElec.stiffness_key) && ...
    ~strcmp(keys.transfer_key,keysElec.transfer_key) && ...
    ~strcmp(keys.leadfield_key,keysElec.leadfield_key);
tests.orientation = strcmp(lf.orientation,'free');

normals = [1 0 0;0 1 0];
H = randn(8,6);
surfaceSource = struct('pos',randn(2,3),'inside',true(2,1), ...
    'nrm',normals,'orientation','surface-normal');
normalCfg = eegsl.default_config();
normalCfg.forward.engine = 'analytic';
normalCfg.forward.require_fieldtrip = false;
normalCfg.forward.analytic.builder = @(a,b,c,d)struct('leadfield',H); %#ok<NASGU>
normalLf = eegsl.forward.build_leadfield(linked,projected,surfaceSource,normalCfg);
expected = [H(:,1:3)*normals(1,:)',H(:,4:6)*normals(2,:)'];
tests.surface_normal_projection = norm(normalLf.leadfield-expected,'fro') < 1e-12 && ...
    strcmp(normalLf.orientation,'surface-normal') && normalLf.normals_applied;
missingNormals = rmfield(surfaceSource,'nrm');
caught = false;
try
    eegsl.forward.build_leadfield(linked,projected,missingNormals,normalCfg);
catch err
    caught = strcmp(err.identifier,'eegsl:Forward:MissingNormals');
end
tests.missing_normals = caught;

tissueMesh = struct('tissuelabel',{{'scalp','skull'}});
[ordered,condInfo] = eegsl.forward.resolve_conductivity(tissueMesh, ...
    struct('skull',0.01,'scalp',0.43));
tests.conductivity_ordered = isequal(ordered,[0.43;0.01]) && ...
    isequal(condInfo.tissuelabel,{'scalp';'skull'});
lastwarn('');
eegsl.forward.resolve_conductivity(tissueMesh,[0.43 0.01]);
[~,conductivityWarning] = lastwarn;
tests.conductivity_order_assumed = strcmp(conductivityWarning, ...
    'eegsl:Forward:ConductivityOrderAssumed');
tests.conductivity_missing = error_id(@()eegsl.forward.resolve_conductivity( ...
    tissueMesh,struct('scalp',0.43)),'eegsl:Forward:ConductivityMissingTissue');
tests.conductivity_extra = error_id(@()eegsl.forward.resolve_conductivity( ...
    tissueMesh,struct('scalp',0.43,'skull',0.01,'brain',0.33)), ...
    'eegsl:Forward:ConductivityExtraTissue');
tests.missing_tissue_labels = error_id(@()eegsl.forward.resolve_conductivity( ...
    struct(),[0.43 0.01]),'eegsl:Forward:MissingTissueLabel');
legacyCfg = struct('fieldtrip',struct());
tests.legacy_fieldtrip_config = error_id(@()eegsl.forward.build_headmodel( ...
    mesh,cond,legacyCfg),'eegsl:Forward:LegacyFieldTripConfig');
assert_test_checks(tests,'test_forward_adapters');
tests.all_passed = true;
end

function caught = error_id(f,id)
caught = false;
try, f(); catch err, caught = strcmp(err.identifier,id); end
end
