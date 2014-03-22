if exist('hFpga','var') && ~isempty(hFpga)  && isvalid(hFpga)
    hFpga.delete()
end

hFpga = dabs.ni.rio.NiFPGA('Microscopy NI7961 NI5732.lvbitx');
hFpga.returnEnumsAsStrings = true;
hFpga.openSession('RIO0');
hFpga.download();
hFpga.reset();
hFpga.run();

%assert(hFpga.AdapterModulePresent != 0,'No Adapter Module installed');
disp('Detecting Adapter Module');
while(hFpga.AdapterModuleIDInserted == 0)
    pause(0.1);
end
assert(hFpga.AdapterModuleIDMismatch == 0,'Wrong FlexRIO Adapter Module installed');

disp('Waiting for Adapter Module to be initialized');
while(~hFpga.AdapterModuleInitializationDone)
    pause(0.1);
end

disp('Sending Mask');
mask = ones(1,1025,'int16')*2;
mask(513) = -1;
for i = 1:length(mask)
    hFpga.MaskWriteIndex = i-1;
    hFpga.MaskElementData = mask(i);
    hFpga.MaskDoWriteElement = false;
    hFpga.MaskDoWriteElement = true;
end

disp('Sending Acquisition Parameters');
hFpga.DebugProduceDummyData = true;
hFpga.AcqParamLiveReverseLineRead = false;
hFpga.AcqParamSamplesPerRecord = sum(abs(mask));
hFpga.AcqParamRecordsPerSequence = 0;
hFpga.AcqParamTagEveryNRecords =  256;
hFpga.AcqParamLiveTriggerHoldOff = 10;
hFpga.AcqParamLivePreTriggerSamples = 0;

disp('Configuring FIFO');
hFpga.FifoEnableSingleChannel = true;
hFpga.fifo_SingleChannelToHostI16.configure(1000000);
hFpga.fifo_SingleChannelToHostI16.start();

disp('Starting Acqisition')
hFpga.AcqEngineDoArm = false;
hFpga.AcqEngineDoArm = true;
figure
samples = hFpga.fifo_SingleChannelToHostI16.read(((length(mask)-1)*256+4)*2); %read with frametag
plot(samples)

hFpga.AcqEngineDoReset = true;
%hFpga.MultiChannelToHostU64

%hFpga.delete();
