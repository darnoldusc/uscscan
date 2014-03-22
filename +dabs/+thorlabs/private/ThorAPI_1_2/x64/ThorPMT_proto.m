function [methodinfo,structs,enuminfo,ThunkLibName]=ThorPMT
%THORPMT Create structures to define interfaces found in 'PMT_SDK_MOD'.

%This function was generated by loadlibrary.m parser version 1.1.6.33 on Tue Nov  1 11:40:20 2011
%perl options:'PMT_SDK_MOD.i -outfile=ThorPMT.m -thunkfile=ThorPMT_thunk_pcwin64.c'
ival={cell(1,0)}; % change 0 to the actual number of functions to preallocate the data.
structs=[];enuminfo=[];fcnNum=1;
fcns=struct('name',ival,'calltype',ival,'LHS',ival,'RHS',ival,'alias',ival,'thunkname', ival);
MfilePath=fileparts(mfilename('fullpath'));
ThunkLibName=fullfile(MfilePath,'ThorPMT_thunk_pcwin64');
% long FindDevices ( long * DeviceCount ); 
fcns.thunkname{fcnNum}='longvoidPtrThunk';fcns.name{fcnNum}='FindDevices'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'longPtr'};fcnNum=fcnNum+1;
% long SelectDevice ( const long Device ); 
fcns.thunkname{fcnNum}='longlongThunk';fcns.name{fcnNum}='SelectDevice'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'long'};fcnNum=fcnNum+1;
% long TeardownDevice (); 
fcns.thunkname{fcnNum}='longThunk';fcns.name{fcnNum}='TeardownDevice'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
% long GetParamInfo ( const long paramID , long * paramType , long * paramAvailable , long * paramReadOnly , double * paramMin , double * paramMax , double * paramDefault ); 
fcns.thunkname{fcnNum}='longlongvoidPtrvoidPtrvoidPtrvoidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='GetParamInfo'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'long', 'longPtr', 'longPtr', 'longPtr', 'doublePtr', 'doublePtr', 'doublePtr'};fcnNum=fcnNum+1;
% long SetParam ( const long paramID , const double param ); 
fcns.thunkname{fcnNum}='longlongdoubleThunk';fcns.name{fcnNum}='SetParam'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'long', 'double'};fcnNum=fcnNum+1;
% long GetParam ( const long paramID , double * param ); 
fcns.thunkname{fcnNum}='longlongvoidPtrThunk';fcns.name{fcnNum}='GetParam'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'long', 'doublePtr'};fcnNum=fcnNum+1;
% long PreflightPosition (); 
fcns.thunkname{fcnNum}='longThunk';fcns.name{fcnNum}='PreflightPosition'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
% long SetupPosition (); 
fcns.thunkname{fcnNum}='longThunk';fcns.name{fcnNum}='SetupPosition'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
% long StartPosition (); 
fcns.thunkname{fcnNum}='longThunk';fcns.name{fcnNum}='StartPosition'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
% long StatusPosition ( long * status ); 
fcns.thunkname{fcnNum}='longvoidPtrThunk';fcns.name{fcnNum}='StatusPosition'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'longPtr'};fcnNum=fcnNum+1;
% long ReadPosition ( DeviceType deviceType , double * pos ); 
fcns.thunkname{fcnNum}='longDeviceTypevoidPtrThunk';fcns.name{fcnNum}='ReadPosition'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'DeviceType', 'doublePtr'};fcnNum=fcnNum+1;
% long PostflightPosition (); 
fcns.thunkname{fcnNum}='longThunk';fcns.name{fcnNum}='PostflightPosition'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
% long GetLastErrorMsg ( wchar_t * msg , long size ); 
fcns.thunkname{fcnNum}='longvoidPtrlongThunk';fcns.name{fcnNum}='GetLastErrorMsg'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'uint16Ptr', 'long'};fcnNum=fcnNum+1;
enuminfo.ParamType=struct('TYPE_LONG',0,'TYPE_DOUBLE',1);
enuminfo.DeviceType=struct('DEVICE_TYPE_FIRST',0,'PMT1',1024,'DEVICE_TYPE_LAST',1025);
enuminfo.Params=struct('PARAM_FIRST_PARAM',0,'PARAM_DEVICE_TYPE',0,'PARAM_PMT1_GAIN_POS',700,'PARAM_PMT1_ENABLE',701,'PARAM_PMT2_GAIN_POS',702,'PARAM_PMT2_ENABLE',703,'PARAM_SCANNER_ENABLE',708,'PARAM_PMT_SAFETY',713,'PARAM_LAST_PARAM',714);
enuminfo.StatusType=struct('STATUS_BUSY',0,'STATUS_READY',1,'STATUS_ERROR',2);
methodinfo=fcns;