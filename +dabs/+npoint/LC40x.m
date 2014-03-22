classdef LC40x < handle
    %LC40x
    %   Detailed explanation goes here
    
    %% PUBLIC PROPERTIES
    
    properties
        rangeType; %One of {'microns' 'millimeters' 'uradians'}
        positionCommand;
        servoState; %Logical. True if servo circuit enabled       
        currentChannel; %Numeric scalar
    end
    
    properties(SetAccess=private)
        numChannelsConnected; %Number of channels physically connected to controller
        %TODO: Fix pid reads, using read array
        %         pidProportionalGain;
        %         pidIntegralGain;
        %         pidDerivativeGain;
        positionReading;
        range;
    end
    
    %% HIDDEN PROPERTIES
    properties (Hidden,SetAccess=private)
        hSerial; %Handle to MATLAB serial object        
    end
    
    properties (Hidden,Constant)
        CHAN_BASE_ADDRESS = hex2dec('11830000');
        CHAN_OFFSET = hex2dec('1000');
        DIGITAL_MAX_VAL = 524287;
    end
    
    
    %% LIFECYCLE
    methods
        
        function obj = LC40x(varargin)
            % obj = LC40x(p1,v1,p2,v2,...)
            %
            % P-V options:
            % comPort: (REQUIRED) Integer specifying COM port of serial device
            % baudRate: (OPTIONAL) Integer etc.
            %
            % See constructor documentation for
            % dabs.interfaces.RS232DeviceBasic and
            
            
            pv = most.util.filterPVArgs(varargin,{'comPort' 'baudRate'},{'comPort'});
            pv = most.util.cellPV2structPV(pv); %convert to struct
            
            if ~isfield(pv,'baudRate')
                pv.baudRate = 9600;
            end
            
            %             obj.hRS232 = dabs.interfaces.RS232DeviceBasic('comPort',pv.comPort,'baudRate',pv.baudRate);
            %             obj.hRS232.defaultTerminator = '7';
            obj.hSerial = serial(sprintf('com%d',pv.comPort),'baudRate',pv.baudRate);
            fopen(obj.hSerial);
            
            %Initializations
            obj.currentChannel = 1;
            
                  
        end
        
        function delete(obj)
            fclose(obj.hSerial);
            delete(obj.hSerial);
        end
      
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        
        function set.currentChannel(obj,val)
            validateattributes(val,{'numeric'},{'scalar' 'integer' 'positive'});
            assert(val <= obj.numChannelsConnected,'Invalid channel specified: controller has only %d channels',val); %#ok<*MCSUP>
            
            obj.currentChannel = val;        
        end
        
        function val = get.numChannelsConnected(obj)
            val = 255 - obj.zprpReadLocation('118303A0','int32');
        end
        
        function val = get.positionCommand(obj)
            digVal = obj.zprpReadChannelLocation('218','int32');
            val = (digVal/ obj.DIGITAL_MAX_VAL) * (obj.range / 2);

        end
        
        function set.positionCommand(obj,val)
            obj.zprpWriteChannelLocation('218','int32',(obj.DIGITAL_MAX_VAL * 2 / obj.range) * val);
        end

        function val = get.positionReading(obj)
            digVal = obj.zprpReadChannelLocation('334','int32');            
            val = (digVal / obj.DIGITAL_MAX_VAL) * (obj.range / 2);
        end

        %         function val = get.pidDerivativeGain(obj)
        %             val = obj.zprpReadChannelLocation('730','double');
        %         end
        %
        %
        %         function val = get.pidIntegralGain(obj)
        %             val = obj.zprpReadChannelLocation('728','double');
        %         end
        %
        %
        %         function val = get.pidProportionalGain(obj)
        %             val = obj.zprpReadChannelLocation('720','double');
        %         end
        %
        function val = get.range(obj)
            persistent range
            if isempty(range)
                range = obj.zprpReadChannelLocation('78','int32');
            end
            val = range;
        end

        function val = get.rangeType(obj)
           val = obj.zprpReadChannelLocation('44','int32'); 
        end
                
        function val = get.servoState(obj)
            val = obj.zprpReadChannelLocation('84','int32');
        end
                
        function set.servoState(obj,val)
            obj.zprpWriteChannelLocation('84','int32',val);
        end


    end
    
    methods (Hidden)

        function val = zprpReadChannelLocation(obj,hexOffset,dataType)
         
            hexAddress = hex2dec(hexOffset) + obj.CHAN_BASE_ADDRESS + (obj.currentChannel * obj.CHAN_OFFSET);
            val = obj.zprpReadLocation(dec2hex(hexAddress), dataType);
        end

        function val = zprpReadLocation(obj,hexLocation,dataType)

            %Flush input buffer
            ba = obj.hSerial.BytesAvailable;
            if ba > 0
               fread(obj.hSerial,ba);
            end
            
            %Send read command
            fwrite(obj.hSerial,hex2dec('a0'));
            fwrite(obj.hSerial,hex2dec(hexLocation),dataType);
            fwrite(obj.hSerial,hex2dec('55'));

            %Parse reply
            resp = fread(obj.hSerial,1); %acknowledge byte
            assert(strcmpi(dec2hex(resp),'A0'));
            
            resp = fread(obj.hSerial,1,'uint32'); %address echo
            assert(strcmpi(dec2hex(resp),hexLocation));

            val = fread(obj.hSerial,1,dataType); %data payload
            
            resp = fread(obj.hSerial,1); %terminator
            assert(strcmpi(dec2hex(resp),'55'));
        end

        function zprpWriteChannelLocation(obj,hexOffset,dataType,data)
            hexAddress = hex2dec(hexOffset) + obj.CHAN_BASE_ADDRESS + (obj.currentChannel * obj.CHAN_OFFSET);
            obj.zprpWriteLocation(dec2hex(hexAddress), dataType, data);
        end
            
        function zprpWriteLocation(obj,hexLocation,dataType,data)
            
            %Send write command
            fwrite(obj.hSerial,hex2dec('a2'));
            fwrite(obj.hSerial,hex2dec(hexLocation),dataType);
            fwrite(obj.hSerial,data,dataType);
            fwrite(obj.hSerial,hex2dec('55'));            
        end
        
    end
                
        
        

end