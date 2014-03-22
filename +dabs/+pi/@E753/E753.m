classdef E753 < dabs.pi.gcs.MotionController & dabs.pi.gcs.CoreExtendedProperties & dabs.pi.gcs.SystemParameterExtendedProperties & dabs.pi.gcs.SystemParameterEthernetProperties & dabs.pi.gcs.SystemParameterAdvancedProperties & dabs.pi.gcs.MatrixSystemParameterProperties & dabs.pi.gcs.WaveGeneratorProperties
   %Class encapsulating Physik Instrumente E753 controller computer interface

    %% PUBLIC PROPERTIES
    
    properties (Dependent, Access=public)
        sensorChannelsActive;
        piezoChannelsActive;
        waveGeneratorsActive;
    end
    
    %% CONSTRUCTOR/DESTRUCTOR      
    
    methods
        
        function obj = E753(varargin)
            % Constructs a Devices.PI.E7 device object
            %
            % Prop-Value pair args
            % connectionType: <OPTIONAL - Default='rs232'> Specify the connection protocol to use. One of {'rs232' 'usb' 'ethernet'}.
            % comPort: (REQUIRED IF CONNECTION IS RS232) Number specifiying COM port to which controller is connected
            % baudRate: <OPTIONAL - Default=115200> Specify baud rate to use during communication. Must match that set on hardware.
            
            %Call superclass constructor       
            obj = obj@dabs.pi.gcs.MotionController(varargin{:});
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
            updateAPIData@most.APIWrapper(mfilename('class'));
         end
         
         function waveGenerators = axes2waveGenerators(axesCell)
            % A utility function to map between axes and wave generators 
            % (which is nothing more than converting a string cell array to a numeric cell array).
            waveGenerators = num2cell(str2double(axesCell));
         end
         
    end
    
    %% ABSTRACT PROPERTY REALIZATION (most.MachineDataFile)
    %     properties (Constant,Hidden)
    %
    %        mdfClassName = ''; %opt out of MDF scheme , zlclMDFClassName();
    %        mdfHeading = 'PI E753 Controller';
    %
    %        mdfDependsOnClasses;
    %        mdfDirectProp;
    %        mdfPropPrefix;
    %     end
    
     
    %% ABSTRACT PROPERTY REALIZATION (dabs.pi.MotionController)
    properties (Constant, Hidden)
        controllerType = 'E753';
        GCSPrefix = 'E7XX_'; 
        useAxesComponentIndex = true;
        corePropertyExclusions = {'serialNumber' 'driftCompensation' 'startupMacro' 'maxVelocity'}; %PI: May also excluded voltageActual -- but this should work!
    end
    
    %% ABSTRACT PROPERTY REALIZATION (most.APIWrapper)
    
    %Following MUST be supplied with non-empty values for each concrete subclass
    properties (Constant, Hidden)
        apiPrettyName = 'E753 GCS2';  %A unique descriptive string of the API being wrapped         
        apiCompactName = 'E753_GCS2'; %A unique, compact string of the API being wrapped (must not contain spaces) 
        
        apiSupportedVersionNames = {'current'}; %A cell array of shorthand names (strings) for API versions supported by this wrapper class

        %Properties which can be indexed by version
        apiDLLNames = zlclPlatformDecorate('E7XX_GCS2_DLL'); %Either a single name of the DLL filename (sans the '.dll' extension), or a Map of such names keyed by values in 'apiSupportedVersionNames'
        apiHeaderFilenames = zlclAPIHeaderFilenames(); %Either a single name of the header filename (with the '.h' extension - OR a .m or .p extension), or a Map of such names keyed by values in 'apiSupportedVersionNames'
    end
    
    properties (SetAccess=protected, Hidden)
       apiHeaderFinalPaths = zlclPlatformPath();       
       apiAuxFile1Paths = ''; %E-753 driver installation does not include error-code file 
    end
    
    
end

%% LOCAL FUNCTIONS
function fname = zlclPlatformDecorate(fname)

switch computer()
    case 'PCWIN'
        %Do nothing
    case 'PCWIN64'        
        %Append '_x64' to filename
        [p,f,e] = fileparts(fname);                
        f = [f '_x64']; 
        fname = fullfile(p,[f e]);        
    otherwise
        assert(false);
end

end

function pname = zlclPlatformPath()

switch computer()
    case 'PCWIN'
        pname = fullfile(fileparts(mfilename('fullpath')),'private','Win32');
    case 'PCWIN64'
        pname = fullfile(fileparts(mfilename('fullpath')),'private','x64');
    otherwise
        error('Unsupported platform');
end

end

function fname = zlclAPIHeaderFilenames()
    switch computer()
        case 'PCWIN'
            fname = 'E7XX_GCS2_DLL_proto.m';            
        case 'PCWIN64'
            fname = 'E7XX_GCS2_DLL_x64_proto.m';
        otherwise
            error('Unsupported platform');            
    end 
end

