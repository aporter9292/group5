function [ATR100, RF_star, DeltaT, t] = fidelity1_climate_Kerosene(cruiseFuel_kg)

% ============================================================
% Fidelity 1 Climate Model
% Cruise phase only
% CO2 emissions only
%
% Uses equations directly from the PPC Engineer lecture
% ============================================================


%% ------------------------------------------------------------
% 1. Time vector (0–100 years)
% ------------------------------------------------------------
dt = 0.1;                 % time resolution [years]
t = 0:dt:100;
n = length(t);


%% ------------------------------------------------------------
% 2. Convert cruise fuel burn → CO2 emitted
% ------------------------------------------------------------
EI_CO2 = 3.16;            % emission index [kg CO2 / kg fuel]

E_CO2 = EI_CO2 * cruiseFuel_kg;


%% ------------------------------------------------------------
% 3. Atmospheric CO2 impulse response Gx_CO2(t)
%    coefficients from slide 28
% ------------------------------------------------------------

alpha = [0.067 0.1135 0.152 0.0970 0.041];
tau   = [inf 313.8 79.8 18.8 1.7];

Gx_CO2 = zeros(size(t));

for i = 1:length(alpha)

    if isinf(tau(i))
        term = alpha(i) * ones(size(t));
    else
        term = alpha(i) * exp(-t/tau(i));
    end

    Gx_CO2 = Gx_CO2 + term;

end


%% ------------------------------------------------------------
% 4. Change in atmospheric CO2 concentration
% ------------------------------------------------------------
% 1 ppm of CO2 in the atmosphere = ~7.8e12 kg
ppm_conversion_factor = 7.8e12;
DeltaX_CO2 = (E_CO2 / ppm_conversion_factor) .* Gx_CO2;
% The equation on the slides includes an integral however we 
% can ignore this is and treat 

%% ------------------------------------------------------------
% 5. Normalised radiative forcing RF*(t)
% ------------------------------------------------------------

X0 = 380;   % background CO2 concentration (ppm)

RF_star = log((X0 + DeltaX_CO2) ./ X0) / log(2);


%% ------------------------------------------------------------
% 6. Thermal response function GT(t)
%    equation provided in lecture
% ------------------------------------------------------------

GT = (2.246/36.8) * exp(-t/36.8);

%% ------------------------------------------------------------
% 7. Convolution to compute temperature response
% ------------------------------------------------------------
DeltaT = zeros(size(t));
for k = 1:n
    tprime = t(1:k);                  % all past times up to current time
    RFp    = RF_star(1:k);            % RF* at those past times

    lag = t(k) - tprime;             % (t - t')
    GT_lag = (2.246/36.8) * exp(-lag/36.8);

    A = GT_lag .* RFp * dt;          % elementwise contribution array
    DeltaT(k) = sum(A);              % sum of all past contributions
end

ATR_trend = zeros(size(t));

for k = 2:n
    ATR_trend(k) = (1 / t(k)) * trapz(t(1:k), DeltaT(1:k));
end

% conv_result = conv(RF_star, GT) * dt;
% 
% DeltaT = conv_result(1:length(t));

% 
% for t = t(0):1:t(101)
    

%% ------------------------------------------------------------
% 8. Compute ATR100
% ------------------------------------------------------------

ATR100 = (1/100) * trapz(t, DeltaT);


%% ------------------------------------------------------------
% 9. Display results
% ------------------------------------------------------------

fprintf('\n------------------------------\n');
fprintf('Fidelity 1 Climate Model\n');
fprintf('Cruise Fuel Burn : %.1f kg\n', cruiseFuel_kg);
fprintf('CO2 Emitted      : %.1f kg\n', E_CO2);
fprintf('ATR100           : %.6e K\n', ATR100);
fprintf('------------------------------\n');


%% ------------------------------------------------------------
% 10. Optional plots
% ------------------------------------------------------------

figure
plot(t, DeltaT, 'b--', 'LineWidth', 2)
grid on
xlabel('Time (years)')
ylabel('\Delta T (K)')
title('Kerosene — CO_2 Temperature Response (Fidelity 1)')
legend('\Delta T [K]', 'Location','best')

figure
yyaxis left
plot(t, DeltaT, 'b--', 'LineWidth', 2)
ylabel('\Delta T (K)')

yyaxis right
plot(t, ATR_trend, 'r--', 'LineWidth', 2)
ylabel('ATR (K)')

xlabel('Time (years)')
grid on
title('Kerosene — CO_2 Temperature Response and ATR Trend (Fidelity 1)')
legend('\Delta T (K)', 'ATR running avg (K)', 'Location','northeast')

end