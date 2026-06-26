function generateCSVdata(data_dir)
% Creates machine readable data for html dashboard
%
% mpqc.report.generateCSVdata(maintenance_folder_path)
%
% Purpose-  outputs CSV files for longitudinal tracking of power,
% electrical noise, standard light source data, and photon counting from
% lens paper data
% Will be used to generate files for an HTML dashboard
%
%
% Isabell Whiteley, SWC AMF 2026

% debugging check
maintenanceFiles = [dir(fullfile(data_dir,'\**\*.tif')) ; dir(fullfile(data_dir,'\**\*.mat'))];

% Note what figures are open by user
figsBefore = findall(groot,'Type','figure');

disp('Searching for electrical noise data')
en = mpqc.longitudinal.electrical_noise(data_dir);
if isempty(en)
    disp('No electrical noise data')
else
    m = size(en.twoSD, 1);
    varNames = cellstr("PMT" + (1:m));
    electrical_noise = array2table(en.twoSD',  'VariableNames', varNames);
    electrical_noise = addvars(electrical_noise, string(en.date(:)),'Before', 1,'NewVariableNames', 'Date');
    outfile = fullfile(data_dir, 'electrical_noise_dashboard.csv');
    writetable(electrical_noise, outfile);
end

disp('Searching for power data')
pow = mpqc.longitudinal.power(data_dir);
if isempty(pow)
    disp('No power data')
else
    power = table(pow.date', pow.maxPower',pow.percentAt100mW', 'VariableNames',{'Date','MaxPower','PercentAt100mW'});
    outfile = fullfile(data_dir, 'power_dashboard.csv');
    writetable(power, outfile);
end

disp('Searching for standard light source data')
stdLight = mpqc.longitudinal.standard_light_source(data_dir);
if isempty(stdLight)
    disp('No standard light source data')
else
    stdLightSource = table(stdLight.maxDate',stdLight.meanValue');
    outfile = fullfile(data_dir, 'standard_light_dashboard.csv');
    writetable(stdLightSource, outfile);
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
    outfile = fullfile(data_dir, 'photons_perpixel_dashboard.csv');
    writetable(photonsPerPixel, outfile);
end

% closes any figures opened by code
figsAfter = findall(groot,'Type','figure');
newFigs = setdiff(figsAfter, figsBefore);
delete(newFigs)


