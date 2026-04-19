function [MassPack, LGPack] = LandingGear_BWB_Jeya(PlanformPack, MassPack)
% LANDINGGEAR
% Landing gear module for BWB sizing code integration

%% ==============================
% USER CONTROL / ASSUMPTIONS
% ===============================
lambda = 1.2;
Vz = 3.0;
xt = 0.16;

gear_height = 4.0;      % m
mlg_ref = 28.0;         % m

%% ==============================
% INPUTS FROM PACKS
% ===============================
MTOM = PlanformPack.MTOM;
MLM  = MassPack.MLM;
X_CG = MassPack.X_CG;

% Use pack values if available, otherwise defaults
if isfield(MassPack, 'CG_height')
    CG_height = MassPack.CG_height;
else
    CG_height = 3.0;
end

if isfield(PlanformPack, 'L_f')
    aircraft_length = PlanformPack.L_f;
else
    aircraft_length = 45.0;
end

%% ==============================
% TYRE + SHOCK INPUTS
% ===============================
tyre_diameter = 1.27;
tyre_width = 0.52;
tyre_radius = tyre_diameter / 2;

shock_stroke_ref = 1.2;

%% ==============================
% LANDING GEAR LAYOUT
% ===============================
track_width = 14.0;
half_track = track_width / 2;

nose_x = 4.5;
nose_y = [-0.7 0.7];

mlg_x = [25 26.5 28 29.5 31];
mlg_y_left  = -half_track;
mlg_y_right =  half_track;

%% ==============================
% BUILD POSITIONS
% ===============================
gear_positions = [];

% Nose gear
for i = 1:length(nose_y)
    gear_positions = [gear_positions; nose_x nose_y(i)]; %#ok<AGROW>
end

% Left main gear
for i = 1:length(mlg_x)
    gear_positions = [gear_positions; mlg_x(i) mlg_y_left]; %#ok<AGROW>
end

% Right main gear
for i = 1:length(mlg_x)
    gear_positions = [gear_positions; mlg_x(i) mlg_y_right]; %#ok<AGROW>
end

%% ==============================
% TAIL-STRIKE GEOMETRY
% ===============================
L_tail = aircraft_length - mlg_ref;
theta_tailstrike = atan(gear_height / L_tail) * 180 / pi;

%% ==============================
% SHOCK ABSORBER PHYSICS
% ===============================
g = 9.81;
xs = ((MLM * Vz^2) / (2 * lambda * MLM * g) - 0.5 * xt) / 0.75;

%% ==============================
% MASS MODEL
% ===============================
mLG_base = 0.06400108 * MTOM;

h_ref = tyre_radius + shock_stroke_ref + 2.0;

k_height = 0.5;
k_stroke = 0.3;

mLG = mLG_base * (gear_height / h_ref)^k_height * (xs / shock_stroke_ref)^k_stroke;

main_gear_mass = 0.9 * mLG;
nose_gear_mass = 0.1 * mLG;

%% ==============================
% LOADS
% ===============================
main_wheels = 20;
nose_wheels = 4;

main_load = 0.9 * MLM;
load_per_wheel = main_load / main_wheels;

%% ==============================
% STABILITY
% ===============================
theta_turnover = atan(CG_height / half_track) * 180 / pi;

tipback_distance = mlg_ref - X_CG;
theta_tipback = atan(CG_height / tipback_distance) * 180 / pi;

%% ==============================
% WRITE OUTPUTS TO LGPACK
% ===============================
LGPack.mLG = mLG;
LGPack.main_mass = main_gear_mass;
LGPack.nose_mass = nose_gear_mass;

LGPack.theta_tailstrike = theta_tailstrike;
LGPack.theta_tipback = theta_tipback;
LGPack.theta_turnover = theta_turnover;

LGPack.load_per_wheel = load_per_wheel;

LGPack.gear_positions = gear_positions;
LGPack.mlg_ref = mlg_ref;
LGPack.mlg_x = mlg_x;
LGPack.mlg_y_left = mlg_y_left;
LGPack.mlg_y_right = mlg_y_right;

LGPack.nose_x = nose_x;
LGPack.nose_y = nose_y;

LGPack.gear_height = gear_height;
LGPack.compressed_height = gear_height - xs;

LGPack.shock_stroke = xs;
LGPack.lambda = lambda;
LGPack.Vz = Vz;
LGPack.xt = xt;

LGPack.track_width = track_width;
LGPack.half_track = half_track;

LGPack.main_wheels = main_wheels;
LGPack.nose_wheels = nose_wheels;

LGPack.tyre_diameter = tyre_diameter;
LGPack.tyre_width = tyre_width;
LGPack.tyre_radius = tyre_radius;

LGPack.tail_distance = L_tail;
LGPack.main_load = main_load;

LGPack.tailstrike_ok = theta_tailstrike < 15;
LGPack.tipback_ok = theta_tipback > theta_tailstrike;
LGPack.turnover_ok = theta_turnover < 63;

%% ==============================
% UPDATE MASSPACK
% ===============================
MassPack.LG = mLG;

% Only uncomment this if landing gear mass is NOT already included in OEW
% MassPack.OEW = MassPack.OEW + mLG;

end