classdef Controller < most.Controller
    %CONTROLLER Controller class for the USCScan application
    

    %% ABSTRACT PROPERTY REALIZATIONS (most.Controller)
    properties (SetAccess=protected)
        propBindings = lclInitPropBindings();
    end
    
    properties (Hidden, Dependent)
        mainControlsStatusString;
    end
    
    %% PUBLIC PROPERTIES
    properties
        channelsTargetDisplay; %A value indicating 'active' channel display, or Inf, indicating the merge display figure. If empty, no channel is active.         
    end
      
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        
        function obj = Controller(hModel)
            obj = obj@most.Controller(hModel,...
                {'mainControlsV4' 'imageControlsV4' 'configControlsV4' 'triggerControlsV4' 'channelControlsV5'}, ...
                {'configControlsV4'});
            
            %GUI Initializations
            obj.ziniMainControls();
            obj.ziniConfigControls();
            obj.ziniImageControls();
            %             obj.ziniChannelControls();
            %             obj.ziniPowerControls();
            %             obj.ziniMotorControls();
            %             obj.ziniPosnControls();
            %             obj.ziniFastZControls();
            %             obj.ziniTriggerControls();
            
            obj.ziniFigPositions();
            
            % imageControlsV4.pmTargetFigure
            optionStrings = cell(obj.hModel.MAX_NUM_CHANNELS+2,1);
            optionStrings{1} = 'None';
            for i = 1:obj.hModel.MAX_NUM_CHANNELS
                optionStrings{i+1} = sprintf('Chan %d',i);
            end
            optionStrings{end} = 'Merge';
            set(obj.hGUIData.imageControlsV4.pmTargetFigure,'String',optionStrings);
            set(obj.hGUIData.imageControlsV4.pmTargetFigure,'Value',1);
            

            
            
        end
        
        function initialize(obj)
            
            initialize@most.Controller(obj);
            
        end
        
  
        
        function ziniFigPositions(obj)
            most.gui.setPixelLocation(obj.hGUIs.mainControlsV4,[12 828]);
            %most.gui.setPixelLocation(obj.hGUIs.motorControlsV4,[12 604]);
            %most.gui.setPixelLocation(obj.hGUIs.powerControlsV4,[344 647]);
            most.gui.setPixelLocation(obj.hGUIs.imageControlsV4,[12 137]);
            %most.gui.setPixelLocation(obj.hGUIs.fastZControlsV4,[586 616]);

            setpixelposition(obj.hModel.hFigs(1),[276 156 408 408]);
            setpixelposition(obj.hModel.hFigs(2),[701 156 408 408]);  %Invisible by default
            setpixelposition(obj.hModel.hFigs(3),[1127 156 408 408]);  %Invisible by default
            setpixelposition(obj.hModel.hFigs(4),[928 657 408 408]);  %Invisible by default
            %setpixelposition(obj.hModel.channelsHMergeFig,[970 611 490 490]);  %Invisible by default

        end
        
        
        function ziniMainControls(obj)
            
            %Disable controls for currently unimplemented features
            most.gui.disableAll(obj.hGUIData.mainControlsV4.pnlROIControls);
            
            disabledControls = {'stCycleIteration' 'stCycleIterationOf' 'etIterationsDone' 'etIterationsTotal' 'tbCycleControls' ...
                'stScanRotation' 'scanRotation' 'scanRotationSlider' 'zeroRotate' ...
                'stScanShiftSlow' 'stScanShiftFast' 'scanShiftSlow' 'scanShiftFast' ...
                'xstep' 'ystep' 'left' 'right' 'up' 'down' 'centerOnSelection' 'zero' ...
                'zoomhundredsslider' 'zoomhundreds' ...
                'etScanAngleMultiplierFast' ...
                'pbLastLine' 'pbLastLineParent' ...
                'snapShot' 'numberOfFramesSnap'};
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledControls);
            
            %Disable menu items for currently unimplemented features
            disabledMenuItems = {   'mnu_File_LoadCycle' 'mnu_File_SaveCycle' 'mnu_File_SaveCycleAs' ...
                'mnu_Settings_Beams' 'mnu_Settings_ExportedClocks' ...
                'mnu_View_CycleModeControls' 'mnu_View_ROIControls' 'mnu_View_PosnControls' ...
                'mnu_View_Channel1MaxDisplay' 'mnu_View_Channel2MaxDisplay' 'mnu_View_Channel3MaxDisplay' 'mnu_View_Channel4MaxDisplay'};
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledMenuItems);
            
            %             %Re-purpose 'Align' controls toggle button to Point/Park control
            %             hPointBtn = obj.hGUIData.mainControlsV4.tbShowAlignGUI;
            %             set(hPointBtn,'Value',0);
            %             obj.changedPointButton(hPointBtn);
            %
        end
        
        function ziniConfigControls(obj)
            
            %Hide controls not used in SI5
            hideControls = {'tbShowAdvanced' 'pbApplyConfig'};
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Visible','off'), hideControls);
            
            %Disable controls with features not supported in SI5.1
            disableControls = {'stShutterDelay' 'stShutterDelayMs' 'etShutterDelay'};
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Enable','off'), disableControls);
            
            %Tether default location to Main Controls (can later be overridden by user settings, if desired)
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4, obj.hGUIs.configControlsV4, 'righttop');
            
        end
  
        
        function ziniImageControls(obj)
            
            %Initialize menubars
            set(obj.hGUIData.imageControlsV4.mnu_Settings_AverageSamples,'Enable','off'); %Average samples option not available in SI5
            set(obj.hGUIData.imageControlsV4.mnuPMTOffsets,'Visible','off'); %Hide PMT offsets
            
            %Initialize channel LUT controls
             for i=1:obj.hModel.MAX_NUM_CHANNELS
                 
                 if i > obj.hModel.MAX_NUM_CHANNELS %Disable controls for reduced channel count devices
                     set(findobj(obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i)),'Type','uicontrol'),'Enable','off');
                     
                     set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                     set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                     
                     set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',i)),'String',num2str(0));
                     set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',i)),'String',num2str(0));
                 else
                     %Allow 10-percent of negative range, if applicable
                     chanLUTRange = 2^(obj.hModel.hAcq.bitDepth - 1);
                     set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',-chanLUTRange/10,'Max',chanLUTRange,'SliderStep',[.01 .1]);
                     set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',-chanLUTRange/10,'Max',chanLUTRange,'SliderStep',[.01 .1]);
                 end
             end
            
            %Move Frame Averaging/Selection panel up if there are 2 or less channels
            if obj.hModel.MAX_NUM_CHANNELS <= 2
                
                charShift = (obj.hModel.MAX_NUM_CHANNELS - 2) * 5;
                
                for i=3:obj.hModel.MAX_NUM_CHANNELS
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Visible','off');
                    set(findall(hPnl),'Visible','off');
                end
                
                for i=1:2
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Position',get(hPnl,'Position') + [0 -charShift 0 0]);
                end
                
                %                 hPnl = obj.hGUIData.imageControlsV4.pnlAveragingAndSelection;
                %                 set(hPnl,'Position',get(hPnl,'Position') + [0 charShift 0 0]);
                %
                %                 hPnl = obj.hGUIData.imageControlsV4.pnlImageTools;
                %                 set(hPnl,'Position',get(hPnl,'Position') + [0 charShift 0 0]);
                
                hFig = obj.hGUIs.imageControlsV4;
                set(hFig,'Position',get(hFig,'Position') + [0 charShift 0 -charShift]);
                
            end
        end
        
   
        function delete(obj)

        end
        
    end
    
    %% PROPERTY ACCESS
    methods
        
     
        
        % This sets the GUI-displayed status string, NOT the hModel status
        % string.
        function set.mainControlsStatusString(obj,val)
            set(obj.hGUIData.mainControlsV4.statusString,'String',val);
        end
        
        % This gets the GUI-displayed status string, NOT the hModel status
        % string.
        function val = get.mainControlsStatusString(obj)
            val = get(obj.hGUIData.mainControlsV4.statusString,'String');
        end
        
        
        
    end
    
    %% APP PROPERTY CALLBACKS
    % Methods named changedXXX(src,...) respond to changes to model, which should update the controller/GUI
    % Methods named changeXXX(hObject,...) respond to changes to GUI, which should update the model
    methods
   
        function changedChanLUT(obj,src,evnt)
            %Cycle through and update all chanLUT properties
            for i=1:obj.hModel.MAX_NUM_CHANNELS
                chanProp = sprintf('chan%dLUT',i);
                
                blackVal = obj.hModel.(chanProp)(1);
                whiteVal = obj.hModel.(chanProp)(2);

                set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Value',blackVal);
                set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Value',whiteVal);
                
                set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',i)),'String',num2str(blackVal));
                set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',i)),'String',num2str(whiteVal));
            end
        end
        
        function changeChannelsLUT(obj,src,blackOrWhite,chanIdx)
            %blackOrWhite: 0 if black, 1 if white
            %chanIdx: Index of channel whose LUT value to change
            
            switch get(src,'Style')
                case 'edit'
                    newVal = str2num(get(src,'String'));
                case 'slider'
                    newVal = get(src,'Value');
                    newVal = round(newVal); %Only support integer values, from slider controls
            end
            
            if isempty(newVal) %Erroneous entry
                obj.changedChanLUT(); %refresh View
            else
                chanProp = sprintf('chan%dLUT',chanIdx);
                %Force black level to be less than white level
                if ~blackOrWhite %set black level
                    if newVal >= obj.hModel.(chanProp)(2)
                        newVal = obj.hModel.(chanProp)(2) - 1;
                    end
                else %set white level
                    if newVal <= obj.hModel.(chanProp)(1)
                       newVal = obj.hModel.(chanProp)(1) + 1;
                    end
                end
                
                try
                    obj.hModel.(chanProp)(2^blackOrWhite) = newVal;
                catch ME
                    obj.changedChannelsLUT();
                    obj.updateModelErrorFcn(ME);
                end
            end
            
        end
        
        function changeChannelsActive(obj,chanChgd,value)
                        
            
            if ~obj.hModel.multiChannel %single chan mode
                obj.hModel.channelsActive = chanChgd; %Turn on just the channel that was clicked (don't allow turn-off)
                
            else %multi chan mode
                if value
                    obj.hModel.channelsActive = union(obj.hModel.channelsActive,chanChgd);
                else
                    obj.hModel.channelsActive = setdiff(obj.hModel.channelsActive,chanChgd);
                end

            end
            
            
            %             if ~obj.hModel.multiChannel
            %                 for chanIdx = 1:obj.hModel.MAX_NUM_CHANNELS
            %                     dispChannel = sprintf('cbDisplayChannel%d',chanIdx);
            %                     if chanIdx ~= chanChgd
            %                         % disable all other channels in single channel mode
            %                         set(obj.hGUIData.channelControlsV5.(dispChannel),'Value',0);
            %                     end
            %                 end
            %
            %                 if value == 1
            %                     %obj.hModel.singleChannelNumber = chanChgd;
            %                     obj.hModel.channelsActive = chanChgd;
            %                 else
            %                    obj.hModel.channelsActive = [];
            %                 end
            %             else
            %                 channelsActive = obj.hModel.channelsActive;
            %                 index = find(channelsActive == chanChgd);
            %                 if value == 1 && isempty(index)
            %                     channelsActive = sort([channelsActive chanChgd]);
            %                 elseif value == 0 && ~isempty(index)
            %                     channelsActive(index) = [];
            %                 end
            %                 obj.hModel.channelsActive = channelsActive;
            %             end
        end
        
        function changedChannelsActive(obj,src,evnt)
            
            
            for i=1:obj.hModel.MAX_NUM_CHANNELS
                hCtl = obj.hGUIData.channelControlsV5.(sprintf('cbDisplayChannel%d',i));
                set(hCtl,'Value',ismember(i,obj.hModel.channelsActive));                
            end
            
            %             justChangedChan = sscanf(get(src,'Tag'),'cbDisplayChannel%d');
            %
            %             if ~obj.hModel.multiChannel %single chan mode
            %                 obj.channelsActive = justChangedChan; %Turn on just the channel that was clicked (don't allow turn-off)
            %
            %             else %multi chan mode
            %                 chansActive = [];
            %
            %                 for i=1:obj.hModel.MAX_NUM_CHANNELS
            %                     if obj.hGUIData.channelControlsV5.(sprintf('cbDisplayChannel%d',i))
            %                         chansActive(end+1) = i; %#ok<AGROW>
            %                     end
            %                 end
            %
            %                 obj.channelsActive = chansActive;
            %             end
        end
        
        function changeMultiChannel(obj,multiChanEnable)
            obj.hModel.multiChannel = multiChanEnable;
        end
        
        function changedMultichannel(obj,src,evnt)
            
            hSingleChan = obj.hGUIData.channelControlsV5.tbSingleChannel;
            hMultiChan = obj.hGUIData.channelControlsV5.tbMultiChannel;
            
            if obj.hModel.multiChannel
                set(hMultiChan,'Value',1);
                set(hSingleChan,'Value',0);
            else
                set(hMultiChan,'Value',0);
                set(hSingleChan,'Value',1);
            end
            
            
            
            %             if ~obj.hModel.multiChannel
            %                 set(obj.hGUIData.channelControlsV5.tbMultiChannel,'String','Single Channel');
            %                 for chanIdx = 1:obj.hModel.MAX_NUM_CHANNELS
            %                     dispChannel = sprintf('cbDisplayChannel%d',chanIdx);
            %                     value = 0;
            %                     if chanIdx == obj.hModel.singleChannelNumber
            %                         value = 1;
            %                     end
            %                     set(obj.hGUIData.channelControlsV5.(dispChannel),'Value',value);
            %                 end
            %                 obj.hModel.channelsActive = obj.hModel.singleChannelNumber;
            %             else
            %                 set(obj.hGUIData.channelControlsV5.pbMultiChannel,'String','Multi Channel');
            %             end
        end
        
       
        
        function changedAcqFramesDone(obj,src,evnt)
            switch obj.hModel.acqState
                case 'focus'
                    %do nothing
                otherwise
                    val = obj.hModel.acqFramesDone;
                    set(obj.hGUIData.mainControlsV4.framesDone,'String',num2str(val));
            end
        end
        
        function changedAcqState(obj,src,evnt)
            hFocus = obj.hGUIData.mainControlsV4.focusButton;
            hGrab = obj.hGUIData.mainControlsV4.grabOneButton;
            hLoop = obj.hGUIData.mainControlsV4.startLoopButton;
            switch obj.hModel.acqState
                case 'idle'
                    set(hFocus,'String','FOCUS','Visible','on');
                    set(hGrab,'String','GRAB','Visible','on');
                    set(hLoop,'String','LOOP','Visible','on');
                    
                case 'focus'
                    set([hFocus hGrab hLoop],'Visible','off');
                    set(hFocus,'String','ABORT','Visible','on');
                    
                case 'grab'
                    set([hFocus hGrab hLoop],'Visible','off');
                    set(hGrab,'String','ABORT','Visible','on');
                    
                case {'loop' 'loop_wait'}
                    set([hFocus hGrab hLoop],'Visible','off');
                    set(hLoop,'String','ABORT','Visible','on');
                    
                    %TODO: Maybe add 'error' state??
                    
            end
        end
        
       
        function changedScanAngleMultiplierSlow(obj,~,~)
            
            s = obj.hGUIData.configControlsV4;
            hForceSquareCtls = [s.cbForceSquarePixel s.cbForceSquarePixelation];
            
            if obj.hModel.scanAngleMultiplierSlow == 0
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',1);                
                set(hForceSquareCtls,'Enable','off');
            else
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',0);
                set(hForceSquareCtls,'Enable','on');
            end
        end
              
        function changeScanPhaseStepwise(obj,stepMultiplier,fineStep)            
            if fineStep
                step = 1;
            else
                step = 4;
            end
            obj.hModel.periodTriggerPhase = obj.hModel.periodTriggerPhase + step*stepMultiplier;
        end    
        
        function changedScanFramePeriod(obj,~,~)
            if isnan(obj.hModel.scanFramePeriod)
                set(obj.hGUIData.fastZControlsV4.etFramePeriod,'BackgroundColor',[0.9 0 0]);
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',[0.9 0 0]);
            else
                set(obj.hGUIData.fastZControlsV4.etFramePeriod,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
            end
        end
        
        function changedScanForceSquarePixelation_(obj,~,~)
            if obj.hModel.scanForceSquarePixelation_
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','inactive');
            else
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','on');
            end
        end
        
        function changedScanForceSquarePixel_(obj,~,~)
            if obj.hModel.scanForceSquarePixel_
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','inactive');
            else
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','on');
            end
        end

        
        function changeScanZoomFactor(obj,hObject,absIncrement,lastVal)
            
            %hLSM = obj.hModel.hLSM;
            
            newVal = get(hObject,'Value');
            
            currentZoom = obj.hModel.zoomFactor;
            
            if newVal > lastVal
                newZoom = currentZoom + absIncrement;
                minFieldChange = -1;
            elseif newVal < lastVal
                newZoom = currentZoom - absIncrement;
                minFieldChange = 1;
            else
                assert(false);
            end
            
            obj.hModel.zoomFactor = newZoom;  
        end    
               
        function changedStatusString(obj,~,~)
            % For now, just display the string
            ss = obj.hModel.statusString;
            obj.mainControlsStatusString = ss;
        end
        
    
        
        function changedTriggerExtTrigAvailable(obj,~,~)
            hBtn = obj.hGUIData.mainControlsV4.tbExternalTrig;
            if obj.hModel.triggerExtTrigAvailable
                set(hBtn,'Enable','on');
            else
                set(hBtn,'Enable','off');
            end
        end
        
     
        
        function changeFastZSettlingTimeVar(obj,src,~,~)
            
            val = str2double(get(src,'String'));
            if isnan(val)
                obj.changedFastZSettlingTime();
                return;
            end
            
            try
                switch obj.hModel.fastZScanType
                    case 'sawtooth'
                        obj.hModel.fastZAcquisitionDelay = val;
                    case 'step'
                        obj.hModel.fastZSettlingTime = val;
                    otherwise
                        assert(false);
                end
            catch ME
                obj.changedFastZSettlingTime();
                switch ME.identifier
                    case 'most:InvalidPropVal'
                        % no-op
                    case 'PDEPProp:SetError'
                        throwAsCaller(obj.DException('','ModelUpdateError',ME.message));
                    otherwise
                        ME.rethrow();
                end
            end
            
        end
        
            
        function changedLoggingEnable(obj,~,~)
            
            hAutoSaveCBs = [obj.hGUIData.mainControlsV4.cbAutoSave obj.hGUIData.configControlsV4.cbAutoSave];
            hLoggingControls = [obj.hGUIData.mainControlsV4.baseName obj.hGUIData.mainControlsV4.baseNameLabel ...
                obj.hGUIData.mainControlsV4.fileCounter obj.hGUIData.mainControlsV4.fileCounterLabel];
            
            if obj.hModel.loggingEnable
                set(hAutoSaveCBs,'BackgroundColor',[0 .8 0]);
                set(hLoggingControls,'Enable','on');
            else
                set(hAutoSaveCBs,'BackgroundColor',[1 0 0]);
                set(hLoggingControls,'Enable','off');
            end            
        end
        
        function setSavePath(obj,~,~)
           folder_name = uigetdir(pwd);
           
           if folder_name ~= 0
               obj.hModel.loggingFilePath = folder_name;
           end
        end
    
    end
    
    %% ACTION CALLBACKS
    methods (Hidden)
        
        function showChannelDisplay(obj,channelIdx)
            tag = sprintf('image_channel%d',channelIdx);
            hFig = findobj(obj.hAuxGUIs,'Tag',tag);
            if ~isempty(hFig)
                set(hFig,'Visible','on');
            end
        end
        
        function imageFunction(obj,fcnName)
            
            hFig = obj.zzzSelectImageFigure();
            if isempty(hFig)
                return;
            end
            
            allChannelFigs = obj.hModel.hFigs;
            [tf chanIdx] = ismember(hFig,allChannelFigs);
            if tf
                feval(fcnName,obj.hModel,chanIdx);
            end
            
        end       
             
        function toggleLineScan(obj,src,evnt)
            
            lineScanEnable = get(src,'Value');
            
            if lineScanEnable
                obj.hModel.scanAngleMultiplierSlow = 0;
            else
                obj.hModel.scanParamResetToBase({'scanAngleMultiplierSlow'});
                if obj.hModel.scanAngleMultiplierSlow == 0 %No CFG file, or CFG file has no scanAngleMultiplierSlow value, or Base value=0
                    obj.hModel.scanAngleMultiplierSlow = 1;
                end
            end
            
        end
        
    end
    
    %% CONTROLLER PROPERTY CALLBACKS
    
    methods (Hidden)
        
        function changeChannelsTargetDisplay(obj,src)
            val = get(src,'Value');
            switch val
                case 1 %None selected
                    obj.channelsTargetDisplay = [];
                case obj.hModel.MAX_NUM_CHANNELS + 2
                    obj.channelsTargetDisplay = inf;
                otherwise
                    obj.channelsTargetDisplay = val - 1;
            end
        end
        
    end
    
    
    %% PRIVATE/PROTECTED METHODS
    
    methods (Access=protected)
        
        function hFig = zzzSelectImageFigure(obj)
            %Selects image figure, either from channelsTargetDisplay property or by user-selection
            
            hFig = [];
            
            if isempty(obj.channelsTargetDisplay)
                obj.mainControlsStatusString = 'Select image...';
                chanFigs = obj.hModel.hFigs;
                hFig = most.gui.selectFigure(chanFigs);
                obj.mainControlsStatusString = '';
                % TODO they can select the MERGE figure
            elseif isinf(obj.channelsTargetDisplay)
                %TODO: Handle Merge figure
            else
                hFig = obj.hModel.hFigs(obj.channelsTargetDisplay);
            end
        end
        
    end
    
end

%% LOCAL FUNCTIONS


function v = zlclShortenFilename(v)
assert(ischar(v));
[~,v] = fileparts(v);
end

%helper for changedStackStartEndPositionPower
function zlclEnableUIControlBasedOnVal(hUIC,val,enableOn)
if isnan(val)
    set(hUIC,'Enable','off');
else
    set(hUIC,'Enable',enableOn);
end

end


function propBindings = lclInitPropBindings()

%NOTE: In this prop metadata list, order does NOT matter!
%NOTE: These are properties for which some/all handling of model-view linkage is managed 'automatically' by this class

%TODO: Some native approach for dependent properties could be specified here, to handle straightforward cases where change in one property affects view of another -- these are now handled as 'custom' behavior with 'Callbacks'
%      For example: scanLinePeriodUS value depends on scanMode


s = struct();

%s.acqFramesDone = struct('Callback','changedAcqFramesDone');
s.numFrames = struct('GuiIDs',{{'mainControlsV4','framesTotal'}});
%s.acqNumAveragedFrames = struct('GuiIDs',{{'mainControlsV4','etNumAvgFramesSave'}});

%s.scanAngleMultiplierFast = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierFast'}});
%s.scanAngleMultiplierSlow = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierSlow'}},'Callback','changedScanAngleMultiplierSlow');

s.chan1LUT = struct('Callback','changedChanLUT');
s.chan2LUT = struct('Callback','changedChanLUT');
s.chan3LUT = struct('Callback','changedChanLUT');
s.chan4LUT = struct('Callback','changedChanLUT');

s.zoomFactor = struct('GuiIDs',{{'mainControlsV4' 'pcZoom'}});
s.pixelsPerLine = struct('GuiIDs',{{'configControlsV4','pmPixelsPerLine'}});
s.linesPerFrame = struct('GuiIDs',{{'configControlsV4','etLinesPerFrame'}});
s.linePeriod_ = struct('GuiIDs',{{'configControlsV4','etLinePeriod'}},'ViewScaling',1e6,'ViewPrecision',5);
s.fillFractionTime = struct('GuiIDs',{{'configControlsV4','etFillFrac'}});
s.fillFraction = struct('GuiIDs',{{'configControlsV4','etFillFracSpatial'}},'ViewPrecision','%0.3f');
% s.scanPixelTimeMean = struct('GuiIDs',{{'configControlsV4','etPixelTimeMean'}},'ViewScaling',1e9,'ViewPrecision','%.1f');
% s.scanPixelTimeMaxMinRatio = struct('GuiIDs',{{'configControlsV4','etPixelTimeMaxMinRatio'}},'ViewPrecision','%.1f');
% s.scanForceSquarePixelation = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixelation'}});
% s.scanForceSquarePixel  = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixel'}});
% s.scanForceSquarePixel_ = struct('Callback','changedScanForceSquarePixel_');
% s.scanForceSquarePixelation_ = struct('Callback','changedScanForceSquarePixelation_');

s.bidirectionalAcq = struct('GuiIDs',{{'configControlsV4','cbBidirectionalScan'}});
s.scanFrameRate_ = struct('GuiIDs',{{'configControlsV4','etFrameRate'}},'ViewPrecision','%.2f');
% s.scanFramePeriod = struct('GuiIDs',{{'fastZControlsV4','etFramePeriod'}},'ViewPrecision','%.1f','ViewScaling',1000,'Callback','changedScanFramePeriod');

s.loggingEnable = struct('GuiIDs',{{'mainControlsV4','cbAutoSave','configControlsV4','cbAutoSave'}},'Callback','changedLoggingEnable');
s.loggingFileStem = struct('GuiIDs',{{'mainControlsV4' 'baseName'}});
s.loggingFileCounter = struct('GuiIDs',{{'mainControlsV4' 'fileCounter'}});

% acquisition State
s.frameCounter = struct('GuiIDs',{{'mainControlsV4','framesDone'}});
s.acqRepeatCounter = struct('GuiIDs',{{'mainControlsV4','repeatsDone'}});
s.grabNumFrames = struct('GuiIDs',{{'mainControlsV4','framesTotal'}});
s.acqNumRepeats = struct('GuiIDs',{{'mainControlsV4','repeatsTotal'}});

% s.loggingFramesPerFile = struct('GuiIDs',{{'configControlsV4' 'etFramesPerFile'}});
% s.loggingFramesPerFileLock = struct('GuiIDs',{{'configControlsV4' 'cbFramesPerFileLock'}});

s.acqState = struct('Callback','changedAcqState','GuiIDs',{{'mainControlsV4' 'statusString'}});
s.triggerExtTrigAvailable = struct('Callback','changedTriggerExtTrigAvailable');
s.triggerTypeExternal = struct('GuiIDs',{{'mainControlsV4' 'tbExternalTrig'}});
s.termSeqTrigIn = struct('GuiIDs',{{'triggerControlsV4' 'etStartTrigSrc'}});

s.periodTriggerPhase = struct('GuiIDs',{{'configControlsV4','etScanPhase'}});
s.multiChannel = struct('Callback','changedMultichannel');
s.channelsActive = struct('Callback','changedChannelsActive');
% s.loopNumRepeats = struct('GuiIDs',{{'mainControlsV4','repeatsTotal'}});
s.loopRepeatPeriod = struct('GuiIDs',{{'mainControlsV4','etRepeatPeriod'}});
% s.loopRepeatsDone = struct('GuiIDs',{{'mainControlsV4','repeatsDone'}});
% 
% s.secondsCounter = struct('Callback','changedSecondsCounter');

%s.statusString = struct('Callback','changedStatusString');

%s.frameAcqFcnDecimationFactor = struct('GuiIDs',{{'configControlsV4' 'etFrameAcqFcnDecimationFactor'}});

propBindings = s;

end

