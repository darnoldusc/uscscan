classdef testClass < handle
    %TESTCLASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hDUT; %Handle to device under test
        
        verbose = true;
        logFileName = '';
    end
    
    properties (SetAccess=protected)
        logFileID;
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = testClass(hDUT)
            obj.hDUT = hDUT;           
        end
        
        function delete(obj)
            obj.closeLogFile();
        end
    end      
    
    
    
    
    %% UNIT TESTS
    
    methods 
        function testDisplay(obj)            
            disp('***Testing DUT Display****');
            disp(obj);
            disp('**************************');
        end
          
        function ok = testCorePropSetGet(obj)  
            
            obj.initLogFile(); %Prepare error log file    
            
            ok = true;
           
            simpleSetGetPropMap = initSimpleSetGetPropMap();            
            
            function simpleSetGetPropMap = initSimpleSetGetPropMap()
                simpleSetGetPropMap = containers.Map();
                %simpleSetGetPropMap('driftCompensation') = {0 1 0}; %This fails on E-816 -- even in their software!
                simpleSetGetPropMap('servoControlMode') = {0 1 0};   
                simpleSetGetPropMap('samplesPerAverage') = {1 2 4 1};                
            end
            
            disp('***Testing Simple Set/Get Access*****');
            propNames = simpleSetGetPropMap.keys();
            for i=1:length(simpleSetGetPropMap.keys)
                propVals = simpleSetGetPropMap(propNames{i});
                
                for j=1:length(propVals)
                    try
                        if ~isempty(findprop(obj.hDUT,propNames{i}))
                            obj.hDUT.(propNames{i}) = propVals{j};
                            assert(obj.hDUT.(propNames{i}) == propVals{j});
                        end
                    catch ME
                        obj.reportError('Error setting ''%s'' = %s: %s\n',propNames{i}, mat2str(propVals{j}),ME.message);
                        ok = false;
                    end
                end                
            end                        
            
        end  
        
        function ok = testSetGetVoltage(obj)
           
            obj.initLogFile(); %Prepare error log file
            
            
            ok = true;

            disp('***Testing Set/Get of voltage commands****');
            obj.hDUT.servoControlMode = false;

            if ~isempty(findprop(obj.hDUT,'setVoltageMin'))
                voltageList = linspace(obj.setVoltageMin,obj.setVoltageMax,10);                
            else
                ok = false;
                obj.reportError('Unable to test voltage command -- cannot determine valid command voltage range for DUT.');                
            end
            
            for i=1:length(voltageList)
                try
                    obj.hDUT.voltageCommand = voltageList{i};
                    pause(0.5);
                    voltageActual = obj.hDUT.voltageActual ;
                    assert( abs( voltageActual - voltageList{i})/abs(voltageList{i}) < .01, 'Actual voltage value (%d) differed by more than 1\% from set voltage (%d)',voltageActual,voltageList{i});
                catch ME
                    obj.reportError('Error occurred when setting voltage level %d V:\n\t%s\n',voltageList{i},ME.message);                    
                    obj.reportError('ABORT TEST!\n');
                    ok = false;
                    break;
                end
            end
            
            
        end
        
        function moveCompleteTest(obj)
            
            
        end

    end
    
    
        
    %% HELPER METHODS
    methods (Access=protected)

        function initLogFile(obj,testName)
            if ~isempty(obj.logFileName) && isempty(obj.logFileID)
                obj.logFileID = fopen(obj.logFileName,'a');   
                
                fprintf(obj.logFileID, '***%s -- %s\n',datestr(now), testName);
            end            
        end
        
        function closeLogFile(obj)
            if ~isempty(obj.logFileID)
                fclose(obj.logFileID);
                obj.logFileID = [];
            end
        end
            
        
        function reportError(obj,formatStr,varargin)           
            if obj.verbose
               fprintf(2,formatStr,varargin{:});                
            end       
            
            if ~isempty(obj.logFileID)
                fprintf(obj.logFileID,formatStr,varargin{:});
            end            
        end
        
        
        
        
    end
    
    
end

