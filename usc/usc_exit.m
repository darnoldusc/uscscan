
function usc_exit(varargin)
%% function usc_exit(varargin)
%usc_exit Exits USCScan (gracefully)
%% SYNTAX
%   usc_exit() --> exits USCScan unconditionally
%   usc_exit('prompt') --> exits USCScan only after user confirms intent


version = usc_isRunning();
if ~version 
    error('USCScan is not running or not running correctly -- cannot exit from USCScan');
end

%Prompt user before exit, if needed
if ~isempty(varargin)
    if ~ischar(varargin{1}) || ~strcmpi(varargin{1},'prompt')
        error('Invalid argument provided to. Only valid argument is ''prompt''');
    end

    ans =questdlg('Are you sure you want to exit USCScan?','Exit USCScan Confirmation','Yes','No','No');

    if strcmpi(ans,'No')
        return; %Abort this exit function
    end
end
        
%Handle SI4 case
if version == 4
    evalin('base','delete(hUSC)');
    evalin('base','clear hUSC hUSCCtl');
    return;
end

%Handle SI3 case

global state gh

%VI091510A
if ~isstruct(gh) %No GUIs have been created yet
    return;
end

%%%VI051710A%%%
if isfield(state,'hUSC') && isvalid(state.hUSC) 
    notify(state.hUSC, 'appClose');
    delete(state.hUSC);
end
%%%%%%%%%%%%%%%


%Clear USCScan's GUI figures...
guiHandles = fieldnames(gh);
for i=1:length(guiHandles)  
    if ishandle(gh.(guiHandles{i}).figure1) %VI091510A
        delete(gh.(guiHandles{i}).figure1);
    end
end

%%%VI091510A: All done if no INI file has been read yet 
if ~isstruct(state) || ~isfield(state,'software') || ~isfield(state.software,'version')
    return;       
end

%Clear any other figures (VI110708A)
for i=1:length(state.internal.figHandles)
    if ishandle(state.internal.figHandles(i))
        close(state.internal.figHandles(i));
    end
end

%Clear the various acquisition/display figures
for i=1:state.init.maximumNumberOfInputChannels
    if length(state.internal.GraphFigure) >= i && ishandle(state.internal.GraphFigure(i)) %VI112309A
        delete(state.internal.GraphFigure(i));
    end
    
    if length(state.internal.MaxFigure) >= i && ishandle(state.internal.MaxFigure(i)) %VI112309A
        delete(state.internal.MaxFigure(i));
    end   
end
if ~isempty(state.internal.MergeFigure) && ishandle(state.internal.MergeFigure)
    delete(state.internal.MergeFigure);
end

%%%VI032810A%%%%%%
if ~isempty(state.motor.hMotor) && isvalid(state.motor.hMotor) %VI091510A
    delete(state.motor.hMotor);
end
%%%%%%%%%%%%%%%%%%   

%%%VI051111A%%%%%%%
if ~isempty(state.motor.hMotorZ) && isvalid(state.motor.hMotorZ) 
    delete(state.motor.hMotorZ);
end
%%%%%%%%%%%%%%%%%%%%

%%%VI090109A: Removed %%%%%%%%%%%%%%%%
%Clear objects owned by USCScan
%
% stopAllChannels(state.acq.dm);
% delete(state.acq.dm);
% daqobjs = {'state.init.ai' 'state.init.aiPMTOffsets' 'state.init.ao1' 'state.init.ao2' ...
%             'state.init.dio' 'state.init.aiF' 'state.init.ao1F' 'state.init.ao2F' 'state.init.aoPark' ...
%             'state.init.aiZoom'};
%
% for i=1:length(daqobjs)
%     if ~isempty(eval(daqobjs{i}))
%         obj = eval(daqobjs{i});
%         if isrunning(obj)
%             stop(obj);
%         end
%         delete(obj);
%     end
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%VI090109A: Clear DAQmx Interface Objects%%%%%%%%
daqObjs = {state.init.hAI state.init.hAIZoom ...
    state.init.hAO state.init.hAOPark state.init.hTrigger state.init.hStartTrigCtr state.init.hNextTrigCtr ...
    state.shutter.hDO state.init.eom.hAO state.init.hFrameClkCtr state.init.hLineClkCtr state.init.hPixelClkCtr};

%%%VI122309A%%
for i=1:state.init.eom.numberOfBeams
    AOParkTask = ['hAOPark' num2str(i)]; %VI031110A
    if isfield(state.init.eom,AOParkTask) %VI031110A
        daqObjs{end+1} = state.init.eom.(AOParkTask);
    end
    
    %%%VI062410A
    if ~isempty(state.init.hAIPhotodiode) && ~isempty(state.init.hAIPhotodiode{i}) %VI091510A
        daqObjs{end+1} = state.init.hAIPhotodiode{i};
    end
%     %TO002110A - This was causing a C-level crash during Matlab shutdown. Technically, the issue is Matlab wasn't properly handling the cell reference exception.
%     %%%VI062410A
%     if length(state.init.hAIPhotodiode) >= i
%         if ~isempty(state.init.hAIPhotodiode{i})
%             daqObjs{end+1} = state.init.hAIPhotodiode{i};
%         end
%     end
end
%%%%%%%%%%%%%%

for i=1:length(daqObjs)
    if ~isempty(daqObjs{i}) && isvalid(daqObjs{i})
        delete(daqObjs{i});
    end
end   

%%%VI092109A
if ~isempty(state.init.hDAQmx)
    clear state.init.hDAQmx; 
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       

%Clear te global variables
clear global gh state;





