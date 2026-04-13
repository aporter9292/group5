clc
clear
close all

%% ==============================
% 🔧 USER CONTROL (MAX GEOMETRY)
% ===============================
lambda = 1.2;          
Vz = 3;                
xt = 0.16;             

% MAX realistic design choices
gear_height = 4.0;          % Maximum feasible height (m)
mlg_ref = 28.0;             % Aft reposition (m)

%% ==============================
% Aircraft Inputs
% ===============================
MTOM = 618000;          
MLM  = 483000;          
aircraft_length = 45;   
X_CG = 21.47;           
CG_height = 3;          

%% ==============================
% Tyre + Shock Inputs
% ===============================
tyre_diameter = 1.27;   
tyre_width = 0.52;      
tyre_radius = tyre_diameter / 2;

shock_stroke_ref = 0.5; % reference

%% ==============================
% Landing Gear Layout (AFT CLUSTERED)
% ===============================
track_width = 14;
half_track = track_width / 2;

nose_x = 4.5;
nose_y = [-0.7 0.7];

% New optimized MLG positions (clustered aft)
mlg_x = [25 26.5 28 29.5 31];

mlg_y_left  = -half_track;
mlg_y_right =  half_track;

%% ==============================
% Build Positions
% ===============================
gear_positions = [];

% Nose gear
for i = 1:length(nose_y)
    gear_positions = [gear_positions; nose_x nose_y(i)];
end

% Left main gear
for i = 1:length(mlg_x)
    gear_positions = [gear_positions; mlg_x(i) mlg_y_left];
end

% Right main gear
for i = 1:length(mlg_x)
    gear_positions = [gear_positions; mlg_x(i) mlg_y_right];
end

%% ==============================
% Tail-strike Geometry
% ===============================
L_tail = aircraft_length - mlg_ref;

theta_tailstrike = atan(gear_height / L_tail) * 180/pi;

%% ==============================
% Shock Absorber Physics
% ===============================
g = 9.81;

xs = ((MLM * Vz^2)/(2 * lambda * MLM * g) - 0.5 * xt) / 0.75;

%% ==============================
% MASS MODEL (UPDATED)
% ===============================
mLG_base = 0.0445 * MTOM;

% Reference geometry
h_ref = tyre_radius + shock_stroke_ref + 2.0;

% Scaling factors
k_height = 0.5;
k_stroke = 0.3;

% NEW mass with height + stroke effects
mLG = mLG_base * (gear_height / h_ref)^k_height * (xs / shock_stroke_ref)^k_stroke;

% Split mass
main_gear_mass = 0.9 * mLG;
nose_gear_mass = 0.1 * mLG;

%% ==============================
% Loads
% ===============================
main_wheels = 20;
main_load = 0.9 * MLM;
load_per_wheel = main_load / main_wheels;

%% ==============================
% Stability
% ===============================
theta_turnover = atan(CG_height / half_track) * 180/pi;

tipback_distance = mlg_ref - X_CG;
theta_tipback = atan(CG_height / tipback_distance) * 180/pi;

%% ==============================
% DISPLAY RESULTS
% ===============================
disp('==============================')
disp('MAX GEOMETRY CONFIGURATION')

disp(' ')
disp('--- GEOMETRY ---')
disp(['Gear Height (m): ', num2str(gear_height)])
disp(['MLG Reference Position (m): ', num2str(mlg_ref)])
disp(['Tail Distance (m): ', num2str(L_tail)])
disp(['Tail-strike Angle (deg): ', num2str(theta_tailstrike)])

disp(' ')
disp('--- MASS ---')
disp(['Total Landing Gear Mass (kg): ', num2str(mLG)])
disp(['Main Landing Gear Mass (kg): ', num2str(main_gear_mass)])
disp(['Nose Landing Gear Mass (kg): ', num2str(nose_gear_mass)])

disp(' ')
disp('--- SHOCK ---')
disp(['Shock Stroke (m): ', num2str(xs)])

disp(' ')
disp('--- STABILITY ---')
disp(['Turnover Angle (deg): ', num2str(theta_turnover)])
disp(['Tip-back Angle (deg): ', num2str(theta_tipback)])

disp(' ')
disp('--- LOAD ---')
disp(['Load per wheel (kg): ', num2str(load_per_wheel)])

disp(' ')
disp('--- POSITIONS (x,y) ---')
disp(gear_positions)

%% ==============================
% PLOT
% ===============================
figure
hold on
grid on
axis equal

scatter(gear_positions(:,1), gear_positions(:,2), 120, 'filled')

plot([0 aircraft_length],[0 0],'k--','LineWidth',1.5)

xlabel('Aircraft Length (m)')
ylabel('Lateral Position (m)')
title('Optimized Landing Gear Layout (Max Geometry)')

xlim([0 aircraft_length])
ylim([-10 10])

hold off
%% ==============================
% FULL 3D BWB + REAL LANDING GEAR
% ===============================
figure(2)
clf
hold on
grid on
axis equal
view(3)

title('3D BWB Aircraft with Real Landing Gear')

%% ==============================
% BWB GEOMETRY (FROM YOUR PLANFORM)
% ===============================
span = 79;
half_span = span/2;

% Span stations
y_stations = [0 0.05 0.25 0.35 0.65 1] * half_span;

% Chord lengths (C1 → C6)
chord = [45 40 22.6 22.6 13.3 7.2];

% Leading edge positions (IMPORTANT)
x_le = [0 1 6 10 18 25];

X_body = [];
Y_body = [];
Z_body = [];

for i = 1:length(y_stations)
    
    y = y_stations(i);
    c = chord(i);
    x0 = x_le(i);
    
    x_line = linspace(x0, x0 + c, 50);
    
    % smooth thickness distribution
    t = 0.08 * c;
    z_line = -t * (1 - (x_line - x0)/c).^2;
    
    X_body = [X_body; x_line];
    Y_body = [Y_body; y*ones(size(x_line))];
    Z_body = [Z_body; z_line];
end

% Mirror
X_full = [X_body; X_body];
Y_full = [Y_body; -Y_body];
Z_full = [Z_body; Z_body];

surf(X_full, Y_full, Z_full, ...
    'FaceAlpha',0.85, ...
    'EdgeColor','none')

colormap([0.75 0.75 0.8])

%% ==============================
% FULL 3D BWB + LANDING GEAR + MARKERS
% ===============================
figure(2)
clf
hold on
grid on
axis equal
view(3)

title('3D BWB Aircraft with Landing Gear')

%% ==============================
% BWB INPUT DATA
% ===============================
span = 79;
half_span = span/2;

y_stations = [0 0.05 0.25 0.35 0.65 1] * half_span;
chord      = [45 40 22.6 22.6 13.3 7.2];
x_le       = [0 1 6 10 18 25];

%% ==============================
% SMOOTH BWB SURFACE
% ===============================
[X_mesh, Y_mesh] = meshgrid(linspace(0,45,80), linspace(-half_span,half_span,100));
Z_mesh = NaN(size(X_mesh));

for i = 1:size(Y_mesh,1)
    
    y = abs(Y_mesh(i,1));
    
    c  = interp1(y_stations, chord, y, 'linear','extrap');
    x0 = interp1(y_stations, x_le, y, 'linear','extrap');
    
    for j = 1:size(X_mesh,2)
        
        x = X_mesh(i,j);
        
        if x >= x0 && x <= (x0 + c)
            
            t = 0.08 * c;
            Z_mesh(i,j) = -t * (1 - (x - x0)/c)^2;
        end
        
    end
end

surf(X_mesh, Y_mesh, Z_mesh, ...
    'FaceAlpha',0.9,'EdgeColor','none')

colormap([0.75 0.75 0.8])

%% ==============================
% WHEEL FUNCTION (CYLINDER)
% ===============================
function draw_wheel(x,y,z,r,width)
theta = linspace(0,2*pi,30);
w = linspace(-width/2,width/2,2);

[T,W] = meshgrid(theta,w);

X = r*cos(T) + x;
Y = r*sin(T) + y;
Z = W + z;

surf(X,Y,Z,'EdgeColor','none','FaceColor',[0.05 0.05 0.05])
end

%% ==============================
% LANDING GEAR
% ===============================
z_attach = -1;

% ===== NOSE GEAR =====
for i = 1:length(nose_y)
    
    x = nose_x;
    y = nose_y(i);
    
    plot3([x x],[y y],[z_attach gear_height],'k','LineWidth',3)
    draw_wheel(x,y,z_attach,tyre_radius,tyre_width)
end

% ===== MAIN GEAR =====
bogie_length = 2.0;
num_wheels = 4;

for i = 1:length(mlg_x)
    
    for side = [-1 1]
        
        x = mlg_x(i);
        y = side * half_track;
        
        plot3([x x],[y y],[z_attach gear_height],'k','LineWidth',3)
        
        x_bogie = linspace(x - bogie_length/2, x + bogie_length/2, num_wheels);
        
        plot3(x_bogie, y*ones(size(x_bogie)), ...
              z_attach*ones(size(x_bogie)), 'k','LineWidth',4)
        
        for j = 1:num_wheels
            draw_wheel(x_bogie(j), y, z_attach, tyre_radius, tyre_width)
        end
    end
end

%% ==============================
% MARK C1 TO C6
% ===============================
labels = {'C1','C2','C3','C4','C5','C6'};

for i = 1:length(y_stations)
    
    y = y_stations(i);
    x0 = x_le(i);
    
    plot3(x0, y, 0,'ro','MarkerFaceColor','r')
    plot3(x0,-y, 0,'ro','MarkerFaceColor','r')
    
    text(x0, y, 1, labels{i},'Color','yellow','FontWeight','bold')
    text(x0,-y,1, labels{i},'Color','yellow','FontWeight','bold')
end

%% ==============================
% CG MARKER
% ===============================
plot3(X_CG,0,1,'go','MarkerSize',10,'MarkerFaceColor','g')
text(X_CG,0,2,'CG','Color','green','FontSize',12)

%% ==============================
% GROUND
% ===============================
[Xg,Yg] = meshgrid(0:5:aircraft_length, -10:2:10);
Zg = -0.01 * ones(size(Xg));

surf(Xg,Yg,Zg,'FaceAlpha',0.1,'EdgeColor','none')

%% ==============================
% AXIS
% ===============================
xlabel('X (Length)')
ylabel('Y (Width)')
zlabel('Z (Height)')

xlim([0 aircraft_length])
ylim([-half_span half_span])
zlim([-5 gear_height+2])

hold off