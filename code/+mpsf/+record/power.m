function power(varargin)
% Measuring the power out of the objective at different percent power in SI
%
% function mpsf.record.power('wavelength', value)
%
% Purpose
% Uses a powermeter in the sample plane to measure the true laser power out
% of the object at different percent power levels in scanImage. Also save
% the predicted power given by scanImage.
%
% Isabell Whiteley, SWC 2025


out =  parseInputVariable(varargin{:});
laser_wavelength=out.wavelength;

% Connect to ScanImage using the linker class
API = sibridge.silinker;

if API.linkSucceeded == false
    return
end

% Create 'diagnostic' directory in the user's desktop
saveDir = mpsf.tools.makeTodaysDataDirectory;
if isempty(saveDir)
    return
end

%Record the state of all ScanImage settings we will change so we can change them back
settings = mpsf.tools.recordScanImageSettings(API);

API.turnOffPMTs % is this how to do this? How does it know how many PMTs there are?

% Connect to Powermeter, set wavelength, zero
powermeter = mpsf.interfaces.ThorPower; % IS THIS HOW TO CALL THE POWERMETER CLASS?
powermeter.setWavelength(laser_wavelength) % sends new wavelength to powermeter

% Tell SI to point
API.pointBeam % turns on point in scanimage

% control the laser power in percentage
API.controlLaserPower = .01; % set laser power to 1%


%% Measure power
Power = zeros(10,20);
SIpower = zeros(1,20);
SIpower(1,1) = API.powerPercent2Watt;
for measurements = 1:size(Power,1) % measuring first data point
    Power(measurements,1) = powermeter.getPower; % takes 10 measurements at each percentage, pausing for 0.25s between each
    pause(0.25)
end

% then put it  in a loop!
for percent = 1:size(Power,2)-1 % should loop 19 times, first datapoint collected already
    API.controlLaserPower = percent*5; % increase laser power in 5% increments
    pause(3); % pause for 3 seconds
    for measurements = 1:size(Power,1) % takes 10 measurements at each percentage, pausing for 0.25s between each
        Power(measurements,percent+1) = powermeter.getPower;
        pause(0.25)
    end
    SIpower(1,percent+1) = API.powerPercent2Watt;%this is in BeamControls % the power scanimage thinks it is at each percentage laser power
end

% Turn off point


%% Save measured power and what SI thinks it should be

% Set file name and save dir
SETTINGS=mpsf.settings.readSettings;
fileStem = sprintf('%s_power_%dnm_%dmW_%s__%s', ...
    SETTINGS.microscope.name, ...
    laser_wavelength, ...
    datestr(now,'yyyy-mm-dd_HH-MM-SS'));


% API.hSI.hScan2D.logFileStem=fileStem;
% API.hSI.hScan2D.logFilePath=saveDir;
% API.hSI.hScan2D.logFileCounter=1;
% 
% API.acquireAndWait;


% Report where the file was saved
mpsf.tools.reportFileSaveLocation(saveDir,fileStem)

% Save system settings to this location
settingsFilePath = mpsf.settings.findSettingsFile;
copyfile(settingsFilePath, saveDir)

% Reapply original scanimage settings
mpsf.tools.reapplyScanImageSettings(API,settings);