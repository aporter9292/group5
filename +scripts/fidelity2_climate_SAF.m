function [ATR100, RF_total, DeltaT_total, t, ...
          E_CO2_Stages, E_CO2_Total, species_ATR] = fidelity2_climate_SAF(fuel_stages_kg, cruise_alt_ft, stage_alts_ft, range_km)
% ============================================================
% Fidelity 2 Climate Model — SAF (HEFA) Variant  (Refinement Sprint)
% All mission phases, all species, altitude-dependent scaling.
%
% Identical structure to fidelity2_climate_CO2.m (kerosene) but
% applies SAF-specific emission index scaling for ALL applicable
% species, sourced from peer-reviewed literature:
%
%  ┌──────────────────────────────────────────────────────────────┐
%  │ Species   │ Scale  │ Base EI (kerosene) │ SAF EI   │ Source  │
%  │ CO2       │  0.20  │ 3.16 kg/kg         │ 0.632    │ CORSIA  │
%  │ Soot      │  0.50  │ 4.0e-5 kg/kg       │ 2.0e-5   │ Voigt21 │
%  │ AIC       │  0.50  │ baseline           │ ×0.50    │ Voigt21 │
%  │ SO4       │  0.20  │ 2.0e-4 kg/kg       │ 0.4e-4   │ DiSab25 │
%  │ NOx       │  1.00  │ 16.2 g/kg          │ unchanged│ conservative│
%  │ H2O       │  1.00  │ 1.26 kg/kg         │ unchanged│ no data │
%  └──────────────────────────────────────────────────────────────┘
%
% References:
%   CO2 :  ICAO CORSIA Doc 9988 (2022) – HEFA-SPK lifecycle factor
%          GDP Handbook §2.6 (CADEM0016)
%   Soot:  Voigt et al. (2021), Commun. Earth Environ. 2:114
%          DOI: 10.1038/s43247-021-00174-y
%          "50–70% reduction in soot particle number at cruise"
%          → 50% used (conservative end)
%   AIC :  Voigt et al. (2021) — contrail ice crystal number
%          proportional to soot particle number → 50% AIC reduction
%   SO4 :  Di Sabatino et al. (2025), AIAA SciTech Forum
%          DOI: 10.2514/6.2025-0162
%          "70–90% reduction in SO2 emissions" (lower sulfur SAF)
%          → 80% used (central estimate)
%   NOx :  Di Sabatino (2025) found +15% at cruise but for small
%          JT15D-4 engine only — not generalisable to large turbofan.
%          Conservative assumption: same as kerosene.
%
% INPUTS:
%   fuel_stages_kg  : 1x9  [TaxiOut, TakeOff+Climb, Cruise, Descent, Landing,
%                            Contingency, Alternate, Loiter, ToGate]  kg
%   cruise_alt_ft   : (optional) cruise altitude [ft].  Default = 35000
%   stage_alts_ft   : (optional) 1x9 representative altitudes [ft].
%   range_km        : (optional) mission range [km] for AIC.
%
% OUTPUTS:
%   ATR100         : Total ATR over 100 years [K]
%   RF_total       : Total RF time-series [W/m²]
%   DeltaT_total   : Total temperature response [K]
%   t              : Time vector 0-100 years
%   E_CO2_Stages   : CO2 emitted per stage [kg]  (SAF lifecycle)
%   E_CO2_Total    : Total CO2 [kg]              (SAF lifecycle)
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
    stage_alts_ft = [0, 5000, cruise_alt_ft, 10000, 1500, ...
                     cruise_alt_ft, 20000, 1500, 0];
end
if nargin < 4 || isempty(range_km),   range_km = []; end

stage_alts_m = stage_alts_ft * 0.3048;

%% ============================================================
%  SAF SCALING FACTORS  — all sourced from provided literature
%% ============================================================

% -- CO2 lifecycle (ICAO CORSIA HEFA-SPK default) --
EI_CO2_combustion = 3.16;      % combustion EI [kg CO2/kg fuel]
lifecycle_factor  = 0.20;      % HEFA: 80% well-to-wake saving
EI_CO2            = EI_CO2_combustion * lifecycle_factor;   % = 0.632

% -- Soot (Voigt et al. 2021, 50% conservative reduction) --
soot_scale = 0.50;             % 50–70% measured in-flight; 50% used
EI_soot    = 4.0e-5 * soot_scale;   % = 2.0e-5 kg soot / kg fuel

% -- SO4 (Di Sabatino et al. 2025, 70–90% SO2 reduction; 80% used) --
SO4_scale  = 0.20;             % retain 20% of kerosene SO4
EI_SO4     = 2.0e-4 * SO4_scale;    % = 4.0e-5 kg SO4 / kg fuel

% -- AIC (Voigt 2021: proportional to soot particle number) --
AIC_scale  = soot_scale;       % = 0.50 (same proportional reduction)

% -- NOx & H2O: unchanged (conservative / insufficient data) --
EI_NOx  = 16.2e-3;    % kg NOx  / kg fuel  (PPC Example Mission)
EI_H2O  = 1.26;       % kg H2O  / kg fuel

fprintf('\n=== SAF (HEFA) Emission Indices — Fidelity 2 ===\n');
fprintf('EI_CO2  : %.4f kg/kg  (lifecycle ×%.2f vs kero %.2f) — CORSIA\n', EI_CO2, lifecycle_factor, EI_CO2_combustion);
fprintf('EI_soot : %.2e kg/kg  (×%.2f vs kerosene)         — Voigt 2021\n', EI_soot, soot_scale);
fprintf('EI_SO4  : %.2e kg/kg  (×%.2f vs kerosene)         — Di Sabatino 2025\n', EI_SO4, SO4_scale);
fprintf('AIC     : scale ×%.2f                              — Voigt 2021\n', AIC_scale);
fprintf('EI_NOx  : %.4f kg/kg  (unchanged — conservative)  — no applicable data\n', EI_NOx);
fprintf('EI_H2O  : %.4f kg/kg  (unchanged)\n', EI_H2O);
fprintf('================================================\n');

%% 1. Time vector
dt = 0.1;
t  = 0:dt:100;
n  = length(t);

%% 2. Total emissions (SAF values)
total_fuel   = sum(fuel_stages_kg);
E_CO2_Stages = fuel_stages_kg .* EI_CO2;
E_CO2_Total  = sum(E_CO2_Stages);
E_H2O        = total_fuel * EI_H2O;
E_SO4        = total_fuel * EI_SO4;
E_soot       = total_fuel * EI_soot;
E_NOx        = total_fuel * EI_NOx;

%% 3. Altitude scaling s(h) — Dallara 2011 Fig. 4 reference values
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
sAIC_eff  = sum(fuel_frac .* s_AIC);

%% 4. CO2 — long-lived, log-formula (Dallara 2011 / PPC slide 28)
alpha_CO2 = [0.067, 0.1135, 0.152, 0.0970, 0.041];
tau_CO2   = [inf,   313.8,  79.8,  18.8,   1.7  ];
ppm_mass  = 7.8e12;   % kg CO2 per ppm
X0        = 380;      % background CO2 [ppm]

Gx = zeros(size(t));
for i = 1:length(alpha_CO2)
    if isinf(tau_CO2(i)), Gx = Gx + alpha_CO2(i);
    else,                  Gx = Gx + alpha_CO2(i) * exp(-t / tau_CO2(i)); end
end
DeltaX_CO2 = (E_CO2_Total / ppm_mass) .* Gx;
RF_CO2     = log((X0 + DeltaX_CO2) ./ X0) / log(2);

%% 5. Short-lived species — constant RF over 1 year, zero after
%    RF constants calibrated from PPC Example Mission (slide 39):
%      H2O:  E=18900 kg, RF_expected= 0.04e-10 → p = 2.116e-15 W/m²/kg
%      SO4:  E=3 kg,     RF_expected=-0.07e-10 → p =-2.333e-12 W/m²/kg
%      Soot: E=0.6 kg,   RF_expected= 0.06e-10 → p = 1.000e-10 W/m²/kg
%    SAF scales EI_SO4 and EI_soot; the p constants remain unchanged
%    (they reflect per-kg atmospheric radiative forcing, not fuel EIs).

p_H2O  =  2.116e-15;   % W/m² per kg H2O
p_SO4  = -2.333e-12;   % W/m² per kg SO4  (cooling — but SAF has less SO4!)
p_soot =  1.000e-10;   % W/m² per kg soot  (warming — SAF has less soot!)

short_lived = @(p, E, s_eff) step1yr(p * E * s_eff, t);

RF_H2O  = short_lived(p_H2O,  E_H2O,  sH2O_eff);
RF_SO4  = short_lived(p_SO4,  E_SO4,  sSO4_eff);   % SAF: less cooling (less SO4)
RF_soot = short_lived(p_soot, E_soot, sSoot_eff);   % SAF: less warming (less soot)

%% 6. NOx — three effects (same as kerosene, conservative)
%    PPC Example Mission calibration (slide 38-39):
%      CH4 depletion: RF=-0.04e-10 → A_CH4=-1.646e-13 (code uses Dallara -5.16e-13)
%      O3 short:      RF=-0.01e-10 → A_O3S=-4.115e-14  (1-yr step, negative)
%      O3 long:       RF=+0.91e-10 → A_O3L=+3.745e-13  (persistent, warming)
%    Sources: Dallara 2011 (Table A2) + PPC Example Mission PDF p.39

A_CH4   = -5.16e-13;   % W/m² per kg NOx — CH4 depletion  (negative)
A_O3S   = -4.115e-14;  % W/m² per kg NOx — O3 short       (negative, 1-yr)
A_O3L   = +3.745e-13;  % W/m² per kg NOx — O3 long        (positive, persistent)
tau_CH4 = 12;          % years (methane lifetime, IPCC)

RF_NOx_CH4 = A_CH4 * E_NOx * sNOx_eff .* exp(-t / tau_CH4);
RF_NOx_O3S = step1yr(A_O3S * E_NOx * sNOx_eff, t);
RF_NOx_O3L = A_O3L * E_NOx * sNOx_eff .* ones(size(t));
RF_NOx     = RF_NOx_CH4 + RF_NOx_O3S + RF_NOx_O3L;

%% 7. AIC (contrails) — SAF scaled by AIC_scale = 0.50 (Voigt 2021)
%    Base calibration: 4000km=2159.9nm, RF_expected=0.76e-10
%    → p_AIC = 3.519e-14 W/m²/nm  (Dallara 2011, Example Mission)
%    SAF reduces contrail ice crystal number proportionally to soot.
p_AIC_per_nm = 3.519e-14;   % W/m²/nm  (kerosene baseline)

if ~isempty(range_km)
    cruise_range_nm = range_km / 1.852;
else
    cruise_range_nm = fuel_stages_kg(3) / 10.0;  % proxy: cruise fuel / 10 kg/nm
end
RF_AIC_val = p_AIC_per_nm * cruise_range_nm * sAIC_eff * AIC_scale;  % ← SAF scaled
RF_AIC     = step1yr(RF_AIC_val, t);

%% 8. Total RF
RF_total = RF_CO2 + RF_H2O + RF_SO4 + RF_soot + RF_NOx + RF_AIC;

%% 9. Convolution → ΔT(t)
DeltaT_total = zeros(size(t));
for k = 1:n
    lag    = t(k) - t(1:k);
    GT_lag = (2.246 / 36.8) * exp(-lag / 36.8);
    DeltaT_total(k) = sum(GT_lag .* RF_total(1:k) * dt);
end

%% 10. ATR100 — total and per species
ATR100 = (1/100) * trapz(t, DeltaT_total);

sp_fields = {'CO2','H2O','SO4','soot','NOx_CH4','NOx_O3S','NOx_O3L','AIC'};
sp_RFs    = {RF_CO2, RF_H2O, RF_SO4, RF_soot, RF_NOx_CH4, RF_NOx_O3S, RF_NOx_O3L, RF_AIC};
species_ATR = struct();
for si = 1:length(sp_fields)
    dT = zeros(size(t));
    for k = 1:n
        lag    = t(k) - t(1:k);
        GT_lag = (2.246 / 36.8) * exp(-lag / 36.8);
        dT(k)  = sum(GT_lag .* sp_RFs{si}(1:k) * dt);
    end
    species_ATR.(sp_fields{si}) = (1/100) * trapz(t, dT);
end

%% 11. Display
stage_names = {'Taxi Out','TakeOff+Climb','Cruise','Descent','Landing', ...
               'Contingency','Alternate','Loiter','To Gate'};
fprintf('\n==============================================\n');
fprintf('  Fidelity 2 Climate Model — SAF (HEFA)\n');
fprintf('==============================================\n');
fprintf('Cruise altitude  : %.0f ft\n', cruise_alt_ft);
fprintf('\n--- Fuel & CO2 by Stage (SAF lifecycle) ---\n');
for i = 1:5
    fprintf('  %-15s : %8.1f kg fuel  -> %8.1f kg CO2\n', ...
            stage_names{i}, fuel_stages_kg(i), E_CO2_Stages(i));
end
fprintf('----------------------------------------------\n');
fprintf('Total Fuel    : %10.1f kg\n', total_fuel);
fprintf('Total CO2 SAF : %10.1f kg  (vs kero: %.1f kg  [-80%%])\n', ...
        E_CO2_Total, E_CO2_Total / lifecycle_factor);
fprintf('\n--- ATR100 by Species ---\n');
fprintf('  %-14s : %+.4e K\n', 'CO2',      species_ATR.CO2);
fprintf('  %-14s : %+.4e K\n', 'H2O',      species_ATR.H2O);
fprintf('  %-14s : %+.4e K  [SO4 ×%.2f — Di Sabatino 2025]\n', 'SO4',  species_ATR.SO4, SO4_scale);
fprintf('  %-14s : %+.4e K  [Soot×%.2f — Voigt 2021]\n',       'Soot', species_ATR.soot, soot_scale);
fprintf('  %-14s : %+.4e K\n', 'NOx-CH4',  species_ATR.NOx_CH4);
fprintf('  %-14s : %+.4e K\n', 'NOx-O3S',  species_ATR.NOx_O3S);
fprintf('  %-14s : %+.4e K\n', 'NOx-O3L',  species_ATR.NOx_O3L);
fprintf('  %-14s : %+.4e K  [AIC ×%.2f — Voigt 2021]\n',       'AIC',  species_ATR.AIC, AIC_scale);
fprintf('----------------------------------------------\n');
fprintf('  %-14s : %+.4e K\n', 'TOTAL ATR100', ATR100);
fprintf('==============================================\n');

%% 12. Plots
ATR_trend = zeros(size(t));
for k = 2:n
    ATR_trend(k) = (1 / t(k)) * trapz(t(1:k), DeltaT_total(1:k));
end

figure;
plot(t, DeltaT_total, 'g-', 'LineWidth', 2);
grid on; xlabel('Time (years)'); ylabel('\Delta T (K)');
title('SAF — Total Temperature Response, All Species (Fidelity 2)');
legend('\Delta T total (K)', 'Location','best');

figure;
sp_names_SAF = {'CO_2','H_2O','SO_4','Soot','NOx-CH_4','NOx-O_3S','NOx-O_3L','AIC'};
colors = lines(length(sp_fields));
hold on;
for si = 1:length(sp_fields)
    plot(t, sp_RFs{si}, 'LineWidth', 1.5, ...
         'Color', colors(si,:), 'DisplayName', sp_names_SAF{si});
end
plot(t, RF_total, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Total RF');
hold off; grid on; legend('Location','best');
xlabel('Time (years)'); ylabel('RF (W/m^2)');
title('SAF — Radiative Forcing by Species (Fidelity 2)');

figure;
yyaxis left;  plot(t, DeltaT_total, 'g-',  'LineWidth', 2); ylabel('\Delta T (K)');
yyaxis right; plot(t, ATR_trend,    'r--', 'LineWidth', 2); ylabel('ATR (K)');
xlabel('Time (years)'); grid on;
title('SAF — Temperature Response and ATR Trend (Fidelity 2)');
legend('\Delta T (K)', 'ATR running avg (K)', 'Location','northeast');

end

%% Helper: constant value for first year, zero after
function out = step1yr(val, t)
    out = zeros(size(t));
    out(t <= 1) = val;
end
