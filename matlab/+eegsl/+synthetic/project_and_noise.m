function sens = project_and_noise(cfg, lf, src)
%PROJECT_AND_NOISE Forward project sources and add deterministic white noise.
%   Noise std is set from snr_db (default 20 dB) relative to the RMS of the
%   clean sensor data.
L = lf.leadfield;
S = src.source;
if size(L,2) ~= size(S,1)
    error('eegsl:Synthetic:ForwardDimension','Leadfield has %d columns but sources have %d rows.',size(L,2),size(S,1));
end
snr = cfg.synthetic.snr_db;
if isempty(snr), snr = 20; end
X = L*S;
sigma = sqrt(mean(X(:).^2)) / 10^(snr/20);
switch cfg.synthetic.noise_model
    case 'white'
        noise = sigma * randn(eegsl.synthetic.stream_for(cfg,2),size(X));
    otherwise
        error('eegsl:Synthetic:NoiseModel','Unsupported noise model: %s.',cfg.synthetic.noise_model);
end
sens = struct('clean',X,'noisy',X+noise,'noise',noise,'noise_std',sigma,'snr_db',snr);
end
