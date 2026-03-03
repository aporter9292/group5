classdef TLAR
    %TLAR Top-Level Aircraft (Design) Requirements
    
    properties
        Crew
        Range       % Harmonic Range
        Payload     % Max. Payload
        V_ld        % Landing Speed
        V_app       % approach speed
        V_climb     % climb speed (CAS)
        V_loiter
        GroundRun
        GroundRun_NCE
        GroundRun_MEX
        GroundRun_BOG
        GroundRunLanding
        ApproachRun
        M_c         % cruise Mach number
        Alt_max     % max altitude in m
        Alt_cruise  % Cruise Altitude
        CrewMass    % Mass of the Crew
    end

    properties
        M_alt % Mach number at each alititude to be limited by either M_c or V_climb
    end

    % alternate airport diversion properties
    properties
        Alt_alternate = 22e3./SI.ft;
        Range_alternate = 200./SI.Nmile;
        Loiter = 30./SI.min; % 30 minutes in seconds
    end
    methods(Static)
        function obj = B777F
            obj = cast.TLAR();
            obj.Range = 4800./SI.Nmile;% m (from nautical miles)
            obj.GroundRun = 2830; % m
            obj.GroundRun_NCE = 2655; % m
            obj.GroundRun_MEX = 3647; % m
            obj.GroundRun_BOG = 3495; % m
            obj.GroundRunLanding = 2500; % m
            obj.ApproachRun = 305; % m
            obj.M_c = 0.82;
            obj.Alt_max = 39e3./SI.ft; %m (39,000ft)
            obj.Alt_cruise = 31e3./SI.ft;
            obj.Crew = 4;
            obj.Payload = 103700;
            obj.CrewMass = (80+10)*obj.Crew;
            obj.V_app = 200./SI.knt;
            obj.V_ld = 150./SI.knt;
            obj.V_climb = 250/SI.knt;
            obj.V_loiter = 175/SI.knt;
        end

        % Airliner design
        function obj = Delphinus_6a
            obj = cast.TLAR();
            obj.Range = 7500*1000;% m
            obj.GroundRun = 2830; % m
            obj.GroundRun_NCE = 2655; % m
            obj.GroundRun_MEX = 3647; % m
            obj.GroundRun_BOG = 3495; % m
            obj.GroundRunLanding = 2500; % m
            obj.ApproachRun = 305; % m
            obj.M_c = 0.85;
            obj.Alt_max = 36e3./SI.ft; % m
            obj.Alt_cruise = 31e3./SI.ft;
            obj.Crew = 4;
            obj.Payload = 108000; % kg
            % obj.Payload = 125000; % kg
            obj.CrewMass = (80+10)*obj.Crew;
            obj.V_app = 150./SI.knt;
            obj.V_ld = 150./SI.knt;
            obj.V_climb = 190/SI.knt;
            obj.V_loiter = 230/SI.knt;
        end
    end
end
