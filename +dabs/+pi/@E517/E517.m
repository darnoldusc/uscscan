classdef E517 < Devices.PI.MotionController & Devices.PI.private.CoreExtendedProperties & Devices.PI.Properties.SystemParameterExtendedProperties & Devices.PI.private.SystemParameterEthernetProperties & Devices.PI.private.SystemParameterGPIBProperties & Devices.PI.private.WaveGeneratorProperties
    
    %% ABSTRACT PROPERTY REALIZATION (Devices.PI.MotionController)
    properties (Constant, Hidden)
        controllerType = 'E517';
        GCSPrefix = 'PI_';
        useAxesComponentIndex = false;
        corePropertyExclusions = {};
    end
    
    
    %% ABSTRACT PROPERTY REALIZATION 
    properties (Constant, Hidden)        
        %Properties which can be indexed by version
        apiDLLNames = 'PI_GCS2_DLL';
        apiHeaderFilenames = 'PI_GCS2';
    end    
    
    properties (SetAccess=protected, Hidden)
       apiHeaderPaths; % use default
       apiDLLPaths = 'C:\Program Files\PI\PI_GCS2\'; 
    end
    
    properties (Dependent, Access=protected)
        sensorChannelsActive;
        piezoChannelsActive;
        waveGeneratorsActive;
    end
    
    %% USER PROPERTIES
    
    %PDEP Props (supported exclusively by E-517 or not within other property category)
    properties (GetObservable,SetObservable)
        
        %Get/Set access
        autoCalibrationOptions;         % qATC (E-517)
        autoCalibrationResults;         % qATS (E-517)
        homePosition;                   % qDFH (E-517)
        impulseParams;                  % qIMP (E-517)
        isControllerReady;              % IsControllerReady (E-517)
        isRunningMacro;                 % IsRunningMacro (E-517)
        availableMacros;                % qMAC (E-517)
        axesNamesAll;                   % SAI_ALL (E-517)
        step;                           % qSTE (E-517)
        availableDigitalChannels;       % qTIO (E-517)
        validAxisChars;                 % qTVI (E-517)
        version;                        % qVER (E-517)
        
        %Set-only props
        voltageCommandRelative;         % SVR (E-517)
        
        %Get-only props
        startupMacro;                   % MAC_qDEF (E-517, E-816)
        driftCompensation;              % DCO (E-517, E-816)

        commandSyntaxVersion;           % CSV (E-517)
        digitalInputState;              % DIO (E-517)
        positionLowerLimit;             % NLM (E-517)
        positionUpperLimit;             % PLM (E-517)
        controlMode;                    % ONL (E-517)
        
        recordTableRate;                % RTR (E-517)
        velocityControlMode;            % VCO (E-517)
        upperVoltageLimit;              % VMA (E-517)
        lowerVoltageLimit;              % VMI (E-517)
        
        %System properties
        sensorEnable;
        adcGain;
        adcOffset;
        hwGain;
        hwOffset;
        lcdUnit;
        lcdFormat;
        userOrigin;
        swOnTargetSignal;
        dacOffset;
        dacGain;
        gain;
        deviceID;
        pulseWidth;
        lcdBrightness;
        lcdContrast;
        gpibAddress;
        gpibEnable;
        waveGeneratorCyclesSystemParam;
        maxWavePointsTable;
        recordPointsTableMax;
        numberOfTriggerCycles;
        autoZeroMatchedOffset;
    end
    
    properties
        sensorChannelIDs = {1 2 3};  % from E-517 User Manual (p.33)
        piezoChannelIDs = {4 5 6};   % from E-517 User Manual (p.33)
        waveGeneratorIDs = {1 2 3};  % from E-517 DLL Manual (p.52)
    end
    
    %% DEVELOPER PROPERTIES
    
    %PDEP Props
    properties (Hidden, SetObservable, GetObservable)
        isMovingRaw; % IsMoving (E-517)
    end
    
    %% CONSTRUCTOR/DESTRUCTOR      
    
    methods
        
        function obj = E517(varargin)
            
            %Call superclass constructor       
            obj = obj@Devices.PI.MotionController(varargin{:});
            
            %             obj.GCSPrefix = 'PI_';
            %             obj.useAxesComponentIndex = true;
        end
 
    end
    
    
    %% PROPERTY ACCESS METHODS
    
    methods
        
        function val = get.piezoChannelsActive(obj)  
            positions = ismember(obj.axesActiveAll,obj.axesActive);
            val = obj.piezoChannelIDs(positions);
        end
        
        function val = get.sensorChannelsActive(obj)
            positions = ismember(obj.axesActiveAll,obj.axesActive);
            val = obj.sensorChannelIDs(positions);
        end
        
        function val = get.waveGeneratorsActive(obj)
%             val = cell(1,length(obj.axesActive));
%             for axis = [obj.axesActive{:}]
%                 val = {val{:} obj.waveDataArrayMap(axis{:})};
%             end
            
            positions = ismember(obj.axesActiveAll,obj.axesActive);
            val = obj.waveGeneratorIDs(positions);
        end
    end
    
    
    %% STATIC METHODS
    
    methods (Static)
        
         function updateAPIData()
            updateAPIData@Programming.Interfaces.VAPIWrapper(mfilename('class'));
         end
         
     end
end