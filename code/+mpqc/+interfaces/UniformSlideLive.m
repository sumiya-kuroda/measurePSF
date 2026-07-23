classdef UniformSlideLive < handle
    % Live updating view of field homogeneity from a uniform slide
    %
    % mpqc.interfaces.UniformSlideLive
    %
    % Purpose
    % Streams the currently displayed ScanImage image to the uniform slide
    % field homogeneity plot. Use this to explore illumination homogeneity
    % interactively: e.g. set ScanImage to Focus with a rolling average of
    % around 30 frames, start this tool, and adjust the microscope whilst
    % watching the plot.
    %
    % Updates are driven by ScanImage's frameAcquired event (no timers, see
    % mpqc.tools.meanFrame for the same pattern). The frame rate is read
    % from ScanImage and frames are skipped so the plot refreshes about
    % updatesPerSecond times a second. How quickly each refresh renders
    % depends on the image size in ScanImage: smaller is faster.
    %
    % All plotting is done by mpqc.plot.renderer.uniform_slide, which is
    % shared with mpqc.plot.uniform_slide (the offline version that reads
    % saved data from disk). This class only handles pulling data from
    % ScanImage as frames arrive.
    %
    % Usage
    % >> U = mpqc.interfaces.UniformSlideLive;
    %
    % Stop and restart live updates:
    % >> U.stop
    % >> U.start
    %
    % Refresh once a second instead of twice:
    % >> U.updatesPerSecond = 1;
    %
    % Close the plot window (or delete the object) to shut down the tool.
    %
    %
    % See also
    % mpqc.plot.uniform_slide, mpqc.plot.renderer.uniform_slide, mpqc.tools.meanFrame
    %
    % Rob Campbell, SWC AMF

    properties
        updatesPerSecond = 2 % Target number of plot refreshes per second
        displayedChanIndex = 1; %This isn't the channel index! If chans 2
                                % and 4 are displayed and this is 2 then
                                % chan 4 is plotted to screen
        overlayZoom = [1.2,2,4] % Which zoom values to overlay as boxes
        crossSections = 'scanner' % 'scanner' or 'diagonal' (see renderer docs)
    end


    properties (Hidden)
        hFig % The figure into which we plot
        API % sibridge.silinker object
        listener_frameAcquired % Fires on each acquired frame
        frameCounter = 0 % Counts acquired frames so we know when to refresh
        renderInProgress = false % Guard so a slow render cannot re-enter itself
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

            % Render right away from the last frame in the ScanImage buffer,
            % which will be there if any image was previously taken
            obj.renderCurrentImage

            % Then update the plot as frames arrive (throttled in obj.update)
            obj.listener_frameAcquired = ...
                addlistener(obj.API.hSI.hUserFunctions, 'frameAcquired', @obj.update);
        end % constructor


        function delete(obj)
            delete(obj.listener_frameAcquired)
            if ~isempty(obj.hFig) && isvalid(obj.hFig)
                delete(obj.hFig)
            end
        end % destructor


        function start(obj)
            % Start live updates
            obj.listener_frameAcquired.Enabled = true;
        end % start


        function stop(obj)
            % Stop live updates
            obj.listener_frameAcquired.Enabled = false;
        end % stop

    end % methods


    methods (Hidden)

        function update(obj,~,~)
            % Runs on each acquired frame. Renders the current image about
            % updatesPerSecond times a second, skipping frames in between.

            if isempty(obj.hFig) || ~isvalid(obj.hFig)
                return
            end

            % Do nothing if a previous render is still going: the drawnow
            % below processes the event queue, so without this guard queued
            % frameAcquired events would re-enter this callback and pile up.
            if obj.renderInProgress
                return
            end

            % Read the frame rate from ScanImage and refresh the plot only
            % every n frames
            framePeriod = obj.API.hSI.hRoiManager.scanFramePeriod;
            framesPerUpdate = max(1, round(1 / (obj.updatesPerSecond*framePeriod)));

            obj.frameCounter = obj.frameCounter + 1;
            if mod(obj.frameCounter, framesPerUpdate) ~= 0
                return
            end

            obj.renderCurrentImage
        end % update


        function renderCurrentImage(obj)
            % Pull the current image from the ScanImage buffer and render it.
            % Quietly does nothing if no image is available (e.g. ScanImage
            % has never acquired anything).

            T = sibridge.getCurrentImage;
            if isempty(T)
                return
            end

            im = T{obj.displayedChanIndex};

            % Query the pixel size each time so zoom changes are handled correctly
            micsPerPixelXY = sibridge.getFOV / obj.API.hSI.hRoiManager.linesPerFrame;

            % Wrap the render in try/catch so a transient error (e.g. a
            % half-formed frame) does not disable the listener, and so the
            % renderInProgress flag is always cleared
            obj.renderInProgress = true;
            try
                mpqc.plot.renderer.uniform_slide(im, micsPerPixelXY, obj.hFig, ...
                        'overlayZoom', obj.overlayZoom, ...
                        'crossSections', obj.crossSections);
                drawnow('limitrate')
            catch ME
                fprintf('%s failed to render: %s\n', mfilename, ME.message)
            end
            obj.renderInProgress = false;
        end % renderCurrentImage


        function windowCloseFcn(obj,~,~)
            % Shut down the tool when the user closes the plot window
            delete(obj)
        end % windowCloseFcn

    end % hidden methods

end % classdef
