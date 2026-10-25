function [sigma_max, info] = sigma_max(R, G, Lambda, opts)
%SIGMA_MAX Largest sigma with R - Lambda - (sigma^2/3)*G positive semidefinite.
if nargin < 3 || isempty(Lambda), Lambda = zeros(size(R)); end
if nargin < 4, opts = struct(); end
tol = getf(opts,'tol',1e-10);
method = lower(char(getf(opts,'method','closed_form')));
maxIter = getf(opts,'max_iterations',200);
R = sym_(R);
G = sym_(G);
A = sym_(R - Lambda);
scale = max(abs(eig(R)));
if ~(scale > 0)
    error('eegsl:Noise:ZeroScale','R has no nonzero eigenvalues.');
end
if norm(G,'fro') == 0
    error('eegsl:Noise:ZeroGeometry','Geometry term G is zero.');
end
[V,D] = eig(A);
d = real(diag(D));
if min(d) < -tol*scale
    error('eegsl:Noise:LambdaNotPSD','R - Lambda is not PSD within relative tolerance.');
end
keep = d > tol*scale;
Vn = V(:,~keep);
if ~any(keep)
    s = 0;
elseif ~isempty(Vn) && norm(Vn'*G*Vn,'fro') > tol*norm(G,'fro')
    s = 0;
else
    switch method
        case 'closed_form'
            Wh = V(:,keep) * diag(1./sqrt(d(keep)));
            maxEig = max(real(eig(sym_(Wh'*G*Wh))));
            if ~(maxEig > 0)
                error('eegsl:Noise:ZeroGeometry','Geometry term has no positive energy in the retained subspace.');
            end
            s = 1/maxEig;
        case 'bisection'
            hi = trace(A)/trace(G);
            if ~(hi > 0), s = 0;
            else
                lo = 0;
                for k = 1:maxIter %#ok<NASGU>
                    mid = (lo+hi)/2;
                    if min(real(eig(sym_(A-mid*G)))) >= -tol*scale
                        lo = mid;
                    else
                        hi = mid;
                    end
                    if hi-lo <= 1e-12*hi, break; end
                end
                s = lo;
            end
        otherwise
            error('eegsl:Noise:SigmaMethod','Unknown sigma_max method: %s.',method);
    end
end
sigma_max = sqrt(3*s);
C = sym_(A-s*G);
info = struct('method',method,'s',s,'relative_tolerance',tol,'scale',scale, ...
    'min_eig_ratio',min(real(eig(C)))/scale,'retained_dimension',sum(keep));
end

function A = sym_(A)
A = (A+A')/2;
end

function value = getf(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
end
