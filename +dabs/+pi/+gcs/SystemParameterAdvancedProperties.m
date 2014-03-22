classdef SystemParameterAdvancedProperties < handle
   
    %% DEVICE PROPERTIES
    % 'Pseudo-dependent' properties representing PI "System Parameters"
    % supported by E-712 & E-753 controllers
    
    properties (GetObservable,SetObservable)
        %SystemParameter properties     
        sensorRangeFactor;
        sensorBoardGain;
        sensorOffsetFactor;
        sensorCableCompensation;
        %autoZeroMatchedOffset; %PI: Listed in E-712 manual, but does not appear to work
        adcChannelForTarget;
        analogTargetOffset
        openLoopSlewRate;
        servoLoopP
        servoLoopI;
        servoLoopD;
        powerUpServoOnEnable;
        powerUpAutoZeroEnable;
        settingTime;
        autoZeroLowVoltage;
        autoZeroHighVoltage;
        positionReportScaling;
        positionReportOffset;
        notchFrequency1;
        notchFrequency2;
        notchRejection1;
        notchRejection2;
        notchBandwidth1;
        notchBandwidth2;
        creepFactor1;
        creepFactor2;
        selectOutputType;
        selectOutputIndex;
        numberOfInputChannels;
        numberOfOutputChannels;
        numberOfSystemAxes;
        powerUpReadIDChip;
        stageType;
        stageSerialNumber;
        stageAssemblyDate;
        macAddress;
        maxDDLPoints;
        autoCalTimeDelayFactor;
        autoCalMinMaxTimeDelayFactor;
        dataRecorderChannelNumber;
        firmwareMark;
        firmwareCRC;
        firmwareDescCRC;
        firmwareDescVersion;
        firmwareMatchcode;
        hardwareMatchcode;
        firmwareVersion;
        firmwareMaxSize;
        firmwareDevice;
        firmwareDesc;
        firmwareDate;
        firmwareDeveloper;
        firmwareLength;
        firmwareCompatability;
        firmwareAddress;
        firmwareDeviceType;
        firmwareDestinationAddress;
        firmwareConfig;
    end
    
end