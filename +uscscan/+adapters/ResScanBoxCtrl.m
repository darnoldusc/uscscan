classdef ResScanBoxCtrl < most.MachineDataFile
    %SCANNINGGALVO
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)    
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ResScanBoxCtrl';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end

    properties (SetObservable)
        acquisitionMode = 'focus';         % one of {'focus', 'grab', 'loop'}           
        sequenceTriggerType = 'internal';  % one of {'external', 'internal'}
        grabNFrames = 10;                  % Number of frames to grab in acquisitionMode Grab or Loop
        resonantScannerFreq = 7910;        % the expected frequency of the resonant scanner in Hz. can only be updated while the scanner is idle
        periodsPerFrame = 256;             % the number of periods per frame. can only be updated while the scanner is idle
        galvoFlyBackPeriods = 1;           % the number of scanner periods to fly back the galvo. can only be updated while the scanner is idle
        galvoParkDeg = 0;                   % the position of the galvo when the scanner is inactive in optical degrees
        galvoInvertScanDirection = false;   % specifies if the ramp that controls the Galvo is inverted
        zoomFactor = 1;
        
        resonantScannerFreqSettleTime = 0.5; % [seconds] time to wait for the resonant scanner to reach its desired frequency after an update of the zoomFactor
        termSeqTrigIn = '';
        
        %simulated mode
        simulated=true;
    end
    
    % Live Values - these properties can be updated during an active acquisition
    properties (SetObservable, Hidden, SetAccess = private)
        galvoStartDeg = 0;                  % the position of the galvo at the start of the scan in optical degrees
        galvoEndDeg = 5;                    % the position of the galvo at the end of the scan in optical degrees
        resonantScannerRangeDeg = 0;        % the resonant scanner zoom level in optical degress
    end
    
    properties (Dependent)
        galvoStartVolts;
        galvoEndVolts;                   
        galvoParkVolts;                  
        resonantScannerRangeVolts;
    end
    
    % Internal Parameters
    properties (Dependent, Hidden)
       termFrameClkIntOutput;
       galvoScanDur;
       galvoScanOutputPts;
    end
    
    properties (SetAccess = private, Hidden)
        hDaqSystem;
        hDaqDevice;
        
        hCtrTaskFrameClk;
        hCtrChanFrameClk;
        
        hCtrTaskMeasResPeriod;
        hCtrChanMeasResPeriod;
        
        hAOTaskResonantScannerZoom;
        
        hAOTaskGalvo;
        hAOChanGalvo;
        
        hAOTaskGalvoPark;
        
        acquisitionActive = false;
        rateAOSampClk;
        resScanBoxCtrlInitialized;
        
        resonantScannerActive = false;
        resonantScannerLastUpdate = clock;
        resonantScannerLastWrittenValue;
    end
    
    properties (Access = private)
        forceInternalTrigger = false;
    end
    
    properties (Constant, Access = private)
        initialSeqRecTrigDelay = 0;  % this is hard-coded in the FPGA
    end
    
    
    %% Lifecycle
    methods
        function obj = ResScanBoxCtrl(simulated)
            if nargin < 1 || isempty(simulated)
                obj.simulated=false;
            else
                obj.simulated=simulated;
            end
            
            %Get property values from machineDataFile
            validateattributes(obj.mdfData.daqDevName,{'char'},{'vector','nonempty'});
            validateattributes(obj.mdfData.chanAOGalvo,{'numeric'},{'scalar','nonnegative','nonempty'});
            validateattributes(obj.mdfData.chanAOResonantScannerZoom,{'numeric'},{'scalar','nonnegative','nonempty'});
            validateattributes(obj.mdfData.chanCtrFrameClk,{'numeric'},{'scalar','nonnegative','nonempty'});
            
            validateattributes(obj.mdfData.galvoVoltsPerOpticalDegree,{'numeric'},{'scalar','finite','positive'});
            validateattributes(obj.mdfData.rScanVoltsPerOpticalDegree,{'numeric'},{'scalar','finite','positive'});
            
            validateattributes(obj.mdfData.termRecTrigIn,{'char'},{'vector','nonempty'});
            validateattributes(obj.mdfData.nominalResScanFreq,{'numeric'},{'scalar','positive'});
            obj.resonantScannerFreq = obj.mdfData.nominalResScanFreq; % set default value
            
            %Optional properties
            validateattributes(obj.mdfData.termSeqTrigIn,{'char'},{});
            obj.termSeqTrigIn = obj.mdfData.termSeqTrigIn;
            validateattributes(obj.mdfData.termsSeqTrigOut,{'cell'},{});
            validateattributes(obj.mdfData.termsRecTrigOut,{'cell'},{});
            validateattributes(obj.mdfData.termsFrameClkOut,{'cell'},{});

            if (~obj.simulated)
                obj.initializeTasks();
            end
        end
        
        function delete(obj)
            try
                if obj.acquisitionActive
                    obj.stop();
                end

                % clear DAQmx buffered Tasks
                obj.hCtrTaskFrameClk.clear();
                obj.hCtrTaskMeasResPeriod.clear();
                obj.hAOTaskGalvo.clear();
                
                % force AO Outputs to 0 Volts
                obj.hAOTaskGalvoPark.writeAnalogData(0);
                obj.hAOTaskResonantScannerZoom.writeAnalogData(0);
                
                % clear unbuffered Tasks
                obj.hAOTaskGalvoPark.clear();
                obj.hAOTaskResonantScannerZoom.clear();

                % disconnect static routes
                obj.connectTerminals(obj.mdfData.termRecTrigIn,obj.mdfData.termsRecTrigOut,false);
                obj.connectTerminals(obj.termFrameClkIntOutput,obj.mdfData.termsFrameClkOut,false);
            
            catch ME
                obj.hDaqDevice.reset(); % hard reset the device to clear all routes and delete all tasks
                rethrow(ME);
            end
            % no need to delete the singleton hDaqSystem Object
            % no need to delete the hDaqDevice Object
        end
    end
    
    %% Public Methods
    methods        
        function start(obj)
            assert(~obj.acquisitionActive,'Acquisition is already active');      
            
            % Initialize Galvo and Resonant Scanner so they have some time
            % to power up, while the tasks configuration is updated
            if ~obj.galvoInvertScanDirection
                obj.forceGalvoVolts(obj.galvoStartVolts);
            else
                obj.forceGalvoVolts(obj.galvoEndVolts);
            end
              

            obj.resonantScannerActivate(true);
            
            if (~obj.simulated)
                % Reconfigure the Tasks for the selected acquisition Mode
                obj.updateTaskCfg();
                
                %Todo: Is this pause needed for the Resonant Scanner to reach
                %its amplitude and send valid triggers?
                obj.resonantScannerWaitFreqSettle();
                
                % start the tasks. do not change the order of these calls
                obj.hAOTaskGalvo.start();       % Slave Task depends on clock provided by Master
                obj.hCtrTaskFrameClk.start();   % Master Task provides clock for Slave
            end
            
            obj.acquisitionActive = true;  
            
            if (~obj.simulated)
                if obj.forceInternalTrigger || strcmp(obj.sequenceTriggerType,'internal')
                    obj.generateInternalSeqTrig();          % generate Sequence Trigger to Trigger FPGA
                end
            end
        end
        
        function stop(obj)
            if (~obj.simulated)
                obj.hCtrTaskFrameClk.stop();
                obj.hAOTaskGalvo.stop();
                obj.hAOTaskGalvo.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            end
                        
            %Park scanner
            % parkGalvo() has to be called after acquisitionActive is set to
            % false, otherwise we run into an infinite loop
            obj.acquisitionActive = false;
            if (~obj.simulated)
                obj.parkGalvo();
            end
            obj.resonantScannerActivate(false);
            
            % Clean up all routes
            if (strcmp(obj.sequenceTriggerType,'internal') || obj.forceInternalTrigger)...
               && length(obj.mdfData.termsSeqTrigOut) > 1
                obj.connectTerminals(obj.mdfData.termsSeqTrigOut{1},obj.mdfData.termsSeqTrigOut{2:end},false);
            end
            
            if strcmp(obj.sequenceTriggerType,'external')
                obj.connectTerminals(obj.termSeqTrigIn,obj.mdfData.termsSeqTrigOut,false);
            end

        end
        
        function sendSoftwareTrigger(obj)
           assert(obj.acquisitionActive,'Cannot send software trigger during active acquisition');
           assert(strcmp(obj.acquisitionMode,'loop'),'Software Trigger only available when acquisitionMode == Loop');
           assert(strcmp(obj.sequenceTriggerType,'internal'),'Software Trigger can only be generated when Trigger Type = ''internal''');
           if ~isempty(obj.mdfData.termsSeqTrigOut)
               obj.generateInternalSeqTrig(); 
           elseif obj.hCtrTaskFrameClk.isTaskDoneQuiet
               obj.hCtrTaskFrameClk.stop();
               obj.hCtrTaskFrameClk.start();
           end
        end
        
        function resonantScannerFreq = calibrateResonantScannerFreq(obj,averageNumSamples)
           if obj.acquisitionActive
               resonantScannerFreq = NaN; %#ok<NASGU>
               error('Measurement cannot be performed during active acquisition');
           end
           
           if nargin < 2 || isempty(averageNumSamples)
               averageNumSamples = 100;
           end
           
           resonantPeriods = obj.hCtrTaskMeasResPeriod.readCounterData(averageNumSamples,6,averageNumSamples);
           resonantPeriod = mean(resonantPeriods); %ignore the first second of the measurement
           resonantScannerFreq = 1/resonantPeriod;
           obj.resonantScannerFreq = resonantScannerFreq;
        end
        
        function resonantScannerActivate(obj,activate)
           if nargin < 2 || isempty(activate)
               activate = true;
           end
           
           if activate
               obj.resonantScannerActive = true;
               obj.resonantScannerUpdateOutputVolts()
           else
               obj.resonantScannerActive = false;
               obj.resonantScannerUpdateOutputVolts();
           end           
        end
        
        function resonantScannerWaitFreqSettle(obj,settleTime)
            if nargin < 2 || isempty(settleTime)
                settleTime = obj.resonantScannerFreqSettleTime;
            end
            
            timeSinceLastAOUpdate = etime(clock,obj.resonantScannerLastUpdate);
            timeToWait = settleTime-timeSinceLastAOUpdate;
            
            if timeToWait > 0
                fprintf('Waiting %f seconds for resonant scanner to settle\n',timeToWait);
                pause(settleTime-timeSinceLastAOUpdate);
            end
        end
    end
    
    %% Private Methods   
    methods (Access = private)
        function resonantScannerUpdateOutputVolts(obj)
            if obj.resonantScannerActive
                newValue = obj.resonantScannerRangeVolts;
            else
                newValue = 0;
            end
            
            if newValue ~= obj.resonantScannerLastWrittenValue
                obj.resonantScannerLastUpdate = clock;
            end
            
            obj.resonantScannerLastWrittenValue = newValue;

            if (~obj.simulated)
                obj.hAOTaskResonantScannerZoom.writeAnalogData(newValue);
            end
        end
        
        function initializeTasks(obj)
            import dabs.ni.daqmx.*;
 
            try
            % get the singleton DAQmx System Object and a handle to the
            % DAQ-Device
            obj.hDaqSystem = dabs.ni.daqmx.System();
            obj.hDaqDevice = dabs.ni.daqmx.Device(obj.mdfData.daqDevName);
            
            % TODO: For debugging we just close Matlab without calling the
            % deconstructor. This might leave some routes on the device
            % active. To work around this, the device is hard reset here.
            % This should be handled better later.
            sprintf('Hard Resetting device ''%s'' to clear all previously set routes',...
                        obj.mdfData.daqDevName);
            obj.hDaqDevice.reset();
            
            % create Tasks
            obj.hCtrTaskFrameClk = Task('GalvoCtrlFrameClk');
            obj.hAOTaskGalvo = Task('GalvoCtrlGalvoPosition');
            obj.hAOTaskResonantScannerZoom = Task('GalvoCtrlresonantScannerZoomVolts');
            obj.hAOTaskGalvoPark = Task('ParkGalvoCtrlAO');
            obj.hCtrTaskMeasResPeriod = Task('MeasureResonantScannerFreq');
            
            %set up Ctr Task to generate the Frame Clock
            highTicks = 2; % Provide initial values that are overwritten later by obj.updateTaskCfg()
            lowTicks = 2; % minimum value allowed by DAQmx = 2 
            obj.hCtrChanFrameClk = obj.hCtrTaskFrameClk.createCOPulseChanTicks(obj.mdfData.daqDevName,obj.mdfData.chanCtrFrameClk,[],obj.qualifyTermName(obj.mdfData.termRecTrigIn),lowTicks,highTicks,obj.initialSeqRecTrigDelay);
            obj.hCtrChanFrameClk.set('pulseTerm',''); %clear the default output
            obj.connectTerminals(obj.termFrameClkIntOutput,obj.mdfData.termsFrameClkOut); %connect the frame clock output to the specified terminals
            % The remaining configuration depends on obj.acquisitionMode and is updated in obj.updateTaskCfg()
            

            %set up Ctr Task to measure the period of the Resonant Scanner
            %this is the same counter channel as the counter for the frame
            % clock, so it can only be run while the acquisition is not active
            obj.hCtrChanMeasResPeriod = obj.hCtrTaskMeasResPeriod.createCIPeriodChan(obj.mdfData.daqDevName,obj.mdfData.chanCtrFrameClk);
            obj.hCtrChanMeasResPeriod.set('periodTerm',obj.qualifyTermName(obj.mdfData.termRecTrigIn));
            

            %set up buffered AO Task to control the Galvo Scan
            obj.hAOChanGalvo = obj.hAOTaskGalvo.createAOVoltageChan(obj.mdfData.daqDevName,obj.mdfData.chanAOGalvo);
            obj.rateAOSampClk = obj.hAOTaskGalvo.get('sampClkMaxRate');
            obj.hAOTaskGalvo.cfgSampClkTiming(obj.rateAOSampClk,'DAQmx_Val_FiniteSamps',length(obj.galvoScanOutputPts));
            obj.hAOTaskGalvo.cfgDigEdgeStartTrig(obj.termFrameClkIntOutput);
            obj.hAOTaskGalvo.set('startTrigRetriggerable',1);
            
            %set up unbuffered Task to move the Galvo to a given position
            obj.hAOTaskGalvoPark.createAOVoltageChan(obj.mdfData.daqDevName,obj.mdfData.chanAOGalvo);
            obj.parkGalvo();
            
            %set up unbuffered Task to set the resonant scanner zoom level
            obj.hAOTaskResonantScannerZoom.createAOVoltageChan(obj.mdfData.daqDevName,obj.mdfData.chanAOResonantScannerZoom);
            obj.resonantScannerActivate(false); % set output to zero
            
            % pass record trigger to specified terminals - this is a route
            % that persists till the object is deleted
            obj.connectTerminals(obj.mdfData.termRecTrigIn,obj.mdfData.termsRecTrigOut);            
            
            catch ME
                obj.hDaqDevice.reset(); %clear all routes
                delete(obj)
                rethrow(ME);
            end
            
            obj.resScanBoxCtrlInitialized = true;
        end
             
        function updateTaskCfg(obj)
            %make sure both tasks are stopped
            obj.hCtrTaskFrameClk.stop();
            obj.hAOTaskGalvo.stop();
            
            switch obj.acquisitionMode
                case 'focus'
                    obj.hCtrTaskFrameClk.cfgImplicitTiming('DAQmx_Val_ContSamps');
                    obj.hCtrTaskFrameClk.set('startTrigRetriggerable',0);
                    obj.forceInternalTrigger = true;
                case 'grab' 
                    obj.hCtrTaskFrameClk.cfgImplicitTiming('DAQmx_Val_FiniteSamps',obj.grabNFrames);
                    obj.hCtrTaskFrameClk.set('startTrigRetriggerable',0);
                    obj.forceInternalTrigger = false;
                case 'loop'
                    obj.hCtrTaskFrameClk.cfgImplicitTiming('DAQmx_Val_FiniteSamps',obj.grabNFrames);
                    obj.hCtrTaskFrameClk.set('startTrigRetriggerable',1);
                    obj.forceInternalTrigger = false;
                otherwise
                    assert('false');
            end
            
            
            if strcmp(obj.sequenceTriggerType,'internal') || obj.forceInternalTrigger
                if isempty(obj.mdfData.termsSeqTrigOut) % if there is no trigger output, don't bother triggering, just start the acquisition
                    obj.hCtrTaskFrameClk.disableStartTrig;
                else
                    trigTerm = obj.qualifyTermName(obj.mdfData.termsSeqTrigOut{1});
                    obj.hCtrTaskFrameClk.cfgDigEdgeStartTrig(trigTerm);
                    if length(obj.mdfData.termsSeqTrigOut) > 1 % fan out the seq trigger to all specified outputs
                        obj.connectTerminals(obj.mdfData.termsSeqTrigOut{1},obj.mdfData.termsSeqTrigOut{2:end});
                    end
                end    
            elseif strcmp(obj.sequenceTriggerType,'external')
                trigTerm = obj.qualifyTermName(obj.termSeqTrigIn);
                obj.hCtrTaskFrameClk.cfgDigEdgeStartTrig(trigTerm);
                obj.connectTerminals(obj.termSeqTrigIn,obj.mdfData.termsSeqTrigOut);
            else
                assert(false);
            end
            

            highTicks = 2; %highTicks has to be at least 2
            lowTicks = obj.periodsPerFrame + obj.galvoFlyBackPeriods - highTicks;
            
            obj.hCtrChanFrameClk.set('pulseLowTicks', lowTicks);
            obj.hCtrChanFrameClk.set('pulseHighTicks', highTicks);
            obj.hCtrChanFrameClk.set('pulseTicksInitialDelay', obj.initialSeqRecTrigDelay);
            
            galvoScanOutputPoints_ = obj.galvoScanOutputPts;
            obj.hAOTaskGalvo.set('sampQuantSampPerChan',length(galvoScanOutputPoints_));
            obj.hAOTaskGalvo.set('bufOutputBufSize',length(galvoScanOutputPoints_));
            obj.hAOTaskGalvo.writeAnalogData(galvoScanOutputPoints_);
        end
        
        function updateLiveValues(obj)
            if (~obj.simulated)
                if obj.acquisitionActive
                    try
                        obj.hAOTaskGalvo.writeAnalogData(obj.galvoScanOutputPts);
                    catch ME
                        % ignore DAQmx Error 200015 since it is irrelevant here
                        % Error message: "While writing to the buffer during a
                        % regeneration the actual data generated might have
                        % alternated between old data and new data."
                        if isempty(strfind(ME.message, '200015'))
                            rethrow(ME)
                        end
                    end
                else
                    % if the parking position for the Galvo was updated, apply
                    % the new settings.
                    obj.parkGalvo();
                end
            end
        end
        
        function generateInternalSeqTrig(obj)
            if ~isempty(obj.mdfData.termsSeqTrigOut)
                % the ticks of the 20Mhz Timebase are used for the Sequence Trigger
                % so we do not have to create an extra Counter Task just to generate a single pulse
                srcTerm = '20MHzTimebase';
                destTerm = obj.mdfData.termsSeqTrigOut{1};
                obj.connectTerminals(srcTerm,{destTerm});
                pause(0.001); %make sure a few pulses are generated before disconnecting
                obj.connectTerminals(srcTerm,{destTerm},false);
            end
        end
        
        function parkGalvo(obj)
           assert(~obj.acquisitionActive,'Cannot park galvo while scanner is active');
           obj.forceGalvoVolts(obj.galvoParkVolts);
        end
        
        function forceGalvoVolts(obj,value)
            if obj.acquisitionActive
                obj.stop();
            end
            
            if (~obj.simulated)
                obj.hAOTaskGalvoPark.writeAnalogData(value);
            end
        end
        
        function qualifiedTermName = qualifyTermName(obj,termName)
            validateattributes(termName,{'char'},{'vector'});
            
            if isempty(termName)
                qualifiedTermName = '';
            elseif isempty(strfind(termName,'/'))
                qualifiedTermName = sprintf('/%s/%s',obj.mdfData.daqDevName,termName); % e.g. '/PXI1Slot3/PFI1'
            else
                qualifiedTermName = termName;
            end
        end
        
        function connectTerminals(obj,srcTerm,destTerms,connect)
            % srcTerm:   a string specifiying the source e.g. 'PFI0'
            % destTerms: a cell array specifiying the route endpoints e.g.: {'PFI1',PFI2'}
            % connect:   (Optional) if empty or true, the route is
            %               connected, otherwise it is disconnected
            
            if nargin < 4 || isempty(connect)
                connect = true;
            end
            validateattributes(destTerms,{'cell'},{});

            qualSrcTerm = obj.qualifyTermName(srcTerm);
            
            for i = 1:length(destTerms)
                qualDestTerm = obj.qualifyTermName(destTerms{i});
                if connect
                    obj.hDaqSystem.connectTerms(qualSrcTerm,qualDestTerm);
                else
                    obj.hDaqSystem.disconnectTerms(qualSrcTerm,qualDestTerm);
                end
            end
        end     
            
    end
    
    %% Property Access Methods
    methods
        
        function value = get.termFrameClkIntOutput(obj)
            %e.g. '/PXI1Slot3/Ctr0InternalOutput'
            terminal = sprintf('Ctr%uInternalOutput',obj.mdfData.chanCtrFrameClk);
            value = obj.qualifyTermName(terminal);
        end
        
        function dataPoints = get.galvoScanOutputPts(obj)
            
            numDataPointsExact = obj.galvoScanDur*obj.rateAOSampClk;            
            numDataPoints = ceil(numDataPointsExact);
            
            flybackNumPoints = floor(0.75 * obj.galvoFlyBackPeriods * (obj.rateAOSampClk / obj.resonantScannerFreq)); %Flyback ramp spans half of the galvo flyback period                                                                              
            
            voltageRange = [obj.galvoStartVolts obj.galvoEndVolts];
            if obj.galvoInvertScanDirection
                voltageRange = fliplr(voltageRange);
            end
            
            frameDataPoints = linspace(voltageRange(1),voltageRange(2),numDataPoints)';
            flybackDataPoints = linspace(voltageRange(2),voltageRange(1),flybackNumPoints)';
            
            dataPoints = [frameDataPoints; flybackDataPoints];                
              
        end
        
        function value = get.galvoScanDur(obj)
            value = obj.periodsPerFrame/obj.resonantScannerFreq;
        end
    end
    
    %% Property Set Methods
    
   methods
       function set.zoomFactor(obj,value)
           obj.zoomFactor = value;
           
           %side effects
           refAngularRange = obj.mdfData.refAngularRange;
           obj.galvoStartDeg = -( refAngularRange/value ) / 2;
           obj.galvoEndDeg = ( refAngularRange/value ) / 2;
           obj.resonantScannerRangeDeg = refAngularRange / value;
       end
           
       function set.resonantScannerFreq(obj,value)
           assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','resonantScannerFreq');
           obj.resonantScannerFreq = value;
       end
       
       function set.periodsPerFrame(obj,value)
           assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','periodsPerFrame');
           obj.periodsPerFrame = value;
       end

       function set.galvoFlyBackPeriods(obj,value)
           assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','galvoFlyBackPeriods');
           assert(value >= 1,'galvoFlyBackPeriods must be greater or equal to 1');
           obj.galvoFlyBackPeriods = value;
       end
       
       function set.grabNFrames(obj,value)
           assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','grabNFrames');
           obj.grabNFrames = value; 
       end
       
       function value = get.galvoStartVolts(obj)
           value = obj.galvoStartDeg * obj.mdfData.galvoVoltsPerOpticalDegree;
       end
       
       function set.galvoStartVolts(obj,value)
           obj.galvoStartDeg = value / obj.mdfData.galvoVoltsPerOpticalDegree;
       end
       
       function value = get.galvoEndVolts(obj)
           value = obj.galvoEndDeg * obj.mdfData.galvoVoltsPerOpticalDegree;
       end
       
       function set.galvoEndVolts(obj,value)
           obj.galvoEndDeg = value / obj.mdfData.galvoVoltsPerOpticalDegree;
       end
      
      function value = get.galvoParkVolts(obj)
          value = obj.galvoParkDeg * obj.mdfData.galvoVoltsPerOpticalDegree;
      end
      
      function set.galvoParkVolts(obj,value)
          obj.galvoParkDeg = value / obj.mdfData.galvoVoltsPerOpticalDegree;
      end
      
      function set.galvoStartDeg(obj,value)
          obj.galvoStartDeg = value;
          obj.updateLiveValues();
      end
      
      function set.galvoEndDeg(obj,value)
          obj.galvoEndDeg = value;
          obj.updateLiveValues();
      end

      function set.galvoParkDeg(obj,value)
          obj.galvoParkDeg = value;
          obj.updateLiveValues();
      end
      
      function set.galvoInvertScanDirection(obj,value)
          obj.galvoInvertScanDirection = value;
          obj.updateLiveValues();
      end
      
      function value = get.resonantScannerRangeVolts(obj)
         value = obj.resonantScannerRangeDeg * obj.mdfData.rScanVoltsPerOpticalDegree;
      end
      
      function set.resonantScannerRangeVolts(obj,value)
          obj.resonantScannerRangeDeg = value / obj.mdfData.rScanVoltsPerOpticalDegree;
      end
      
      function set.resonantScannerRangeDeg(obj,value)
          obj.resonantScannerRangeDeg = value;
          
          %side effect
          obj.resonantScannerUpdateOutputVolts();
      end
       
       function set.sequenceTriggerType(obj,value)
          assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','sequenceTriggerType');
          assert(ismember(value,{'internal','external'}),'sequenceTriggerType must be one of {''internal'',''external''}');
          if strcmp(value,'external')
              assert(~isempty(obj.termSeqTrigIn),'No External Sequence Trigger Terminal specified');
          end
          obj.sequenceTriggerType = value;
       end
       
       function set.acquisitionMode(obj,value)
          assert(~obj.acquisitionActive,'Cannot change acquisition mode during active acquisition');
          assert(ismember(value,{'focus','grab','loop'}),...
              'acquisitionMode cannot be set to ''%s'' valid values are {''focus'',''grab'',''loop''}',value);
          obj.acquisitionMode = value;
       end
   end
end