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

disp('Searching for electrical noise data')
en = mpqc.longitudinal.electrical_noise(data_dir);
if isempty(en)
    disp('No electrical noise data')
else
    m = size(en.twoSD, 1);
    varNames = cellstr("PMT" + (1:m));
    electrical_noise = array2table(en.twoSD',  'VariableNames', varNames);
    electrical_noise = addvars(electrical_noise, string(en.date(:)),'Before', 1,'NewVariableNames', 'Date');
    dashboardData.electrical_noise = table2struct(electrical_noise);
end

disp('Searching for power data')
pow = mpqc.longitudinal.power(data_dir);
if isempty(pow)
    disp('No power data')
else
    power = table(pow.date', pow.maxPower',pow.percentAt100mW', 'VariableNames',{'Date','MaxPower','PercentAt100mW'});
    dashboardData.power = table2struct(power);
end

disp('Searching for standard light source data')
stdLight = mpqc.longitudinal.standard_light_source(data_dir);
if isempty(stdLight)
    disp('No standard light source data')
else
    stdLightSource = table(stdLight.maxDate',stdLight.meanValue');
    dashboardData.standard_light_source = table2struct(stdLightSource);
end

disp('Searching for photon counting data')
photons = mpqc.longitudinal.lens_paper(data_dir,true);
if isempty(photons)
    disp('No photon counting data')
else
    powerRange = numel(photons.photonsPerPixel);
    data = cell2mat(cellfun(@(x) x(:), photons.photonsPerPixel, 'UniformOutput', false));
    photonsPerPixel = array2table(data, 'VariableNames', photons.powerRanges);
    photonsPerPixel = addvars(photonsPerPixel, datetime([photons.date{:}])', 'Before', 1, 'NewVariableNames', 'Date');
    dashboardData.photons_perpixel = table2struct(photonsPerPixel);
end

outfile = fullfile(data_dir, 'dashboardData.json');
fid = fopen(outfile, 'w');
if fid == -1
    error('mpqc:report:generateDashboardData:FileOpenFailed', ...
        'Could not open %s for writing.', outfile);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(dashboardData), 'char');
clear cleanup

% closes any figures opened by code
figsAfter = findall(groot,'Type','figure');
newFigs = setdiff(figsAfter, figsBefore);
delete(newFigs)


