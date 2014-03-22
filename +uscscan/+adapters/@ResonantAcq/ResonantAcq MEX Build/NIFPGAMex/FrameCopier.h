#pragma once

#include "stdafx.h"
#include "MatlabParams.h"

/*
FrameCopier

Responsibilities.
* Has a worker thread that listens to the FPGA FIFO queue for
when frames appear.
* When a frame appears in the FPGA queue, add it to the logging
queue and to the Matlab access queue.
* Signal Matlab that a new frame is available after pushing onto
Matlab-access queue, using AsyncMex. Code for the actual callback 
and frame retrieval live in NIFPGAMex.

In the abstract, FrameCopier is a class that
responds to a frame-arrival event by copying a frame off a buffer
and pushing into a pipeline (one or more FrameQueues).

Thread-safety.  
FrameCopier expects only a single thread (a 'controller' thread)
to access its public methods. A FrameCopier instance will spawn
a thread (the 'processing thread') to perform its duties, but this
thread is not publicly accessible. Public API calls are thread-safe
with respect to the processing thread. However, public API calls
made from more than a single controller thread are probably unsafe.
Note that technically there is a third thread involved (spawned by
/AsyncMex), which triggers the next frame event.

State model.
* CONSTRUCTED. A newly constructed FrameCopier is not in a
usable state.
* ARMED. The Setup/Configuration methods (see below) should be
called before an acquisition to initialize the object. After 
appropriately initializing the object, call arm() to arm the TFC
and enter the ARMED state.
* RUNNING. Frames are processed as they arrive and the
new frame event is signaled.
* PAUSED. Frames may arrive, but no action is
taken. Processing may be resumed.
* STOPPED. Frames may arrive, but no action is
taken. Pausing and Stopping differ in that a fresh Start performs
checks and resets frame counters, whereas a Resume does not.
* KILLED. Killing the TFC terminates its processing thread ASAP and
renders the TFC useless.
*/

//forward declarations
class MatlabParams;
class FrameQueue;

class FrameCopier : public StateModelObject {

public:
	static const unsigned int FRAME_TAG_SIZE_BYTES = sizeof(long); // size of frame tag in bytes

	FrameCopier(void);
	~FrameCopier(void);

	/// Initialization methods (setup/config)
	/// These methods cannot be called on a TFC at state ARMED or above.

	// Get the new-frame event. Set/Signal this event to notify a TFC
	// that a new frame has arrived on the input buffer.
	HANDLE getNewFrameEvent(void) const;

	// Configure the Matlab callback. To enable the callback, specify a
	// nonNULL asm and valid scannerID. To disable the callback, pass in
	// NULL for asm.
	//
	// TFC does not take ownership of the asm.
	void configureMatlabCallback(AsyncMex* asyncMex);

	void setMatlabCallbackEnable(bool enable);

	// Specify the output queues. For now, this is just the logging
	// queue, as the processed-data queue (Matlab queue) has its own
	// set method. TFC will push frames onto these queues as they show
	// up. The ordering of queues in the vector is irrelevant.
	void setOutputQueues(const std::vector<FrameQueue*> &outputQs);

	// Specify Matlab output queue.
	void setMatlabQueue(FrameQueue* q);

	// Specify a decimation factor for the processed data queue and
	// Matlab callback (default=1). A decimation factor of 0 or 1 indicates no
	// decimation. A decimation factor of k indicates to perform the
	// callback every kth frame.
	void setMatlabDecimationFactor(unsigned int fac);

	/// Arm

	// Arm the TFC. This performs verifications and prepares to run. The
	// return value is true if the arm is successful.
	//
	// Precondition: CONSTRUCTED or ARMED (double-arming has no effect)
	// Postcondition: ARMED
	bool arm(void);

	// Precondition: ARMED or STOPPED.
	// Postcondition: CONSTRUCTED
	void disarm(void);


	/// Start/stop/pause processing. 

	// stopProcessing() and pauseProcessing() here are blocking by
	// design. Three reasons:
	// 1. The state model would require states like STOPPING and PAUSING
	// if those commands were nonblocking.
	// 2. (Related, but more concretely) Client code that looks like
	// 
	//      ...
	//      TFC.stopProcessing();
	//      MatlabQueue.flush();
	//      ...
	//   
	// might not do the expected thing if stopProcessing is
	// nonblocking. Eg, currently-processing frames could end 
	// up in MatlabQueue "after" the flush.
	// 3. Stopping should be fast, since at the moment there 
	// is at most one frame waiting being processed or waiting to 
	// be processed.

	// This call is a quirk, see comment in FrameCopier.cpp.
	// This should be called after startProcessing().
	void startThorAcq(void); 

	// Reset counters and begin processing frames. 
	//
	// Precondition: ARMED or STOPPED 
	// Postcondition: RUNNING
	void startProcessing(void); //const std::vector<int> &outputQsEnabled);

	// Stop frame processing. This blocks until processing is done.
	//
	// Precondition: RUNNING OR STOPPED OR PAUSED 
	// Postcondition: STOPPED
	void stopProcessing(void);

	bool isProcessing(void) const;

	// Pause frame processing. This blocks until processing is paused.
	//
	// Precondition: RUNNING or PAUSED
	// Postcondition: PAUSED
	void pauseProcessing(void);

	// Counters ARE reset when resuming. This is specialized for SI stacks.
	//
	// Precondition: PAUSED
	// Postcondition: RUNNING
	void resumeProcessing(void);

	/// Run metadata

	// Number of frames seen since last call to startProcessing(). This
	// number includes both processed and missed frames. 
	//
	// This can be called in any state.
	unsigned int getFramesSeen(void) const;

	// Number of frames seen (theoretically anyway) but not processed,
	// since last call to startProcessing(). 
	//
	// This can be called in any state.
	unsigned int getFramesMissed(void) const;


	/// Misc

	// Killing a TFC exits its processing thread as soon as possible and
	// renders the TFC useless.
	//
	// This is nonblocking.
	// 
	// Precondition: any
	// Postcondition: KILLED
	void kill(void);

	// Append debug info to s.
	void debugString(std::string &s) const;

private:
	void safeStartProcessing(void);
	void safeStopProcessing(void);

	static unsigned int WINAPI threadFcn(LPVOID);

	// Process the current contents of the input buffer in case where frame tagging is enabled.
	// Returns true if a Thor error occurred.
	//bool processAvailableTaggedFramesCaveman(void);

	// Process a single Thor frame & generate Matlab event. Returns true if a Thor error occurred.
	bool processFrame(void);

	// Extract specified channels from input buffer, and append frameTag if supplied, creating filteredInputBuffer. 
	// Returns pointer to either original input buffer or filtered input buffer, as appropriate. 
	char * filterInputBufferChannels(char* filteredInputBuffer, std::vector<int> &chanVec, int numChans, bool contiguousChans, int firstChan, long frameTag);

	// Subtract offset values from buffer of input data
	void FrameCopier::subtractInputOffsets(char* inputBuf, std::vector<int> &chanVec);

	void startAcq(void);
	void stopAcquisition();
	bool fStopAcquisition;

	void* trueFree(void*);

private:
	MatlabParams* fmp;

	static const DWORD STOP_TIMEOUT_MILLISECONDS = 5000; // 5 seconds
	static const uint32_t FRAME_WAIT_TIMEOUT = 250; // milliseconds
	
	//frame info
	char* fInputBuffer;
	char* fDeinterlaceBuffer;
	char* fOutputBuffer;
	char* fMatlabFilteredInputBuf;
	char* fOutputDataFilteredInputBuf;  

	static const unsigned int THREADFCN_WAIT_TIMEOUT = 200; // milliseconds

	HANDLE fThread;
	HANDLE fStartAcqEvent;
	HANDLE fNewFrameEvent;
	HANDLE fKillEvent;

	CRITICAL_SECTION fProcessFrameCS; // CS that makes the entire operation of processing a frame "atomic"; used when stopping/pausing
	LONG fProcessing;
	unsigned int fFramesSeen;
	unsigned int fFramesMissed; // This tries to count the number of missed frames by mismatch of Thor index and number of copies, but this is not authoratative -- e.g. CopyAcquisitions could 'succeed' in returning a previously supplied frame
	long fLastFrameTagCopied;

	bool fFrameTagEnable; // if true, an extra long word is copied with each source Thor frame, indicating the frame's index value

	FrameQueue* fMatlabQ;
	unsigned int fMatlabDecimationFactor;
	std::vector<FrameQueue*> fOutputQs;
	std::vector<int> fOutputQsEnabled; //Vector of boolean-valued ints indicating which, if any, of the output Qs are enabled for copy-to

	//asyncMex related
	struct MatlabCallbackInfo {
		AsyncMex* asyncMex;
		int scannerID;
		bool enable;
	};
	MatlabCallbackInfo fMatlabCallbackInfo;
};
