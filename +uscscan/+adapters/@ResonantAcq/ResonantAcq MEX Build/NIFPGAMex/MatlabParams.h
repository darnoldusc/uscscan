//stores all Matlab-connected data
//Singleton class. If you don't know what that means, look it up.
#pragma once

#include "stdafx.h"
#include "AsyncMex.h"
#include "mex.h"
#include "FrameCopier.h"
#include "FrameLogger.h"

class MatlabParams
{
	//Leaving most of the member variables public for now, because
	//this is being refactored from a struct. May make private later.
public:
	//constants
    static const char *DEFAULT_LOG_FILENAME;
	static const unsigned int MAXFILENAMESIZE = 256;
	static const unsigned int MAXIMAGEHEADERSIZE = 8194; 
    
	//simulated operation.
	bool simulated;

	//image and acquisition parameters
	size_t pixelsPerLine;
	size_t linesPerFrame;
	bool frameTagging;
	bool isMultiChannel;
	unsigned long frameQueueCapacity;

	size_t frameSizePixels;        //Number of Pixels in one frame (not including frame tag)
    size_t frameSizeBytes;         //Number of Bytes in one frame (frame + optional frame tag)
    size_t frameSizeFifoElements;  //Number of FIFO elements for one frame (frame + optional frame tag)
	size_t tagSizeBytes;           //Tag Size in Bytes (0 for frameTagging == 0)
    size_t tagSizeFifoElements;    //Number of FIFO elements for the tag (0 for frameTagging == 0)

	//used for frameLogger only.
	bool loggingEnabled;
	unsigned short pixelSizeBytes;
	unsigned short numLoggingChannels;
    bool frameTagOneBased;
	bool signedData;
	int frameDelay;
	unsigned int loggingAverageFactor;
	char loggingFullFileName[MAXFILENAMESIZE];
	char loggingOpenModeString[8];
	char loggingHeaderString[MAXIMAGEHEADERSIZE];

	//fpga parameters
	NiFpga_Status fpgaStatus;
	NiFpga_Session fpgaSession;
	uint32_t fpgaFifoNumberSingleChan;
	uint32_t fpgaFifoNumberMultiChan;
	size_t* fpgaElementsRemaining;

	//matlab 
	mxArray* resonantAcqObject;
	mxArray* NIFPGAObject;
	AsyncMex* asyncMex;
	mxArray* callbackFuncHandle;
	bool callbackEnabled;

	//C++ objects
	FrameQueue* matlabQueue;
	FrameQueue* loggingQueue;

	//Instrumentation data
	long numDroppedFramesCopier;
	unsigned long lastCopierTag;

public:
	static MatlabParams* getInstance();
	~MatlabParams();

	//void setIsMultiChannel(int value);
	//void setFifoNumber(uint32_t fifoNumber);
	//void setSession(NiFpga_Session sessionID);
	void MatlabParams::readPropsFromMatlab();
	void MatlabParams::setCallback(mxArray* mxCbk);

private:
	MatlabParams();
	//mxArray* getAttrib(MatlabParams*, const mxArray*);
	
	static MatlabParams* instance;
};



//Other parameters we might need someday

/*

struct ImageParameters {
  bool isMultiChannel;
  int imageHeight;
  int imageWidth;
  int bytesPerPixel;
  bool signedData;
  int numChannelsAvailable;
  int numProcessedDataChannels;
  int numLoggingChannels;

  int processedDataFirstChan; //First channel (starting with 1) designated to be included in data retrieved by getProcessedData()
  int loggingFirstChan; //First channel (starting with 1) designated to be included in frames logged to disk
  bool processedDataContiguousChans; //true if processed data channels are contiguous, e.g. 1-3, 2-4, not 1,3,4
  bool loggingContiguousChans; //true if processed data channels are contiguous, e.g. 1-3, 2-4, not 1,3,4

  std::vector<int> processedDataChanVec; //Vector of booleans, of size numChannelsAvailable, indicating which channels are designated to be included in data retrieved by getProcessedData()
  std::vector<int> loggingChanVec; //Vector of booleans, of size numChannelsAvailable, indicating which channels are designated to be included in frames logged to disk
  std::vector<int> chansToCopyVec; //Vector of booleans, of size numChannelsAvailable, containing the union of processedDataChanVec & loggingChanVec -- all the channels that are to be copied, for one purpose or another.
  bool singleChanVec; //true if processedDataChanVec=loggingChanVec

  bool subtractOffsetEnable;  //Boolean value true when one or more channel offset values should be subtracted
  std::vector<int> channelOffsets; //Vector of short integers representing last-measured offset value for each input channel. Value of 0 indicates no measured offset for a channel, or to disable subtraction for that channel.
  
  int frameNumChannels; // number of channels acquired by Thor API
  int frameNumPixels;
  int frameSize; // size of frame in bytes, including all of the frameNumChannels
  int frameSizePerChannel; //size of frame in bytes, for each channel

  ImageParameters(void) : 
    isMultiChannel(0),
    imageHeight(0), 
    imageWidth(0), 
    bytesPerPixel(0),
    signedData(0),
    numChannelsAvailable(0),
    numProcessedDataChannels(0),
    numLoggingChannels(0),
    processedDataFirstChan(-1),
    loggingFirstChan(-1),
    processedDataContiguousChans(false),
    loggingContiguousChans(false),
    singleChanVec(false),
	subtractOffsetEnable(0),
    frameNumChannels(0), //Can be either 1 or 4, given ThorAPI 
    frameNumPixels(0),
    frameSize(0),
    frameSizePerChannel(0)
  { 
  }

  // initialize values based on lsm M-object.
  void init(const mxArray* lsmObj);

  // Append debug info to s.
  void debugString(std::string &s) const;
};

*/