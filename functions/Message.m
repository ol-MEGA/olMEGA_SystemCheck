classdef Message < handle
    
    % Class that handles info string with timed update of dots
    
    properties
        sItems = {'','.','..','...'};
        targetObj;
        sText;
        t;
        sLast;
    end
    
    methods
        
        function [obj] = Message(target)
            
            obj.targetObj = target; 
            
            obj.sText = '';
            obj.sLast = obj.sItems{end};
            obj.t = timer();
            obj.t.StartDelay = 0;
            obj.t.ExecutionMode = 'fixedRate';
            obj.t.Period = 0.2;
            obj.t.TimerFcn = @obj.startCallback;
            obj.t.StopFcn = @obj.stopCallback;
            
        end
        
        function [] = setText(obj, sText)
            obj.sText = sText;
        end
        
        function [] = stop(obj, ~, ~)
            
            if strcmp(obj.t.Running, 'on')
                stop(obj.t);
            end
            
        end
        
        function [] = start(obj, ~, ~)
            
            if strcmp(obj.t.Running, 'off')
                start(obj.t);
            end
            
        end
        
        function [] = kill(obj, ~, ~)
            
            obj.stopTimer();
            delete(obj.t);
         
        end
        
        function [] = stopCallback(obj, ~, ~)
            obj.sLast = '';
        end
        
        function [] = startCallback(obj, ~, ~)
            
            switch obj.sLast
                
                case obj.sItems{1}
                    obj.sLast = obj.sItems{2};
                case obj.sItems{2}
                    obj.sLast = obj.sItems{3};
                case obj.sItems{3}
                    obj.sLast = obj.sItems{4};
                case obj.sItems{4}
                    obj.sLast = obj.sItems{1};
                    
            end
           
            obj.targetObj.Text = [obj.sText, obj.sLast];
            drawnow;
            
        end
        
    end
    
end