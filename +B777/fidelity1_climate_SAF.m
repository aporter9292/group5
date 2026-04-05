function [ATR100, RF_star, DeltaT, t] = fidelity1_climate_SAF(cruiseFuel_kg)

% ============================================================
% Fidelity 1 Climate Model — SAF (HEFA) Variant
% Cruise phase only, CO2 emissions only.
%
% Identical structure to fidelity1_climate_C02.m but uses the
% CORSIA HEFA lifecycle CO2 emission index (80% well-to-wake
% reduction vs kerosene):
%
%   EI_CO2_SAF = 3.16 × 0.20 = 0.632 kg CO2 / kg fuel
%
% SAF Lifecycle Reference:
%   ICAO CORSIA SAF Methodology (Doc 9988, 2022 edition)
%   — HEFA-SPK pathway default lifecycle factor = 0.20
%   GDP Handbook §2.6: "Consider full life-cycle emissions of
%   kerosene and sustainable aviation fuels (SAFs)"
%
% Uses equations directly from the PPC Engineer lecture.
% ============================================================

%% SAF Lifecycle Definition
% --------------------------------------------------------
%  Combustion physics: burning 1 kg fuel ALWAYS releases 3.16 kg CO2.
%  The lifecycle credit accounts for the carbon captured during feedstock
%  growth / waste diversion (HEFA = used cooking oil, etc.).
%  Net lifecycle factor = 0.20  →  net EI_CO2 = 0.632 kg / kg fuel.
% --------------------------------------------------------
EI_CO2_combustion = 3.16;   % combustion EI (same for all fuels) [kg CO2/kg fuel]
lifecycle_factor  = 0.20;   % HEFA CORSIA default (80% lifecycle saving)
EI_CO2            = EI_CO2_combustion * lifecycle_factor;  % = 0.632

fprintf('\n--- SAF Lifecycle (Fidelity 1) ---\n');
fprintf('Combustion EI    : %.3f kg CO2 / kg fuel\n', EI_CO2_combustion);
fprintf('Lifecycle factor : %.2f  (%.0f%% of kerosene baseline)\n', ...
        lifecycle_factor, lifecycle_factor * 100);
fprintf('Net EI_CO2       : %.3f kg CO2 / kg fuel\n', EI_CO2);
fprintf('-----------------------------------\n');

%% 1. Time vector (0–100 years)
dt = 0.1;
t  = 0:dt:100;
n  = length(t);

%% 2. CO2 emitted (SAF lifecycle)
E_CO2 = EI_CO2 * cruiseFuel_kg;

%% 3. Atmospheric CO2 impulse response Gx_CO2(t)
%    (Dallara 2011 / PPC slide 28 coefficients)
alpha = [0.067  0.1135  0.152  0.0970  0.041];
tau   = [inf    313.8   79.8   18.8    1.7  ];

Gx_CO2 = zeros(size(t));
for i = 1:length(alpha)
    if isinf(tau(i))
        term = alpha(i) * ones(size(t));
    else
        term = alpha(i) * exp(-t / tau(i));
    end
    Gx_CO2 = Gx_CO2 + term;
end

%% 4. Change in atmospheric CO2 concentration
ppm_conversion_factor = 7.8e12;  % kg CO2 per ppm
DeltaX_CO2 = (E_CO2 / ppm_conversion_factor) .* Gx_CO2;

%% 5. Normalised radiative forcing RF*(t)
X0      = 380;   % background CO2 concentration [ppm]
RF_star = log((X0 + DeltaX_CO2) ./ X0) / log(2);

%% 6. Thermal response function GT(t)     (PPC lecture)
GT = (2.246 / 36.8) * exp(-t / 36.8);

%% 7. Convolution → ΔT(t)
DeltaT = zeros(size(t));
for k = 1:n
    tprime  = t(1:k);
    RFp     = RF_star(1:k);
    lag     = t(k) - tprime;
    GT_lag  = (2.246 / 36.8) * exp(-lag / 36.8);
    DeltaT(k) = sum(GT_lag .* RFp * dt);
end

ATR_trend = zeros(size(t));
for k = 2:n
    ATR_trend(k) = (1 / t(k)) * trapz(t(1:k), DeltaT(1:k));
end

%% 8. ATR100
ATR100 = (1/100) * trapz(t, DeltaT);

%% 9. Display
fprintf('\n------------------------------\n');
fprintf('Fidelity 1 Climate Model — SAF\n');
fprintf('Cruise Fuel Burn : %.1f kg\n',   cruiseFuel_kg);
fprintf('Net CO2 Emitted  : %.1f kg\n',   E_CO2);
fprintf('  (vs kerosene   : %.1f kg  [−%.0f%%])\n', ...
        EI_CO2_combustion * cruiseFuel_kg, (1 - lifecycle_factor) * 100);
fprintf('ATR100           : %.6e K\n', ATR100);
fprintf('------------------------------\n');

%% 10. Plots
figure
plot(t, DeltaT, 'g--', 'LineWidth', 2)
grid on
xlabel('Time (years)')
ylabel('\Delta T (K)')
title('SAF — CO_2 Temperature Response (Fidelity 1)')
legend('\Delta T [K]', 'Location','best')

figure
yyaxis left
plot(t, DeltaT, 'g--', 'LineWidth', 2)
ylabel('\Delta T (K)')

yyaxis right
plot(t, ATR_trend, 'r--', 'LineWidth', 2)
ylabel('ATR (K)')

xlabel('Time (years)')
grid on
title('SAF — CO_2 Temperature Response and ATR Trend (Fidelity 1)')
legend('\Delta T (K)', 'ATR running avg (K)', 'Location','northeast')

end
