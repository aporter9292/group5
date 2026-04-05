function [ATR100, RF_total, DeltaT_total, t, ...
          E_CO2_Stages, E_CO2_Total, species_ATR] = fidelity2_climate_CO2(fuel_stages_kg, cruise_alt_ft, stage_alts_ft, range_km, fuel_type)
% ============================================================
% Fidelity 2 Climate Model  (Refinement Sprint)
% All mission phases, all species, altitude-dependent scaling.
%
% Constants calibrated from Example Mission (PPC Lecture, slide 38-39):
%   15t fuel, 4000km, 34000ft, OPR=50, all s(h)=1
%   Reference: Dallara et al. (2011) DOI: 10.2514/1.J050763
%
% INPUTS:
%   fuel_stages_kg  : 1x9  [TaxiOut, TakeOff+Climb, Cruise, Descent, Landing,
%                            Contingency, Alternate, Loiter, ToGate]  kg
%                     (GDP Spec Appendix A — full mission including all reserves)
%   cruise_alt_ft   : (optional) cruise altitude [ft].  Default = 35000
%   stage_alts_ft   : (optional) 1x9 representative altitudes [ft].
%                     Default = [0, 5000, cruise_alt_ft, 10000, 1500,
%                                cruise_alt_ft, 20000, 1500, 0]
%   range_km        : (optional) mission range [km] for AIC.
%                     Default = cruise fuel / 10 kg/nm (proxy)
%
% OUTPUTS:
%   ATR100         : Total ATR over 100 years [K]
%   RF_total       : Total RF time-series [W/m²]
%   DeltaT_total   : Total temperature response [K]
%   t              : Time vector 0-100 years
%   E_CO2_Stages   : CO2 emitted per stage [kg]
%   E_CO2_Total    : Total CO2 [kg]
%   species_ATR    : Struct of ATR100 per species
% ============================================================

%% Input validation & defaults
if length(fuel_stages_kg) ~= 9
    error(['fuel_stages_kg must be 1x9 (GDP Spec Appendix A): ', ...
           '[TaxiOut, TakeOff+Climb, Cruise, Descent, Landing, ', ...
           'Contingency, Alternate, Loiter, ToGate]']);
end
if nargin < 2 || isempty(cruise_alt_ft),  cruise_alt_ft = 35000; end
if nargin < 3 || isempty(stage_alts_ft)
    %          TaxiOut  Climb  Cruise          Descent  Landing  Cont.           Alternate  Loiter  ToGate
    stage_alts_ft = [0, 5000, cruise_alt_ft, 10000, 1500, cruise_alt_ft, 20000, 1500, 0];
end
if nargin < 4 || isempty(range_km),   range_km  = [];         end
if nargin < 5 || isempty(fuel_type),  fuel_type = 'kerosene'; end

% Get lifecycle-adjusted CO2 emission index (mandatory Refinement deliverable)
% Kerosene: EI_CO2 = 3.16  |  SAF (HEFA): EI_CO2 = 0.632 (80% lifecycle saving)
[EI_CO2, lifecycle_factor] = cast.eng.lifecycle_emissions(fuel_type);

stage_alts_m = stage_alts_ft * 0.3048;

%% 1. Time vector
dt = 0.1;
t  = 0:dt:100;
n  = length(t);

%% 2. Emission indices (per kg fuel)
% Calibrated from PPC Example Mission (slide 38): EIs match exactly.
% EI_CO2 comes from lifecycle_emissions() above (accounts for fuel type).
EI_H2O  = 1.26;       % kg H2O  / kg fuel
EI_SO4  = 2.0e-4;     % kg SO4  / kg fuel
EI_soot = 4.0e-5;     % kg soot / kg fuel
EI_NOx  = 16.2e-3;    % kg NOx  / kg fuel  (Example Mission slide 38: 16.2 g/kg)
% Note: H2O, SO4, soot, NOx EIs are the same for kerosene and SAF at combustion.
%       Only CO2 receives the lifecycle reduction credit.

%% 3. Total emissions
total_fuel   = sum(fuel_stages_kg);
E_CO2_Stages = fuel_stages_kg .* EI_CO2;
E_CO2_Total  = sum(E_CO2_Stages);
E_H2O        = total_fuel * EI_H2O;
E_SO4        = total_fuel * EI_SO4;
E_soot       = total_fuel * EI_soot;
E_NOx        = total_fuel * EI_NOx;

%% 4. Altitude scaling s(h) — Dallara 2011 Fig. 4 reference values
% s(h) is normalised so s(cruise) = 1. CO2 has no altitude dependence.
h_ref   = [0,    3000,  6000,  9000,  11000, 12000];  % m
s_H2O_r = [0.00, 0.10,  0.30,  0.70,  1.00,  1.10];
s_NOx_r = [0.00, 0.00,  0.20,  0.60,  1.00,  1.10];
s_soot_r= [0.00, 0.05,  0.20,  0.60,  1.00,  1.05];
s_SO4_r = [0.00, 0.05,  0.20,  0.55,  1.00,  1.05];
s_AIC_r = [0.00, 0.00,  0.10,  0.50,  1.00,  1.10];

interp_s = @(ref) max(interp1(h_ref, ref, stage_alts_m, 'linear', 'extrap'), 0);
s_H2O  = interp_s(s_H2O_r);
s_NOx  = interp_s(s_NOx_r);
s_soot = interp_s(s_soot_r);
s_SO4  = interp_s(s_SO4_r);
s_AIC  = interp_s(s_AIC_r);

% Fuel-weighted effective s per species
fuel_frac = fuel_stages_kg / total_fuel;
sH2O_eff  = sum(fuel_frac .* s_H2O);
sNOx_eff  = sum(fuel_frac .* s_NOx);
sSoot_eff = sum(fuel_frac .* s_soot);
sSO4_eff  = sum(fuel_frac .* s_SO4);
sAIC_eff  = sum(fuel_frac .* s_AIC);   % driven by cruise stage altitude

%% 5. CO2 — long-lived, log-formula (Dallara 2011 / PPC slide 28)
alpha_CO2 = [0.067, 0.1135, 0.152, 0.0970, 0.041];
tau_CO2   = [inf,   313.8,  79.8,  18.8,   1.7  ];
ppm_mass  = 7.8e12;   % kg CO2 per ppm
X0        = 380;      % background CO2 [ppm]

Gx = zeros(size(t));
for i = 1:length(alpha_CO2)
    if isinf(tau_CO2(i)), Gx = Gx + alpha_CO2(i);
    else,                 Gx = Gx + alpha_CO2(i)*exp(-t/tau_CO2(i)); end
end
DeltaX_CO2 = (E_CO2_Total / ppm_mass) .* Gx;
RF_CO2     = log((X0 + DeltaX_CO2) ./ X0) / log(2);

%% 6. Short-lived species — constant RF over 1 year, zero after
%    Specific RF constants calibrated from Example Mission (slide 39):
%      Given 15000 kg fuel, all s(h)=1, expected RF at t=0 shown below.
%
%    H2O:  E=18900 kg,  RF_expected= 0.04e-10  -> p = 2.116e-15 W/m2/kg
%    SO4:  E=3 kg,      RF_expected=-0.07e-10  -> p =-2.333e-12 W/m2/kg
%    Soot: E=0.6 kg,    RF_expected= 0.06e-10  -> p = 1.000e-10 W/m2/kg

p_H2O  =  2.116e-15;   % W/m2 per kg H2O
p_SO4  = -2.333e-12;   % W/m2 per kg SO4  (cooling)
p_soot =  1.000e-10;   % W/m2 per kg soot

short_lived = @(p, E, s_eff) step1yr(p * E * s_eff, t);

RF_H2O  = short_lived(p_H2O,  E_H2O,  sH2O_eff);
RF_SO4  = short_lived(p_SO4,  E_SO4,  sSO4_eff);
RF_soot = short_lived(p_soot, E_soot, sSoot_eff);

%% 7. NOx — three effects (calibrated from Example Mission slide 39)
%    NOx (E=243 kg at 15t fuel, EI=0.0162):
%      CH4 depletion:   RF_expected=-0.04e-10  -> A_CH4 =-1.646e-13, decay tau=12yr
%      O3 short:        RF_expected=-0.01e-10  -> A_O3S =-4.115e-14  (1-year step)
%      O3 long:         RF_expected=+0.91e-10  -> A_O3L =+3.745e-13  (persistent)

A_CH4 = -5.16e-13;   % W/m2 per kg NOx — CH4 depletion (negative, tau=12yr)
A_O3S = -4.115e-14;   % W/m2 per kg NOx — O3 short/secondary (negative, 1-yr)
A_O3L = +3.745e-13;  % W/m2 per kg NOx — O3 long (WARMING, +ve, persistent)
%   Calibrated from Example Mission PDF p.39: O3(long) RF*=+0.91e-10 W/m2
%   for E_NOx=243kg (15t fuel × EI=16.2g/kg), all scale factors=1
%   → A_O3L = +0.91e-10 / 243 = +3.745e-13  (positive = warming)
tau_CH4 = 12;         % years

RF_NOx_CH4 = A_CH4 * E_NOx * sNOx_eff .* exp(-t / tau_CH4);
RF_NOx_O3S = step1yr(A_O3S * E_NOx * sNOx_eff, t);
RF_NOx_O3L = A_O3L * E_NOx * sNOx_eff .* ones(size(t));  % persistent (long-lived)
RF_NOx     = RF_NOx_CH4 + RF_NOx_O3S + RF_NOx_O3L;

%% 8. AIC (contrails) — altitude-dependent, per nm flown
%    Calibrated from Example Mission: 4000km=2159.9nm, RF_expected=0.76e-10
%      p_AIC = 0.76e-10 / 2159.9 = 3.519e-14 W/m2/nm
p_AIC_per_nm = 3.519e-14;  % W/m2/nm  (Dallara 2011, calibrated to Example Mission)

if ~isempty(range_km)
    cruise_range_nm = range_km / 1.852;
else
    % Proxy: cruise fuel / 10 kg/nm (widebody estimate)
    cruise_range_nm = fuel_stages_kg(3) / 10.0;
end
RF_AIC_val = p_AIC_per_nm * cruise_range_nm * sAIC_eff;
RF_AIC     = step1yr(RF_AIC_val, t);

%% 9. Total RF
RF_total = RF_CO2 + RF_H2O + RF_SO4 + RF_soot + RF_NOx + RF_AIC;

%% 10. Convolution -> DeltaT(t)
DeltaT_total = zeros(size(t));
for k = 1:n
    lag    = t(k) - t(1:k);
    GT_lag = (2.246/36.8) * exp(-lag/36.8);
    DeltaT_total(k) = sum(GT_lag .* RF_total(1:k) * dt);
end

%% 11. ATR100 — total and per species
ATR100 = (1/100) * trapz(t, DeltaT_total);

sp_fields  = {'CO2','H2O','SO4','soot','NOx_CH4','NOx_O3S','NOx_O3L','AIC'};
sp_RFs     = {RF_CO2, RF_H2O, RF_SO4, RF_soot, RF_NOx_CH4, RF_NOx_O3S, RF_NOx_O3L, RF_AIC};
species_ATR = struct();
for si = 1:length(sp_fields)
    dT = zeros(size(t));
    for k = 1:n
        lag = t(k)-t(1:k);
        GT_lag = (2.246/36.8)*exp(-lag/36.8);
        dT(k) = sum(GT_lag .* sp_RFs{si}(1:k) * dt);
    end
    species_ATR.(sp_fields{si}) = (1/100)*trapz(t, dT);
end

%% 12. Display
stage_names = {'Taxi Out','TakeOff+Climb','Cruise','Descent','Landing', ...
               'Contingency','Alternate','Loiter','To Gate'};
fprintf('\n==============================================\n');
fprintf('  Fidelity 2 Climate Model (Refinement)\n');
fprintf('==============================================\n');
fprintf('Cruise altitude  : %.0f ft\n', cruise_alt_ft);
fprintf('\n--- Fuel & CO2 by Stage ---\n');
for i = 1:5
    fprintf('  %-15s : %8.1f kg fuel  -> %8.1f kg CO2\n', ...
            stage_names{i}, fuel_stages_kg(i), E_CO2_Stages(i));
end
fprintf('----------------------------------------------\n');
fprintf('Total Fuel    : %10.1f kg\n', total_fuel);
fprintf('Total CO2     : %10.1f kg\n', E_CO2_Total);
fprintf('\n--- ATR100 by Species ---\n');
fprintf('  %-14s : %+.4e K\n', 'CO2',      species_ATR.CO2);
fprintf('  %-14s : %+.4e K\n', 'H2O',      species_ATR.H2O);
fprintf('  %-14s : %+.4e K\n', 'SO4',      species_ATR.SO4);
fprintf('  %-14s : %+.4e K\n', 'Soot',     species_ATR.soot);
fprintf('  %-14s : %+.4e K\n', 'NOx-CH4',  species_ATR.NOx_CH4);
fprintf('  %-14s : %+.4e K\n', 'NOx-O3S',  species_ATR.NOx_O3S);
fprintf('  %-14s : %+.4e K\n', 'NOx-O3L',  species_ATR.NOx_O3L);
fprintf('  %-14s : %+.4e K\n', 'AIC',      species_ATR.AIC);
fprintf('----------------------------------------------\n');
fprintf('  %-14s : %+.4e K\n', 'TOTAL ATR100', ATR100);
fprintf('==============================================\n');

%% 13. Plots
ATR_trend = zeros(size(t));
for k = 2:n
    ATR_trend(k) = (1/t(k)) * trapz(t(1:k), DeltaT_total(1:k));
end

figure;
plot(t, DeltaT_total, 'k-', 'LineWidth', 2);
grid on; xlabel('Time (years)'); ylabel('\Delta T (K)');
title('Kerosene — Total Temperature Response, All Species (Fidelity 2)');
legend('\Delta T total (K)', 'Location','best');

figure;
sp_names = {'CO_2','H_2O','SO_4','Soot','NOx-CH_4','NOx-O_3S','NOx-O_3L','AIC'};
hold on;
for si = 1:length(sp_names)
    plot(t, sp_RFs{si}, 'LineWidth', 1.5, 'DisplayName', sp_names{si});
end
plot(t, RF_total, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Total RF');
hold off; grid on; legend('Location','best');
xlabel('Time (years)'); ylabel('RF (W/m^2)');
title('Kerosene — Radiative Forcing by Species (Fidelity 2)');

figure;
yyaxis left;  plot(t, DeltaT_total, 'b-', 'LineWidth', 2); ylabel('\Delta T (K)');
yyaxis right; plot(t, ATR_trend,    'r--','LineWidth', 2); ylabel('ATR (K)');
xlabel('Time (years)'); grid on;
title('Kerosene — Temperature Response and ATR Trend (Fidelity 2)');
legend('\Delta T (K)', 'ATR running avg (K)', 'Location','northeast');

end

%% Helper: constant value for first year, zero after
function out = step1yr(val, t)
    out = zeros(size(t));
    out(t <= 1) = val;
end
