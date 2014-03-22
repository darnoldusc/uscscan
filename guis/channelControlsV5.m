function varargout = channelControlsV5(varargin)
% CHANNELCONTROLSV5 MATLAB code for channelControlsV5.fig
%      CHANNELCONTROLSV5, by itself, creates a new CHANNELCONTROLSV5 or raises the existing
%      singleton*.
%
%      H = CHANNELCONTROLSV5 returns the handle to a new CHANNELCONTROLSV5 or the handle to
%      the existing singleton*.
%
%      CHANNELCONTROLSV5('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CHANNELCONTROLSV5.M with the given input arguments.
%
%      CHANNELCONTROLSV5('Property','Value',...) creates a new CHANNELCONTROLSV5 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before channelControlsV5_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to channelControlsV5_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help channelControlsV5

% Last Modified by GUIDE v2.5 20-Mar-2014 17:31:57

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @channelControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @channelControlsV5_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before channelControlsV5 is made visible.
function channelControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to channelControlsV5 (see VARARGIN)

% Choose default command line output for channelControlsV5
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes channelControlsV5 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = channelControlsV5_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in cbDisplayChannel1.
function cbDisplayChannel1_Callback(hObject, eventdata, handles)
% hObject    handle to cbDisplayChannel1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of cbDisplayChannel1
value = get(hObject,'Value');
handles.hController.changeChannelsActive(1,value);


% --- Executes on button press in cbDisplayChannel2.
function cbDisplayChannel2_Callback(hObject, eventdata, handles)
% hObject    handle to cbDisplayChannel2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of cbDisplayChannel2
value = get(hObject,'Value');
handles.hController.changeChannelsActive(2,value);

% --- Executes on button press in cbDisplayChannel3.
function cbDisplayChannel3_Callback(hObject, eventdata, handles)
% hObject    handle to cbDisplayChannel3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of cbDisplayChannel3
value = get(hObject,'Value');
handles.hController.changeChannelsActive(3,value);

% --- Executes on button press in cbDisplayChannel4.
function cbDisplayChannel4_Callback(hObject, eventdata, handles)
% hObject    handle to cbDisplayChannel4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of cbDisplayChannel4
value = get(hObject,'Value');
handles.hController.changeChannelsActive(4,value);

% --- Executes on button press in tbSingleChannel.
function tbSingleChannel_Callback(hObject, eventdata, handles)
% hObject    handle to tbSingleChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changeMultiChannel(false);


% --- Executes on button press in tbMultiChannel.
function tbMultiChannel_Callback(hObject, eventdata, handles)
% hObject    handle to tbMultiChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tbMultiChannel
handles.hController.changeMultiChannel(true);
