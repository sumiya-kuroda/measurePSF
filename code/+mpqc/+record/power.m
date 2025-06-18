classdef power < handle

    % Measures the power at the objective at a range of percent power values in SI
    %
    % Purpose
    % Uses a power meter in the sample plane to measure the true laser power at the
    % objective at different percent power levels in ScanImage. Used to check that
    % the power calibration is accurate. The function also saves these predicted
    % power values.
    %
    % Usage notes
    % Change wavelength with, for example:
    % P = mpqc.record.power(800);
    % P.recordPowerCurve
    % P.laserWavelength(920)
    % P.recordPowerCurve
    %
    % Requirements
    % You must have installed ThorLabs power meter GUI from:
    % https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=OPM
    % See mpqc.interfaces.ThorlabsPowerMeter
    %
    %
    % Isabell Whiteley, SWC AMF, initial commit 2025


    properties
        % The number of steps over which the sample the power fraction range.
        numSteps = 21;

        % The number of times to measure power at each percent power value
        sampleReps = 4;

        laserWavelength

        powerMeasurements %- a structure containing the recorded data with fields:
        %   .observedPower_mW
        %   .currentTime
        %   .SIpower_mW
        %   .laserWavelength
        %   .fittedMinAndMax

    end % properties

    properties (Hidden)
        hFig      % The figure window
        hAxPower  % Plot showing power in mW as a function of % power
        hAxResid  % Plot showing the residuals

        % Buttons
        hButton_save
        hButton_data2base
        hButton_calibrateSI
        hButton_runPowerMeasure

        % Plot elements in raw data plot
        H_observed
        H_meanVal
        H_SI_Power
        H_fit

        figureTag = 'powerMeterFig'

        cachedSettings % cached ScanImage settings to re-apply

        API % ScanImage APIs
        powermeter % Power meter class is here
        hBT % BakingTray added here optionally to set laser power 
    end

    methods

        function obj = power(varargin)
            % Measures the power at the objective at a range of percent power values in SI
            %
            % function mpqc.record.power('wavelength', value)
            %
            % Purpose
            % Uses a power meter in the sample plane to measure the true laser power at the
            % objective at different percent power levels in ScanImage. Used to check that
            % the power calibration is accurate. The function also saves these predicted
            % power values.
            %
            %
            % Inputs (optional param/val pairs. If not defined, a CLI prompt appears)
            %  'wavelength' - Excitation wavelength of the laser. Defined in nm.
            %
            % Outputs (optional)
            % powerMeasurements - a structure containing the recorded data with fields:
            %   .observedPower_mW
            %   .currentTime
            %   .SIpower_mW
            %   .laserWavelength
            %
            %
            % Requirements
            % You must have installed ThorLabs power meter GUI from:
            % https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=OPM
            % See mpqc.interfaces.ThorlabsPowerMeter
            %
            %
            % Isabell Whiteley, SWC AMF, initial commit 2025


                %%
                % Parse inputs and ensure user has supplied the current wavelength
                if exist('BakingTray','file')
                    obj.hBT = BakingTray.getObject(true);
                    out.wavelength = obj.hBT.laser.readWavelength;
                else
                    out = parseInputVariable(varargin{:});
                end


                if ~ismac
                    % Connect to ScanImage using the linker class
                    obj.API = sibridge.silinker;

                    if obj.API.linkSucceeded == false
                        % Bail out if no ScanImage
                        return
                    end



                    % Record the state of all ScanImage settings we will change so we can
                    % change them back
                    obj.cachedSettings = mpqc.tools.recordScanImageSettings(obj.API);


                    obj.connectToPowerMeter
                end

                obj.makeFigWindow
                obj.laserWavelength=out.wavelength; % here since it triggers a figure reset


            end % constructor


            function delete(obj)

                % Reapply original ScanImage settings
                if ~isempty(obj.API) && obj.API.linkSucceeded
                    if ~isempty(obj.cachedSettings)
                        mpqc.tools.reapplyScanImageSettings(obj.API, obj.cachedSettings);
                    end
                    obj.API.parkBeam
                end

                % Disconnect from power meter
                delete(obj.powermeter)


                delete(obj.hFig)

            end % delete


            function connectToPowerMeter(obj)
                % Connect to power meter and set wavelength. Bail out if we can't connect to it.
                %
                % power.connectToPowerMeter()
                %
                %

                % Get the list of connected devices and cache in base workspace because this step
                % is slow
                W = evalin('base','whos');

                if ismember('PowerMeterDevices',{W.name});
                    fprintf('Reusing list of previously connected power meters\n')
                    DeviceDescription = evalin('base', 'PowerMeterDevices');
                    obj.powermeter = mpqc.interfaces.ThorlabsPowerMeter(DeviceDescription);
                else
                    obj.powermeter = mpqc.interfaces.ThorlabsPowerMeter;
                    DeviceDescription = obj.powermeter.deviceList; % cache
                    assignin('base','PowerMeterDevices',DeviceDescription);
                end

                obj.powermeter.connect

            end % connectToPowerMeter



            function fitRawData(obj)
                % linear fit of raw data

                if isempty(obj.powerMeasurements)
                    return
                end

                xraw = obj.H_observed.XData(:);
                y = obj.H_observed.YData(:);

                x=[ones(size(xraw)),xraw];

                [b,bint,r,~,out_stats]=regress(y,x);

                X = obj.H_fit.XData;
                Y = b(1)+ X*b(2);

                obj.H_fit.YData = Y;

                obj.powerMeasurements.fittedMinAndMax = Y;
            end % fitRawData


            function makeFigWindow(obj)
                % Build the figure window if it is not already there

                % TODO -- it's possible we don't actually need to find the existing window
                H = findobj('Tag',obj.figureTag);

                if isempty(H)
                    obj.hFig = figure('Tag',obj.figureTag);
                    figure(obj.hFig);


                    obj.hAxPower = axes('Position', [0.08,0.20,0.40,0.60], ...
                                'parent', obj.hFig);

                    obj.hAxResid = axes('Position', [0.58,0.20,0.40,0.60], ...
                                'parent', obj.hFig);


                    % A save button is added at the end so the user can optionally save data
                    obj.hButton_save = uicontrol(...
                                'Style', 'PushButton', ...
                                'Units', 'Normalized', ...
                                'Position', [0.75, 0.015, 0.15, 0.06], ...
                                'String', 'Save Data', ...
                                'ToolTip', sprintf('Save data to Desktop.\n("power.saveData")'), ...
                                'Parent', obj.hFig, ...
                                'Enable', 'off', ...
                                'Callback', @obj.saveData);

                    obj.hButton_data2base = uicontrol(...
                                'Style', 'PushButton', ...
                                'Units', 'Normalized', ...
                                'Position', [0.49, 0.015, 0.24, 0.06], ...
                                'String', 'Data to base workspace', ...
                                'ToolTip', sprintf('Copy data to base workspace.\n("power.data2base")'), ...
                                'Parent', obj.hFig, ...
                                'Enable', 'off', ...
                                'Callback', @obj.data2base);

                    obj.hButton_calibrateSI = uicontrol(...
                                'Style', 'PushButton', ...
                                'Units', 'Normalized', ...
                                'Position', [0.27, 0.015, 0.21, 0.06], ...
                                'String', 'Calibrate ScanImage', ...
                                'ToolTip',  sprintf('Apply calibration data to ScanImage.\n("power.calibrateSI")'), ...
                                'Parent', obj.hFig, ...
                                'Enable', 'off', ...
                                'Callback', @obj.calibrateSI);

                    obj.hButton_runPowerMeasure = uicontrol(...
                                'Style', 'PushButton', ...
                                'Units', 'Normalized', ...
                                'Position', [0.05, 0.015, 0.21, 0.06], ...
                                'String', 'Measure Power Curve', ...
                                'ToolTip', sprintf('Measure powerCurve\n("power.recordPowerCurve")'), ...
                                'Parent', obj.hFig, ...
                                'Enable', 'on', ...
                                'Callback', @obj.recordPowerCurve);

                    % So closing the window triggers the destructor
                    obj.hFig.CloseRequestFcn = @obj.windowCloseFcn;
                else
                    obj.hFig = findobj('Tag',obj.figureTag);
                end
            end % makeFigWindow


            function resetPlot(obj)
                % Reset all the plots and wipe all plotted data
                %
                % power.resetPlot()

                cla(obj.hAxPower)
                cla(obj.hAxResid)
                title(sprintf('Wavelength = %d nm', obj.laserWavelength),'parent',obj.hAxPower)
                obj.powerMeasurements = [];

                obj.disableButtons

            end % reset plot


            function disableButtons(obj)
                % disables buttons when no data are available to save

                obj.hButton_save.Enable='off';
                obj.hButton_data2base.Enable='off';
                obj.hButton_calibrateSI.Enable='off';
            end % disableButtons

            function enableButtons(obj)
                % enables buttons when no data are available to save

                obj.hButton_save.Enable='on';
                obj.hButton_data2base.Enable='on';
                obj.hButton_calibrateSI.Enable='on';
            end % disableButtons

        end % main methods



        % Getters or setter
        methods

            function set.laserWavelength(obj,val)
                % Reset the plot if the user changes wavelength. This makes it less
                % likely the user will acquire data tagged with the wrong wavelength.
                if ~isnumeric(val) || ~isscalar(val)
                    return
                end
                obj.laserWavelength = val;
                obj.powermeter.setWaveLength(obj.laserWavelength)
                obj.resetPlot

            end

        end % getters/setters



        % Callbacks
        methods
            function recordPowerCurve(obj,~,~)
                % Record power curve and compare to compare actual vs expected
                %
                % power.recordPowerCurve

                if ~isempty(obj.hBT)
                    obj.laserWavelength = obj.hBT.laser.readWavelength;
                else
                    obj.resetPlot;
                end

                % Pre-allocate local variables for plotting
                observedPower_mW = nan(obj.numSteps, obj.sampleReps);
                SIpower_mW = nan(1, obj.numSteps)';
                powerSeriesPercent = linspace(0,100,obj.numSteps);

                % A linear fit will go here
                obj.H_fit = plot([powerSeriesPercent(1), powerSeriesPercent(end)], ...
                    [nan,nan],'-r','LineWidth',2,'Parent', obj.hAxPower);

                hold(obj.hAxPower,'on')

                obj.H_observed = plot(repmat(powerSeriesPercent,1,obj.sampleReps)', ...
                            observedPower_mW(:),'.k', 'Parent', obj.hAxPower);

                % The mean values at each percent power
                obj.H_meanVal = plot(powerSeriesPercent, mean(observedPower_mW,2),'-r', ...
                    'Parent', obj.hAxPower);

                % The predicted power from ScanImage
                obj.H_SI_Power = plot(powerSeriesPercent, SIpower_mW*1000, '-b', ...
                    'Parent', obj.hAxPower);



                hold(obj.hAxPower,'off')

                legend([obj.H_meanVal, obj.H_SI_Power], ...
                    {'Mean Observed Power', 'SI Power'}, ...
                    'Location', 'NorthWest')

                title(sprintf('Wavelength = %d nm', obj.laserWavelength),'parent',obj.hAxPower)
                obj.hAxPower.YLabel.String = 'Power (mW)';
                obj.hAxPower.XLabel.String = 'Percent Power';

                % Set Y axis limits to reasonable values from the start
                obj.hAxPower.YLim = [0, obj.API.powerPercent2Watt(1)*1200];
                obj.hAxPower.XLim = [0,105];


                obj.API.turnOffAllPMTs
                obj.API.pointBeam

                % control the laser power in percentage
                obj.API.setLaserPower(.01) ; % set laser power to 1%

                box(obj.hAxPower,'on')
                grid(obj.hAxPower,'on')

                % Record and plot graph as we go
                for ii = 1:obj.numSteps
                    obj.API.setLaserPower(powerSeriesPercent(ii)/100);
                    pause(0.1); % pause for 0.1 seconds

                    for jj = 1:obj.sampleReps
                        % Read power in W. Convert to mW and store.
                        observedPower_mW(ii,jj) = obj.powermeter.readPower*1000;
                    end

                    % Overlay at the start the power scanimage thinks it is at each percentage 
                    % laser power
                    SIpower_mW(ii) = obj.API.powerPercent2Watt(powerSeriesPercent(ii)/100)*1000;

                    obj.H_observed.YData = observedPower_mW(:);
                    obj.H_meanVal.YData(ii) = mean(observedPower_mW(ii,:),2);
                    obj.H_SI_Power.YData(ii) = SIpower_mW(ii);
                    drawnow
                end

                obj.API.parkBeam;

                % Plot the difference between the ScanImage curve and the recorded data 
                % in the right plot axis. 
                plot(mean(observedPower_mW,2), (SIpower_mW - mean(observedPower_mW,2)), 'ok', ...
                    'MarkerFaceColor', [1,1,1]*0.5, ...
                    'parent', obj.hAxResid);

                obj.hAxResid.YLabel.String = 'SI\_Power - Observed\_Power (mW)';
                obj.hAxResid.XLabel.String = 'Observed Power (mW)';
                box(obj.hAxResid,'on')
                grid(obj.hAxResid,'on')


                % Assemble the power measurements in a structure that can be saved or
                % returned at the command line to the base workspace.
                obj.powerMeasurements.observedPower_mW = observedPower_mW;
                obj.powerMeasurements.SIpower_mW = SIpower_mW;
                obj.powerMeasurements.powerSeriesPercent = powerSeriesPercent;
                obj.powerMeasurements.currentTime = datestr(now,'yyyy-mm-dd_HH-MM-SS');
                obj.powerMeasurements.laserWavelength = obj.laserWavelength;
                obj.powerMeasurements.fittedMinAndMax = [];

                % Updates obj.powerMeasurements.fittedMinAndMax
                obj.fitRawData

                obj.enableButtons;

            end % recordPowerCurve


            function saveData(obj,~,~)
                % This callback runs when the save button is pressed

                if isempty(obj.powerMeasurements)
                    return
                end

                % Create 'diagnostic' directory in the user's desktop
                saveDir = mpqc.tools.makeTodaysDataDirectory;
                if isempty(saveDir)
                    fprintf('Failed to make save directory. NOT SAVING.\n')
                    return
                end

                % Build the file name to which we will save the data
                SETTINGS=mpqc.settings.readSettings;

                fileName = sprintf('%s_power_calib_%dnm__%s', ...
                    SETTINGS.microscope.name, obj.laserWavelength, ...
                     datestr(now,'yyyy-mm-dd_HH-MM-SS'));

                % Save data to this location
                powerMeasurements = obj.powerMeasurements;
                save(fullfile(saveDir,fileName), "powerMeasurements")


                % Ensure we have a copy of the system settings at this location too
                settingsFilePath = mpqc.settings.findSettingsFile;
                copyfile(settingsFilePath, saveDir)

                % Report where the file was saved
                mpqc.tools.reportFileSaveLocation(saveDir,fileName)
            end % saveData_Callback

            function data2base(obj,~,~)
                % Runs when the data2base button is pressed
                assignin('base','PowerCalibrationData',obj.powerMeasurements);
                fprintf('Data copied to base workspace as variable: "PowerCalibrationData"\n')
            end % data2base_Callback

            function calibrateSI(obj,~,~)
                % Runs when the calibrate SI button is called
                %
                % Uses the linear fit to set max and min limits in ScanImage
                if isempty(obj.powerMeasurements)
                    return
                end

                minMax_W = round(obj.powerMeasurements.fittedMinAndMax)/1000;
                obj.API.setBeamMinMaxPowerInW(minMax_W);
            end % calibrateSI_Callback


        end % callbacks



        methods (Hidden)
            function windowCloseFcn(obj,~,~)
                % This runs when the user closes the figure window.
                obj.delete % simply call the destructor
            end %close windowCloseFcn
        end % hidden methods

end % classdef
