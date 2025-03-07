classdef ThorPower < handle
    % Interface class for ThorLabs power meters
    %
    % mpqc.interfaces.ThorPower
    %
    % Purpose
    % Controls ThorLabs power meters using VISA. Gets laser power, temperature, sets
    % the illumination wavelength, etc.
    %
    % Example
    % tPower = mpqc.interfaces.ThorPower
    % tPower.getPower
    % delete(tPower)
    %
    %
    % Requirements
    % NI VISA should be installed. See also: (TODO -- DO WE NEED THAT?)
    % https://www.mathworks.com/matlabcentral/fileexchange/45086-data-acquisition-toolbox-support-package-for-national-instruments-ni-daqmx-devices
    %
    %
    % Acknowledgements
    % This class is based on one created by Mohamadreza Fazel (Lidkelab) at:
    % https://github.com/LidkeLab/matlab-instrument-control/tree/main
    %
    %
    % Isabell Whiteley, SWC AMF, initial commit 2025


    properties
        visaObj           % Visa Object (Virtual Instrument Standard Architecture=VISA)
        wavelengthLimits  % Min and max of wavelength.
        currentLambda     % Wavelength
    end

    properties (Hidden,SetObservable)
        lastMeasuredPower
        lastMeasuredTemperature
    end


    methods
        function obj=ThorPower
            % mpqc.interfaces.ThorPower
            %
            % Inputs
            % none
            %

            % Find a VISA-USB object.
            vendorinfo = visadevlist;
            s=vendorinfo(1,1).ResourceName;

            % TODO -- no test that s is not empty
            obj.visaObj = visadev(s);

            % Connect to instrument object
            %fopen(obj.visaObj); %% WHY COMMENTED OUT??

            % Measure the limits of the wavelength.
            obj.getMinMaxWavelength(obj);
        end % constructor


        function delete(obj)
            obj.shutdown();
        end % destructor


        function Reply=send(obj,Message)
            % Sends a message to the power-meter and receives feedback.

            Reply = writeread(obj.visaObj,Message);

        end % send


        function devInfo = reportDeviceInfo(obj)
            % Return string describing the model number, etc, of the power meter
            devInfo = obj.send('*IDN?');
        end % reportDeviceInfo


        function devInfo = reportSensorInfo(obj)
            % Return string describing the sensor head
            devInfo = obj.send(':SYST:SENS:IDN?');
        end % reportSensorInfo


        function autoRange = isAutoRangeEnabled(obj)
            % Return 1 if autorange is enabled. 0 otherwise
            autoRange = obj.send(':SENS:POWER:RANG:AUTO?');
            autoRange = str2num(autoRange);
        end % isAutoRangeEnabled


        function disableAutoRange(obj)
            % Disable auto-range
            fprintf(obj.visaObj,'SENSE:POWER:RANGE:AUTO OFF');
        end % disableAutoRange


        function enableAutoRange(obj)
            % Enable auto-range
            fprintf(obj.visaObj,'SENSE:POWER:RANGE:AUTO ON');
        end % enableAutoRange


        function setAutoRange(obj,autoRange)
            % Set auto-range.
            % autoRange is a string (TODO: for now)
            %
            % e.g.
            % setAutoRange('0.1')
            fprintf(obj.visaObj,sprintf('SENSE:POWER:RANGE %s',autoRange));
        end % setAutoRange


        function varargout = getMinMaxWavelength(obj)
            % Read the wavelength limits of the sensor and log these
            %
            R1=obj.send('SENS:CORR:WAV? MIN');
            R2=obj.send('SENS:CORR:WAV? MAX');
            obj.wavelengthLimits = [str2double(R1) str2double(R2)];

            if nargout>0
                varargout{1} = obj.wavelengthLimits;
            end
        end % getMinMaxWavelength


        function varargout = getWavelength(obj)
            %Reading the current wavelength of the instrument.
            %
            % If no output arguments the wavelength is printed to screen.
            % If an output is requested, the wavelength is returned as a
            % scalar and nothing is printed to screen.

            currentLambda=str2double(send(obj,'SENS:CORR:WAV?'));

            obj.currentLambda = currentLambda;

            if nargout==0
                fprintf('Wavelength: %d nm \n',obj.currentLambda);
            else
                varargout{1} = currentLambda;
            end
        end % getWavelength


        function varargout = getPower(obj)
            % Read power in mW

            Out=str2double(obj.send('MEASURE:POWER?'))*1000;
            obj.lastMeasuredPower = Out;
            if nargout==0
                fprintf('Power is: %0.4f mW \n', Out);
            else
                varargout{1} = Out;
            end
        end % getPower


        function varargout = getTemperature(obj)
            % Read temperature in degrees C

            Out=str2double(obj.send('MEASURE:TEMPERATURE?'));
            obj.lastMeasuredTemperature= Out;
            if nargout==0
                fprintf('Temperature is: %0.1f degrees C \n', Out);
            else
                varargout{1} = Out;
            end
        end % getTemperature


        function setWavelength(obj,lambda)
            % Setting the wavelength
            %
            % Inputs
            % lambda - the wavelength to set the meter to in nm
            %

            if lambda < obj.wavelengthLimits(1) | lambda > obj.wavelengthLimits(2)
                fprintf('The wavelength is out of the range [%dm, %dnm].', ...
                    minL, maxL);
            end

            s = sprintf('CORRECTION:WAVELENGTH %g nm',lambda);
            write(obj.visaObj,s,"string");

            obj.currentLambda = lambda;
        end % setWavelength


        function shutdown(obj)
            %This function is called in the destructor to delete the communication port.
            delete(obj.visaObj);
        end % shutdown

    end % methods

end% classdef
