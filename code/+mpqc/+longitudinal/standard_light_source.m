function varargout = standard_light_source(data_dir,varargin)
% Plots showing photon count of PMTs over time
%
%
%
%
% Isabell Whiteley, SWC AMF 2025

if nargin<1
    data_dir = pwd;
end


debugPlots = true;

maintenanceFiles = dir(fullfile(data_dir,'\**\*.tif')); 
n=1;

for ii=1:length(maintenanceFiles)
    tmp = maintenanceFiles(ii);

    if contains(tmp.name,'standard_light_source')
        plotting_template(n) = generic_generator_template(tmp);
        plotting_template(n).type = 'standard_light_source';
        plotting_template(n).plotting_func = @mpqc.plot.standard_light_source;
        plotting_template(n).date = string(datetime(regexp(tmp.name, '(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})','match'),'InputFormat','yyyy-MM-dd_HH-mm-ss'));
        [pathstr,plotting_template(n).name,ext] = fileparts(tmp.name);
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

for ii = 1:length(plotting_template)
    if contains(plotting_template(ii).full_path_to_data, '.tif')
        stdLight(:,:,:,ii) = mpqc.tools.scanImage_stackLoad(plotting_template(ii).full_path_to_data); % (x,y,pmt,file)
    end
end

% % TO DO
% Read variables from title
% Check standard light source serial number is same
% Separate by colour
% 
% OR 
% 
% Do we take the photon count analysis only?

disp('done')













end

function out = generic_generator_template(t_dir)
out.full_path_to_data = fullfile(t_dir.folder,t_dir.name);
out.type = [];
out.plotting_func = [];
out.name = [];
out.date = [];
end