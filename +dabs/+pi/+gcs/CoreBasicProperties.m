classdef CoreBasicProperties < handle
   
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties supported (at least) by the E-816 (plus any
    % other devices).
    %
    
    % Get-only props
    properties (GetObservable,SetObservable)
        position;                       % qPOS (E-517, E-712, E-816, E-753)
        positionCommand;                % qMOV (E-517, E-712, E-816, E-753) NOTE: this *can* be set, but defer to use of moveXXX() functions
        voltageActual;                  % qVOL (E-517, E-712, E-816, E-753)
        voltageCommand;                 % SVA (E-517, E-712, E-816, E-753)
        onTarget;                       % qONT (E-517, E-712, E-816, E-753)
        overflowStatus;                 % qOVF (E-517, E-712, E-816, E-753)

        axesNames;                      % SAI (E-517, E-816, E-753)
        servoControlMode;               % SVO (E-517, E-712, E-816, E-753)
        

        identificationString;           % qIDN (E-517, E-712, E-816, E-753)
        serialNumber;                   % qSSN (E-517, E-816); handled otherwise for E-712/E-753
    end
    
end