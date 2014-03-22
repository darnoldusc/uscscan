function [methodinfo,structs,enuminfo,ThunkLibName]=E816_DLL_x64_proto_r2010b
%E816_DLL_X64_PROTO_R2010B Create structures to define interfaces found in 'E816_DLL_MOD'.

%This function was generated by loadlibrary.m parser version 1.1.6.33 on Tue Nov 22 22:20:42 2011
%perl options:'E816_DLL_MOD.i -outfile=E816_DLL_x64_proto_r2010b.m -thunkfile=E816_DLL_x64_thunk_pcwin64.c'
ival={cell(1,0)}; % change 0 to the actual number of functions to preallocate the data.
structs=[];enuminfo=[];fcnNum=1;
fcns=struct('name',ival,'calltype',ival,'LHS',ival,'RHS',ival,'alias',ival,'thunkname', ival);
MfilePath=fileparts(mfilename('fullpath'));
ThunkLibName=fullfile(MfilePath,'E816_DLL_x64_thunk_pcwin64');
% long  __stdcall E816_InterfaceSetupDlg ( const char * szRegKeyName ); 
fcns.thunkname{fcnNum}='longcstringThunk';fcns.name{fcnNum}='E816_InterfaceSetupDlg'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'cstring'};fcnNum=fcnNum+1;
% long  __stdcall E816_ConnectRS232 ( int nPortNr , long nBaudRate ); 
fcns.thunkname{fcnNum}='longint32longThunk';fcns.name{fcnNum}='E816_ConnectRS232'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'int32', 'long'};fcnNum=fcnNum+1;
% long  __stdcall E816_FindOnRS ( int * pnStartPort , int * pnStartBaud ); 
fcns.thunkname{fcnNum}='longvoidPtrvoidPtrThunk';fcns.name{fcnNum}='E816_FindOnRS'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'int32Ptr', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_IsConnected ( long ID ); 
fcns.thunkname{fcnNum}='int32longThunk';fcns.name{fcnNum}='E816_IsConnected'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long'};fcnNum=fcnNum+1;
% void  __stdcall E816_CloseConnection ( long ID ); 
fcns.thunkname{fcnNum}='voidlongThunk';fcns.name{fcnNum}='E816_CloseConnection'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'long'};fcnNum=fcnNum+1;
% int  __stdcall E816_GetError ( long ID ); 
fcns.thunkname{fcnNum}='int32longThunk';fcns.name{fcnNum}='E816_GetError'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_TranslateError ( int errNr , char * szBuffer , int maxlen ); 
fcns.thunkname{fcnNum}='int32int32cstringint32Thunk';fcns.name{fcnNum}='E816_TranslateError'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'int32'};fcnNum=fcnNum+1;
% int  __stdcall E816_SetTimeout ( long ID , int timeout ); 
fcns.thunkname{fcnNum}='int32longint32Thunk';fcns.name{fcnNum}='E816_SetTimeout'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32'};fcnNum=fcnNum+1;
% long  __stdcall E816_ConnectTCPIP ( const char * szHostname , long port ); 
fcns.thunkname{fcnNum}='longcstringlongThunk';fcns.name{fcnNum}='E816_ConnectTCPIP'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'cstring', 'long'};fcnNum=fcnNum+1;
% long  __stdcall E816_EnumerateTCPIPDevices ( char * szBuffer , long iBufferSize ); 
fcns.thunkname{fcnNum}='longcstringlongThunk';fcns.name{fcnNum}='E816_EnumerateTCPIPDevices'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'cstring', 'long'};fcnNum=fcnNum+1;
% long  __stdcall E816_ConnectTCPIPByDescription ( const char * szDescription ); 
fcns.thunkname{fcnNum}='longcstringThunk';fcns.name{fcnNum}='E816_ConnectTCPIPByDescription'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'cstring'};fcnNum=fcnNum+1;
% long  __stdcall E816_EnumerateUSB ( char * szBuffer , long iBufferSize , const char * szFilter ); 
fcns.thunkname{fcnNum}='longcstringlongcstringThunk';fcns.name{fcnNum}='E816_EnumerateUSB'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'cstring', 'long', 'cstring'};fcnNum=fcnNum+1;
% long  __stdcall E816_ConnectUSB ( const char * szDescription ); 
fcns.thunkname{fcnNum}='longcstringThunk';fcns.name{fcnNum}='E816_ConnectUSB'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qIDN ( long ID , char * szBuffer , int maxlen ); 
fcns.thunkname{fcnNum}='int32longcstringint32Thunk';fcns.name{fcnNum}='E816_qIDN'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qERR ( long ID , int * pnError ); 
fcns.thunkname{fcnNum}='int32longvoidPtrThunk';fcns.name{fcnNum}='E816_qERR'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qHLP ( long ID , char * szBuffer , int maxlen ); 
fcns.thunkname{fcnNum}='int32longcstringint32Thunk';fcns.name{fcnNum}='E816_qHLP'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qPOS ( long ID , const char * axes , double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qPOS'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qONT ( long ID , const char * axes , BOOL * pbOnTarget ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qONT'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MOV ( long ID , const char * axes , const double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_MOV'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qMOV ( long ID , const char * axes , double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qMOV'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MVR ( long ID , const char * axes , const double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_MVR'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_SVO ( long ID , const char * szAxes , const BOOL * pbValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_SVO'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qSVO ( long ID , const char * szAxes , BOOL * pbValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qSVO'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_DCO ( long ID , const char * szAxes , const BOOL * pbValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_DCO'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qDCO ( long ID , const char * szAxes , BOOL * pbValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qDCO'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_SVA ( long ID , const char * axes , const double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_SVA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qSVA ( long ID , const char * axes , double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qSVA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_SVR ( long ID , const char * axes , const double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_SVR'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qVOL ( long ID , const char * axes , double * pdValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qVOL'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qOVF ( long ID , const char * axes , BOOL * pbOverflow ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qOVF'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_AVG ( long ID , int nAverage ); 
fcns.thunkname{fcnNum}='int32longint32Thunk';fcns.name{fcnNum}='E816_AVG'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qAVG ( long ID , int * pnAverage ); 
fcns.thunkname{fcnNum}='int32longvoidPtrThunk';fcns.name{fcnNum}='E816_qAVG'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_SPA ( long ID , const char * szAxes , const int * iCmdarray , const double * dValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrvoidPtrThunk';fcns.name{fcnNum}='E816_SPA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qSPA ( long ID , const char * szAxes , const int * iCmdarray , double * dValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrvoidPtrThunk';fcns.name{fcnNum}='E816_qSPA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_WPA ( long ID , const char * swPassword ); 
fcns.thunkname{fcnNum}='int32longcstringThunk';fcns.name{fcnNum}='E816_WPA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qSAI ( long ID , char * axes , int maxlen ); 
fcns.thunkname{fcnNum}='int32longcstringint32Thunk';fcns.name{fcnNum}='E816_qSAI'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qSSN ( long ID , const char * szAxes , int * piValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qSSN'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qSCH ( long ID , char * pcChannelName ); 
fcns.thunkname{fcnNum}='int32longcstringThunk';fcns.name{fcnNum}='E816_qSCH'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_SCH ( long ID , char cChannelName ); 
fcns.thunkname{fcnNum}='int32longint8Thunk';fcns.name{fcnNum}='E816_SCH'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int8'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_RST ( long ID ); 
fcns.thunkname{fcnNum}='int32longThunk';fcns.name{fcnNum}='E816_RST'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_BDR ( long ID , int nBaudRate ); 
fcns.thunkname{fcnNum}='int32longint32Thunk';fcns.name{fcnNum}='E816_BDR'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qBDR ( long ID , int * pnBaudRate ); 
fcns.thunkname{fcnNum}='int32longvoidPtrThunk';fcns.name{fcnNum}='E816_qBDR'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qI2C ( long ID , int * pnErrorCode , char * pcChannel ); 
fcns.thunkname{fcnNum}='int32longvoidPtrcstringThunk';fcns.name{fcnNum}='E816_qI2C'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32Ptr', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_WTO ( long ID , char cAxis , int nNumber ); 
fcns.thunkname{fcnNum}='int32longint8int32Thunk';fcns.name{fcnNum}='E816_WTO'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int8', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_WTOTimer ( long ID , char cAxis , int nNumber , int timer ); 
fcns.thunkname{fcnNum}='int32longint8int32int32Thunk';fcns.name{fcnNum}='E816_WTOTimer'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int8', 'int32', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_SWT ( long ID , char cAxis , int nIndex , double dValue ); 
fcns.thunkname{fcnNum}='int32longint8int32doubleThunk';fcns.name{fcnNum}='E816_SWT'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int8', 'int32', 'double'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qSWT ( long ID , char cAxis , int nIndex , double * pdValue ); 
fcns.thunkname{fcnNum}='int32longint8int32voidPtrThunk';fcns.name{fcnNum}='E816_qSWT'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int8', 'int32', 'doublePtr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MVT ( long ID , const char * szAxes , const BOOL * pbValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_MVT'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qMVT ( long ID , const char * szAxes , BOOL * pbValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qMVT'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qDIP ( long ID , const char * szAxes , BOOL * pbValarray ); 
fcns.thunkname{fcnNum}='int32longcstringvoidPtrThunk';fcns.name{fcnNum}='E816_qDIP'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_GcsCommandset ( long ID , const char * szCommand ); 
fcns.thunkname{fcnNum}='int32longcstringThunk';fcns.name{fcnNum}='E816_GcsCommandset'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_GcsGetAnswer ( long ID , char * szAnswer , int bufsize ); 
fcns.thunkname{fcnNum}='int32longcstringint32Thunk';fcns.name{fcnNum}='E816_GcsGetAnswer'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'cstring', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_GcsGetAnswerSize ( long ID , int * iAnswerSize ); 
fcns.thunkname{fcnNum}='int32longvoidPtrThunk';fcns.name{fcnNum}='E816_GcsGetAnswerSize'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_ConfigPStage ( long ID , char cAxis , double dPos10V , double dPos0V , BOOL bUseCurrentParams ); 
fcns.thunkname{fcnNum}='int32longint8doubledoubleint32Thunk';fcns.name{fcnNum}='E816_ConfigPStage'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int8', 'double', 'double', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_ConfigPZTVAmplifier ( long ID , char cAxis , unsigned char ucAmpType , BOOL bUseCurrentParams ); 
fcns.thunkname{fcnNum}='int32longint8uint8int32Thunk';fcns.name{fcnNum}='E816_ConfigPZTVAmplifier'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'long', 'int8', 'uint8', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_IsRecordingMacro ( int ID , BOOL * pbRecordingMacro ); 
fcns.thunkname{fcnNum}='int32int32voidPtrThunk';fcns.name{fcnNum}='E816_IsRecordingMacro'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_IsRunningMacro ( int ID , BOOL * pbRunningMacro ); 
fcns.thunkname{fcnNum}='int32int32voidPtrThunk';fcns.name{fcnNum}='E816_IsRunningMacro'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_DEL ( int ID , const char * szName ); 
fcns.thunkname{fcnNum}='int32int32cstringThunk';fcns.name{fcnNum}='E816_MAC_DEL'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_START ( int ID , const char * szName ); 
fcns.thunkname{fcnNum}='int32int32cstringThunk';fcns.name{fcnNum}='E816_MAC_START'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_NSTART ( int ID , const char * szName , int nrRuns ); 
fcns.thunkname{fcnNum}='int32int32cstringint32Thunk';fcns.name{fcnNum}='E816_MAC_NSTART'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_qMAC ( int ID , const char * szName , char * szBuffer , int maxlen ); 
fcns.thunkname{fcnNum}='int32int32cstringcstringint32Thunk';fcns.name{fcnNum}='E816_qMAC'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'cstring', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_BEG ( int ID , const char * szName ); 
fcns.thunkname{fcnNum}='int32int32cstringThunk';fcns.name{fcnNum}='E816_MAC_BEG'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_END ( int ID ); 
fcns.thunkname{fcnNum}='int32int32Thunk';fcns.name{fcnNum}='E816_MAC_END'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_qFREE ( int ID , int * pNumberChars ); 
fcns.thunkname{fcnNum}='int32int32voidPtrThunk';fcns.name{fcnNum}='E816_MAC_qFREE'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'int32Ptr'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_DEF ( int ID , const char * szName ); 
fcns.thunkname{fcnNum}='int32int32cstringThunk';fcns.name{fcnNum}='E816_MAC_DEF'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_MAC_qDEF ( int ID , char * szBuffer , int maxlen ); 
fcns.thunkname{fcnNum}='int32int32cstringint32Thunk';fcns.name{fcnNum}='E816_MAC_qDEF'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'int32'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_SaveMacroToFile ( int ID , const char * szFileName , const char * szMacroName ); 
fcns.thunkname{fcnNum}='int32int32cstringcstringThunk';fcns.name{fcnNum}='E816_SaveMacroToFile'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'cstring'};fcnNum=fcnNum+1;
% BOOL  __stdcall E816_LoadMacroFromFile ( int ID , const char * szFileName , const char * szMacroName ); 
fcns.thunkname{fcnNum}='int32int32cstringcstringThunk';fcns.name{fcnNum}='E816_LoadMacroFromFile'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'cstring'};fcnNum=fcnNum+1;
methodinfo=fcns;