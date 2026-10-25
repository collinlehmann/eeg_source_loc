function tests = test_source_space_grid()
%TEST_SOURCE_SPACE_GRID Verify the world-coordinate lattice contracts.
mirrorOK = true;
for nx = 255:257
    dims = [nx 51 51];
    mask = ellipsoid_mask(dims,[100 20 20]);
    anatomy = fixture(mask,[nx 51 51]);
    for spacing = 2:7
        cfg = struct('source',struct('spacing_mm',spacing));
        sm = eegsl.source.build_source_space(anatomy,[],cfg);
        insidePos = sm.pos(sm.inside,:);
        mirrorOK = mirrorOK && all(ismembertol([-insidePos(:,1),insidePos(:,2:3)], ...
            insidePos,1e-9,'ByRows',true));
        dx = unique(diff(unique(insidePos(:,1))));
        mirrorOK = mirrorOK && all(abs(dx-spacing)<1e-9);
    end
end
tests.mirror_symmetric = mirrorOK;

mask = ellipsoid_mask([61 61 61],[25 20 15]);
anatomy = fixture(mask,[61 61 61]);
sm = eegsl.source.build_source_space(anatomy,[],struct('source',struct('spacing_mm',4)));
tests.fieldtrip_shape = prod(sm.dim) == size(sm.pos,1) && ...
    numel(sm.inside) == size(sm.pos,1) && numel(sm.label) == size(sm.pos,1);
ix = randperm(size(sm.pos,1),min(10,size(sm.pos,1)));
[a,b,c] = ind2sub(sm.dim,ix);
expected = sm.pos(sub2ind(sm.dim,a,b,c),:)';
actual = sm.transform*[a(:)';b(:)';c(:)';ones(1,numel(ix))];
tests.transform_maps_lattice = max(abs(actual(1:3,:)-expected),[],'all') < 1e-9;

cube = fixture(true(30,30,30),[30 30 30]);
cubeCfg = struct('source',struct('spacing_mm',3,'neighbor_continuity',true, ...
    'symmetry',false));
cubeSpace = eegsl.source.build_source_space(cube,[],cubeCfg);
occ = reshape(cubeSpace.inside,cubeSpace.dim);
neighbors = convn(double(occ),ones(3,3,3),'same')-double(occ);
tests.continuity = ~occ(1,1,1) && any(occ(:)) && all(neighbors(occ)>=8);

derived = eegsl.source.build_source_space(anatomy,[], ...
    struct('source',struct('spacing_mm',[],'target_points',3000)));
tests.target_count = abs(nnz(derived.inside)-3000) <= 150;

shift = [eye(3),-ones(3,1);0 0 0 1];
nifti = anatomy;
nifti.transform_convention = 'nifti';
nifti.transform = anatomy.transform/shift;
ftSpace = eegsl.source.build_source_space(anatomy,[], ...
    struct('source',struct('spacing_mm',5)));
niftiSpace = eegsl.source.build_source_space(nifti,[], ...
    struct('source',struct('spacing_mm',5)));
tests.nifti_convention = isequal(ftSpace.pos,niftiSpace.pos);

tests.missing_unit = error_id(rmfield(anatomy,'unit'),'eegsl:Source:MissingUnit');
tests.missing_coordsys = error_id(setfield(anatomy,'coordsys',''), ...
    'eegsl:Source:MissingCoordsys'); %#ok<SFLD>
badCoordsys = anatomy; badCoordsys.coordsys = 'unknown';
tests.coordsys_not_lr = error_id(badCoordsys,'eegsl:Source:CoordsysNotLR');
badConvention = anatomy; badConvention.transform_convention = 'other';
tests.transform_convention = error_id(badConvention,'eegsl:Source:TransformConvention');

assert_test_checks(tests,'test_source_space_grid');
tests.all_passed = true;
end

function anatomy = fixture(mask,dims)
center = (dims+1)/2;
T = [eye(3),-center(:);0 0 0 1];
anatomy = struct('mask',mask,'transform',T,'transform_convention','fieldtrip', ...
    'unit','mm','coordsys','ras');
end

function mask = ellipsoid_mask(dims,radii)
[i,j,k] = ndgrid(1:dims(1),1:dims(2),1:dims(3));
c = (dims+1)/2;
mask = ((i-c(1))/radii(1)).^2+((j-c(2))/radii(2)).^2+ ...
    ((k-c(3))/radii(3)).^2 <= 1;
end

function caught = error_id(anatomy,id)
caught = false;
try
    eegsl.source.build_source_space(anatomy,[], ...
        struct('source',struct('spacing_mm',5)));
catch err
    caught = strcmp(err.identifier,id);
end
end
