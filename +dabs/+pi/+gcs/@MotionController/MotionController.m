classdef MotionController < most.APIWrapper & most.PDEPProp & dabs.pi.gcs.CoreBasicProperties
    % MOTIONCONTROLLER Abstract class encapsulating functionality of a piezo
    % controller under the Physik Instrumente General Command Set (GCS).
    %
    % The goal of this class is to provide a thin wrapper around PI's GCS (a C 
    % API), in the form of a Matlab class.  As its name implies, the general
    % command set is designed to be an all-encompassing programmatic interface
    % for many PI devices.  However, given different device capabilities, the
    % GCS's generality is not always consistent.  Any deviations or
    % device-specific quirks are documented in the function in which they exist.
    %
    % 
    %% DEVICE PROPERTIES:
    % 
    % All GCS functions consist of a device prefix (e.g. "E816_") that is
    % prepended to the function name. GCS functionality can be broken into three
    % main categories:
    %
    %   1) GCS functions: these are "pure" functions that accept a number of
    %   arguments and perform an atomic action (e.g. E7XX_ConnectRS232()). A 
    %   number of these functions have been mapped to class methods (in which 
    %   case the device prefix is dropped and the first letter of the function
    %   is lower case (e.g. connectRS232()).
    %
    %   2) GCS "system parameters": these are device parameters that are stored
    %   in non-volatile ROM, and loaded to volatile RAM at device startup.  Most
    %   system parameters have been mapped to class properties (using
    %   most.APIWrapper's "pseudo-dependant" property
    %   functionality). In the GCS scheme, system parameters are accessed via
    %   five functions:
    %
    %     a) SPA(): write system parameters to RAM.  
    %       Mapped to writeSystemParametersRAM().
    %
    %     b) qSPA(): read system parameters from RAM. 
    %       Mapped to readSystemParametersRAM().
    %
    %     c) SEP(): write system paramters to ROM.
    %       Not mapped.
    %
    %     d) qSEP(): read system parameters from ROM.
    %       Mapped to readSystemParametersROM().
    %
    %     e) WPA(): copy system parameters from RAM to ROM.
    %       Mapped to writeSystemParametersAll().
    %
    %    While these mappings exist, it is easier (and preferred) to access the
    %    class property mapping directly.  Concrete subclasses inherit these
    %    class properties from dabs.pi.gcs.SystemParameterXXX classes.
    %    Using this scheme, accessing device system properties (in RAM) is 
    %    accomplished by modifying class properties:
    %
    %      objectHandle.positionOne = 22;
    %        or
    %      p2 = objectHandle.positionTwo;   
    %
    %   3) GCS "three-letter" functions.  Some of these represent "actual"
    %   functions (e.g. MOV()), whereas some are abstractions of system
    %   parameters (e.g. AOS()).  Those that represent functions have been
    %   abstracted by class methods: for instance, MOV() is implicitly called by
    %   calling any of the classes moveXXX() methods.  In contrast, those
    %   three-letter functions that abstract system parameters are accessed via
    %   class properties; for instance, AOS() is implicitly called by accessing
    %   objectHandle.analogInputOffset.  See the GCS documentation for further
    %   details.
    %
    %% CREDITS
    %   Created Summer 2010 by Vijay Iyer (HHMI/JFRC) and David Earl (5AM Solutions)
    %
    %% *************************************************************************
    
    %TODO (VI083010): Consider whether several of the API data vars currently defined should better be 'class' data vars, as they are not related to API versions.
    
    
    %% ABSTRACT PROPERTY REALIZATION (most.PDEPProp)
    properties (Constant,Hidden)
        %Pseudo-dependent property handling
        pdepSetErrorStrategy = 'restoreCached'; % <One of {'setEmpty','restoreCached','setErrorHookFcn'}>. setEmpty: stored property value becomes empty when driver set error occurs. restoreCached: restore value from prior to the set action generating error. setErrorHookFcn: The subclass implements its own setErrorHookFcn() to handle set errors in subclass-specific manner.
    end
    
    %% ABSTRACT PROPERTY REALIZATION (most.APIWrapper)
        
    properties (Constant, Hidden)
        apiCachedDataPath = ''; % default        
    end
    
    properties (SetAccess=protected, Hidden)
        %API 'pre-fab' cached data variables
        apiStandardFuncRegExp; % default (n/a)
        apiHasFuncNargoutMap; % default (false)

        apiResponseCodeSuccess = 1;
        apiResponseCodeProcessor; %Default (none)
        
        apiCachedDataVarMap = containers.Map( {'errorNameMap' 'systemParameterNames' 'systemMatrixParameterNames' 'implicitParameterNames'}, ...
                                              {'extractErrorMaps' 'extractSystemParameterNames' 'extractSystemParameterNames' 'extractImplicitParameterNames' }); %TODO: do something with descriptions: 'errorDescriptionMap' 'extractErrorMaps'       
                                          
        apiVersionDetectEnable = false; 
        
        apiHeaderRootPath=''; 
        apiHeaderPathStem; 
        %apiHeaderFinalPaths; % Defer to subclass!
        apiHeaderPlatformPaths = 'standard'; %NOT version-indexed. If supplied, either 'standard' or a 2-element string cell array. Default is 'none'. Specifies 32 & 64-bit subfolders of apiHeaderFinalPaths in which to find platform-specific header files. Value of 'standard' implies: {'win32' 'x64'}.
                   
        apiDLLPaths = 'useApiHeaderPaths';
        apiDLLPlatformPaths; %NOT version-indexed. If supplied, either 'standard' or a 2-element string cell array. Default is 'none'. Specifies 32 & 64-bit subfolders of apiDLLPaths in which to find platform-specific header files. Value of 'standard' implies: {'win32' 'x64'}.

        apiAuxFile1Names = 'picontrollererrors.h'; % File specifying response code meanings. As best as we can tell, this is universal.
        %apiAuxFile1Paths; %Defer to subclass. If empty, error decoding will not occur. Generally: File is not supplied with Dabs, so installing the PI-supplied driver is required to obtain this file and allow error decoding.
        
        apiAuxFile2Names; % default
        apiAuxFile2Paths; % default
    end
    
    
    
    %% ABSTRACT PROPERTIES (to be realized by concrete subclass)
    properties (Abstract, Constant, Hidden)
        controllerType; % Identifies the model of the PI device
        useAxesComponentIndex; %Identifies if controller uses piezo/sensor indexing, rather than axes indexing, into certain properties
        GCSPrefix; % The device-specific prefix appended to GCS function names.
        corePropertyExclusions; %Cell array of those properties in CoreBasicProperties class which should be excluded from display -- i.e. are not valid properties for particular device
    end
    
    
    %% USER PROPERTIES
    
    %Pseudo-dependent device properties
    properties (GetObservable,SetObservable, Hidden)
        %In general, the getError() method should be used instead
        errorCode;                      % qERR (E-517, E-712, E-816).
    end
    
    
    properties (Dependent)
        isMoving; %Logical indicating if piezo is moving (i.e. to reach command target position)
    end
    
    properties (Access=public)
        defaultBaudRate = 115200;
        defaultConnectionType = 'rs232';
        
        moveCompleteTimeout = 15;
        moveAsyncTimeout = 15;
        moveCompletePauseInterval = 0.01;
        
        relativeOrigin=[0 0 0];
    end
    
    %% SUPERUSER PROPERTIES
    
    properties (Dependent, Hidden)
        implicitParameters;
        systemParameters;          
    end
    
    
    %Constants, fudge-factors, etc
    properties (Hidden, SetAccess=protected)
        sensorVoltageRange = 10; %Sensor (output) voltage range corresponding to full range-of-motion
        commandVoltageRange = 10; %Command (input) voltage range corresponding to full range-of-motion
    end
    
    %% DEVELOPER PROPERTIES
    
    % Constructor-initialized
    properties (SetAccess=private)
        controllerID; % every device is assigned a unique ID upon connection.
        
        connectionType; % the connection type to use (one of {'rs232', 'usb', 'ethernet')
        baudRate; % the baudrate to use for RS232 connections.
        comPort; % the COM port to use for RS232 connections.
    end   
    
    
    % Properties to be explicitly initialized on object construction
    properties (SetAccess=protected, Hidden)
        propertyMap; % maintains the mapping between class properties and their GCS equivalents.
        functionMap; % maintains the mapping between class methods and their GCS equivalents.
        systemParameterMap = initSystemParameterMap(); %Map of system parameter pretty names to hex codes
        implicitParamMasterList = initImplicitParamMasterList(); %Master list of those properties which, if present, are also system parameters -- i.e. written to ROM via writeSystemParameters()
        
        asyncMovePending = false; %Flag indicating if an async move is in progress
        asyncMoveTimeReference; %Time reference, obtained via tic(), of start of async move
        
        isConstructed=false; % a global flag indicating if the object has been successfully constructed
        
        customDisplayPropertyList; %List of props to be shown on disp() calls
    end
    
    properties (SetAccess=protected, Hidden)
        axesActive; % a cell array of strings containing the current active device axes.
        axesMap; % maintains a map between axes names and axes indiices
        
        waveTableDataArray; % a struct array maintaining the internal class representation of the device wave table
        waveTableDataArrayMap; % maintains a map between wave generators and wave tables (applicable for E-712).
    end
    
    %% USER EVENTS
    events (NotifyAccess=private)
        moveAsyncCompleteEvent;
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    
    methods
        function obj = MotionController(varargin)
            % Constructs a dabs.pi.MotionController class of the given model.
            %
            % Prop-Value pair args
            % connectionType: <OPTIONAL - Default='rs232'> Specify the connection protocol to use. One of {'rs232' 'usb' 'ethernet'}.
            % comPort: <REQUIRED, if connectionType='rs232'> Number specifiying COM port to which controller is connected
            % baudRate: <OPTIONAL - Default=115200> Specify baud rate to use during communication. Must match that set on hardware.
            
            
            %Call superclass constructors
            obj = obj@most.APIWrapper();
            
            % initialize maps
            obj.initMaps();
            
            argMap = obj.extractPropValArgMap(varargin,{'connectionType' 'comPort' 'baudRate'});
            
            if ~argMap.isKey('connectionType') || isempty(argMap('connectionType'))
                obj.connectionType = obj.defaultConnectionType; %TODO: Consider having default depend on controller type
            else
                obj.connectionType = lower(argMap('connectionType'));
            end
            
            if ~argMap.isKey('comPort') || isempty(argMap('comPort'))
                
                if (strcmp(obj.connectionType,'rs232'))
                    error('A COM port must be specified for RS232 connections.');
                    % TODO: use FindOnRS()?
                end
            else
                obj.comPort = argMap('comPort');
            end
            
            if ~argMap.isKey('baudRate') || isempty(argMap('baudRate'))
                obj.baudRate = obj.defaultBaudRate;
            else
                obj.baudRate = argMap('baudRate');
            end
            
            if strcmp(obj.connectionType,'usb')
                [numDevices deviceIDStrings] = obj.enumerateUSB();
                
                if numDevices <= 0
                    error('No controllers found via USB');
                else
                    obj.controllerID = obj.connectUSB(deviceIDStrings);
                end
            elseif strcmp(obj.connectionType,'rs232')
                obj.controllerID = obj.connectRS232();
            else
                error(['Unknown connection type: ' obj.connectionType]);
            end
            
            if obj.controllerID < 0
                error(['Could not connect to ' obj.controllerType ' via ' obj.connectionType]);
            end
            
            %Initialize properties to start-up defaults
            obj.initializeModelPropValues();
            
            %Set default display properties
            mClass = ?dabs.pi.gcs.CoreBasicProperties;
            for prop=[mClass.Properties{:}]
                propName = prop.Name;
                if ~isempty(findprop(obj,propName)) && ~ismember(propName, obj.corePropertyExclusions)
                    obj.customDisplayPropertyList{end+1} = propName;
                end
            end
            
            %Signal construction completion
            obj.isConstructed = true;
            
        end
        
        function delete(obj)
            
            if ~isempty(obj.controllerID) && obj.controllerID >= 0
                % close the connection to the device
                %obj.GCSCall('closeConnection',true);
                obj.apiCallRaw(obj.GCSFuncName('closeConnection'),obj.controllerID);
            end
        end
        
    end
    
    
    %% PROPERTY ACCESS METHODS
    
    
    % Pseudo-dependent property handling
    methods (Hidden,Access=protected)
        
        function pdepPropHandleGet(obj,src,evnt)
            propName = src.Name;
            
            %The Maps should have all the available properties, so this
            %error condition should never arise. This could be made into
            %assert statemenent. Need to handle the matrixSystemParameters
            %at some point, though, so leave out for now.          
            %             if ~obj.propertyMap.isKey(propName) && ~obj.systemParameterMap.isKey(propName)
            %                 error([propName ' is not supported by the ' obj.controllerType]);
            %             end
            
            %These are the systeme parameters available for /this/ concrete GCS controller class
            systemParams = obj.accessAPIDataVar('systemParameterNames');
            matrixSystemParams = obj.accessAPIDataVar('systemMatrixParameterNames');
            
            switch propName
                case {'commandLevel', 'commandSyntaxVersion', 'recordTableRate', 'numberOfDataRecordChannels' ...
                        'numberOfPiezoChannels', 'numberOfSensorChannels', 'isRunningMacro' 'samplesPerAverage' ...
                        'numberOfdataRecordTables' 'numberOfWaveGenerators'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropSimple,src,evnt);
                    
                case {'channelName'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropSingleChar,src,evnt);
                    
                case {'availableDigitalChannels'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropMultiple,src,evnt);
                    
                case {'driftCompensation', 'homePosition', 'impulse', 'positionCommand', 'positionLowerLimit' ...
                        'onTarget', 'overflowStatus', 'positionUpperLimit' 'position' ...
                        'step' 'voltageCommand' 'servoControlMode' 'positionCommandMin' 'positionCommandMax' ...
                        'velocityControlMode' 'velocity' 'isControllerReady' 'isMovingRaw' 'wasDigitalPulseDetected' ...
                        'analogInputOffset' 'autoZeroDone'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropAxisIndexed,src,evnt);
                    
                case {'upperVoltageLimit' 'lowerVoltageLimit'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropPiezoChannelIndexed,src,evnt);
                    
                case {'controlMode' 'digitalInputState' 'sensorPosition' 'adValue'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropSensorChannelIndexed,src,evnt);
                    
                case {'waveGeneratorOffset' 'waveTableSelection'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropWaveGeneratorIndexed,src,evnt);
                    
                case {'helpStringDataRecording' ...
                        'identificationString' 'validAxisChars' 'version'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropString,src,evnt);
                    
                case {'helpString' 'helpStringAvailableParams'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropStringLong,src,evnt);
                    
                case {'availableMacros' 'interfaceConfig' 'interfaceConfigStore'} %TODO: probably move these somewhere else...
                    obj.pdepPropGroupedGet(@obj.getGCSPropOptionedString,src,evnt);
                    
                case { 'axesNames' 'axesNamesAll'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropAxesNames,src,evnt);
                    
                case {'waveGeneratorCycles'}
                    obj.pdepPropGroupedGet(@obj.getGCSPropWaveGeneratorIndexed,src,evnt);
                    
                case { 'autoCalibrationOptions' 'autoCalibrationResults' 'dataRecordTables' ...
                        'triggerOutputConditions' 'dataRecorderConfig' 'I2CState' 'waveTablePoints' 'waveTableData' ...
                        'waveGeneratorTableRate' 'isWaveGeneratorRunning' 'errorCode' 'voltageActual' 'serialNumber' 'rs232BaudRate'}
                    obj.pdepPropIndividualGet(src,evnt);
                    
                case systemParams(:)
                    obj.pdepPropGroupedGet(@obj.readSystemParameterRAM,src,evnt);
                    
                case matrixSystemParams(:)
                    obj.pdepPropGroupedGet(@obj.readMatrixSystemParameterRAM,src,evnt);
                    
                otherwise
                    
            end
            
            % ensure we return numbers as doubles
            if isnumeric(obj.(propName))
                obj.pdepPropLockMap(propName) = true;
                obj.(propName) = double(obj.(propName));
                obj.pdepPropLockMap(propName) = false;
            end
        end
        
        function pdepPropHandleSet(obj,src,evnt)
            propName = src.Name;
            
            if ~obj.propertyMap.isKey(propName) && ~obj.systemParameterMap.isKey(propName)
                error([propName ' is not supported by the ' obj.controllerType]);
            end
            
            systemParams = obj.accessAPIDataVar('systemParameterNames');
            
            switch propName
                case {'commandSyntaxVersion' 'recordTableRate' 'samplesPerAverage' 'channelName'}
                    obj.pdepPropGroupedSet(@obj.setGCSPropSimple,src,evnt);
                    
                case {'driftCompensation' 'voltageCommand' 'servoControlMode' 'positionLowerLimit' 'positionUpperLimit' ...
                        'voltageCommandRelative' 'velocityControlMode' 'velocity' 'moveTriggered' 'analogInputOffset'}
                    obj.pdepPropGroupedSet(@obj.setGCSPropAxesIndexed,src,evnt);
                    
                case {'controlMode' 'upperVoltageLimit' 'lowerVoltageLimit'}
                    obj.pdepPropGroupedSet(@obj.setGCSPropPiezoChannelIndexed,src,evnt);
                    
                case {'waveGeneratorCycles' 'waveGeneratorOffset' 'waveTableSelection'}
                    obj.pdepPropGroupedSet(@obj.setGCSPropWaveGeneratorIndexed,src,evnt);
                    
                case {'commandLevel' 'triggerOutputConditions' 'dataRecorderConfig' 'homePosition' 'waveGeneratorTableRate'}
                    obj.pdepPropIndividualSet(src,evnt);
                    
                case systemParams(:)
                    obj.pdepPropGroupedSet(@obj.writeSystemParameterRAM,src,evnt);
                    
                otherwise
                    obj.pdepPropSetDisallow(src,evnt);
            end
            
        end
        
        
    end
    
    % GROUPED PDEP GET METHODS
    methods (Hidden)

        function val = getGCSPropSimple(obj,propName)
            val = obj.GCSCall(['get' propName],true,0);
        end
        
        function val = getGCSPropSingleChar(obj,propName)
            val = obj.GCSCall(['get' propName],true,char(1));
            val = val(1);
        end
        
        function vals = getGCSPropMultiple(obj,propName)
            % A generalized getter for GCS functions that return two values (via a pointer).
            % NOTE: perhaps 'multiple' is not a good name for this? then again, 'double' would be even more confusing...
            
            vals = cell(1,2);
            [vals{:}] = obj.GCSCall(['get' propName],true,0,0);
        end
        
        function val = getGCSPropAxisIndexed(obj,propName)
            [~,val] = obj.GCSCall(['get' propName],true,obj.cell2string(obj.axesActive),zeros(1,length(obj.axesActive))); % TODO: driftCompensation -- spins for a while and then returns error code 0
        end
        
        function val = getGCSPropPiezoChannelIndexed(obj,propName)
            [~,val] = obj.GCSCall(['get' propName],true,obj.piezoChannelsActive,zeros(1,length(obj.piezoChannelsActive)),length(obj.piezoChannelsActive));
        end
        
        function val = getGCSPropSensorChannelIndexed(obj,propName)
            [~,val] = obj.GCSCall(['get' propName],true,obj.sensorChannelsActive,zeros(1,length(obj.sensorChannelsActive)),length(obj.sensorChannelsActive));
        end
        
        function val = getGCSPropString(obj,propName)
        	val = obj.GCSCall(['get' propName],true,char(ones(1,3096)),3096);
        end
        
        function val = getGCSPropStringLong(obj,propName)
        	val = obj.GCSCall(['get' propName],true,char(ones(1,20000)),20000);
        end
        
        function val = getGCSPropOptionedString(obj,propName)
            %TODO - Actual implementation
            val = [];
        end
        
        function val = getGCSPropIndividual(obj,propName)
            val = obj.(['get' upper(propName(1)) propName(2:end)]);
        end
        
        function val = getGCSPropAxesNames(obj,propName)
            names = obj.GCSCall(['get' propName],true,char(ones(1,256)),256);
            
            % return the axis names as a cell array
            val = {};
            for character = names
                if regexp(character,'\w+') % skip any newlines or quotes...
                    val = [val {character}];
                end
            end
        end
        
        function vals = getGCSPropWaveGeneratorIndexed(obj,propName)
            [~,vals] = obj.GCSCall(['get' propName],true,obj.waveGeneratorsActive,0,length(obj.waveGeneratorsActive));
        end
        
        
        % Individual PDEP get methods
        function val = getAutoCalibrationOptions(obj)
            % TODO - actual implementation
            val = [];
        end
        
        function val = getAutoCalibrationResults(obj)
            % TODO - actual implementation
            val = [];
        end
        
        function val = getRs232BaudRate(obj)
            % Gets the current baudrate of the device.
            % NOTE: this is implemented as an individual getter because E-816 provides value as GCS parameter, other controllers via a system parameter
            
            if ismember(obj.controllerType,{'E517' 'E712' 'E753'})
                val = obj.readSystemParameterRAM('rs232BaudRate');
            elseif strcmp(obj.controllerType,'E816')
                val = obj.getGCSPropSingle('rs232BaudRate');
            end
        end
        
        function val = getDataRecordTables(obj)
            % TODO - actual implementation
            val = [];
        end
        
        function val = getErrorCode(obj)
            % Gets the current error code from the device.  See GCS qERR() documentation.
            
            errorNameMap = obj.accessAPIDataVar('errorNameMap');
            
            errCode = obj.GCSCall('geterrorCode',true,0);
            if isempty(errorNameMap)
                val = errCode;
            else
                val = obj.mapReverseDecode(errorNameMap,errCode);
            end            
            
        end
        
        
        function val = getI2CState(obj)
            val = cell(2,1);
            [val{:}] = obj.GCSCall('getI2CState',true,0,char(ones(256,1)));            
        end
            
        
        function val = getSerialNumber(obj)
            % Gets the device's serial number.  See GCS qSSN() documentation.
            switch obj.controllerType
                case {'E516' 'E816'}
                    [~,val] = obj.GCSCall('getserialNumber',true,obj.cell2string(obj.axesActive),zeros(1,16));
                case {'E517'}
                    val = obj.getGCSPropString('serialNumber');   
                case {'E753'}
                    val = obj.serialNumberHardware; %Defer to system parameter
            end
        end
        
        function val = getTriggerOutputConditions(obj)
            % TODO - actual implementation
            val = [];
        end
        
        function val = getDataRecorderConfig(obj)
            % TODO - actual implementation
            val = [];
        end
        
        function val = getVoltageActual(obj)
            % Gets the current voltage reading from the device.  See GCS qVOL()
            % documentation.
            %
            % NOTE: implemented as individual getter because signature is different for various devices.
            
           switch obj.controllerType
               case {'E516' 'E816'}
                   val = obj.getGCSPropAxisIndexed('voltageActual');
               case {'E517' 'E712' 'E753'}
                   val = obj.getGCSPropPiezoChannelIndexed('voltageActual');
           end
        end
        
        function vals = getWaveTablePoints(obj)
            % Gets the length of the waveforms currently stored in the device.  See GCS qWAV() documentation..
            
            activeGenerators = obj.waveGeneratorsActive;
            [~,~,vals] = obj.GCSCall('getwaveTablePoints',true,activeGenerators,ones(1,length(activeGenerators)),zeros(1,length(activeGenerators)),length(activeGenerators));
        end
        
        function vals = getWaveTableData(obj)
            % Reads in current wavetable data. A cell array is returned (each
            % entry containing one wavetable's data). See GCS qGWD()
            % documentation.
            
            vals = cell(1,length(obj.waveTableDataArray));
            lengths = obj.waveTablePoints;
            
            % read each table individually (DLL doesn't support reading wavetables of different lengths)
            for i = 1:length(obj.waveGeneratorsActive)
                ID = obj.waveGeneratorsActive(i);
                size = lengths(i);
                
                if size == 0
                    continue;
                end
                
                [~,~,~] = obj.GCSCall('getwaveTableData',true,ID,1,1,size,0,char(ones(1,3096)),3096);
                
                % wait for the async read to complete
                while obj.getAsyncBufferIndex() ~= size
                    pause(0.1);
                end
                
                val = obj.getAsyncBuffer(size);
                
                vals{i} = val;
            end
            
        end
        
        function val = getWaveGeneratorTableRate(obj)
            % Returns the table rate and interpolation type of all available wave generators
            % See GCS qWTR() documentation.
            
            n = numel(find(obj.waveGeneratorsActive));
            [~,tableRate,interpolation] = obj.GCSCall('getwaveGeneratorTableRate',true,libpointer(),ones(n,1),ones(n,1),n);
            
            val = {tableRate interpolation};
        end
        
        
        function val = getIsWaveGeneratorRunning(obj)
            %Returns scalar logical indicating if any of the wave generators are running
            %TODO:Returns logical array indicating which wave generators are running                                              
            [~,val] = obj.apiCall(obj.GCSFuncName('isGeneratorRunning'),obj.controllerID,libpointer(),0,1);             
        end
    end
    
    
   
    
    methods                
        

        
        function set.axesActive(obj,vals)
            % Sets the given axes to be the current active axes.
            % 'vals': a cell string array of axes names.
            
            if ~iscell(vals)
                if length(vals) == 1
                    vals = {vals};
                else
                    error('Axis names must be given as a cell array');
                end
            end
            
            % ensure we use upper case letters...
            vals = upper(vals);
            
            if ~all(ismember(vals,obj.axesNames))
                error('Invalid axis name');
            end
            
            obj.axesActive = vals;
        end
        
        function val = get.isMoving(obj)
            if ~isempty(findprop(obj,'isMovingRaw'))
                val = obj.isMovingRaw;
            elseif ~isempty(findprop(obj,'onTarget'))
                val = ~obj.onTarget;
            else
                val = false; %Default value if unable to actually determine
            end
        end
            
        
        function val = get.systemParameters(obj)
            % Gets the class-cached list of system parameter names.
            
            val = obj.accessAPIDataVar('systemParameterNames');
        end
        
        function set.waveTableDataArrayMap(obj,map)
            % associate the given axes with the given waveTables
            obj.waveTableDataArrayMap = map;
            
            if strcmp(obj.controllerType,'E712') %#ok<MCSUP>
                %hook up the wave generator to the appropriate wave tables
                obj.waveTableSelect(obj.waveTableDataArrayMap.keys,obj.waveTableDataArrayMap.values); %#ok<MCSUP>
            end
        end
        
    end
    
    methods (Hidden)
        
        % GROUPED PDEP SET METHODS
        function setGCSPropSimple(obj,propName,args)
            % assume multiple arguments passed as cell array
            
            if ~iscell(args)
                args = num2cell(args);
            end
            
            callFunc = [obj.GCSPrefix obj.propertyMap(propName)];
            obj.apiCall(callFunc,obj.controllerID,args{:});
        end
        
        function setGCSPropAxesIndexed(obj,propName,args)
            % assume multiple arguments passed as cell array
            
            if ~iscell(args)
                args = num2cell(args);
            end
            
            callFunc = [obj.GCSPrefix obj.propertyMap(propName)];
            obj.apiCall(callFunc,obj.controllerID,obj.cell2string(obj.axesActive),cell2mat(args));
        end
        
        function setGCSPropPiezoChannelIndexed(obj,propName,args)
            % assume channel arguments passed as cell array
            
            if ~iscell(args)
                args = num2cell(args);
            end
            
            callFunc = [obj.GCSPrefix obj.propertyMap(propName)];
            obj.apiCall(callFunc,obj.controllerID,obj.piezoChannelsActive,args{:},length(args));
        end
        
        function setGCSPropWaveGeneratorIndexed(obj,propName,arg)
            if isscalar(arg)
                vals = repmat(arg,1,length(obj.waveGeneratorsActive));
            else
                if length(arg) ~= length(obj.waveGeneratorsActive)
                    error('The number of arguments must match the number of active wave generators');
                end
            end
            
            obj.GCSCall(propName,true,[obj.waveGeneratorsActive{:}],vals,length(vals));
        end
        
        % INDIVIDUAL PDEP SET METHODS
        function setCommandLevel(obj,val)
            % Sets the current device command level. See GCS CCL()
            % documentation.
            
            obj.GCSCall('commandLevel',val,obj.password);
        end
        
        function setDataRecorderConfig(obj,val)
            %TODO
        end
        
        function setTriggerOutputConditions(obj,val)
            %TODO
        end
        
        function setWaveGeneratorTableRate(obj,val)
            % Sets the table rate for the wave generator (and optionally,
            % interpolation).  See GCS WTR() documentation.
            
            activeWaveGenerators = [obj.waveGeneratorsActive{:}];
            
            if iscell(val) && length(val) == 2
                tableRate = val{1};
                interpolation = val{2};
            else
                tableRate = val;
                interpolation = 0;
            end
            
            obj.GCSCall('waveGeneratorTableRate',activeWaveGenerators,tableRate,interpolation,length(activeWaveGenerators));
        end
        
        function setWaveTableData(obj,waveTableIndex,dataStructure)
            % Sets the given wavetable (indexed in waveTableDataArray) to the 
            % given data.
            %
            % NOTE: this method only modifies the internal class representation
            % of the wave table data.  To send the data to the device, it is
            % necessary to call waveTableDataUpdate().  
            %
            % 'waveTableDataArray' is a cell array of struct arrays: each entry 
            % in the cell array represents one wave generator on the device. The
            % mapping between wave generators and cell array indices is
            % maintained by 'waveTableDataArrayMap'.  
            % 
            % The structure arrays serve as an abstraction of the four GCS 
            % WAV_XXX() functions. (See the GCS documentation for further
            % details) The struct arrays have the following format:
            %
            % waveTableDataArray{waveGeneratorIndex} = 
            %   struct('type',{}, ...
            %          'append',{}, ...
            %          'segmentLength',{}, ...
            %          'amplitude',{}, ...
            %          'offset',{}, ...
            %          'waveLength',{}, ...
            %          'startPoint',{}, ...
            %          'speedUpDown',{}, ...
            %          'centerPoint',{}, ...
            %          'pointData',{})
            %
            % Each array entry in a given struct array represents one segment of
            % a waveform (note that is important to set struct.append = 1 to any
            % entries after the first, otherwise each subsequent entry will
            % overwrite the previous).  
            
            if waveTableIndex > length(obj.waveTableDataArray)
                error('Given index exceeds size of waveTableDataArray');
            end
            
            obj.waveTableDataArray{waveTableIndex} = dataStructure;
        end
        
    end
    
    
    %% ABSTRACT METHOD REALIZATIONS / FUNCTION OVERRIDES
    methods
        %
        %         function display(obj)
        %             % See Programming.Interfaces.VClassDisplay() documentation.
        %
        %             obj.displaySmart(properties(obj),'suppressInheritedProps',true,'explicitExcludeList',{'waveTableData'});
        %         end
        
    end
    
    
    %% USER METHODS
    
    % API WRAPPER METHODS
    methods (Access=public)
        
        function automaticCalibration(obj,channels,vals)
            % TODO
        end
        
        function automaticZeroCalibration(obj,varargin)
            %See PI GCS documentation for description of this function and its arguments
            %NOTES: 1) Argument order has been changed from the GCS
            %       2) Trailing arguments can be omitted/left empty, and defaults will be used, as described below.
            %'voltages': Default=autoZeroLowVoltage
            %'useDefaults': Default=true
            useDefaults = true;
            
            if nargin == 2
                if islogical(varargin{2})
                    useDefaults = varargin{2};
                    voltages = 0;
                    if ~useDefaults
                        error('You must specify an array of low voltage parameters');
                    end
                elseif isnumeric(varargin{2})
                    voltages = varargin{2};
                    useDefaults = false;
                end
            end
            
            obj.GCSCall('automaticZeroCalibration',true,obj.cell2string(obj.axesActive),voltages,useDefaults);
            
            while ~obj.autoZeroDone
                % wait until the zeroing process is finished
            end
        end
        
        function clearWaveTable(obj,varargin)
            % Clears the given wave tables on the device.
            % 'varargin: a list of wave tables indices to clear, otherwise
            % defaults to all active wave tables.
            
            if nargin < 2
                generatorIDs = obj.waveGeneratorsActive{:};
            else
                generatorIDs = varargin{:};
            end
            
            obj.GCSCall('clearWaveTable',true,generatorIds,length(generatorIDs));
        end
        
        function controllerID = connectRS232(obj)
            % Connects to the device via RS232 (using stored class property
            % values.)
            % See GCS ConnectRS232() documentation.
            
            controllerID = obj.apiCallRaw(obj.GCSFuncName('connectRS232'),obj.comPort,obj.baudRate);
        end
        
        function controllerID = connectUSB(obj,idString)
            % Connects to the device via USB (using stored class property
            % values.)
            % See GCS ConnectUSB() documentation.
            
            controllerID = obj.GCSCall('connectUSB',false,idString);
        end
        
        function defineHome(obj)
            % Defines the current device position as the "home position".  See
            % GCS DFH() documentation.
            
            obj.GCSCall('defineHome',true,obj.cell2string(obj.axesActive));
        end
        
        function delay(obj,val)
            % Causes the device to pause for the specified time.
            % See GCS DEL() documentation.
            
            obj.GCSCall('delay',true,val);
        end
        
        function id = enumerateUSB(obj)
            % Gets a list of available USB-connected devices.  See GCS
            % EnumerateUSB() documentation.
            
            [ids,~] = obj.GCSCall('EnumerateUSB',false,char(ones(1024)),1024,obj.controllerType);
            
            %TODO: handle multiple IDs...
        end
        
        
        function val = getAsyncBuffer(obj,size)
            % Returns the internal buffer used to store data.
            % See GCS GetAsyncBuffer() documentation.
            % size: the length of the buffer to retrieve.
            
            p = libpointer('doublePtrPtr',zeros(1,size));
            p = obj.apiCall([obj.GCSPrefix 'GetAsyncBuffer'],obj.controllerID,p);
            val = p;
        end
        
        function val = getAsyncBufferIndex(obj)
            % Returns the index of the last value read into the async buffer.
            % See GCS GetAsyncBufferIndex() documentation.
            % NOTE: this function breaks the usual pattern in that its return
            % value is not a success code, but the actual value. This
            % necessitates the use of apiCallRaw().
            
            val = obj.apiCallRaw([obj.GCSPrefix 'GetAsyncBufferIndex'],obj.controllerID);
        end
        
        function val = getError(obj)
            % Returns error code, in string-encoded format, pertaining to last command.
            % See GCS qERR() documentation.
            % NOTE: This function returns actual value, rather than response code. Therefore: use apiCallRaw()
            
            errorNameMap = obj.accessAPIDataVar('errorNameMap');            
            errCode = obj.apiCallRaw([obj.GCSPrefix 'GetError'],obj.controllerID);            
            
            if isempty(errorNameMap)
                val = errCode;
            else                         
                val = obj.mapReverseDecode(errCode);
            end
        end
        
        function halt(obj)
            % Causes the device to halt its current motion. See GCS HLT()
            % documentation.
            
            obj.GCSCall('halt',true,obj.cell2string(obj.axesActive));
        end
        
        function home(obj)
            % Causes the device to return to its home position. See GCS GOH()
            % documentation.
            
            obj.GCSCall('home',true,obj.cell2string(obj.axesActive));
        end
        
        function macroBegin(obj,name)
            obj.GCSCall('macroBegin',true,name);
        end
        
        function macroDefine(obj,name)
            obj.GCSCall('macroDefine',true,name);
        end
        
        function macroDelete(obj,name)
            obj.GCSCall('macroDelete',true,name);
        end
        
        function macroEnd(obj)
            obj.GCSCall('macroEnd',true);
        end
        
        function macroStart(obj,name,runs)
            if nargin < 3 || isempty(runs)
                obj.GCSCall('macroStart',true,name);
            else
                obj.GCSCall('macroNStart',true,name,runs);
            end
        end
        
        function moveComplete(obj, targetPosn)
            %Starts move to targetPosn, specified in relative coordinates, and
            %blocks command execution until move is completed.
            obj.moveCompleteHidden(targetPosn,false);
        end
        
        function moveCompleteIncremental(obj, increment)
            %Starts incremental move and blocks command execution until move is
            %completed.
            obj.moveCompleteHidden(increment,true);
        end
        
        function moveStart(obj,targetPosn)
            %Starts relative move and returns immediately. Can check for move
            %completion via 'isMoving'.
            obj.moveStartHidden(targetPosn, false, false);
        end
        
        function moveStartIncremental(obj, increment)
            %Starts incremental move and returns immediately. Can check for move
            %completion via 'isMoving'.
            obj.moveStartHidden(increment,true,false);
        end

        function moveAsync(obj,targetPosn)
            %Starts move, specified in relative coordinates, and returns
            %immediately. Generates event when move has completed.
            obj.moveStartHidden(targetPosn, false, true);
        end
        
        function moveAsyncIncremental(obj, increment)
            %Starts incremental move and returns immediately. Generates event
            %when move has completed.
            %             assert(isvector(increment) && length(increment) == 3, 'Error: parameter ''increment'' should be a 3 vector.');
            %
            %             obj.moveAsync(increment,true,true);
            
            obj.moveStartHidden(increment,true,true);
        end
        
        function moveFinish(obj)
            %Manually signal end-of-move following a (one-step) moveStart() command (not a moveStartGenerateEvent()). This is required to clear asyncMovePending flag before subsequent asynchronous moves can be started.
            %This should be done before the moveAsyncTimeout period, if specified, has expired, or timeout error will occur (even if move has physically completed).
            
            %Check if command should proceed
            obj.blockOnErrorCond();
            if ~obj.asyncMovePending
                return;
            end
            
            %Reset asyncMovePending flag if not moving
            if obj.isMoving()
                error(['The device of class' obj.controllerType ' appears to still be moving, so asynchronous move cannot be deemed finished.']);
            else
                obj.asyncMovePending = false;
            end
        end
        
        function reloadSystemParameters(obj,varargin)
            obj.GCSCall('reloadSystemParameters',true,varargin);
        end
        
        function renameAxes(obj,oldNames,newNames)
            % renames the axes (in 'oldNames') to 'newNames'
            obj.GCSCall('renameAxes',{oldNames newNames});
            
            obj.axesMap = containers.Map(newNames,num2cell(1:length(newNames)));
        end
        
        function val = readSystemParameterROM(obj,params)
            if nargin < 2 || isempty(params)
                val = obj.readSystemParameter('systemParametersROM');
            else            
                val = obj.readSystemParameter('systemParametersROM',params);
            end
        end
        
        function val = readSystemParameterRAM(obj,params)
            if nargin < 2 || isempty(params)
                val = obj.readSystemParameter('systemParametersRAM');
            else
                val = obj.readSystemParameter('systemParametersRAM',params);
            end
        end
        
        function val = readMatrixSystemParameterRAM(obj,params)
            val = obj.readMatrixSystemParameter('systemParametersRAM',params);
        end
        
        function val = readMatrixSystemParameterROM(obj,params)
            val = obj.readMatrixSystemParameter('systemParametersROM',params);
        end
        
        function vals = readMatrixSystemParameter(obj,source,params)
            %Grouped getter for matrix parameters. One dimension of matrix is always given by the axesActive property
            
            assert(~isempty(findprop(obj,'matrixSystemParamDataMap')), 'Device does not have matrix system parameters');
                        
            if ~ismember(params,obj.matrixSystemParamDataMap.keys());
               error('Unsupported matrix system parameter');                
            end
            
            %Process params input
            if ischar(params) && isvector(params)
                params = {params};
            elseif ~iscellstr(params)
                error('A single parameter name, or cell array of such must be passed');
            end                       
            
            vals = cell(1,length(params)); %These are matrix values

            
            % construct a numeric array of system parameter IDs            
            paramIDs = {};
            for i = 1:length(params)
                param = params{i};
                
                paramData = obj.matrixSystemParamDataMap(param);
            
                startParamID = paramData.startAddress;
                endParamID = startParamID + paramData.number - 1;
                
                paramIDs{i} = [startParamID:endParamID];                      
                            
                if paramData.axisDim == 1
                    vals{i} = zeros(length(obj.axesActive),length(paramIDs{i}));
                else
                    vals{i} = zeros(length(paramIDs{i}),length(obj.axesActive));                    
                end
                
                %Iterate through readSystemParameter calls to build up matrix
                for j = 1:length(paramIDs{i})                    
                    %Each axisValArray gives (numeric) values for one axis
                    axisValArray = obj.readSystemParameter(source,paramIDs{i}(j));
                    
                    %Handle case where particular controller only uses/supports subset of the matrix value
                    if isempty(axisValArray) 
                        if paramData.axisDim == 1
                            vals{i}(:,j:end) =  [];
                        else
                            vals{i}(j:end,:) =  [];
                        end
                        break;
                    end                        
                        
                    if paramData.axisDim == 1
                        vals{i}(:,j) =  axisValArray';
                    else
                        vals{i}(j,:) =  axisValArray;
                    end                                                          
                end                                                
                
            end
            
            if length(vals) == 1
                vals = vals{1};
            end
            
        end
        
        function vals = readSystemParameter(obj,source,params)
            % Reads the specified system parameters from ROM.
            % Returns a cell array of parameter values.
            % paramNames: a cell array (of strings) of system parameter names. Or a numeric array of parameterIDs (pre-decoded).
            
            if nargin > 2 && ~isempty(params) && ~isnumeric(params)
                if ~ismember(params,obj.accessAPIDataVar('systemParameterNames'))
                    error('You have specified an unsupported system parameter');
                end
            end
            
            % if no params are specified, read all "pure", "shadowed"
            if nargin < 3 || isempty(params)
                params = obj.accessAPIDataVar('systemParameterNames');
            else
                if ~iscell(params) && ischar(params)
                    params = {params};
                end
            end
            
            % construct a numeric array of system parameter IDs
            if ~isnumeric(params)
                paramIDs = [];
                for i = 1:length(params)
                    paramIDs(i) = obj.systemParameterMap(params{i});
                end
            else
                paramIDs = params;                
            end
                        
            switch obj.controllerType
                case {'E516' 'E816'}
                    if strcmp(source,'systemParametersROM')
                        error('This device does not support reading from ROM');
                    end
                    
                    axesString = repmat('A',1,length(paramIDs));
                    [~,~,valueArray] = obj.GCSCall(['get' source],true,axesString,paramIDs,zeros(1,length(paramIDs)));
                    vals = valueArray;
                    
                case {'E517' 'E712' 'E753'}
                    [response,~,~,valueArray,stringVals] = obj.apiCallRaw(obj.GCSFuncName(['get' source]),obj.controllerID,obj.cell2string(obj.axesActive),paramIDs,zeros(1,length(paramIDs)),char(ones(1,3096)),3096);
                    
                    % if we see a failed response, retry multiple times (passing "axis" identifiers one-at-a-time) until we see another failed response.
                    if response == 0
                                 
                        errCode = obj.getError();
                        if isequal(errCode,54) %parameter does not exist for this class
                            vals = [];
                        else
                            [~,~,inputChannels] = obj.apiCall([obj.GCSPrefix 'qSPA'],obj.controllerID,'1',obj.systemParameterMap('numberOfInputChannels'),0,char(1),1);
                            [~,~,outputChannels] = obj.apiCall([obj.GCSPrefix 'qSPA'],obj.controllerID,'1',obj.systemParameterMap('numberOfOutputChannels'),0,char(1),1);
                            maxChannels = max(inputChannels,outputChannels);
                            
                            vals = {};
                            for i = 1:maxChannels
                                [response,~,~,value,stringVals] = obj.apiCallRaw(obj.GCSFuncName(['get' source]),obj.controllerID,num2str(i),paramIDs,zeros(1,length(paramIDs)),char(ones(1,3096)),3096);
                                
                                if response == 0
                                    if i == 1
                                        obj.processErrorResponseCode(0,'readSystemParameter');
                                    end
                                    
                                    return;
                                else
                                    % determine if our value was returned as a numeric or as a string
                                    if ~strcmp(stringVals,char(ones(1,3096)))
                                        vals{i} = deblank(stringVals);
                                    else
                                        vals{i} = value;
                                    end
                                end
                            end
                        end
                    else
                        vals = valueArray;
                    end
            end

            if iscell(vals) && all(cellfun(@(x)isnumeric(x) && isscalar(x),vals))
                vals = cell2mat(vals);
            end
        end

        function vals = readSystemParametersAllRAM(obj)
            % A convenience method that calls readSystemParameter() in RAM mode.
            
            vals = obj.readSystemParametersAll('readSystemParameterRAM');
        end
        
        function vals = readSystemParametersAllROM(obj)
            % A convenience method that calls readSystemParameter() in ROM mode.
            
            vals = obj.readSystemParametersAll('readSystemParameterROM');
        end
        
        function vals = readSystemParametersAll(obj,source)
            % Reads all system parameters (and all "implicit" parameters) from ROM.
            % Returns a struct of parameter values (containing a nested struct of "implicit" values).
            
            vals = struct();
            
            % read all "pure" and "shadowed" parameters
            systemParams = obj.accessAPIDataVar('systemParameterNames');
            
            for i = 1:length(systemParams)
                keyName = systemParams{i};
                %val = obj.readSystemParameterROM(keyName);                
                val = feval(source,obj,keyName);
                vals.(keyName) = val;
            end            
            
            % read all "implicit" parameters
            implicitParams =  obj.accessAPIDataVar('implicitParameterNames');
            
            implicitVals = struct();
            for key = implicitParams
                implicitVals.(key{:}) = obj.(key{:});
            end
            
            % store the implicit struct as a nested-struct
            vals.implicitParameters = implicitVals;
        end
        
        function reboot(obj)
            % Reboots the hardware. See GCS RBT() documentation.
            
            obj.GCSCall('reboot',true);
        end
        
        function restart(obj)
            % Restarts the device.  See GCS RST() documentation.
            
            obj.GCSCall('restart',true);
        end
        
        function startImpulse(obj,size)
            % Triggers the device to perform an impulse.  See GCS IMP()
            % documentation.
            obj.GCSCall('startImpulse',true,obj.cell2string(obj.axesActive),size);
        end
        
        function startStep(obj,size)
            % Triggers the device to perform a step.  See GCS STE()
            % documentation.
            obj.GCSCall('startStep',true,obj.cell2string(obj.axesActive),size);
        end
        
        function startWaveGenerator(obj,startMode,varargin)
            % Starts the wave generator output.
            % This abstracts the call to WGO().  A user may specify a start
            % mode, as well as a number of optional arguments.  'startMode' must
            % be one of the three valid start modes. Optional arguments are
            % given as key-value pairs.
            % valid keys:
            %   triggerOnDataPoint
            %   triggerOnPeriod
            %   triggerOnAmplitudeLimit
            %   startAtLastEndpoint
            %   startAtLastStopPoint
            %
            % values are given as logicals indicating if the option should be
            % enabled (default to false).
            
            if isempty(startMode)
                startMode = 'servoTriggerServoSync';
            end
            
            if ~ismember(startMode,{'servoTriggerServoSync' 'externalTriggerServoSync' 'externalTriggerExternalSync'})
                error('Invalid startMode');
            end
            
            % map an option name to it's index into the array
            optionMap = containers.Map({'dummy'},{1});
            optionMap('servoTriggerServoSync') = 1;
            optionMap('externalTriggerServoSync') = 2;
            optionMap('externalTriggerExternalSync') = 3;
            optionMap('triggerOnDataPoint') = 4;
            optionMap('triggerOnPeriod') = 5;
            optionMap('triggerOnAmplitudeLimit') = 6;
            optionMap('startAtLastEndpoint') = 9;
            optionMap('startAtLastStopPoint') = 15;
            options = zeros(1,16);
            argMap = obj.extractPropValArgMap(varargin,{'triggerOnDataPoint' 'triggerOnPeriod' 'triggerOnAmplitudeLimit' ...
                'startAtLastEndpoint' 'startAtLastStopPoint'});
            
            % set the appropriate 'bits' of the array
            options(optionMap(startMode)) = 1;
            
            for key = [optionMap.keys]
                if argMap.isKey(key{:}) && argMap(key{:})
                    options(key{:}) = 1;
                end
            end
            
            obj.GCSCall('startWaveGenerator',true,obj.waveGeneratorsActive,options,16);
        end
        
        function startWaveGeneratorTriggered(obj)
            % Starts the wave generator output in triggered mode (E-816)
            
            for ID = [obj.waveGeneratorsActive]
                obj.GCSCall('startWaveGeneratorTriggered',true,ID{:},64);
            end
        end
        
        function startWaveGeneratorTimed(obj,time)
            % Starts the wave generator output in timed mode (E-816)
            if nargin < 2 || isempty(time)
                error('You must specify a time (in ms)');
            end
            
            for ID = [obj.waveGeneratorsActive]
                obj.GCSCall('startWaveGeneratorTimed',true,ID{:},64,time);
            end
        end
        
        function stop(obj)
            obj.GCSCall('stop',true);
        end
        
        function stopWaveGenerator(obj)
            % Stops any active wave generators.  See GCS WGO() or WTO() documentation.
            
            switch obj.controllerType
                case {'E517' 'E712'}
                    obj.GCSCall('startWaveGenerator',true,obj.waveGeneratorsActive,0,0);
                case {'E816'}
                    for ID = [obj.waveGeneratorsActive]
                        obj.GCSCall('startWaveGeneratorTriggered',true,ID{:},0); % documentation doesn't specify if starting via E816_WTOTimer must be stopped via E816_WTOTimer...for now, assume not; this would introduce more logic.
                    end
            end
        end
        
        function waveTableDataUpdate(obj, waveTableIDs)
            % Parses the data in 'waveTableDataArray' and makes appropriate calls to
            % WAV().
            % waveTableIDs: an optional numeric array specifying which wavetables to update.
            
            % default to update all wave tables if none specified
            if nargin < 2 || isempty(waveTableIDs)
                waveTableIDs = obj.waveGeneratorsActive;
            end
            
            for ID = waveTableIDs
                if isempty(obj.waveTableDataArray{ID})
                    continue;
                end
                
                for i = 1:length(obj.waveTableDataArray{ID})
                    
                    if ~isempty(obj.waveTableDataArray{ID}(i))
                        waveSegment = obj.waveTableDataArray{ID}(i);
                    end
                    
                    switch lower(waveSegment.type)
                        case {'sinusoid'}
                            obj.GCSCall('sinusoid',true,ID,waveSegment.startPoint,waveSegment.waveLength,waveSegment.append,waveSegment.centerPoint,waveSegment.amplitude,waveSegment.offset,waveSegment.segmentLength);
                        case {'line' 'ramp'}
                            obj.GCSCall(waveSegment.type,true,ID,waveSegment.startPoint,waveSegment.waveLength,waveSegment.append,waveSegment.speedUpDown,waveSegment.amplitude,waveSegment.offset,waveSegment.segmentLength);
                        case {'point'}
                            if strcmp(obj.controllerType,'E816')
                                for i = 1:length(waveSegment.pointData)
                                    obj.GCSCall('setWaveTable',true,obj.mapReverseDecode(obj.waveTableDataArrayMap,ID),i-1,waveSegment.pointData(i)); % TODO: for some reason, this is expecting a number rather than a char for the axis ID
                                end
                            else
                                obj.GCSCall('point',true,ID,waveSegment.startPoint,waveSegment.waveLength,waveSegment.append,waveSegment.pointData);
                            end
                    end
                end
            end
            
        end
        
        function waveTableSelect(obj,waveGenerators,waveTables)
            % Connects the given wave generators to the given wave tables.
            
            % convert to a numeric cell array if we're given a string cell array
            if ischar(waveGenerators{1})
                waveGenerators = obj.axes2waveGenerators(waveGenerators);
            end
            
            obj.GCSCall('waveTableSelect',true,cell2mat(waveGenerators),cell2mat(waveTables),length(waveGenerators));
        end
        
        function writeSystemParameterRAM(obj,param,val)
            if nargin > 1 && ~isempty(param)
                if ~ismember(param,obj.accessAPIDataVar('systemParameterNames'))
                    error('You have specified an unsupported system parameter');
                end
            else
                error('You must specify a parameter');
            end
            
            % construct a numeric array of system parameter IDs
            paramID = obj.systemParameterMap(param);
                        
            switch obj.controllerType
                case {'E516' 'E816'}
                    obj.GCSCall('systemParametersRAM',true,obj.controllerID,paramID,val);
                    
                case {'E517' 'E712' 'E753'}
                    if ischar(val)
                        response = obj.apiCallRaw(obj.GCSFuncName('systemParametersRAM'),obj.controllerID,obj.cell2string(obj.axesActive),paramID,0,val);
                    else
                        response = obj.apiCallRaw(obj.GCSFuncName('systemParametersRAM'),obj.controllerID,obj.cell2string(obj.axesActive),paramID,val,char(1));
                    end
                    
                    % if we see a failed response, we might be setting a 'system' parameter; try again, passing a single value for 'szAxes'
                    if response == 0
                        if ischar(val)
                            response = obj.apiCallRaw(obj.GCSFuncName('systemParametersRAM'),obj.controllerID,'1',paramID,0,val);
                        else
                            response = obj.apiCallRaw(obj.GCSFuncName('systemParametersRAM'),obj.controllerID,'1',paramID,val,0);
                        end
                        
                        if response == 0
                            obj.processErrorResponseCode(0,'writeSystemParameter');
                            return;
                        end
                    end  
            end
        end
        
        function writeSystemParameters(obj,params)
            % Writes the specified parameters (given as strings in a cell array)
            % to ROM.
            
            if nargin > 1 && ~isempty(params)
                if ~ismember(params,obj.accessAPIDataVar('systemParameterNames'))
                    error('You have specified an unsupported system parameter');
                end
            end
            
            % construct a numeric array of system parameter IDs
            paramIDs = cell(1,length(params));
            i = 1;
            for param = [params{:}]
                paramIDs{i} = obj.systemParameterMap(param{:});
                i = i + 1;
            end
            obj.GCSCall('writeSystemParameters',true,obj.password,obj.cell2string(obj.axesActive),paramIDs);
        end
        
        function writeSystemParametersAll(obj,varargin)
            % Writes all system parameters to ROM.
            
            switch obj.controllerType
                case {'E517' 'E712' 'E753'}
                    writeSystemParameters();
                case {'E816'}
                    obj.GCSCall('writeSystemParameters',true,obj.password);
            end
            
        end
        
        
    end
    
    
    
    %% DEVELOPER METHODS
    
    %     methods
    %         function display(obj)
    %             obj.smartDisplay(obj.customDisplayPropertyList);
    %         end
    %
    %     end
    
    methods (Hidden)
        
        function moveFinishForce(obj)
            obj.asyncMovePending = false;
        end
        
        function GCSFuncName = GCSFuncName(obj,funcName)
            % Ensures that a function is supported, and properly formats the function call string.
            
            appendQ = strcmpi(funcName(1:3),'get');
            if appendQ
                funcName = funcName(4:end);
            end
            
            if obj.functionMap.isKey(funcName)
                if appendQ
                    GCSFuncName = [obj.GCSPrefix 'q' obj.functionMap(funcName)];
                else
                    GCSFuncName = [obj.GCSPrefix obj.functionMap(funcName)];
                end
            elseif obj.propertyMap.isKey(funcName)
                if appendQ
                    GCSFuncName = [obj.GCSPrefix 'q' obj.propertyMap(funcName)];
                else
                    GCSFuncName = [obj.GCSPrefix obj.propertyMap(funcName)];
                end
            else
                error([funcName '() is not supported by the ' obj.controllerType]);
            end
            
        end
        
        function varargout = GCSCall(obj,prettyName,useID,varargin)
            % Utility to call underlying GCS function corresponding to property or method identified by prettyName.
            % The funcArgList is either a scalar or a cell array of arguments to pass to the GCS function.
            
            % ensure cell array for scalar args
            if ~isempty(varargin) && ~iscell(varargin)
                varargin = {varargin};
            end
            
            varargout = cell(nargout,1);
            
            if useID
                [varargout{:}] = obj.apiCall(obj.GCSFuncName(prettyName),obj.controllerID,varargin{:});
            else
                [varargout{:}] = obj.apiCall(obj.GCSFuncName(prettyName),varargin{:});
            end
        end
        
        
        function errorNameMap = extractErrorMaps(obj)
            if ~isempty(obj.apiAuxFile1Paths(obj.apiCurrentVersion))
                errorNameMap = obj.extractCodeMap('#define\s+(\w+)\s+(-*\d+).*',fullfile(obj.apiAuxFile1Paths(obj.apiCurrentVersion),obj.apiAuxFile1Names(obj.apiCurrentVersion)));
            else
                errorNameMap = containers.Map();
            end
        end
        
        function implicitParameterNames = extractImplicitParameterNames(obj)
            implicitParameterNames = {};
            
            possParams = obj.implicitParamMasterList;
            for i = 1:length(possParams);
                propHandle = findprop(obj,possParams{i});
                if ~isempty(propHandle)
                    implicitParameterNames{end+1} = possParams{i}; %#ok<AGROW>
                end
            end
        end
        
        
        function s = extractSystemParameterNames(obj)
            
            s =struct();
            
            s.systemParameterNames = {};
            s.systemMatrixParameterNames = {};

            mClass = metaclass(obj);
              
            %Identify all properties specified within a SystemParameterXXX 
            for prop=[mClass.Properties{:}]
                if ~isempty(regexp(prop.DefiningClass.Name,'dabs.pi.gcs.SystemParameter', 'once'))
                    if obj.systemParameterMap.isKey(prop.Name)
                        s.systemParameterNames = [s.systemParameterNames {prop.Name}]; %#ok<AGROW>
                    end
                elseif ~isempty(regexp(prop.DefiningClass.Name,'dabs.pi.gcs.MatrixSystemParameter', 'once'))
                    if obj.matrixSystemParamDataMap.isKey(prop.Name)
                        s.systemMatrixParameterNames = [s.systemMatrixParameterNames {prop.Name}]; %#ok<AGROW>
                    end                    
                end
            end
        end
        
        function processErrorResponseCode(obj, ~, funcName)
            % Overrides processErrorResponseCode() in VAPIWrapper
            % NOTE: we disregard the input argument, 'responseCode', because that just tells us a call failed.  We still have to ask for the actual error code.
            % NOTE: We use getError() method, rather than errorCode property, as this is more robust.
            
            if nargin <  3
                errorString = [obj.apiPrettyName ' error :' obj.getError()];
            else
                errorString = [obj.apiPrettyName ' error in call to API function ''' funcName ''': ' obj.getError()];
            end
            
            ME = MException([obj.classNameShort ':APICallErr'],errorString);
            ME.throwAsCaller();
        end
        
    end
    
    
    methods (Access=protected)
        
        function blockOnPendingMove(obj)
            %Method which blocks subsequent action on pending move
            if obj.asyncMovePending
                throwAsCaller(obj.DException('','BlockOnPendingMove','A move is pending. Unable to proceed with current command.'));
            end
        end
        
        function blockOnErrorCond(obj)
            %Blocks subsequent action if error condition is present
            if obj.errorCondition
                throwAsCaller(obj.DException('','BlockOnError','An error condition exists for device of class %s. Unable to proceed with current command.',class(obj)));
            end
        end
        
        function genericErrorHandler(obj,ME)
            rethrow(ME);
        end
        
    end
    
    
    methods (Access=protected)
        
        function initializeModelPropValues(obj)
            
            % default to all available axes active
            obj.axesActive = obj.axesNames;
            obj.axesMap = containers.Map(obj.axesActive,num2cell(1:length(obj.axesActive)));
            
            % initialize our cell array of wave table data (keyed by axis name)
            obj.waveTableDataArray = cell(1,length(obj.axesActive));
            for i = 1:length(obj.axesActive)
                obj.waveTableDataArray{i} = struct( 'type',{}, ...
                    'append',{}, ...
                    'segmentLength',{}, ...
                    'amplitude',{}, ...
                    'offset',{}, ...
                    'waveLength',{}, ...
                    'startPoint',{}, ...
                    'speedUpDown',{}, ...
                    'centerPoint',{}, ...
                    'pointData',{} ...
                    );
            end
            
            % construct a map of axes identifiers to waveTable cell array index
            % map each axis to its corresponding waveTableDataArray index
            obj.waveTableDataArrayMap = containers.Map({obj.axesActive{:}},num2cell([1:length(obj.axesActive)]));
            
        end
        
        function initMaps(obj)
            % maps a meaningful property name to a GCS acronym
            obj.propertyMap = containers.Map({'dummy'},{'dummy'});
            
            obj.propertyMap('autoZeroDone') = 'ATZ';
            obj.propertyMap('errorCode') = 'ERR';
            obj.propertyMap('identificationString') = 'IDN';
            obj.propertyMap('isRunningMacro') = 'IsRunningMacro';
            obj.propertyMap('startupMacro') = 'MAC_qDEF';
            obj.propertyMap('onTarget') = 'ONT';
            obj.propertyMap('overflowStatus') = 'OVF';
            obj.propertyMap('position') = 'POS';
            obj.propertyMap('serialNumber') = 'SSN';
            obj.propertyMap('voltageActual') = 'VOL';
            obj.propertyMap('driftCompensation') = 'DCO';
            obj.propertyMap('positionCommand') = 'MOV';
            obj.propertyMap('axesNames') = 'SAI';
            obj.propertyMap('axesNamesAll') = 'SAI_ALL';
            obj.propertyMap('voltageCommand') = 'SVA';
            obj.propertyMap('voltageCommandRelative') = 'SVR';
            obj.propertyMap('servoControlMode') = 'SVO';
            obj.propertyMap('autoCalibrationOptions') = 'ATC';
            obj.propertyMap('autoCalibrationResults') = 'ATS';
            obj.propertyMap('commandLevel') = 'CCL';
            obj.propertyMap('commandSyntaxVersion') = 'CSV';
            obj.propertyMap('triggerOutputConditions') = 'CTO';
            obj.propertyMap('driftCompensation') = 'DCO';
            obj.propertyMap('homePosition') = 'DFH';
            obj.propertyMap('digitalInputState') = 'DIO';
            obj.propertyMap('dataRecorderConfig') = 'DRC';
            obj.propertyMap('dataRecordTables') = 'DRT';
            if strcmp(obj.controllerType,'E816')
                obj.propertyMap('waveTableData') = 'SWT';
            else
                obj.propertyMap('waveTableData') = 'GWD';
            end
            obj.propertyMap('helpStringDataRecording') = 'HDR';
            obj.propertyMap('helpString') = 'HLP';
            obj.propertyMap('helpStringAvailableParams') = 'HPA';
            obj.propertyMap('interfaceConfig') = 'IFC';
            obj.propertyMap('interfaceConfigStore') = 'IFS';
            obj.propertyMap('impulse') = 'IMP';
            obj.propertyMap('isControllerReady') = 'IsControllerReady';
            obj.propertyMap('isMovingRaw') = 'IsMoving';
            obj.propertyMap('availableMacros') = 'MAC';
            obj.propertyMap('positionLowerLimit') = 'NLM';
            obj.propertyMap('controlMode') = 'ONL';
            obj.propertyMap('positionUpperLimit') = 'PLM';
            obj.propertyMap('recordTableRate') = 'RTR';
            obj.propertyMap('step') = 'STE';
            obj.propertyMap('velocityControlMode') = 'VCO';
            obj.propertyMap('velocity') = 'VEL';
            obj.propertyMap('upperVoltageLimit') = 'VMA';
            obj.propertyMap('lowerVoltageLimit') = 'VMI';
            obj.propertyMap('availableDigitalChannels') = 'TIO';
            obj.propertyMap('positionCommandMin') = 'TMN';
            obj.propertyMap('positionCommandMax') = 'TMX';
            obj.propertyMap('numberOfDataRecordTables') = 'TNR';
            obj.propertyMap('numberOfPiezoChannels') = 'TPC';
            obj.propertyMap('numberOfSensorChannels') = 'TSC';
            obj.propertyMap('sensorPosition') = 'TSP';
            obj.propertyMap('validAxisChars') = 'TVI';
            obj.propertyMap('numberOfWaveGenerators') = 'TWG';
            obj.propertyMap('version') = 'VER';
            obj.propertyMap('samplesPerAverage') = 'AVG';
            obj.propertyMap('rs232BaudRate') = 'BDR';
            obj.propertyMap('wasDigitalPulseDetected') = 'DIP';
            obj.propertyMap('I2CState') = 'I2C';
            obj.propertyMap('moveTriggered') = 'MVT';
            obj.propertyMap('channelName') = 'SCH';
            obj.propertyMap('analogInputOffset') = 'AOS';
            obj.propertyMap('waveTablePoints') = 'WAV';
            obj.propertyMap('waveGeneratorCycles') = 'WGC';
            obj.propertyMap('waveGeneratorOffset') = 'WOS';
            obj.propertyMap('waveTableSelection') = 'WSL';
            obj.propertyMap('waveGeneratorTableRate') = 'WTR';
            obj.propertyMap('adValue') = 'TAD';
            obj.propertyMap('dataRecordTables') = 'DRR';
            obj.propertyMap('numberOfDataRecordTables') = 'TNR';
            obj.propertyMap('helpString') = 'HLP';
            obj.propertyMap('helpStringAvailableParams') = 'HPA';
            obj.propertyMap('helpStringDataRecording') = 'HDR';
            obj.propertyMap('adValue') = 'TAD';
            obj.propertyMap('isWaveGeneratorRunning') = 'IsGeneratorRunning';
            
            obj.propertyMap.remove('dummy');
            
            %maps a function name to a GCS acronym (common to all GCS devices)
            obj.functionMap = containers.Map({'dummy'},{'dummy'});
            
            obj.functionMap('automaticZeroCalibration') = 'ATZ';
            obj.functionMap('closeConnection') = 'CloseConnection';
            obj.functionMap('connectRS232') = 'ConnectRS232';
            obj.functionMap('delay') = 'DEL';
            obj.functionMap('defineHome') = 'DFH';
            obj.functionMap('getError') = 'GetError';
            obj.functionMap('macBegin') = 'MAC_BEG';
            obj.functionMap('macDefine') = 'MAC_DEF';
            obj.functionMap('macDelete') = 'MAC_DEL';
            obj.functionMap('macEnd') = 'MAC_END';
            obj.functionMap('macFree') = 'MAC_qFree';
            obj.functionMap('macNStart') = 'MAC_NSTART';
            obj.functionMap('macStart') = 'MAC_START';
            obj.functionMap('move') = 'MOV';
            obj.functionMap('moveRelative') = 'MVR';
            obj.functionMap('home') = 'GOH';
            obj.functionMap('halt') = 'HLT';
            obj.functionMap('reloadSystemParameters') = 'RPA';
            obj.functionMap('renameAxes') = 'SAI';
            obj.functionMap('reboot') = 'RBT';
            obj.functionMap('restart') = 'RST';
            obj.functionMap('startImpulse') = 'IMP';
            obj.functionMap('clearOutputTriggerSettings') = 'TWC';
            obj.functionMap('setOutputTriggerSettings') = 'TWS';
            obj.functionMap('systemParametersROM') = 'SEP';
            obj.functionMap('systemParametersRAM') = 'SPA';
            obj.functionMap('startStep') = 'STE';
            obj.functionMap('stop') = 'STP';
            obj.functionMap('setWaveTable') = 'SWT';
            obj.functionMap('sinusoid') = 'WAV_SIN_P';
            obj.functionMap('line') = 'WAV_LIN';
            obj.functionMap('point') = 'WAV_PNT';
            obj.functionMap('ramp') = 'WAV_RAMP';
            obj.functionMap('clearWaveTable') = 'WCL';
            obj.functionMap('startWaveGenerator') = 'WGO';
            obj.functionMap('writeSystemParameters') = 'WPA';
            obj.functionMap('waveTableSelect') = 'WSL';
            obj.functionMap('startWaveGeneratorTimed') = 'WTOTimer';
            obj.functionMap('startWaveGeneratorTriggered') = 'WTO';
            obj.functionMap('isGeneratorRunning') = 'IsGeneratorRunning';
            obj.functionMap.remove('dummy');
            
        end
        
        
        function moveStartReal(obj,targetPosn,doIncremental)
            %Dispatch of actual moveStart operation
            
            
            if length(obj.axesActive) ~= length(targetPosn)
                error('The given coordinate dimensions do not match the number of active axes');
            end
            
            if ~doIncremental
                obj.GCSCall('move',true,obj.cell2string(obj.axesActive),targetPosn);
            else
                obj.GCSCall('moveRelative',true,obj.cell2string(obj.axesActive),targetPosn);
            end
            
            obj.asyncMovePending = true;
        end
        
        function moveCompleteHidden(obj,targetPosn,doIncremental)
            %Generalized blocking move function used by moveCompleteXXX() methods
            
            %Check if command should proceed
            obj.blockOnErrorCond();
            obj.blockOnPendingMove();
            
            try
                obj.moveStartReal(targetPosn,doIncremental);
                
                if ~obj.isMoving
                    t = tic();
                    while ~obj.onTarget
                        if toc(t) > obj.moveCompleteTimeout
                            error(['Move failed to complete within specified ''moveCompleteTimeout'' period (' obj.moveCompleteTimeout ' s)']);
                        end
                        pause(obj.moveCompletePauseInterval);
                    end
                end
                
                %Signal end of any async move. Harmless if none was used.
                obj.moveFinish();
                
            catch ME
                obj.genericErrorHandler(ME);
            end
            
        end
        
        
        function moveStartHidden(obj, targetPosn, doIncremental, isAsync)
            %Generalized move function called by other moveStartXXX()and moveStartCompleteEventXXX() methods.
            
            try
                %Check if command should proceed
                obj.blockOnErrorCond();
                obj.blockOnPendingMove();
                
                %                 %Convert targetPosn to absolute coordinates, if needed
                %                 if ~forceAbsolute
                %                     targetPosn = targetPosn + obj.relativeOrigin;
                %                 end
                
                %Set up timers, if necessary
                if isAsync
                    moveAsyncTimer = timer('TimerFcn',@moveAsyncTimerFcn,'StartDelay',0.2,'Period',0.2,'ExecutionMode','fixedRate','Name','moveCompletePoll');
                    
                    if ~isinf(obj.moveAsyncTimeout)
                        %Timer that will fire if event-generating async move
                        %times out.
                        moveAsyncTimeoutTimer = timer('TimerFcn',@handleMoveAsyncTimeout,'StartDelay',obj.moveAsyncTimeout,'Name','moveAsyncTimeoutCheck'); %single-shot timer
                    else
                        moveAsyncTimeoutTimer = [];
                    end
                else
                    moveAsyncTimer = [];
                end
                
                %Start move
                obj.moveStartReal(targetPosn,doIncremental);
                obj.asyncMoveTimeReference = tic();

                %Start timer to poll for move completion, if needed
                if isAsync
                    start([moveAsyncTimer moveAsyncTimeoutTimer]);
                end
                
            catch ME
                obj.genericErrorHandler(ME);
            end
            
            
            function moveAsyncStopTimers()
                %Stop timers..but don't delete them, as they may be used again
                
                if ~isempty(moveAsyncTimer)
                    stop(moveAsyncTimer);
                end
                
                if ~isempty(moveAsyncTimeoutTimer)
                    stop(moveAsyncTimeoutTimer);
                end
            end
            
            function moveAsyncCleanup()
                % handles adminstrative tasks after the completion of an async move.
                
                %Stop & Delete timer resources
                timers = [moveAsyncTimer moveAsyncTimeoutTimer];
                for i=1:length(timers)
                    if ~isempty(timers(i))
                        stop(timers(i));
                        delete(timers(i));
                    end
                end
                

                %Reset flags
                obj.asyncMovePending = false;
            end
            
            function moveAsyncTimerFcn(~,~)
                %Timer function that polls to see if motor is still moving
                
                if obj.asyncMovePending %Move completed before timeout
                    if ~obj.isMoving
                        handleMoveAsyncComplete();
                    end
                else %Move may have been interrupted
                    moveAsyncCleanup();
                end
            end
            
            
            function handleMoveAsyncTimeout(~,~)
                if obj.asyncMovePending %timeout occurred before move complete was detected (or manually specified)
                    warning(['Move failed to complete within specified ''moveAsyncTimeout'' period (' obj.moveAsyncTimeout ' s)']);
                else %Move may have been previously interrupted
                    moveAsyncCleanup();
                end
            end
            
            function handleMoveAsyncComplete(~,~)
                %Move may have been interrupted
                if ~obj.asyncMovePending
                    obj.moveAsyncCleanup();
                    return;
                end
                
                obj.asyncMovePending = false;
                moveAsyncStopTimers(); %This stops moveAsyncTimeoutTimer, as move complete came before timeout
                
                moveAsyncCleanup(); %Delete all resources related to async move
                
                obj.notify('moveAsyncCompleteEvent');
            end
            
        end
        
    end
    
    methods (Static)
        
        
        function val = cell2string(cellArray)
            % A helper function to collapse a cell array of strings to a single string (while maintaining a space between all chars).
            
            val = [];
            
            for i = 1:length(cellArray)
                if i == 1
                    val = cellArray{i};
                else
                    val = [val ' ' cellArray{i}];
                end
            end
            
        end
        
        function key = mapReverseDecode(map,value)
            %Method for reverse-lookup for Maps for which the key-value pairs are 1-1 and unique in both directions
            %Assumes values are numeric
            
            keys = map.keys;
            values = map.values;
            
            key = keys{find(value==cell2mat(values))};
        end
        
    end
    
end

%% HELPERS
function systemParameterMap = initSystemParameterMap()
    %maps a meaningful SystemParameter param name to a GCS acronym 
    systemParameterMap = containers.Map({'dummy'},{1});

    % E-517 and E-712 specific:
    systemParameterMap('sensorEnable') = 33554432;
    systemParameterMap('sensorCorrectionZeroOrder') = 33554944;
    systemParameterMap('sensorCorrectionFirstOrder') = 33555200;
    systemParameterMap('adcGain') = 67110144;
    systemParameterMap('adcOffset') = 67110400;
    systemParameterMap('hwGain') = 67110656;
    systemParameterMap('hwOffset') = 67110912;
    systemParameterMap('lcdUnit') = 67112448;
    systemParameterMap('lcdFormat') = 67112449;
    systemParameterMap('digitalFilterType') = 83886080;
    systemParameterMap('digitalFilterBandwidth') = 83886081;
    systemParameterMap('digitalFilterOrder') = 83886082;
    systemParameterMap('filterParamA0') = 83886337;
    systemParameterMap('filterParamA1') = 83886338;
    systemParameterMap('filterParamB0') = 83886339;
    systemParameterMap('filterParamB1') = 83886340;
    systemParameterMap('filterParamB2') = 83886341;
    systemParameterMap('rangeLimitMin') = 117440512;
    systemParameterMap('rangeLimitMax') = 117440513;
    systemParameterMap('servoLoopSlewRate') = 117441024;
    systemParameterMap('positionOne') = 117441792;
    systemParameterMap('positionTwo') = 117441793;
    systemParameterMap('positionThree') = 117441794;
    systemParameterMap('axisName') = 117442048;
    systemParameterMap('axisUnit') = 117442049;
    systemParameterMap('tolerance') = 117442816;
    systemParameterMap('defaultVoltage') = 117443585;
    systemParameterMap('userOrigin') = 117506560;
    systemParameterMap('swOnTargetSignal') = 117507584;
    systemParameterMap('axisServoMode') = 117637376;
    systemParameterMap('piezoOneDriving') = 150994944;
    systemParameterMap('piezoTwoDriving') = 150994945;
    systemParameterMap('piezoThreeDriving') = 150994946;
    systemParameterMap('dacOffset') = 167772176;
    systemParameterMap('dacGain') = 167772192;
    systemParameterMap('gain') = 184549379;
    systemParameterMap('outputVoltageMin') = 184549383;
    systemParameterMap('outputVoltageMax') = 184549384;
    systemParameterMap('offset') = 184549386;
    systemParameterMap('setVoltageMin') = 201326592;
    systemParameterMap('setVoltageMax') = 201326593;
    systemParameterMap('serialNumberDevice') = 218103808;
    systemParameterMap('serialNumberHardware') = 218104064;
    systemParameterMap('hardwareName') = 218104320;
    systemParameterMap('hardwareRevision') = 218104832;
    systemParameterMap('deviceID') = 218105344;
    systemParameterMap('sensorSamplingTime') = 234881280;
    systemParameterMap('servoUpdateTime') = 234881536;
    systemParameterMap('pulseWidth') = 234883328;
    systemParameterMap('numberOfSensorChannelsSystemParam') = 234883843;
    systemParameterMap('numberOfPiezoChannelsSystemParam') = 234883844;
    systemParameterMap('numberOfTriggerOutputs') = 234883845;
    systemParameterMap('lcdBrightness') = 234884352;
    systemParameterMap('lcdContrast') = 234884353;
    systemParameterMap('rs232BaudRate') = 285213696;
    systemParameterMap('ethernetIPAddress') = 285214208;
    systemParameterMap('ethernetIPMask') = 285214464;
    systemParameterMap('ethernetIPConfig') = 285214720;
    systemParameterMap('gpibAddress') = 285214976;
    systemParameterMap('ethernetIPMACAddress') = 285215488;
    systemParameterMap('gpibEnable') = 301989889;
    systemParameterMap('waveGeneratorCyclesSystemParam') = 318767107;
    systemParameterMap('maxWavePoints') = 318767108;
    systemParameterMap('waveGeneratorTableRateSystemParam') = 318767369;
    systemParameterMap('numberOfWaveTables') = 318767370;
    systemParameterMap('waveOffsetSystemParam') = 318767371;
    systemParameterMap('maxWavePointsTable') = 318767617;
    systemParameterMap('tableRate') = 369098752;
    systemParameterMap('numberOfChannelsMax') = 369099008;
    systemParameterMap('recordPointsMax') = 369099264;
    systemParameterMap('recordPointsTableMax') = 369099265;
    systemParameterMap('numberOfTriggerCycles') = 402653440;

    % E-712 specific:
    systemParameterMap('sensorRangeFactor') = 33554688;
    systemParameterMap('sensorBoardGain') = 33554689;
    systemParameterMap('sensorOffsetFactor') = 33554690;
    systemParameterMap('sensorCableCompensation') = 33554691;
    systemParameterMap('autoZeroMatchedOffset') = 33554692;
    systemParameterMap('adcChannelForTarget') = 100664576;
    systemParameterMap('analogTargetOffset') = 100664577;
    systemParameterMap('openLoopSlewRate') = 117441025;
    systemParameterMap('servoLoopP') = 117441280;
    systemParameterMap('servoLoopI') = 117441281;
    systemParameterMap('servoLoopD') = 117441282;
    systemParameterMap('powerUpServoOnEnable') = 117442560;
    systemParameterMap('powerUpAutoZeroEnable') = 117442562;
    systemParameterMap('onTargetTolerance') = 117442816;
    systemParameterMap('settingTime') = 117442817;
    systemParameterMap('autoZeroLowVoltage') = 117443072;
    systemParameterMap('autoZeroHighVoltage') = 117443073;
    systemParameterMap('defaultVoltage') = 117443585;
    systemParameterMap('positionReportScaling') = 117444613;
    systemParameterMap('positionReportOffset') = 117444614;
    systemParameterMap('notchFrequency1') = 134217984;
    systemParameterMap('notchFrequency2') = 134217985;
    systemParameterMap('notchRejection1') = 134218240;
    systemParameterMap('notchRejection2') = 134218241;
    systemParameterMap('notchBandwidth1') = 134218496;
    systemParameterMap('notchBandwidth2') = 134218497;
    systemParameterMap('creepFactor1') = 134218752;
    systemParameterMap('creepFactor2') = 134218753;
    systemParameterMap('selectOutputType') = 167772163;
    systemParameterMap('selectOutputIndex') = 167772164;
    systemParameterMap('numberOfInputChannels') = 234883840;
    systemParameterMap('numberOfOutputChannels') = 234883841;
    systemParameterMap('numberOfSystemAxes') = 234883842;
    systemParameterMap('powerUpReadIDChip') = 251658240;
    systemParameterMap('stageType') = 251658496;
    systemParameterMap('stageSerialNumber') = 251658752;
    systemParameterMap('stageAssemblyDate') = 251659008;
    systemParameterMap('macAddress') = 285215488;
    systemParameterMap('maxDDLPoints') = 335544331;
    systemParameterMap('autoCalTimeDelayFactor') = 335544576;
    systemParameterMap('autoCalMinMaxTimeDelayFactor') = 335544577;
    systemParameterMap('dataRecorderChannelNumber') = 369099520;
    systemParameterMap('firmwareMark') = 4294901761;
    systemParameterMap('firmwareCRC') = 4294901762;
    systemParameterMap('firmwareDescCRC') = 4294901763;
    systemParameterMap('firmwareDescVersion') = 4294901764;
    systemParameterMap('firmwareMatchcode') = 4294901766;
    systemParameterMap('hardwareMatchcode') = 4294901767;
    systemParameterMap('firmwareVersion') = 4294901768;
    systemParameterMap('firmwareMaxSize') = 4294901771;
    systemParameterMap('firmwareDevice') = 4294901772;
    systemParameterMap('firmwareDesc') = 4294901773;
    systemParameterMap('firmwareDate') = 4294901774;
    systemParameterMap('firmwareDeveloper') = 4294901775;
    systemParameterMap('firmwareLength') = 4294901776;
    systemParameterMap('firmwareCompatability') = 4294901777;
    systemParameterMap('firmwareAddress') = 4294901778;
    systemParameterMap('firmwareDeviceType') = 4294901779;
    systemParameterMap('hardwareRevision') = 4294901780;
    systemParameterMap('firmwareDestinationAddress') = 4294901781;
    systemParameterMap('firmwareConfig') = 4294901782;

    % E-516 and E-816 specific:
    systemParameterMap('vadGain') = 1;
    systemParameterMap('vadOffset') = 2;
    systemParameterMap('padGain') = 3;
    systemParameterMap('padOffset') = 4;
    systemParameterMap('daGain') = 5;
    systemParameterMap('daOffset') = 6;
    systemParameterMap('kSen') = 7;
    systemParameterMap('oSen') = 8;
    systemParameterMap('kPZT') = 9;
    systemParameterMap('oPZT') = 10;

    systemParameterMap.remove('dummy');
end


function implicitParamMasterList = initImplicitParamMasterList()
    implicitParamMasterList = {'commandSyntaxVersion' 'triggerOutputConditions' 'dataRecorderConfig' ...
        'positionLowerLimit' 'positionUpperLimit' 'velocityControlMode' ...
        'samplesPerAverage' 'channelName'};
end
