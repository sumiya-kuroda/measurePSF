function varargout = power(varargin)
% Measuring the power out of the objective at different percent power in SI
%
% function mpqc.record.power('wavelength', value)
%
% Purpose
% Uses a powermeter in the sample plane to measure the true laser power out
% of the object at different percent power levels in scanImage. Also save
% the predicted power given by scanImage.
%
% Inputs
% ....
%
% Outputs
% optionally return data structure...
%
%
% Isabell Whiteley, SWC AMF, inital commit 2025


out =  parseInputVariable(varargin{:});
laser_wavelength=out.wavelength;
percentIncrease = 0.05;
stepSize = round(1/percentIncrease);

% Connect to ScanImage using the linker class
API = sibridge.silinker;

if API.linkSucceeded == false
    return
end

% Create 'diagnostic' directory in the user's desktop
    saveDir = mpqc.tools.makeTodaysDataDirectory;
    if isempty(saveDir)
        return
    end

%Record the state of all ScanImage settings we will change so we can change them back
settings = mpqc.tools.recordScanImageSettings(API);

API.turnOffAllPMTs % is this how to do this? How does it know how many PMTs there are?

% Connect to Powermeter, set wavelength, zero
powermeter = mpqc.interfaces.ThorPower; % IS THIS HOW TO CALL THE POWERMETER CLASS?
powermeter.setWavelength(laser_wavelength) % sends new wavelength to powermeter

% Tell SI to point
API.pointBeam % turns on point in scanimage

% control the laser power in percentage
API.setLaserPower(.01) ; % set laser power to 1%
%TO DO: only works on one laser systems


%% Measure power
observedPower = zeros(10,stepSize);
SIpower = zeros(1,stepSize);

% then put it  in a loop!
powerSeries = 0:percentIncrease:1;
for ii = 1:length(powerSeries-1) % should loop 19 times, first datapoint collected already
    API.setLaserPower(powerSeries(ii));
    pause(0.125); % pause for 3 seconds
    tic
    for jj = 1:size(observedPower,1) % takes 10 measurements at each percentage, pausing for 0.25s between each
        observedPower(jj,ii) = powermeter.getPower;
        % pause(0.25)
    end
    % the power scanimage thinks it is at each percentage laser power
    SIpower(1,ii) = API.powerPercent2Watt(powerSeries(ii));
    toc
end
delete(powermeter)

powerMeasurements.observedPower = observedPower;
powerMeasurements.SIpower = SIpower;
currentTime = datestr(now,'yyyy-mm-dd_HH-MM-SS');
powerMeasurements.currentTime = currentTime;
powerMeasurements.laser_wavelength= laser_wavelength;

% Turn off point
API.parkBeam % Parks beam in scanimage

% Plot the data and ask user if they want to save
figure
plot(powerSeries*100,observedPower','.k')
hold on
meanPower = plot(powerSeries*100,mean(observedPower,1),'-r');
estPower = plot(powerSeries*100,SIpower*1000, '-b'); % Puts SI power into mW
legend([meanPower estPower], 'Mean Observed Power', 'SI Power')
title(['Wavelength = ',num2str(laser_wavelength), 'nm'])
ylabel('Power (mW)')
xlabel('Percent power')


% Add save button
saveData_PushButton = uicontrol('Style', 'PushButton', 'Units', 'Normalized', ...
    'Position', [0.4, 0.025, 0.15, 0.04], 'String', 'Save Data', ...
    'ToolTip', 'Save data to Desktop', ...
    'Callback', @saveData_Callback);
hold off

%% Save measured power and what SI thinks it should be
SETTINGS=mpqc.settings.readSettings;
fileStem = sprintf('%s_power_calib_%dnm_%s__%s', ...
    SETTINGS.microscope.name, laser_wavelength, ...
    datestr(now,'yyyy-mm-dd_HH-MM-SS'));
fullfile(saveDir,fileStem);
    function saveData_Callback(ObjectH, EventData)
        % display('button pushed')
        save(fullfile(saveDir,fileStem), "powerMeasurements")
        % Report where the file was saved
        mpqc.tools.reportFileSaveLocation(saveDir,fileStem)
    end

% Save system settings to this location
settingsFilePath = mpqc.settings.findSettingsFile;
copyfile(settingsFilePath, saveDir)

% Reapply original scanimage settings
mpqc.tools.reapplyScanImageSettings(API,settings);

%optionally return data structure
if nargout > 0
    varargout{1} = powerMeasurements;
end

end