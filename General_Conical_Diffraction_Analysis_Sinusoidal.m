%% RETICOLO: L3600-1-6 SINUSOIDAL GRATING ANALYSIS
% Grating Type: Holographic (Sinusoidal Grooves) 
% Mounting: Conical (Out-of-Plane) Grazing Incidence
% Target: m = -1 Order

clear; clc; close all;

%% --- 1. SETTINGS & PATH ---
scriptName = mfilename; 
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir'), addpath(genpath(lib_path)); end

%% --- 2. PHYSICAL PARAMETERS ---
wavelength = 10;                % [nm]
groove_density = 3600;          % [L/mm] [cite: 1069]
period = 1e6 / groove_density;  % [nm] (~277.78 nm)
m_order = -1;                   

% --- CONICAL GEOMETRY ---
grazing_angle = 3.75;           % [deg] gamma
sin_alpha_xz = abs(m_order * wavelength / (2 * period * sind(grazing_angle)));
if sin_alpha_xz > 1, error('Order is evanescent'); end
alpha_xz = asind(sin_alpha_xz); 

% RETICOLO Coordinate Transformation
theta_inc = acosd(sind(grazing_angle) * cosd(alpha_xz));
delta_conical = atand(cosd(grazing_angle) / (sind(grazing_angle) * sind(alpha_xz)));
num_harmonics = 130;            
alpha_pol = 0;                  
rho = 1 * sind(theta_inc);

%% --- 3. TEXTURE DEFINITION (Sinusoidal Staircase) ---
n_vacuum = 1.0; 
n_substrate = 0.985 + 0.015i;   % Nickel (Ni) at 10nm (Approximation)

% Sinusoidal Parameters
groove_depth = 15.0;            % [nm] h 
num_steps = 20;                 % Number of slices to approximate the sine wave
step_height = groove_depth / num_steps;

% Initialize textures cell array
% textures{1} = Vacuum, textures{2} = Substrate, 3:end = Sinusoid slices
textures = cell(1, num_steps + 2);
textures{1} = {n_vacuum}; 
textures{2} = {n_substrate};

for j = 1:num_steps
    % Calculate the center of the current vertical slice
    z_mid = (j - 0.5) * step_height;
    % Solve for the width of the material at height z using: 
    % z = (h/2) * (1 + cos(2*pi*x/period))
    % Relative width (w/d) = acos(2*z/h - 1) / pi
    rel_width = acos(2 * z_mid / groove_depth - 1) / pi;
    edge = rel_width * period;
    
    % Each slice has a ridge of width 'edge' and vacuum
    textures{j+2} = { [0, edge], [n_substrate, n_vacuum] };
end

parm = res0; parm.res1.vi = 1;
aa = res1(wavelength, period, textures, num_harmonics, rho, delta_conical, parm);

%% --- 4. PROFILE & COMPUTATION ---
% Build the sequence: Vacuum top -> Sinusoid slices -> Substrate base
heights = [0, repmat(step_height, 1, num_steps), 0];
sequence = [1, 3:(num_steps+2), 2];
profile1 = {heights, sequence};

ef = res2(aa, profile1);
res_TE = ef.TEinc_top_reflected; 

total_R_TE = sum(res_TE.efficiency);
absorption_TE = (1 - total_R_TE) * 100;

idx_target = find(res_TE.order == m_order);
if ~isempty(idx_target)
    kx_out = res_TE.K(idx_target(1), 1); 
    beta_xz_out = asind(kx_out / sind(grazing_angle));
    eff_te = res_TE.efficiency(idx_target(1)) * 100;
else
    beta_xz_out = NaN; eff_te = 0;
end

%% --- 5. REPORT SUMMARY ---
fprintf('\n================== EXPERIMENTAL DATA SUMMARY ==================\n');
fprintf('Profile Type: Sinusoidal (Staircase approx.)\n');
fprintf('Input Parameters (Experimental Layout - Out-of-Plane):\n');
fprintf('  - Grazing Angle (gamma):  %5.2f deg\n', grazing_angle);
fprintf('  - Incident Alpha (xz):    %5.2f deg\n', alpha_xz);
fprintf('  - Wavelength (lambda):    %5.2f nm\n', wavelength);
fprintf('--------------------------------------------------------------\n');
if ~isempty(idx_target)
    fprintf('Results for Target Order m = %d:\n', m_order);
    fprintf('  - TE Efficiency:            %8.4f %%\n', eff_te);
    fprintf('  - Diffracted Beta (xz):     %8.4f deg (Target: %.2f)\n', beta_xz_out, alpha_xz);
end
fprintf('--------------------------------------------------------------\n');
fprintf('System Health (Energy Balance):\n');
fprintf('  - Total Reflectivity (TE):  %7.4f %%\n', total_R_TE*100);
fprintf('  - Total Absorption (TE):    %7.4f %%\n', absorption_TE);
fprintf('==============================================================\n');

%% --- 6. FIGURES ---
% Figure 1: Geometry
figure('Name', 'Sinusoidal Geometry');
parm_geom = res0; parm_geom.res3.trace = 1;
res3(linspace(-period/2, period/2, 200), aa, profile1, [1, 1], parm_geom); 
title('Figure 1: Sinusoidal Groove Profile Approximation');

% Figure 2: Efficiency
figure('Name', 'Efficiency Analysis');
target_orders = -3:3; te_plot_eff = zeros(size(target_orders));
for i = 1:length(target_orders)
    idx = find(res_TE.order == target_orders(i));
    if ~isempty(idx), te_plot_eff(i) = res_TE.efficiency(idx(1))*100; end
end
bar(target_orders, te_plot_eff);
xlabel('Order'); ylabel('Efficiency %'); title('Figure 2: Efficiency vs Order (Sinusoidal)'); grid on;

% Figure 3: Shadowing Map
figure('Name', 'Field Shadowing');
[e, z_map, x_map] = res3(linspace(-period/2, period/2, 500), aa, profile1, [1, 0], res0);
Int = abs(e(:,:,1)).^2 + abs(e(:,:,2)).^2 + abs(e(:,:,3)).^2;
imagesc(x_map(1,:), z_map(:,1), Int); colormap(jet); colorbar; axis tight;
xlabel('X [nm]'); ylabel('Z [nm]');
title('Figure 3: Field Intensity |E|^2 (Sinusoidal Shadowing)');

retio;

%% --- 7. AUTO-PUBLISH ---
if ~any(strcmpi({dbstack.name}, 'publish'))
    if ~exist('Reports', 'dir'), mkdir('Reports'); end
    publish([scriptName, '.m'], struct('format','pdf','outputDir','Reports'));
end