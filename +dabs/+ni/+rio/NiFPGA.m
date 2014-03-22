classdef NiFPGA < dynamicprops
    %   A class to communicate with a National Instruments FPGA via the
    %   NI FPGA Interface C API. This class parses the .lvbtix file
    %   directly without the need of a headerfile.
    %   
    %   Implemented so far:
    %       - Read and Write Boolean and Integer Registers
    %       - Read and Write Enums, both as strings and integer values
    %         (see property returnEnumsAsStrings)
    %       - Read and Write FIFOs
    %   Arrays not yet implemented
    %   Clusters and Fixed Point not supported by C-Api
    %
    %   The registers are added as dynamic properties during
    %   the construction of the object.
    %   Reading the property polls the register on the FPGA.
    %   Writing a property sets the register on the FPGA.
    
    properties (SetAccess = private)
        rioDeviceID = '';
        session = 0;
        bitFileName;
        bitFileSignature;        
    end
   
    %% HIDDEN PROPS
    properties (Hidden, SetAccess=private)
        registerMap;
    end
    
    properties (Hidden)
        returnEnumsAsStrings = true; % if true, properties of datatype Enum are returned as their string description. if false, their integer value is returned
    end
    
    properties (Constant,Access = private)
        dllRelPath = 'private';
        dllName = 'NiFpgaWrapper';
        headerName = 'NiFpgaWrapper.h';
        
        %Arrays, Clusters and fixed point data types are not supported yet        
        matlabDataTypeMap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64', 'EnumU8', 'EnumU16', 'EnumU32', 'EnumU64'},...
            {'uint8', 'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'});
        fpgaWriteMethodMap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64', 'EnumU8', 'EnumU16', 'EnumU32', 'EnumU64'},...
            {'NiFpga_WriteBool', 'NiFpga_WriteU8', 'NiFpga_WriteU16', 'NiFpga_WriteU32', 'NiFpga_WriteU64', 'NiFpga_WriteI8', 'NiFpga_WriteI16', 'NiFpga_WriteI32', 'NiFpga_WriteI64', 'NiFpga_WriteU8', 'NiFpga_WriteU16', 'NiFpga_WriteU32', 'NiFpga_WriteU64'});
        fpgaReadMethodMap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64', 'EnumU8', 'EnumU16', 'EnumU32', 'EnumU64'},...
            {'NiFpga_ReadBool', 'NiFpga_ReadU8', 'NiFpga_ReadU16', 'NiFpga_ReadU32', 'NiFpga_ReadU64', 'NiFpga_ReadI8', 'NiFpga_ReadI16', 'NiFpga_ReadI32', 'NiFpga_ReadI64', 'NiFpga_ReadU8', 'NiFpga_ReadU16', 'NiFpga_ReadU32', 'NiFpga_ReadU64'});
    end
    
    %% Lifecycle
    methods
        function obj = NiFPGA(bitFileName,simulated)
            if nargin < 2 || isempty(simulated)
                simulated = false;
            end
            
            if ~ischar(bitFileName)
                error('Bitfile name must be a string (e.g. ''MyBitfile.lvbitx'')');
            elseif exist(bitFileName, 'file') ~= 2
                error('File %s does not exist',bitFileName);
            end
            
            classpath = fileparts(mfilename('fullpath'));
            
            if ~libisloaded(obj.dllName)
                
                dllpath = fullfile(classpath,obj.dllRelPath,obj.dllName);
                headerpath = fullfile(classpath,obj.dllRelPath,obj.headerName);
                loadlibrary(dllpath,headerpath);
            end
            
            if (~simulated)
                obj.nifpgaCall('NiFpga_Initialize');
            end
            
            obj.bitFileName = bitFileName;
            obj.parseBitFile();
        end
        
       function delete(obj,noResetIfLastSession)
           if nargin < 2 || isempty(noResetIfLastSession)
               noResetIfLastSession = false;
           end
           
            if libisloaded(obj.dllName)
                if obj.session ~= 0
                   obj.closeSession(noResetIfLastSession);
                end
                
                obj.nifpgaCall('NiFpga_Finalize');
                %better not unload the library here, since other objects might still use it
                %unloadlibrary(obj.dllName); % do not unload the library
            end
        end  
    end
    
    %% Public Methods
    methods      
        function openSession(obj,rioDeviceID)
            if nargin < 2 || isempty(rioDeviceID)
                rioDeviceID = 'RIO0';
            end
            
            validateattributes(rioDeviceID,{'char'},{'vector','nonempty'});
           
            [~,~,~,obj.session] = obj.nifpgaCall('NiFpga_Open',which(obj.bitFileName),...
                    obj.bitFileSignature,rioDeviceID,uint32(0),0);
            
            obj.rioDeviceID = rioDeviceID;
        end
        
        function closeSession(obj,noResetIfLastSession)
           if nargin < 2 || isempty(noResetIfLastSession)
               noResetIfLastSession = false;
           else
               validateattributes(noResetIfLastSession,{'logical'},{});
           end

           if obj.session == 0
              warning('No active session');
           else
               %NiFpga_Status NiFpga_Close(NiFpga_Session session, uint32_t attribute)
               obj.nifpgaCall('NiFpga_Close',obj.session,uint32(noResetIfLastSession));
               obj.session = 0;
           end
        end
        
        function run(obj)
            if obj.session == 0
                warning('No active session');
            else
                %NiFpga_Status NiFpga_Run(NiFpga_Session session, uint32_t attribute)
                obj.nifpgaCall('NiFpga_Run',obj.session,0);
            end  
        end
        
        function abort(obj)
            if obj.session == 0
                warning('No active session');
            else
                %NiFpga_Status NiFpga_Abort(NiFpga_Session session)
                obj.nifpgaCall('NiFpga_Abort',obj.session,0);
            end  
        end

        function reset(obj)
            if obj.session == 0
                warning('No active session');
            else    
                %NiFpga_Status NiFpga_Reset(NiFpga_Session session)
                obj.nifpgaCall('NiFpga_Reset',obj.session);
            end  
        end
        
        function download(obj)
            if obj.session == 0
                warning('No active session');
            else
                %NiFpga_Status NiFpga_Download(NiFpga_Session session)
                obj.nifpgaCall('NiFpga_Download',obj.session);
            end  
        end
    end
    
    %% Hidden Methods
    methods (Hidden)   
        
        
        function parseBitFile(obj)
            xDoc = xmlread(obj.bitFileName);
            
            % get bitfile signature
            xSignature = xDoc.getElementsByTagName('SignatureRegister');
            xSignature = xSignature.item(0);
            obj.bitFileSignature = char(xSignature.getFirstChild.getData);
            
            
            %get fifos
            xDmaChAllocList = xDoc.getElementsByTagName('DmaChannelAllocationList');
            xDmaChAllocList = xDmaChAllocList.item(0);
            xDmaChs = xDmaChAllocList.getElementsByTagName('Channel');
            for k = 0:xDmaChs.getLength-1;
                xDmaCh = xDmaChs.item(k);
                fifoname = char(xDmaCh.getAttribute('name'));    
                fifoname = regexprep(fifoname,'[^\w\d'']','');
                fifoname = sprintf('fifo_%s',fifoname);
               
                xNumber = xDmaCh.getElementsByTagName('Number');
                xNumber = xNumber.item(0);
                fifonumber = uint32(str2double(char(xNumber.getFirstChild.getData)));
                
                xDatatype = xDmaCh.getElementsByTagName('SubType');
                xDatatype = xDatatype.item(0);
                fifodatatype = char(xDatatype.getFirstChild.getData);
                
                xDirection = xDmaCh.getElementsByTagName('Direction');
                xDirection = xDirection.item(0);
                fifodirection = char(xDirection.getFirstChild.getData);
                
                fifomatlabdatatype = obj.matlabDataTypeMap(fifodatatype);
                
                proph = obj.addprop(fifoname);
                proph.GetAccess = 'public';
                proph.SetAccess = 'private';
                
                obj.(fifoname) = dabs.ni.rio.NiFIFO(obj,fifoname,fifodirection,fifonumber,fifodatatype,fifomatlabdatatype);

            end
 
            %get registers
            obj.registerMap = containers.Map();
            
            xRegisterList = xDoc.getElementsByTagName('RegisterList');
            xRegisterList = xRegisterList.item(0);
            xRegisters = xRegisterList.getElementsByTagName('Register');
            
            for k = 0:xRegisters.getLength-1;
                regprops = {};
                xRegister =  xRegisters.item(k);
                
                %get the register name
                xName = xRegister.getElementsByTagName('Name');
% TODO this needs to be improved
                xName = xName.item(1);

                
                if ~isempty(xName.getFirstChild)
                    name = char(xName.getFirstChild.getData);
                    name = regexprep(name,'[^\w\d'']',''); %remove all special characters from name


                    %get the register datatype
                    xDatatype = xRegister.getElementsByTagName('Datatype');
                    xDatatype = xDatatype.item(0);
                    xDatatype = xDatatype.getFirstChild;
                    xDatatype = xDatatype.getNextSibling; %Compensate for the newline character
                    regprops.datatype = char(xDatatype.getTagName);
                    
                    if ~isKey(obj.matlabDataTypeMap,regprops.datatype)
                       warning('Datatype %s of register %s is not supported. Register is not added to object.', ...
                           regprops.datatype,name);
                       continue; %skip to the next Register
                    end
                    
                    regprops.matlabdatatype = obj.matlabDataTypeMap(regprops.datatype);
                    regprops.fpgawritemethod = obj.fpgaWriteMethodMap(regprops.datatype);
                    regprops.fpgareadmethod = obj.fpgaReadMethodMap(regprops.datatype);

                    %get the register offset
                    xOffset = xRegister.getElementsByTagName('Offset');
                    xOffset = xOffset.item(0);
                    regprops.offset = uint32(str2double(char(xOffset.getFirstChild.getData)));
                    
                    %check if datatype is of type Enum
                    if ~isempty(strfind(regprops.datatype,'Enum'));
                       enumStrings = {};
                       enumValues = {};
                       xStringList = xRegister.getElementsByTagName('StringList');
                       xStringList = xStringList.item(0);
                       xStringArray = xStringList.getElementsByTagName('String');
                       for l = 0:xStringArray.getLength-1;
                           xString = xStringArray.item(l);
                           xString = xString.getFirstChild;
                           if isempty(xString)
                               string = '';
                           else
                               string = char(xString.getData);
                           end
                           enumValues{l+1} = cast(l, regprops.matlabdatatype); %#ok<AGROW>
                           enumStrings{l+1} = string; %#ok<AGROW>
                       end
                       enumValToStr = containers.Map(enumValues,enumStrings);
                       enumStrToVal = containers.Map(enumStrings,enumValues);
                       regprops.enumValToStr = enumValToStr;
                       regprops.enumStrToVal = enumStrToVal;
                    end

                    % add the dynamic property to the object. Make sure
                    % if two registers have same name or name of register
                    % matches a method of the class, append a suffix
                    suffix = 0;
                    namewithsuffix = name;
                    while isprop(obj,namewithsuffix) || ismethod(obj,namewithsuffix)
                        suffix = suffix + 1;
                        namewithsuffix = sprintf('%s_%d',name,suffix);
                    end
                    name = namewithsuffix;
                        
                    obj.registerMap(name) = regprops;
                    proph = obj.addprop(name);
                    proph.GetObservable = true;
                    proph.SetObservable = true;
                    proph.GetAccess = 'public';
                    proph.SetAccess = 'public';
                    obj.addlistener(name,'PostSet',@obj.dynPropPostSetEvents);
                    obj.addlistener(name,'PreGet',@obj.dynPropPreGetEvents);
                end  
            end 
        end
        
        function varargout = nifpgaCall(obj,funcName,varargin)
            varargout = cell(nargout,1);
            [status, varargout{:}] = calllib(obj.dllName,funcName,varargin{:});

            statusString = sprintf('NI RIO Driver Status Code: %d',status);

            if status > 0
                warning(statusString); %#ok<WNTAG,SPWRN>
            elseif status < 0
                error(statusString); %#ok<SPERR>
            end
        end
        
        function dynPropPostSetEvents(obj,src,~)
            % while manipulating the property, deactivate its eventlistener
            src.SetObservable = false;
            src.GetObservable = false;
            try
                propName = src.Name; %get the property name

                if obj.session == 0
                    %warning('No active FPGA session');
                    obj.(propName) = [];
                else                
                    r = obj.registerMap(propName);
                    val = obj.(propName); %get the property value

                    % translate enum char into integer value
                    if isfield(r,'enumStrToVal') && isfield(r,'enumValToStr')
                       if ischar(val);
                           enumStrToVal = getfield(r,'enumStrToVal'); %#ok<GFLD>
                           
                           %Workaround for Matlab R2012a
                           if exist('strjoin','builtin')
                               assert(isKey(enumStrToVal,val),...
                                   '''%s'' is not a valid value for Enum property %s. Valid Values are:\n\t''%s',...
                                   val,propName,strjoin(enumStrToVal.keys,'''\n\t'''));
                           else
                               assert(isKey(enumStrToVal,val),...
                                   '''%s'' is not a valid value for Enum property %s',...
                                   val,propName);                              
                           end
                           val = enumStrToVal(val);
                       else
                           enumValToStr = getfield(r,'enumValToStr'); %#ok<GFLD>
                           keys = enumValToStr.keys;
                           assert(isKey(enumValToStr,val),...
                               '%s is not a valid value for Enum property %s. Valid Values are one of: {%s\b\b}',...
                               num2str(val),propName,sprintf('%d, ',keys{:}));
                       end
                    end

                    assert(isscalar(val),'Register %s cannot be assigned nonscalar values',propName);
                    castval = cast(val, r.matlabdatatype);
                    if val ~= castval
                        warning([propName ' is of datatype ' r.matlabdatatype ...
                            '. Value ' num2str(val) ' coerced to ' num2str(castval)]);
                    end
                    obj.nifpgaCall(r.fpgawritemethod,obj.session,r.offset,castval);
                    obj.(propName) = castval;
                end
            catch ME
                % if setting the property fails, rearm its events
                src.SetObservable = true;
                src.GetObservable = true;
                rethrow(ME);
            end
            % rearm events for the property
            src.SetObservable = true;
            src.GetObservable = true;
        end
        
        function dynPropPreGetEvents(obj,src,~)            
            % while manipulating the property, deactivate eventlistener for
            % the property
            src.SetObservable = false;
            src.GetObservable = false;
            
            try
                propName = src.Name; %get the property name

                if obj.session == 0
                    %warning('No active FPGA session');
                    obj.(propName) = [];
                else
                    r = obj.registerMap(propName);
                    val = zeros(1,r.matlabdatatype); %preallocate datatype
                    val = obj.nifpgaCall(r.fpgareadmethod,obj.session,r.offset,val);

                    %handle enums
                    if obj.returnEnumsAsStrings && isfield(r,'enumValToStr')
                       enumValToStr = getfield(r,'enumValToStr'); %#ok<GFLD>
                       if isKey(enumValToStr,val) %handle out of bound values gracefully
                           val = enumValToStr(val);
                       end
                    end

                    obj.(propName) = val;
                end
            catch ME
                % if setting the property fails, rearm its events
                src.SetObservable = true;
                src.GetObservable = true;
                rethrow(ME);
            end
            % rearm events for the property
            src.SetObservable = true;
            src.GetObservable = true;
        end
    end  
end

