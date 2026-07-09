function varargout = power(data_dir,varargin)
% Function to track the changes in laser power over time
%
% mpqc.longitudinal.power(maintenance_folder_path, varargin)
%
% Optional inputs:
% 'startDate', 'year-month-day'
%  mpqc.longitudinal.power(maintennace_folder_path,'startDate','2024-06-01')
% 'wavelength', value
%  mpqc.longitudinal.power(maintenance_folder_path,'wavelength',800)
%
% Purpose
% Plots the power at the objective from 0-100% and compares maximum output
% power over time. Used to monitor the health of a laser
%
%
% Outputs
% out (optional) - structure containing key information and data.
%
%
%
% Isabell Whiteley, SWC AMF 2026

if nargin<1
    data_dir = pwd;
end

maintenanceFiles = dir(fullfile(data_dir,'**','*.mat'));
n=1;

for ii=1:length(maintenanceFiles)
    tmp = maintenanceFiles(ii);

    if contains(tmp.name,'power')
        plotting_template(n).full_path_to_data = fullfile(tmp.folder,tmp.name);
        plotting_template(n).type = 'power';
        plotting_template(n).plotting_func = @mpqc.plot.power;
        plotting_template(n).date = string(datetime(regexp(tmp.name, '(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})','match'),'InputFormat','yyyy-MM-dd_HH-mm-ss'));
        plotting_template(n).wavelength = str2num(cell2mat(regexp(tmp.name,'\d*(?=nm)','match')));
        [pathstr,plotting_template(n).name,ext] = fileparts(tmp.name);
        n=n+1;
    end
end
if ~exist('plotting_template','var')
    disp('No power measurement files found')
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

    while [plotting_template(startIndex).date] < startDate && startIndex <= numel(plotting_template)
        startIndex = startIndex + 1;
    end

    plotting_template = plotting_template(startIndex:end);
end

% If only one wavelength is measured
if isequal(plotting_template(:).wavelength)
    fig = mpqc.tools.returnFigureHandleForFile(['long_',mfilename]);
    for ii = 1:length(plotting_template)
        if contains(plotting_template(ii).full_path_to_data, '.mat')
            % If power data is found, load it and find max value
            powerData(ii) = load(plotting_template(ii).full_path_to_data);
            power = mean(powerData(ii).powerMeasurements.observedPower_mW');
            maxPower(ii) = power(end); %  data is 11x4 and it only takes the final value rather than the average value
            percentAt100mW(ii) = interp1(power,powerData(ii).powerMeasurements.powerSeriesPercent,100);

            % Plot the power curves for each date
            hold on
            subplot(3,1,1)
            plot(linspace(0,100,length(powerData(ii).powerMeasurements.observedPower_mW)),mean(powerData(ii).powerMeasurements.observedPower_mW,2),'.')
            legend(plotting_template.date,'location', 'Northwest')
            title(cell2mat(['Power at ', string(plotting_template(1).wavelength), 'nm']))
            xlabel('Percent power')
            ylabel('Power (mW)')
            hold off
        end
    end
    % Plot the maximum laser output over time
    subplot(3,1,2)
    plot(maxPower, '-*')
    title('Maximum laser power')
    xlabels = {plotting_template.date};
    xticks(1:length(xlabels))
    xticklabels(xlabels)
    ylabel('Maximum power (mW)')

    subplot(3,1,3)
    plot(percentAt100mW)
    title('Percent power at 100mW')
    xlabels = {plotting_template.date};
    xticks(1:length(xlabels))
    xticklabels(xlabels)
    ylabel('Percent power')

% If you only want to plot one measured wavelength, specified in varargin
elseif  any(strcmp(varargin, 'wavelength'))
    
    fig = mpqc.tools.returnFigureHandleForFile(['long_',mfilename]);
    idx = find(strcmp(varargin, 'wavelength'), 1);
    wavelength = varargin{idx + 1};
    a = 0;
    for ii = 1:length(plotting_template)

        if contains(plotting_template(ii).full_path_to_data, '.mat') && isequal(plotting_template(ii).wavelength,wavelength)
            a=a+1;
            powerData(a) = load(plotting_template(ii).full_path_to_data);
            power = mean(powerData(a).powerMeasurements.observedPower_mW');
            maxPower(a) = power(end);
            waveDate(a) = plotting_template(ii).date;
            percentAt100mW(a) = interp1(power,powerData(a).powerMeasurements.powerSeriesPercent,100);



            hold on
            subplot(3,1,1)
            plot(linspace(0,100,length(powerData(a).powerMeasurements.observedPower_mW)),mean(powerData(a).powerMeasurements.observedPower_mW,2),'.')
            legend(waveDate(:),'location', 'Northwest')
            title(cell2mat(['Power at ', string(wavelength), 'nm']))
            xlabel('Percent power')
            ylabel('Power (mW)')
            hold off

        end

    end

    if ~exist('powerData', 'var')
        disp('No measurements found for provided wavelength')
    end

    if exist('maxPower','var') % Only plots is varargin wavelength is present
        subplot(3,1,2)
        plot(maxPower, '-*')
        title('Maximum laser power')
        xlabels = waveDate(:);
        xticks(1:length(xlabels))
        xticklabels(xlabels)
        ylabel('Maximum power (mW)')

        subplot(3,1,3)
        plot(percentAt100mW)
        title('Percent power at 100mW')
        xlabels = {plotting_template.date};
        xticks(1:length(xlabels))
        xticklabels(xlabels)
        ylabel('Percent power')
    end

% If multiple wavelengths have been recorded
else

    fig = mpqc.tools.returnFigureHandleForFile(['long_',mfilename]);

    for i = 1:length(plotting_template)
        allWave(i) = plotting_template(i).wavelength;
    end
    wavelengthVals = unique(allWave);
    numWavelength = length(wavelengthVals);

    for jj = 1:numWavelength
        fig(jj) = mpqc.tools.returnFigureHandleForFile(sprintf('%s_%d', mfilename,jj));

        a=0;
        for ii = 1:length(plotting_template)

            if contains(plotting_template(ii).full_path_to_data, '.mat') && isequal(plotting_template(ii).wavelength,wavelengthVals(jj))
                % If power data is found, load it and find max value
                a=a+1;
                powerData(a,jj) = load(plotting_template(ii).full_path_to_data);
                power = mean(powerData(a,jj).powerMeasurements.observedPower_mW');
                maxPower(a,jj) = power(end);
                waveDate(a,jj) = plotting_template(ii).date;
                percentAt100mW(a,jj) = interp1(power,powerData(a,jj).powerMeasurements.powerSeriesPercent,100);


                hold on
                subplot(3,1,1)
                plot(linspace(0,100,length(powerData(a,jj).powerMeasurements.observedPower_mW)),mean(powerData(a,jj).powerMeasurements.observedPower_mW,2),'.')
                legend(waveDate(:,jj),'location', 'Northwest')
                title(cell2mat(['Power at ', string(wavelengthVals(jj)), 'nm']))
                xlabel('Percent power')
                ylabel('Power (mW)')
                hold off
            end
        end
        subplot(3,1,2)
        plot(maxPower(:,jj), '-*')
        title('Maximum laser power')
        xlabels = waveDate(:,jj);
        xticks(1:length(xlabels))
        xticklabels(xlabels)
        ylabel('Maximum power (mW)')

        subplot(3,1,3)
        plot(percentAt100mW(:,jj))
        title('Percent power at 100mW')
        xlabels = {plotting_template.date};
        xticks(1:length(xlabels))
        xticklabels(xlabels)
        ylabel('Percent power')
    end
end


% Output of the main function
if nargout>0
    out.fileName = {plotting_template(:).name};
    out.date ={plotting_template(:).date};
    out.powerData = powerData;
    out.maxPower = maxPower;
    out.percentAt100mW = percentAt100mW;
    out.wavelength = {plotting_template(:).wavelength};
    varargout{1} = out;
end

end
