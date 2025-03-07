classdef ThorPower < handle
    % mic.powermeter.PM100D: Matlab Instrument class to control power meter PM100D.
    %
    % ## Description
    % Controls power meter PM100D, gets the current power. It can also gets
    % the current temperature. The wavelengtj of the light can also be
    % set for power measurement (within the sensor limits). The gui shows
    % a movie of the plot of the
    % measured power where the shown period can be modified. It also shows
    % the current power and the maximum measured power. To run this code
    % you need the power meter to be connected to the machine.
    %
    % ## Constructor
    % Example: P = mic.powermeter.PM100D; P.gui
    %
    % ## Key Functions:
    % constructor(), exportState(), send(), minMaxWavelength(), getWavelength(), measure(), setWavelength(), shutdown()
    %
    % ## REQUIREMENTS:
    %    NI_DAQ  (VISA and ICP Interfaces) should be installed.
    %    Data Acquisition Toolbox Support Package for National Instruments
    %    NI-DAQmx Devices: This add-on can be installed from link:
    %    https://www.mathworks.com/matlabcentral/fileexchange/45086-data-acquisition-toolbox-support-package-for-national-instruments-ni-daqmx-devices
    %    MATLAB 2021a or higher.
    %
    % ### CITATION: Mohamadreza Fazel, Lidkelab, 2017.
    %
    % Adapted from: https://github.com/LidkeLab/matlab-instrument-control/tree/main
    
    properties
        VisaObj             %Visa Object (Virtual Instrument Standard Architecture=VISA)
        Limits              %Min and max of wavelength.
        Lambda              %Wavelength       
    end

    properties (Hidden,SetObservable)
        Power              % Last measured power
        Temperature    % Last measured temperature
    end
    
    
    methods (Static)
        function obj=ThorPower
            %This is the constructor.
            %example PM = mic.powermeter.PM100D
            
            % Find a VISA-USB object.
            vendorinfo = visadevlist;
            s=vendorinfo(1,1).ResourceName;
            
            % TODO -- no test that s is not empty
            obj.VisaObj = visadev(s);

            % Connect to instrument object
            %fopen(obj.VisaObj);
            % Measure the limits of the wavelength.
            obj.Limits=minMaxWavelength(obj);
        end

        function funcTest()
            %testing the class.
            try
                TestObj=mic.powermeter.PM100D();
                fprintf('Constructor is run and an object of the class is made.\n');
                Limit = minMaxWavelength(TestObj);
                fprintf('Min wavelength: %d, Max wavelength: %d\n', Limit(1),Limit(2));
                getWavelength(TestObj);
                fprintf('The current wavelength is %d nm.\n',TestObj.Lambda);
                TestObj.Lambda=600;
                setWavelength(TestObj);
                fprintf('The wavelength is set to 600 nm.\n');
                State=exportState(TestObj);
                fprintf('The exportState function was successfully tested.\n');
                TestObj.delete();
                fprintf('The port is closed and the object is deleted.\n');
                fprintf('The class is successfully tested :)\n')
            catch ME
                fprintf('Sorry an error has ocured :(\n');
                ME
            end
        end
    end
    
    methods

        
        function Reply=send(obj,Message)
            %Sending a message to the power-meter and getting a feedback.
            %fprintf(obj.VisaObj,Message);
            %Reply=fscanf(obj.VisaObj,'%s');
            Reply = writeread(obj.VisaObj,Message);

        end
        
        function devInfo = reportDeviceInfo(obj)
            % Return string describing the model number, etc, of the power meter
            devInfo = obj.send('*IDN?');
        end
        
        function devInfo = reportSensorInfo(obj)
            % Return string describing the sensor head
            devInfo = obj.send(':SYST:SENS:IDN?');
        end
        
        function autoRange = isAutoRangeEnabled(obj)
            % Return 1 if autorange is enabled. 0 otherwise
            autoRange = obj.send(':SENS:POWER:RANG:AUTO?');
            autoRange = str2num(autoRange);
        end
        
        function disableAutoRange(obj)
            % Disable auto-range
            fprintf(obj.VisaObj,'SENSE:POWER:RANGE:AUTO OFF');
        end
        
        function enableAutoRange(obj)
            % Enable auto-range
            fprintf(obj.VisaObj,'SENSE:POWER:RANGE:AUTO ON');
        end
        
        function setAutoRange(obj,autoRange)
            % Set auto-range.
            % autoRange is a string (TODO: for now)
            %
            % e.g.
            % setAutoRange('0.1')
            fprintf(obj.VisaObj,sprintf('SENSE:POWER:RANGE %s',autoRange));
        end
        
        function Limits=minMaxWavelength(obj)
            %Reading the limits of the wavelength.
            %
            R1=obj.send('SENS:CORR:WAV? MIN');
            R2=obj.send('SENS:CORR:WAV? MAX');
            Limits = [str2double(R1) str2double(R2)];
        end
        
        function varargout = getWavelength(obj)
            %Reading the current wavelength of the instrument.
            %
            % If no output arguments the wavelength is printed to screen. 
            % If an output is requested, the wavelength is returned as a
            % scalar and nothing is printed to screen. 
            
            Lambda=str2double(send(obj,'SENS:CORR:WAV?'));
            
            obj.Lambda = Lambda;

            if nargout==0
                fprintf('Wavelength: %d nm \n',obj.Lambda);
            else
                varargout{1} = Lambda;
            end
        end
        

        function varargout = getPower(obj)
            % Read power in mW (?)
            
            Out=str2double(obj.send('MEASURE:POWER?'))*1000;
            obj.Power = Out;
            if nargout==0
                fprintf('Power is: %0.4f mW \n', Out);
            else
                varargout{1} = Out;
            end
        end


        function varargout = getTemperature(obj)
            % Read temperature in degrees C

            Out=str2double(obj.send('MEASURE:TEMPERATURE?'));
            obj.Temperature= Out;
            if nargout==0
                fprintf('Temperature is: %0.1f degrees C \n', Out);
            else
                varargout{1} = Out;
            end
        end
        

        function setWavelength(obj,lambda)
            % Setting the wavelength
            %
            % Inputs
            % lambda - the wavelength to set the meter to in nm
            %

            % TODO -- use the range of detector
            minL = 400;
            maxL = 1100;
            if lambda < minL | lambda > maxL
                fprintf('The wavelength is out of the range [%dm, %dnm].', ...
                    minL, maxL);
            end
            
            s = sprintf('CORRECTION:WAVELENGTH %g nm',lambda);
            %fprintf(obj.VisaObj, s);
            write(obj.VisaObj,s,"string");

            obj.Lambda = lambda;
        end


        function shutdown(obj)
            %This function is called in the destructor to delete the communication port.
            delete(obj.VisaObj);
            
        end
            
        function delete(obj)
            %This function closes the communication port and close the gui.
            obj.shutdown();
        end % delete

        
    end
end% classdef
