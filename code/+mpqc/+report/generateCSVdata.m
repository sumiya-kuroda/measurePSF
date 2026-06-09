function out=generateCSVdata(data_dir)
% Creates machine readable data for html dashboard
%
%

en = mpqc.longitudinal.electrical_noise(data_dir);
out.electrical_noise = en.twoSD;

pow = mpqc.longitudinal.power(data_dir);
out.maxPower = pow.maxPower;
out.percentAt100mW = pow.percentAt100mW;
% out.wavelength = {plotting_template(:).wavelength};

% stdLight = mpqc.longitudinal.standard_light_source;
% out.


function out = generic_generator_template(data_dir)
out.electrical_noise = [];
out.maxPower = [];
out.percentAt100mW = [];


% if nargin<1
%     data_dir = pwd;
% end
% maintenanceFiles = [
%     dir(fullfile(data_dir, '**', '*.tif'));
%     dir(fullfile(data_dir, '**', '*.mat'))
% ];
% n=1;
% standard_light_done = false;
% 
% % Searches for the files
% for ii = 1:length(maintenanceFiles)
%     tmp = maintenanceFiles(ii);
% 
%     if contains(tmp.name,'.tif') || contains(tmp.name,'.mat')
%         if contains(tmp.name,'electrical_noise')
%             out(n) = generic_generator_template(tmp);
%             out(n).type = 'electrical_noise';
%             out(n).plotting_func = @mpqc.longitudinal.electrical_noise;
%             out(n).date = tmp.date;
%             n=n+1;
% 
%         elseif contains(tmp.name,'lens_paper_')
%             out(n) = generic_generator_template(tmp);
%             out(n).type = 'lens_paper';
%             out(n).plotting_func = @mpqc.longitudinal.lens_paper;
%             out(n).date = tmp.date;
%             n=n+1;
% 
%         elseif contains(tmp.name,'standard_light_source') && ~standard_light_done
%             out(n) = generic_generator_template(tmp);
%             out(n).type = 'standard_light_source';
%             out(n).plotting_func = @mpqc.longitudinal.standard_light_source;
%             out(n).data_dir = maintenanceFiles(ii).folder;
%             out(n).date = tmp.date;
%             n=n+1;
% 
%         elseif contains(tmp.name,'power')
%             out(n) = generic_generator_template(tmp);
%             out(n).type = 'power';
%             out(n).plotting_func = @mpqc.longitudinal.power;
%             out(n).date = tmp.date;
%             n=n+1;
%         end
%     end
% 
%     if ~exist('out','var')
%         fprintf('No data found in directory %s\n', data_dir)
%         out = [];
%     end
% end
% 
% % Runs the functions
% f=find(strcmp({out.type},'electrical_noise'));
%     if ~isempty(f)
%         for ii=1:length(f)
%             data = out(f(ii)).plotting_func(out(f(ii)).full_path_to_data);
%             electrical_noise = data.twoSD ;
%         end  
%     end
% 
% % Internal functions follow
% function out = generic_generator_template(t_dir)
% out.full_path_to_data = fullfile(t_dir.folder);
% out.type = [];
% out.plotting_func = [];
% out.laser_wavelength = mpqc.report.laser_wavelength_from_fname(t_dir.name); %get laser wavelength
% out.laser_power = mpqc.report.laser_power_from_fname(t_dir.name); %get laser power
% out.data_dir = []; %for standard light source
% out.date = [];