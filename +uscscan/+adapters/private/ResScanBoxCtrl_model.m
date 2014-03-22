%% ResScanBoxCtrl
daqDevName = 'PXI1Slot3';           %   daqDevName: String identifying the NI-DAQ board to be used to control the Resonant Scanner Box. The name of the DAQ-Device can be seen in NI MAX. e.g. 'Dev1' or 'PXI1Slot3'
chanAOGalvo = 0;                    %   chanAOGalvo: The numeric ID of the Analog Output channel to be used to control the Galvo.
chanAOResonantScannerZoom = 1;      %   chanAOresonantScannerZoom: The numeric ID of the Analog Output channel to be used to control the Resonant Scanner Zoom level.
chanCtrFrameClk = 0;                %   chanCtrFrameClk: The numeric ID of the Counter channel to be used to generate the frame clock rom from the record clock.

galvoVoltsPerOpticalDegree = 1.0;   %   galvo conversion factor from optical degrees to volts
rScanVoltsPerOpticalDegree = 0.33;  %   resonant scanner conversion factor from optical degrees to volts
refAngularRange = 15;               %   optical degrees for resonant scanner and galvo at zoom level = 1           

termRecTrigIn = 'PFI0';             %   termRecTrigIn: String identifying the input terminal connected to the record clock. Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'
nominalResScanFreq = 7910;          %   nominal frequency of the resonant scanner

% ************ OPTIONAL *********************
termSeqTrigIn = '';                 %   termSeqTrigIn: for external triggering
termsFrameClkOut = {'PFI12'};       %   termFrameClkOut: String identifying the output terminal for the Frame Clock. If omitted/blank the Frame Clock is not routed to an external terminal. Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'
termsRecTrigOut = {'PXI_Trig0'};    %   termRecTrigOut: String identifying the output terminal to mirror the record clock. Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'
termsSeqTrigOut = {'PXI_Trig1'};    %   termSeqTrigOut: String identifying the output terminal for the Sequence Trigger.  Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'