#pragma once

#include "stdafx.h"
#include "FPGAFrameCopier.h"
#include <sstream>
#include <process.h>
#include "StateModelObject.h"
#include "FrameQueue.h"
//#include "FPGALSM.h"

FPGAFrameCopier::FPGAFrameCopier(void) : 
fProcessing(0),
fFramesSeen(0),
fFramesMissed(0),
fLastFrameTagCopied(0),
fInputBuffer(NULL),
fProcessedDataFilteredInputBuf(NULL),
fOutputDataFilteredInputBuf(NULL),
fFrameTagEnable(true),
fProcessedDataQ(NULL),
fProcessedDataDecimationFactor(1),
fFpgaStartAcqAddress(0),

#define threadSafePrint(...) EnterCriticalSection(&fProcessFrameCS); _cprintf(__VA_ARGS__); LeaveCriticalSection(&fProcessFrameCS)

{
	fNewFrameEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fNewFrameEvent!=NULL);
	fStartAcqEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fStartAcqEvent!=NULL);
	fKillEvent = CreateEvent(NULL,FALSE,FALSE,NULL);
	assert(fKillEvent!=NULL);

	InitializeCriticalSection(&fProcessFrameCS);

	fThread = (HANDLE) _beginthreadex(NULL,
		0,
		FPGAFrameCopier::threadFcn,
		(LPVOID)this,
		0,
		NULL);
	assert(fThread!=0);

	fMATLABCallbackInfo.asyncMex = NULL;
	fMATLABCallbackInfo.scannerID = -1;
	fMATLABCallbackInfo.enable = false;
}

FPGAFrameCopier::~FPGAFrameCopier(void)
{
	if (fThread!=0) {
		kill();
	}
	CFAEMisc::closeHandleAndSetToNULL(fNewFrameEvent);
	CFAEMisc::closeHandleAndSetToNULL(fStartAcqEvent);
	CFAEMisc::closeHandleAndSetToNULL(fKillEvent);

	DeleteCriticalSection(&fProcessFrameCS);

	// fInputBuffer, fOutputQs, fMATLABCallbackInfo.asyncMex not owned
	// by TFC.
}

HANDLE
FPGAFrameCopier::getNewFrameEvent(void) const
{
	return fNewFrameEvent;
}

void
FPGAFrameCopier::configureMATLABCallback(AsyncMex *asyncMex,int scannerID)
{
	assert(fState==CONSTRUCTED);

	assert(asyncMex!=NULL);
	fMATLABCallbackInfo.asyncMex = asyncMex;
	fMATLABCallbackInfo.scannerID = scannerID;
}

void
FPGAFrameCopier::setMATLABCallbackEnable(bool enable)
{
	assert(fState==CONSTRUCTED);

	fMATLABCallbackInfo.enable = enable;
}
void 

void 
FPGAFrameCopier::configureAcq(FPGAMexParams* fmp){
	this.fmp = fmp;
}

void
FPGAFrameCopier::setProcessedDataDecimationFactor(unsigned int fac)
{
	assert(fState==CONSTRUCTED);

	if (fac==0) {
		fac = 1;
	}
	fProcessedDataDecimationFactor = fac;
}

void
FPGAFrameCopier::setOutputQueues(const std::vector<FrameQueue*> &outputQs)
{
	assert(fState==CONSTRUCTED);

	fOutputQs = outputQs;
}

void
FPGAFrameCopier::setProcessedDataQueue(FrameQueue *q)
{
	assert(fState==CONSTRUCTED);

	fProcessedDataQ = q;
}


bool
FPGAFrameCopier::arm(void)
{
	assert(fState<=ARMED);

	bool tfSuccess = true;

	/// perform verifications, but don't change any state (clear
	/// queues), etc.

	//TODO - put in more array size verifications, taking frameTag into account

	if (fInputBuffer==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	if (fProcessedDataQ==NULL) { 
		CONSOLETRACE();
		tfSuccess = false; 
	}
	//if (fInputImageSize!=fProcessedDataQ->recordSize()) { 
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

	if (fMATLABCallbackInfo.asyncMex==NULL) {
		CONSOLETRACE();
		tfSuccess = false; 
	}
	if (fMATLABCallbackInfo.scannerID<0) { 
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
FPGAFrameCopier::disarm(void)
{
	assert(fState==ARMED || fState==STOPPED);
	assert(fThread!=0);
	assert(fProcessing==0);

	fState = CONSTRUCTED;
}

void
FPGAFrameCopier::startAcq(void)
{
	SetEvent(fStartAcqEvent);
}

void
FPGAFrameCopier::startProcessing(const std::vector<int> &outputQsEnabled)
{
	assert(fState==ARMED || fState==STOPPED);

	fOutputQsEnabled = outputQsEnabled; 

	// If processed data or output Q is not empty, that is unexpected. Throw up a MsgBox.
	if (!fProcessedDataQ->isEmpty()) {
		char str[256];
		sprintf_s(str,256,"FPGAFrameCopier: Processed data queue has size %d!\n",fProcessedDataQ->size());
		MessageBox(NULL,str,"Warning",MB_OK);
	}
	std::size_t numQs = fOutputQs.size();
	for (std::size_t i=0;i<numQs;i++) {
		FrameQueue *queue = fOutputQs[i];
		if (!queue->isEmpty()) {
			char str[256];
			sprintf_s(str,256,"FPGAFrameCopier: Output queue idx %d not empty, has size %d!\n",
				i,queue->size());
			MessageBox(NULL,str,"Warning",MB_OK);
		}
	}

	ResetEvent(fStartAcqEvent);
	ResetEvent(fNewFrameEvent);
	ResetEvent(fKillEvent);

	safeStartProcessing();

	fState = RUNNING;
}

void
FPGAFrameCopier::stopProcessing(void)
{
	assert(fState==RUNNING || fState==STOPPED || fState==PAUSED);

	safeStopProcessing();

	fState = STOPPED;
}

bool
FPGAFrameCopier::isProcessing(void) const
{
	return fProcessing!=0;
}

void
FPGAFrameCopier::pauseProcessing(void)
{
	assert(fState==RUNNING || fState==PAUSED);

	safeStopProcessing();

	fState = PAUSED;
}

void
FPGAFrameCopier::resumeProcessing(void)
{
	assert(fState==PAUSED);

	safeStartProcessing();

	fState = RUNNING;
}

unsigned int
FPGAFrameCopier::getFramesSeen(void) const
{
	return fFramesSeen;  
}

unsigned int
FPGAFrameCopier::getFramesMissed(void) const
{
	return fFramesMissed;  
}


void
FPGAFrameCopier::kill(void)
{  
	SetEvent(fKillEvent); // nonblocking termination of processing thread
	CloseHandle(fThread); // Does not forcibly terminate thread, only
	// releases handle. Thread will terminate
	// when threadFcn exits.
	fThread = 0;
	fState = KILLED;
}

void
FPGAFrameCopier::debugString(std::string &s) const
{
	std::ostringstream oss;
	oss << "--FPGAFrameCopier--" << std::endl;
	oss << "State Processing FramesSeen FramesMissed: " 
		<< fState << " " << fProcessing << " " << fFramesSeen << " " 
		<< fFramesMissed << std::endl;
	oss << "MLCBI.scannerID MLCBI.enable ProcessedDataDecimationFactor: "
		<< fMATLABCallbackInfo.scannerID <<  " "
		<< fMATLABCallbackInfo.enable << " " 
		<< fProcessedDataDecimationFactor << std::endl;
	s.append(oss.str());
}

void
FPGAFrameCopier::safeStartProcessing(void)
{
	EnterCriticalSection(&fProcessFrameCS); 
	fFramesSeen = 0;
	fFramesMissed = 0;
	fLastFrameTagCopied = -1;
	fProcessing = 1;
	LeaveCriticalSection(&fProcessFrameCS);
}

void
FPGAFrameCopier::safeStopProcessing(void)
{
	EnterCriticalSection(&fProcessFrameCS); 
	fProcessing = 0;
	LeaveCriticalSection(&fProcessFrameCS);
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
// in the processing thread (within threadFcn). For example, if
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
WINAPI FPGAFrameCopier::threadFcn(LPVOID userData)
{
	size_t pixelsPerFrame;
	CONSOLETRACE();
	FPGAFrameCopier *obj = static_cast<FPGAFrameCopier*>(userData);
	
	HANDLE evtArray[3];
	evtArray[0] = obj->fKillEvent;
	evtArray[1] = obj->fStartAcqEvent;
	evtArray[2] = obj->fNewFrameEvent;

	//mem allocation
	elementsRemaining = calloc(1,sizeof(size_t));
	if(fImageParams.isMultiChannel){
		pixelsPerFrame = fmp->linesPerFrame*fmp->pixelsPerLine*4;
		fInputBuffer = calloc(pixelsPerFrame*sizeof(uint64_t)/sizeof(char), sizeof(char));
	}
	else{
		pixelsPerFrame = fmp->linesPerFrame*fmp->pixelsPerLine;
		fInputBuffer = calloc(pixelsPerFrame*sizeof(uint16_t)/sizeof(char), sizeof(char));
	}

	bool flag = false;

	while(true){
		//check for stop signal
		if(fStopAcquisition){
			fStopAcquisition = false;
		}

		if ((obj->fProcessing == 1) && (flag == false)) {
			CONSOLETRACE();
			flag = true;
		}


		//Polling for frames via ReadFIFO. This blocks automatically when there are no frames.
		if(fImageParams.isMultiChannel){
			CONSOLEPRINT("threadFcn - fImageParams.isMultiChannel == true - calling niFpga_ReadFifoI16...\n");
			fFpgaStatus = NiFpga_ReadFifoI16(fmp->fpgaSession, fmp->fpgaFifo, fInputBuffer, pixelsPerFrame, FRAME_WAIT_TIMEOUT, fFpgaElementsRemaining)
		}
		else{
			CONSOLEPRINT("threadFcn - fImageParams.isMultiChannel == false - calling niFpga_ReadFifoI64...\n");
			fFpgaStatus = NiFpga_ReadFifoI64(fmp->fpgaSession, fmp->fpgaFifo, fInputBuffer, pixelsPerFrame, FRAME_WAIT_TIMEOUT, fFpgaElementsRemaining)
		}
		
		if(fFpgaStatus == NiFpga_Status_FifoTimeout){
			threadSafePrint("FIFO timeout. Retrying.");
			continue;
		}

		if(fFpgaStatus != NiFpga_Status_Success){
			std::stringstream ss;
			ss << "Error reading from FIFO. Got Status: " << fFpgaStatus << std::endl;
			threadSafePrint(ss.str());
			break;
		}

		//Got a frame! push it to Matlab queue and logging queue
		EnterCriticalSection(&obj->fProcessFrameCS);
		if (obj->fProcessing!=0) {
		
			bool tfErr;

			if (obj->fFrameTagEnable == true)
				tfErr = obj->processAvailableTaggedFramesCaveman();
			else
				tfErr = obj->processAvailableUntaggedFrames();

			if (tfErr) {
				// We report the error, but we do not change obj->fState
				// (currently there is no safe way of doing so within this thread).
				reportNIFPGAError();
			}
		}
		LeaveCriticalSection(&obj->fProcessFrameCS);
		break;
	}

	//mem deallocation
	free(fInputBuffer);
	free(elementsRemaining);
}

void FPGAFrameCopier::stopAcquisition(){
	fStopAcquisition = true;
}

// Note1: The call to this helper method from threadFcn is
// protected by fProcessFrameCS.
// Note2: If the processing thread is executing within
// processAvailableFrames, then the TFC must have fState==RUNNING.
bool
FPGAFrameCopier::processAvailableTaggedFramesCaveman(void)
{
	while (true) {
		long status = CopyAcquisition(fInputBuffer);
		//CONSOLEPRINT("CopyAcquisition at %d ms\n",GetTickCount());
		long *frameTagPtr =  reinterpret_cast<long*>(fInputBuffer + fImageParams.frameSize);
		long frameTag = *frameTagPtr;

		if (frameTag<fLastFrameTagCopied) {
			CONSOLEPRINT("frameTag: %d lastFrameTagCopied:%d\n",frameTag,fLastFrameTagCopied);
			assert(false);
			break;
		} else if (frameTag==fLastFrameTagCopied) {
			CONSOLEPRINT("Same frame tag as lastFrameTagCopied: %d %d\n",frameTag,fLastFrameTagCopied);
			break;
		} else {
			long deltaTag = frameTag - fLastFrameTagCopied;
			fFramesSeen += deltaTag;
			fFramesMissed += deltaTag-1;

			CONSOLEPRINT("IKE: %d\n", frameTag);
			if (deltaTag > 1) {
				CONSOLEPRINT("FPGAFrameCopier: WARNING - Dropped frames! Frame tag jumped by %d frames. Total missed frame tags: %d!!\n",deltaTag,fFramesMissed);
			}

			fLastFrameTagCopied = frameTag;

			char *inputBufTmp = NULL;
			ImageParameters *ip = &fImageParams;

			//Apply offset subtraction, if specified

			// Push to processed data Q; signal MATLAB callback
			// XXX UPDATE THIS LOGIC, fFRAMESSEEN MIGHT JUMP AROUND
			if ((fFramesSeen % fProcessedDataDecimationFactor == 0) && ip->numProcessedDataChannels > 0) {        
				inputBufTmp = filterInputBufferChannels(fProcessedDataFilteredInputBuf,
					ip->processedDataChanVec,ip->numProcessedDataChannels,
					ip->processedDataContiguousChans, ip->processedDataFirstChan,frameTag);

				if (ip->subtractOffsetEnable) {
					subtractInputOffsets(inputBufTmp,ip->processedDataChanVec);
				}	

				bool tfSuccess = fProcessedDataQ->push_back(inputBufTmp);
				if (tfSuccess && fMATLABCallbackInfo.enable) {
					AsyncMex_postEventMessage(fMATLABCallbackInfo.asyncMex,fMATLABCallbackInfo.scannerID);
				}
			}

			// Push onto remaining output Qs (VVV: Only 1 output Q, for logging, is supported at this time)

			std::size_t NQ = fOutputQs.size();

			for (std::size_t i=0;i<NQ;++i) {

				if (fOutputQsEnabled[i]) {

					//Extract logging channels (TODO: Generalize/vectorize this operation to apply for possible other output Qs)

					if (!ip->singleChanVec || inputBufTmp == NULL) { //Can reuse processed-data filtered input buffer, if channel specs are the same          
						inputBufTmp = filterInputBufferChannels(fOutputDataFilteredInputBuf,
							ip->loggingChanVec,ip->numLoggingChannels,
							ip->loggingContiguousChans,ip->loggingFirstChan,frameTag);

						if (ip->subtractOffsetEnable) {
							subtractInputOffsets(inputBufTmp,ip->loggingChanVec);
						}	
					}

					FrameQueue *fq = fOutputQs[i];
					fq->push_back(inputBufTmp);
				}
			}
		}
	}

	return false;
}

//Subtracts input offset values from channels specified in chanActiveVec, if fImageParams.subtractOffsetEnable=true
//Note that any channels for which offset subtraction is individually disabled, the fImageParams.channelsOffsets value is 0.
void 
FPGAFrameCopier::subtractInputOffsets(char *filteredInputBuf, std::vector<int> &chanActiveVec)
{
	CONSOLETRACE();
	int bytesPerPixel = fImageParams.bytesPerPixel;
	int channelSize = fImageParams.frameSizePerChannel; //size in bytes
	bool signedData = fImageParams.signedData;

	assert(bytePerPixel == 2);
	int channelSizeShort = channelSize / bytesPerPixel; //size in shorts (unsigned or not)

	short *inputBufShort;
	unsigned short *inputBufUShort;

	if (signedData) {
		inputBufShort = reinterpret_cast<short*> (filteredInputBuf);
	} else {
		inputBufUShort = reinterpret_cast<unsigned short*> (filteredInputBuf);
	}

	//Do the offset subtraction
	int activeChanCount = -1;
	for (int i=0; i<fImageParams.numChannelsAvailable;++i) {
		int channelOffsetVal = fImageParams.channelOffsets[i];

		if (chanActiveVec[i] > 0) {
			activeChanCount += 1;
		} else {
			continue;
		}

		if (fImageParams.subtractOffsetEnable > 0 && channelOffsetVal != 0) {
			CONSOLEPRINT("Subtracting offset from channel %d\n",i+1);
			for (int j=0; j<(channelSizeShort);++j) {
				int idx = channelSizeShort*activeChanCount + j;
				if (signedData) {
					*(inputBufShort + idx) = *(inputBufShort + idx) - static_cast<short>(channelOffsetVal); 
				} else {
					*(inputBufUShort + idx) = *(inputBufUShort + idx) - static_cast<unsigned short>(channelOffsetVal); 
				}


				//if (signedData) {
				//} else {
				//	*(inputBufUShort + idx) = *(inputBufUShort + idx) - dynamic_cast<channelOffsets[i];
				//}
			}
		}
	}		

}

char *
FPGAFrameCopier::filterInputBufferChannels(char *filteredInputBuffer, std::vector<int> &chanVec, 
										   int numChans, bool contiguousChans, int firstChan, long frameTag)
{ 
	//filteredInputBuffer should be pre-allocated to correct size

	CONSOLETRACE();

	//If selected channels match the number of channels in source input buffer, just use it directly 
	if (numChans == fImageParams.frameNumChannels) {
		return fInputBuffer; 
	}

	int channelSize = fImageParams.frameSizePerChannel; //size in bytes

	//Copy data from input buffer to 'filtered' input buffer
	if (contiguousChans) { 
		//Single copy in case of contiguous channels
		memcpy(filteredInputBuffer,fInputBuffer + firstChan*channelSize,numChans*channelSize);
	} else {
		//Copy channel contents one-at-a-time if channels are not contiguous
		int chanCount = 0;
		for (int i=0;i<fImageParams.numChannelsAvailable;++i)  {    
			if (chanVec[i] > 0) {
				memcpy(filteredInputBuffer + chanCount*channelSize, fInputBuffer + i*channelSize, channelSize);    
				chanCount++;
			}
		}
	}

	//Append frame tag to the returned 'filtered' input buffer, if supplied. 
	//In case of contiguous channels -- this may overwrite some data in the input buffer!
	if (frameTag != -1) { 
		long *frameTagPtr = reinterpret_cast<long *>(filteredInputBuffer + numChans*channelSize);
		*frameTagPtr = frameTag;
	}

	return filteredInputBuffer;
}


bool
FPGAFrameCopier::processAvailableUntaggedFrames(void)
{
	while (true) {
		long statusRet = -13;
		long status = -13;
		long indexOfLastCompletedFrame = -13;

		statusRet = StatusAcquisitionEx(status,indexOfLastCompletedFrame);    

		if (statusRet==0 || status==STATUS_ERROR) {
			return true;

		} else if (status==STATUS_BUSY) {
			// No (more) frames available; all available frames processed successfully.
			return false;

		} else { // STATUS_READY
			// 1+ frames available to be processed.

			long statusRet = CopyAcquisition(fInputBuffer);
			if (statusRet==0) {
				return true;
			}

			// update counters
			fFramesSeen++;
			if (indexOfLastCompletedFrame >= 0) {
				if (indexOfLastCompletedFrame+1 > fFramesSeen) {
					CONSOLEPRINT("FPGAFrameCopier: Dropped frame on frame count %d, Thorlabs idx %d.\n",
						fFramesSeen,indexOfLastCompletedFrame);

					unsigned long missingFrameCount = indexOfLastCompletedFrame + 1 - fFramesSeen; 
					fFramesSeen += missingFrameCount;
					fFramesMissed += missingFrameCount;
				}
			}

			// Processed data Q and MATLAB callback
			if (fFramesSeen % fProcessedDataDecimationFactor==0) {
				bool tfSuccess = fProcessedDataQ->push_back(fInputBuffer);
				if (tfSuccess && fMATLABCallbackInfo.enable) {
					AsyncMex_postEventMessage(fMATLABCallbackInfo.asyncMex,fMATLABCallbackInfo.scannerID);
				}
			}

			// Push onto output Qs
			std::size_t NQ = fOutputQs.size();
			for (std::size_t i=0;i<NQ;++i) {
				FrameQueue *fq = fOutputQs[i];
				fq->push_back(fInputBuffer);
			}
		}
	}
}

void 
FPGAFrameCopier::reportNIFPGAError(void)
{
	wchar_t errmsg[256];
	GetLastErrorMsg(errmsg,256);
	std::wstring msgboxstr(L"FPGAFrameCopier fatal err: ");
	msgboxstr += errmsg;
	MessageBoxW(NULL,msgboxstr.c_str(),NULL,MB_OK);
}
