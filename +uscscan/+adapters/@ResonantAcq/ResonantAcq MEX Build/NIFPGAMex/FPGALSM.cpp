#include "stdafx.h"
#include "FPGALSM.h"
#include "FrameLogger.h"
#include "FrameQueue.h"
#include "FPGAFrameCopier.h"
#include <sstream>
#include "math.h"


#define MAXCALLBACKNAMELENGTH 256

const char *AsyncMexMATLABCallbackArgs::CALLBACK_EVENT_DATA_FIELD_NAMES[] = 
{"framesAvailable", 
"droppedFramesTotal", 
"droppedLogFramesTotal", 
"droppedMLCallbackFramesTotal",
"frameCount"};

const char *FPGALSM::DEFAULT_LSM_FILENAME = "lsm_data";
const char *FPGALSM::LSM_MATLAB_PROPERTY_CALLBACK_DECIMATION = "frameEventDecimationFactor";
const char *FPGALSM::LSM_MATLAB_PROPERTY_PIXELS_PER_LINE = "pixelsPerLine";
const char *FPGALSM::LSM_MATLAB_PROPERTY_LINES_PER_FRAME = "linesPerFrame";

namespace
{
  mxArray * makeDoubleScalarZeroMXArray(void)
  {
    mxArray *p = mxCreateDoubleScalar(0);
    assert(p!=NULL);
    mexMakeArrayPersistent(p);
    return p;
  }
}

AsyncMexMATLABCallbackArgs::AsyncMexMATLABCallbackArgs(void)
{
  evtData = mxCreateStructMatrix(1,1,CALLBACK_EVENT_DATA_NUM_FIELDS,CALLBACK_EVENT_DATA_FIELD_NAMES);
  assert(evtData!=NULL);
  mexMakeArrayPersistent(evtData);

  framesAvailableArray = makeDoubleScalarZeroMXArray();
  droppedFramesArray = makeDoubleScalarZeroMXArray();
  droppedLogFramesArray = makeDoubleScalarZeroMXArray();
  droppedMLCallbackFramesArray = makeDoubleScalarZeroMXArray();
  frameCountArray = makeDoubleScalarZeroMXArray();

  // use of constants is a little broken here but no biggie
  mxSetField(evtData,0,CALLBACK_EVENT_DATA_FIELD_NAMES[0],framesAvailableArray);
  mxSetField(evtData,0,CALLBACK_EVENT_DATA_FIELD_NAMES[1],droppedFramesArray);
  mxSetField(evtData,0,CALLBACK_EVENT_DATA_FIELD_NAMES[2],droppedLogFramesArray);
  mxSetField(evtData,0,CALLBACK_EVENT_DATA_FIELD_NAMES[3],droppedMLCallbackFramesArray);
  mxSetField(evtData,0,CALLBACK_EVENT_DATA_FIELD_NAMES[4],frameCountArray);

  rhs[0] = NULL; // cbkFcn; will be filled in
  rhs[1] = NULL; // lsmObj; will be filled in
  rhs[2] = evtData;
}

AsyncMexMATLABCallbackArgs::~AsyncMexMATLABCallbackArgs(void)
{
  if (evtData!=NULL) {
    mxDestroyArray(evtData);
    // Should destroy all arrays created    
  }
}

FPGALSM::FPGALSM(void) :
fScannerID(-1),
fScannerObjHandle(NULL),
fAsyncMex(NULL),
fCallbackFuncHandle(NULL),
fSingleFrameBuffer(NULL),
fLogger(new FrameLogger()),
fThorFrameCopier(new ThorFrameCopier()),
fFrameTagEnable(false)
{
  assert(fLogger!=NULL);
}

namespace
{
  void destroyMXArrayProperty(mxArray **a)
  {
    if (*a!=NULL) {
      mxDestroyArray(*a);
      *a = NULL;
    }
  }

  void thorFrameCopierEnsureArmed(ThorFrameCopier *tfc)
  {
    if (tfc->isProcessing()) {
      CONSOLEPRINT("TFC was processing, stopping.\n");
      tfc->stopProcessing();
    } 
    ThorFrameCopier::State tfcState = tfc->getState();
    if (tfcState < ThorFrameCopier::ARMED) {
      CONSOLEPRINT("TFC was not armed, arming.\n");
      bool tfSuccess = tfc->arm();
      assert(tfSuccess);
    }     
  }

  // This method exists b/c stopping an acquisition only stops the TFC and doesn't
  // disarm it. Subsequent config methods might require a disarmed TFC.
  void thorFrameCopierEnsureDisarmed(ThorFrameCopier *tfc)
  {
    if (tfc->isProcessing()) {
      CONSOLEPRINT("TFC was processing, stopping.\n");
      tfc->stopProcessing();
    } 
    ThorFrameCopier::State tfcState = tfc->getState();
    if (tfcState >= ThorFrameCopier::ARMED) {
      CONSOLEPRINT("TFC was armed or above, disarming.\n");
      tfc->disarm();
    }     
  }

  // See note for thorFrameCopierEnsureDisarmed.
  void frameLoggerEnsureDisarmed(FrameLogger &lgr)
  {
    if (lgr.isLogging()) {
      CONSOLEPRINT("Logger was logging, stopping.\n");
      lgr.stopLogging();
    }
    FrameLogger::State st = lgr.getState();
    if (st >= FrameLogger::ARMED) {
      CONSOLEPRINT("Logger was armed or above, disarming.\n");
      lgr.disarm();
    }
  }

  void frameLoggerEnsureArmed(FrameLogger &lgr)
  {
    if (lgr.isLogging()) {
      CONSOLEPRINT("Logger was logging, stopping.\n");
      lgr.stopLogging();
    }
    FrameLogger::State st = lgr.getState();
    if (st >= FrameLogger::ARMED) {
      CONSOLEPRINT("Logger was armed or above, disarming.\n");
      lgr.disarm();
    }
    lgr.arm();
  }
}

FPGALSM::~FPGALSM(void)
{
  destroyMXArrayProperty(&fScannerObjHandle);

  if (fAsyncMex!=NULL) {
    AsyncMex_destroy(&fAsyncMex);
  }
  destroyMXArrayProperty(&fCallbackFuncHandle);

  if (fSingleFrameBuffer!=NULL) {
    mxFree(fSingleFrameBuffer);
    fSingleFrameBuffer = NULL;
  }

  if (fLogger!=NULL) {
    delete fLogger;
    fLogger = NULL;
  }

  if (fThorFrameCopier!=NULL) {
    delete fThorFrameCopier;
    fThorFrameCopier = NULL;
  }

}

void
FPGALSM::init(const mxArray *lsmObj)
{
  CONSOLETRACE();

  assert(lsmObj!=NULL);
  assert(fState==CONSTRUCTED);

  fScannerObjHandle = mxDuplicateArray(lsmObj);
  mexMakeArrayPersistent(fScannerObjHandle);

  fScannerID = CFAEMisc::getIntScalarPropFromMX(lsmObj,"deviceID");

  fFrameTagEnable = (bool) CFAEMisc::getIntScalarPropFromMX(lsmObj,"frameTagEnable");

  fAsyncMex = AsyncMex_create((AsyncMex_Callback *) FPGALSM::asyncMexMATLABCallback,this);
  assert(fAsyncMex!=NULL);

  // fCallbackFuncHandle set in configureCallback

  // fAsyncMexCbkArgs set in asyncMexMATLABCallback


  fThorFrameCopier->setProcessedDataQueue(&fProcessedDataQueue);
  std::vector<FrameQueue*> fOutputQs;
  fOutputQs.push_back(&fLoggerQueue);
  fThorFrameCopier->setOutputQueues(fOutputQs);
  fThorFrameCopier->configureMATLABCallback(fAsyncMex,fScannerID);
  // ThorFrameCopier.updateInputBuffer called in configureBuffers
  // ThorFrameCopier.setMATLABCallbackDecimationFactor called in configureCallback

  SetStatusEvent(fThorFrameCopier->getNewFrameEvent());

  fLogger->setInputQueue(&fLoggerQueue);
  fLogger->setFrameTagProps(static_cast<bool>(CFAEMisc::getIntScalarPropFromMX(lsmObj,"loggingFrameTagEnable")),
    static_cast<bool>(CFAEMisc::getIntScalarPropFromMX(lsmObj,"loggingFrameTagOneBased")));

  fState = INITTED;
}

int
FPGALSM::getScannerID(void) const
{
  return fScannerID;
}

void
FPGALSM::configureImageBuffers(void)
{
  CONSOLETRACE();
  assert(fState==INITTED || fState==CONFIGURED);

  //Extract queue & frame size parameters from M-layer
  int queueSz = CFAEMisc::getIntScalarPropFromMX(fScannerObjHandle,"circBufferSize");

  //Determine frame sizes to use for input buffer
  int totalInputFrameSizeBytes; //total size of frame data, including frame tag, if applicable
  if (fFrameTagEnable == true){
    totalInputFrameSizeBytes = fmp->frameSize + ThorFrameCopier::FRAME_TAG_SIZE_BYTES;
  } else {
    totalInputFrameSizeBytes = fmp->frameSize;
  }

  //Prepare input buffer (single-frame)
  if(fSingleFrameBuffer!=NULL) {
    mxFree(fSingleFrameBuffer);
    fSingleFrameBuffer = NULL;
  }    
  fSingleFrameBuffer = (char*)mxCalloc(1,totalInputFrameSizeBytes);

  assert(fSingleFrameBuffer!=NULL);
  mexMakeMemoryPersistent(fSingleFrameBuffer);

  fThorFrameCopier->updateInputBuffers(fSingleFrameBuffer,fmp);

  //Determine frame sizes to use for processed/output data Qs
  int processedDataQRecordSize = fmp->frameSizePerChannel * fmp->numProcessedDataChannels;
  int loggingQRecordSize = fmp->frameSizePerChannel * fmp->numLoggingChannels;

  if (fFrameTagEnable == true) {
    processedDataQRecordSize += ThorFrameCopier::FRAME_TAG_SIZE_BYTES;
    if (fLogger->getFrameTagEnable()) {
      loggingQRecordSize += ThorFrameCopier::FRAME_TAG_SIZE_BYTES;
    }
  }   

  //Initialize output queues (multi-frame)
  fProcessedDataQueue.init(processedDataQRecordSize,queueSz,queueSz);
  fLoggerQueue.init(loggingQRecordSize,queueSz,queueSz);    

  // ThorFrameCopier could be STOPPED (and not disarmed)
  thorFrameCopierEnsureDisarmed(fThorFrameCopier);

  fState = CONFIGURED;
}

void
FPGALSM::readLogfileStateOffMObject(int &loggingAverageFactor,
                                    std::string &fname,
                                    std::string &modestr,
                                    std::string &headerstr) const
{
  loggingAverageFactor = CFAEMisc::getIntScalarPropFromMX(fScannerObjHandle,"loggingAveragingFactor");  

  // fileName
  char fileNameBuf[MAXFILENAMESIZE] = {'\0'};
  mxArray *mxTmp = mxGetProperty(fScannerObjHandle,0,"loggingFullFileName");
  if (mxTmp!=NULL) {
    mxGetString(mxTmp,fileNameBuf,MAXFILENAMESIZE);
    mxDestroyArray(mxTmp);
    mxTmp = NULL;
  } else {
    sprintf_s(fileNameBuf,MAXFILENAMESIZE,"%s_%d",DEFAULT_LSM_FILENAME,fScannerID);
    CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingFullFileName' returned NULL!");
  }
  fname = fileNameBuf;

  // fileMode
  char fileModeStrBuf[8] = "wbn";
  mxTmp = mxGetProperty(fScannerObjHandle,0,"loggingOpenModeString");
  if (mxTmp!=NULL) {
    mxGetString(mxTmp,fileModeStrBuf,8);
    mxDestroyArray(mxTmp);
    mxTmp = NULL;
  } else {
    // defaults to "wbn"
    CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingOpenModeString' returned NULL!");
  }
  modestr = fileModeStrBuf;

  // header
  char headerStrArray[MAXIMAGEHEADERSIZE] = "Default header str";
  mxTmp = mxGetProperty(fScannerObjHandle,0,"loggingHeaderString");
  if (mxTmp!=NULL) {
    mxGetString(mxTmp,headerStrArray,MAXIMAGEHEADERSIZE);
    mxDestroyArray(mxTmp);
    mxTmp = NULL;
  } else {
    // defaults to "Default..." etc
    CONSOLEPRINT("WARNING! configureLogFile: mxGetProperty 'loggingHeaderString' returned NULL!");
  }
  headerstr = headerStrArray;
}

void
FPGALSM::configureLogFile(void)
{
  CONSOLETRACE();

  assert(!fLogger->isLogging());

  int loggingAvFactor = 0;
  std::string headerstr;
  LogFileNote lfn;
  readLogfileStateOffMObject(loggingAvFactor,lfn.filename,lfn.modeStr,headerstr);

  frameLoggerEnsureDisarmed(*fLogger);
  fLogger->configureImage(fmp,(unsigned int) loggingAvFactor,headerstr.c_str());
  fLogger->configureFile(lfn.filename.c_str(),lfn.modeStr.c_str());  

}

void
FPGALSM::configureCallback(void)
{
  assert(fState>=INITTED);

  if (fCallbackFuncHandle != NULL) {
    mxDestroyArray(fCallbackFuncHandle);
    fCallbackFuncHandle = NULL;    
  }

  // frameAcquiredFcn
  mxArray *mxCbk = mxGetProperty(fScannerObjHandle,0,"frameAcquiredEventFcn");
  if(mxCbk == NULL) {
    CONSOLEPRINT("WARNING! configureCallback: 'frameAcquiredEventFcn' is NULL\n");
  } else if(mxGetClassID(mxCbk) != mxFUNCTION_CLASS) {
    CONSOLEPRINT("WARNING! configureCallback: 'frameAcquiredEventFcn' is not a function handle\n");
  } else if(mxIsEmpty(mxCbk)) {
    CONSOLEPRINT("WARNING! configureCallback: 'frameAcquiredEventFcn' is empty\n");
  } else {
    fCallbackFuncHandle = mxDuplicateArray(mxCbk);
    mexMakeArrayPersistent(fCallbackFuncHandle);
  }

  thorFrameCopierEnsureDisarmed(fThorFrameCopier);
  fThorFrameCopier->setMATLABCallbackEnable(fCallbackFuncHandle!=NULL);
}

void
FPGALSM::configureCallbackDecimationFactor(void)
{
  assert(fState>=INITTED);

  // decimation factor
  int decimationFactor = CFAEMisc::getIntScalarPropFromMX(fScannerObjHandle,LSM_MATLAB_PROPERTY_CALLBACK_DECIMATION);

  if (decimationFactor<=0) {
    CONSOLEPRINT("WARNING! decimationFactor is less than or equal to zero. Ignoring.\n");
  } else {
    thorFrameCopierEnsureDisarmed(fThorFrameCopier);
    fThorFrameCopier->setProcessedDataDecimationFactor((unsigned int)decimationFactor);
  }

}

long
FPGALSM::thorPreflightAcquisition(void)
{
  assert(fState>=CONFIGURED);
  return PreflightAcquisition(fSingleFrameBuffer);
}

long
FPGALSM::thorSetupAcquisition(void)
{
  assert(fState>=CONFIGURED);
  return SetupAcquisition(fSingleFrameBuffer);
}

void
FPGALSM::arm(void)
{
  assert(fState>=CONFIGURED);

  thorFrameCopierEnsureArmed(fThorFrameCopier);

  // At moment, arming of Logger is done in startLogging(). Note that
  // not all acqs will be logged.

  if (fState<ARMED) {
    fState = ARMED;
  }
}

void
FPGALSM::reinitQueues(void)
{
  fProcessedDataQueue.reinit();
  fLoggerQueue.reinit();
}

void
FPGALSM::startLogging(int frameDelay)
{
  frameLoggerEnsureArmed(*fLogger);
  fLogger->startLogging(frameDelay);
}

void 
FPGALSM::startAcquisition(bool allowLogging)
{
  assert(fState>=ARMED);

  reinitQueues(); 

  assert(fThorFrameCopier->getState()==ThorFrameCopier::ARMED || fThorFrameCopier->getState()==ThorFrameCopier::STOPPED);

  std::vector<int> outputQsEnabled (1,0);

  outputQsEnabled[0] = static_cast<int>(allowLogging);

  fThorFrameCopier->startProcessing(outputQsEnabled);
  fThorFrameCopier->startThorAcq();

  fState = RUNNING;
}

// Required calls to change parameter during ongoing acquisition
void 
FPGALSM::startAlreadyRunning(void)
{
  assert(fState==RUNNING);

  thorSetupAcquisition(); //Calls SetupAcquisition()

  fThorFrameCopier->pauseProcessing(); //Suspends ThorFrameCopier processing (via fProcessing)
  fThorFrameCopier->resumeProcessing(); //Resets counters & resumes ThorFrameCoper processing
  fThorFrameCopier->startThorAcq(); //Sends signal to call StartAcquisition() 
}

//// "Directly call API StartAcquisition() function (which can block
//// for long time in case of external triggering)"
//long
//FPGALSM::startAcquisitionDirect(void)
//{
//  assert(fState>=ARMED);  
//
//  thorFrameCopierEnsureArmed(fThorFrameCopier);  
//  fThorFrameCopier->startProcessing();
//  long status = StartAcquisition(fSingleFrameBuffer);
//  
//  fState = RUNNING;
//
//  return status;
//}

namespace
{
  void mexPrintDroppedFrameMsgIfNec(unsigned long n,const char *locStr)
  {
    if (n>0) {
      mexPrintf("WARNING: Frames dropped during acquisition in %s. # of dropped frames: %d.\n",
        locStr,n);
    }
  }
}

void 
FPGALSM::stopAcquisition(void)
{
  if (fState<RUNNING) {
    CFAEASSERT(false,"FPGALSM::stopAcquisition called while fState<RUNNING.\n");
    return;
  }

  ThorFrameCopier::State tfcState = fThorFrameCopier->getState();
  if (tfcState<=ThorFrameCopier::STOPPED) {
    assert(false); // should be impossible
  } else {
    fThorFrameCopier->stopProcessing(); // blocks
  }

  int verbose = CFAEMisc::getIntScalarPropFromMX(fScannerObjHandle,"verbose");
  if (verbose == 1) {
    mexPrintf("ThorFrameCopier framesSeen: %d framesMissed: %d\n",
      fThorFrameCopier->getFramesSeen(),
      fThorFrameCopier->getFramesMissed());
    mexPrintf("Logger framesLogged: %d. LoggerQ frames dropped: %d\n", fLogger->getFramesLogged(), fLoggerQueue.num_dropped_push_back());
    mexPrintf("Processed DataQ frames dropped: %d.\n",fProcessedDataQueue.num_dropped_push_back());
  } 
  /* else {
  unsigned long thorMissed = fThorFrameCopier.getFramesMissed();
  unsigned long dataQDropped = fProcessedDataQueue.num_dropped_push_back();
  mexPrintDroppedFrameMsgIfNec(thorMissed,"thor frame copier");
  mexPrintDroppedFrameMsgIfNec(dataQDropped,"data queue");

  if (fLogger->isLogging()) {
  unsigned long loggerQDropped = fLoggerQueue.num_dropped_push_back();   
  mexPrintDroppedFrameMsgIfNec(loggerQDropped,"logger queue"); 
  }
  }*/

  if (fLogger->isLogging()) {
    fLogger->stopLogging(); // blocks
  }

  // Note: Call to Thor::PostFlightAcquisition is done in M, which is bizzaro

  fState = CONFIGURED;
}

//Function designed specifically for stack operations. Stop processing frames while moving, but maintain logging to same file.
//Note, we might not really need to stop processing even -- because Thor MultiFrameCount should stop sending new ones anyway.
void 
FPGALSM::pauseAcquisition(void)
{
  assert(fState>=RUNNING);

  fThorFrameCopier->pauseProcessing();

  fState = PAUSED;
}

//Function designed specifically for stack operations. 
//Needs to send start signal to TFC because acquisition is stopped at each slice (multi-frame count is reached). 
void
FPGALSM::resumeAcquisition(void)
{
  assert(fState==PAUSED);

  fThorFrameCopier->resumeProcessing();
  fThorFrameCopier->startThorAcq(); // Send start signal which restarts acquisition (pending external trigger)

  fState = RUNNING;
}

bool 
FPGALSM::isAcquiring(void) const
{
  bool retval = (fState==RUNNING);

  // sanity check
  if (retval) {
    assert(fThorFrameCopier->isProcessing());
  }

  return retval;
}

long
FPGALSM::thorPostflightAcquisition(void)
{
  //assert(fState>=RUNNING);
  return PostflightAcquisition(fSingleFrameBuffer);
}

void
FPGALSM::addLogfileRolloverNote(unsigned long frameToStart)
{
  assert(fState==RUNNING || fState==PAUSED);

  LogFileNote lfn;
  int unused;
  std::string imageDesc;
  readLogfileStateOffMObject(unused,lfn.filename,lfn.modeStr,lfn.imageDesc);
  lfn.frameIdx = frameToStart;
  fLogger->addLogfileRolloverNote(lfn);
}

mxArray *
FPGALSM::getProcessedFrames(int numFrames)
{
  unsigned long numAvailFrames = fProcessedDataQueue.size();
  assert(numAvailFrames>0);
  if (numFrames<=0) { 
    numFrames = numAvailFrames; 
  }
  assert((unsigned int)numFrames <= numAvailFrames);

  mwSize dataDims[4];
  dataDims[0] = fmp->imageWidth;
  dataDims[1] = fmp->imageHeight;
  dataDims[2] = fmp->numProcessedDataChannels;
  dataDims[3] = (mwSize) numFrames;

  mxClassID dataCls;
  switch (fmp->bytesPerPixel) {
    case 2:
      dataCls = mxINT16_CLASS;
      break;
    default:
      // only know how to handle 2-bytes right now
      assert(false);
      break;
  }
  mxArray *data = mxCreateNumericArray(4,dataDims,dataCls,mxREAL);
  char *pr = static_cast<char*>(mxGetData(data));

  std::size_t frameSz = fProcessedDataQueue.recordSize();
  std::size_t imageSz;
  if (fFrameTagEnable == true)  {
    mxArray *frameTagArray = mxCreateNumericMatrix(numFrames,1,mxDOUBLE_CLASS,mxREAL);
    double *frameTagPtr = static_cast<double*>(mxGetData(frameTagArray)); 

    imageSz = fProcessedDataQueue.recordSize() - ThorFrameCopier::FRAME_TAG_SIZE_BYTES;
  } else {
    imageSz = fProcessedDataQueue.recordSize();
  }

  long *frameTagPtr; //Hard-code type of frame tag value (long)
  if (fFrameTagEnable == true) {
    frameTagPtr = static_cast<long*>(mxCalloc(1,sizeof(long)));
  }


  for (int i=0;i<numFrames;++i) {

    const char *src = static_cast<const char *>(fProcessedDataQueue.front_unsafe());    
    char *dest = pr + i*imageSz; //image destination

    // Use of FrameQueue::front_unsafe here should be
    // okay. front_unsafe is dangerous wrt concurrent init() and
    // pop_front(); at the moment only the main MATLAB thread performs
    // init(), pop_front(), and front_unsafe() (all within this
    // file). The main MATLAB exec thread acts as both Consumer and
    // Controller, so there should be no concurrency danger.

    memcpy(dest,src,imageSz);

    if (fFrameTagEnable == true) { //copy frame tag
      memcpy(frameTagPtr,src + imageSz,ThorFrameCopier::FRAME_TAG_SIZE_BYTES);
    }

    fProcessedDataQueue.pop_front();
  }

  //Transpose image data (data is row-major, but Matlab arrays are column-major)
  mxArray *permuteArg = mxCreateDoubleMatrix(1,4,mxREAL); 
  double *permuteArgVals = mxGetPr(permuteArg);
  permuteArgVals[0] = 2;
  permuteArgVals[1] = 1;
  permuteArgVals[2] = 3;
  permuteArgVals[3] = 4;

  dataDims[0] = fmp->imageHeight;
  dataDims[1] = fmp->imageWidth;
  mxArray *outData = mxCreateNumericArray(4,dataDims,dataCls,mxREAL);


  mxArray *rhs[2];
  rhs[0] = data;
  rhs[1] = permuteArg;

  int ok = mexCallMATLAB(1,&outData,2,rhs,"permute");
  assert(ok==0);

  mxDestroyArray(permuteArg);
  mxDestroyArray(data);
  

  //CONSOLEPRINT("Retrieved processed data at %d ms\n",GetTickCount());
  if (fFrameTagEnable == true) {    // Return cell array with data array and frame tag
    mxArray *outCellData = mxCreateCellMatrix(2,1);
    mxArray *frameTag = mxCreateDoubleScalar(static_cast<double>(*frameTagPtr));

    //TODO: Deal with multi-frame case -- should return multiple frame tags then

    mxSetCell(outCellData,0,outData);
    mxSetCell(outCellData,1,frameTag);

    mxFree(frameTagPtr);

    return outCellData;

  } else { //Return just the data array
    return outData; 
  }
}

unsigned int
FPGALSM::getNumProcessedFramesAvailable(void) const
{
  return fProcessedDataQueue.size();
}

unsigned int
FPGALSM::getNumThorFramesSeen(void) const
{
  return fThorFrameCopier->getFramesSeen();
}

unsigned int
FPGALSM::getNumThorFramesDropped(void) const
{
  return fThorFrameCopier->getFramesMissed();
}

unsigned int
FPGALSM::getNumDroppedLogFrames(void) const
{
  return fLoggerQueue.num_dropped_push_back();
}

unsigned int
FPGALSM::getNumDroppedProcessedFrames(void) const
{
  return fProcessedDataQueue.num_dropped_push_back();
}

// Wrapper for Matlab callback, used with AsyncMex.
void 
FPGALSM::asyncMexMATLABCallback(LPARAM scannerID, void *FPGALSMObj)
{
  FPGALSM *tlsm = static_cast<FPGALSM*>(FPGALSMObj);

  if (tlsm->isAcquiring()) {

    //Initialize src/event arguments that will be passed to callback: cbkFcn(src,evt)

    tlsm->fAsyncMexCbkArgs.rhs[0] = tlsm->fCallbackFuncHandle;
    tlsm->fAsyncMexCbkArgs.rhs[1] = tlsm->fScannerObjHandle;
    assert(tlsm->fAsyncMexCbkArgs.rhs[2]==tlsm->fAsyncMexCbkArgs.evtData);

    // historic code that appears totally insane, might have caused sporadic SEGVs
    //     int* pdata = (int*)(mxGetData(rhs[1])); 
    //     pdata[0] = scannerData->scannerID;

    //double *ptr = mxGetPr(tlsm->fAsyncMexCbkArgs.framesAvailableArray);
    //ptr[0] = (double)tlsm->fProcessedDataQueue.size();

    //ptr = mxGetPr(tlsm->fAsyncMexCbkArgs.droppedFramesArray);
    //ptr[0] = (double)tlsm->fThorFrameCopier->getFramesMissed();

    //ptr = mxGetPr(tlsm->fAsyncMexCbkArgs.droppedLogFramesArray);
    //ptr[0] = (double)tlsm->fLoggerQueue.num_dropped_push_back();

    //ptr = mxGetPr(tlsm->fAsyncMexCbkArgs.droppedMLCallbackFramesArray);
    //ptr[0] = (double)tlsm->fProcessedDataQueue.num_dropped_push_back();

    //ptr = mxGetPr(tlsm->fAsyncMexCbkArgs.frameCountArray);
    //ptr[0] = tlsm->fThorFrameCopier->getFramesSeen();

    mxArray *mException = mexCallMATLABWithTrap(0,NULL,3,tlsm->fAsyncMexCbkArgs.rhs,"feval");
    if (mException!=NULL) {
      char *errorString = (char*)mxCalloc(256,sizeof(char));
      mxArray *tmp = mxGetProperty(mException, 0, "message"); 
      mxGetString(tmp,errorString,MAXCALLBACKNAMELENGTH);
      mxDestroyArray(tmp);
      CONSOLEPRINT("WARNING! callbackWrapper: error executing callback: \n\t%s\n", errorString);
      mxFree(errorString);
      mxDestroyArray(mException);
    }
  }
}

void
FPGALSM::debugString(std::string &s) const
{
  std::ostringstream oss;

  oss << "--FPGALSM--" << std::endl;
  oss << "ScannerID: " << fScannerID << " State: " << fState 
    << " FrameTagEnable: " << fFrameTagEnable << std::endl;
  s.append(oss.str());

  fThorFrameCopier->debugString(s);
  fProcessedDataQueue.debugString(s);
  fLoggerQueue.debugString(s);
  fLogger->debugString(s);
}
