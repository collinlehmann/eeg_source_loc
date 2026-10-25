function m = compute_metrics(cfg, space, lf, src, sens, estimate)
%COMPUTE_METRICS Sensor error, source similarity and localization metrics.
%   Tolerance guidance: the pipeline is deterministic, so repeated runs on
%   the same MATLAB build should agree to ~1e-10 (relative); tests use 1e-9.
%   Metric values describe this toy setup only, not real-world accuracy.
L = lf.leadfield;
S = src.source;
Y = estimate;
if ~isequal(size(Y),size(S))
    error('eegsl:Synthetic:EstimateDimension','Estimate size [%s] differs from truth size [%s].', ...
        num2str(size(Y)),num2str(size(S)));
end
recon = L*Y;
err = recon - sens.clean;
m = struct();
m.sensor_rmse = sqrt(mean(err(:).^2));
m.sensor_relative_frobenius = norm(err,'fro')/max(eps,norm(sens.clean,'fro'));

Sr = reduce(S,cfg); Yr = reduce(Y,cfg);
active = src.active_sources;
c = zeros(numel(active),1);
for k = 1:numel(active)
    c(k) = corr_(Sr(active(k),:),Yr(active(k),:));
end
m.source_correlation_active = c;
m.source_correlation_mean = mean(c);
m.source_r2 = 1 - sum((Sr(:)-Yr(:)).^2)/max(eps,sum((Sr(:)-mean(Sr(:))).^2));

[~,tp] = max(max(Sr,[],1));
[~,trueIdx] = max(Sr(:,tp));
[~,estIdx] = max(Yr(:,tp));
m.peak_time_index = tp;
m.peak_true_source = trueIdx;
m.peak_estimated_source = estIdx;
m.localization_error = norm(space.pos(estIdx,:)-space.pos(trueIdx,:));
[~,order] = sort(Yr(:,tp),'descend');
k = min(3,numel(order));
m.top3_hit = any(order(1:k) == trueIdx);
if ~isempty(space.deep_source_index)
    d = space.deep_source_index;
    [~,td] = max(Sr(d,:));
    [~,o] = sort(Yr(:,td),'descend');
    m.deep_source_rank = find(o == d,1);
else
    m.deep_source_rank = NaN;
end
end

function R = reduce(X,cfg)
if strcmp(cfg.synthetic.orientation_mode,'free')
    R = eegsl.inverse.reduce_source(X,'norm');
else
    R = abs(X);
end
end

function c = corr_(a,b)
a = a(:)-mean(a(:)); b = b(:)-mean(b(:));
d = norm(a)*norm(b);
if d <= eps, c = 0; else, c = (a'*b)/d; end
end
