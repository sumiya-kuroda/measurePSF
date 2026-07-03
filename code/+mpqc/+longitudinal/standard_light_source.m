function varargout = standard_light_source(data_dir,varargin)
% Plots showing mean pixel value recorded from a standard light source over
% time at the maximum gain recorded.
%
% mpqc.longitudinal.standard_light_source(maintenace_folder_path, varargin)
% Optional inputs: Starting date- year-month-day
% mpqc.longitudinal.electrical_noise(maintenace_folder_path, '2024-06-01')
%
% Purpose
% Plots of the mean pixel value of each PMT when recording a standard light
% source. A decrease in pixel value over time suggestuions a deterioration
% of the PMT
%
%
% Outputs
% out (optional) - structure containing key information and data.
%
%
%
%
% Isabell Whiteley, SWC AMF 2025

if nargin<1
    data_dir = pwd;
end


maintenanceFiles = dir(fullfile(data_dir,'**','*.tif'));
n=1;

for ii=1:length(maintenanceFiles)
    tmp = maintenanceFiles(ii);

    if contains(tmp.name,'standard_light_source')
        plotting_template(n) = generic_generator_template(tmp);
        plotting_template(n).type = 'standard_light_source';
        plotting_template(n).plotting_func = @mpqc.plot.standard_light_source;
        plotting_template(n).date = string(datetime(regexp(tmp.name, '(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})','match'),'InputFormat','yyyy-MM-dd_HH-mm-ss'));
        [pathstr,plotting_template(n).name,ext] = fileparts(tmp.name);
        gains = regexp(plotting_template(n).name,'(\d+)[vV]', 'tokens');
        plotting_template(n).gainsUsed = str2double(gains{1}{1});
        n=n+1;
    end
end
if ~exist('plotting_template','var')
    disp('No standard light source files found')
    varargout{1} = [];
    return
end

% sort plotting_template data by the date/time
date_list = [plotting_template.date];
[~,order] = sort(datenum(date_list,'dd-mm-yyyy hh:MM:ss'),1,'ascend');
plotting_template = plotting_template(order);

if any(strcmp(varargin, 'startDate')) % Optional variable for selecting starting date
    idx = find(strcmp(varargin, 'startDate'), 1);  % first match
    startDate = datetime(varargin{idx + 1});
    startIndex = 1;

    while [plotting_template(startIndex).date] < startDate
        startIndex = startIndex + 1;
    end

    plotting_template = plotting_template(startIndex:end);
end


maxGain = max([plotting_template.gainsUsed]);
plotting_template_max = plotting_template([plotting_template.gainsUsed] == maxGain);


for ii = 1:length(plotting_template_max) % each date
    if contains(plotting_template_max(ii).full_path_to_data, '.tif')
        [data,metaData]  = mpqc.tools.scanImage_stackLoad(plotting_template_max(ii).full_path_to_data);
        numChannels = length(metaData.channelSave);

        %save only first frame of each channel
        data = data(:,:,1:numChannels);

        for jj = 1:numChannels % each PMT
            meanValue(jj,ii) = mean(data(:,:,jj),'all'); % (pixelValue,pmt,file)
            % need to put Nan if PMTs are missing. Currently lists 0
        end

    end

end


fig = mpqc.tools.returnFigureHandleForFile(['long_',mfilename]);

plot(meanValue')
xlabels = {plotting_template_max.date};
title('Mean pixel value at max gain')
ylabel('Mean pixel value')
xticks(1:length(xlabels))
xticklabels(xlabels)
legend(metaData.channelName(metaData.channelSave),'Location','NorthWest')

if nargout>0
    out.fileName = {plotting_template(:).name};
    out.meanValue = meanValue;
    out.date ={plotting_template(:).date};
    out.maxDate = {plotting_template_max(:).date};
    varargout{1} = out;
end

end

function out = generic_generator_template(t_dir)
out.full_path_to_data = fullfile(t_dir.folder,t_dir.name);
out.type = [];
out.plotting_func = [];
out.name = [];
out.date = [];
out.gainsUsed = [];
end
