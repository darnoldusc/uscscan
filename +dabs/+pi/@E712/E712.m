classdef E712 < Devices.PI.private.MotionController & Devices.PI.private.CoreExtendedProperties & Devices.PI.private.SystemParameterExtendedProperties & Devices.PI.private.SystemParameterEthernetProperties & Devices.PI.private.SystemParameterAdvancedProperties & Devices.PI.private.MatrixSystemParameterProperties & Devices.PI.private.WaveGeneratorProperties
   
    %% ABSTRACT PROPERTY REALIZATION (Devices.PI.MotionController)
    properties (Constant, Hidden)
        controllerType = 'E712';
        GCSPrefix = 'E7XX_'; 
        useAxesComponentIndex = true;
        corePropertyExclusions = {'serialNumber' 'driftCompensation' 'startupMacro'}; %PI: May also excluded voltageActual -- but this should work!
    end
    
    %% ABSTRACT PROPERTY REALIZATION (Programming.Interfaces.VAPIWrapper)
    
    %Following MUST be supplied with non-empty values for each concrete subclass
    properties (Constant, Hidden)
        apiPrettyName = 'E712 GCS2';  %A unique descriptive string of the API being wrapped         
        apiCompactName = 'E712_GCS2'; %A unique, compact string of the API being wrapped (must not contain spaces) 
        
        apiSupportedVersionNames = {'2.1.0'}; %A cell array of shorthand names (strings) for API versions supported by this wrapper class

        %Properties which can be indexed by version
        apiDLLNames = 'E7XX_GCS2_DLL'; %Either a single name of the DLL filename (sans the '.dll' extension), or a Map of such names keyed by values in 'apiSupportedVersionNames'
        apiHeaderFilenames = 'E7XX_GCS2_DLL.h'; %Either a single name of the header filename (with the '.h' extension - OR a .m or .p extension), or a Map of such names keyed by values in 'apiSupportedVersionNames'
    end
    
    properties (SetAccess=protected, Hidden)
       apiHeaderPaths = 'C:\Program Files\PI\E-712E712_GCS_DLL';
       apiDLLPaths = 'C:\Program Files\PI\E-712E712_GCS_DLL';
    end
    
    properties (Dependent, Access=public)
        sensorChannelsActive;
        piezoChannelsActive;
        waveGeneratorsActive;
    end
    
    %% CONSTRUCTOR/DESTRUCTOR      
    
    methods
        
        function obj = E712(varargin)
            % Constructs a Devices.PI.E712 device object
            %
            % Prop-Value pair args
            % connectionType: <OPTIONAL - Default='rs232'> Specify the connection protocol to use. One of {'rs232' 'usb' 'ethernet'}.
            % comPort: (REQUIRED IF CONNECTION IS RS232) Number specifiying COM port to which controller is connected
            % baudRate: <OPTIONAL - Default=115200> Specify baud rate to use during communication. Must match that set on hardware.
            
            %Call superclass constructor       
            obj = obj@Devices.PI.private.MotionController(varargin{:});
        end
 
    end
    
    
    %% PROPERTY ACCESS METHODS
    
    methods
        
        function val = get.piezoChannelsActive(obj)
            val = str2double(obj.axesActive);
        end
        
        function val = get.sensorChannelsActive(obj)
            val = str2double(obj.axesActive);
        end
        
        function val = get.waveGeneratorsActive(obj)
            val = str2double(obj.axesActive);
        end
    end
    
    
    %% STATIC METHODS
    
    methods (Static)
        
         function updateAPIData()
            updateAPIData@Programming.Interfaces.VAPIWrapper(mfilename('class'));
         end
         
         function waveGenerators = axes2waveGenerators(axesCell)
            % A utility function to map between axes and wave generators 
            % (which is nothing more than converting a string cell array to a numeric cell array).
            waveGenerators = num2cell(str2double(axesCell));
         end
         
     end
end