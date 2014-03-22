%% ResonantAcq
pathToBitfile = 'Microscopy NI7961 NI5732.lvbitx'; % Relative or absolute Path to bitfile
rioDeviceID = 'RIO0';               %   FlexRIO Device ID as specified in MAX. If empty, defaults to 'RIO0'
nominalResScanFreq = 7910;          %   nominal frequency of the resonant scanner

% ************ OPTIONAL *********************
% These values are loaded as defaults and can be changed at runtime
acquisitionTriggerIn = 'PXI_Trig1';                     % Input terminal of Acquisition Start Trigger. Valid Values are {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}
periodTriggerIn = 'PXI_Trig0';                          % Input terminal of the Resonant Scanner Sync signal. Valid Values are {'', 'PFI1'..'PFI3', 'PXI_Trig0'..'PXI_Trig7'}