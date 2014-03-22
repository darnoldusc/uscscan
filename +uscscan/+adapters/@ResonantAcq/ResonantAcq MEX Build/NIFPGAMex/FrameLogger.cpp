#include "stdafx.h"
#include "FrameLogger.h"
#include <sstream>
#include <process.h>

//const char *FrameLogger::FRAME_TAG_FORMAT_STRING = "Frame Tag = %08d\n";
const char *FrameLogger::FRAME_TAG_FORMAT_STRING = "Frame Tag = %16lu\n";

FrameLogger::FrameLogger(void) : 
fThread(0),
//fFrameQueue(NULL),
fTifWriter(new TifWriter()),
fAverageFactor(1),
fAveragingBuf(NULL),
fAveragingResultBuf(NULL),
fKillLoggingFlag(false),
fHaltLoggingFlag(false),
fFramesLogged(0),
//fFrameTagEnable(false),
fmp(MatlabParams::getInstance())
//fFrameDelay(0)
{
	CONSOLEPRINT("FrameLogger::FrameLogger...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	assert(fTifWriter!=NULL);

	fState = CONSTRUCTED;

	InitializeCriticalSection(&fLogfileRolloverCS);
}

FrameLogger::~FrameLogger(void)
{
	CONSOLEPRINT("FrameLogger::~FrameLogger...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	if (fThread!=0) {
		stopLoggingImmediately();
		// Could go stronger and use something like TerminateThread here.
	}

	//fFrameQueue = NULL; // FrameQueue not owned by this obj  
	if (fTifWriter!=NULL) {
		delete fTifWriter;
		fTifWriter = NULL;
	}

	deleteAveragingBuffers();

	DeleteCriticalSection(&fLogfileRolloverCS); // no way to check if this has been initted
}

//bool
//FrameLogger::getFrameTagEnable()
//{
//	CONSOLEPRINT("FrameLogger::getFrameTagEnable...\n");
//	return fFrameTagEnable;
//}

//void
//FrameLogger::setFrameTagProps(bool frameTagEnable,bool frameTagOneBased)
//{
//	CONSOLEPRINT("FrameLogger::setFrameTagProps...\n");
//	assert(fState<ARMED);
//	fFrameTagEnable = frameTagEnable;
//	fFrameTagOneBased = frameTagOneBased;
//}

void 
FrameLogger::configureImage(unsigned int averagingFactor,
							const char *imageDesc)
{
	CONSOLEPRINT("FrameLogger::configureImage...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState<ARMED);
	assert(averagingFactor>0);

	//fImageParams = ip;
	// ip.numChannelsAvailable, ip.numChannelsActive are not used in FrameLogger.
	assert(!fTifWriter->isTifFileOpen());

	//Handle frame tag case, if applicable -- prepend frame tag, pad image description
	std::string imageDescStr = imageDesc;
	if (fmp->frameTagging) {
		//Prepend frame tag
		char frameTagStr[FRAME_TAG_STRING_LENGTH+1]="0";
		sprintf_s(frameTagStr,FRAME_TAG_FORMAT_STRING,0); 
		imageDescStr.insert(0,frameTagStr);

		//Pad image description (allows for ease of modifying description contents without recomputing IFDs etc)
		imageDescStr.append(IMAGE_DESC_DEFAULT_PADDING,' ');
		CONSOLEPRINT("SETTING DEFAULT HEADER TO: %s\n",imageDescStr.c_str());
	}

	//fTifWriter->configureImage(ip.imageWidth,ip.imageHeight,ip.bytesPerPixel,
	//	ip.numLoggingChannels,ip.signedData,imageDescStr.c_str());
	fTifWriter->configureImage((unsigned short) fmp->pixelsPerLine, (unsigned short) fmp->linesPerFrame,fmp->pixelSizeBytes,fmp->numLoggingChannels,fmp->signedData,imageDescStr.c_str());
	fConfiguredImageDescLength = (unsigned int) imageDescStr.length();

	fAverageFactor = averagingFactor;
	this->deleteAveragingBuffers();

	if (fAverageFactor > 1) {
		//CONSOLEPRINT("fImP.fnp: %d. faB: %p. sizeof fab: %d\n",fImageParams.frameNumPixels,fAveragingBuf,(sizeof fAveragingBuf));
		fAveragingBuf = new double[fmp->frameSizePixels * fmp->numLoggingChannels]();
		fAveragingResultBuf = new char[fmp->frameSizePixels * fmp->numLoggingChannels](); 
		assert(fAveragingBuf!=NULL);
		assert(fAveragingResultBuf!=NULL);
		zeroAveragingBuffers();
	}

	return;
}


//void 
//FrameLogger::configureImage(const ImageParameters &ip,
//							unsigned int averagingFactor,
//							const char *imageDesc)
//{
//	CONSOLETRACE();
//	assert(fState<ARMED);
//	assert(averagingFactor>0);
//
//	fImageParams = ip;
//	// ip.numChannelsAvailable, ip.numChannelsActive are not used in FrameLogger.
//	assert(!fTifWriter->isTifFileOpen());
//
//	//Handle frame tag case, if applicable -- prepend frame tag, pad image description
//	std::string imageDescStr = imageDesc;
//	if (fFrameTagEnable) {
//		//Prepend frame tag
//		char frameTagStr[FRAME_TAG_STRING_LENGTH+1]="0";
//		sprintf(frameTagStr,FRAME_TAG_FORMAT_STRING,0); 
//		imageDescStr.insert(0,frameTagStr);
//
//		//Pad image description (allows for ease of modifying description contents without recomputing IFDs etc)
//		imageDescStr.append(IMAGE_DESC_DEFAULT_PADDING,' ');
//	}
//
//	fTifWriter->configureImage(ip.imageWidth,ip.imageHeight,ip.bytesPerPixel,
//		ip.numLoggingChannels,ip.signedData,imageDescStr.c_str());
//	fConfiguredImageDescLength = imageDescStr.length();
//
//	fAverageFactor = averagingFactor;
//	this->deleteAveragingBuffers();
//
//	if (fAverageFactor > 1) {
//		//CONSOLEPRINT("fImP.fnp: %d. faB: %p. sizeof fab: %d\n",fImageParams.frameNumPixels,fAveragingBuf,(sizeof fAveragingBuf));
//		fAveragingBuf = new double[ip.frameNumPixels * ip.numLoggingChannels]();
//		fAveragingResultBuf = new char[ip.frameSizePerChannel * ip.numLoggingChannels](); 
//		assert(fAveragingBuf!=NULL);
//		assert(fAveragingResultBuf!=NULL);
//		zeroAveragingBuffers();
//	}
//
//	return;
//}

void 
FrameLogger::configureFile(const char *filename, const char *fileModeStr)
{
	CONSOLEPRINT("FrameLogger::configureFile...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLEPRINT("Filename: %s, fileModeStr: %s\n",filename,fileModeStr);
	CONSOLETRACE();
	assert(fState<ARMED);

	assert(filename!=NULL);
	assert(fileModeStr!=NULL);

	// To configure the file before the acq, we put a single logfileNote
	// in the logfileNotes with frameidx of 1.
	//
	// We treat this call as a reset of the logfilenotes.
	fLogfileNotes.clear();
	LogFileNote lfn(filename,fileModeStr,1);
	fLogfileNotes.push_front(lfn);
}  

// void 
// FrameLogger::setHeaderString(const char *str)
// {
// }

// arm ensures that all configuration-related state is set
// properly. runtime state is not initialized until startLogging().
bool
FrameLogger::arm(void)
{
	CONSOLEPRINT("FrameLogger::arm...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	// As in ThorFrameCopier, we perform verifications, but do not
	// modify any state here.

	assert(fState==CONSTRUCTED || fState==ARMED);
	assert(fThread==0);

	bool tfSuccess = true;

	if (fmp->loggingQueue==NULL) { tfSuccess = false; }
	if (fTifWriter==NULL) { tfSuccess = false; }
	assert(!fTifWriter->isTifFileOpen());
	if (fmp->loggingQueue->recordSize()!=fmp->frameSizeBytes) { tfSuccess = false; }
	// assume fImageParams and fTifWriter agree
	if (fAverageFactor>1 && (fAveragingBuf==NULL || fAveragingResultBuf==NULL)) {
		tfSuccess = false;
	}
	if ( !(fLogfileNotes.size()==1 && fLogfileNotes.front().frameIdx==1) ) { 
		// Initial file not configured
		tfSuccess = false; 
	}

	fState = (tfSuccess) ? ARMED : CONSTRUCTED;

	return tfSuccess;  
}

void
FrameLogger::disarm(void)
{
	CONSOLEPRINT("FrameLogger::disarm...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	assert(fState==ARMED || fState==STOPPED);
	assert(fThread==0);
	fState = CONSTRUCTED;
}

void
//FrameLogger::startLogging(int frameDelay)
FrameLogger::startLogging(void)
{
	CONSOLEPRINT("FrameLogger::startLogging...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState==ARMED);
	assert(fThread==0);

	// pre-start state initializations
	//fFrameDelay = frameDelay;
	fKillLoggingFlag = false;
	fHaltLoggingFlag = false;
	fFramesLogged = 0; 

	if (fAverageFactor > 1) {    
		zeroAveragingBuffers();
	}

	if (!fmp->loggingQueue->isEmpty())
		CONSOLEPRINT("FrameLogger: Input queue is nonempty, has size %d.\n", fmp->loggingQueue->size());
	// If fFrameQueue is nonempty, that is bizzaro. Throw a msgbox
	//if (!fFrameQueue->isEmpty()) {

	//	// xxx this comes up in testing b/c of the
	//	// "start-logger-after-acq-started" thing, the messagebox might be
	//	// modal or something

	//	CONSOLEPRINT("FrameLogger: Input queue is nonempty, has size %d.\n",
	//		fFrameQueue->size());

	//	// char str[256];
	//	// sprintf_s(str,256,"FrameLogger: Input queue is nonempty, has size %d.\n",
	//	// 	    fFrameQueue->size());
	//	// MessageBox(NULL,str,"Warning",MB_OK);
	//}
	fThread = (HANDLE)_beginthreadex(NULL,0,FrameLogger::loggingThreadFcn,(LPVOID)this,0,NULL);
	assert(fThread!=0);
	fState = RUNNING;
}

bool 
FrameLogger::isLogging(void) const 
{
	CONSOLEPRINT("FrameLogger::isLogging...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	return fState==RUNNING;
}

void 
FrameLogger::stopLogging(void) 
{
	CONSOLEPRINT("FrameLogger::stopLogging...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState==RUNNING);
	CONSOLEPRINT("FrameLogger: fState is RUNNING \n");
	assert(fThread!=0);
	CONSOLEPRINT("FrameLogger: fthread != 0\n");

	fHaltLoggingFlag = true; 

	// Stop signal sent. Now wait for logging thread to terminate.

	DWORD retval = WaitForSingleObject(fThread,STOP_LOGGING_TIMEOUT_MILLISECONDS);
	switch (retval) {
	  case WAIT_OBJECT_0:
		  CONSOLEPRINT("FrameLogger::stopLogging WAIT_OBJECT_0...\n");
		  // logging thread completed.
		  {
			  BOOL b = CloseHandle(fThread);
			  assert(b!=0);
			  fThread = 0;
			  // other runtime state can remain as-is in STOPPED state. to start,
			  // will have to disarm + arm + startLogging.
		  }
		  fState = STOPPED;
		  break;

	  case WAIT_TIMEOUT:
	  case WAIT_ABANDONED:
	  case WAIT_FAILED:
	  default:
		  CONSOLEPRINT("FrameLogger::stopLogging HARD STOP!!\n");
		  // Try harder to stop logging.
		  stopLoggingImmediately(); 

		  assert(fState==STOPPED || fState==KILLED);

		  if (fState==STOPPED) {
			  CONSOLEPRINT("FrameLogger: Logger could not finish processing. %d frames were unlogged.\n", fmp->loggingQueue->size());
			  // stopImmediately succeeded, which means everything is okay, but
			  // that we didn't finish logging.
			  //char str[256];
			  //sprintf_s(str,256,"FrameLogger: Logger could not finish processing. %d frames were unlogged.\n", fmp->loggingQueue->size());
			  //MessageBox(NULL,str,"Warning",MB_OK);
		  }

		  break;
	}
}

void
FrameLogger::stopLoggingImmediately(void)
{
	CONSOLEPRINT("FrameLogger::stopLoggingImmediately...\n");
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	CONSOLETRACE();
	assert(fState==RUNNING);
	assert(fThread!=0);

	fKillLoggingFlag = true; 

	DWORD retval = WaitForSingleObject(fThread, STOP_LOGGING_TIMEOUT_MILLISECONDS);
	switch (retval) {
		case WAIT_OBJECT_0:
			// logging thread stopped.
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
			// stop immediately failed; we are hosed
			{
				CONSOLEPRINT("FrameLogger: Unable to stop logger. Please report this error to the ScanImage team.\n");
				//char str[256];
				//sprintf_s(str,256,"FrameLogger: Unable to stop logger. Please report this error to the ScanImage team.\n");
				//MessageBox(NULL,str,"Error",MB_OK);
			}
			fState = KILLED; // FrameLogger will be unusable in this state
			break;
		}
}

void
FrameLogger::addLogfileRolloverNote(const LogFileNote &lfn)
{
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	assert(fState==ARMED || fState==RUNNING || fState == STOPPED);

	EnterCriticalSection(&fLogfileRolloverCS);

	if (!fLogfileNotes.empty()) {
		// enforce strict monotonicity
		assert(fLogfileNotes.back().frameIdx < lfn.frameIdx);
	}
	fLogfileNotes.push_back(lfn);

	LeaveCriticalSection(&fLogfileRolloverCS);
}

unsigned long
FrameLogger::getFramesLogged(void) const
{
	CONSOLEPRINT("FrameLogger::fState: %d\n", fState);
	return fFramesLogged;
}

void
FrameLogger::debugString(std::string &s) const
{
	std::ostringstream oss;
	oss << "--FrameLogger--" << std::endl;
	oss << "State Thread TifWriterFileOpen fAvFactor: " 
		<< fState << " " << fThread << " " 
		<< fTifWriter->isTifFileOpen() << " " 
		<< fAverageFactor << std::endl;
	oss << "KillLoggingFlag HaltLoggingFlag FramesLogged: "
		<< fKillLoggingFlag << " "
		<< fHaltLoggingFlag << " " 
		<< fFramesLogged << std::endl;

	s.append(oss.str());  
	//fImageParams.debugString(s);

	oss.str("");
	std::size_t numNotes = fLogfileNotes.size();
	for (std::size_t i=0;i<numNotes;i++) {
		oss << "LogfileNote " << i << ": " << "fname modestr frmIdx: " 
			<< fLogfileNotes[i].filename << " " 
			<< fLogfileNotes[i].modeStr << " " 
			<< fLogfileNotes[i].frameIdx << std::endl;
	}
	s.append(oss.str());
}

//unsigned int WINAPI FrameLogger::loggingThreadFcn(LPVOID userData)
unsigned __stdcall FrameLogger::loggingThreadFcn( void* userData )
{
	CONSOLEPRINT("FrameLogger::loggingThreadFcn...\n");
	FrameLogger *obj = static_cast<FrameLogger*>(userData);

	unsigned long localFrameTag;

	//Instantiate the MatlabParams singleton.	
	MatlabParams* fmpThread = MatlabParams::getInstance();
	const int16_t* sourceArray;
	int16_t  fpgaTagIdentifier;
	uint16_t fpgaPlaceHolder;
	uint16_t fpgaTotalAcquiredRecordsA;
	uint16_t fpgaTotalAcquiredRecordsB;

	while (1) {
		if (obj->fKillLoggingFlag) {
			CONSOLEPRINT("KILL LOGGING FLAG: %d\n",obj->fKillLoggingFlag);
			break;
		}
		if (obj->fHaltLoggingFlag && fmpThread->loggingQueue->isEmpty()) {
			CONSOLEPRINT("HALT LOGGING FLAG: %d, LOGGING QUEUE EMPTY? %d\n",obj->fHaltLoggingFlag,(int) fmpThread->loggingQueue->isEmpty());
			break;
		}

		//TODO: Log File Notes
		/// Roll over file if appropriate
		EnterCriticalSection(&obj->fLogfileRolloverCS);
		//CONSOLETRACE();
		if (!obj->fLogfileNotes.empty()) {
		 
			const LogFileNote &lfn = obj->fLogfileNotes.front();
			unsigned long framesLoggedPlus1 = obj->fFramesLogged+1; //fFramesLogged is 0-based
			if (framesLoggedPlus1 > lfn.frameIdx) { 
				// already beyond first logfilenote; ignore
				CONSOLEPRINT("FrameLogger: ignoring log file note (fname frameidx %s %d), already at frameIdx+1==%d.\n",lfn.filename.c_str(),lfn.frameIdx,framesLoggedPlus1);
				// TODO do a mexprintf here, maybe redef CONSOLEPRINT macro.
				obj->fLogfileNotes.pop_front();

			} else if (framesLoggedPlus1 == lfn.frameIdx) { 
				CONSOLEPRINT("FrameLogger: rolling over file (fname frameIdx %s %d).\n",lfn.filename.c_str(),lfn.frameIdx);
				if (obj->fTifWriter->isTifFileOpen()) {
					obj->fTifWriter->closeTifFile();
				}
				if (!obj->fTifWriter->openTifFile(lfn.filename.c_str(),lfn.modeStr.c_str())) {
				    CONSOLEPRINT("FrameLogger: Error opening file %s. Aborting logging.\n",lfn.filename.c_str());
					//char str[256];
					//sprintf_s(str,256,"FrameLogger: Error opening file %s. Aborting logging.\n",lfn.filename.c_str());
					//MessageBox(NULL,str,"Error",MB_OK);
					// This break will exit loggingThreadFcn. Subsequent calls
					// to stopLogging or stopLoggingImmediately will "succeed".
					break; 
				}       
				CONSOLETRACE();

				//Handle image description update, if supplied
				std::string imd = lfn.imageDesc;       
				if (!imd.empty()) {
					if (fmpThread->frameTagging) {
						size_t padLength = obj->fConfiguredImageDescLength - imd.length();
						if (padLength > 0) {
							imd.append(padLength,' ');
						} else if (padLength < 0) { //New header is longer than (previous header + IMAGE_DESC_DEFAULT_PADDING)
                            CONSOLEPRINT("FrameLogger: Header string modified to length larger than logging stream was configured to handle.\n");
							//char str[256];
							//sprintf_s(str,256,"FrameLogger: Header string modified to length larger than logging stream was configured to handle.");
							//MessageBox(NULL,str,"Error",MB_OK);
							// This break will exit loggingThreadFcn. Subsequent calls
							// to stopLogging or stopLoggingImmediately will "succeed".
							break; 
						}
						obj->fTifWriter->modifyImageDescription(FRAME_TAG_STRING_LENGTH,imd.c_str(),obj->fConfiguredImageDescLength+1);
					} else {
						obj->fTifWriter->replaceImageDescription(lfn.imageDesc.c_str());
					}          
				}

				obj->fLogfileNotes.pop_front();

			} else {
				// Haven't reached lfn.frameIdx yet
			}
		}

		LeaveCriticalSection(&obj->fLogfileRolloverCS);
		//CONSOLETRACE();

		// Write frame to TIF file
		if (fmpThread->loggingQueue->size() >= (unsigned int) (fmpThread->frameDelay + 1) || (obj->fHaltLoggingFlag && !fmpThread->loggingQueue->isEmpty())) {
//			CONSOLEPRINT("Framelogger: Writing frame to TIF file...\n");
//		    CONSOLETRACE();
		assert(obj->fTifWriter->isTifFileOpen());

		// update local tag if tagging is enabled.
		if (fmpThread->frameTagging) {
			sourceArray = static_cast<const int16_t*>(fmpThread->loggingQueue->front_unsafe());
			fpgaTagIdentifier = (int16_t) sourceArray[(fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2];
			fpgaPlaceHolder = (uint16_t) sourceArray[(fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2 + 1];
			fpgaTotalAcquiredRecordsA = (uint16_t) sourceArray[(fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2 + 2];
			fpgaTotalAcquiredRecordsB = (uint16_t) sourceArray[(fmpThread->frameSizeBytes - fmpThread->tagSizeBytes)/2 + 3];
			localFrameTag = (unsigned long) fpgaTotalAcquiredRecordsA * (unsigned long) 65536 + (unsigned long) fpgaTotalAcquiredRecordsB;
			//CONSOLEPRINT("localFrameTag: %lu\n",localFrameTag);
		}

		// Three threads access fFrameQueue: this thread (the logging
		// thread), the ThorFrameCopier thread (doing pushes only), and
		// the MATLAB exec thread (acting as the controller). Use
		// front_checkout/checkin to protect against controller eg
		// initting the queue while we read (unlikely but conceivable).

		//CONSOLETRACE();
		const void *framePtr = fmpThread->loggingQueue->front_checkout();

		const char *charFramePtr = static_cast<const char*>(framePtr);

		if (obj->fAverageFactor==1) {
			// no averaging.

			if (fmpThread->frameTagging) {
				//CONSOLETRACE();

				if (!obj->updateFrameTag(charFramePtr,localFrameTag)) {
					CONSOLETRACE();

					// This break will exit loggingThreadFcn. Subsequent calls
					// to stopLogging or stopLoggingImmediately will "succeed".
					break; 
				}          
			}
			//CONSOLETRACE();

			// If this hangs/throws, front_checkin will never be called
			// and we will lock up.
		//	CONSOLETRACE();
			obj->fTifWriter->writeFramesForAllChannels(charFramePtr,(unsigned int) fmpThread->frameSizeBytes * fmpThread->numLoggingChannels);
		//	CONSOLETRACE();


			fmpThread->loggingQueue->front_checkin();
		} else {

			int modVal = obj->fFramesLogged % obj->fAverageFactor;
			if (modVal == 0) {
				obj->zeroAveragingBuffers();
			}
			bool computeAverageTF = (modVal + 1 == obj->fAverageFactor);

			obj->addToAveragingBuffer(framePtr);

			if (fmpThread->frameTagging && computeAverageTF) {
				if (!obj->updateFrameTag(charFramePtr,localFrameTag)) {
					// This break will exit loggingThreadFcn. Subsequent calls
					// to stopLogging or stopLoggingImmediately will "succeed".
					break; 
				}      
			}

			fmpThread->loggingQueue->front_checkin();
			framePtr = NULL;

			if (computeAverageTF) {
				obj->computeAverageResult();

				obj->fTifWriter->writeFramesForAllChannels(obj->fAveragingResultBuf,(unsigned int) fmpThread->frameSizeBytes * fmpThread->numLoggingChannels);
			}
		}

		fmpThread->loggingQueue->pop_front();
		obj->fFramesLogged++;
		}

		Sleep(0); //relinquish thread
	}

	CONSOLEPRINT("FrameLogger: exiting logging thread.\n");

	if (obj->fTifWriter->isTifFileOpen()) {
		obj->fTifWriter->closeTifFile();
	}

	return 0;
}

bool
FrameLogger::updateFrameTag(const char *framePtr)
{
	CONSOLEPRINT("FrameLogger::updateFrameTag...\n");
	CONSOLETRACE();
	//TODO: Put frame tag computation code from nifpgamex.cpp in here.
	//const long *frameTagPtr =  reinterpret_cast<const long*>(framePtr + fmp->numLoggingChannels * fmp->frameSizeBytes);
	
	//long frameTag = *frameTagPtr;
	long frameTag = 0; // This is for testing only! Remove and replace with real frame tag computation code.
	if (fmp->frameTagOneBased) {
		frameTag++;
	}

	char frameTagStr[FRAME_TAG_STRING_LENGTH+1] = "0";
	int numWritten = sprintf_s(frameTagStr,FRAME_TAG_FORMAT_STRING,frameTag);
	//int numWritten = sprintf_s(frameTagStr,FRAME_TAG_STRING_LENGTH+1,"Frame Tag = %08d",frameTag);  

	if (numWritten == FRAME_TAG_STRING_LENGTH) {
		fTifWriter->modifyImageDescription(0,frameTagStr,FRAME_TAG_STRING_LENGTH);
		return true;
	} else {
		char str[256];
		sprintf_s(str,256,"FrameLogger: Error writing frame tag. Wrote %d chars to make string: %s. (should have written %d). Aborting logging.\n",numWritten,frameTagStr,FRAME_TAG_STRING_LENGTH);
		MessageBox(NULL,str,"Error",MB_OK);
		return false;
	}
}

bool
FrameLogger::updateFrameTag(const char *framePtr, unsigned long frameTag)
{
	//CONSOLEPRINT("FrameLogger::updateFrameTag...\n");
	//CONSOLETRACE();
	//TODO: Put frame tag computation code from nifpgamex.cpp in here.
	//const long *frameTagPtr =  reinterpret_cast<const long*>(framePtr + fmp->numLoggingChannels * fmp->frameSizeBytes);
	
	//long frameTag = *frameTagPtr;
	//long frameTag = 0; // This is for testing only! Remove and replace with real frame tag computation code.
	//if (fmp->frameTagOneBased) {
	//	frameTag++;
	//}

	//*frameTagPtr = frameTag;

	char frameTagStr[FRAME_TAG_STRING_LENGTH+1] = "0";
	int numWritten = sprintf_s(frameTagStr,FRAME_TAG_FORMAT_STRING,frameTag);
	//int numWritten = sprintf_s(frameTagStr,FRAME_TAG_STRING_LENGTH+1,"Frame Tag = %08d",frameTag);  

	if (numWritten == FRAME_TAG_STRING_LENGTH) {
		fTifWriter->modifyImageDescription(0,frameTagStr,FRAME_TAG_STRING_LENGTH);
//		CONSOLEPRINT("FRAME TAG STRING: %s, FRAME TAG STRING LENGTH: %d\n",frameTagStr, FRAME_TAG_STRING_LENGTH);
		return true;
	} else {
		char str[256];
		sprintf_s(str,256,"FrameLogger: Error writing frame tag. Wrote %d chars to make string: %s. (should have written %d). Aborting logging.\n",numWritten,frameTagStr,FRAME_TAG_STRING_LENGTH);
		MessageBox(NULL,str,"Error",MB_OK);
		return false;
	}
}

void FrameLogger::zeroAveragingBuffers(void)
{
	assert(fAveragingBuf!=NULL);
	for (size_t i=0;i<(fmp->frameSizePixels * fmp->numLoggingChannels);i++) {
		fAveragingBuf[i] = 0.0;
	}
	assert(fAveragingResultBuf!=NULL);
	for (size_t i=0;i<(fmp->frameSizeBytes * fmp->numLoggingChannels);i++) {
		fAveragingResultBuf[i] = 0; // unnnecessary, defensive programming
	}
}

void FrameLogger::addToAveragingBuffer(const void *p)
{
	assert(fAveragingBuf!=NULL);
	assert(sizeof(short)==2);
	assert(sizeof(long)==4);

	for (int i=0;i<(fmp->frameSizePixels*fmp->numLoggingChannels);i++) {
		switch (fmp->pixelSizeBytes) {
	case 1:
		fAveragingBuf[i] += (double) (*((char*)p + i)); // ((char*)p)[i]
		break;
	case 2:
		fAveragingBuf[i] += (double) (*((short*)p + i)); // etc
		break;
	case 4:
		fAveragingBuf[i] += (double) (*((long*)p + i));
		break;
	default:
		assert(false);
		}
	}
}

void FrameLogger::computeAverageResult(void)
{
	for (int i=0;i<(fmp->frameSizePixels * fmp->numLoggingChannels);++i) {
		double avVal = fAveragingBuf[i] / (double)fAverageFactor;
		switch (fmp->pixelSizeBytes) {
	case 1:
		((char *)fAveragingResultBuf)[i] = (char)avVal;
		break;
	case 2:				
		((short *)fAveragingResultBuf)[i] = (short)avVal;
		break;
	case 4:
		((long *)fAveragingResultBuf)[i] = (long)avVal;
		break;
	default:
		assert(false);
		}
	}
}

void
FrameLogger::deleteAveragingBuffers(void) 
{
	if (fAveragingBuf!=NULL) {
		delete[] fAveragingBuf;
		fAveragingBuf = NULL;
	}
	if (fAveragingResultBuf!=NULL) {
		delete[] fAveragingResultBuf;
		fAveragingResultBuf = NULL;
	}

}

//**********************************************************************************
//The following code is taken from ThorLSM and incorporated in the framelogger code.

void
FrameLogger::configureLogFile(void)
{
    CONSOLEPRINT("FrameLogger::configureLogFile...\n");
	CONSOLETRACE();

	assert(!isLogging());

	CONSOLEPRINT("FrameLogger::configureLogFile - ensuring disarmed...\n");
	ensureDisarmed();
	CONSOLEPRINT("FrameLogger::configureLogFile - calling configureImage...\n");
	configureImage((unsigned int) fmp->loggingAverageFactor,fmp->loggingHeaderString);
	CONSOLEPRINT("FrameLogger::configureLogFile - calling configureFile...\n");
	configureFile(fmp->loggingFullFileName,fmp->loggingOpenModeString);  
}

// See note for thorFrameCopierEnsureDisarmed.
void
FrameLogger::ensureDisarmed(void)
{
	if (isLogging()) {
		CONSOLEPRINT("Logger was logging, stopping.\n");
		stopLogging();
	}
	disarm();
}