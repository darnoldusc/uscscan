struct AsyncMexMATLABCallbackArgs {

  static const unsigned int CALLBACK_EVENT_DATA_NUM_FIELDS = 5;
  static const char *CALLBACK_EVENT_DATA_FIELD_NAMES[];

  mxArray *rhs[3];
  mxArray *evtData;
  mxArray *framesAvailableArray;
  mxArray *droppedFramesArray;
  mxArray *droppedLogFramesArray;
  mxArray *droppedMLCallbackFramesArray;
  mxArray *frameCountArray;

  AsyncMexMATLABCallbackArgs(void);

  ~AsyncMexMATLABCallbackArgs(void);
};