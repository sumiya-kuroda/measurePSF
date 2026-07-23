function uniform_slide(im,micsPerPixelXY,hFig,varargin)
    % Render the uniform slide field homogeneity plots into a figure
    %
    % mpqc.plot.renderer.uniform_slide(im,micsPerPixelXY,hFig,'param1','val1',...)
    %
    % Purpose
    % Does the actual plotting of field homogeneity from a uniform fluorescent
    % slide image. This renderer is shared by mpqc.plot.uniform_slide, which
    % feeds it data from a saved TIFF, and mpqc.interfaces.UniformSlideLive,
    % which feeds it live data from ScanImage. It contains no data loading or
    % acquisition logic: it just draws.
    %
    % The figure is cleared and re-drawn on each call, so it is safe to call
    % repeatedly on the same figure to produce a live updating view. The
    % figure is drawn to without stealing focus.
    %
    % Inputs [required]
    % im - 2D image of the uniform slide (frames already averaged).
    % micsPerPixelXY - number of microns per pixel in X/Y.
    % hFig - handle of the figure to draw into.
    %
    % Inputs [optional param/val pairs]
    % overlayZoom - Vector indicating which zoom values to overlay as boxes.
    %               A reasonable selection chosen by default.
    % crossSections - Which directions the image cross-sections should run. 'diagonal' or 'scanner'.
    %              If 'scanner', the lines run through the centre parallel with the scan axes.
    %              This is the default. If 'diagonal' they run from the image corners, which are the
    %              darkest parts of the field of view.
    %
    % Outputs
    % none
    %
    % See also
    % mpqc.plot.uniform_slide, mpqc.interfaces.UniformSlideLive
    %
    % Rob Campbell, SWC AMF


    %Parse optional arguments
    params = inputParser;
    params.CaseSensitive = false;
    params.addParamValue('overlayZoom', [1.2,2,4], @(x) isnumeric(x) && isscalar(x) || isvector(x) || isempty(x));
    params.addParamValue('crossSections', 'scanner', @(x) isstr(x) && (strcmpi(x,'scanner') || strcmpi(x,'diagonal')));
    params.parse(varargin{:});

    overlayZoom = params.Results.overlayZoom;
    crossSections = params.Results.crossSections;


    % Make the target figure current without stealing focus, then wipe it
    set(0,'CurrentFigure',hFig)
    clf(hFig)

    subplot(1,2,1)
    plotData = double(im);

    % Smooth it a bit before plotting. Contours and cross sections are further
    % smoothed on top of this (see below).
    % The imresize along rows removes artifacts caused by amplifier ringing
    plotData = imresize(plotData,[round(size(plotData,1)*0.75), size(plotData,2)]);
    plotData = imresize(plotData,size(im));
    fSize=round(size(plotData,1)/10);
    plotData = medfilt2(plotData,[fSize,fSize],'symmetric'); %filter heavily

    % Normalise (any offset in the data is removed here)
    plotData = plotData-min(plotData(:));
    plotData = plotData/max(plotData(:));



    imagesc(plotData)
    axis equal tight
    colormap gray

    mpqc.tools.add_scale_axis_tick_labels(gca,micsPerPixelXY)

    hold on
    nContours = 10;
    contour(plotData, 0:1/nContours:1, 'Color', [0.95,0.95,1], 'linewidth', 1)
    color_tmp = gray(nContours);
    colormap(color_tmp)


    % Add diagonal lines which we will use later to associate with the next plot
    switch crossSections
        case 'diagonal'
            plot([1,size(plotData,1)], [1,size(plotData,2)], '-r', 'linewidth',2)
            plot([1,size(plotData,1)], [size(plotData,2),1], '-c', 'linewidth',2)
        case 'scanner'
            plot([1,size(plotData,1)], [size(plotData,2)/2,size(plotData,2)/2], '-r', 'linewidth',2) %Y
            plot([size(plotData,2)/2,size(plotData,2)/2], [1,size(plotData,1)], '-c', 'linewidth',2) %X
    end


    % Diagnostic/extra information feature: show boxes indicating the FOV
    % at different zooms.
    if ~isempty(overlayZoom)

        zoom_cols = parula(length(overlayZoom));

        for ii=1:length(overlayZoom)
            L=length(im);
            newSize = L/overlayZoom(ii);
            offset = (L-newSize)/2;
            r(ii) = rectangle('Position', [offset,offset,newSize,newSize], ...
                                'EdgeColor', zoom_cols(ii,:));
            text_zoom(ii) = text(offset+1,offset+4, ...
                            sprintf('Zoom %0.1f', overlayZoom(ii)), ...
                            'Color', zoom_cols(ii,:), ...
                            'FontSize',12, ...
                            'FontWeight','Bold');
        end

    end

    hold off
    set(gca,'FontSize',12)


    % Plot intensity cross-sections along the red/cyan lines
    subplot(1,2,2)

    switch crossSections
        case 'diagonal'
            micsPerDataPoint = sqrt(2*micsPerPixelXY^2);

            f_diag = eye(length(plotData));
            yData = plotData(find(f_diag));
            xData = (1:length(yData)) * micsPerDataPoint;
            xData = xData - mean(xData);

            hXsection1 = plot(xData,yData,'-r','linewidth',2);

            hold on

            yData = plotData(find(rot90(f_diag)));

            hXsection2 = plot(xData,yData,'-c','linewidth',2);

        case 'scanner'
            micsPerDataPoint = micsPerPixelXY;

            xSectionX = plotData(:, round(size(plotData,2)/2));
            xSectionY = plotData(round(size(plotData,2)/2),:);

            xData = (1:length(xSectionY)) * micsPerDataPoint;
            xData = xData - mean(xData);
            hXsection1 = plot(xData,xSectionY,'-r','linewidth',2);
            hold on
            hXsection2 = plot(xData,xSectionX,'-c','linewidth',2);
    end


    xlim([xData(1),xData(end)])
    ylim([0,1])

    % Add tick labels
    xticks = round(linspace(xData(1)+0.5,xData(end)-0.5,5));
    set(gca, 'Xtick', xticks)
    grid on

    xlabel('microns')
    ylabel('normalized intensity')

    % Overlay lines corresponding with the zooms
    if ~isempty(overlayZoom)
        imSizeInMicrons = length(xData)*micsPerDataPoint;
        L = length(hXsection1.XData);
        for ii=1:length(overlayZoom)
            thisZoom = imSizeInMicrons / overlayZoom(ii);
            newSize = L/overlayZoom(ii);
            offset = (L-newSize)/2;
            plot([thisZoom/2,thisZoom/2], ylim, 'Color', zoom_cols(ii,:))
            plot(-[thisZoom/2,thisZoom/2], ylim, 'Color', zoom_cols(ii,:))
        end
    end

    % Tweak plot properties
    set(gca,'Color',[1,1,1]*0.7, ...
        'FontSize',12)

    set(hFig,'InvertHardcopy','off', 'Color','w')

    % Nicely scale the plot window so the two figures are sized well with
    % respect to each other. Do this only on the first render into this
    % figure so we do not fight the user if they resize a live view.
    if ~isappdata(hFig,'mpqc_renderer_uniform_slide_sized')
        hFig.Position(3) = hFig.Position(4)*2.3;
        setappdata(hFig,'mpqc_renderer_uniform_slide_sized',true)
    end
