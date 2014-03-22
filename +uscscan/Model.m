classdef Model < most.Model
%MODEL Model class for the USCScan application
    
    
    %% PUBLIC PROPS
    properties (SetObservable)
        linesPerFrame = 512;
        pixelsPerLine = 512;
        fillFraction = 0.9; %Portion of res scanner angular amplitude used for imaging
        resonantScannerFreq = 7910;
        
        bidirectionalAcq = true;
        
        flybackLinesPerFrame  = 4; %Number of res scanner lines to use for galvo scan flyback
        
        zoomFactor = 1;
        numFrames = 1;
        
        grabNumFrames = 100;    % Number of frames to grab in once cycle in acquisition modes 'grab' or 'loop'
        frameCounter = 0;       % Number of frames acquired
        acqNumRepeats = 100;    % Number of grabs to perform when in acquisition mode 'loop'
        acqRepeatCounter = 0;   % Number of grabs in acquisition mode 'loop'
        loopRepeatPeriod = 10;  % Time in seconds between two loop repeats in software trigger mode
        
        triggerExtTrigAvailable = false;
        triggerTypeExternal = false;
        termSeqTrigIn = '';
        
        periodTriggerPhase = 0; % Delay between Period Trigger and acquisition of line; Can be positive and negative
        
        channelsActive = 1; %Array specifying which channels (numbered 1 to MAX_NUM_CHANNELS) are active for display and logging
        
        multiChannel = false;
        %singleChannelNumber = 1;
        chan1LUT = [-10 100];
        chan2LUT = [-10 100];
        chan3LUT = [-10 100];
        chan4LUT = [-10 100];
        
        
        %Logging properties from SI5.m
        loggingFilePath = '';
        loggingFileStem = '';
        loggingFileCounter = 1;
        loggingFileSubCounter = [];
        loggingEnable = false;
        
        
        %simulated mode
        simulated=false;
    end
    
    properties (SetObservable, Dependent)
        fillFractionTime; %Portion of res scanner half-period used for imaging during each line
        linePeriod_;
        scanFrameRate_;
    end
    
    properties (SetObservable, SetAccess=protected)
        acqState = 'idle'; %One of {'focus' 'grab' 'loop' 'idle'}
        acqMode;
    end
    
    %% HIDDEN PROPS
    
    properties (Hidden)
        hAcq; %Handle to FPGA-based acquisition module
        hScan; %Handle to scanner control unit (res scanner & galvo control)
        mask = [];
        
        hFigs = [-1 -1 -1 -1];
        hAxes = [-1 -1 -1 -1];
        hImages = [-1 -1 -1 -1]; % handles for images coming in from scanner.
        
        hLoopRepeatTimer;
    end
    
    properties (SetAccess=protected)
        triggerClockTimeFirst; %Time of first trigger of current acquisition (first Repeat in case of LOOP). For slice acquisitions, only trigger time for first slice is recorded.
        %triggerTime; %Last time at which triggers arrived during GRAB or LOOP, relative to first triggerFrameStartTime. For slice acquisitions, only trigger time for first slice is recorded.
        %triggerFrameStartTime; %Last time at which triggered acquisition actually started during GRAB or LOOP , relative to first triggerFrameStartTime. First entry is always time 0. For slice cquisitions, only trigger time for first slice is recorded.
        %triggerFrameNumber; %First frame acquired in currently logged file (if any). Value is updated at each start or next trigger.
    end

    properties (Constant, Hidden)
       MAX_NUM_CHANNELS = 4;
       LOOP_TIMER_PERIOD = 1;
       %triggerHeaderProps = {'triggerClockTimeFirst' 'triggerTime' 'triggerFrameStartTime' 'triggerFrameNumber'};
    end
    
    %% CONSTRUCTOR ETC
    methods
        
        function obj = Model()
            %Open FPGA acquisition adapter
            obj.hAcq  = uscscan.adapters.ResonantAcq(obj.simulated);
            
            %Open scanner control adapter
            obj.hScan = uscscan.adapters.ResScanBoxCtrl(obj.simulated);
            obj.termSeqTrigIn = obj.hScan.termSeqTrigIn;
            obj.triggerExtTrigAvailable = ~isempty(obj.hScan.termSeqTrigIn);
 
            %Set the park angle to what is set in the defaults.
            
            %Register the callback with the scanner controller.
            obj.hAcq.frameAcquiredFcn = @(src,evnt)obj.zzzFrameAcquiredFcn;
            
            %Initialize the figure/image objects
            for i = 1:obj.MAX_NUM_CHANNELS
                obj.hFigs(i) = figure();
                obj.hImages(i) = imagesc(rand(512,512));
                obj.hAxes(i) = get(obj.hImages(i),'Parent');
                colormap(gray);
            end
            
            obj.hLoopRepeatTimer = timer('BusyMode','drop',...
                                  'ExecutionMode','fixedRate',...
                                  'StartDelay',obj.LOOP_TIMER_PERIOD, ...
                                  'Period',obj.LOOP_TIMER_PERIOD, ...
                                  'TimerFcn',@obj.zzzLoopTimerFcn);            

            
            %Self-initialize
            mc = metaclass(obj);
            mps = mc.PropertyList;
            for i=1:length(mps)
                mp = mps(i);
                if isequal(mp.GetAccess,'public') && isequal(mp.SetAccess,'public') && ~mp.Dependent
                    obj.(mp.Name) = obj.(mp.Name);
                end
            end
            
            

            
        end
        
        function delete(obj)
            %Close FPGA acquisition adapter
            if ~isempty(obj.hAcq) && isvalid(obj.hAcq)
                  obj.hAcq.delete();

            end
            
            %Close scanner control adapter
            if ~isempty(obj.hAcq) && isvalid(obj.hAcq)
                  obj.hScan.delete();
            end 
            
            delete(obj.hLoopRepeatTimer);
        end     
    end
    
    %% PUBLIC METHODS
    methods 
        function startFocus(obj)
            %Set the image figure axes limits
            obj.zzzSetImageFigureAxesLimits();
            
            %Set acquisition mode in modules
            obj.hAcq.acquisitionMode = 'focus';
            obj.hScan.acquisitionMode = 'focus';
            
            obj.frameCounter = 0;
            obj.acqRepeatCounter = 0;

            %TODO: Handle 'calibrate frequency' outside of startFocus()
            %obj.hScan.resonantScannerActivate(true);
            %obj.hScan.resonantScannerWaitFreqSettle();
            %resFreq = obj.hScan.calibrateResonantScannerFreq();
            %obj.resonantScannerFreq = resFreq;
            %obj.hAcq.scannerFrequency = resFreq;
            %obj.periodTriggerPhase = obj.hAcq.estimatedPhaseTriggerDelay;
            %fprintf('Scanner Frequency calibrated: %fHz\n',resFreq);
            
            obj.hAcq.start();
            obj.hScan.start();
            
            obj.acqMode = 'focus';
            obj.acqState = 'focus';
        end
        
        function startGrab(obj)
            %Set acquisition mode in modules
            obj.hAcq.acquisitionMode = 'grab';
            obj.hScan.acquisitionMode = 'grab';
            
            obj.acqMode = 'grab';
            obj.acqState = 'grab';
            zzzStartAcquisitionMode(obj);
        end
        
        function startLoop(obj)            
            %Set the image figure axes limits
%             obj.zzzSetImageFigureAxesLimits();
            
            %Set acquisition mode in modules
            obj.hAcq.acquisitionMode = 'loop';
            obj.hScan.acquisitionMode = 'loop';
            
            obj.acqMode = 'loop';
            obj.acqState = 'loop';
            zzzStartAcquisitionMode(obj);

        end
        
        function abort(obj)
            obj.zzzStopAcquisition();
        end
        
    end
    
    %% HIDDEN METHODS
    methods (Hidden)
        function zzzSetImageFigureAxesLimits(obj)
            hImages_ = obj.hImages(obj.channelsActive);
            for i=1:numel(obj.channelsActive)
                figure(obj.hFigs(obj.channelsActive(i)));
            end
            
            for i=1:numel(hImages_)
                hAx = get(hImages_(i),'Parent');
                set(hAx,    'XLim',[1 obj.pixelsPerLine],...
                    'YLim',[1 obj.linesPerFrame + obj.flybackLinesPerFrame]);
                
                set(hImages_(i),'CData',zeros(obj.linesPerFrame+obj.flybackLinesPerFrame,obj.pixelsPerLine));
            end
        end
        
        
        function zzzStartAcquisitionMode(obj)
            %Common code for starting GRAB and LOOP modes
             
            obj.acqRepeatCounter = 0;
            %Set the image figure axes limits
            obj.zzzSetImageFigureAxesLimits();
                        
            if obj.triggerTypeExternal
               obj.hScan.sequenceTriggerType = 'external';
            else
               obj.hScan.sequenceTriggerType = 'internal';
            end
            
            if obj.loggingEnable %&& obj.stackSlicesDone == 0 (TODO)
                %obj.hLSM.loggingFileName = obj.loggingFullFileName;
                obj.triggerClockTimeFirst = datestr(datenum(clock()),'dd-mm-yyyy HH:MM:SS.FFF');
                obj.hAcq.loggingHeaderString = obj.modelGetHeader();
                %startLogging(obj.hLSM,obj.loggingFrameDelay);
            end
            
            %TODO: Handle 'calibrate frequency' outside of startFocus()
            %obj.hScan.resonantScannerActivate(true);
            %obj.hScan.resonantScannerWaitFreqSettle();
            %resFreq = obj.hScan.calibrateResonantScannerFreq();
            %obj.resonantScannerFreq = resFreq;
            %obj.hAcq.scannerFrequency = resFreq;
            %obj.periodTriggerPhase = obj.hAcq.estimatedPhaseTriggerDelay;
            %fprintf('Scanner Frequency calibrated: %fHz\n',resFreq);
                   
            obj.zzzStartAcquisition();
        end
        
        function zzzStartAcquisition(obj)
            %Common code for start GRAB and individual LOOP Repeat          
            obj.acqState = obj.acqMode;
            fprintf('acquisition Mode: %s',obj.acqMode);
            
            obj.frameCounter = 0;

            obj.hAcq.grabNFrames = obj.grabNumFrames;
            obj.hScan.grabNFrames = obj.grabNumFrames;
            
            if ~isempty(obj.loggingFileSubCounter)
                obj.loggingFileSubCounter = 1;
            end
            
            
            %Start Loop Repeat timer
            if isequal(obj.acqMode,'loop') && ~obj.triggerTypeExternal
                start(obj.hLoopRepeatTimer);
            end
            
            %Start acquisition & scanning
            obj.hAcq.start();
            obj.hScan.start();                           
            
        end
        
        function zzzStopAcquisition(obj)
            
            obj.hAcq.stop();
            obj.hScan.stop();
            
            obj.acqState = 'idle';
                        
        end
        
        
        function zzzEndAcquisition(obj)
            %Handle end of GRAB or LOOP Repeat
            
            %Update logging file counters for next acquisition
            if obj.loggingEnable
                obj.loggingFileCounter = obj.loggingFileCounter + 1;
                
                if ~isempty(obj.loggingFileSubCounter)
                    obj.loggingFileSubCounter = 1;
                end
            end

            %Stop acq (Do we need to do this for end of LOOP Repeats?)
            obj.zzzStopAcquisition();
            
            %For Loop, restart or re-arm acquisition
            if isequal(obj.acqMode,'loop') && obj.acqRepeatCounter < obj.acqNumRepeats
                disp('rearming')
                if obj.triggerTypeExternal %Re-arm
                    obj.zzzStartAcquisition();
                else
                    obj.acqState = 'loop_wait';
                end
            end
        end
            
       
        function frame = data2frame(obj, data)
           frame = reshape(data,obj.pixelsPerLine,obj.linesPerFrame)';
        end
        
        
        
        function estimatedPhase = zzzEstimatePeriodTriggerPhase(obj,updatehAcq)
            if nargin < 2 || isempty(updatehAcq)
               updateAcq = true; 
            end
            
            empiricalVolts = [4.950000,3.96,3,2.475000,1.650000,1.237500,0.990000,0.825000,0.707143,0.618750,0.550000];
            empiricalPixelsPerLine = [256 512 1024 2048];
            empiricalPhase =  [    44    56    78    97   128   141   153   158   165   168   170
                                   47    59    81    98   129   144   155   162   168   170   175
                                   47    60    83   101   132   147   157   163   170   174   175
                                   47    60    83   101   133   149   157   167   174   175   177];
            %surf(empiricalVolts,empiricalPixelsPerLine,empiricalPhase)
            
            estimatedPhase = interp2(empiricalVolts,empiricalPixelsPerLine,empiricalPhase,...
                    obj.hScan.resonantScannerRangeVolts,obj.pixelsPerLine,'linear',-1);
            
            if estimatedPhase < 0
                % no empirical data in this range
                return
            end
                
            if strcmp(obj.hAcq.flexRioAdapterModule,'NI5734')
                estimatedPhase = round(estimatedPhase * 120/80); % Todo: this is a workaround to support the NI5734 adapter module. Verify that this makes sense
            else
                estimatedPhase = round(estimatedPhase);
            end
            
            if updateAcq
                obj.periodTriggerPhase = estimatedPhase;
            end
        end

    end
    
    %Callbacks
    methods (Hidden)
        function zzzFrameAcquiredFcn(obj,src,evnt)            
            if ~obj.hAcq.acqRunning
                return;
            end
            
            frame = struct();
            frameData = obj.hAcq.readFrame(); 
            assert(~isempty(frameData),'Got empty frame data');
            
            obj.frameCounter = obj.frameCounter + 1;
            
            %display the frame
            % fprintf('displaying frame #%u\n',obj.frameCounter);
            for i = 1:length(obj.channelsActive);
                chan = obj.channelsActive(i);
                set(obj.hImages(chan),'CData',frameData{i});
            end            
            
            if ~strcmp(obj.acqState,'focus') && obj.frameCounter >= obj.grabNumFrames
                disp('stopping');
                obj.acqRepeatCounter = obj.acqRepeatCounter + 1;
                obj.zzzEndAcquisition();
            end
            
        end
        
        
        function zzzLoopTimerFcn(obj,src,evnt)            
            
            if src.TasksExecuted == src.TasksToExecute
                stop(src);
                obj.zzzStartAcquisition();                                            
                
                %TODO: Reset timer countdown property
            else
                %TODO: Implement timer countdown property
            end                        
        end        
        
    end
    
    %% PROP ACCESS METHODS
    methods       
        
        
        
        % ************************************************
        % Acquisition properties
        % ************************************************
        
        function set.acqState(obj,val)
            assert(ismember(val,{'idle' 'focus' 'grab' 'loop'}));
            obj.acqState = val;
                 
            
        end
        
        function set.bidirectionalAcq(obj,val)
            val = obj.validatePropArg('bidirectionalAcq',val);
            obj.bidirectionalAcq = (val == 1);
            
            %Side-effects    
            obj.zprpSetAcqAndScanParameters;
        end
        
        
        function set.pixelsPerLine(obj,val)
            val = obj.validatePropArg('pixelsPerLine',val);
            obj.pixelsPerLine = val;

            
            % in acquisition mode focus a change of pixelsPerLine should
            % stop the acquisition, change the parameter and restart
            rearmFocus = false;
            if strcmp(obj.acqState,'focus')
                obj.abort();
                rearmFocus = true;
            end
            
            %Side-effects
            obj.hAcq.pixelsPerLine = val;
            obj.zzzEstimatePeriodTriggerPhase();
            
            if rearmFocus
                obj.startFocus();
            end
        end
        
        function set.fillFraction(obj,val)
            val = obj.validatePropArg('fillFraction',val);
            obj.fillFraction = val;

            %Side-effects
            obj.hAcq.fillFraction = val;
            obj.zprpSetAcqAndScanParameters();
        end
        
        function value = get.fillFraction(obj)
           value = obj.fillFraction; 
        end
        
        function value = get.fillFractionTime(obj)
            %TODO: Actually compute this correctly
           value = obj.fillFraction * (0.66/0.8); %Apply approximate multiplier for now
        end
        
        function set.fillFractionTime(obj,val)
            val = obj.validatePropArg('fillFractionTime',val);
            %TODO: Actually compute this correctly
            obj.fillFraction = val / (0.66/0.8); %Apply approximate multiplier for now
        end
        
        function val = get.linePeriod_(obj)
           val = 1e6/obj.resonantScannerFreq; %line Period in us
        end
        
        function set.linePeriod_(obj,val)
            obj.mdlDummySetProp(val,'linePeriod_');   
        end
        
        function val = get.scanFrameRate_(obj)
            val = obj.resonantScannerFreq*(2^obj.bidirectionalAcq)/(obj.linesPerFrame+obj.flybackLinesPerFrame);
        end
        
        function set.scanFrameRate_(obj,val)
            obj.mdlDummySetProp(val,'scanFrameRate_');   
        end
        
        function set.periodTriggerPhase(obj,val)
            val = obj.validatePropArg('periodTriggerPhase',val);
            obj.periodTriggerPhase = val;
            obj.hAcq.periodTriggerPhase = val;
        end
        
        
        function set.multiChannel(obj,val)
            assert(isequal(obj.acqState,'idle'),'Cannot set single/multichannel mode during active acquisition');
            val = obj.validatePropArg('multiChannel',val);
            obj.multiChannel = val;
            
            %Side effects
            obj.hAcq.multiChannel = val;

            if val %Multi-channel
                if isempty(obj.channelsActive)
                    obj.channelsActive = 1;
                end
                
                %TODO: Make ResonantAcq (hAcq) object respect the
                %channelsActive proprety (for logging etc)
            else
                if ~isempty(obj.channelsActive)
                    obj.channelsActive = obj.channelsActive(1);
                end
                
                obj.hAcq.singleChannelNumber = obj.channelsActive;
            end

        end
        
        %         function set.singleChannelNumber(obj,val)
        %             val = obj.validatePropArg('singleChannelNumber',val);
        %             obj.singleChannelNumber = val;
        %
        %             obj.hAcq.singleChannelNumber = val;
        %         end

        % ************************************************
        % Scanner properties
        % ************************************************     
        function set.linesPerFrame(obj,val)
            val = obj.validatePropArg('linesPerFrame',val);
            
            % in acquisition mode focus a change of linesPerFrame should
            % stop the acquisition, change the parameter and restart
            rearmFocus = false;
            if strcmp(obj.acqState,'focus')
                obj.abort();
                rearmFocus = true;
            end
            
            %Side-effects
            obj.linesPerFrame = val;
            obj.zprpSetAcqAndScanParameters();
            
            if rearmFocus
                obj.startFocus();
            end
            
            
        end

        function set.flybackLinesPerFrame(obj,val)
            val = obj.validatePropArg('flybackLinesPerFrame',val);
            obj.flybackLinesPerFrame = val;

            %Side-effects
            obj.zprpSetAcqAndScanParameters();
        end
        
        function set.grabNumFrames(obj,val)
            val = obj.validatePropArg('grabNumFrames',val);
            obj.grabNumFrames = val;
        end
        
        function set.acqNumRepeats(obj,val)
            val = obj.validatePropArg('acqNumRepeats',val);
            obj.acqNumRepeats = val;
        end           
        
        function set.zoomFactor(obj,val)
            val = obj.validatePropArg('zoomFactor',val);
            obj.zoomFactor = val;

            %Side-effects
            obj.hScan.zoomFactor = val;
            obj.zzzEstimatePeriodTriggerPhase();
        end
        
        function set.numFrames(obj,val)
            val = obj.validatePropArg('numFrames',val);
            obj.numFrames = val;
            % TODO: Ed - what does this do?
        end
        
        % ************************************************
        % Trigger properties
        % ************************************************ 
        function set.termSeqTrigIn(obj,val)
           obj.termSeqTrigIn = val;
           
           %Side-effects
           obj.hScan.termSeqTrigIn = val;
           obj.triggerExtTrigAvailable = obj.triggerExtTrigAvailable;
        end
        
        function set.triggerTypeExternal(obj,val)
            val = obj.validatePropArg('triggerTypeExternal',val);
            obj.triggerTypeExternal = val;
        end
        
        function set.loopRepeatPeriod(obj,val)
            obj.zprpAssetIdleOrFocus();
            val = obj.validatePropArg('loopRepeatPeriod',val);
            obj.loopRepeatPeriod = val;
            
            %Side-effects
            numRepeatPeriods = round(obj.loopRepeatPeriod / obj.LOOP_TIMER_PERIOD);
            set(obj.hLoopRepeatTimer,'TasksToExecute',numRepeatPeriods);            
        end

        % ************************************************
        % Channel Properties
        % ************************************************

        function set.channelsActive(obj,val)
           val = obj.validatePropArg('channelsActive',val);
           assert(numel(val) <= obj.MAX_NUM_CHANNELS,'Exceeded max num channels'); %TODO: cleanup msg
           
           obj.channelsActive = val;
           for i = 1:numel(obj.hFigs)
              deactivate = isempty(find(obj.channelsActive==i,1));
              if deactivate
                set(obj.hFigs(i),'visible','off');
              else
                set(obj.hFigs(i),'visible','on');
              end
           end
        end
        
        function set.chan1LUT(obj,val)
            val = obj.validatePropArg('chan1LUT',val);
            obj.chan1LUT = val;
            
            obj.zprpUpdateChanLUT(1,val);
        end
        
        function set.chan2LUT(obj,val)
            val = obj.validatePropArg('chan2LUT',val);
            obj.chan2LUT = val;
            
            obj.zprpUpdateChanLUT(2,val);
        end
        
        function set.chan3LUT(obj,val)
            val = obj.validatePropArg('chan3LUT',val);
            obj.chan3LUT = val;
            
            obj.zprpUpdateChanLUT(3,val);
        end
        
        function set.chan4LUT(obj,val)
            val = obj.validatePropArg('chan4LUT',val);
            obj.chan4LUT = val;
            
            obj.zprpUpdateChanLUT(4,val);
        end
        
        

        % ************************************************
        % Logging Properties
        % ************************************************
        
        function set.loggingFilePath(obj,val)
            val = obj.validatePropArg('loggingFilePath',val);
            obj.loggingFilePath = val;
            
            obj.zprpUpdateLoggingFullFileName;
        end
        
        function set.loggingFileStem(obj,val)
            val = obj.validatePropArg('loggingFileStem',val);
            obj.loggingFileStem = val;

            obj.zprpUpdateLoggingFullFileName();
        end
        
        function set.loggingFileCounter(obj,val)
            val = obj.validatePropArg('loggingFileCounter',val);
            obj.loggingFileCounter = val;

            obj.zprpUpdateLoggingFullFileName;        
        end
        
        function set.loggingFileSubCounter(obj,val)
            val = obj.validatePropArg('loggingFileSubCounter',val);
            obj.loggingFileSubCounter = val;

            obj.zprpUpdateLoggingFullFileName;            
        end
        
        function set.loggingEnable(obj,val)
            val = obj.validatePropArg('loggingEnable',val);
            obj.loggingEnable = val;
            obj.hAcq.loggingEnable = val;
        end
        
    end
    
    %Prop-set helpers
    methods (Hidden)
        
        function zprpAssetIdleOrFocus(obj,propname)
            assert(ismember(obj.acqState,{'idle' 'focus'}),'Cannot set property ''%s'' during active acquisition');            
        end
            
        function zprpSetAcqAndScanParameters(obj, val)
            %Set values in hScan & hAcq objects.
            
            %Compute/set line-per-frame values
            obj.hAcq.bidirectional = obj.bidirectionalAcq;
            obj.hAcq.pixelsPerLine = obj.pixelsPerLine;
            obj.hAcq.linesPerFrame =  obj.linesPerFrame + obj.flybackLinesPerFrame;
            obj.hAcq.fillFraction = obj.fillFraction;
            obj.hScan.periodsPerFrame = obj.linesPerFrame / 2^(obj.bidirectionalAcq);
            obj.hScan.galvoFlyBackPeriods = obj.flybackLinesPerFrame / 2^(obj.bidirectionalAcq);
            obj.hScan.zoomFactor = obj.zoomFactor;
            
        end
        
        function zprpUpdateChanLUT(obj,chanIdx,newVal)
            set(obj.hAxes(chanIdx),'CLim',newVal);
        end
        
        
        function zprpUpdateLoggingFullFileName(obj)
            
            if isempty(obj.loggingFilePath) || isempty(obj.loggingFileStem)
                obj.hAcq.loggingFullFileName = '';
            else
      
                fname = obj.loggingFileStem;
        
                %Append file counters to stem
                fname = [fname '_' sprintf('%03d',obj.loggingFileCounter)];
                                
                if ~isempty(obj.loggingFileSubCounter)
                    fname = [fname '_' sprintf('%03d',obj.loggingFileSubCounter)];
                end
                
                %Construct full name
                obj.hAcq.loggingFullFileName = fullfile(obj.loggingFilePath,[fname '.tif']);
            end
        end
        
        
    end
    
    %% ABSTRACT PROP REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclInitPropAttributes();
        mdlHeaderExcludeProps;
    end    
end

%% LOCAL FUNCTIONS

function s = zlclInitPropAttributes()
%At moment, only application props, not pass-through props, stored here -- we think this is a general rule
%NOTE: These properties are /ordered/..there may even be cases where a property is added here for purpose of ordering, without having /any/ metadata.
%       Properties are initialized/loaded in specified order.
%

s = struct();

s.scanFrameRate_ = struct('DependsOn',{{'resonantScannerFreq' 'bidirectionalAcq' 'linesPerFrame' 'flybackLinesPerFrame'}});
s.linePeriod_ = struct('DependsOn',{{'resonantScannerFreq'}});
s.linesPerFrame = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.pixelsPerLine = struct('Attributes','scalar','Options',2.^(4:11)');
s.fillFraction = struct('Range',[0 1], 'Attributes','scalar');
s.fillFractionTime = struct('Attributes',{{'scalar' 'positive' 'finite'}});
s.bidirectionalAcq = struct('Classes','binaryflex','Attributes','scalar');
s.flybackLinesPerFrame = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.zoomFactor = struct('Attributes',{{'scalar' 'nonnegative' 'finite'}});
s.grabNumFrames = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.numFrames = struct('Attributes',{{'scalar' 'positive' 'finite' 'integer'}});
s.frameCounter = struct('Attributes',{{'scalar' 'nonnegative' 'finite' 'integer'}});
s.acqNumRepeats = struct('Attributes',{{'scalar' 'nonnegative' 'integer'}});
s.acqRepeatCounter = struct('Attributes',{{'scalar' 'nonnegative' 'finite' 'integer'}});
s.channelsActive = struct('Classes','numeric','AllowEmpty',1);
s.multiChannel = struct('Classes','binarylogical','Attributes','scalar');
%s.singleChannelNumber = struct('Attributes','scalar','Options',(1:4)');
s.chan1LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.chan2LUT = struct('Attributes',{{'numel', 2, 'finite'  'integer'}});
s.chan3LUT = struct('Attributes',{{'numel', 2, 'finite'  'integer'}});
s.chan4LUT = struct('Attributes',{{'numel', 2, 'finite'  'integer'}});
s.termSeqTrigIn = struct('Classes','string','AllowEmpty',1);
s.loopRepeatPeriod = struct('Attributes',{{'scalar','positive','integer','finite'}});

s.loggingDir = struct('Classes','string','AllowEmpty',1);
s.loggingFileStem = struct('Classes','string','AllowEmpty',1);
s.loggingFileNumber = struct('Attributes',{{'scalar' 'positive' 'finite'}});
s.loggingFileCounter = struct('Attributes',{{'scalar' 'positive' 'finite'}});
s.loggingFileSubCounter = struct('Attributes',{{'scalar' 'positive' 'finite'}},'AllowEmpty',1);

s.loggingEnable = struct('Classes','binarylogical','Attributes','scalar');

s.triggerExtTrigAvailable = struct('Classes','binarylogical','Attributes','scalar');
s.triggerTypeExternal = struct('Classes','binarylogical','Attributes','scalar');


s.periodTriggerPhase = struct('Attributes',{{'integer','finite','scalar'}},'Range',[-4096 100000]);
end
