classdef ProgressLogger < handle
    %PROGRESSLOGGER Rate-limited console and file progress logger.
    properties
        Enabled = true
        LogFile = ''
        IntervalSeconds = 1
    end
    properties (Access=private)
        LastTime = -inf
        FileId = -1
        Clock
    end
    methods
        function obj = ProgressLogger(cfg)
            obj.Clock = tic;
            if nargin < 1, cfg = struct(); end
            if isfield(cfg,'enabled'), obj.Enabled = logical(cfg.enabled); end
            if isfield(cfg,'log_file'), obj.LogFile = char(cfg.log_file); end
            if isfield(cfg,'interval_seconds'), obj.IntervalSeconds = cfg.interval_seconds; end
            if obj.Enabled && ~isempty(obj.LogFile)
                [folder,~,~] = fileparts(obj.LogFile);
                if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
                obj.FileId = fopen(obj.LogFile,'a');
                if obj.FileId < 0, error('eegsl:Progress:OpenLog','Cannot open log file.'); end
            end
        end
        function log(obj, message, varargin)
            if ~obj.Enabled, return; end
            nowSeconds = toc(obj.Clock);
            if nowSeconds-obj.LastTime < obj.IntervalSeconds, return; end
            obj.write(message,varargin{:});
            obj.LastTime = nowSeconds;
        end
        function event(obj,message,varargin)
            if ~obj.Enabled, return; end
            obj.write(message,varargin{:});
        end
        function delete(obj)
            if obj.FileId >= 0, fclose(obj.FileId); obj.FileId = -1; end
        end
    end
    methods (Access=private)
        function write(obj,message,varargin)
            if isempty(varargin), text=char(message); else, text=sprintf(message,varargin{:}); end
            line=sprintf('[%s] %s\n',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),text);
            fprintf('%s',line);
            if obj.FileId>=0, fprintf(obj.FileId,'%s',line); fflush(obj.FileId); end
        end
    end
end
