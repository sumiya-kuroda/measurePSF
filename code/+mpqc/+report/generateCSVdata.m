function out=generateCSVdata(data_dir)
% Creates machine readable data for html dashboard
%
%

% debugging check
maintenanceFiles = [dir(fullfile(data_dir,'\**\*.tif')) ; dir(fullfile(data_dir,'\**\*.mat'))];

en = mpqc.longitudinal.electrical_noise(data_dir);
if isempty(en)
    disp('No electrical noise data')
else
    out.electrical_noise = en.twoSD;
    out.enDate = en.date;
end

pow = mpqc.longitudinal.power(data_dir);
if isempty(pow)
    disp('No power data')
else
    out.maxPower = pow.maxPower;
    out.percentAt100mW = pow.percentAt100mW;
    out.powerDate = pow.date;
end
% out.wavelength = {plotting_template(:).wavelength};

stdLight = mpqc.longitudinal.standard_light_source(data_dir);
if isempty(stdLight)
    disp('No standard light source data')
else
    out.meanValue = stdLight.meanValue;
    out.stdLightDate = stdLight.date;
end

photons = mpqc.longitudinal.lens_paper(data_dir);
if isempty(photons)
    disp('No photon counting data')
else
    out.photonsPerPixel = photons.photonsPerPixel;
end


csvData = struct2table(out,'AsArray',true);
csvData = rows2vars(splitvars(csvData));
outfile = fullfile(data_dir,'dashboardData.csv');
writetable(csvData,outfile)


% function out = generic_generator_template(data_dir)
% out.electrical_noise = [];
% out.maxPower = [];
% out.percentAt100mW = [];


