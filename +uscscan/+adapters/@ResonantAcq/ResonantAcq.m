classdef ResonantAcq < most.MachineDataFile
    %RESONANTACQ
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)    
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ResonantAcq';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end


    
    
    %% PUBLIC PROPERTIES
    
    % Settable during an active acquisition
    properties                
        singleChannelNumber = 1;    % channel to be displayed in single channel mode
        periodTriggerPhase = 0;     % (TODO: Change this to microseconds) shift image relative to the period Trigger (units = ADC samples, where one ADC sample has a period of 1/acqSampleRate)
        reverseLineRead = false;    % flip the image horizontally    
    end
    
    properties                
        acquisitionMode = 'focus'; % Acquisition Mode. One of {'focus','grab','loop'}
        pixelsPerLine = 512;      % Horizontal frame size
        linesPerFrame = 514;      % Vertical frame size
        bidirectional = true;     % Specifies if the both sweep directions of the resonant scanner produce a line
        fillFraction = 0.8;
        
        grabNFrames = 1;        % Number of frames to be acquired after the Acquisition Trigger. Ignored in acquisition Mode 'focus'
        scannerFrequency = 7910;  % Frequency of the resonant scanner in Hz
        
        multiChannel = true;      % Channels to acquire
        frameTagging = true;     % Activates frame tagging
        
        frameAcquiredFcn;         % Callback function to be executed when a frame is acquired
        
        
        
        debugOutput = true;
        dummyData = false;

        %Logging internal properties
        loggingEnable = false;
        loggingFullFileName;
        loggingOpenModeString = 'wbn';
        loggingHeaderString;
        
        
        acquisitionTriggerIn = '';% Input terminal of the Resonant Scanner Sync signal. Valid Values are one of {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}
        periodTriggerIn = '';     % Input terminal of Acquisition Start Trigger. Valid Values are one of {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}
        
        %simulated mode
        simulated=false;
    end
       
    %Constructor-initialized
    properties (SetAccess = private)
        bitDepth;
        acqSampleRate; %TODO: Remove 'acq' prefix...it's redundant
        acqParaSamplesPerPeriod;

        flexRioAdapterModule;
        framesAcquired = 0;
    end
    
    
    %% HIDDEN PROPERTIES
    
    properties (Hidden, SetAccess = private)
        mask; %Array specifies samples per pixel for each resonant scanner period
        estimatedPhaseTriggerDelay; % delays the start of the acquisition relative to the period trigger to compensate for line fillfraction < 1
        %frameQueueRecordSize; %Size of frame queue record (frame + optional frame tag), in bytes
        frameSizePixels;        %Number of Pixels in one frame (not including frame tag)
        frameSizeBytes;         %Number of Bytes in one frame (frame + optional frame tag)
        frameSizeFifoElements;  %Number of FIFO elements for one frame (frame + optional frame tag)
        tagSizeFifoElements;    %Number of FIFO elements for the tag (0 for frameTagging == 0)
        
        acqRunning = false;
        flagMaskNeedsUpdate = true;   % After startup the mask needs to be updated
        flagResizeAcquisition = true; % After startup the frame copier needs to be initialized
        flagLastResAOWrite;
    end
    
    properties (Dependent, Hidden)
        acqParaLinesPerPeriod;
        acqParaTriggerHoldOff;
        acqParaPreTriggerSamples;
        acqParaPeriodsPerFrame;
        acqParaPeriodsPerGrab;
    end
    
    properties (Hidden, SetAccess = immutable)
        hFpga;
        fpgaFifoNumberSingleChan;
        fpgaFifoNumberMultiChan;
    end
    
    properties (Hidden, Constant)
        ADAPTER_MODULE_MAP = containers.Map({278099318, 278099349},{'NI5732','NI5734'});
        ADAPTER_MODULE_SAMPLING_RATE_MAP = containers.Map({'NI5732','NI5734'},{80e6,120e6});
        ADAPTER_MODULE_TRIGGER_TO_ADC_DELAY = containers.Map({'NI5732','NI5734'},{16,16});
        ADAPTER_MODULE_ADC_BIT_DEPTH = containers.Map({'NI5732','NI5734'},{14,16});
        
        FRAME_TAG_SIZE_BYTES = 8;
        FIFO_ELEMENT_SIZE_BYTES_MULTI_CHAN = 8;
        FIFO_ELEMENT_SIZE_BYTES_SINGLE_CHAN = 2;
        TRIGGER_HEAD_PROPERTIES = {'triggerClockTimeFirst' 'triggerTime' 'triggerFrameStartTime' 'triggerFrameNumber'};
        
        fifoSizeFrames = 16;
        frameQueueCapacity = 16;
    end
    
    %% Lifecycle
    methods
        function obj = ResonantAcq(simulated)
            if nargin < 1 || isempty(simulated)
                obj.simulated = false;
            else
                obj.simulated = simulated;
            end
            
            obj.dispDbgMsg('Initializing Object & Opening FPGA session');
            obj.hFpga = dabs.ni.rio.NiFPGA(obj.mdfData.pathToBitfile);

            if (~obj.simulated)
                obj.hFpga.openSession(obj.mdfData.rioDeviceID);
            end
            
            assert(isprop(obj.hFpga,'fifo_SingleChannelToHostI16') ...
                    && isprop(obj.hFpga,'fifo_MultiChannelToHostU64'),...
                'Expected FIFO objects not found for loaded FPGA module bitfile');
            
            %Hard-Reset FPGA. This brings the FPGA in a known state after an aborted acquisition
            obj.fpgaReset();
            
            if (~obj.simulated)
                obj.fpgaDetectAdapterModule();
            end
            %Store FPGA device FIFO names. The names of the FIFO are parsed
            %from the bitfile, so they can change when the FPGA code is
            %modified. Storing the parameters here enables us to change the
            %names in Matlab without having to recompile the MEXfunction
            obj.fpgaFifoNumberSingleChan = obj.hFpga.fifo_SingleChannelToHostI16.fifoNumber;
            obj.fpgaFifoNumberMultiChan = obj.hFpga.fifo_MultiChannelToHostU64.fifoNumber;          
            
            %Initialize MEX-layer interface
            ResonantAcqMex(obj,'init');
            
            %Get defaults from Machine Data File
            obj.periodTriggerIn = obj.mdfData.periodTriggerIn;
            obj.acquisitionTriggerIn = obj.mdfData.acquisitionTriggerIn;
            obj.scannerFrequency = obj.mdfData.nominalResScanFreq;
        end
        
        function delete(obj)
            if obj.acqRunning
                obj.stop();
            end

            ResonantAcqMex(obj,'delete');
            
            obj.hFpga.delete();            
        end
    end
    
    
    %% Public Methods
    methods
        
        function start(obj)
            obj.dispDbgMsg('Starting Acquisition');

            if (~obj.simulated)
                obj.fpgaCheckAdapterModuleInitialization();
            end
            
            obj.hFpga.AcqEngineDoReset = true;
            obj.fpgaUpdateAcquisitionParameters();

            if (~obj.simulated)
                if obj.flagMaskNeedsUpdate;
                    obj.zprpUpdateMask();
                end
            end
            
            obj.fpgaSelectFifo();
            
            % reset frame counter
            obj.framesAcquired = 0;
            
            %force resize on start (we don't know why, but it fixes shift issue in image)
            if true || obj.flagResizeAcquisition
                obj.zprpResizeAcquisition();
            end
            
            %Start acquisition 
            obj.hFpga.AcqEngineDoArm = true;
            ResonantAcqMex(obj,'startAcq');
            obj.acqRunning = true;
        end
        
        function stop(obj)
            ResonantAcqMex(obj,'stopAcq');

            obj.hFpga.AcqEngineDoReset = true;            

            if (~obj.simulated)
                obj.fpgaStopFifo();
            end
            
            obj.acqRunning = false;
        end
        
        function [frame, tag, elremaining] = readFrame(obj)           
            assert(obj.acqRunning,'Acquisition is not running');
            
            [frame, tag, elremaining] = ResonantAcqMex(obj,'getFrame');
            
            obj.framesAcquired = obj.framesAcquired + 1;
            
%           this is done in the model
%             if strcmp(obj.acquisitionMode,'grab') && obj.framesAcquired >= obj. grabNFrames
%                    obj.stop();
%             end
        end
    end
    
    %% Property Access Methods
    %Dependend Properties
    methods
        function val = get.acqParaPeriodsPerGrab(obj)
            val = obj.acqParaPeriodsPerFrame * obj.grabNFrames;
        end
        
        function val = get.acqParaPeriodsPerFrame(obj)
            val = obj.linesPerFrame / obj.acqParaLinesPerPeriod;
            assert(val == floor(val),'acqParaPeriodsPerFrame must be an integer. Current Value: %f',val);
        end
        
        function val = get.acqParaLinesPerPeriod(obj)
            val = 2^(obj.bidirectional);
        end
        
       function value = get.acqParaTriggerHoldOff(obj)
            holdOff = obj.periodTriggerPhase + obj.estimatedPhaseTriggerDelay;
            if holdOff > 0
                value = holdOff;
            else
                value = 0;
            end
        end
        
        function value = get.acqParaPreTriggerSamples(obj)
            holdOff = obj.periodTriggerPhase + obj.estimatedPhaseTriggerDelay;
            if holdOff < 0
                value = abs(holdOff);
            else
                value = 0;
            end
        end

        function value = get.estimatedPhaseTriggerDelay(obj)
            if (~obj.simulated)
                obj.zzzComputeMask();
            end
            
            absSamplesPerLine = ( obj.acqSampleRate / obj.scannerFrequency ) / 2;
            maskSamplesPerLine = sum(abs(obj.mask)) / (2^obj.bidirectional);
            
            estimatedPhaseTriggerDelay = absSamplesPerLine - maskSamplesPerLine;
            
            
            estimatedPhaseTriggerDelay = estimatedPhaseTriggerDelay +...
                obj.ADAPTER_MODULE_TRIGGER_TO_ADC_DELAY(obj.flexRioAdapterModule);
            value = round(estimatedPhaseTriggerDelay);
        end
    end
    
    
    %% Property Access Methods for Live Acquisition Parameters
    methods
        function set.grabNFrames(obj,val) 
            obj.zprpAssertNotRunning('grabNFrames');
            validateattributes(val,{'numeric'},{'scalar','integer','positive'});
            obj.grabNFrames = val;
        end
        
        function set.acquisitionMode(obj,val)
            %validation
            obj.zprpAssertNotRunning('acquisitionMode');
            assert(ismember(val,{'focus','grab','loop'}),'Cannot set acquisitionMode to ''%s''',val);
            
            %set prop
            obj.acquisitionMode = val;
        end
        
        function set.frameTagging(obj,val)
            %validation
            obj.zprpAssertNotRunning('frameTagging');
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.frameTagging = val;
            %side effects
            obj.flagResizeAcquisition = true;
        end
        
        function set.multiChannel(obj,val)
            %validation
            obj.zprpAssertNotRunning('multiChannel');
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.multiChannel = val;
            %side effects
            obj.flagResizeAcquisition = true;
        end
        
        function set.pixelsPerLine(obj,val)
            %validation
            obj.zprpAssertNotRunning('pixelsPerLine');
            validateattributes(val,{'numeric'},{'positive' 'scalar' 'integer'});
            %set prop
            obj.pixelsPerLine = val;
            %side effects
            obj.flagMaskNeedsUpdate = true;
            obj.flagResizeAcquisition = true;
        end
        
        function set.linesPerFrame(obj,val)
            %validation
            obj.zprpAssertNotRunning('linesPerFrame');
            validateattributes(val,{'numeric'},{'positive' 'scalar' 'integer'});
            %set prop
            obj.linesPerFrame = val;
            %side effects
            obj.flagMaskNeedsUpdate = true;
            obj.flagResizeAcquisition = true;
        end
        
        function set.fillFraction(obj,val)
            %validation
            obj.zprpAssertNotRunning('fillFraction');
            validateattributes(val,{'numeric'},{'positive' 'scalar'});
            %set prop
            obj.fillFraction = val;
            %side effects
            obj.flagMaskNeedsUpdate = true;
        end
        
        function set.bidirectional(obj,val)
            %validation
            obj.zprpAssertNotRunning('bidirectional');
            validateattributes(val,{'logical'},{'scalar'});
            %set prop
            obj.bidirectional = val;
            %side effects
            obj.flagMaskNeedsUpdate = true;
            obj.flagResizeAcquisition = true;
        end
        
        function set.periodTriggerIn(obj,val)
            %validation
            obj.zprpAssertNotRunning('periodTriggerIn');
            %set prop
            obj.periodTriggerIn = val;
        end
        
        function set.acquisitionTriggerIn(obj,val)
            %validation
            obj.zprpAssertNotRunning('acquisitionTriggerIn');
            %set prop
            obj.acquisitionTriggerIn = val;
        end
        
        function set.scannerFrequency(obj,val)
            %validation
            obj.zprpAssertNotRunning('scannerFrequency');
            validateattributes(val,{'numeric'},{'positive' 'finite' 'scalar'});
            %set prop
            obj.scannerFrequency = val;
            %side effects            
            obj.flagMaskNeedsUpdate = true;
        end        
        
        function set.frameAcquiredFcn(obj,val)
            %vaidation
            obj.zprpAssertNotRunning('frameAcquiredFcn');
            if isempty(val)
                val = [];
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end

            %set prop
            obj.frameAcquiredFcn = val;
            %side effects            
            ResonantAcqMex(obj,'registerFrameAcqFcn',val);            
        end
        
        function set.loggingEnable(obj, val)
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.loggingEnable = val;
            obj.flagResizeAcquisition = true;
        end
        
        function set.loggingFullFileName(obj, val)
            obj.loggingFullFileName=val;
            obj.flagResizeAcquisition = true;
        end
        
        function set.loggingOpenModeString(obj, val)
            obj.loggingOpenModeString=val;
            obj.flagResizeAcquisition = true;
        end
        
        function set.loggingHeaderString(obj, val)
            obj.loggingHeaderString=val;
            obj.flagResizeAcquisition = true;
        end
    end
    
    %% Property Access Methods for Live Acquisition Parameters
    methods
        function set.singleChannelNumber(obj,val)
            %validation - channel numbers in Matlab are 1 based {1,2,3,4}
            validateattributes(val,{'numeric'},{'positive' 'finite' 'scalar' 'integer'});
            %set prop
            obj.singleChannelNumber = val;
            %side effects
            obj.fpgaUpdateLiveAcquisitionParameters('singleChannelNumber');
        end
        
        function set.periodTriggerPhase(obj,val)
            %validation
            validateattributes(val,{'numeric'},{'finite' 'scalar' 'integer'});
            %set prop
            obj.periodTriggerPhase = val;
            %side effects
            if obj.flagMaskNeedsUpdate; % this is needed to calculate the estimatedPhaseTriggerDelay
                obj.zprpUpdateMask();
            end
            obj.fpgaUpdateLiveAcquisitionParameters('periodTriggerPhase');
        end
        

       function set.reverseLineRead(obj,val)
            %validation
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.reverseLineRead = val;
            %side effects
            obj.fpgaUpdateLiveAcquisitionParameters('reverseLineRead');
       end  
       
    end
    
    %Property-access helpers
    methods (Hidden)
        function zprpUpdateMask(obj)
            obj.dispDbgMsg('Sending Mask to FPGA');
            % Compute mask and store in obj.mask attribute.
            if (~obj.simulated)
                zzzComputeMask(obj)
            end
            obj.acqParaSamplesPerPeriod = sum(abs(obj.mask));
            obj.fpgaUpdateLiveAcquisitionParameters('periodTriggerPhase');
            %zzzComputeMaskTest(obj)
            
            
            % generate the mask write indices and cast the data to the
            % right datatype
            maskWriteIndices = cast(0:(length(obj.mask)-1),'uint16');
            maskData = cast(obj.mask','int16');
            
            % interleave the indices with the mask data and recast it into
            % a uint32. This is the format the MasktoFPGA FIFO expects
            maskToSend = reshape([maskData;maskWriteIndices],1,[]);
            maskToSend = typecast(maskToSend,'uint32');
            
            try
%                 Element by element write of mask array to FPGA.
%                 for i = 1:length(obj.mask)
%                     obj.hFpga.MaskWriteIndex = i-1;
%                     obj.hFpga.MaskElementData = obj.mask(i);
%                     
%                     obj.hFpga.MaskDoWriteElement = true;
%                 end
                
                % Stream Mask to FPGA with a DMA FIFO
                if (~obj.simulated)
                   obj.hFpga.fifo_MaskToFPGA.write(maskToSend);
                end
                            
                obj.hFpga.AcqParamSamplesPerRecord = obj.acqParaSamplesPerPeriod;
            catch ME
                error('Error sending mask to FPGA device: \n%s',ME.message);
            end
            
            obj.flagMaskNeedsUpdate = false;
        end
        
        function zprpAssertNotRunning(obj,propName)
            assert(~obj.acqRunning,'Cannot set property ''%s'' while acquisition is running',propName);            
        end
       
        function zprpResizeAcquisition(obj)    
            obj.frameSizePixels = obj.pixelsPerLine * obj.linesPerFrame; %not including frame tag

            if obj.multiChannel
                fifoElementSizeBytes = obj.FIFO_ELEMENT_SIZE_BYTES_MULTI_CHAN;
            else
                fifoElementSizeBytes = obj.FIFO_ELEMENT_SIZE_BYTES_SINGLE_CHAN;
            end
            
            obj.tagSizeFifoElements = (obj.FRAME_TAG_SIZE_BYTES / fifoElementSizeBytes) * obj.frameTagging ;
            assert(obj.tagSizeFifoElements == floor(obj.tagSizeFifoElements),'Frame Tag Byte Size must be an integer multiple of FIFO Element Byte Size');
            
            obj.frameSizeFifoElements = obj.frameSizePixels + obj.tagSizeFifoElements;
            obj.frameSizeBytes = obj.frameSizeFifoElements * fifoElementSizeBytes;
            
            if (~obj.simulated)
                %Configure FIFO managed by FPGA interface
                if obj.multiChannel
                    obj.hFpga.fifo_MultiChannelToHostU64.configure(obj.frameSizeFifoElements*obj.fifoSizeFrames);
                    obj.hFpga.fifo_MultiChannelToHostU64.start();
                else
                    obj.hFpga.fifo_SingleChannelToHostI16.configure(obj.frameSizeFifoElements*obj.fifoSizeFrames);
                    obj.hFpga.fifo_SingleChannelToHostI16.start();
                end
            end
                        
            %Configure queue(s) managed by MEX interface
            ResonantAcqMex(obj,'resizeAcquisition');          
            obj.flagResizeAcquisition = false;
        end
    end
    
    %% HIDDEN METHODS
    methods (Hidden)
        
%         function zzzComputeMaskTest(obj)
%             obj.mask = ones(1025);
%             obj.mask(513) = -1;
%         end
        
        function zzzComputeMask(obj)
            scanFreq = obj.scannerFrequency;
            sampRate = obj.acqSampleRate;
            fillFrac = obj.fillFraction;
            ppl = obj.pixelsPerLine;
            
            sampleTimes = linspace(0,1/scanFreq,sampRate/scanFreq);
            
            tFun = @(theta) acos(-2*theta) / (2*pi*scanFreq);
            pixelThetas = linspace(-(1/2),1/2,ppl) * fillFrac;
            pixelTimes = tFun(pixelThetas);
            
            %% Sample to pixel assignments
            
            %Assign first sample to first pixel
            [firstSampleTime,firstSampleIdx] = min(abs(sampleTimes-pixelTimes(1)));
            
            %Keep assigning samples to pixels
            [nextSampleTime, nextSampleIdx] = deal(firstSampleTime,firstSampleIdx);
            sampleAssignments = cell(obj.pixelsPerLine,1);
            while true
                [~, pixelIdx] = min(abs(pixelTimes - nextSampleTime));
                sampleAssignments{pixelIdx} = [sampleAssignments{pixelIdx} nextSampleIdx];
                
                nextSampleIdx = nextSampleIdx + 1;
                nextSampleTime = sampleTimes(nextSampleIdx);
                
                if pixelIdx == obj.pixelsPerLine
                    if length(sampleAssignments{pixelIdx}) == length(sampleAssignments{pixelIdx-1})
                        break;
                    end
                end
            end
            
            %Count the # samples per pixel
            samplesPerPixel = cellfun(@length,sampleAssignments);
            
            %Determine bidirectional 'sample mask'
            samplesToSkip = ((sampRate/scanFreq) - 2*sum(samplesPerPixel))/2;
            if ~(round(samplesToSkip)==samplesToSkip)
                %fprintf('WARNING: Samples to skip not evenly divisible. This may prevent perfect bidirectional alignment, i.e. a half-pixel error.\n');
                samplesToSkip = round(samplesToSkip);
            end
            
            if obj.bidirectional
                obj.mask = [samplesPerPixel;-samplesToSkip;flipud(samplesPerPixel)];
            else
                obj.mask = samplesPerPixel;
            end
            
            % side effect
            obj.zzzComputeEstimatedPhaseTriggerDelay()
        end
        
        function zzzComputeEstimatedPhaseTriggerDelay(obj)  
           absSamplesPerLine = ( obj.acqSampleRate / obj.scannerFrequency ) / 2;
           maskSamplesPerLine = sum(abs(obj.mask)) / (2^obj.bidirectional);
           
           estimatedPhaseTriggerDelay = absSamplesPerLine - maskSamplesPerLine;
           
           
           estimatedPhaseTriggerDelay = estimatedPhaseTriggerDelay +...
                   obj.ADAPTER_MODULE_TRIGGER_TO_ADC_DELAY(obj.flexRioAdapterModule);
           value = round(estimatedPhaseTriggerDelay);
           obj.estimatedPhaseTriggerDelay = value;
        end
    end
    
    %% Private Methods for FPGA Access
    methods (Access = private)
        function fpgaUpdateAcquisitionParameters(obj)
            obj.dispDbgMsg('Updating Acquisition Parameters on FPGA');
            
            switch obj.acquisitionMode
                case 'focus'
                    obj.hFpga.AcqParamRecordsPerSequence = 0;
                case 'grab'
                    obj.hFpga.AcqParamRecordsPerSequence = obj.acqParaPeriodsPerGrab;
                case 'loop'
                    obj.hFpga.AcqParamRecordsPerSequence = obj.acqParaPeriodsPerGrab;
                otherwise
                    assert(false);
            end
            
            % Configure Record Parameters
            obj.hFpga.AcqParamTagEveryNRecords =  obj.acqParaPeriodsPerFrame * obj.frameTagging;
            obj.hFpga.DebugProduceDummyData = obj.dummyData;
            
            % Configure Trigger Lines
            obj.hFpga.RecordTriggerTerminalIn = obj.periodTriggerIn;
            obj.hFpga.SequenceTriggerTerminalIn = obj.acquisitionTriggerIn;

            
            %additionally update the Live Acquisition Parameters
            if (~obj.simulated)
                obj.fpgaUpdateLiveAcquisitionParameters('forceall');
            end
        end

        
        function fpgaUpdateLiveAcquisitionParameters(obj,property)
            if obj.acqRunning || strcmp(property,'forceall')
                obj.dispDbgMsg('Updating FPGA Live Acquisition Parameter: %s',property);
               
                if updateProp('singleChannelNumber')
                        % Decrement because the FPGA channel numbers are
                        % 0-based wheres in Matlab 1-based numbers are used
                        obj.hFpga.AcqParamSelectSingleChannel = obj.singleChannelNumber - 1;
                end
                
                if updateProp('periodTriggerPhase') 
                        obj.hFpga.AcqParamLiveTriggerHoldOff = obj.acqParaTriggerHoldOff;
                        obj.hFpga.AcqParamLivePreTriggerSamples = obj.acqParaPreTriggerSamples;
                end
                
                if updateProp('reverseLineRead') 
                        obj.hFpga.AcqParamLiveReverseLineRead = obj.reverseLineRead;
                end
            end
            
            % Helper function to identify which properties to update
            function tf = updateProp(currentprop)
                tf = strcmp(property,'forceall') || strcmp(property,currentprop);
            end
        end        
        
        function fpgaReset(obj)
            obj.dispDbgMsg('Resetting FPGA');
            if (~obj.simulated)
                obj.hFpga.reset();
                obj.hFpga.run();
            end
            obj.dispDbgMsg('Resetting FPGA completed');
        end
        
        function fpgaCheckAdapterModuleInitialization(obj)
            obj.dispDbgMsg('checking FPGA Adapter Module Initialization');
            timeout = 5;           %timeout in seconds
            pollinginterval = 0.5; %pollinginterval in seconds
            while obj.hFpga.AdapterModuleInitializationDone == 0
                pause(0.5);
                timeout = timeout - pollinginterval;
                if timeout <= 0
                    error('Initialization of adapter module timed out')
                end
            end
            obj.dispDbgMsg('FPGA Adapter Module is initialized');
        end
        
        function fpgaDetectAdapterModule(obj)
            obj.dispDbgMsg('Detecting FlexRIO Adapter Module');
            timeout = 10;           %timeout in seconds
            pollinginterval = 0.5; %pollinginterval in seconds
            while obj.hFpga.AdapterModulePresent == 0
                pause(0.5);
                timeout = timeout - pollinginterval;
                if timeout <= 0
                    error('No FlexRIO Adapter Module installed');
                end
            end
            
            % wait till the adapter module reports it's ID
            while obj.hFpga.AdapterModuleIDInserted == 0
               pause(0.5); 
            end
            
            % get the adapter module name 
            expectedModuleID = obj.hFpga.AdapterModuleIDExpected;
            insertedModuleID = obj.hFpga.AdapterModuleIDInserted;
            
            expectedModuleName = obj.ADAPTER_MODULE_MAP(expectedModuleID);
            if isKey(obj.ADAPTER_MODULE_MAP,insertedModuleID)
                insertedModuleName = obj.ADAPTER_MODULE_MAP(insertedModuleID);
            else
                insertedModuleName = sprintf('Unknown Module ID: %d', insertedModuleID);
            end
            
            %check if right module is installed
            assert(obj.hFpga.AdapterModuleIDMismatch == 0,...
                'Wrong Adapter Module installed. Expected Module: ''%s'', Inserted Module:''%s''',...
                    expectedModuleName,insertedModuleName);
                
            %get the module sampling rate
            obj.acqSampleRate = obj.ADAPTER_MODULE_SAMPLING_RATE_MAP(insertedModuleName);
            obj.bitDepth = obj.ADAPTER_MODULE_ADC_BIT_DEPTH(insertedModuleName);
            obj.flexRioAdapterModule = insertedModuleName;
            
            obj.dispDbgMsg('FlexRIO Adapter Module detected: %s',insertedModuleName);
            obj.dispDbgMsg('FlexRIO Acquisition Sampling Rate: %dHz',obj.acqSampleRate);
        end
        
        function fpgaSelectFifo(obj)
            obj.hFpga.FifoEnableSingleChannel = ~obj.multiChannel;
            obj.hFpga.FifoEnableMultiChannel = obj.multiChannel;
        end
        
        
        function fpgaStopFifo(obj)
            obj.dispDbgMsg('Stopping FIFO');
            if obj.multiChannel
                obj.hFpga.fifo_MultiChannelToHostU64.stop();
            else
                obj.hFpga.fifo_SingleChannelToHostI16.stop();
            end
        end
        
    end
    
    %% Private Methods for Debugging
    methods (Access = private)
        function dispDbgMsg(obj,varargin)
            if obj.debugOutput
                fprintf(horzcat('Class: ',class(obj),': ',varargin{1},'\n'),varargin{2:end});
            end
        end
    end
    
end

