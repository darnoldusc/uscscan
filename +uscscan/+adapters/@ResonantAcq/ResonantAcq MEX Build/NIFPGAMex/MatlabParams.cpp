#include "MatlabParams.h"

const char *MatlabParams::DEFAULT_LOG_FILENAME = "default_file.tif";

MatlabParams* MatlabParams::instance = NULL;
MatlabParams* MatlabParams::getInstance(){
	if(!instance){
		instance = new MatlabParams;
	}
	return instance;
}

MatlabParams::MatlabParams(){
	//simulated operation.
	simulated = false;

	//most values are set in readPropsFromMatlab
	callbackFuncHandle = NULL;
	pixelsPerLine = 0;
	linesPerFrame = 0;

	//TODO: Figure out what to do with these...do we need them in MATLAB?
    pixelSizeBytes = 2;
    numLoggingChannels = 1;
    signedData = false;
	frameDelay = 0;
	frameTagOneBased = true;
	loggingAverageFactor = 1;

	//Instrumentation vars
	numDroppedFramesCopier = 0;
	lastCopierTag = 0;
}

MatlabParams::~MatlabParams(){
	//fill in later
}

void MatlabParams::readPropsFromMatlab(){
	//Reads the value of each property from the Matlab NiFpga class.
	//Note that Matlab's NiFpga class is dynamic; many properties don't
	//exist until they are created by reading them from the bitfile.

	mxArray* propVal;

	//simulation mode
	propVal = mxGetProperty(resonantAcqObject,0,"simulated");
	simulated = (bool) mxGetScalar(propVal);
	mxDestroyArray(propVal);

	CONSOLEPRINT("simulated mode: %d\n",simulated);

	//acquisition-specific parameters
	propVal = mxGetProperty(resonantAcqObject,0,"pixelsPerLine");
	pixelsPerLine = (size_t) mxGetScalar(propVal);
	mxDestroyArray(propVal);

	CONSOLEPRINT("pixelsPerLine: %d\n",pixelsPerLine);

	propVal = mxGetProperty(resonantAcqObject,0,"linesPerFrame");
	linesPerFrame = (size_t) mxGetScalar(propVal);
	mxDestroyArray(propVal);

	CONSOLEPRINT("linesPerFrame: %d\n",linesPerFrame);

	propVal = mxGetProperty(resonantAcqObject,0,"multiChannel");
	isMultiChannel = (bool) mxGetScalar(propVal);
	mxDestroyArray(propVal);

	CONSOLEPRINT("isMultiChannel: %d\n",isMultiChannel);

	if (isMultiChannel)
		numLoggingChannels = 4;
	else
		numLoggingChannels = 1;

	propVal = mxGetProperty(resonantAcqObject,0,"frameTagging");
	frameTagging = (bool) mxGetScalar(propVal);
	mxDestroyArray(propVal);

	CONSOLEPRINT("frameTagging: %d\n",frameTagging);

	// frame Size in different units
	propVal = mxGetProperty(resonantAcqObject,0,"frameSizePixels");
	frameSizePixels = (size_t) mxGetScalar(propVal);
	mxDestroyArray(propVal);

	CONSOLEPRINT("frameSizePixels: %d\n",frameSizePixels);

	propVal = mxGetProperty(resonantAcqObject,0,"frameSizeBytes");
	frameSizeBytes = (size_t) mxGetScalar(propVal);
	mxDestroyArray(propVal);

		CONSOLEPRINT("frameSizeBytes: %d\n",frameSizeBytes);


	propVal = mxGetProperty(resonantAcqObject,0,"frameSizeFifoElements");
	frameSizeFifoElements = (size_t) mxGetScalar(propVal);
	mxDestroyArray(propVal);

		CONSOLEPRINT("frameSizeFifoElements: %d\n",frameSizeFifoElements);


	propVal = mxGetProperty(resonantAcqObject,0,"FRAME_TAG_SIZE_BYTES");
	tagSizeBytes = (size_t) mxGetScalar(propVal);
	mxDestroyArray(propVal);

		CONSOLEPRINT("tagSizeBytes: %d\n",tagSizeBytes);


	propVal = mxGetProperty(resonantAcqObject,0,"tagSizeFifoElements");
	tagSizeFifoElements = (size_t) mxGetScalar(propVal);
	mxDestroyArray(propVal);

		CONSOLEPRINT("tagSizeFifoElements: %d\n",tagSizeFifoElements);


	propVal = mxGetProperty(resonantAcqObject,0,"frameQueueCapacity");
	frameQueueCapacity = (unsigned long) mxGetScalar(propVal);
	mxDestroyArray(propVal);

		CONSOLEPRINT("frameQueueCapacity: %d\n",frameQueueCapacity);

	//TODO: Put resize of fInputBuffer in here.

	propVal = mxGetProperty(resonantAcqObject,0,"loggingEnable");
	loggingEnabled = (bool) mxGetScalar(propVal);
	mxDestroyArray(propVal);

		CONSOLEPRINT("loggingEnabled: %d\n",loggingEnabled);


	// fileName
	char fileNameBuf[MAXFILENAMESIZE] = {'\0'};
	propVal = mxGetProperty(resonantAcqObject,0,"loggingFullFileName");
	if (propVal!=NULL) {
		mxGetString(propVal,fileNameBuf,MAXFILENAMESIZE);
        if (strlen(fileNameBuf)==0)
            sprintf_s(fileNameBuf,MAXFILENAMESIZE,"%s",DEFAULT_LOG_FILENAME);
		mxDestroyArray(propVal);
		propVal = NULL;
	} else {
		sprintf_s(fileNameBuf,MAXFILENAMESIZE,"%s",DEFAULT_LOG_FILENAME);
		CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingFullFileName' returned NULL!");
	}
	strcpy_s(loggingFullFileName,fileNameBuf);
	CONSOLEDEBUG("'loggingFullFileName' set to:%s\n",loggingFullFileName);

	// fileMode
	char fileModeStrBuf[8] = "wbn";
	propVal = mxGetProperty(resonantAcqObject,0,"loggingOpenModeString");
	if (propVal!=NULL) {
		mxGetString(propVal,fileModeStrBuf,8);
		mxDestroyArray(propVal);
		propVal = NULL;
	} else {
		// defaults to "wbn"
		CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingOpenModeString' returned NULL!");
	}
	strcpy_s(loggingOpenModeString,fileModeStrBuf);
	CONSOLEDEBUG("'loggingOpenModeString' set to:%s\n",loggingOpenModeString);

	// header
	char headerStrArray[MAXIMAGEHEADERSIZE] = "Default header str";
	propVal = mxGetProperty(resonantAcqObject,0,"loggingHeaderString");
	if (propVal!=NULL) {
		mxGetString(propVal,headerStrArray,MAXIMAGEHEADERSIZE);
		mxDestroyArray(propVal);
		propVal = NULL;
	} else {
		// defaults to "Default..." etc
		CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingHeaderString' returned NULL!");
	}
	strcpy_s(loggingHeaderString,headerStrArray);
	CONSOLEDEBUG("'loggingHeaderString' set to:%s\n",loggingHeaderString);
}

//void MatlabParams::setIsMultiChannel(int value){
//	CONSOLEPRINT("Setting isMultiChannel to: %d", value);
//	isMultiChannel = (bool) value;
//}
//
//void MatlabParams::setFifoNumber(uint32_t fifoNumber){
//	CONSOLEPRINT("Setting fpgaFifo to: %d",(uint32_t) fifoNumber);
//	fpgaFifo = fifoNumber;
//}
//
//void MatlabParams::setSession(NiFpga_Session sessionID){
//	CONSOLEPRINT("Setting session to: %d",(NiFpga_Session) sessionID);
//	fpgaSession = sessionID;
//}

void MatlabParams::setCallback(mxArray* mxCbk){
	if (callbackFuncHandle != NULL) {
		CONSOLEPRINT("callbackFuncHandle != NULL, destroying array callbackFunHandle.\n");
		mxDestroyArray(callbackFuncHandle);
		callbackFuncHandle = NULL;    
	}
	if(mxCbk == NULL) {
		CONSOLEPRINT("WARNING! configureCallback: 'frameAcquiredFcn' is NULL\n");
	} else if(!mxIsEmpty(mxCbk) && (mxGetClassID(mxCbk) != mxFUNCTION_CLASS)) {
		CONSOLEPRINT("WARNING! configureCallback: 'frameAcquiredFcn' is not a function handle\n");
	} else {
		CONSOLEPRINT("configureCallback: Setting callbackFunHandle to function specified.\n");

		callbackFuncHandle = mxDuplicateArray(mxCbk);
		mexMakeArrayPersistent(callbackFuncHandle);
	}
}


