
classdef olMEGA_SystemCheck < handle
    
    properties
        
        vScreenSize;
        nGUIWidth = 600;
        nGUIHeight = 400;
        nLeftWidth;
        nUpperHeight;
        nInterval_Vertical;
        nInterval_Horizontal = 30;
        nButtonHeight = 30;
        nButtonWidth = 76;
        nBottomSpace;
        nSpread_Lights_Horizontal;
        nSpread_Lights_Vertical = 20;
        nLampHeight = 15;
        nLampInterval_Vertical;
        nPanelTitleHeight = 18;
        nDropDownInterval;
        nDropDownWidth = 200;
        nDropDownHeight = 20;
        nTextHeight = 20;
        nToggleWidth = 20;
        
        nPanelHeight_SaveResult;
        nPanelHeight_Measurement;
        nPanelHeight_MobileDevice;
        
        prefix;
        stAudioInput;
        cAudioInput;
        stAudioOutput;
        cAudioOutput;
        nAudioInput;
        nAudioOutput;
        sAudioError = '';
        
        mColors;
        sTitleFig_Main = 'olMEGA_SystemCheck';
        
        hFig_Main;
        hPanel_Graph;
        hPanel_MobileDevice;
        hPanel_Measurement;
        hPanel_SaveResult;
        hPanel_Lamps;
        hPanel_Hardware;
        
        hLabel_CheckDevice;
        hButton_CheckDevice;
        hLabel_CloseApp
        hButton_CloseApp
        hLabel_Calibrate;
        hButton_Calibration;
        hLabel_Start;
        hButton_Start;
        hLabel_Constant;
        hEdit_Constant;
        hLabel_SaveToPhone;
        hButton_SaveToPhone;
        hLabel_SaveInfo;
        hButton_SaveInfo;
        
        hAxes;
        hLabel_Message;
        hInfoInitializing;
        hMessage;
        hHotspot;
        hInfoField;
        
        hLabel_Device;
        hLamp_Device;
        hLabel_Calibration;
        hLamp_Calibration;
        hLabel_Measurement;
        hLamp_Measurement;
        hLabel_Saved;
        hLamp_Saved;
        
        hLabel_Input;
        hDropDown_Input;
        hLabel_Output;
        hDropDown_Output;
        hButtonGroup_Input;
        hButtonGroup_Output;
        hToggle_Input_L;
        hToggle_Input_R;
        hToggle_Output_L;
        hToggle_Output_R;
        
        nSamplerate = 16000;
        nBlockSize = 512;
        nDurationCalibration_s = 5;
        nCalibConstant_Mic_FS_SPL = 120;
        nSystemCalibConstant;
        nLevel_Calib_dBSPL;
        nLevel_Calib_dBFS;
        nCalibConstant_System;
        vCalibConstant_System;
        nDurationMeasurement_s = 5;
        vTransferFunction;
        vOriginal_rec;
        vRefMic_rec;
        vRefMic_Noise;
        vRefMic_Silence;
        
        sFileName_Calib = 'calib.txt';
        
        sDeviceAddress = '';
        
        bMobileDevice = false;
        bAudioDevice = false;
        bCalib = false;
        bMeasurement = false;
        bEnableButtons = false;
        
        oPlayRec;
        nFs = 48000;
        nFs_Target = 16000;
        nBits = 16;
        nFormat = 'double';
        
        bLoop = true;
        
        
    end
    
    
    methods
        
        function obj = olMEGA_SystemCheck()     
            close all;
            addpath('functions');
            
            if ~exist([pwd, filesep, 'cache'], 'dir')
                mkdir([pwd, filesep, 'cache']);
            end
           
            if ismac
                obj.prefix = '/usr/local/bin/';
            else
                obj.prefix = '';
            end
            
            set(0,'Units','Pixels') ;
            obj.vScreenSize = get(0, 'ScreenSize');
            
            obj.nLeftWidth = obj.nGUIWidth - obj.nButtonWidth - ...
                2 * obj.nInterval_Horizontal;
            
            obj.nLeftWidth = 464;
            
            
            obj.nInterval_Vertical = ((obj.nGUIHeight - ...
                3*obj.nPanelTitleHeight - 7*obj.nButtonHeight)/10);
            
            obj.nPanelHeight_MobileDevice = obj.nPanelTitleHeight + 2*obj.nButtonHeight + 3*obj.nInterval_Vertical;
            obj.nPanelHeight_Measurement = obj.nPanelTitleHeight + 3*obj.nButtonHeight + 4*obj.nInterval_Vertical + 1;
            obj.nPanelHeight_SaveResult = obj.nPanelTitleHeight + 2*obj.nButtonHeight + 3*obj.nInterval_Vertical;
            
            obj.nUpperHeight = obj.nGUIHeight - obj.nPanelHeight_SaveResult;
            
            obj.nUpperHeight = 280;
            
            obj.nLampInterval_Vertical = (obj.nGUIHeight - obj.nPanelTitleHeight - ...
                obj.nUpperHeight - 4*obj.nLampHeight)/5;
            obj.nDropDownInterval = (obj.nGUIHeight - obj.nPanelTitleHeight - ...
                obj.nUpperHeight - 2*obj.nDropDownHeight - 2*obj.nTextHeight)/3;
            
            % Interval between progress lights;
            obj.nSpread_Lights_Horizontal = (obj.nLeftWidth - 3 * obj.nButtonHeight) / 4;
            
            obj.mColors = getColors();
            
            obj.oPlayRec = audioPlayerRecorder('SampleRate', obj.nFs);
            
            obj.checkPrerequisites();
            
            obj.buildGUI();
            
%             obj.hMessage = Message(obj.hInfoInitializing);
            
            obj.checkDevice();
            
            
            obj.checkAudioHardware();
            
            obj.loadSetting();
            
%             obj.hMessage.stop();
        end
        
        function [] = loadSetting(obj)
            if exist('recording_Calibration.wav', 'file')
                sResult = questdlg('Load existing Calibration?', 'Calibration', 'Yes','No', 'Yes');
                if (strcmp(sResult, 'Yes'))
                    [vCalibration, obj.nSamplerate] = audioread('recording_Calibration.wav');
                    obj.calculateCalibration(vCalibration);
                end
            end
            if exist('settings.mat', 'file')
                load('settings.mat', 'nAudioOutputValue', 'nAudioInputValue', 'hToggle_Output_L_Value', 'hToggle_Input_L_Value');
                obj.hToggle_Output_L.Value = hToggle_Output_L_Value;
                obj.hToggle_Input_L.Value = hToggle_Input_L_Value;
                val.Value = nAudioOutputValue;
                if find(ismember(obj.hDropDown_Output.Items, val.Value))
                    obj.hDropDown_Output.Value = val.Value;
                    obj.callback_DropDownAudioOutput(-1, val);
                end
                val.Value = nAudioInputValue;
                if find(ismember(obj.hDropDown_Input.Items, val.Value))
                    obj.hDropDown_Input.Value = val.Value;
                    obj.callback_DropDownAudioInput(-1, val);
                end
            end
        end
        
        function [] = buildGUI(obj)
            
            % Main Figure
            
            obj.hFig_Main = uifigure();
            obj.hFig_Main.Position = [ ...
                (obj.vScreenSize(3)-obj.nGUIWidth)/2, ...
                (obj.vScreenSize(4)-obj.nGUIHeight)/2, ...
                obj.nGUIWidth, ...
                obj.nGUIHeight];
            obj.hFig_Main.Name = obj.sTitleFig_Main;
            obj.hFig_Main.Resize = 'Off';
            obj.hFig_Main.ToolBar = 'None';
            obj.hFig_Main.MenuBar = 'None';
            obj.hFig_Main.Units = 'Pixels';
            
            
            % Panel: Graph
            
            
            obj.hPanel_Graph = uipanel(obj.hFig_Main);
            obj.hPanel_Graph.Position = [ ...
                1, ...
                obj.nGUIHeight - obj.nUpperHeight, ...
                obj.nLeftWidth, ...  %+1
                obj.nUpperHeight]; %+1
            obj.hPanel_Graph.Title = 'Graph';
            
            obj.hAxes = uiaxes(obj.hPanel_Graph);
            obj.hAxes.Units = 'Pixels';
            obj.hAxes.Position = [0,0,obj.hPanel_Graph.Position(3), obj.hPanel_Graph.Position(4)-20];
            obj.hAxes.Visible = 'Off';
            disableDefaultInteractivity(obj.hAxes);
            obj.hAxes.Box = 'On';
            obj.hAxes.Layer = 'Top';
            obj.hAxes.Color = 'none';
            
%             obj.hInfoInitializing = uilabel(obj.hPanel_Graph);
%             obj.hInfoInitializing.Position = [(obj.nLeftWidth - 80)/2, (obj.nUpperHeight - 20)/2, 80, 20];
%             obj.hInfoInitializing.Text = '';
%             obj.hInfoInitializing.FontSize = 14;
%             obj.hInfoInitializing.HorizontalAlignment = 'left';
%             obj.hInfoInitializing.VerticalAlignment = 'center';
            
            obj.hInfoField = text('Parent', obj.hAxes, 'Position', [100,100], 'String', 'test');
%             obj.hInfoField.Position = [240, 20, 200, 120];
%             obj.hInfoField.Text = '';
%             obj.hInfoField.FontSize = 14;
%             obj.hInfoField.HorizontalAlignment = 'right';
%             obj.hInfoField.VerticalAlignment = 'bottom';

%                 obj.hInfoField = wordcloud(obj.hPanel_Graph, 'asdfdo sr p kfgh', 1);

%             obj.hInfoField = text(obj.hAxes);
%             obj.hInfoField.BackgroundColor = [1,0,0];
%             obj.hInfoField.Position = [240, 20];
%             obj.hInfoField.String = 'asdsdfgfhhj';
%             obj.hInfoField.FontSize = 14;
%             obj.hInfoField.HorizontalAlignment = 'right';
%             obj.hInfoField.BackgroundColor = [1,1,1];
%             obj.hInfoField.VerticalAlignment = 'bottom';
            
            obj.hHotspot = patch(obj.hAxes, [0,0,1,1],[0,1,1,0], [1,1,1], 'FaceAlpha', 0.1, 'EdgeColor', 'none');
            obj.hHotspot.ButtonDownFcn = @obj.doNothing;
            
            
            % Panel: Mobile Device
            
            
            obj.hPanel_MobileDevice = uipanel(obj.hFig_Main);
            obj.hPanel_MobileDevice.Position = [ ...
                obj.nLeftWidth, ...
                obj.nPanelHeight_SaveResult + obj.nPanelHeight_Measurement, ...
                obj.nGUIWidth - obj.nLeftWidth + 1, ...
                obj.nPanelHeight_MobileDevice];
            obj.hPanel_MobileDevice.Title = 'Application';
            
            % Button: CheckDevice
            obj.hButton_CheckDevice = uibutton(obj.hPanel_MobileDevice);
            obj.hButton_CheckDevice.Position = [ ...
                obj.nInterval_Horizontal, ...
                2 * obj.nInterval_Vertical + 1 * obj.nButtonHeight, ...
                obj.nButtonWidth, ...
                obj.nButtonHeight];
            obj.hButton_CheckDevice.Text = 'Reset';
            obj.hButton_CheckDevice.ButtonPushedFcn = @obj.callbackResetApplication;
            
            % Button: Close App
            obj.hButton_CloseApp = uibutton(obj.hPanel_MobileDevice);
            obj.hButton_CloseApp.Position = [ ...
                obj.nInterval_Horizontal, ...
                1 * obj.nInterval_Vertical + 0 * obj.nButtonHeight, ...
                obj.nButtonWidth, ...
                obj.nButtonHeight];
            obj.hButton_CloseApp.Text = 'Close';
            obj.hButton_CloseApp.ButtonPushedFcn = @obj.callbackCloseApp;
            
            
            % Panel: Measurement
            
            
            obj.hPanel_Measurement = uipanel(obj.hFig_Main);
            obj.hPanel_Measurement.Position = [ ...
                obj.nLeftWidth, ...
                obj.nPanelHeight_SaveResult, ...
                obj.nGUIWidth - obj.nLeftWidth + 1, ...
                obj.nPanelHeight_Measurement + 1];
            obj.hPanel_Measurement.Title = 'Measurement';
            
            % Button: Calibrate
            obj.hButton_Calibration = uibutton(obj.hPanel_Measurement);
            obj.hButton_Calibration.Position = [ ...
                obj.nInterval_Horizontal, ...
                3 * obj.nInterval_Vertical + 2 * obj.nButtonHeight, ...
                obj.nButtonWidth, ...
                obj.nButtonHeight];
            obj.hButton_Calibration.Text = 'Calibration';
            obj.hButton_Calibration.ButtonPushedFcn = @obj.callbackPerformCalibration;
            
            % Button: Start
            obj.hButton_Start = uibutton(obj.hPanel_Measurement);
            obj.hButton_Start.Position = [ ...
                obj.nInterval_Horizontal, ...
                2 * obj.nInterval_Vertical + 1 * obj.nButtonHeight, ...
                obj.nButtonWidth, ...
                obj.nButtonHeight];
            obj.hButton_Start.Text = 'Start';
            obj.hButton_Start.ButtonPushedFcn = @obj.callbackPerformTFMeasurement;
            
            % Edit: Constant
            obj.hEdit_Constant = uieditfield(obj.hPanel_Measurement);
            obj.hEdit_Constant.Position = [ ...
                obj.nInterval_Horizontal, ...
                1 * obj.nInterval_Vertical + 0 * obj.nButtonHeight, ...
                obj.nButtonWidth, ...
                obj.nButtonHeight];
            obj.hEdit_Constant.Editable = 'off';
            obj.hEdit_Constant.HorizontalAlignment = 'Center';
            obj.hEdit_Constant.Value = '-';
            
            
            % Panel: Save Result
            
            
            obj.hPanel_SaveResult = uipanel(obj.hFig_Main);
            obj.hPanel_SaveResult.Position = [ ...
                obj.nLeftWidth, ...
                1, ...
                obj.nGUIWidth - obj.nLeftWidth + 1, ...
                obj.nPanelHeight_SaveResult];
            obj.hPanel_SaveResult.Title = 'Save Result';
            
            % Button: SaveToPhone
            obj.hButton_SaveToPhone = uibutton(obj.hPanel_SaveResult);
            obj.hButton_SaveToPhone.Position = [ ...
                obj.nInterval_Horizontal, ...
                2 * obj.nInterval_Vertical + 1 * obj.nButtonHeight, ...
                obj.nButtonWidth, ...
                obj.nButtonHeight];
            obj.hButton_SaveToPhone.Text = 'Phone';
            obj.hButton_SaveToPhone.ButtonPushedFcn = @obj.callbackSaveToPhone;
            
            % Button: SaveInfo
            obj.hButton_SaveInfo = uibutton(obj.hPanel_SaveResult);
            obj.hButton_SaveInfo.Position = [ ...
                obj.nInterval_Horizontal, ...
                obj.nInterval_Vertical, ...
                obj.nButtonWidth, ...
                obj.nButtonHeight];
            obj.hButton_SaveInfo.Text = 'Disk';
            obj.hButton_SaveInfo.ButtonPushedFcn = @obj.callbackSaveToDisk;
            
            
            % Panel: Lamps
            
            
            obj.hPanel_Lamps = uipanel(obj.hFig_Main);
            obj.hPanel_Lamps.Position = [ ...
                1, ...
                1, ...
                obj.nLeftWidth/3, ...
                obj.nGUIHeight - obj.nUpperHeight];
            obj.hPanel_Lamps.Title = 'Progress';
            
            % Label: Device
            obj.hLabel_Device = uilabel(obj.hPanel_Lamps);
            obj.hLabel_Device.Position  = [ ...
                obj.nInterval_Horizontal + obj.nLampHeight + 5, ...
                4 * obj.nLampInterval_Vertical + 3 * obj.nLampHeight, ...
                80, ...
                obj.nLampHeight];
            obj.hLabel_Device.Text = 'Mobile Device';
            
            % Lamp: Device
            obj.hLamp_Device = uilamp(obj.hPanel_Lamps);
            obj.hLamp_Device.Position = [ ...
                obj.nInterval_Horizontal, ...
                4 * obj.nLampInterval_Vertical + 3 * obj.nLampHeight, ...
                obj.nLampHeight, ...
                obj.nLampHeight];
            obj.hLamp_Device.Color = obj.mColors(2, :);
            
            % Label: Calibration
            obj.hLabel_Calibration = uilabel(obj.hPanel_Lamps);
            obj.hLabel_Calibration.Position  = [ ...
                obj.nInterval_Horizontal + obj.nLampHeight + 5, ...
                3 * obj.nLampInterval_Vertical + 2 * obj.nLampHeight, ...
                80, ...
                obj.nLampHeight];
            obj.hLabel_Calibration.Text = 'Calibration';
            
            % Lamp: Calibration
            obj.hLamp_Calibration = uilamp(obj.hPanel_Lamps);
            obj.hLamp_Calibration.Position = [ ...
                obj.nInterval_Horizontal, ...
                3 * obj.nLampInterval_Vertical + 2 * obj.nLampHeight, ...
                obj.nLampHeight, ...
                obj.nLampHeight];
            obj.hLamp_Calibration.Color = obj.mColors(2, :);
            
            % Label: Measurement
            obj.hLabel_Measurement = uilabel(obj.hPanel_Lamps);
            obj.hLabel_Measurement.Position  = [ ...
                obj.nInterval_Horizontal + obj.nLampHeight + 5, ...
                2 * obj.nLampInterval_Vertical + obj.nLampHeight, ...
                80, ...
                obj.nLampHeight];
            obj.hLabel_Measurement.Text = 'Measurement';
            
            % Lamp: Measurement
            obj.hLamp_Measurement = uilamp(obj.hPanel_Lamps);
            obj.hLamp_Measurement.Position = [ ...
                obj.nInterval_Horizontal, ...
                2 * obj.nLampInterval_Vertical + obj.nLampHeight, ...
                obj.nLampHeight, ...
                obj.nLampHeight];
            obj.hLamp_Measurement.Color = obj.mColors(2, :);
            
            % Label: Saved
            obj.hLabel_Saved = uilabel(obj.hPanel_Lamps);
            obj.hLabel_Saved.Position = [ ...
                obj.nInterval_Horizontal + obj.nLampHeight + 5, ...
                obj.nLampInterval_Vertical - 1, ...
                80, ...
                obj.nLampHeight];
            obj.hLabel_Saved.Text = 'Saved';
            
            % Lamp: Saved
            obj.hLamp_Saved = uilamp(obj.hPanel_Lamps);
            obj.hLamp_Saved.Position = [ ...
                obj.nInterval_Horizontal, ...
                obj.nLampInterval_Vertical, ...
                obj.nLampHeight, ...
                obj.nLampHeight];
            obj.hLamp_Saved.Color = obj.mColors(2, :);
            
            
            % Panel: Hardware
            
            
            obj.hPanel_Hardware = uipanel(obj.hFig_Main);
            obj.hPanel_Hardware.Position = [ ...
                obj.nLeftWidth/3, ...
                1, ...
                obj.nLeftWidth/3*2 + 1, ...
                obj.nGUIHeight - obj.nUpperHeight];
            obj.hPanel_Hardware.Title = 'Hardware';
            
            % Label: Output
            obj.hLabel_Output = uilabel(obj.hPanel_Hardware);
            obj.hLabel_Output.Position = [ ...
                obj.nInterval_Horizontal, ...
                2 * obj.nDropDownInterval + 2 * obj.nDropDownHeight + obj.nTextHeight, ...
                obj.nDropDownWidth, ...
                obj.nDropDownHeight];
            obj.hLabel_Output.Text = 'Audio Output';
            
            % DropDown: Output
            obj.hDropDown_Output = uidropdown(obj.hPanel_Hardware);
            obj.hDropDown_Output.Position = [ ...
                obj.nInterval_Horizontal, ...
                2 * obj.nDropDownInterval + obj.nDropDownHeight + obj.nTextHeight, ...
                obj.nDropDownWidth, ...
                obj.nDropDownHeight];
            obj.hDropDown_Output.ValueChangedFcn = @obj.callback_DropDownAudioOutput;
            obj.hDropDown_Output.Items = {''};
            obj.hDropDown_Output.Enable = 'Off';
            
            % ToggleGroup: Output
            obj.hButtonGroup_Output = uibuttongroup(obj.hPanel_Hardware);
            obj.hButtonGroup_Output.Position = [ ...
                obj.nInterval_Horizontal + obj.nDropDownWidth + 10, ...
                2 * obj.nDropDownInterval + obj.nDropDownHeight + obj.nTextHeight, ...
                2 * obj.nToggleWidth + 4, ...
                obj.nDropDownHeight];
            obj.hButtonGroup_Output.SelectionChangedFcn = @obj.callback_ToggleButtonValueChanged;
            obj.hButtonGroup_Output.BorderType = 'none';
            
            % ToggleButton: Output L
            obj.hToggle_Output_L = uitogglebutton(obj.hButtonGroup_Output);
            obj.hToggle_Output_L.Position = [ ...
                1, ...
                1, ...
                obj.nToggleWidth, ...
                obj.nDropDownHeight];
            obj.hToggle_Output_L.Text = 'L';
            
            % ToggleButton: Output R
            obj.hToggle_Output_R = uitogglebutton(obj.hButtonGroup_Output);
            obj.hToggle_Output_R.Position = [ ...
                obj.nToggleWidth + 2, ...
                1, ...
                obj.nToggleWidth, ...
                obj.nDropDownHeight];
            obj.hToggle_Output_R.Text = 'R';
            
            % Label: Input
            obj.hLabel_Input = uilabel(obj.hPanel_Hardware);
            obj.hLabel_Input.Position = [ ...
                obj.nInterval_Horizontal, ...
                obj.nDropDownInterval + obj.nDropDownHeight, ...
                obj.nDropDownWidth, ...
                obj.nDropDownHeight];
            obj.hLabel_Input.Text = 'Audio Input';
            
            % DropDown: Input
            obj.hDropDown_Input = uidropdown(obj.hPanel_Hardware);
            obj.hDropDown_Input.Position = [ ...
                obj.nInterval_Horizontal, ...
                obj.nDropDownInterval, ...
                obj.nDropDownWidth, ...
                obj.nDropDownHeight];
            obj.hDropDown_Input.ValueChangedFcn = @obj.callback_DropDownAudioInput;
            obj.hDropDown_Input.Items = {''};
            obj.hDropDown_Input.Enable = 'Off';
            
            % ToggleGroup: Input
            obj.hButtonGroup_Input = uibuttongroup(obj.hPanel_Hardware);
            obj.hButtonGroup_Input.Position = [ ...
                obj.nInterval_Horizontal + obj.nDropDownWidth + 10, ...
                obj.nDropDownInterval, ...
                2 * obj.nToggleWidth + 4, ...
                obj.nDropDownHeight];
            obj.hButtonGroup_Input.SelectionChangedFcn = @obj.callback_ToggleButtonValueChanged;
            obj.hButtonGroup_Input.BorderType = 'none';
            
            % ToggleButton: Input L
            obj.hToggle_Input_L = uitogglebutton(obj.hButtonGroup_Input);
            obj.hToggle_Input_L.Position = [ ...
                1, ...
                1, ...
                obj.nToggleWidth, ...
                obj.nDropDownHeight];
            obj.hToggle_Input_L.Text = 'L';
            
            % ToggleButton: Input R
            obj.hToggle_Input_R = uitogglebutton(obj.hButtonGroup_Input);
            obj.hToggle_Input_R.Position = [ ...
                obj.nToggleWidth + 2, ...
                1, ...
                obj.nToggleWidth, ...
                obj.nDropDownHeight];
            obj.hToggle_Input_R.Text = 'R';
            
            drawnow;
            
        end
        
        function [] = checkPrerequisites(obj)
            
            warning('backtrace', 'off');
            
            [~, tmp] = system('adb devices');
            if ~contains(tmp, 'List')
                warning('ADB is not properly installed on your system.');
            end
            
            if verLessThan('matlab', '9.5')
                warning('Matlab version upgrade is necesary.');
            end
            
            warning('backtrace', 'on');
            
        end
        
        function [] = checkAudioHardware(obj)
            
            % Get an overview of all connected audio hardware and fill in
            % the dropdown menus
            
            info = audiodevinfo;
            stInput = info.input;
            stOutput = info.output;
      
            obj.stAudioInput = [];
            obj.stAudioOutput = [];
            
            for tmp = stInput'
               if (isempty(obj.stAudioInput))
                    obj.stAudioInput = tmp;
                    obj.cAudioInput = {tmp.Name};
                else
                    obj.stAudioInput(end+1) = tmp;
                    obj.cAudioInput{end+1} = tmp.Name;
               end
            end
            
            for tmp = stOutput'
                if (isempty(obj.stAudioOutput))
                    obj.stAudioOutput = tmp;
                    obj.cAudioOutput = {tmp.Name};
                else
                    obj.stAudioOutput(end+1) = tmp;
                    obj.cAudioOutput{end+1} = tmp.Name;
                end
            end
            
            obj.bAudioDevice = false;
            if (isempty(obj.cAudioInput) && isempty(obj.cAudioOutput))
                obj.sAudioError = 'No audio device found.';
                errordlg(obj.sAudioError);
            elseif (isempty(obj.cAudioInput) && ~isempty(obj.cAudioOutput))
                obj.sAudioError = 'No audio input device found.';
                errordlg(obj.sAudioError);
                obj.hDropDown_Output.Items = obj.cAudioOutput;
                obj.hDropDown_Output.Enable = 'On';
            elseif (isempty(obj.cAudioOutput) && ~isempty(obj.cAudioInput))
                obj.sAudioError = 'No audio input device found.';
                errordlg(obj.sAudioError);
                obj.hDropDown_Input.Items = obj.cAudioInput;
                obj.hDropDown_Input.Enable = 'On';
            else
                obj.hDropDown_Input.Items = obj.cAudioInput;
                obj.hDropDown_Output.Items = obj.cAudioOutput;
                obj.hDropDown_Input.Enable = 'On';
                obj.hDropDown_Output.Enable = 'On';
                obj.bAudioDevice = true;
            end
            
            obj.bEnableButtons = true;
            obj.hInfoInitializing.Text = '';
            drawnow;
            
%             obj.showImage('');
            
        end
        
        function [] = callback_DropDownAudioOutput(obj, tmp , val)
            
            for iDevice = 1 : length(obj.stAudioOutput)
                if strcmp(obj.stAudioOutput(iDevice).Name, val.Value)
                    obj.nAudioOutput = obj.stAudioOutput(iDevice).ID;
                    if tmp ~= -1
                        obj.callback_ToggleButtonValueChanged();
                    end
                    break;
                end
            end
        end
        
        function [] = callback_DropDownAudioInput(obj, tmp , val)
            
            for iDevice = 1 : length(obj.stAudioInput)
                if strcmp(obj.stAudioInput(iDevice).Name, val.Value)
                    obj.nAudioInput = obj.stAudioInput(iDevice).ID;
                    if tmp ~= -1
                        obj.callback_ToggleButtonValueChanged();
                    end
                    break;
                end
            end
        end
        
        function [] = callback_ToggleButtonValueChanged(obj, ~, ~)
            nAudioOutputValue = obj.hDropDown_Output.Value;
            nAudioInputValue = obj.hDropDown_Input.Value;
            hToggle_Output_L_Value = obj.hToggle_Output_L.Value;
            hToggle_Input_L_Value = obj.hToggle_Input_L.Value;
            save('settings.mat', 'nAudioOutputValue', 'nAudioInputValue', 'hToggle_Output_L_Value', 'hToggle_Input_L_Value');
        end
        
        function [] = showImage(obj, sImage)
            
            switch sImage
                case 'connectDevice'
                    obj.hLamp_Measurement.Color = obj.mColors(2, :);
                    obj.hLamp_Device.Color = obj.mColors(2, :);
                    mImage = imread(['images', filesep, 'img_connectDevice.png']);
                case 'setUpCalibrator'
                    obj.hLamp_Calibration.Color = obj.mColors(3, :);
                    % Reset color of saved lamp
                    obj.hLamp_Saved.Color = obj.mColors(2, :);
                    % Reset color of measurement lamp
                    obj.hLamp_Measurement.Color = obj.mColors(2, :);
                    mImage = imread(['images', filesep, 'img_setupCalibrator.png']);
                case 'setUpMeasurement'
                    obj.hEdit_Constant.Value = '';
                    obj.hLamp_Measurement.Color = obj.mColors(3, :);
                    % Reset color of saved lamp
                    obj.hLamp_Saved.Color = obj.mColors(2, :);
                    mImage = imread(['images', filesep, 'img_setupMeasurement.png']);
                case ''
%                     mImage = [];
                    mImage = imread(['images', filesep, 'img_standard.png']);
            end
            
            obj.hAxes.Visible = 'On';
            obj.hAxes.NextPlot = 'replace';
            
            image(obj.hAxes, mImage);
            obj.hInfoField = text('Parent', obj.hAxes, ...
                'Position', [440, 240], ...
                'String', '', ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 14);
            
            obj.hAxes.XLim = [1, 464];
            obj.hAxes.YLim = [1, 260];
            obj.hAxes.XTickLabel = {};
            obj.hAxes.XTick = [];
            obj.hAxes.YTickLabel = {};
            obj.hAxes.YTick = [];
            
            obj.hAxes.Box = 'On';
            obj.hAxes.Layer = 'Top';
            
            obj.hHotspot = patch(obj.hAxes, [1, 1, 464, 464],[1, 280, 280, 1], ...
                [1,1,1], 'FaceAlpha', 0.01, 'EdgeColor', 'none');
            
            if obj.hToggle_Input_L.Value
                sInput = 'left';
            else
                sInput = 'right'; 
            end
            
            if obj.hToggle_Output_L.Value
                sOutput = 'left';
            else
                sOutput = 'right'; 
            end
            
            switch sImage
                case 'connectDevice'
                    obj.hInfoField.String = sprintf(['Please connect the\n', ...
                        'Mobile Device to the\nComputer, then click here.']);
                    obj.hHotspot.ButtonDownFcn = @obj.checkDevice;
                case 'setUpCalibrator'
                    
                    obj.hInfoField.String = sprintf(['Position the microphone\n', ...
                        'inside the calibration chamber.\nEnsure that the microphone ', ...
                        'is\nconnected to the %s input.\nThen click here.'], sInput);
                    drawnow;
                    obj.hHotspot.ButtonDownFcn = @obj.performCalibration;
                case 'setUpMeasurement'
                    obj.hInfoField.String = sprintf(['Position the microphone\n', ...
                        'and MEMS next to each other\nin front of the speaker\nconnected to the %s output,\nthen click here + the symbol in the app.'], sOutput);
                    obj.hHotspot.ButtonDownFcn = @obj.phoneStartRecording;
                case ''
                    obj.hInfoField.String = '';
                    obj.hHotspot.ButtonDownFcn = @obj.doNothing;
            end
            
            drawnow;
            
        end
        
        function [] = callbackResetApplication(obj, ~, ~)
            
            if obj.bEnableButtons
                obj.resetApplication();
                obj.loadSetting();
            end
            
        end
        
        function [] = resetApplication(obj)
        
            obj.bCalib = false;
            obj.hLamp_Calibration.Color = obj.mColors(2, :);
            obj.bMeasurement = false;
            obj.hLamp_Measurement.Color = obj.mColors(2, :);
            obj.hLamp_Saved.Color = obj.mColors(2, :);
            obj.checkDevice();
            
        end
        
        function [bMobileDevice] = checkDevice(obj, ~, ~)
            
            obj.bEnableButtons = false;
            obj.bMobileDevice = false;
            bMobileDevice = false;
            
            set(obj.hButton_Calibration, 'Enable', 'off');
            set(obj.hButton_CheckDevice, 'Enable', 'off');
            set(obj.hButton_CloseApp, 'Enable', 'off');
            set(obj.hButton_SaveInfo, 'Enable', 'off');
            set(obj.hButton_SaveToPhone, 'Enable', 'off');
            set(obj.hButton_Start, 'Enable', 'off');
            
            obj.hInfoField.String = 'Please wait (or restart SystemCheck-App after several Minutes)...';
            drawnow;

            % make sure only one device is connected
            sTestDevices = [obj.prefix,'adb devices'];
            [~, sList] = system(sTestDevices);
            if (length(splitlines(sList)) > 4)
                errordlg('Too many mobile devices connected.', 'Error');
                obj.bMobileDevice = 0;
                obj.hLamp_Device.Color = obj.mColors(2, :);
                obj.showImage('connectDevice');
                return;
            elseif (length(splitlines(sList)) < 4)
                errordlg('No mobile device connected.', 'Error');
                obj.bMobileDevice = 0;
                obj.hLamp_Device.Color = obj.mColors(2, :);
                obj.showImage('connectDevice');
                return;
            elseif (contains(sList, 'List'))
                obj.bMobileDevice = true;
                obj.hLamp_Device.Color = obj.mColors(5, :);
                obj.bMobileDevice = true;
                bMobileDevice = true;
                obj.showImage('');
%                 obj.hMessage.setText('Initializing');
%                 obj.hInfoInitializing.Text = obj.hMessage.sText;
%                 obj.hMessage.start();
                drawnow;
            end
            
            obj.closeApp()
            % Check if activity is running. if not: start, if it does:
            % restart
            [~, temp] = system('adb shell dumpsys activity com.example.olMEGASystemCheck');
            if contains(temp, 'Bad activity command')
                [~, ~] = system('adb shell am start -n com.example.olMEGASystemCheck/.MainActivity');
            else
                [~, ~] = system('adb shell "am broadcast -a com.example.olMEGASystemCheck.intent.TEST --es sms_body ''Reset'' -n com.example.olMEGASystemCheck/.IntentReceiver --include-stopped-packages"');
            end
            obj.hInfoField.String = 'Please ''Activate'' olMEGASystemCheck-App';
            drawnow;
            
            % Wait and check if application is running as expected
            sData = '';
            while ~contains(sData, 'Waiting') && obj.bLoop
                [~, sData] = system('adb shell dumpsys activity com.example.olMEGASystemCheck');
                pause(0.1);
            end
            if contains(sData, 'DEVICE=')
                tempdata = split(sData,'DEVICE=');
                tempdata = split(tempdata{2}, ';');
                obj.sDeviceAddress = char(tempdata{1});
                obj.sFileName_Calib = [obj.sDeviceAddress '.txt'];
            end
            obj.bEnableButtons = true;
            set(obj.hButton_Calibration, 'Enable', 'on');
            set(obj.hButton_CheckDevice, 'Enable', 'on');
            set(obj.hButton_CloseApp, 'Enable', 'on');
            set(obj.hButton_SaveInfo, 'Enable', 'on');
            set(obj.hButton_SaveToPhone, 'Enable', 'on');
            set(obj.hButton_Start, 'Enable', 'on');
            obj.hInfoField.String = '';
            drawnow;
            
        end
        
        function [] = callbackPerformCalibration(obj, ~, ~)
            
            if ~obj.bEnableButtons
                return;
            end
            
            if ~obj.bCalib
                obj.showImage('setUpCalibrator');
            else
                sResult = questdlg('Reference microphone already calibrated. Redo?', ...
                    'Calibration', 'Yes','No', 'No');
                if (strcmp(sResult, 'Yes'))
                    obj.showImage('setUpCalibrator');
                end
            end
        end
        
        function [] = performCalibration(obj, ~, ~)
            
            obj.bEnableButtons = false;
            
            obj.bCalib = false;
            obj.bMeasurement = false;
            
            obj.showImage('');
            obj.hAxes.XLim = [0, obj.nBlockSize];
            obj.hAxes.YLim = [-1, 1];
            
            nSamples = obj.nDurationCalibration_s * obj.nSamplerate;
            
            vSilence = zeros(nSamples, 1);
            
            devReader = audiorecorder(obj.nFs, obj.nBits, 2, obj.nAudioInput);
            devPlayer = audioplayer(vSilence, obj.nFs, obj.nBits, obj.nAudioOutput);
            
            % Hack but works fine
            record(devReader);
            playblocking(devPlayer);
            stop(devReader);
            
            vCalibration = getaudiodata(devReader, 'double');
            
            if obj.hToggle_Input_L.Value
                vCalibration(:, 2) = [];
            else
                vCalibration(:, 1) = [];
            end
            
            obj.showImage('');
            
            if max(abs(vCalibration)) < 1/sqrt(2)
                obj.bEnableButtons = true;
                errordlg('Calibration signal too low.');
                return; 
            end
            
            % Write recording to file for offline analysis (TODO: omit)
            audiowrite('recording_Calibration.wav', vCalibration, obj.nSamplerate);

            obj.calculateCalibration(vCalibration);
            
            obj.bEnableButtons = true;
        end
        
        function calculateCalibration(obj, vCalibration)
            % HighPass
            [b, a] = butter(4, 100*2*pi/obj.nSamplerate, 'high');
            vCalibration = filter(b, a, vCalibration);
            
            % Calibrator emits signal 1kHz @ 114dB SPL
            obj.nLevel_Calib_dBSPL = 114;
            obj.nLevel_Calib_dBFS = 20*log10(rms(vCalibration));
            obj.nCalibConstant_Mic_FS_SPL = obj.nLevel_Calib_dBSPL - obj.nLevel_Calib_dBFS;
            
            obj.hLamp_Calibration.Color = obj.mColors(5, :);
            obj.showImage('');
            
            % Perform check whether calibration result was okay
            if true
                obj.bCalib = true;
            end            
        end
        
        function [] = callbackPerformTFMeasurement(obj, ~, ~)
            
            if ~obj.bEnableButtons
                return;
            end
            
            if ~obj.bMeasurement %&& ~obj.bCalib
                obj.showImage('setUpMeasurement');
            else
                sResult = questdlg('Measurement already taken. Redo?', ...
                    'Measurement', 'Yes','No', 'No');
                if (strcmp(sResult, 'Yes'))
                    obj.closeApp()
                    %sCommand = 'adb shell "am broadcast -a com.example.IHABSystemCheck.intent.TEST --es sms_body ''Reset'' -n com.example.IHABSystemCheck/.IntentReceiver"';
                    %[~, ~] = system(sCommand);
                    
                    sData = '';
                    while ~contains(sData, 'Waiting') && obj.bLoop
                        [~, sData] = system('adb shell dumpsys activity com.example.olMEGASystemCheck');
                        pause(0.1);
                    end
                    
                    obj.showImage('setUpMeasurement');
                end
            end
            
        end
        
        function [] = performTFMeasurement(obj, ~, ~)
            
            obj.bEnableButtons = false;
            
            obj.bMeasurement = false;
            
            obj.showImage('');
           
            nSamples = obj.nDurationMeasurement_s * obj.nFs;
            
            vSilence = zeros(nSamples, 2);
            
            vNoise = 2 * rand(nSamples, 1) - 1;
            
            if obj.hToggle_Output_L.Value
                vNoise = [vNoise, zeros(size(vNoise))];
            else
                vNoise = [zeros(size(vNoise)), vNoise];
            end
            
            obj.vRefMic_Noise = zeros(nSamples, 1);
            obj.vRefMic_Silence = zeros(nSamples, 1);

            obj.hAxes.Visible = 'On';
            
            fprintf('Measuring silence.\n')
          
            devReader = audiorecorder(obj.nFs, obj.nBits, 2, obj.nAudioInput);
            devPlayer = audioplayer(vSilence, obj.nFs, obj.nBits, obj.nAudioOutput);
            
            record(devReader);
            playblocking(devPlayer);
            stop(devReader);
            vRecord = getaudiodata(devReader, 'double');
            if obj.hToggle_Input_L.Value
                obj.vRefMic_Silence = vRecord(:, 1);
            else
                obj.vRefMic_Silence = vRecord(:, 2);
            end

            fprintf('Measuring Noise.\n');
            
            devReader = audiorecorder(obj.nFs, obj.nBits, 2, obj.nAudioInput);
            devPlayer = audioplayer(vNoise, obj.nFs, obj.nBits, obj.nAudioOutput);
            
            record(devReader);
            playblocking(devPlayer);
            stop(devReader);
            vRecord = getaudiodata(devReader, 'double');
            if obj.hToggle_Input_L.Value
                obj.vRefMic_Noise = vRecord(:, 1);
            else
                obj.vRefMic_Noise = vRecord(:, 2);
            end
            
            obj.phoneStopRecording();
            
        end
        
        function [] = finishTFMeasurement(obj)
            try
                vSystem = obj.phoneGetRecording();

                vSystem = vSystem - mean(vSystem);
                
                vIdx = obj.findNoiseIdx(vSystem);
                vSystem_Silence = vSystem(vIdx(1) : vIdx(2), :);
                vSystem_Noise = vSystem(vIdx(3) : vIdx(4), :);

                % Calculate Single Value System Calibration Constant
                L_RefMic_dBFS = 20*log10(rms(obj.vRefMic_Noise));
                L_olMEGA_dBFS = 20*log10(rms(vSystem_Noise));
                obj.nSystemCalibConstant = obj.nCalibConstant_Mic_FS_SPL - (L_olMEGA_dBFS - L_RefMic_dBFS);

                vDiff_RefMic = 20*log10(rms(obj.vRefMic_Noise)/rms(obj.vRefMic_Silence));
                vDiff_System = 20*log10(rms(vSystem_Noise)./rms(vSystem_Silence));

                vSpec_Ref_Silence = 10*log10(pwelch(obj.vRefMic_Silence, obj.nBlockSize));
                vSpec_Ref_Noise = 10*log10(pwelch(obj.vRefMic_Noise, obj.nBlockSize));
                vSpec_System_Silence = 10*log10(pwelch(vSystem_Silence, obj.nBlockSize));
                vSpec_System_Noise = 10*log10(pwelch(vSystem_Noise, obj.nBlockSize));

                obj.hAxes.Visible = 'On';
                obj.hAxes.NextPlot = 'replace';

                semilogx(obj.hAxes, vSpec_Ref_Noise + obj.nCalibConstant_Mic_FS_SPL, 'Color', obj.mColors(1, :));

                obj.hAxes.NextPlot = 'add';

                semilogx(obj.hAxes, vSpec_System_Noise(:, 1) + obj.nSystemCalibConstant(1), 'Color', obj.mColors(2, :));
                semilogx(obj.hAxes, vSpec_System_Noise(:, 2) + obj.nSystemCalibConstant(2), 'Color', obj.mColors(3, :));
                semilogx(obj.hAxes, vSpec_Ref_Silence + obj.nCalibConstant_Mic_FS_SPL, 'Color', obj.mColors(4, :));
                semilogx(obj.hAxes, vSpec_System_Silence(:,1) + obj.nSystemCalibConstant(1), 'Color', obj.mColors(5, :));
                semilogx(obj.hAxes, vSpec_System_Silence(:,2) + obj.nSystemCalibConstant(2), 'Color', obj.mColors(6, :));

                obj.hAxes.XLim = [0, obj.nBlockSize/2+1];
                %             obj.hAxes.YLim = [-100, 50];
                obj.hAxes.XTickLabel = {};
                obj.hAxes.XTick = [];
                obj.hAxes.YTickLabel = {};
                obj.hAxes.YTick = [];

                obj.hAxes.Box = 'On';
                obj.hAxes.Layer = 'Top';
                
                try
                    legend(obj.hAxes, {'RefNoise', 'SystemNoiseL', 'SystemNoiseR', ...
                        'RefSilence', 'SystemSilenceL','SystemSilenceR'}, ...
                        'Orientation', 'vertical', 'Location', 'SouthWest');
                catch
                end
                Image = frame2im(obj.hAxes);
                imwrite(Image, [pwd, filesep, 'calibration', filesep, replace(obj.sFileName_Calib, '.txt', '.png')]);

                if (abs(diff(vDiff_System)) > 3)
                    fprintf('Microphone dynamics more than 3 dB apart.\n');
                end

                if (abs(vDiff_RefMic - mean(vDiff_System)) >= 3)
                    fprintf('Dynamic disparity between reference and system.\n');
                end

                if  (abs(diff(obj.nSystemCalibConstant)) >= 3)
                    fprintf('Microphone levels more than 3 dB apart.\n')
                end

                % Check whether calibration result is valid
                if diff(obj.nSystemCalibConstant) < 2

                    obj.writeCalibrationToFile(obj.nSystemCalibConstant);

                    obj.hEdit_Constant.Value = num2str(mean(obj.nSystemCalibConstant));
                    obj.hLamp_Measurement.Color = obj.mColors(5, :);    
                    obj.bMeasurement = true;
                end
            catch
                uiwait(msgbox('Error analysing recorded Signal'));
            end

            obj.bEnableButtons = true;
            
        end
        
        function [] = writeCalibrationToFile(obj, vLevel)
            hFid = fopen([pwd, filesep, 'calibration', filesep, obj.sFileName_Calib], 'w');
            fprintf(hFid, '%f\n', vLevel);
            fclose(hFid);
        end
        
        function [] = doNothing(obj, ~, ~)
            return;
        end
        
        function [vIdx] = findNoiseIdx(obj, vSignal)
            
            %vSignal = vSignal - mean(vSignal);
            vSignal(1:round(0.5*obj.nSamplerate), :) = [];
            
            nLevelStart = mean(rms(vSignal(1*obj.nSamplerate : 3*obj.nSamplerate, :)));
            nIdx = find(mean(abs(vSignal), 2) > nLevelStart*10);
            nIdx_Noise_Start = nIdx(1);
            nIdx_Noise_Start_safe = nIdx_Noise_Start + 1*obj.nSamplerate;
            nIdx_Noise_End = nIdx(end);
            nIdx_Noise_End_safe = nIdx_Noise_End - 1*obj.nSamplerate;
            
            nIdx_Silence_End = nIdx_Noise_Start - obj.nSamplerate;
            nIdx_Silence_Start = nIdx_Silence_End - 3*obj.nSamplerate;
            
            vIdx = [nIdx_Silence_Start, nIdx_Silence_End, nIdx_Noise_Start_safe, nIdx_Noise_End_safe] + round(0.5*obj.nSamplerate);
            
            vIdx(1) = 1;
            vIdx(4) = length(vSignal);
            

%             vIdx = [0.1, 4.5, 5.5, 9.5]*obj.nFs_Target;
        end
        
        function [] = phoneStartRecording(obj, ~, ~)
            
            % Wait and check if application is running as expected
            sData = '';
            while ~contains(sData, 'Measuring') && obj.bLoop
                [~, sData] = system('adb shell dumpsys activity com.example.olMEGASystemCheck');
                pause(0.1);
            end
            
            
%             
%             system("adb shell svc usb setFunctions ptp");
%             system("adb shell svc usb setFunctions mtp");
%             fprintf('sending now\n');
%             
% %             sCommand = 'adb shell "am broadcast -a com.example.IHABSystemCheck.intent.TEST --es sms_body ''Start'' -n com.example.IHABSystemCheck/.IntentReceiver --include-stopped-packages"';
%             sCommand = 'adb shell "am broadcast -a com.example.IHABSystemCheck.intent.TEST --es sms_body ''Start'' -n com.example.IHABSystemCheck/.IntentReceiver"';
%             [~, ~] = system(sCommand);
%             
%             fprintf('sent\n');
%             
%             system("adb shell svc usb setFunctions ptp");
%             system("adb shell svc usb setFunctions mtp");
%             
%             sData = '';
%             while ~contains(sData, 'Measuring') && obj.bLoop
%                 [~, sData] = system('adb shell dumpsys activity com.example.IHABSystemCheck');
%                 sData
%                 pause(0.1);
%             end



%             
            obj.performTFMeasurement();
%             
        end
        
        function [] = phoneStopRecording(obj)
            
            %sCommand = 'adb shell "am broadcast -a com.example.IHABSystemCheck.intent.TEST --es sms_body ''Stop'' -n com.example.IHABSystemCheck/.IntentReceiver --include-stopped-packages"';
%             [~, ~] = system(sCommand);
            
            sData = '';
            while ~contains(sData, 'Finished') && obj.bLoop
                [~, sData] = system('adb shell dumpsys activity com.example.olMEGASystemCheck');
                pause(0.1);
            end
            
%             sCommand = 'adb shell "am broadcast -a com.example.IHABSystemCheck.intent.TEST --es sms_body ''Finished'' -n com.example.IHABSystemCheck/.IntentReceiver --include-stopped-packages"';
%             [~, ~] = system(sCommand);
            
            obj.finishTFMeasurement();
            
        end
        
        function [vRecording] = phoneGetRecording(obj)
            
            if ~exist([pwd, filesep, 'cache'], 'dir')
                mkdir([pwd, filesep, 'cache']);
            end
            [~, ~] =  system(['adb pull sdcard/olMEGASystemCheck/cache/SystemCheck.wav ', pwd, filesep, 'cache']);
            vRecording = audioread([pwd, filesep, 'cache', filesep, 'SystemCheck.wav']);
            %delete([pwd, filesep, 'cache', filesep, 'SystemCheck.wav']);
        end
        
        function [] = callbackSaveToDisk(obj, ~, ~)
            
            if ~obj.bEnableButtons
                return;
            end
            
            if obj.bMeasurement
                obj.saveToDisk();
            else
                errordlg('No measurement data available.')
            end
        end
        
        function [] = saveToDisk(obj, ~, ~)
            sFolder = uigetdir('Please select directory to store calibration data.');
            
            if ~isempty(sFolder)
                copyfile([pwd, filesep, 'calibration', filesep, obj.sFileName_Calib], sFolder);
            end
            
        end
        
        function [] = callbackSaveToPhone(obj, ~, ~)
            
            if ~obj.bEnableButtons
                return;
            end
            
            if obj.bMeasurement
                obj.saveToPhone();
            else
                errordlg('No measurement data available.')
            end
        end
        
        function [] = saveToPhone(obj, ~, ~)
            
            obj.bEnableButtons = false;
            
            vStatus = [];
            
            % Erase folder
            sCommand_erase_quest = [obj.prefix, 'adb shell rm -r /sdcard/olMEGA/calibration'];
            [status, ~] = system(sCommand_erase_quest);
            vStatus = [vStatus, status];
            
            % Make new folder
            sCommand_erase_quest = [obj.prefix, 'adb shell mkdir /sdcard/olMEGA/calibration'];
            [status, ~] = system(sCommand_erase_quest);
            vStatus = [vStatus, status];
            
            % Copy calibration data to phone
            sCommand_log = [obj.prefix, 'adb push calibration/', obj.sFileName_Calib,' sdcard/olMEGA/calibration/calib.txt'];
            [status, ~] = system(sCommand_log);
            vStatus = [vStatus, status];
            
            % Check-in new folder
            sCommand_erase_quest = [obj.prefix, 'adb -d shell "am broadcast -a android.intent.action.MEDIA_MOUNTED -d file:///sdcard/olMEGA/calibration'];
            [status, ~] = system(sCommand_erase_quest);
            vStatus = [vStatus, status];
            
            sCommand = 'adb shell "am broadcast -a com.example.olMEGASystemCheck.intent.TEST --es sms_body ''StoreCalibration'' -n com.example.olMEGASystemCheck/.IntentReceiver --include-stopped-packages"';
            [~, ~] = system(sCommand);

            %TODO: Check whether file is there
            if true
                % Announce all is good
                obj.hLamp_Saved.Color = obj.mColors(5, :);
            end
            
            obj.bEnableButtons = true;
            
        end
        
        function [] = callbackCloseApp(obj, ~, ~)
            
%             if obj.bEnableButtons
                obj.bLoop = false;
                drawnow;
                % Close Android App
                obj.closeApp();
                % Close Matlab App
                close(obj.hFig_Main);
                % Just to be sure there are no open dialog boxes
                close all;
%             end
            
        end
        
        function [] = closeApp(obj)
            [~, ~] =  system('adb shell am force-stop com.example.olMEGASystemCheck');
        end
        
    end
    
end