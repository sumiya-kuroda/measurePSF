classdef power < handle

    % Measures the power at the objective at a range of percent power values in SI
    %
    % Purpose
    % Uses a powermeter in the sample plane to measure the true laser power at the
    % objective at different percent power levels in ScanImage. Used to check that
    % the power calibration is accurate. The function also saves these predicted
    % power values.
    %
    %
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
        %   .observedPower
        %   .currentTime
        %   .SIpower_mW
        %   .laserWavelength
        %   .fittedMinAndMax

        % Plot elements in raw data plot
        H_observed
        H_meanVal
        H_SI_Power
        H_fit

    end % properties

    properties (Hidden)
        hFig      % The figure window
        hAxPower  % Plot showing power in mW as a function of % power
        hAxResid  % Plot showing the residuals

        % Buttons
        hButton_save
        hButton_data2base
        hButton_calibrateSI


        figureTag = 'powerMeterFig'

        cachedSettings % cached ScanImage settings to re-apply

        API % ScanImage APIs
        powermeter % Power meter class is here
    end

    methods

        function obj = power(varargin)
            % Measures the power at the objective at a range of percent power values in SI
            %
            % function mpqc.record.power('wavelength', value)
            %
            % Purpose
            % Uses a powermeter in the sample plane to measure the true laser power at the
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
            %   .observedPower
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
                out =  parseInputVariable(varargin{:});
                obj.laserWavelength=out.wavelength;


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

                obj.makeFigWindow

            end


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
                obj.powermeter.setWaveLength(obj.laserWavelength)

            end % connectToPowerMeter



            function recordPowerCurve(obj)
                % Record power curve and compare to compare actual vs expected
                %
                % power.recordPowerCurve


                obj.resetPlot;

                % Pre-allocate local variables for plotting
                observedPower = zeros(obj.numSteps, obj.sampleReps)*nan;
                SIpower_mW = zeros(1, obj.numSteps);
                powerSeriesPercent_mW = linspace(0,100,obj.numSteps);

                %powerSeriesPercent_matrix_tmp = repmat(powerSeriesPercent_mW',1,sampleReps);
                %H_observed = plot(powerSeriesPercent_matrix_tmp(:),observedPower(:),'.k', ...
                %    'Parent', obj.hAxPower);
                % TODO -- the following should work instead of the above

                %repmat(powerSeriesPercent_mW,1,obj.sampleReps)'
                %size(observedPower(:)),
                obj.H_observed = plot(repmat(powerSeriesPercent_mW,1,obj.sampleReps)', ...
                            observedPower(:),'.k', 'Parent', obj.hAxPower);

                hold(obj.hAxPower,'on')

                % The mean values at each percent power
                obj.H_meanVal = plot(powerSeriesPercent_mW, mean(observedPower,2),'-r', ...
                    'Parent', obj.hAxPower);

                % The predicted power from ScanImage
                obj.H_SI_Power = plot(powerSeriesPercent_mW, SIpower_mW*1000, '-b', ...
                    'Parent', obj.hAxPower);

                % A linear fit will go here
                obj.H_fit = plot([powerSeriesPercent_mW(1), powerSeriesPercent_mW(end)], ...
                    [nan,nan],'-r','LineWidth',2,'Parent', obj.hAxPower);

                hold(obj.hAxPower,'off')

                %legend([obj.H_observed, obj.H_meanVal, obj.H_SI_Power], ...
                %    'Raw values', 'Mean Observed Power', 'SI Power', ...
                %    'Location', 'NorthWest')
                title(sprintf('Wavelength = %d nm', obj.laserWavelength))
                ylabel('Power (mW)')
                xlabel('Percent power')

                % Set Y axis limits to reasonable values from the start
                ylim([0, obj.API.powerPercent2Watt(1)*1200])
                xlim([0,105])
                box on
                grid on

                obj.API.turnOffAllPMTs
                obj.API.pointBeam

                % control the laser power in percentage
                obj.API.setLaserPower(.01) ; % set laser power to 1%

                % Record and plot graph as we go
                for ii = 1:obj.numSteps
                    obj.API.setLaserPower(powerSeriesPercent_mW(ii)/100);
                    pause(0.1); % pause for 0.1 seconds

                    for jj = 1:obj.sampleReps
                        % Read power in W. Convert to mW and store.
                        observedPower(ii,jj) = obj.powermeter.readPower*1000;
                    end

                    % The power scanimage thinks it is at each percentage laser power
                    SIpower_mW(ii) = obj.API.powerPercent2Watt(powerSeriesPercent_mW(ii)/100)*1000;

                    obj.H_observed.YData = observedPower(:);
                    obj.H_meanVal.YData(ii) = mean(observedPower(ii,:),2);
                    obj.H_SI_Power.YData(ii) = SIpower_mW(ii);
                    drawnow
                end


                obj.API.parkBeam;

                % Assemble the power measurements in a structure that can be saved or
                % returned at the command line to the base workspace.
                obj.powerMeasurements.observedPower = observedPower;
                obj.powerMeasurements.SIpower_mW = SIpower_mW';
                obj.powerMeasurements.powerSeriesPercent_mW = powerSeriesPercent_mW;
                obj.powerMeasurements.currentTime = datestr(now,'yyyy-mm-dd_HH-MM-SS');
                obj.powerMeasurements.laserWavelength = obj.laserWavelength;
                obj.powerMeasurements.fittedMinAndMax = obj.H_fit.YData;

            end % recordPowerCurve


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


                    obj.hAxPower = axes('Position', [0.08,0.15,0.4,0.4], ...
                                'parent', obj.hFig);

                    obj.hAxResid = axes('Position', [0.58,0.15,0.4,0.4], ...
                                'parent', obj.hFig);


                    % A save button is added at the end so the user can optionally save data
                    obj.hButton_save = uicontrol(...
                                'Style', 'PushButton', ...
                                'Units', 'Normalized', ...
                                'Position', [0.75, 0.015, 0.15, 0.04], ...
                                'String', 'Save Data', ...
                                'ToolTip', 'Save data to Desktop', ...
                                'Parent',obj.hFig, ...
                                'Callback', @obj.saveData_Callback);

                    obj.hButton_data2base = uicontrol(...
                                'Style', 'PushButton', ...
                                'Units', 'Normalized', ...
                                'Position', [0.45, 0.015, 0.25, 0.04], ...
                                'String', 'Data to base workspace', ...
                                'ToolTip', 'Copy data to base workspace', ...
                                'Parent',obj.hFig, ...
                                'Callback', @obj.data2base_Callback);

                    obj.hButton_calibrateSI = uicontrol(...
                                'Style', 'PushButton', ...
                                'Units', 'Normalized', ...
                                'Position', [0.15, 0.015, 0.25, 0.04], ...
                                'String', 'Calibrate ScanImage', ...
                                'ToolTip', 'Apply calibration data to ScanImage', ...
                                'Parent',obj.hFig, ...
                                'Callback', @obj.calibrateSI_Callback);



                    obj.hFig.CloseRequestFcn = @obj.windowCloseFcn; %So closing the window triggers the destructor
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
                obj.powerMeasurements = [];

            end % reset plot

        end


        % Callbacks
        methods
            function saveData_Callback(obj,~,~)
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

            function data2base_Callback(obj,~,~)
                % Runs when the data2base button is pressed
                assignin('base','PowerCalibrationData',obj.powerMeasurements);
            end % data2base_Callback

            function calibrateSI_Callback(obj,~,~)
                % Runs when the calibrate SI button is called
                if isempty(obj.powerMeasurements)
                    return
                end

                minMax = obj.powerMeasurements.fittedMinAndMax;
            end % calibrateSI_Callback


        end % callbacks



        methods (Hidden)
            function windowCloseFcn(obj,~,~)
                % This runs when the user closes the figure window.
                obj.delete % simply call the destructor
            end %close windowCloseFcn
        end % hidden methods

end % classdef
