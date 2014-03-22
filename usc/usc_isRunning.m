function version = usc_isRunning()
%usc_isRunning Determines which, if any, major version of USCScan appears to be currently running
%% SYNTAX
%   version = usc_isRunning()
%       version: 0 if USCScan is either not running or not running correctly; if USCScan is found running, the major version number (e.g. 3 or 4) is given

version = 0; %No valid version yet found


%SI4 case
if ~existState && ~existGh
    if evalin('base','exist(''hUSC'',''var'');')
        hUSC = evalin('base','hUSC;');
        if ~isempty(hSI)
            version = 5;
        end
    end
    return;
end

