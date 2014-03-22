classdef LinearStageController < dabs.interfaces.LSCAnalogOption
    %LinearStageController Class adapting a concrete PI MotionController to dabs.interfaces.LSCAnalogOption
    
    % NOTES
    %   This class maintains handle to dabs.pi.gcs.MotionController object
    
    %% ABSTRACT PROPERTY REALIZATION (dabs.interfaces.LinearStageController)
    properties (Constant,Hidden)
        nonblockingMoveCompletedDetectionStrategy = 'poll'; % Either 'callback' or 'poll'. If 'callback', this class guarantees that moveDone() will be called when a nonblocking move is complete. See documentation for moveStartHook().
    end
    
    properties (SetAccess=protected,Dependent)
        infoHardware;
    end

    properties (SetAccess=protected,Dependent,Hidden)
        invertCoordinatesRaw;        
        velocityRaw;
        maxVelocityRaw;        
        
        %Unsupported properties -- no prop getters/setters defined, will
        %simply error
        accelerationRaw;
    end
    
    properties (SetAccess=protected, Hidden)
        resolutionRaw;
        
        positionDeviceUnits = 1e-6;
        velocityDeviceUnits = 1e-6;
        accelerationDeviceUnits = 1e-6;
    end        
     
    %% ABSTRACT PROPERTY REALIZATION (dabs.interfaces.LSCAnalogOption)
    
    properties (SetAccess=protected,Hidden)
        analogCmdEnableRaw = false
    end        
    
    %% SUPERUSER PROPERTIES
    properties (Hidden)
        moveFinishDelay=0; %Time, in seconds, to wait following reported finish        
    end
    
    %% DEVELOPER PROPERTIES
    
    properties (Hidden,Constant)
        LSC2MCMap = zlclInitLSC2MCMap();        
    end
        
    properties (Hidden,SetAccess=protected)
       hPI;   %Handle to PI Motion Controller object
       
       analogCmdEnableProp = ''; 
    end
        
        
    
    %% OBJECT LIFECYCLE    
    methods
        
        function obj = LinearStageController(varargin)
            % obj = LinearStageController(p1,v1,p2,v2,...)
            %
            % PV Args:
            %    controllerType: <REQUIRED> One of {'e517' 'e712' 'e816' 'e753'}
            %    comPort: <REQUIRED, if using RS232> Number specifiying COM port to which linear stage controller is connected
            %    baudRate: <REQUIRED, if using RS232> Specify baud rate to use during communication. Must match that set on hardware.
            %    resolutionBest: <OPTIONAL> Specify resolutionBest, in um, for device, which will be enforced as minimum tolerance for analog move completion determination
                                   

            %Process input args
            pvCell = most.util.filterPVArgs(varargin,{'controllerType' 'numDeviceDimenions' 'resolutionBest'},{'controllerType'});
            pvStruct = most.util.cellPV2structPV(pvCell);            
            controllerType = pvStruct.controllerType;
            
            %Construct PI motion controller device
            rootPackageName = 'dabs.pi';
            mp = meta.package.fromName(rootPackageName);            
            classNames = cellfun(@(x)x.Name,mp.Classes,'UniformOutput',0);
            
            [tf,idx] = ismember(lower(sprintf('%s.%s',rootPackageName,controllerType)),lower(classNames));
            if tf
                hPI = feval(classNames{idx},varargin{:});
            else
                error('Specified controller type (''%s'') not supported', controllerType);
            end                       
                        
            %Construct superclass
            numDeviceDimensions = length(hPI.axesNames);
            if isfield(pvStruct,'numDeviceDimensions')
                assert(isequal(numDeviceDimensions,pvStruct.numDeviceDimensions),'The specified ''numDeviceDimensions'' value is not valid for devices of type ''%s''.',class(hPI));
            end
            
            obj = obj@dabs.interfaces.LSCAnalogOption('numDeviceDimensions',numDeviceDimensions,varargin{:});
                        
            %Property initialization             
            obj.hPI = hPI;            
            obj.hPI.servoControlMode = true;
            
            if isfield(pvStruct,'resolutionBest')
                obj.resolutionBest = pvStruct.resolutionBest;
            end
            
            if isempty(obj.resolution)
                obj.resolution = obj.resolutionBest;
            end            
            
            analogCmdEnableProps = {'adcChannelForTarget' 'controlMode'}; %Props for E712/E753 & E517, respectively
            for i=1:length(analogCmdEnableProps)
                if ~isempty(findprop(obj.hPI, analogCmdEnableProps{i}))
                    obj.analogCmdEnableProp = analogCmdEnableProps{i};
                    break;
                end
            end
            

        end        

                
    end
    
    %% PROPERTY ACCESS METHODS
    
    methods
                
        function val = get.analogCmdEnableRaw(obj)
            switch obj.analogCmdEnableProp
                case 'adcChannelForTarget'
                    val = obj.hPI.adcChannelForTarget > 0;
                case 'controlMode'
                    val = obj.hPI.controlMode;
                otherwise
                    val = obj.analogCmdEnableRaw;
            end
        end
        
        function set.analogCmdEnableRaw(obj,val)            
            %Enable analog input control with appropriate software property, if any, for particular controller
            
            switch obj.analogCmdEnableProp %#ok<MCSUP>
                case 'adcChannelForTarget'
                    if val
                        obj.hPI.adcChannelForTarget = 2;
                    else
                        obj.hPI.adcChannelForTarget = 0;
                    end
                case 'controlMode'
                    obj.hPI.controlMode = val;
            end
            
            obj.analogCmdEnableRaw = val;                                   
        end
            
        function val = get.infoHardware(obj)
            val = obj.hPI.(obj.LSC2MCMap('infoHardware'));
        end
        
        function val = get.maxVelocityRaw(obj)                       
            %TODO: Determine if the 'open-loop slew rate' value can be used
            %   effectively to determine the maximum allowed velocity (servo loop slew rate) value
            %   There is no property, for /any/ controller, that directly reports the max velocity (servo loop slew rate)
                        
            val = nan;            
        end
        
        %         function val = get.resolutionBest(obj)
        %             if isempty(obj.resolutionBest)
        %                 if ~isempty(findprop(obj.hPI,'rangeLimitMin'))
        %                     range = obj.hPI.rangeLimitMax - obj.hPI.rangeLimitMin;
        %                     val = range / 2^12; %Use 2^12 as a typical/worst-case resoluton %TODO: Use worst of the AO & AI bit resolutions, rather than 2^12, in case where analog command is used
        %                 else
        %                     val = 0; %We don't have any idea in this case...
        %                 end
        %             else
        %                 val = obj.resolutionBest; %Use value set upon construction
        %             end
        %         end
        %
        %         function set.resolutionBest(obj,val)
        %             assert(isnumeric(val) && all(val) >= 0 && isfinite(val) && isvector(val) && ismember(numel(val),[1 obj.numDeviceDimensions]),'resolutionBest must be a positive scalar or array of size [1 numDeviceDimensions]');
        %             obj.resolutionBest = val;
        %         end
                    
        function val = get.velocityRaw(obj)
            MCPropName = obj.LSC2MCMap('velocity');
            if findprop(obj.hPI.(MCPropName))
                val = obj.hPI.(MCPropName);
            else
                val = nan;
            end                
        end          
        
        function set.velocityRaw(obj,val)
            MCPropName = obj.LSC2MCMap('velocity');
            if findprop(obj.hPI.(MCPropName))
                obj.hPI.(MCPropName) = val;
            end
        end
        
        function val = get.resolutionRaw(obj)
            if isempty(obj.resolutionRaw)           
                val = obj.resolutionBestRaw; %Use value set upon construction
            else
                val = obj.resolutionRaw;
            end               
        end        
        
    end
    
    %% ABSTRACT METHOD IMPLEMENTATIONS (dabs.interfaces.LSCAnalogOption)
    
    methods (Access=protected,Hidden)
        
        function moveStartDigitalHook(obj,targetPosn)
            obj.hPI.moveFinishForce(); %Force reset of PI.MotionController asyncMove flag -- relying on asyncMovePending flag in LSC instead
            obj.hPI.moveStart(targetPosn);
        end
        
        function tf = isMovingDigitalHook(obj)
            tf = obj.hPI.(obj.LSC2MCMap('isMoving'));
        end
        
        function posn = positionAbsoluteRawDigitalHook(obj)
            posn = obj.hPI.(obj.LSC2MCMap('positionAbsoluteRaw'));
        end
        
    end
    
    methods
        function voltage = analogCmdPosn2Voltage(obj,posn)
            
            %TODO: Handle PI device 'generality' (logic now specific to SystemParameterBasicProperties devices, e.g. E-516 & E-816) -- either via adaptor class, or via added MotionController smarts
            
            voltage = (posn / obj.hPI.kSen) + obj.hPI.oSen;
            
            %Ensure voltage fits within AO range
            voltage = min(max(voltage,obj.analogCmdOutputRange(1)),obj.analogCmdOutputRange(2));
        end
        
        function posn = analogSensorVoltage2Posn(obj,voltage)

            %TODO: Handle PI device 'generality' (logic now specific to SystemParameterBasicProperties devices, e.g. E-516 & E-816) -- either via adaptor class, or via added MotionController smarts
            
            posn = (voltage - obj.hPI.oSen) * obj.hPI.kSen;            
        end
    end
    
    %% ABSTRACT METHOD IMPLEMENTATIONS (dabs.interfaces.LinearStageController)
    
    methods (Access=protected,Hidden)        
        function recoverHook(obj)
            %Do nothing
        end
        
        function val = getResolutionBestHook(obj)
            %Return scalar value identifying best possible resolution that
            %can be expected, in positionDeviceUnits (microns)
            
            if ~isempty(findprop(obj.hPI,'rangeLimitMin'))
                range = obj.hPI.rangeLimitMax - obj.hPI.rangeLimitMin;
                val = (range / 2^12); %Use 2^12 as a typical/worst-case resoluton --  %TODO: Use worst of the AO & AI bit resolutions, rather than 2^12, in case where analog command is used
            else
                val = 0; %We don't have any idea in this case...
            end                        
        end
        
    end
    
end


function LSC2MCMap = zlclInitLSC2MCMap()

LSC2MCMap = containers.Map('KeyType','char','ValueType','char');

LSC2MCMap('positionAbsoluteRaw') = 'position';
LSC2MCMap('isMoving') = 'isMoving';
%LSC2MCMap('onTarget') = 'onTarget';
LSC2MCMap('infoHardware') = 'identificationString';
LSC2MCMap('velocity') = 'velocity';
LSC2MCMap('limitReached') = 'overflowStatus';



end
    

