function out=generateCSVdata(data_dir)
% Creates machine readable data for html dashboard
%
%

en = mpqc.longitudinal.electrical_noise(data_dir);
if isempty(en)
    return
else
    out.electrical_noise = en.twoSD;
end

pow = mpqc.longitudinal.power(data_dir);
if isempty(pow)
    return
else
    out.maxPower = pow.maxPower;
    out.percentAt100mW = pow.percentAt100mW;
    out.powerDate = pow.date;
end
% out.wavelength = {plotting_template(:).wavelength};

stdLight = mpqc.longitudinal.standard_light_source;
if isempty(stdLight)
    return
else
    out.meanValue = stdLight.meanValue;
    out.stdLightDate = stdLight.date;
end

photons = mpqc.longitudinal.lens_paper;
if isempty(photons)
    return
else
    out.photonsPerPixel = photons.photonsPerPixel;
end


csvData = struct2table(out);
outfile = fullfile(data_dir,'dashboardData.csv');
writetable(csvData,outfile)


function out = generic_generator_template(data_dir)
out.electrical_noise = [];
out.maxPower = [];
out.percentAt100mW = [];


