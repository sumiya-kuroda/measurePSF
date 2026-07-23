classdef UniformSlideLive < handle
    % Live updating view of field homogeneity from a uniform slide
    %
    % mpqc.interfaces.UniformSlideLive
    %
    % Purpose
    % Polls ScanImage at regular intervals (once per second by default) and
    % streams the currently displayed image to the uniform slide field
    % homogeneity plot. Use this to explore illumination homogeneity
    % interactively: e.g. set ScanImage to Focus with a rolling average of
    % around 30 frames, start this tool, and adjust the microscope whilst
    % watching the plot.
    %
    % All plotting is done by mpqc.plot.renderer.uniform_slide, which is
    % shared with mpqc.plot.uniform_slide (the offline version that reads
    % saved data from disk). This class only handles pulling data from
    % ScanImage on a timer.
    %
    % Usage
    % >> U = mpqc.interfaces.UniformSlideLive;
    %
    % Stop and restart live updates:
    % >> U.stop
    % >> U.start
    %
    % Change the update interval to 2 seconds:
    % >> U.updateInterval = 2;
    %
    % Close the plot window (or delete the object) to shut down the tool.
    %
    %
    % See also
    % mpqc.plot.uniform_slide, mpqc.plot.renderer.uniform_slide
    %
    % Rob Campbell, SWC AMF

    properties
        updateInterval = 1 % How often to poll ScanImage (seconds)
        displayedChanIndex = 1; %This isn't the channel index! If chans 2 
                                % and 4 are displayed and this is 2 then 
                                % chan 4 is plotted to screen
        overlayZoom = [1.2,2,4] % Which zoom values to overlay as boxes
        crossSections = 'scanner' % 'scanner' or 'diagonal' (see renderer docs)
    end


    properties (Hidden)
        hFig % The figure into which we plot
        hTimer % Timer that polls ScanImage
        API % sibridge.silinker object
        figName = 'UniformSlideLive' % Tag applied to the figure window
    end


    methods

        function obj = UniformSlideLive
            % Connect to ScanImage using the linker class
            obj.API = sibridge.silinker;
            if obj.API.linkSucceeded == false
                delete(obj)
                return
            end

            % Focus an existing live view figure if one exists, otherwise make one
            fig = findobj(0,'Tag',obj.figName);
            if isempty(fig)
                obj.hFig = figure;
                set(obj.hFig, 'Tag', obj.figName, ...
                    'Name', 'Uniform slide live view', ...
                    'NumberTitle', 'off')
            else
                obj.hFig = fig;
                figure(fig)
            end
            obj.hFig.CloseRequestFcn = @obj.windowCloseFcn;
            obj.hTimer = timer('Name', 'UniformSlideLiveTimer', ...
                            'Period', obj.updateInterval, ...
                            'ExecutionMode', 'fixedSpacing', ...
                            'BusyMode', 'drop', ...
                            'TimerFcn', @obj.update);

            % Do a first update right away then begin polling
            obj.update
            obj.start
        end % constructor


        function delete(obj)
            if ~isempty(obj.hTimer) && isvalid(obj.hTimer)
                stop(obj.hTimer)
                delete(obj.hTimer)
            end
            if ~isempty(obj.hFig) && isvalid(obj.hFig)
                delete(obj.hFig)
            end
        end % destructor


        function start(obj)
            % Start live updates
            if strcmp(obj.hTimer.Running,'off')
                start(obj.hTimer)
            end
        end % start


        function stop(obj)
            % Stop live updates
            stop(obj.hTimer)
        end % stop


        function set.updateInterval(obj,interval)
            obj.updateInterval = interval;
            % Apply to the timer, restarting it if it was running
            if isempty(obj.hTimer) || ~isvalid(obj.hTimer)
                return
            end
            wasRunning = strcmp(obj.hTimer.Running,'on');
            stop(obj.hTimer)
            obj.hTimer.Period = interval;
            if wasRunning
                start(obj.hTimer)
            end
        end % set.updateInterval

    end % methods


    methods (Hidden)

        function update(obj,~,~)
            % Pull the current image from ScanImage and render it.
            % Runs on each timer tick. Quietly does nothing if no image is
            % available (e.g. ScanImage is idle).

            if isempty(obj.hFig) || ~isvalid(obj.hFig)
                return
            end

            T = sibridge.getCurrentImage;
            if isempty(T)
                return
            end

            im = T{obj.displayedChanIndex};

            % Query the pixel size each time so zoom changes are handled correctly
            micsPerPixelXY = sibridge.getFOV / obj.API.hSI.hRoiManager.linesPerFrame;

            % Wrap the render in try/catch so a transient error (e.g. a
            % half-formed frame) does not kill the timer
            try
                mpqc.plot.renderer.uniform_slide(im, micsPerPixelXY, obj.hFig, ...
                        'overlayZoom', obj.overlayZoom, ...
                        'crossSections', obj.crossSections);
            catch ME
                fprintf('%s failed to render: %s\n', mfilename, ME.message)
            end
        end % update


        function windowCloseFcn(obj,~,~)
            % Shut down the tool when the user closes the plot window
            delete(obj)
        end % windowCloseFcn

    end % hidden methods

end % classdef
