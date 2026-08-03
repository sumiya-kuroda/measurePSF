function generateDashboardData(data_dir)
% Creates machine readable data for html dashboard
%
% mpqc.report.generateDashboardData(maintenance_folder_path)
%
% Purpose
% Outputs files for longitudinal tracking of power, electrical noise, standard light
% source data, and photon counting from lens paper data. These files will be used to
% generate files for an HTML dashboard
%
%
% Isabell Whiteley, SWC AMF 2026


% Note what figures are open by user
figsBefore = findall(groot,'Type','figure');

dashboardData = struct();

% Placeholder for yaml info
dashboardData.system = [];

% Data section
dashboardData.metrics = [];

% Electrical noise
disp('Searching for electrical noise data')
en = mpqc.longitudinal.electrical_noise(data_dir);
if isempty(en)
    disp('No electrical noise data')
else
    m = size(en.twoSD, 1);
    varNames = ['date', cellstr("PMT" + (1:m))];
    twoSD = en.twoSD';
    dates = datetime(string([en.date{:}]'), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    datesISO = cellstr(string(dates, "yyyy-MM-dd'T'HH:mm:ss"));
    n = numel(datesISO);
    data = cell(n, 1);
    for ii = 1:n
        data{ii} = [{datesISO{ii}}, num2cell(twoSD(ii, :))];
    end
    dashboardData.metrics.electrical_noise.data = data;
    dashboardData.metrics.electrical_noise.varNames = varNames;
    dashboardData.metrics.electrical_noise.label = 'Electrical Noise';
    dashboardData.metrics.electrical_noise.units = 'pixel value';
end

% Power
disp('Searching for power data')
pow = mpqc.longitudinal.power(data_dir);
if isempty(pow)
    disp('No power data')
else
   % TO DO add in wavelength
    varNames = {'date','MaxPower','PercentAt100mW'};
    dates = datetime(string([pow.date{:}]'), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    datesISO = cellstr(string(dates, "yyyy-MM-dd'T'HH:mm:ss"));
    n = numel(datesISO);
    power = cell(n, 1);
    for ii = 1:n
        power{ii} = {datesISO{ii}, pow.maxPower(ii), pow.percentAt100mW(ii)};
    end
    dashboardData.metrics.power.data = power;
    dashboardData.metrics.power.varNames = varNames;
    dashboardData.metrics.power.label = 'Laser Power';
    dashboardData.metrics.power.units = 'mW';
end

% Standard light source
disp('Searching for standard light source data')
stdLight = mpqc.longitudinal.standard_light_source(data_dir);
if isempty(stdLight)
    disp('No standard light source data')
else
    m = size(stdLight.meanValue, 1);
    varNames = ["date", "ch" + string(1:m)];
    dates = datetime(string([stdLight.maxDate{:}]'), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    datesISO = cellstr(string(dates, "yyyy-MM-dd'T'HH:mm:ss"));
    n = numel(datesISO);
    stdLightData = cell(n, 1);
    for ii = 1:n
        stdLightData{ii} = [{datesISO{ii}}, num2cell(stdLight.meanValue(:, ii)')];
    end
    % dashboardData.metrics.standardLight.label = 'Standard Light Source';
    dashboardData.metrics.standardLight.data = stdLightData;
    dashboardData.metrics.standardLight.varNames = varNames;  
    dashboardData.metrics.standardLight.label = 'Standard Light Source';
    dashboardData.metrics.standardLight.units = 'mean pixel value';
end

% Lens paper photons per pixel
disp('Searching for photon counting data')
photons = mpqc.longitudinal.lens_paper(data_dir,'skipStandardSource',true);
if isempty(photons)
    disp('No photon counting data')
else
    varNames = ['date',photons.powerRanges];
    dates = datetime(string([photons.date{:}]'), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    datesISO = cellstr(string(dates, "yyyy-MM-dd'T'HH:mm:ss"));
    n = numel(datesISO);
    photonsPerPixel = cell(n, 1);
    for ii = 1:n
        values = cellfun(@(x) x(ii), photons.photonsPerPixel);
        photonsPerPixel{ii} = [{datesISO{ii}}, num2cell(values)];
    end
    dashboardData.metrics.photonsPerPixel.data = photonsPerPixel;
    dashboardData.metrics.photonsPerPixel.varNames = varNames;
    dashboardData.metrics.photonsPerPixel.label = 'Photons per pixel';
    dashboardData.metrics.photonsPerPixel.units = 'photons/pixel';
end



outfile = fullfile(data_dir, 'longitudinalDashboardData.json');
fid = fopen(outfile, 'w');
if fid == -1
    error('mpqc:report:generateDashboardData:FileOpenFailed', ...
        'Could not open %s for writing.', outfile);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(dashboardData,PrettyPrint=true));
clear cleanup

% closes any figures opened by code
figsAfter = findall(groot,'Type','figure');
newFigs = setdiff(figsAfter, figsBefore);
delete(newFigs)
