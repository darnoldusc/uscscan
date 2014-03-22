#pragma once

#include "stdafx.h"
#include "FrameCopier.h"
#include <sstream>
#include <process.h>
#include "StateModelObject.h"
#include "FrameQueue.h"

FrameCopier::FrameCopier(void) : 
fProcessing(0),
fFramesSeen(0),
fFramesMissed(0),
fLastFrameTagCopied(0),
fInputBuffer(NULL),
fOutputBuffer(NULL),
fDeinterlaceBuffer(NULL),
fMatlabFilteredInputBuf(NULL),
fOutputDataFilteredInputBuf(NULL),
fFrameTagEnable(true),
fMatlabDecimationFactor(1),
fmp(MatlabParams::getInstance()),
fStopAcquisition(false)

#define threadSafePrint(...) EnterCriticalSection(&fProcessFrameCS); _cprintf(__VA_ARGS__); LeaveCriticalSection(&fProcessFrameCS)
{
	fNewFrameEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fNewFrameEvent!=NULL);
	fStartAcqEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fStartAcqEvent!=NULL);
	fKillEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fKillEvent!=NULL);

	InitializeCriticalSection(&fProcessFrameCS);

	fmp->asyncMex = NULL;
	fmp->callbackEnabled = false;
}

FrameCopier::~FrameCopier(void)
{
	if (fThread!=0) {
		kill();
	}

	CFAEMisc::closeHandleAndSetToNULL(fNewFrameEvent);
	CFAEMisc::closeHandleAndSetToNULL(fStartAcqEvent);
	CFAEMisc::closeHandleAndSetToNULL(fKillEvent);
	DeleteCriticalSection(&fProcessFrameCS);

	// fInputBuffer, fOutputQs, fmp->asyncMex not owned
	// by TFC.
}

HANDLE
FrameCopier::getNewFrameEvent(void) const
{
	return fNewFrameEvent;
}



void
FrameCopier::configureMatlabCallback(AsyncMex *asyncMex)
{
	assert(fState==CONSTRUCTED);

	assert(asyncMex!=NULL);
	fmp->asyncMex = asyncMex;
}

void
FrameCopier::setMatlabCallbackEnable(bool enable)
{
	assert(fState==CONSTRUCTED);

	fmp->callbackEnabled = enable;
}

void
FrameCopier::setMatlabDecimationFactor(unsigned int fac)
{
	assert(fState==CONSTRUCTED);

	if (fac==0) {
		fac = 1;
	}
	fMatlabDecimationFactor = fac;
}

void
FrameCopier::setOutputQueues(const std::vector<FrameQueue*> &outputQs)
{
	assert(fState==CONSTRUCTED);

	fOutputQs = outputQs;
}

void
FrameCopier::setMatlabQueue(FrameQueue *q)
{
	assert(fState==CONSTRUCTED);

	fMatlabQ = q;
}


bool
FrameCopier::arm(void)
{
	assert(fState<=ARMED);

	bool tfSuccess = true;

	/// perform verifications, but don't change any state (clear
	/// queues), etc.

	//TODO - put in more array size verifications, taking frameTag into account
	if (fDeinterlaceBuffer==NULL) {
        CONSOLETRACE();
		tfSuccess = false;
	}
	if (fInputBuffer==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	if (fOutputBuffer==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	if (fMatlabQ==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	//if (fInputImageSize!=fMatlabQ->recordSize()) { 
	//  CONSOLETRACE();
	//  tfSuccess = false; 
	//}
	if (fOutputQs.empty()) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	//std::size_t numQs = fOutputQs.size();
	//for (std::size_t i=0;i<numQs;i++) {
	//  if (fInputImageSize!=fOutputQs[i]->recordSize()) { 
	//    CONSOLETRACE();
	//    tfSuccess = false; 
	//  }
	//}

	if (fmp->asyncMex==NULL) {
		CONSOLETRACE();
		tfSuccess = false; 
	}
	assert(fThread!=0);
	assert(fProcessing==0);

	if (tfSuccess) {
		fState = ARMED;
	}

	return tfSuccess;
}

void 
FrameCopier::disarm(void)
{
	assert(fState==ARMED || fState==STOPPED);
	assert(fThread!=0);
	assert(fProcessing==0);

	fState = CONSTRUCTED;
}

void
FrameCopier::startAcq(void)
{
	SetEvent(fStartAcqEvent);
}

void
FrameCopier::startProcessing(void) //const std::vector<int> &outputQsEnabled)
{
	MatlabParams* fmp = MatlabParams::getInstance();

	assert(fState==ARMED || fState==STOPPED);
	CONSOLETRACE();
	CONSOLEPRINT("matlabQueue: %d",fmp->matlabQueue);

	//fOutputQsEnabled = outputQsEnabled; 

	// If processed data or output Q is not empty, that is unexpected. Throw up a MsgBox.
	if (!fmp->matlabQueue->isEmpty())
	{
		CONSOLETRACE();
		CONSOLEPRINT("FrameCopier: Processed data queue has size %d!\n",fmp->matlabQueue->size());
        //Clear the frame queue if there is any residual data from a previous run.
        fmp->matlabQueue->reinit();
	}

	//ResetEvent(fStartAcqEvent);
	//ResetEvent(fNewFrameEvent);
	//ResetEvent(fKillEvent);
	CONSOLETRACE();

	safeStartProcessing();

	fThread = (HANDLE) _beginthreadex(NULL, 0, FrameCopier::threadFcn, (LPVOID)this, 0, NULL);

	//Set thread state to RUNNING if fThread is not 0.
	assert(fThread!=0);
	fState = RUNNING;
}

void
FrameCopier::stopProcessing(void)
{
    assert(fState==RUNNING || fState==STOPPED || fState==PAUSED);
	assert(fThread!=0);

	// Send stop signal.
	safeStopProcessing();
	// Stop signal sent. Now wait for logging thread to terminate.

	DWORD retval = WaitForSingleObject(fThread,STOP_TIMEOUT_MILLISECONDS);
	switch (retval) {
	  case WAIT_OBJECT_0:
		  // logging thread completed.
		  {
			  BOOL b = CloseHandle(fThread);
			  assert(b!=0);
			  fThread = 0;
		  }
		  fState = STOPPED;
		  break;

	  case WAIT_TIMEOUT:
	  case WAIT_ABANDONED:
	  case WAIT_FAILED:
	  default:
		  CONSOLEPRINT("FrameCopier::HARD STOP!!\n");
		  assert(fState==STOPPED || fState==KILLED);

		  if (fState==STOPPED) {
			  CONSOLEPRINT("FrameCopier: Copier could not finish processing. %d frames were unlogged.\n", fmp->matlabQueue->size());
		  }

		  break;
	}
}

bool
FrameCopier::isProcessing(void) const
{
	return fProcessing!=0;
}

void
FrameCopier::pauseProcessing(void)
{
	assert(fState==RUNNING || fState==PAUSED);

	safeStopProcessing();

	fState = PAUSED;
}

void
FrameCopier::resumeProcessing(void)
{
	assert(fState==PAUSED);

	safeStartProcessing();

	fState = RUNNING;
}

unsigned int
FrameCopier::getFramesSeen(void) const
{
	return fFramesSeen;  
}

unsigned int
FrameCopier::getFramesMissed(void) const
{
	return fFramesMissed;  
}


void
FrameCopier::kill(void)
{  
	DWORD threadExitCode = 0; // Used to store exit code for proper call of Terminate Thread.
//	BOOL returnValue;

	SetEvent(fKillEvent); // nonblocking termination of processing thread
//	returnValue = GetExitCodeThread(fThread, (LPDWORD) threadExitCode); // get Exit code for fThread from Windows.
//	CONSOLEPRINT("GetExitCodeThread status: %d, error code: %d\n",returnValue, GetLastError());
//	returnValue = TerminateThread(fThread,threadExitCode); // Forcibly terminate thread using threadExitCode.
//	CONSOLEPRINT("TerminateThread status: %d, error code: %d\n",returnValue, GetLastError());
	CloseHandle(fThread); // Does not forcibly terminate thread, only releases handle. Close handle for cleanup.
	fThread = 0;
	fState = KILLED;
}

void
FrameCopier::debugString(std::string &s) const
{
	std::ostringstream oss;
	oss << "--FrameCopier--" << std::endl;
	oss << "State Processing FramesSeen FramesMissed: " 
		<< fState << " " << fProcessing << " " << fFramesSeen << " " 
		<< fFramesMissed << std::endl;
	oss << "MLCBI.enable MatlabDecimationFactor: "
		<< fmp->callbackEnabled << " " 
		<< fMatlabDecimationFactor << std::endl;
	s.append(oss.str());
}

void
FrameCopier::safeStartProcessing(void)
{
	CONSOLETRACE();
	CONSOLEPRINT("Safe start processing\n");

	EnterCriticalSection(&fProcessFrameCS); 
	fFramesSeen = 0;
	fFramesMissed = 0;
	fLastFrameTagCopied = -1;
	fProcessing = 1;
	LeaveCriticalSection(&fProcessFrameCS);
}

void
FrameCopier::safeStopProcessing(void)
{
	EnterCriticalSection(&fProcessFrameCS); 
	fProcessing = 0;
	LeaveCriticalSection(&fProcessFrameCS);
}

void FrameCopier::stopAcquisition(){
	fStopAcquisition = true;
}

void*
FrameCopier::trueFree(void * fMem)
{
	if (fMem != NULL)
		free(fMem);
	return NULL;
}

// Threading impl notes.  
//
// Some TFC state accessed by the processing thread cannot change
// while threadFcn (or downstream calls) accesses it, due to
// constraints provided by the state model. Examples are fInputBuffer, fOutputQs.
// 
// The only TFC state that is truly shared by the processing thread
// and controller thread are the Events, fProcessing, fFramesSeen,
// fFramesMissed. These are protected with fProcessFrameCS.
//
// At the moment, no state changes (changes to fState) can originate
// in the processing thread (within threadFnc). For example, if
// something bad happens, the processing thread cannot call
// obj->stopProcessing() to put obj's state into STOPPED. The reason
// is that stopProcessing() and other state-change methods are not
// thread-safe with respect to each other, as explained in header.
//
// If in the future there is the need to enable this sort of state
// change, all state-change methods (ALL interactions involving
// potential modification to fState) will need to be protected with
// critical_sections or the like.

unsigned int 
WINAPI FrameCopier::threadFcn(LPVOID userData)
{
#ifdef CONSOLEDEBUG
	NIFPGAMexDebugger::getInstance()->setConsoleAttribsForThread(FOREGROUND_GREEN|FOREGROUND_INTENSITY);
#endif
	//CONSOLETRACE();
	FrameCopier *obj = static_cast<FrameCopier*>(userData);
	
	HANDLE evtArray[3];
	evtArray[0] = obj->fKillEvent;
	evtArray[1] = obj->fStartAcqEvent;
	evtArray[2] = obj->fNewFrameEvent;
	
	//Instantiate the MatlabParams singleton.	
	MatlabParams* fmpThread = MatlabParams::getInstance();

	//Instantiate and initialize local copy of frameSizeBytes & frameQueueCapacity
	size_t localframeSizeBytes = -1;
	//unsigned long localFrameQueueCapacity = fmpThread->frameQueueCapcity;

	//mem allocation
	size_t* elementsRemaining = (size_t*) calloc(1,sizeof(size_t));
	
	int count = 0;
	int deinterlaceCount = 0;
	bool isInitialized = false;
	bool pushbackOK = false;
	int16_t* sourceArray;
	int16_t* destinationArray;
	size_t smallOffset      = 4;
	size_t frameTwoOffset   = fmpThread->frameSizePixels;
	size_t frameThreeOffset = fmpThread->frameSizePixels*2;
	size_t frameFourOffset  = fmpThread->frameSizePixels*3;
    unsigned long simulatedFrameCount = 0;

	while(true){
		//check for stop signal
		if(obj->fStopAcquisition){
			CONSOLETRACE();
			break;
		}

		if(!obj->isProcessing()){
			CONSOLETRACE();
			break;
		}

		//Initialize FPGA context in this thread - does this /need/ to be in the while loop??
		if (!isInitialized) {
			assert(obj->fProcessing == 0);
			fmpThread->fpgaStatus = NiFpga_Initialize();
            if (!fmpThread->simulated)
                fmpThread->fpgaStatus = NiFpga_Initialize();
            else
                fmpThread->fpgaStatus = NiFpga_Status_Success;

			if(fmpThread->fpgaStatus != NiFpga_Status_Success){
				CONSOLEPRINT("Error initializing FPGA interface context. Got Status: %d\n",fmpThread->fpgaStatus);
			}else
                isInitialized = true;
		}

		// Check to see if the user has changed either linesPerFrame or pixelsPerLine. If so, then recompute framesize,
		// free the old fInputBuffer, and re-calloc the fInputBuffer to the correct size.
		if ((fmpThread->frameSizeBytes != localframeSizeBytes))
		{
			assert(obj->fProcessing == 0);
			CONSOLEPRINT("Resizing fInputBuffer to %d bytes\n", fmpThread->frameSizeBytes);

			// Recompute offsets for de-interlacing
			frameTwoOffset   = fmpThread->frameSizePixels;
			frameThreeOffset = fmpThread->frameSizePixels*2;
			frameFourOffset  = fmpThread->frameSizePixels*3;

			// Set local copies of lpp and ppl to the new values.
			localframeSizeBytes = fmpThread->frameSizeBytes;

			// Free the old memory associated with the fInputBuffer.
			obj->fInputBuffer = (char*) obj->trueFree(obj->fInputBuffer);
			obj->fDeinterlaceBuffer = (char*) obj->trueFree(obj->fDeinterlaceBuffer);
			obj->fOutputBuffer = (char*) obj->trueFree(obj->fOutputBuffer);

			// Resize input buffer
			obj->fInputBuffer = (char*) calloc(localframeSizeBytes, sizeof(char));
            obj->fDeinterlaceBuffer = (char*) calloc(localframeSizeBytes, sizeof(char));
			obj->fOutputBuffer = (char*) calloc(localframeSizeBytes, sizeof(char));

			CONSOLEPRINT("Resized fmpThread->frameSize: %d\n",(int) fmpThread->frameSizeBytes,localframeSizeBytes);
		}

		if (obj->isProcessing())
		{
			count++;
			//Polling for frames via NiFpga_ReadFIFO. This blocks automatically when there are no frames.
            if(!fmpThread->simulated)
			{
                if(fmpThread->isMultiChannel){
                    fmpThread->fpgaStatus = NiFpga_ReadFifoI64(fmpThread->fpgaSession, fmpThread->fpgaFifoNumberMultiChan, (int64_t*)obj->fInputBuffer, fmpThread->frameSizeFifoElements, FRAME_WAIT_TIMEOUT,  elementsRemaining);
                    //CONSOLEPRINT("NiFpga_ReadFifoI64. Session: %d,  Frame Size: %d, Elements Remaining: %d\n", (NiFpga_Session)fmpThread->fpgaSession,  (int) fmpThread->frameSizeFifoElements, (int) *elementsRemaining);            
                }
                else
                {
                    fmpThread->fpgaStatus = NiFpga_ReadFifoI16(fmpThread->fpgaSession, fmpThread->fpgaFifoNumberSingleChan, (int16_t*)obj->fInputBuffer, fmpThread->frameSizeFifoElements, FRAME_WAIT_TIMEOUT, elementsRemaining);
                    //CONSOLEPRINT("NiFpga_ReadFifoI16. Session: %d, FIFO number: %d, Frame Size: %d, Elements Remaining: %d\n", (NiFpga_Session)fmpThread->fpgaSession, fmpThread->fpgaFifoNumberSingleChan, (int) fmpThread->frameSizeFifoElements, (int) *elementsRemaining);            
                }
            }
			else
			{
                //***********************************************************************************
                //BEGIN SIMULATED INPUT CODE
                //***********************************************************************************
                fmpThread->fpgaStatus = NiFpga_Status_Success; // always simulate NiFpga Success to 0.
                *elementsRemaining = 0; // always elementsRemaining is zero.

                //Create gradient on all channels.
                int tCount = 0;
                int channelCount = 0;
                int xiter,yiter = 0;
                int16_t* myArray;
                if(fmpThread->isMultiChannel){
                    tCount = 0;
                    myArray = reinterpret_cast<int16_t*> (obj->fInputBuffer);
                    for (channelCount=0;channelCount<4;channelCount++)
                        for (yiter=0; yiter < fmpThread->linesPerFrame; yiter++)
                            for (xiter=0; xiter < fmpThread->pixelsPerLine; xiter++)
                                myArray[tCount++] = (int16_t) xiter;
                }
                else
                {
                    tCount = 0;
                    myArray = reinterpret_cast<int16_t*> (obj->fInputBuffer);
                    for (yiter=0; yiter < fmpThread->linesPerFrame; yiter++)
                        for (xiter=0; xiter < fmpThread->pixelsPerLine; xiter++)
                            myArray[tCount++] = (int16_t) xiter;
                }
                //Add Simulated Frame Tag (if tagging enabled.)
                if (fmpThread->frameTagging)
                {
                    myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2] = -32768;
                    myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+1] = 0;
                    myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+2] = (int16_t) (simulatedFrameCount / 65536);
                    myArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+3] = (int16_t) simulatedFrameCount & 0xFFFF;
                         simulatedFrameCount++;
                }
                Sleep(50);
                //***********************************************************************************
                //END SIMULATED INPUT CODE
                //***********************************************************************************
			}
			if (count % 100 == 0) {
				CONSOLEPRINT("FrameCopier count %d -- Session: %d,  Frame Size in Elements: %d, Elements Remaining: %d\n", count, (NiFpga_Session)fmpThread->fpgaSession,  fmpThread->frameSizeFifoElements, (int) *elementsRemaining);			
			}

			if(fmpThread->fpgaStatus == NiFpga_Status_FifoTimeout)
			{
				//threadSafePrint("FIFO timeout. Retrying.");
				CONSOLEPRINT("Read FIFO timeout. Retrying...\n");
				continue;
			} else if(fmpThread->fpgaStatus != NiFpga_Status_Success)
			{
				CONSOLEPRINT("Error reading from FIFO. Got Status: %d\n", fmpThread->fpgaStatus);		
				//break;
			} else if(fmpThread->fpgaStatus == NiFpga_Status_Success)
			{
				//Got a frame!
				//If we are capturing multiple channels, then de-interlace the input buffer here:
				if (fmpThread->isMultiChannel)
				{
					deinterlaceCount = 0;
					sourceArray = reinterpret_cast<int16_t*>(obj->fInputBuffer);
					destinationArray  = reinterpret_cast<int16_t*>(obj->fDeinterlaceBuffer);
					while (deinterlaceCount < fmpThread->frameSizePixels)
					{
						*destinationArray                      = *(sourceArray++);
						*(destinationArray + frameTwoOffset)   = *(sourceArray++);
						*(destinationArray + frameThreeOffset) = *(sourceArray++);
						*(destinationArray + frameFourOffset)  = *(sourceArray++);
						destinationArray++;
						deinterlaceCount++;
					}
					if (fmpThread->frameTagging)
					{
						//CONSOLEPRINT("TAG RAW VALUE B : %u %u %u %d \n",(uint16_t) *sourceArray,(uint16_t) *(sourceArray+1),(uint16_t) *(sourceArray+2),(int16_t) *(sourceArray+3));
						sourceArray = reinterpret_cast<int16_t*>(obj->fInputBuffer);
						destinationArray  = reinterpret_cast<int16_t*>(obj->fDeinterlaceBuffer);
						destinationArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2] = sourceArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2];
						destinationArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+1] = sourceArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+1];
						destinationArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+2] = sourceArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+2];
						destinationArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+3] = sourceArray[(fmpThread->frameSizeBytes-fmpThread->tagSizeBytes)/2+3];
					}
				}
                int xiter, yiter;
				int transposeCount = 0;
				if (fmpThread->isMultiChannel)
				{
					sourceArray = reinterpret_cast<int16_t*>(obj->fDeinterlaceBuffer);
					destinationArray  = reinterpret_cast<int16_t*>(obj->fOutputBuffer);
					//Transpose data here.
					for (yiter=0;yiter < fmpThread->pixelsPerLine;yiter++)
						for (xiter=0;xiter < fmpThread->linesPerFrame;xiter++)
						{
							destinationArray[transposeCount]                  = sourceArray[yiter + (xiter * fmpThread->pixelsPerLine)];
							destinationArray[transposeCount+frameTwoOffset]   = sourceArray[frameTwoOffset + yiter + (xiter * fmpThread->pixelsPerLine)];
							destinationArray[transposeCount+frameThreeOffset] = sourceArray[frameThreeOffset + yiter + (xiter * fmpThread->pixelsPerLine)];
							destinationArray[transposeCount+frameFourOffset]  = sourceArray[frameFourOffset + yiter + (xiter * fmpThread->pixelsPerLine)];
							transposeCount++;
						}
				}
				else
				{
					sourceArray = reinterpret_cast<int16_t*>(obj->fInputBuffer);
					destinationArray  = reinterpret_cast<int16_t*>(obj->fOutputBuffer);
					for (yiter=0;yiter < fmpThread->pixelsPerLine;yiter++)
						for (xiter=0;xiter < fmpThread->linesPerFrame;xiter++)
							destinationArray[transposeCount++] = sourceArray[yiter + (xiter * fmpThread->pixelsPerLine)];
				}

				//push it to Matlab queue and logging queue
				//push back fInputBuffer (or fDeinterlaceBuffer) into matlab queue for processing.
				// Now that we have the frame, signal event to matlab to read queue and display image.
				if(fmpThread->matlabQueue->push_back(obj->fOutputBuffer))
					AsyncMex_postEventMessage(fmpThread->asyncMex,0);
				// Insert call to logger here...
				if (fmpThread->loggingEnabled)
					if (fmpThread->isMultiChannel){
						if (!fmpThread->loggingQueue->push_back(obj->fDeinterlaceBuffer))
							CONSOLEPRINT("Problem pushing frame back into logging queue...\n");
					}
					else{
						if (!fmpThread->loggingQueue->push_back(obj->fInputBuffer))
							CONSOLEPRINT("Problem pushing frame back into logging queue...\n");
					}
			}
		}
		// Relinquish Control of Thread
		Sleep(0); 
	}

	//mem deallocation
	obj->fInputBuffer = (char*) obj->trueFree(obj->fInputBuffer);
	obj->fDeinterlaceBuffer = (char*) obj->trueFree(obj->fDeinterlaceBuffer);
	obj->fOutputBuffer = (char*) obj->trueFree(obj->fOutputBuffer);
	elementsRemaining = (size_t*) obj->trueFree(elementsRemaining);

	//normal exit
	return 0;
}