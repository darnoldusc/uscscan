classdef CoreExtendedProperties < handle
   
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties not supported by the E-816, but
    % supported by all other known GCS controllers (E-517, E-712, E-753)
    %
    
    % Get-only props
    properties (GetObservable,SetObservable)
        autoZeroDone;                   % qATZ (E-517, E-712, E-753)
        positionCommandMin;             % qTMN (E-517, E-712, E-753)
        positionCommandMax;             % qTMX (E-517, E-712, E-753)
        numberOfPiezoChannels;          % qTPC (E-517, E-712, E-753)
        numberOfSensorChannels;         % qTSC (E-517, E-712, E-753)
        sensorPosition;                 % qTSP (E-517, E-712, E-753)
        
        adValue;                        % qTAD (E-517, E-712, E-753)
       
        dataRecordTables;               % qDRR (E-517, E-712, E-753)
        numberOfDataRecordTables;       % qTNR (E-517, E-712, E-753)

        helpStringDataRecording;        % qHDR (E-517, E-712, E-753)
        helpString;                     % qHLP (E-517, E-712, E-753)
        helpStringAvailableParams;      % qHPA (E-517, E-712, E-753) 
    end
    
    % Set-only props
    properties (SetObservable)
    end
    
    % Get and Set props
    properties (GetObservable,SetObservable)
        commandLevel;                   % CCL (E-517, E-712, E-753)
        velocity;                       % VEL (E-517, E-712, E-753)
        
        triggerOutputConditions;        % CTO (E-517, E-712, E-753)
        dataRecorderConfig;             % DRC (E-517, E-712, E-753)
        
        interfaceConfig;                % IFC (E-517, E-712) %%
        interfaceConfigStore;           % IFS (E-517, E-712) %% DEQ - maybe these two shouldn't be props, just helper functions?


    end
    
end