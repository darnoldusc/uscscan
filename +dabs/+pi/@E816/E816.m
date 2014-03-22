classdef E816 < dabs.pi.gcs.MotionController & dabs.pi.gcs.SystemParameterBasicProperties & dabs.pi.gcs.WaveTableProperties
   
    %% ABSTRACT PROPERTY REALIZATION (dabs.pi.MotionController)
    properties (Constant, Hidden)
        controllerType = 'E816';
        GCSPrefix = 'E816_'; 
        useAxesComponentIndex = false;
        corePropertyExclusions = {}; 
    end
    
    %% ABSTRACT PROPERTY REALIZATION (most.MotionController)
    properties (Constant,Hidden)
        
       mdfClassName = zlclMDFClassName();
       mdfHeading = 'PI E816 Controller';
       
       mdfDependsOnClasses;
       mdfDirectProp;
       mdfPropPrefix;
    end        
    
    %% ABSTRACT PROPERTY REALIZATION (most.APIWrapper)
    
    %Following MUST be supplied with non-empty values for each concrete subclass
    properties (Constant, Hidden)
        apiPrettyName = 'E816 GCS';  %A unique descriptive string of the API being wrapped         
        apiCompactName = 'E816_GCS'; %A unique, compact string of the API being wrapped (must not contain spaces) 
        
        apiSupportedVersionNames = {'current'}; %A cell array of shorthand names (strings) for API versions supported by this wrapper class

        %Properties which can be indexed by version
        apiDLLNames = zlclPlatformDecorate('E816_DLL'); %Either a single name of the DLL filename (sans the '.dll' extension), or a Map of such names keyed by values in 'apiSupportedVersionNames'
        apiHeaderFilenames = zlclAPIHeaderFilenames(); %Either a single name of the header filename (with the '.h' extension - OR a .m or .p extension), or a Map of such names keyed by values in 'apiSupportedVersionNames'
    end    

    properties (SetAccess=protected, Hidden)
        %apiHeaderFinalPaths = zlclApiHeaderFinalPaths();
        apiHeaderFinalPaths = zlclPlatformPath();
        %apiDLLPaths = zlclAPIDLLPaths();
        
        apiAuxFile1Paths = zlclAPIAuxFile1Paths();
    end
    
    
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties supported by E-816 (exclusive, or not within any other property category)
    
    % Get-only props
    properties (GetObservable,SetObservable)
        I2CState;                       % qI2C (E-816)
        
        startupMacro;                   % MAC_qDEF (E-517, E-816)        
        driftCompensation;              % DCO (E-517, E-816)
        
        rs232BaudRate;                  % qBDR (E-816)
    end
    
    % Set and Get props
    properties (GetObservable,SetObservable)
        samplesPerAverage;              % AVG (E-816)
        moveTriggered;                  % MVT (E-816)
        channelName;                    % SCH (E-816)
    end

    
    %% CONSTRUCTOR/DESTRUCTOR      
    
    methods
        
        function obj = E816(varargin)
            % Constructs a dabs.pi.E816 device object
            %
            % Prop-Value pair args
            % connectionType: <OPTIONAL - Default='rs232'> Specify the connection protocol to use. One of {'rs232' 'usb' 'ethernet'}.
            % comPort: (REQUIRED IF CONNECTION IS RS232) Number specifiying COM port to which controller is connected
            % baudRate: <OPTIONAL - Default=115200> Specify baud rate to use during communication. Must match that set on hardware.
            
            %Call superclass constructor       
            obj = obj@dabs.pi.gcs.MotionController(varargin{:});                                    
        end
 
    end
    
    
    methods (Hidden)
       
        function val = getWaveTableData(obj)
            % Reads in the current wave table data (overrides MotionController)
            
            val = repmat({zeros(1,64)},1,length(obj.axesActive));
            
            j = 1;
            for axis = [obj.axesActive{:}]
                for i = 1:64
                    val{j}(i) = obj.GCSCall('getwaveTableData',true,axis,i-1,0);
                end
                j = j + 1;
            end
        end
        
    end
    
    
    %     %% METHOD OVERRIDES (most.APIWrapper)
    %
    %     methods (Access=protected)
    %         function smartLoadLibrary(obj,varargin)
    %
    %             %Suppress 'enumeration exists' warning. Different ThorDevice classes may have headers defining the same enumeration, possibly with contradictory definitions, e.g. the Params enum
    %             %However, this class does not make any known use of enumeration arguments, so this warning is, for practical purposes, immaterial
    %
    %             s = warning('query','all');
    %             warning('off','MATLAB:loadlibrary:EnumExists');
    %             smartLoadLibrary@most.APIWrapper(obj,{'windows.h'},varargin{:});
    %             warning(s);
    %         end
    %     end
    
    %% STATIC METHODS
    
    methods (Static)
        
         function updateAPIData()
            updateAPIData@most.APIWrapper(mfilename('class'));
         end
         
     end
end


%% LOCAL FUNCTIONS

% function val = zlclApiHeaderFinalPaths()
% 
% switch computer()
%     case 'PCWIN'
%         val = fullfile(most.idioms.startPath,'program files','pi','e-816','e816_dll');
%     case 'PCWIN64'
%         val = fullfile(most.idioms.startPath,'program files (x86)','pi','e-816','e816_dll');
%     otherwise
%         assert(false);
% end
% 
% end
% 

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

function mdfClassName = zlclMDFClassName()

switch computer()
    case 'PCWIN'
        mdfClassName = ''; %Opt out of MDF scheme
    case 'PCWIN64'
        mdfClassName = mfilename('class');
    otherwise
        error('Unsupported platform');
end

end

function fname = zlclAPIHeaderFilenames()

    %Currently using r2010b prototype files for all cases
    switch computer()
        case 'PCWIN'
            fname = 'E816_DLL_proto_r2010b.m';
        case 'PCWIN64'
            fname = 'E816_DLL_x64_proto_r2010b.m';
        otherwise
            error('Unsupported platform');            
    end 
    
end

% function pname = zlclAPIDLLPaths()
% 
% switch computer()
%     case 'PCWIN'
%         pname = fullfile(most.idioms.startPath,'program files','pi','e-816','e816_dll');
%     case 'PCWIN64'
%         pname = []; %Signals to rely on MDF value
%     otherwise
%         error('Unsupported platform');
% end
% 
% end

function pname = zlclAPIAuxFile1Paths()

switch computer()
    case 'PCWIN'
        pname =fullfile(most.idioms.startPath,'program files','pi','e-816','e816_dll'); %Really expect the path to be there -- if not, errors will throw downstream
    case 'PCWIN64'
        pname =fullfile(most.idioms.startPath,'program files (x86)','pi','e-816','e816_dll'); %Really expect the path to be there -- if not, errors will throw downstream

        %Handle case where 32-bit driver wasn't installed
        if ~isdir(pname)
            pname = '';
        end

    otherwise
        error('Unsupported platform');
end


end