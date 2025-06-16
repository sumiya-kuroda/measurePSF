function varargout = power(varargin)
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
    %   .SIpower
    %   .laser_wavelength
    %
    %
    % Requirements
    % You must have installed ThorLabs power meter GUI from:
    % https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=OPM
    % See mpqc.interfaces.ThorlabsPowerMeter
    %
    %
    % Isabell Whiteley, SWC AMF, initial commit 2025



    % Parse inputs and ensure user has supplied the current wavelength
    out =  parseInputVariable(varargin{:});
    laser_wavelength=out.wavelength;


    % Connect to Powermeter and set wavelength. Bail out if we can't connect to it
    meterlist = mpqc.interfaces.ThorlabsPowerMeter;
    if isempty(meterlist.modelName)
        return
    end
    DeviceDescription=meterlist.listdevices;                % List available device(s)
    powermeter=meterlist.connect(DeviceDescription);  
    powermeter.setWaveLength(laser_wavelength) % sends new wavelength to powermeter


    % The number of steps over which the sample the power fraction range.
    numSteps = 21; % to include the 0% step

    % The number of times to measure power at each percent power value
    sampleReps = 1;


    % Connect to ScanImage using the linker class
    API = sibridge.silinker;

    if API.linkSucceeded == false
        return
    end

    %Record the state of all ScanImage settings we will change so we can change them back
    settings = mpqc.tools.recordScanImageSettings(API);

    API.turnOffAllPMTs

    % Tell SI to point
    API.pointBeam

    % control the laser power in percentage
    API.setLaserPower(.01) ; % set laser power to 1%

    %TODO: only works on one laser systems


    %% Measure power
    observedPower = zeros(numSteps,sampleReps)*nan;
    SIpower = zeros(1,numSteps);
    powerSeriesPercent = linspace(0,100,numSteps);
    powerSeriesPercentMatrix = repmat(powerSeriesPercent',1,sampleReps);
    powerSeriesDec = linspace(0,1,numSteps);


    %% Build a figure to display the data as we go
    powerPlot = figure;
    observed = plot(powerSeriesPercentMatrix(:),observedPower(:),'.k');
    hold on
    meanVal = plot(powerSeriesPercent,mean(observedPower,2),'-r');
    est = plot(powerSeriesPercent,SIpower*1000, '-b');
    hold off

    legend([observed meanVal est],'Raw values', 'Mean Observed Power', 'SI Power')
    title(['Wavelength = ',num2str(laser_wavelength), 'nm'])
    ylabel('Power (mW)')
    xlabel('Percent power')

    for ii = 1:numSteps
        API.setLaserPower(powerSeriesDec(ii));
        pause(0.1); % pause for 0.1 seconds

        for jj = 1:sampleReps
            % observedPower(ii,jj) = powermeter.updateReading(0.1);
            powermeter.updateReading(0.1);
            observedPower(ii,jj) = powermeter.meterPowerReading *1000;

            % pause(0.1)
        end

        % the power scanimage thinks it is at each percentage laser power
        SIpower(1,ii) = API.powerPercent2Watt(powerSeriesDec(ii));

        observed.YData = observedPower(:);
        meanVal.YData(ii) = mean(observedPower(ii,:),2);
        est.YData(ii) = SIpower(1,ii)*1000;
        drawnow
    end

    delete(powermeter)

    API.parkBeam


    % Reapply original scanimage settings
    mpqc.tools.reapplyScanImageSettings(API,settings);


    % A save button is added at the end so the user can optionally save data
    saveData_PushButton = uicontrol(...
        'Style', 'PushButton', ...
        'Units', 'Normalized', ...
        'Position', [0.75, 0.015, 0.15, 0.04], ...
        'String', 'Save Data', ...
        'ToolTip', 'Save data to Desktop', ...
        'Parent',powerPlot, ...
        'Callback', @saveData_Callback);

    % TODO -- add calibrate button

    % TODO -- could add a second button that returns the structure to the base workspace


    % Assemble the power measurements in a structure that can be saved or returned at the
    % command line to the base workspace.
    powerMeasurements.observedPower = observedPower;
    powerMeasurements.SIpower = SIpower;
    powerMeasurements.currentTime = datestr(now,'yyyy-mm-dd_HH-MM-SS');
    powerMeasurements.laser_wavelength= laser_wavelength;


    %optionally return data structure
    if nargout > 0
        varargout{1} = powerMeasurements;
    end


    %%
    % Nested callback functions follow
    function saveData_Callback(~,~)
        % Create 'diagnostic' directory in the user's desktop
        saveDir = mpqc.tools.makeTodaysDataDirectory;
        if isempty(saveDir)
            fprintf('Failed to make save directory. NOT SAVING.\n')
            return
        end

        % Runs when the save button is pressed
        SETTINGS=mpqc.settings.readSettings;

        fileName = sprintf('%s_power_calib_%dnm_%s__%s', ...
            SETTINGS.microscope.name, laser_wavelength, ...
             datestr(now,'yyyy-mm-dd_HH-MM-SS'));
        save(fullfile(saveDir,fileName), "powerMeasurements")

        % Save system settings to this location
        settingsFilePath = mpqc.settings.findSettingsFile;
        copyfile(settingsFilePath, saveDir)

        % Report where the file was saved
        mpqc.tools.reportFileSaveLocation(saveDir,fileName)
    end % saveData_Callback


end % power
