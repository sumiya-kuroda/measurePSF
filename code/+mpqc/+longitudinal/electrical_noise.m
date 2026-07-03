function varargout = electrical_noise(data_dir,varargin)
% Longitudinal electrical noise plots showing FWHM and max values over time
%
% mpqc.longitudinal.electrical_noise(maintenace_folder_path, varargin)
% Optional inputs: Starting date- year-month-day
% mpqc.longitudinal.electrical_noise(maintenace_folder_path, '2024-06-01')
%
% Purpose
% Plots of the pixel value at two standard deviations of electrical noise for each channel
% with PMTs off. If there is significant change in electrical noise, the
% pixel value will increase.
%
%
% Outputs
% out (optional) - structure containing key information and data.
%
%
% Isabell Whiteley, SWC AMF 2025

if nargin<1
    data_dir = pwd;
end


debugPlots = false;

maintenanceFiles = dir(fullfile(data_dir,'**','*.tif'));
n=1;

for ii=1:length(maintenanceFiles)
    tmp = maintenanceFiles(ii);

    if contains(tmp.name,'electrical_noise')
        plotting_template(n) = generic_generator_template(tmp);
        plotting_template(n).type = 'electrical_noise';
        plotting_template(n).plotting_func = @mpqc.plot.electrical_noise;
        plotting_template(n).date = string(datetime(regexp(tmp.name, '(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})','match'),'InputFormat','yyyy-MM-dd_HH-mm-ss'));
        [pathstr,plotting_template(n).name,ext] = fileparts(tmp.name);
        n=n+1;
    end
end
if ~exist('plotting_template','var')
    disp('No electrical noise files found')
    varargout{1} = [];
    return
end

% sort plotting_template data by the date/time
date_list = [plotting_template.date];
[~,order] = sort(datenum(date_list,'dd-mm-yyyy hh:MM:ss'),1,'ascend');
plotting_template = plotting_template(order);

if nargin > 1 % Optional variable for selecting starting date
    startDate = datetime(varargin{1});
    startIndex = 1;

    while [plotting_template(startIndex).date] < startDate && startIndex <= numel(plotting_template)
        startIndex = startIndex + 1;
    end

    plotting_template = plotting_template(startIndex:end);
end

for ii = 1:length(plotting_template)
    if contains(plotting_template(ii).full_path_to_data, '.tif')
        noiseData(:,:,:,ii) = mpqc.tools.scanImage_stackLoad(plotting_template(ii).full_path_to_data);
    end
end

noiseData = single(noiseData);

for q = 1:size(noiseData,4) % each date

    if debugPlots
        fig = mpqc.tools.returnFigureHandleForFile(sprintf('%s_%02d',mfilename,q));
    end

    for t = 1:size(noiseData,3) % each PMT

        % Extract data
        t_im = noiseData(:,:,t,q);

        maxVal(t,q) = max(t_im(:));
        meanVal(t,q) = mean(t_im(:));
        im_2SD(t,q) = std(t_im(:))*2;

        % Optionally plot
        if debugPlots
            subplot(2,2,t)
            a=area(n);
            a.EdgeColor=[0,0,0.75];
            a.FaceColor=[0.5,0.5,1];
            a.LineWidth=2;
            hold on
            b = plot(m);
            b.LineWidth = 2;
            sgtitle(plotting_template(q).date)
            title(['PMT # ',num2str(t)])
            hold off
        end
    end
end

fig = mpqc.tools.returnFigureHandleForFile(sprintf('%s_%02d',mfilename,ii));
xlabels = {plotting_template.date};

hold on
for ii = 1:size(noiseData,3)
    plot(im_2SD(ii,:),  'DisplayName', sprintf('PMT %d', ii))
end

hold off
xticks(1:length(xlabels))
xticklabels(xlabels)
title('Two SD')
ylabel('Pixel value')
legend


% Output of the main function
if nargout>0
    out.fileName = {plotting_template(:).name};
    out.noiseData = noiseData;
    out.twoSD = im_2SD;
    out.maxValues = maxVal;
    out.date ={plotting_template(:).date};
    varargout{1} = out;
end

end % close main funtion



function out = generic_generator_template(t_dir)
    out.full_path_to_data = fullfile(t_dir.folder,t_dir.name);
    out.type = [];
    out.plotting_func = [];
    out.name = [];
    out.date = [];
end
