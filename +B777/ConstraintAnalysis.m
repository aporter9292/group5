function [ThrustToWeightRatio,WingLoading] = ConstraintAnalysis(obj)

%% estimate T/W and W/S from constraint analysis
% Input "obj" will be the ADP class file
% ------------ Environmental Constants -------------
g = 9.81; % kgm/s2
mu = 0.04;

c_ceiling = 295.2; % m/s
    % Speed of sound in air at rho_ceiling
c_cruise = 301.8; % m/s
    % Speed of sound in air at rho_cruise

rho_ISA = 1.225; % kg/m3
    % International sealevel air condition
rho_MEX = 0.8936; % kg/m3
    % Air condition at 2,230 m at 28 Celsius
rho_BOG = 0.8821; % kg/m3
    % Air condition at 2,548 m at 20 Celsius
rho_ceiling = 0.365; % kg/m3
    % Air condition at 36,000 ft at -56.3 Celsius
rho_cruise = 0.442; % kg/m3
    % Air condition at 31,000 ft at -46.4 Celsius

sigma_MEX = rho_MEX/rho_ISA;
sigma_BOG = rho_BOG/rho_ISA;


% ------------ Temporary Aero Config. -------------
AR_pre = 10;
LD_max_pre = 17.5;


% ------------ Temporary Mass Config. -------------
beta_pre = 0.79; % Ratio of MLandM over MTOM


% --------------- Landing Constraint ---------------
% beta = MLandM/MTOM; MLM/MTOM ratio to be updated by MissionAnalysis
beta = beta_pre;

WS_max_ld = (1/2)*rho_BOG*( ...
    ((obj.TLAR.V_app)/1.3)^2 ...
    )*(obj.Cl_max + obj.Delta_Cl_ld)/beta;

WS_design = 1.0*WS_max_ld; % safety limit at 100%

% ---------- Landing Distance Constraint -----------
% This constraint can be deactivated
WS_max_ld_dist = ( ...
    (obj.TLAR.GroundRun_NCE - obj.TLAR.ApproachRun) ...
    *sigma_BOG*(obj.Cl_max + obj.Delta_Cl_ld))*g/(5*beta);

if WS_max_ld_dist < WS_design
    WS_design = WS_max_ld_dist;
end

% -------- Cruising Wing Loading Constraint ---------
% AR = obj.Span^2/obj.WingArea; % Aspect ratio to be updated by AeroPolar
AR = AR_pre;

WS_max_cruise_wingload = (1/2)*rho_cruise*( ...
    (c_cruise*obj.TLAR.M_c)^2 ...
    )*(pi*AR*obj.e*obj.CD0/3)^(0.5);

if WS_max_cruise_wingload < WS_design
    WS_design = WS_max_cruise_wingload;
end


% ------- Loitering Wing Loading Constraint --------
WS_max_loiter_wingload = (1/2)*rho_ISA*( ...
    obj.TLAR.V_loiter^2 ...
    )*(pi*AR*obj.e*obj.CD0)^(0.5);

% Loitering should not be a constraint
%{
if WS_max_loiter_wingload < WS_design
    WS_design = WS_max_loiter_wingload;
end
%}


% ---------- Service Ceiling Constraint -----------
WS_max_ceiling = (1/2)*rho_ceiling*( ...
    (c_ceiling*obj.TLAR.M_c)^2 ...
    )*obj.CL_cruise;

if WS_max_ceiling < WS_design
    WS_design = WS_max_ceiling;
end


% -------------- Take-off Constraint ---------------
CDi_to = ((obj.Cl_max + obj.Delta_Cl_to)^2)/pi/AR/obj.e_to_ld;

TW_min_to = (1.21/( ...
    g*rho_BOG*(obj.Cl_max + obj.Delta_Cl_to)*obj.TLAR.GroundRun_NCE ...
    ))*WS_design + (1/2)*( ...
    obj.CD0 + obj.CD_flap_to + obj.CD_gear + CDi_to ...% + obj.CDi
    ) + (1/2)*mu;

TW_design = TW_min_to;


% -------------- Cruising Constraint ---------------
% S_wet_tot = ; %
% S_ref_wing = ; %

% LD_max = 15.5*(AR*S_ref_wing/S_wet_tot)^0.5; %
LD_max = LD_max_pre;

% LD_cruise = obj.CL_cruise/(obj.CD0 + obj.CDi);

TW_min_cruise = (0.866*LD_max)^(-1);

if TW_min_cruise > TW_design
    TW_design = TW_min_cruise;
end


% ------------ OEI Climbing Constraint --------------
N_engine = 2;
V_ratio = 0.024;
LD_climb = 0.6*LD_max;
gamma = 0.92;

% K = ;

% V_hori = ( ...
%     ((3*rho_MEX*obj.CD0)^(-1))*WS_design*( ...
%     TW_design + (TW_design^2 + 12*obj.CD0*K)^0.5 ...
%     ) ...
%     )^0.5 ;

% V_vert = V_hori*TW_design - ( ...
%     rho_MEX*(V_hori^3)*obj.CD0/(2*WS_design) ...
%     ) - (2*K/rho_MEX/V_hori)*WS_design;

TW_min_climb_OEI = (1/gamma)*( ...
    N_engine/(N_engine - 1) ...
    )*(LD_climb^(-1) + V_ratio);

if TW_min_climb_OEI > TW_design
    TW_design = TW_min_climb_OEI;
end


% ---------- Take-off Distance Constraint -----------
TW_min_todistance = (((445/SI.lb_over_ft2)*g*sigma_MEX* ...
    (obj.Cl_max + obj.Delta_Cl_to))^(-1))*WS_design;

if TW_min_todistance > TW_design
    TW_design = TW_min_todistance;
end

% ----------- Sustain Turning Constraint ------------
TW_min_susturn = 2*1.3*(obj.CD0/pi/AR/obj.e)^0.5;

if TW_min_susturn > TW_design
    TW_design = TW_min_susturn;
end


% --------------- Convergence Trial ----------------
% WS_design = 5100; % WS = 72 m, FL = 63.7 m, Payload = 108000 kg

% --------- Update with constraint analysis ---------
obj.ThrustToWeightRatio = TW_design;
% obj.ThrustToWeightRatio = (513e3*2)/(347815*9.81);
obj.WingLoading = WS_design;
% obj.WingLoading = (347815*9.81)/(473.3*cosd(31.6));
% obj.WingLoading = (347815*9.81)/436.8;

% set Wing Area and Thrust
% SweepQtrChord = real(acosd(0.75.*obj.Mstar./obj.TLAR.M_c)); % quarter chord sweep angle
% obj.WingArea = obj.MTOM*9.81/obj.WingLoading/cosd(SweepQtrChord);
obj.WingArea = obj.MTOM*9.81/obj.WingLoading;
obj.Thrust = obj.ThrustToWeightRatio * obj.MTOM * 9.81;


%{
% ------------ T/W Constraint Arrays ------------
WS_array = linspace(0, 10000, 100);

plot_TW_min_to = (1.21/( ...
    g*rho_MEX*(obj.Cl_max + obj.Delta_Cl_to)) ...
    ).*WS_array + (1/2)*( ...
    obj.CD0 + obj.CD_flap_to + obj.CD_gear + CDi_to ...% + obj.CDi
    ) + (1/2)*mu;
% plot_TW_min_cruise = ones(size(WS_array))*TW_min_cruise;
% plot_TW_min_climb_OEI = ones(size(WS_array))*TW_min_climb_OEI;
plot_TW_min_todistance = (((445/SI.lb_over_ft2)*sigma_MEX* ...
    (obj.Cl_max + obj.Delta_Cl_to))^(-1)).*WS_design;
% plot_TW_min_susturn = ones(size(WS_array))*TW_min_susturn;


% --------- Constraint Analysis Plot ---------
% Plot definition
fig = figure("Name", "Constraint Analysis", "Color", "w");
hold on; grid on;

% W/S constraints
xline( ...
    WS_max_ld, "r--", "LineWidth", 2, ...
    "DisplayName", "Landing");
xline( ...
    WS_max_ld_dist, "g--", "LineWidth", 2, ...
    "DisplayName", "Landing Distance");
xline( ...
    WS_max_cruise_wingload, "b--", "LineWidth", 2, ...
    "DisplayName", "Cruise Wing Load");
xline(WS_max_loiter_wingload, "c--", "LineWidth", 2, ...
    "DisplayName", "Loiter Wing Load");
xline(WS_max_ceiling, "m--", "LineWidth", 2, ...
    "DisplayName", "Ceiling");

% T/W constraints
plot( ...
    WS_array, plot_TW_min_to, "r", "LineWidth", 2, ...
    "DisplayName", "Take-Off");
yline( ...
    TW_min_cruise, "g", "LineWidth", 2, ...
    "DisplayName", "Cruising");
yline( ...
    TW_min_climb_OEI, "b", "LineWidth", 2, ...
    "DisplayName", "Climbing (OEI)");
plot( ...
    WS_array, plot_TW_min_todistance, "c", "LineWidth", 2, ...
    "DisplayName", "TO Distance");
yline( ...
    TW_min_susturn, "m", "LineWidth", 2, ...
    "DisplayName", "Turning (Sustained)");

% Best constrained point
plot( ...
    WS_design, TW_design, "p", ...
    "MarkerSize", 15, ...
    "MarkerFaceColor", "y", ...
    "MarkerEdgeColor", "k", ...
    "DisplayName", "Design Point");

% Release plot
xlabel("W/S Ratio [Nm^-2]");
ylabel("T/W Ratio [N/N]");
legend("Location", "northwest");
xlim([0 8000]);
ylim([0 0.5]);
hold off;

% Save plot
saveas(fig, "Constraint_Diagram.png");
%}
end
