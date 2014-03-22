classdef MatrixSystemParameterProperties < handle
    %   Detailed explanation goes here

    
    %% DEVICE PROPERTIES (Pseudo-Dependent)
    properties (GetObservable, SetObservable)
        axisToOutputSignalMatrix; %'Driving Factor of Piezo #'
        axisToInputSignalMatrix; %'Position from Sensor #'            
        
    end
    
    %% PROTECTED/PRIVATE PROPERTIES
    
    properties (SetAccess=protected)
       matrixSystemParamDataMap = initMatrixSystemParamDataMap();        
    end    
    

end

%% HELPERS

function matrixSystemParamDataMap = initMatrixSystemParamDataMap()

matrixSystemParamDataMap = containers.Map();

matrixSystemParamDataMap('axisToOutputSignalMatrix') = struct('number',14,'startAddress',150994944,'axisDim',2);
matrixSystemParamDataMap('axisToInputSignalMatrix') = struct('number',14,'startAddress',117441792 ,'axisDim',1);

end

