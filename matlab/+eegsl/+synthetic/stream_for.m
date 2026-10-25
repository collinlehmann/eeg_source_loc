function s = stream_for(cfg, offset)
%STREAM_FOR Independent deterministic RNG stream; never touches the global stream.
s = RandStream('twister','Seed',double(eegsl.synthetic.resolve_seed(cfg)) + double(offset));
end
