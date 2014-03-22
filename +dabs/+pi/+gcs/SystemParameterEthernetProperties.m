classdef SystemParameterEthernetProperties < handle
   
    %% DEVICE PROPERTIES (Pseudo-Dependent)
    %  Properties related to GPIB interfacing, which are PI "System Parameters"  
    
    properties (GetObservable,SetObservable)
        ethernetIPAddress;
        ethernetIPMask;
        ethernetIPConfig;
        ethernetIPMACAddress;
    end
    
end