function uscscan()
%USCSCAN Starts USCScan application and its GUI(s)

hUSC = uscscan.Model();
hUSCCtl = uscscan.Controller(hUSC); %#ok<NASGU>

assignin('base','hUSC',hUSC);
assignin('base','hUSCCtl',hUSC.hController{1});

hUSC.initialize();

end