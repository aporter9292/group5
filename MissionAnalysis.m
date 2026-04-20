function [BlockFuel,TripFuel, ResFuel,Mf_TOC,MissionTime,cruise_FL, fuel_stages_kg, range_km, stage_alts_ft] = MissionAnalysis(ADP,tripRange,M_TO)
%MISSIONANALYSIS conduct mission analysis to estimate fuel burn
% Fallback for older MATLAB versions (pre R2019b) instead of arguments block
if nargin < 3
    M_TO = ADP.MTOM; % take off mass fallback
end
%x
EWF = 1;   % empty weight fraction
fs = double.empty;
ts = double.empty;

%% cruise analysis (assume constant C_L)

% pick optimal altitude for cruise
alts = linspace(15e3./SI.ft,44e3./SI.ft,61);
[rho,a,T,P] = cast.atmos(alts);
% [rho_s,a_s,~,P_s] = dcrg.aero.atmos(0);
M_cruise = ADP.TLAR.M_c;
CL_c = EWF*M_TO*9.81./(1/2.*rho.*(a.*M_cruise).^2.*ADP.WingArea); % cruise C_L
CD_c = ADP.AeroPolar.CD(CL_c);
LD_c = CL_c./CD_c;
[~,idx] = max(LD_c);

alt = alts(idx);
CL_c = CL_c(idx);
CD_c = CD_c(idx);
LD_c = CL_c/CD_c;
[~,a,~,~] = cast.atmos(alt);                  % speed of sound at optimal cruise alt [m/s]
cruise_FL  = round(alt.*SI.ft/1e2,0);          % cruise flight level (e.g. 353 = FL353)

% ── BWB L/D override ─────────────────────────────────────────────────────
% AeroPolar uses B777 CD0 (0.019) giving L/D ≈ 11, which is not valid for BWB.
% Override with BWB cruise L/D = 18 (Aero v2.0: CruisePolarSizing seed;
%   CD0=0.012, AR=3.79, e=0.85.  Liebeck 2004 reports 20-23 for clean BWB;
%   18 is conservative and accounts for trim drag + compressibility).
% Remove this line once aero team provides the converged BWB drag polar.
LD_c = 18;   % BWB cruise L/D — Aero v2.0 seed (pending converged polar)
% ─────────────────────────────────────────────────────────────────────────

% Suppress debug plot (L/D vs CL) — remove comment to re-enable
% f = figure(11); clf; plot(Cls,LDs)

% account for fact I don't model climb with an "effective" trip range
tripRange = tripRange * 1;
fs(1) = exp(-tripRange*9.81*ADP.Engine.TSFC(M_cruise,alt)/(M_cruise*a*LD_c)); % Rearranged Brequet
ts(1) = tripRange/(M_cruise*a); % time taken
EWF = EWF*fs(1);


%% alternate mission analysis
[rho,a,~,P] = cast.atmos(ADP.TLAR.Alt_alternate);
% [rho_s,a_s,~,P_s] = dcrg.aero.atmos(0);
M_cruise = ADP.TLAR.M_c;

CL_c = EWF*M_TO*9.81/(1/2*rho*(a*M_cruise)^2*ADP.WingArea); % cruise C_L
CD_c = ADP.AeroPolar.CD(CL_c);
LD_c = CL_c/CD_c;

% account for fact I don't model climb with an "effective" trip range
altRange = ADP.TLAR.Range_alternate * 1;

fs(2) = exp(-altRange*9.81*ADP.Engine.TSFC(M_cruise,altRange)/(M_cruise*a*LD_c)); % Rearranged Brequet
ts(2) = altRange/(M_cruise*a); % time taken
EWF = EWF*fs(2);

%% loiter
[rho,a,~,P] = cast.atmos(0);
Mach = 150/a;
CL = EWF*M_TO*9.81/(1/2*rho*(a*Mach)^2*ADP.WingArea);
CD = ADP.AeroPolar.CD(CL);
LD = CL/CD;

fs(3) = exp(-ADP.TLAR.Loiter*9.81*ADP.Engine.TSFC(Mach,0)/LD); % Snorri
ts(3) = ADP.TLAR.Loiter; % time taken
EWF = EWF*fs(3);

%% Contingency
df = (1-EWF)*0.03;
fs(4) = 1-df/EWF;
ts(4) = 5*60; % 5 minutes...
EWF = EWF*fs(4);


%% fuel stage breakdown using standard mass fractions
% Historical mass fractions (e.g. from Raymer / Gudmundsson 6.2)
% NOTE: ff_to_climb combines Take Off (0.995) AND Climb (0.980) into one
%       stage. fuel_stages_kg(2) therefore represents TakeOff+Climb fuel.
%       This matches the Fidelity 2 stage label 'TakeOff+Climb'.
ff_taxi     = 0.990;         % Taxi Out
ff_to_climb = 0.995 * 0.980; % Take Off + Climb (combined)
ff_desc     = 0.990;         % Descent
ff_ldg      = 0.992;         % Landing & Taxi-in

m_taxi = M_TO * (1 - ff_taxi);
W_taxi = M_TO * ff_taxi;

% TakeOff+Climb stage fuel
m_to = W_taxi * (1 - ff_to_climb);
W_to = W_taxi * ff_to_climb;

% Cruise: fs(1) is the Breguet weight fraction
m_cruise = W_to * (1 - fs(1));
W_cruise = W_to * fs(1);

m_desc = W_cruise * (1 - ff_desc);
W_desc = W_cruise * ff_desc;

m_ldg = W_desc * (1 - ff_ldg);

% ── Reserve fuel stage breakdown (GDP Spec Appendix A) ──────────────────
% Each reserve fuel mass is derived from the Breguet/Snorri weight fractions
% already computed above (fs(1)=cruise, fs(2)=alternate, fs(3)=loiter, fs(4)=contingency).
%
% Post-cruise aircraft mass = M_TO * fs(1)
% Contingency applied LAST per GDP ordering: greatest of 3% trip fuel or 5-min loiter
m_cont   = M_TO * fs(1) * fs(2) * fs(3) * (1 - fs(4));      % [6] Contingency fuel
m_alt    = M_TO * fs(1) * (1 - fs(2));                       % [7] Alternate mission fuel
m_loiter = M_TO * fs(1) * fs(2) * (1 - fs(3));              % [8] Loiter 30-min fuel
m_togate = M_TO * prod(fs) * (1 - ff_taxi);                  % [9] To Gate (20 min, idle)

% fuel_stages_kg: 9 elements — full mission per GDP Spec Appendix A
% [TaxiOut, TakeOff+Climb, Cruise, Descent, Landing, Contingency, Alternate, Loiter, ToGate]
fuel_stages_kg = [m_taxi, m_to, m_cruise, m_desc, m_ldg, m_cont, m_alt, m_loiter, m_togate];

%% update model
EWF_actual = EWF * ff_taxi * ff_to_climb * ff_desc * ff_ldg; % accounting for full mission
BlockFuel = (1-EWF_actual) * M_TO;
TripFuel = sum(fuel_stages_kg);
ResFuel = (1-prod(fs(2:end)))*M_TO;
Mf_TOC = W_to / M_TO;

MissionTime = ts(1);

% --- Outputs for fidelity2_climate_Kerosene pipeline ---
% tripRange is in metres (from ADP.TLAR.Range); convert to km for AIC
range_km = tripRange / 1000;

% Representative altitude [ft] for each of the 9 fuel stages:
%   [TaxiOut, TakeOff+Climb, Cruise, Descent, Landing, Contingency, Alternate, Loiter, ToGate]
% cruise_FL is in flight-level units (e.g. 350 = 35000 ft); Alt_alternate is in m -> convert to ft
alt_alt_ft    = ADP.TLAR.Alt_alternate * SI.ft;   % alternate cruise alt [ft]
stage_alts_ft = [0, 5000, cruise_FL*100, 10000, 1500, cruise_FL*100, alt_alt_ft, 1500, 0];

end