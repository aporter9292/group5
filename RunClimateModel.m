%% RunClimateModel.m
%  Full pipeline: Size aircraft → Mission Analysis → Fidelity 2 Climate Model
%
%  Usage: scripts.RunClimateModel
%  (run from the root of the group5-TEST folder in MATLAB)

%% -- 1. Aircraft setup (Group Spreadsheet -- Design Freeze 08-Apr-2026) ---
% All values sourced from GDP Group 5 master spreadsheet unless noted.
ADP               = B777.ADP();
ADP.TLAR          = cast.TLAR.Delphinus_6a();
ADP.TLAR.M_c      = 0.85;
ADP.CabinRadius   = 9.5;         % fuselage half-width [m] (19m / 2)
ADP.CabinLength   = 45;          % fuselage length [m]
ADP.V_HT          = 0.75;
ADP.V_VT          = 0.07;
N_e               = 4;           % number of engines    -- spreadsheet (provisional)
ADP.Span          = 79.385;      % wingspan [m]         -- spreadsheet
ADP.WingArea      = 1369.995;    % S_ref [m^2]          -- spreadsheet
ADP.MTOM          = 618.39e3;    % MTOM [kg] = 618.39t  -- spreadsheet
ADP.Mf_Fuel       = 111/618.39;  % fuel fraction         -- spreadsheet (111t block fuel)
ADP.Mf_res        = 0.03;
ADP.Mf_Ldg        = 483/618.39;  % MLM/MTOM = 0.781     -- spreadsheet
ADP.Mf_TOC        = 0.97;

%% -- 2. Size the aircraft -------------------------------------------------
fprintf('Sizing aircraft...\n');
ADP = B777.Size(ADP);

% -- MTOM override ---------------------------------------------------------
% B777 structural mass model gives OEM ~ 180t (correct for tube fuselage).
% BWB OEM should be ~ 309t (pressurised flat centerbody is much heavier).
% Override to design MTOM until structures team updates fuselage.m.
ADP.MTOM = 618.39e3;   % forced to group design value -- pending structures fix
fprintf('MTOM forced to design value: %.0f kg (618.39t)\n\n', ADP.MTOM);

%% ── 3. Mission Analysis → get 9-stage fuel breakdown ────────────────────
fprintf('Running mission analysis...\n');
[BlockFuel, TripFuel, ResFuel, Mf_TOC, MissionTime, cruise_FL, ...
 fuel_stages_kg, range_km, stage_alts_ft] = ...
    B777.MissionAnalysis(ADP, ADP.TLAR.Range, ADP.MTOM);

fprintf('Mission analysis complete.\n');
fprintf('  Block Fuel  = %.0f kg\n', BlockFuel);
fprintf('  Trip Fuel   = %.0f kg\n', TripFuel);
fprintf('  Reserve Fuel= %.0f kg\n', ResFuel);
fprintf('  Cruise FL   = FL%.0f\n\n', cruise_FL);

% Print the 9-stage fuel breakdown
stage_labels = {'Taxi Out','TakeOff+Climb','Cruise','Descent','Landing', ...
                'Contingency','Alternate','Loiter','To Gate'};
fprintf('--- 9-Stage Fuel Breakdown ---\n');
for i = 1:9
    fprintf('  [%d] %-15s : %8.1f kg\n', i, stage_labels{i}, fuel_stages_kg(i));
end
fprintf('  Total (9-stage sum): %.0f kg\n\n', sum(fuel_stages_kg));

%% ── 4. Fidelity 2 Climate Model ──────────────────────────────────────────
fprintf('Running Fidelity 2 climate model...\n');

cruise_alt_ft = cruise_FL * 100;   % FL to feet

[ATR100, RF_total, DeltaT_total, t, E_CO2_Stages, E_CO2_Total, species_ATR] = ...
    cast.eng.fidelity2_climate_CO2( ...
        fuel_stages_kg, ...    % 9-stage fuel [kg]
        cruise_alt_ft,  ...    % cruise altitude [ft]
        stage_alts_ft,  ...    % 9 stage altitudes [ft]
        range_km        ...    % mission range [km]
    );

fprintf('\nClimate model complete.\n');
fprintf('  ATR100 = %.4e K\n', ATR100);

%% ── 5. Fidelity 1 — Kerosene vs SAF ──────────────────────────────────────
fprintf('\n--- Fidelity 1 Comparison (cruise CO2 only) ---\n');
cruiseFuel_kg = fuel_stages_kg(3);   % stage 3 = cruise only

[ATR1_kero] = cast.eng.fidelity1_climate_C02(cruiseFuel_kg);
[ATR1_SAF]  = cast.eng.fidelity1_climate_SAF(cruiseFuel_kg);

fprintf('\nFidelity 1 Summary:\n');
fprintf('  Kerosene ATR100 = %.4e K\n', ATR1_kero);
fprintf('  SAF      ATR100 = %.4e K\n', ATR1_SAF);
fprintf('  SAF saving      = %.1f%%\n',  (1 - ATR1_SAF/ATR1_kero)*100);

%% ── 6. Fidelity 2 — SAF (all species) ────────────────────────────────────
fprintf('\n--- Fidelity 2 Comparison (all species) ---\n');

[ATR2_SAF] = cast.eng.fidelity2_climate_SAF( ...
    fuel_stages_kg, ...   % 9-stage fuel [kg]
    cruise_alt_ft,  ...   % cruise altitude [ft]
    stage_alts_ft,  ...   % 9 stage altitudes [ft]
    range_km        ...   % mission range [km]
);

fprintf('\nFidelity 2 Summary:\n');
fprintf('  Kerosene ATR100 = %.4e K\n', ATR100);
fprintf('  SAF      ATR100 = %.4e K\n', ATR2_SAF);
fprintf('  SAF saving      = %.1f%%\n',  (1 - ATR2_SAF/ATR100)*100);

%% -- 7. Per-Segment Breakdown with Altitude & s(h) (Dallara 2011) ---------
% Shows Meghana that each segment is analysed at its own altitude with
% altitude-dependent scaling factors s(h). s(h)=0 at ground means zero
% non-CO2 climate effect; s(h)=1 at cruise means full effect.
% Reference: Dallara et al. (2011) DOI: 10.2514/1.J050763, Fig. 4

fprintf('\n========================================================\n');
fprintf('  Per-Segment Climate Breakdown (Altitude Dependence)\n');
fprintf('========================================================\n');
fprintf('  Ref: Dallara 2011 — s(h) scales non-CO2 effects by altitude\n');
fprintf('  s(h)=0 at ground (no non-CO2 effect), s(h)=1 at cruise\n\n');

% s(h) reference data (same as in fidelity2_climate_CO2.m)
h_ref   = [0,    3000,  6000,  9000,  11000, 12000];  % metres
s_NOx_r = [0.00, 0.00,  0.20,  0.60,  1.00,  1.10];

stage_alts_m = stage_alts_ft * 0.3048;
s_NOx_seg = max(interp1(h_ref, s_NOx_r, stage_alts_m, 'linear', 'extrap'), 0);

fprintf('  %-15s %10s %10s %8s %12s\n', 'Segment', 'Fuel (kg)', 'Alt (ft)', 's(h)NOx', 'CO2 (kg)');
fprintf('  %s\n', repmat('-', 1, 58));
for i = 1:9
    fprintf('  %-15s %10.1f %10.0f %8.2f %12.1f\n', ...
        stage_labels{i}, fuel_stages_kg(i), stage_alts_ft(i), ...
        s_NOx_seg(i), E_CO2_Stages(i));
end
fprintf('  %s\n', repmat('-', 1, 58));
fprintf('  %-15s %10.1f %10s %8s %12.1f\n', ...
    'TOTAL', sum(fuel_stages_kg), '', '', E_CO2_Total);

% Key insight printout
[~, max_idx] = max(fuel_stages_kg);
fprintf('\n  >> Cruise (segment 3) burns %.1f%% of total fuel at FL%.0f\n', ...
    fuel_stages_kg(3)/sum(fuel_stages_kg)*100, cruise_FL);
fprintf('  >> Ground segments (taxi, landing, to-gate) have s(h)=0\n');
fprintf('     → zero NOx/contrail/soot climate effect despite burning %.1f%% of fuel\n', ...
    (fuel_stages_kg(1)+fuel_stages_kg(5)+fuel_stages_kg(9))/sum(fuel_stages_kg)*100);

%% -- 8. Fleet-Level Scaling ------------------------------------------------
% Single mission ATR100 scaled to annual fleet operations.
% N_fleet from group spreadsheet; flights_per_ac assumes F1 calendar.

fprintf('\n========================================================\n');
fprintf('  Fleet-Level Climate Impact\n');
fprintf('========================================================\n');

N_fleet        = 4;     % number of aircraft -- group spreadsheet
flights_per_ac = 24;    % flights per aircraft per year (F1: ~24 races)
total_flights  = N_fleet * flights_per_ac;

ATR100_fleet_kero = ATR100  * total_flights;
ATR100_fleet_SAF  = ATR2_SAF * total_flights;

fprintf('  Fleet size           : %d aircraft\n', N_fleet);
fprintf('  Flights/aircraft/year: %d\n', flights_per_ac);
fprintf('  Total flights/year   : %d\n', total_flights);
fprintf('\n  Single flight (Kerosene) ATR100 = %.4e K\n', ATR100);
fprintf('  Annual fleet (Kerosene) ATR100 = %.4e K  (x%d)\n', ATR100_fleet_kero, total_flights);
fprintf('  Annual fleet (SAF)      ATR100 = %.4e K  (x%d)\n', ATR100_fleet_SAF, total_flights);
fprintf('  Fleet SAF saving               = %.1f%%\n', (1 - ATR100_fleet_SAF/ATR100_fleet_kero)*100);

fprintf('\n  Annual fleet fuel burn (Kerosene): %.0f t\n', sum(fuel_stages_kg)*total_flights/1000);
fprintf('  Annual fleet CO2 (Kerosene)      : %.0f t\n', E_CO2_Total*total_flights/1000);
fprintf('  Annual fleet CO2 (SAF)           : %.0f t\n', E_CO2_Total*total_flights*0.20/1000);

%% -- 9. Plots --------------------------------------------------------------

% --- Figure 1: Species ATR100 Bar Chart (PPC Slide 32 style) ---
sp_names = {'CO_2', 'H_2O', 'SO_4 (cooling)', 'Soot', ...
            'NOx-CH_4 (cooling)', 'NOx-O_3 short', 'NOx-O_3 long', 'AIC (contrails)'};
sp_vals  = [species_ATR.CO2, species_ATR.H2O, species_ATR.SO4, ...
            species_ATR.soot, species_ATR.NOx_CH4, species_ATR.NOx_O3S, ...
            species_ATR.NOx_O3L, species_ATR.AIC];

figure('Name', 'Species ATR100 Breakdown', 'NumberTitle', 'off');
colours = zeros(length(sp_vals), 3);
for i = 1:length(sp_vals)
    if sp_vals(i) >= 0
        colours(i,:) = [0.85 0.33 0.33];   % red = warming
    else
        colours(i,:) = [0.33 0.50 0.85];   % blue = cooling
    end
end
b = barh(sp_vals, 'FaceColor', 'flat');
b.CData = colours;
set(gca, 'YTickLabel', sp_names, 'YTick', 1:length(sp_names), 'FontSize', 10);
xlabel('ATR_{100} contribution (K)');
title('Climate Impact by Species — Fidelity 2 (Kerosene, single flight)');
xline(0, 'k-', 'LineWidth', 1.5);
grid on;

% --- Figure 2: Per-Segment Fuel Burn Bar Chart with Altitude Labels ---
figure('Name', 'Fuel Burn by Segment', 'NumberTitle', 'off');
bar(fuel_stages_kg/1000, 'FaceColor', [0.2 0.5 0.8]);
set(gca, 'XTickLabel', stage_labels, 'XTick', 1:9, 'FontSize', 9);
xtickangle(30);
ylabel('Fuel Burn (tonnes)');
title(sprintf('Fuel Burn by Flight Segment — BWB (MTOM=%.0ft, L/D=22)', ADP.MTOM/1000));
grid on;
% Add altitude labels on top of each bar
for i = 1:9
    alt_label = sprintf('%.0f ft', stage_alts_ft(i));
    text(i, fuel_stages_kg(i)/1000 + 1.5, alt_label, ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
    text(i, fuel_stages_kg(i)/1000 + 0.5, sprintf('%.1ft', fuel_stages_kg(i)/1000), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

% --- Figure 3: Kerosene vs SAF ATR100 Comparison (grouped bar) ---
figure('Name', 'Kerosene vs SAF Comparison', 'NumberTitle', 'off');
comparison_data = [ATR100, ATR2_SAF; ATR100_fleet_kero, ATR100_fleet_SAF];
b2 = bar(comparison_data);
b2(1).FaceColor = [0.85 0.33 0.33];  % kerosene = red
b2(2).FaceColor = [0.33 0.75 0.45];  % SAF = green
set(gca, 'XTickLabel', {'Single Flight', sprintf('Annual Fleet (%d flights)', total_flights)});
ylabel('ATR_{100} (K)');
title('Climate Impact: Kerosene vs SAF — Fidelity 2');
legend('Kerosene', 'SAF (HEFA)', 'Location', 'northwest');
grid on;
