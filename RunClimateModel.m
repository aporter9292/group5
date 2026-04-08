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
