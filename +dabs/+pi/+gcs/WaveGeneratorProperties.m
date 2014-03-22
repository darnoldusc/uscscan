classdef WaveGeneratorProperties < handle
   
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties specific to wave-generator functionality
    %
    
    % Get-only props
    properties (GetObservable,SetObservable)
        isWaveGeneratorRunning;         % IsGeneratorRunning (E-517, E-712)
        numberOfWaveGenerators;         % qTWG (E-517, E-712)
        waveTablePoints;                % qWAV (E-517, E-712)
        waveTableData;                  % qGWD (E-517, E-712)
    end
    
    % Get and Set props
    properties (GetObservable,SetObservable)
        waveGeneratorCycles;            % WGC (E-517, E-712)
        waveGeneratorOffset;            % WOS (E-517, E-712)
        waveTableSelection;             % WSL (E-712)
        waveGeneratorTableRate;         % WTR (E-517, E-712)
    end
    
end