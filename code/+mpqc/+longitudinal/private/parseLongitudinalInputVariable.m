function out = parseLongitudinalInputVariable(varargin)
    % Parse optional inputs for longitudinal analysis functions.
    %
    % out = parseLongitudinalInputVariable('param1', val1, ...)
    %
    % Inputs (optional parameter/value pairs)
    %  'startDate' - First measurement date to include. This can be a
    %                datetime, string, or character vector.
    %  'wavelength' - Excitation wavelength to include, in nm.
    %
    % Outputs
    % out - A structure containing the supplied options. startDate is
    %       returned as a datetime value when it is provided.
    %
    % Isabell Whiteley, SWC AMF, initial commit 2026

    params = inputParser;
    params.CaseSensitive = false;
    params.KeepUnmatched = true;
    params.addParameter('startDate', [], @(x) isdatetime(x) || ischar(x) || isstring(x));
    params.addParameter('wavelength', [], @(x) isnumeric(x));
    params.parse(varargin{:});

    out = params.Results;

    unmatchedFields = fields(params.Unmatched);
    for ii = 1:length(unmatchedFields)
        out.(unmatchedFields{ii}) = params.Unmatched.(unmatchedFields{ii});
    end

    if ~isempty(out.startDate)
        out.startDate = datetime(out.startDate);
    end
end
