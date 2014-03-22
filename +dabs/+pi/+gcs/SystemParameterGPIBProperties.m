classdef SystemParameterGPIBProperties < handle
   
    %% DEVICE PROPERTIES (Pseudo-Dependent)
    %  Properties related to GPIB interfacing, which are PI "System Parameters"  
    
    properties (GetObservable,SetObservable)
        gpibAddress;
        gpibEnable;
    end
    
end