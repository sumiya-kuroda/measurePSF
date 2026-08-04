function uniform_slide(fname,varargin)
    % Make nice plots of the uniform slide data to explore illumination
    %
    % mpqc.plot.uniform_slide(fname,'param1','val1','param2','val2',...)
    %
    % Purpose
    % Make a plot of field homogeneity based on a uniform fluorescent slide or solution.
    % Assumes data obtained from ScanImage (ideally at Zoom 1).
    %
    % Loads data from disk and hands off plotting to mpqc.plot.renderer.uniform_slide,
    % which is shared with the live view (mpqc.interfaces.UniformSlideLive).
    %
    % Inputs [required]
    % fname - relative or absolute path to image stack. Brings up a file
    %     picker GUI if no path is supplied.
    %
    % Inputs [optional]
    % overlayZoom - Vector indicating which zoom values to overlay as boxes.
    %               A reasonable selection chosen by default.
    % crossSections - Which directions the image cross-sections should run. 'diagonal' or 'scanner'.
    %              If 'scanner', the lines run through the centre parallel with the scan axes.
    %              This is the default. If 'diagonal' they run from the image corners, which are the
    %              darkest parts of the field of view.
    %
    % Examples
    % Plot with no zoom boxes overlaid
    % mpqc.plot.uniform_slide('uniform_slide_zoom_1_920nm_5mW__2022-08-02_10-09-33_00001.tif','overlayZoom',[])
    %
    %
    % See also
    % mpqc.plot.renderer.uniform_slide, mpqc.interfaces.UniformSlideLive
    %
    % Rob Campbell, SWC AMF


    % bring up a file picker UI if the user did not input a file
    if nargin<1 || isempty(fname)
        [t_file, t_path] = uigetfile('*.tif', 'Select a file');
        if isequal(t_file, 0)
            return
        else
            fname = fullfile(t_path, t_file);
        end
    end

    [imstack,metadata] = mpqc.tools.scanImage_stackLoad(fname);
    if isempty(imstack)
        return
    end

    % Make a new figure or return a plot handle as appropriate
    fig = mpqc.tools.returnFigureHandleForFile([fname,mfilename]);

    % Average all frames and render (the offset has already been subtracted
    % when the data are loaded)
    mpqc.plot.renderer.uniform_slide(mean(imstack,3), ...
                metadata.micsPerPixelXY, fig, varargin{:});
