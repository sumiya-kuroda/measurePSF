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

 % Create 'diagnostic' directory in the user's desktop
    saveDir = mpsf.tools.makeTodaysDataDirectory;
    if isempty(saveDir)
        return
    end

    %Record the state of all ScanImage settings we will change so we can change them back
    settings = mpsf.tools.recordScanImageSettings(API);

    API.turnOffPMTs() % is this how to do this? How does it know how many PMTs there are?

% Connect to Powermeter

    Powermeter = mic.powermeter.PM100D;
    % Powermeter.gui % don't  need this

% control the laser power in percentage
    API.hSI.hBeams.powers=0; % set laser power to zero

% Tell SI to point

% measure power
    Power = Powermeter.measure;

% save power, the percent power on SI, and what SI thinks it should be

% then put it  in a loop!



  % Set file name and save dir
    SETTINGS=mpsf.settings.readSettings;
    fileStem = sprintf('%s_power_%dnm_%dmW_%s__%s', ...
        SETTINGS.microscope.name, ...
        laser_wavelength, ...
        datestr(now,'yyyy-mm-dd_HH-MM-SS'));

    API.hSI.hScan2D.logFileStem=fileStem;
    API.hSI.hScan2D.logFilePath=saveDir;
    API.hSI.hScan2D.logFileCounter=1;

    API.acquireAndWait;

    mpsf.tools.reapplyScanImageSettings(API,settings);

    % Report where the file was saved
    mpsf.tools.reportFileSaveLocation(saveDir,fileStem)