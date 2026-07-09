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

disp('Searching for electrical noise data')
en = mpqc.longitudinal.electrical_noise(data_dir);
if isempty(en)
    disp('No electrical noise data')
else
    m = size(en.twoSD, 1);
    varNames = ['dates', cellstr("PMT" + (1:m))];
    twoSD = en.twoSD';
    dates = datetime(string([en.date{:}]'), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    datesISO = cellstr(string(dates, "yyyy-MM-dd'T'HH:mm:ss"));
    data = [datesISO, num2cell(twoSD(:, :))];
    dashboardData.metrics.electrical_noise.data = data;
    dashboardData.metrics.electrical_noise.varNames = varNames;
end

disp('Searching for power data')
pow = mpqc.longitudinal.power(data_dir);
if isempty(pow)
    disp('No power data')
else
    % power = table(pow.date', pow.maxPower',pow.percentAt100mW', 'VariableNames',{'Date','MaxPower','PercentAt100mW'});
    varNames = {'Date','MaxPower','PercentAt100mW'};
    dates = datetime(string([pow.date{:}]'), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
    datesISO = cellstr(string(dates, "yyyy-MM-dd'T'HH:mm:ss"));
    power = [datesISO',pow.maxPower,pow.percentAt100mW];
    dashboardData.metrics.power.data = power;
    dashboardData.metrics.power.varNames = varNames;
end
% 
% disp('Searching for standard light source data')
% stdLight = mpqc.longitudinal.standard_light_source(data_dir);
% if isempty(stdLight)
%     disp('No standard light source data')
% else
%     m = size(stdLight.meanValue);
%     varNames = cellstr("Ch" + (1:m));
%     stdLightSource = array2table(stdLight.meanValue', 'VariableNames',varNames);
%     stdLightSource = addvars(stdLightSource,string(stdLight.maxDate(:)),'Before',1,'NewVariableNames','Date');
%     % varNames = ['Date',varNames];
%     % stdLightSource = table(stdLight.maxDate',stdLight.meanValue');%,'VariableNames',varNames);
%     % stdLightSource = splitvars(stdLightSource,'VariableNames',varNames);
%     dashboardData.standard_light_source = stdLightSource;
% end
% 
% disp('Searching for photon counting data')
% photons = mpqc.longitudinal.lens_paper(data_dir,true);
% if isempty(photons)
%     disp('No photon counting data')
% else
%     powerRange = numel(photons.photonsPerPixel);
%     data = cell2mat(cellfun(@(x) x(:), photons.photonsPerPixel, 'UniformOutput', false));
%     photonsPerPixel = array2table(data, 'VariableNames', photons.powerRanges);
%     photonsPerPixel = addvars(photonsPerPixel, datetime([photons.date{:}])', 'Before', 1, 'NewVariableNames', 'Date');
%     dashboardData.photons_perpixel = photonsPerPixel;
% end



outfile = fullfile(data_dir, 'dashboardData5.json');
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
