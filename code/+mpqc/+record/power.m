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
    %   .SIpower_mW
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


    %%
    % Parse inputs and ensure user has supplied the current wavelength
    out =  parseInputVariable(varargin{:});
    laser_wavelength=out.wavelength;


    %% Important variables
    % The following are important and could in future become input arguments.

    % The number of steps over which the sample the power fraction range.
    numSteps = 21;

    % The number of times to measure power at each percent power value
    sampleReps = 4;


    %%
    % Connect to power meter and set wavelength. Bail out if we can't connect to it.

    % Get the list of connected devices and cache in base workspace
    W = evalin('base','whos');
    if ismember('PowerMeterDevices',{W.name});
        fprintf('Reusing list of previously connected power meters\n')
        DeviceDescription = evalin('base', 'PowerMeterDevices');
        powermeter = mpqc.interfaces.ThorlabsPowerMeter(DeviceDescription);
    else
        powermeter = mpqc.interfaces.ThorlabsPowerMeter;
        DeviceDescription = powermeter.deviceList; % cache
        assignin('base','PowerMeterDevices',DeviceDescription);
    end

    powermeter.connect
    powermeter.setWaveLength(laser_wavelength)



    % Connect to ScanImage using the linker class
    API = sibridge.silinker;

    if API.linkSucceeded == false
        delete(powermeter)
        return
    end

    %Record the state of all ScanImage settings we will change so we can change them back
    settings = mpqc.tools.recordScanImageSettings(API);


    API.turnOffAllPMTs
    API.pointBeam

    % control the laser power in percentage
    API.setLaserPower(.01) ; % set laser power to 1%


    %TODO: only works on one laser systems? <------




    %% Build a figure to display the data as we go
    powerPlot = figure;

    % Pre-allocate
    observedPower = zeros(numSteps,sampleReps)*nan;
    SIpower_mW = zeros(1,numSteps);
    powerSeriesPercent_mW = linspace(0,100,numSteps);
    
    powerSeriesPercent_matrix_tmp = repmat(powerSeriesPercent_mW',1,sampleReps);
    H_observed = plot(powerSeriesPercent_matrix_tmp(:),observedPower(:),'.k');

    hold on
    H_meanVal = plot(powerSeriesPercent_mW,mean(observedPower,2),'-r');
    H_SI_Power = plot(powerSeriesPercent_mW,SIpower_mW*1000, '-b');
    hold off

    legend([H_observed H_meanVal H_SI_Power], ...
        'Raw values', 'Mean Observed Power', 'SI Power', ...
        'Location', 'NorthWest')
    title(['Wavelength = ',num2str(laser_wavelength), 'nm'])
    ylabel('Power (mW)')
    xlabel('Percent power')

    % Set Y axis limits to reasonable values from the start
    ylim([0, API.powerPercent2Watt(1)*1200])
    xlim([0,105])
    box on
    grid on


    % Record and plot graph as we go
    for ii = 1:numSteps
        API.setLaserPower(powerSeriesPercent_mW(ii)/100);
        pause(0.1); % pause for 0.1 seconds

        for jj = 1:sampleReps
            % Read power in W. Convert to mW and store.
            observedPower(ii,jj) = powermeter.readPower *1000;
        end

        % The power scanimage thinks it is at each percentage laser power
        SIpower_mW(ii) = API.powerPercent2Watt(powerSeriesPercent_mW(ii)/100)*1000;

        H_observed.YData = observedPower(:);
        H_meanVal.YData(ii) = mean(observedPower(ii,:),2);
        H_SI_Power.YData(ii) = SIpower_mW(ii);
        drawnow
    end


    % Disconnect from power meter
    delete(powermeter)

    API.parkBeam


    % Reapply original ScanImage settings
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
    powerMeasurements.SIpower_mW = SIpower_mW';
    powerMeasurements.powerSeriesPercent_mW = powerSeriesPercent_mW;
    powerMeasurements.currentTime = datestr(now,'yyyy-mm-dd_HH-MM-SS');
    powerMeasurements.laser_wavelength= laser_wavelength;


    % Optionally return data structure
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

        fileName = sprintf('%s_power_calib_%dnm__%s', ...
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
