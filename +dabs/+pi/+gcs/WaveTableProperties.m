classdef WaveTableProperties < handle
   
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties specific to wave-table functionality
    %
    
    % Get and Set props
    properties (GetObservable,SetObservable)
        waveTableData;                  % SWT (E-816)         
    end
    
end