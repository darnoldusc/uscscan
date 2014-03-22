classdef SystemParameterBasicProperties < handle
   
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties representing PI "System Parameters"
    % (common to E-516 and E-816)
    
    properties (GetObservable,SetObservable)
        %SystemParameter properties     
        vadGain;
        vadOffset;
        padGain;
        padOffset;
        daGain;
        daOffset;
        kSen;
        oSen;
        kPZT;
        oPZT;
    end
    
    
    %Compute some of the properties that are included in SystemParameterExtendedProperties and include as dependent properties, for maximum homology
    %TODO: Refine the implementations of rangeLimitMin/Max and outputVoltageMin/Max...perhaps they should determine, rather than depend on command/sensorVoltageRange values
    properties (Dependent)
        setVoltageMin;
        setVoltageMax;
        
        rangeLimitMin;
        rangeLimitMax;
        
        outputVoltageMin;
        outputVoltageMax;
                
    end
    
    methods
        function val = get.setVoltageMin(obj) 
            val = obj.oPZT;
        end
        
        function val = get.setVoltageMax(obj)
            val = obj.oPZT + obj.sensorVoltageRange*obj.kPZT; %#ok<MCNPN>
        end
        
        function val = get.rangeLimitMin(obj)
            val = 0;
        end
        
        function val = get.rangeLimitMax(obj)
            val = obj.kSen * obj.sensorVoltageRange;
        end
        
        function val = get.outputVoltageMin(obj)
            val = 0;
        end
        
        function val = get.outputVoltageMax(obj)
            val = obj.sensorVoltageRange; 
        end

    end
        
    
end