#include <process.h>    /* _beginthread, _endthread */
#include <string>
#include <map>

#include "stdafx.h"
#include "MatlabParams.h"
#include "FrameQueue.h"
#include "FrameCopier.h"
#include "FrameLogger.h"

#define MAX_LSM_COMMAND_LEN 32
#define MAXCALLBACKNAMELENGTH 256


//core objects
// These variables will persist between MEX calls, as they are above the mexFunction declaration.
MatlabParams* fmp;
//FrameQueue* matlabQueue;
FrameCopier* frameCopier;
FrameLogger* frameLogger;
static bool mexInitted = false;

// Called at mex unload/exit
void uninitMEX(void) 
{
	CONSOLETRACE();
    //Gracefully exit
	//Stop Frame Logger.
	if (frameLogger->isLogging())
	{	
		CONSOLEPRINT("STOPPING FRAME LOGGER...\n");
		frameLogger->stopLogging();
	}
	//Stop Frame Copier.
	CONSOLEPRINT("STOPPING FRAME COPIER...\n");
	frameCopier->stopProcessing();
	//************************************************
	mexUnlock();
	mexInitted = false;
}

void initMEX(void) {
#ifdef CONSOLEDEBUG
	NIFPGAMexDebugger::getInstance()->setConsoleAttribsForThread(FOREGROUND_BLUE|FOREGROUND_GREEN|FOREGROUND_INTENSITY);
	CONSOLETRACE();
#endif
	mexLock();
	mexAtExit(uninitMEX);
}

void
asyncMexMATLABCallback(LPARAM lParam, void* fpgaMexParams)
{
	//lParam: Info supplied by postEventMessage
	//void *: Pointer to data/object specified at time of AsyncMex_create()

	mxArray* rhs[3];
	rhs[0] = fmp->callbackFuncHandle;
	rhs[1] = fmp->resonantAcqObject;
	rhs[2] = NULL;
	
	//TODO: Maybe prevent C callback altogether if Matlab callback is empty
	if (mxIsEmpty(rhs[0])) {
		CONSOLEPRINT("In asyncMexMATLABCallback: rhs is empty.\n");
		return;
	}		
	// MATLAB syntax for defining callbackFuncHandle:
	// callbackFuncHandle = @(src,evnt)disp('hello')
	mxArray* mException = mexCallMATLABWithTrap(0,NULL,2,rhs,"feval");

	if (mException!=NULL) {
		char* errorString = (char*)mxCalloc(256,sizeof(char));
		mxArray* tmp = mxGetProperty(mException, 0, "message"); 
		mxGetString(tmp,errorString,MAXCALLBACKNAMELENGTH);
		mxDestroyArray(tmp);
		CONSOLEPRINT("WARNING! asyncMexMATLABCallback: error executing callback: \n\t%s\n", errorString);
		mxFree(errorString);
		mxDestroyArray(mException);
	}
}

enum LSMCommandType { INITIALIZE = 0,
SET_SESSION,
SET_FIFO_NUMBER,
SET_IS_MULTI_CHANNEL,
CREATE_CALLBACK,
RESIZE_ACQUISITION,
REGISTER_FRAMEACQ_CALLBACK,
GET_FRAME,
START_ACQ,
STOP_ACQ,
DELETE_SELF,
UNKNOWN_CMD
};

LSMCommandType getLSMCommand(const char* str) {
	//CONSOLEPRINT("NIFPGAMex: %s\n", str);

	if     (strcmp(str, "init") == 0) { return INITIALIZE; }
	else if(strcmp(str, "setSession") == 0) { return SET_SESSION; } 
	//else if(strcmp(str, "setFifoNumber") == 0) { return SET_FIFO_NUMBER; }
	//else if(strcmp(str, "setIsMultiChannel") == 0) { return SET_IS_MULTI_CHANNEL; }
	//else if(strcmp(str, "createCallback") == 0) { return CREATE_CALLBACK; }
	else if(strcmp(str, "resizeAcquisition") == 0) { return RESIZE_ACQUISITION; } 
	else if(strcmp(str, "registerFrameAcqFcn") == 0) { return REGISTER_FRAMEACQ_CALLBACK; }
	else if(strcmp(str, "getFrame") == 0) { return GET_FRAME; } 
	else if(strcmp(str, "startAcq") == 0) { return START_ACQ; } 
	else if(strcmp(str, "stopAcq") == 0) { return STOP_ACQ; } 
	else if(strcmp(str, "delete") == 0) { return DELETE_SELF; } 

	return UNKNOWN_CMD;
}

void
mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
	if(!mexInitted) {
		initMEX();
		mexInitted = true;

		//create our core objects
		fmp = MatlabParams::getInstance();
		fmp->matlabQueue = new FrameQueue();
		fmp->loggingQueue = new FrameQueue();
		frameCopier = new FrameCopier();
		frameLogger = new FrameLogger();
		static bool mexInitted = false;
	}

	if(nrhs < 2) {
		mexErrMsgTxt("No command specified.");
	}
	char cmdStr[MAX_LSM_COMMAND_LEN];
	mxGetString(prhs[1],cmdStr,MAX_LSM_COMMAND_LEN);

	LSMCommandType lsmCmd = getLSMCommand(cmdStr);
	if(lsmCmd == UNKNOWN_CMD) {
		char errMsg[256];
		sprintf_s(errMsg,256,"\nconfigureFrameAcquiredEvent: Unrecognized command '%s'.",cmdStr);
		mexErrMsgTxt(errMsg);
	}

	// most commands require that scanner data has been initialized, so perform this check first
	switch(lsmCmd) {

 case INITIALIZE :
	 {
		//Store resonant scanner object
		 const mxArray* objTemp = prhs[0];
		 fmp->resonantAcqObject = mxDuplicateArray(prhs[0]);
		 mexMakeArrayPersistent(fmp->resonantAcqObject);

		 //Store  FPGA object
		 fmp->NIFPGAObject = mxGetProperty(fmp->resonantAcqObject,0,"hFpga");
		 mexMakeArrayPersistent(fmp->NIFPGAObject);

		 //Create AsyncMex 'object'
		 CONSOLEPRINT("Creating callback wrapper: fmp->asyncMex called...\n");
		 fmp->asyncMex = AsyncMex_create((AsyncMex_Callback *) asyncMexMATLABCallback , fmp);

		 //Store session & FIFO handles
		 mxArray* propVal;

		 CONSOLETRACE();
		 propVal = mxGetProperty(fmp->NIFPGAObject,0,"session");
		 fmp->fpgaSession = (NiFpga_Session) mxGetScalar(propVal);
		 //fmp->setSession((NiFpga_Session) mxGetScalar(propVal));
		 //CONSOLEPRINT("SET_SESSION CALLED: fmp->setSession called with value %d\n",(NiFpga_Session) mxGetScalar(propVal));
		 mxDestroyArray(propVal);

		 CONSOLETRACE();
		 propVal = mxGetProperty(fmp->resonantAcqObject, 0, "fpgaFifoNumberSingleChan");
		 fmp->fpgaFifoNumberSingleChan = (uint32_t) mxGetScalar(propVal);
		 CONSOLEPRINT("Got FifoNumberSingleChan: %d\n",fmp->fpgaFifoNumberSingleChan);
		 mxDestroyArray(propVal);

		 CONSOLETRACE();
		 propVal = mxGetProperty(fmp->resonantAcqObject, 0, "fpgaFifoNumberMultiChan");
		 fmp->fpgaFifoNumberMultiChan = (uint32_t) mxGetScalar(propVal);
		 CONSOLEPRINT("Got FifoNumberMultiChan: %d\n",fmp->fpgaFifoNumberMultiChan);
		 mxDestroyArray(propVal);

		 //Create/configure Frame Copier thread/object
		 //do this still
	 }
	 break;

 /*case SET_SESSION :
	 {
		 mxArray* propVal = mxGetProperty(fmp->NIFPGAObject,0,"session");
		 fmp->setSession((NiFpga_Session) mxGetScalar(propVal));
		 CONSOLEPRINT("SET_SESSION CALLED: fmp->setSession called with value %d\n",(NiFpga_Session) mxGetScalar(propVal));
		 mxDestroyArray(propVal);
	 }
	 break;

 case SET_FIFO_NUMBER :
	 {
		 mxArray* propVal = mxGetProperty(fmp->NIFPGAObject,0,"fifoNumber");
		 fmp->setFifoNumber((uint32_t) mxGetScalar(propVal));
		 CONSOLEPRINT("SET_FIFO_ID CALLED: fmp->fpgaFifo called with value %d\n",(uint32_t) mxGetScalar(propVal));
		 mxDestroyArray(propVal);
	 }
	 break;*/

 /*case SET_IS_MULTI_CHANNEL :
	 {
		 mxArray* propVal = mxGetProperty(fmp->resonantAcqObject,0,"multiChannel");
		 fmp->setIsMultiChannel((int) mxGetScalar(propVal));
		 CONSOLEPRINT("SET_IS_MULTI_CHANNEL CALLED: fmp->setIsMultiChannel called with value %d\n",(int) mxGetScalar(propVal));
		 mxDestroyArray(propVal);
	 }
	 break;*/

 //case CREATE_CALLBACK:
	// {
	//	 CONSOLEPRINT("CREATE_CALLBACK CALLED: fmp->asyncMex called...\n");
	//	 fmp->asyncMex = AsyncMex_create((AsyncMex_Callback *) asyncMexMATLABCallback , fmp);
	// }
	// break;

 case RESIZE_ACQUISITION:
	 {
		 //CONSOLETRACE();
		 fmp->readPropsFromMatlab();
         fmp->matlabQueue->init(fmp->frameSizeBytes, fmp->frameQueueCapacity, fmp->frameQueueCapacity);
         fmp->loggingQueue->init(fmp->frameSizeBytes, fmp->frameQueueCapacity, fmp->frameQueueCapacity);
	 }
	 break;

 case REGISTER_FRAMEACQ_CALLBACK: 
	 {
		 mxArray* mxCbk = mxGetProperty(fmp->resonantAcqObject,0,"frameAcquiredFcn");
		 fmp->setCallback(mxCbk);
		 mxDestroyArray(mxCbk);
		 //Duplicate & persistence handled by fmp. Is it actually needed though? If mxGetProperty is a mxCreate equivalent, presumably the fucntion callback mxArray is already duplicated?
	 }
	 break;
	 
 case START_ACQ:
	 {
		 //CONSOLEPRINT("matlabQueue: %d",fmp->matlabQueue);
		 //Start Frame Copier.
		 CONSOLEPRINT("STARTING FRAME COPIER...\n");
		 frameCopier->startProcessing();		 
         //Start Frame Logger.
		 if (fmp->loggingEnabled)
		 {
			 CONSOLEPRINT("STARTING FRAME LOGGER...\n");
			 frameLogger->configureLogFile();
			 frameLogger->startLogging();
		 }
	 }
	 break;

 case STOP_ACQ:
	 {
         //Stop Frame Logger.
		 if (frameLogger->isLogging())
			 {	
				 CONSOLEPRINT("STOPPING FRAME LOGGER...\n");
				 frameLogger->stopLogging();
			 }
		 //Stop Frame Copier.
		 CONSOLEPRINT("STOPPING FRAME COPIER...\n");
		 frameCopier->stopProcessing();
	 }
	 break;

 case GET_FRAME: 
	 {
         mwSize frameDims[1];
		 mxArray* data;
         mxArray* dataTransposed;
		 mxArray* dataMatrix;
		 mxArray* tag;
		 mxArray* dataCellArray;
		 mxArray* elremaining;
		 //The following vars are used for de-interlacing multichannel images.
         const int16_t* sourceArray;
         int16_t* destinationArray;
		 int16_t* dataTransposedArray;
		 int16_t* rawData;

		 //Tag variables.
         int16_t  fpgaTagIdentifier;
         uint16_t fpgaPlaceHolder;
         uint16_t fpgaTotalAcquiredRecordsA;
         uint16_t fpgaTotalAcquiredRecordsB;

		 size_t frameTwoOffset   = fmp->frameSizePixels;
		 size_t frameThreeOffset = fmp->frameSizePixels*2;
		 size_t frameFourOffset  = fmp->frameSizePixels*3;
         unsigned long tagVal = 0;

		 if (!fmp->matlabQueue->isEmpty())
		 {
			 //TODO: Remove any redundant memcpys and extra copies of frame data
			 //TODO: Account for the possibility of frame sizes that do not divide evenly into the FIFO, which requires two reads from the FIFO (first part of data, then second part)
			 frameDims[0] = fmp->frameSizeFifoElements;
			 if (fmp->isMultiChannel){
				 data = mxCreateNumericArray(1,frameDims,mxINT64_CLASS,mxREAL);
				 dataTransposed = mxCreateNumericArray(1,frameDims,mxINT64_CLASS,mxREAL);
			 }
			 else
			 {
				 data = mxCreateNumericArray(1,frameDims,mxINT16_CLASS,mxREAL);
				 dataTransposed = mxCreateNumericArray(1,frameDims,mxINT16_CLASS,mxREAL);
			 }

			 //Start the process by getting the memory location of the front of the frame queue and store in sourceArray.
			 sourceArray = static_cast<const int16_t*>(fmp->matlabQueue->front_unsafe());
			 destinationArray  = static_cast<int16_t*>(mxGetData(data));
			 dataTransposedArray = static_cast<int16_t*>(mxGetData(dataTransposed));

			 // If frameTagging is enabled, then store the frame tag.
			 if (fmp->frameTagging) {
				 fpgaTagIdentifier         = (int16_t)  sourceArray[(fmp->frameSizeBytes - fmp->tagSizeBytes)/2];
				 fpgaPlaceHolder           = (uint16_t) sourceArray[(fmp->frameSizeBytes - fmp->tagSizeBytes)/2 + 1];
				 fpgaTotalAcquiredRecordsA = (uint16_t) sourceArray[(fmp->frameSizeBytes - fmp->tagSizeBytes)/2 + 2];
				 fpgaTotalAcquiredRecordsB = (uint16_t) sourceArray[(fmp->frameSizeBytes - fmp->tagSizeBytes)/2 + 3];
				 tagVal = (unsigned long) fpgaTotalAcquiredRecordsA * (unsigned long) 65536 + (unsigned long) fpgaTotalAcquiredRecordsB;

				 //if (tagVal != fmp->lastCopierTag+1) {
					// fmp->numDroppedFramesCopier = fmp->numDroppedFramesCopier + (tagVal - fmp->lastCopierTag + 1);
					// CONSOLEPRINT("FRAMECOPIER dropped %u frames...\n",fmp->numDroppedFramesCopier);
				 //}
				 //fmp->lastCopierTag = tagVal;
			 }

			 memcpy(destinationArray,sourceArray,fmp->frameSizeBytes);

			 //reset pointer to destinationArray so that it points to the beginning of our data.
			 destinationArray  = static_cast<int16_t*>(mxGetData(data));
			 //Once we are done using the sourceArray pointer, we can pop the front off the frame queue.
			 fmp->matlabQueue->pop_front();
			 //Create a 2D cell array of dimension 4x1. Each cell contains a channel frame to send to MATLAB.
			 dataCellArray = mxCreateCellMatrix(4,1);
			 //Create the 2D MATLAB array that will contain the data we just copied into rawData.
			 dataMatrix = mxCreateNumericMatrix(fmp->linesPerFrame,fmp->pixelsPerLine,mxINT16_CLASS,mxREAL);
             //rawData holds pointer to the data stored in dataMatrix.
			 rawData = static_cast<int16_t*>(mxGetData(dataMatrix));
			 //Perform the 1D array transpose. Store the resulting transposed value into dataTransposedArray.
			 //The following may be friendlier for the compiler to optimize.
			 if  (fmp->isMultiChannel)
			 {
				 memcpy(rawData,(int16_t *) destinationArray,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,0,mxDuplicateArray(dataMatrix));
				 memcpy(rawData,(int16_t *) destinationArray+frameTwoOffset,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,1,mxDuplicateArray(dataMatrix));
				 memcpy(rawData,(int16_t *) destinationArray+frameThreeOffset,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,2,mxDuplicateArray(dataMatrix));
				 memcpy(rawData,(int16_t *) destinationArray+frameFourOffset,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,3,mxDuplicateArray(dataMatrix));
			 }
			 else
			 {
				 memcpy(rawData,(int16_t *) destinationArray,fmp->frameSizePixels*2);
				 mxSetCell(dataCellArray,0,mxDuplicateArray(dataMatrix));
			 }
		 }
		 else{
			 mexPrintf("attempting to get frame from empty queue!\n");
			 //Create a 2D cell array of dimension 4x1. Each cell contains a channel frame to send to MATLAB.
			 dataCellArray = mxCreateCellMatrix(4,1);
			 mxSetCell(dataCellArray,0,mxCreateNumericMatrix(1,1,mxINT16_CLASS,mxREAL));
			 mxSetCell(dataCellArray,1,mxCreateNumericMatrix(1,1,mxINT16_CLASS,mxREAL));
			 mxSetCell(dataCellArray,2,mxCreateNumericMatrix(1,1,mxINT16_CLASS,mxREAL));
			 mxSetCell(dataCellArray,3,mxCreateNumericMatrix(1,1,mxINT16_CLASS,mxREAL));
		 }

		 tag = mxCreateDoubleScalar(tagVal);
		 elremaining = mxCreateDoubleScalar(0);

		 //Set up left hand side arguments for passing data back to MATLAB.
		 if (nlhs >= 1)
		 {
			 plhs[0] = dataCellArray;
			 plhs[1] = tag;
			 plhs[2] = elremaining;
		 }
		 //Free memory from heap.
		 mxDestroyArray(dataMatrix);
		 mxDestroyArray(dataTransposed);
		 mxDestroyArray(data);
	 }
	 break;

 case DELETE_SELF:
	 {
		 //frameCopier->stopAcquisition(); //stops thread

		 if (frameCopier != NULL) {
			 CONSOLEPRINT("DELETING FRAME COPIER...\n");
			delete frameCopier;
		 }

		 if (frameLogger != NULL) {
			 CONSOLEPRINT("DELETING FRAME LOGGER...\n");
			 delete frameLogger;
		 }

		 if (&fmp->asyncMex != NULL) {
			 AsyncMex_destroy(&fmp->asyncMex);
		 }

		 if (fmp != NULL) {
			 delete fmp;
		 }
	 }
	 break;

	}
}



/* 
case DELETE:
if (&fmp->asyncMex != NULL) {
AsyncMex_destroy(&fmp->asyncMex);
}

if (fmp.frameCopier!=NULL) {
delete mp->frameCopier;
mp->frameCopier = NULL;
}


if (fmp->matlabObject!=NULL)
delete fmp->matlabObject;
fmp->matlabObject = NULL;
}

break;

case INITIALIZE :
case TEST : 
//case DEBUG_MESSAGES :
// these commands DO NOT require a scanner has been initialized
break;
default :
CFAEMisc::mexAssert(tlsm!=NULL,
"\nconfigureFrameAcquiredEvent: scanner not found or not initialized - call 'initialize' first");
break;
}


int status = -13; // return value
//currently unused
switch (lsmCmd) {

case INITIALIZE : 
scannerMap::createAndInitializeThorLSM(matlabObj);
break;

case CONFIG_CALLBACK : 
tlsm->configureCallback(); 
break;

case CONFIG_CALLBACK_DECIMATION : 
tlsm->configureCallbackDecimationFactor(); 
break;

case CONFIG_BUFFERS : 
tlsm->configureImageBuffers(); 
break; 

case CONFIG_FILE :
tlsm->configureLogFile();
break; 

case ADD_LOGFILE_ROLLOVER_NOTE :
{
assert(nrhs==3);
int frameToStart = (int)mxGetScalar(prhs[2]);
tlsm->addLogfileRolloverNote(frameToStart);
}
break;

//  case DEBUG_MESSAGES :     
//debugScanner(); break;

case GET : 
CFAEMisc::mexAssert(nrhs>=3,"Attribute not specified.");
if (nlhs>=1) {
plhs[0] = getAttrib(tlsm,prhs[2]); 
}
break;

case PREFLIGHT : 
status = tlsm->thorPreflightAcquisition();
break;

case POSTFLIGHT :
status = tlsm->thorPostflightAcquisition();
break; 

case SETUP :
status = tlsm->thorSetupAcquisition();
break;

case NEWACQ : 
tlsm->arm();
break;

case PAUSE :
tlsm->pauseAcquisition();
break;

case RESUME :
tlsm->resumeAcquisition();
break;

case START_LOGGING :
{
assert(nrhs==3);
int frameDelay = (int)mxGetScalar(prhs[2]);
tlsm->startLogging(frameDelay);      
}
break;

case START : 		
{
assert(nrhs==3);
bool allowLogging = static_cast<bool>(mxGetScalar(prhs[2]));
tlsm->startAcquisition(allowLogging);
}
break; 

case START_ALREADY_RUNNING :
tlsm->startAlreadyRunning();
break;

//case START_DIRECT :
//  status = tlsm->startAcquisitionDirect();
//  break;

case STOP :
case FINISH:
tlsm->stopAcquisition();
break;

case IS_ACQUIRING : 
status = tlsm->isAcquiring() ? 1 : 0;
break;

case GETDATA : 
{
int numFrames = (nrhs>=3) ? (int)mxGetScalar(prhs[2]) : 0; // 0 indicates return all avail frames
assert(numFrames>=0);
if (nlhs>=1) {
mxArray* data = tlsm->getProcessedFrames(numFrames);
plhs[0] = data;
}

// used to be that data could be NULL if eg you requested frames when there were none.
//       if(data == NULL) {
// 	data = mxCreateNumericMatrix(1, 0, RETURNED_IMAGE_DATATYPE, mxREAL);
//       }
}
break; 

case FLUSH : 
mexPrintf("Flush: this command currently doesn't do anything.\n");
break;

case FINISH_LOG :
mexPrintf("FinishLogging: this command currently doesn't do anything.\n");
break;

case DESTROY :
scannerMap::destroyThorLSM(matlabObj); 
break;

case TEST : 
CONSOLEPRINT("\n\n\n"); //wouldn't mind clearing console, but with WinAPI only this doesn't seem easy
mexPrintf("\nLSM test successful!\n"); 
break;

case DEBUG_SHOW_STATUS :
{
std::string s;
tlsm->debugString(s);
mexPrintf("\n\n");
mexPrintf(s.c_str());
mexPrintf("\n\n");
}
break;

default: 
break;
}

// return status unless the command is getdata or get, which return different values
if(nlhs > 0 && lsmCmd != GETDATA  && lsmCmd != GET) {
assert(nlhs==1);
assert(sizeof(int)==4);
plhs[0] = mxCreateNumericMatrix(1,1,mxINT32_CLASS,mxREAL);
int* ptr = (int*)mxGetData(plhs[0]);
ptr[0] = status;
}	
}
*/

//mxArray* getAttrib(const mxArray* attribName) {
//
//	assert(attribName!=NULL);
//	char attribStr[64];
//	mxGetString(attribName,attribStr,64);
//
//	CONSOLEPRINT("getAttrib '%s'\n",attribStr);
//
//	int val = -1;
//
//	if (!strcmp(attribStr, "framesAvailable")) {
//		val = (int)fmp->getNumProcessedFramesAvailable();
//	} else if (!strcmp(attribStr, "droppedFramesLast")) {
//		val = (int)fmp->getNumThorFramesDropped();
//	} else if (!strcmp(attribStr, "frameCount")) {
//		val = (int)fmp->getNumThorFramesSeen();
//	} else if (!strcmp(attribStr, "droppedProcessedFramesLast")) {
//		val = (int)fmp->getNumDroppedProcessedFrames();
//	} else if (!strcmp(attribStr, "droppedLogFramesLast")) {
//		val = (int)fmp->getNumDroppedLogFrames();
//	} else if (!strcmp(attribStr, "droppedFramesTotal")) {
//		mexPrintf("getAttrib, droppedFramesTotal is no longer supported.\n");
//		val = 0;
//	} else if (!strcmp(attribStr, "droppedLogFramesTotal")) {
//		mexPrintf("getAttrib, droppedLogFramesTotal is no longer supported.\n");
//		val = 0;
//	}
//
//	mxArray* mxVal = mxCreateNumericMatrix(1,1,mxINT32_CLASS,mxREAL);
//	int* intPr = (int*)(mxGetData(mxVal));
//	intPr[0] = val;
//
//	return mxVal;


