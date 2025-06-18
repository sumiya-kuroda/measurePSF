classdef power < handle

    % Measures the power at the objective at a range of percent power values in ScanImage
    %
    % Purpose
    % Uses a ThorLabs power meter in the sample plane to measure the true laser power at
    % the at different percent power levels in ScanImage. Plots compare the measured power
    % to that predicated by ScanImage. A calibration button applies the measured power
    % settings to ScanImage. Other buttons return the power value data to the base
    % workspace or saves the data as a .mat file.
    %
    %
    % ** Basic Usage:
    % P = mpqc.record.power(800); % Starts the GUI, specifying the laser is tuned to 800 nm
    % P = mpqc.record.power; % Starts the GUI: the user is prompted to enter the wavelength
    %
    % NOTE: if you re-tune the wavelength you should either re-start the GUI or set the
    % the wavelength as follows:
    % P.laserWavelength = 920
    %
    %
    % ** Using the GUI
    % Pressing "Measure Power Curve" will initiate the measurement process and display
    % the results to screen. You can also start the measurement process by running the
    % the recordPowerCurve method at the command line:
    %
    % e.g.
    % P = mpqc.record.power(800);
    % P.recordPowerCurve
    %
    % The above method name is brought up in the tooltip that appears when you hover over
    % the "Measure Power Curve" button.
    %
    %
    % ** Changing the recording parameters
    % To alter the number of points at which the curve is sampled, change the "numSteps"
    % property at the command line and re-run the measurement. To change the number of
    % times each power level is sampled, alter the "sampleReps" property.
    %
    %
    % ** Interpreting the results
    % The left panel shows laser power as a function of percent power in ScanImage. The
    % blue line represents the predicted power from ScanImage. The points and red line are
    % the measured data. A linear fit is applied after the data are acquired. If the
    % microscope is well-calibrated the red fit line will lie on top of the blue line
    % representing the expected values.
    %
    % The the right plot is the difference between the expected and record values as a
    % function of the recorded values. Structure in this plot, especially a curve at the
    % high or low end, could be due to modulator non-linearity. Ensure the offset of the
    % modulator is set correctly and re-run the ScanImage modulator calibration before
    % re-running the power measurement.
    %
    % The data could also be skewed if your sensor is very slow. Change the "settingTime"
    % property to take into account slower sensors.
    %
    %
    % ** Calibrating ScanImage
    % If you are happy that the recorded data look good, press the "Calibrate ScanImage"
    % button and re-run "Measure Power Curve". The expected and measured curves should
    % correspond closely. You may find that very low percent power values now correspond
    % to negative power values. This is because of an imperfect offset of some modulators
    % and arises from their sinusoidal relationship between command voltage and power
    % output. In most cases these negative values are not a problem as we don't need the
    % very low end of the scale. If you need to image a precise low power (such as 5 mW)
    % it is a good idea to measure this before starting and not rely on ScanImage.
    % If you use only lower power values, you can restrict the maximum command signal and
    % play with the offset of the modulator to get a pretty good correspondence between
    % actual and predicted power over your range of interest.
    %
    %
    % ** BakingTray Interface
    % If you are using the laser control interface from the BakingTray, you can start
    % BakingTray first and mpqc.record.power will query the current wavelength each time
    % it makes a recording so you don't have to set this manually.
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

        % Time between changing the laser power and starting to measure.
        % This is to take into account settling time of the power sensor head.
        settlingTime = 0.2;

        laserWavelength

        powerMeasurements %- a structure containing the recorded data with fields:
        %   .observedPower
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

            %%
            % Parse inputs and ensure user has supplied the current wavelength
            out =  parseInputVariable(varargin{:});

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
                % Clean up, disconnect from power meter, etc

                % Reapply original ScanImage settings
                if ~isempty(obj.API) && obj.API.linkSucceeded
                    if ~isempty(obj.cachedSettings)
                        mpqc.tools.reapplyScanImageSettings(obj.API, obj.cachedSettings);
                    end
                    obj.API.parkBeam
                end

                % Disconnect from power meter
                delete(obj.powermeter)

                obj.hBT = [];

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




        end % main methods



        % Getters or setter
        methods

            function set.laserWavelength(obj,val)
                % Reset the plot if the user changes wavelength. This makes it less
                % likely the user will acquire data tagged with the wrong wavelength.
                obj.resetPlot
                obj.laserWavelength = val;
            end

        end % getters/setters



        % Callbacks
        methods
            function recordPowerCurve(obj,~,~)
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
                obj.H_SI_Power = plot(powerSeriesPercent_mW, SIpower_mW*1000, '-b', ...% TODO--why is that x1000?
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
                    pause(obj.settlingTime);

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
                obj.powerMeasurements.fittedMinAndMax = [];

                % Updates obj.powerMeasurements.fittedMinAndMax
                obj.fitRawData

                obj.enableButtons;

            end % recordPowerCurve


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
