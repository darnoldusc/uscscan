classdef SystemParameterExtendedProperties < handle
   
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties representing PI "System Parameters"
    % common to all supported GCS controllers EXCEPT E-816
    
    properties (GetObservable,SetObservable)
        %SystemParameter properties     
        sensorCorrectionZeroOrder;
        sensorCorrectionFirstOrder;
        digitalFilterType;
        digitalFilterBandwidth;
        digitalFilterOrder;
        filterParamA0;
        filterParamA1;
        filterParamB0;
        filterParamB1;
        filterParamB2;
        rangeLimitMin;
        rangeLimitMax;
        servoLoopSlewRate;
        positionOne;
        positionTwo;
        positionThree;
        axisName;
        axisUnit;
        onTargetTolerance;
        defaultVoltage;
        axisServoMode;
        piezoOneDriving;
        piezoTwoDriving;
        piezoThreeDriving;
        outputVoltageMin;
        outputVoltageMax;
        offset;
        setVoltageMin;
        setVoltageMax;
        serialNumberDevice;
        serialNumberHardware;
        hardwareName;
        hardwareRevision;
        sensorSamplingTime;
        servoUpdateTime;
        numberOfSensorChannelsSystemParam; % break from naming convention due to name collision with corresponding GCS property
        numberOfPiezoChannelsSystemParam;
        numberOfTriggerOutputs;
        rs232BaudRate;
        maxWavePoints;
        waveGeneratorTableRateSystemParam;
        numberOfWaveTables;
        waveOffsetSystemParam;
        tableRate;
        numberOfChannelsMax;
        recordPointsMax;
    end
    
end