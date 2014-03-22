#pragma once

#include <string>
#include <matrix.h> // only for fwd declare mxArray *

#include "AsyncMex.h" // only for fwd declare
#include "StateModelObject.h"
#include "FrameQueue.h"
#include "AsyncMexCallbackHeaderArgs.h"

class FrameLogger;
class FPGAFrameCopier;

// FPGALSM is a C++ interface to the Thorlabs LSM.
//
// State model:
// CONSTRUCTED: A freshly constructed FPGALSM is not usable.
// INITTED: A FPGALSM is initted only once. An initted FPGALSM is not usable.
// CONFIGURED: A Configured FPGALSM has had its configureImage() method called, which allocates
// memory for frame buffers and queues, etc.
// ARMED/RUNNING/PAUSED: These have the usual meaning.
class FPGALSM : public StateModelObject {

public:

  static const long DEFAULT_BYTES_PER_PIXEL = 2;
  static const char *DEFAULT_LSM_FILENAME;

  // MATLAB LSM property names (I started const-ifying string literals but didn't finish, no biggie.)
  static const char *LSM_MATLAB_PROPERTY_CALLBACK_DECIMATION;
  static const char *LSM_MATLAB_PROPERTY_PIXELS_PER_LINE;
  static const char *LSM_MATLAB_PROPERTY_LINES_PER_FRAME;

  static const unsigned int MAXFILENAMESIZE = 256;
  static const unsigned int MAXIMAGEHEADERSIZE = 8194; 

  FPGALSM(void);

  ~FPGALSM(void);

  // PreState: CONSTRUCTED
  // PostState: INITTED
  // 
  // Do not init a FPGALSM object twice.
  void init(const mxArray *lsmObj);

  int getScannerID(void) const;


  /// Config/setup

  // PreState: INITTED or CONFIGURED
  // PostState: CONFIGURED
  //
  // Configure image-related state based on lsm M-object. This
  // allocates buffers, queues, etc.
  void configureImageBuffers(void);

  // PreState: Any state where the logger is not running
  // PostState: unchanged
  // 
  // Configure logging state based on image parameters and lsm
  // M-object. M-object parameters read: loggingAverageFactor
  // filename, filemode, headerString
  void configureLogFile(void);

  // PreState: INITTED or CONFIGURED
  //
  // Configure frame-acquired MATLAB callback based on lsm M-object.
  // Can be called multiple times, but cannot be called during a running acq.
  void configureCallback(void);

  // PreState: INITTED or CONFIGURED
  //
  // Configure frame decimation factor to use for frame-acquired MATLAB callbacks, based on lsm M-object.
  // Can be called multiple times, but cannot be called during a running acq.
  void configureCallbackDecimationFactor(void);


  /// Arm

  /// LTTODO it doesn't really make sense to expose these as public API;
  // it doesn't make sense to call Thor::PostFlight outside of the
  // context of stopping an acq.
  long thorPreflightAcquisition(void);

  long thorSetupAcquisition(void);

  void arm(void);

private:
  // thorlabs.LSM has a flushData() call, but this is not used by
  // anybody and I can't see why it is needed at the moment.
  void reinitQueues(void);

public:

  /// Start/stop

  // Ordinarily this would be rolled into startAcquisition(). I believe we separated 
  // this method out so that the Logger can be configured after acquisition has already 
  // started (eg to note the first frame clock time etc).
  //
  // Note: There is no stopLogging() method, the logger is stopped (if running)
  // in stopAcquisition.
  void startLogging(int frameDelay);

  void startAcquisition(bool allowLogging);

  // Prestate: RUNNING
  //
  // This call should be used when running in FOCUS mode and an LSM
  // parameter is changed "on-the-fly." Examples include the acqDelay,
  // zoom, etc. In this situation, one should precede the call to
  // startAlreadyRunning() with calls to FPGALSM::SetParam() as
  // appropriate to set the desired LSM properties. (In practice this
  // is done in the LSM M-class.)
  //
  // Again, this call is only expected during FOCUS mode. Acquisition
  // counters (framesSeen, etc) are reset by this call. 
  void startAlreadyRunning(void);

  //// LTTODO Don't know why this exists.
  //// Return: Thor status code
  //long startAcquisitionDirect(void);

  // Notes: 
  // * If the object is not running, no action is taken.
  // * If the object is running:
  // ** Postcondition is CONFIGURED. 
  // ** Thor::PostFlightAcq is not called.
  // ** Logger finishes its Q.
  void stopAcquisition(void);

  // Pause/resume are specialized for SI stack use case. 
  void pauseAcquisition(void);

  // Pause/resume are specialized for SI stack use case. 
  void resumeAcquisition(void);

  bool isAcquiring(void) const;

  long thorPostflightAcquisition(void);


  /// Runtime adjustment

  // Precondition: RUNNING or PAUSED
  //
  // Read filename, modestr off M-object to createLogFileNote.
  void addLogfileRolloverNote(unsigned long frameToStart);


  /// Data/Metadata access

  // Get/pop frames from the processedDataQueue. Returns a newly
  // allocated mxArray (not mex-persistent).
  //
  // Set numFrames==0 to indicate "get all frames".
  mxArray * getProcessedFrames(int numFrames); 

  // Acquisition metadata/attributes
  unsigned int getNumProcessedFramesAvailable(void) const;
  unsigned int getNumThorFramesSeen(void) const;
  unsigned int getNumThorFramesDropped(void) const;
  unsigned int getNumDroppedLogFrames(void) const;
  unsigned int getNumDroppedProcessedFrames(void) const;

  /// Other

  static void asyncMexMATLABCallback(LPARAM scannerID, void *FPGALSMObj);

  // Append debug info to s.
  void debugString(std::string &s) const;

private:
  void readLogfileStateOffMObject(int &loggingAverageFactor,
    std::string &fname,
    std::string &modestr,
    std::string &headerstr) const;

private:

  int fScannerID; // might be unnec
  mxArray *fScannerObjHandle; // mxArray containing handle to LSM object 

  // Future, consider moving these into MATLAB-callback frameactor
  AsyncMex *fAsyncMex;
  mxArray *fCallbackFuncHandle; 
  AsyncMexMATLABCallbackArgs fAsyncMexCbkArgs;

  FPGAMexParams *fmp; // partially redundant with logger etc.
  char *fSingleFrameBuffer; // a single frame buffer used to hold the currently acquiring frame from the FPGALSM

  bool fFrameTagEnable; // if true, ThorAPI tags each frame (final long word at end of each frame copied from driver)

  FrameQueue fProcessedDataQueue;
  FrameQueue fLoggerQueue;
  ThorFrameCopier *fThorFrameCopier;		
  FrameLogger *fLogger;
};
