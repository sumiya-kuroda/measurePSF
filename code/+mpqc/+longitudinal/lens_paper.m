function varargout = lens_paper(data_dir,varargin)
% Longitudinal lens paper plots showing mean photons per pixel over time
%
% mpqc.longitudinal.lens_paper(maintenace_folder_path, varargin)
% Optional inputs: Starting date- year-month-day
% mpqc.longitudinal.lens_paper(maintenace_folder_path, '2024-06-01')
%
% Purpose
%  
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

maintenanceFiles = dir(fullfile(data_dir,'\**\*.tif'));
n=1;

for ii=1:length(maintenanceFiles)
    tmp = maintenanceFiles(ii);

    if contains(tmp.name,'lens_paper')
        plotting_template(n) = generic_generator_template(tmp);
        plotting_template(n).type = 'lens_paper';
        plotting_template(n).plotting_func = @mpqc.plot.lens_paper;
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

    while [plotting_template(startIndex).date] < startDate
        startIndex = startIndex + 1;
    end

    plotting_template = plotting_template(startIndex:end);
end

for ii = 1:length(plotting_template)
    if contains(plotting_template(ii).full_path_to_data, '.tif')
        lensPaper(:,:,:,ii) = mpqc.tools.scanImage_stackLoad(plotting_template(ii).full_path_to_data);
    end
end
a 
end





function out = generic_generator_template(t_dir)
out.full_path_to_data = fullfile(t_dir.folder,t_dir.name);
out.type = [];
out.plotting_func = [];
out.name = [];
out.date = [];
end