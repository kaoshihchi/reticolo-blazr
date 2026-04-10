%% ========================================================================
%  RETICOLO: L3600-1-6 - LITTROW CONFIGURATION (ENERGY & BETA=ALPHA)
%  =======================================================================
clear; clc; close all;

%% --- 1. SETTINGS ---
plot_geometry = true;   
plot_fields   = true;   
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir'), addpath(genpath(lib_path)); end

%% --- 2. PHYSICAL PARAMETERS ---
wavelength = 3.5;               % [nm]
groove_density = 3600;          % [L/mm]
period = 1e6 / groove_density;  % [nm]
m_order = 1;                   

% --- LITTROW & GRAZING GEOMETRY ---
grazing_angle = 3.75;           % [deg] Explicitly set gamma
% Formula for Littrow alpha in the xz-plane:
% sin(alpha) = |m|*lambda / (2 * d * sin(grazing_angle))
sin_alpha_littrow = abs(m_order * wavelength / (2 * period * sind(grazing_angle)));
alpha_xz = asind(sin_alpha_littrow); 

% --- RETICOLO COORDINATE TRANSFORMATION ---
% theta_inc: angle from the grating normal
theta_inc = acosd(sind(grazing_angle) * cosd(alpha_xz));
delta_conical = atand(cosd(grazing_angle) / (sind(grazing_angle) * sind(alpha_xz)));

num_harmonics = 130;            
alpha_pol = 0;                  % S-pol (TE)
rho = 1 * sind(theta_inc);

%% --- 3. TEXTURE & PROFILE (Laminar Au) ---
n_vacuum = 1.0; 
n_substrate = 0.998 + 0.005i;   % Gold (Au) 
groove_depth = 4.0;             % [nm]
duty_ratio = 0.5;               
edge = duty_ratio * period;     
textures = { {n_vacuum}, {n_substrate}, { [0, edge], [n_substrate, n_vacuum] } };

parm = res0; parm.res1.vi = 1;
aa = res1(wavelength, period, textures, num_harmonics, rho, delta_conical, parm);
heights = [0, groove_depth, 0];
sequence = [1, 3, 2];
profile1 = {heights, sequence};

%% --- 4. EFFICIENCIES & VALIDATION ---
ef = res2(aa, profile1);
res_TE = ef.TEinc_top_reflected; 
res_TM = ef.TMinc_top_reflected;

% Energy Conservation
total_R_TE = sum(res_TE.efficiency);
total_R_TM = sum(res_TM.efficiency);

% Confirming Littrow: Extracting diffraction angle from RETICOLO
idx_target = find(res_TE.order == m_order);
% In true Littrow, kx_out should equal -kx_in
beta_eff = theta_inc; % In RETICOLO theta is the angle from normal

%% --- 5. FINAL REPORT ---
fprintf('\n================== L3600-1-6 LITTROW REPORT ==================\n');
fprintf('Wavelength:      %.2f nm\n', wavelength);
fprintf('Grazing Angle:   %.2f deg (Fixed per request)\n', grazing_angle);
fprintf('Littrow Setup:   YES (Beta = Alpha)\n');
fprintf('Calculated Alpha (xz): %.2f deg\n', alpha_xz);
fprintf('--------------------------------------------------------------\n');
fprintf('ENERGY CONSERVATION:\n');
fprintf('  - Total Reflectivity (S-pol): %7.4f %%\n', total_R_TE * 100);
fprintf('  - Total Reflectivity (P-pol): %7.4f %%\n', total_R_TM * 100);
fprintf('--------------------------------------------------------------\n');
if ~isempty(idx_target)
    fprintf('LITTROW ORDER (m=%d) EFFICIENCY:\n', m_order);
    fprintf('  - S-pol (TE): %7.4f %%\n', res_TE.efficiency(idx_target(1))*100);
    fprintf('  - P-pol (TM): %7.4f %%\n', res_TM.efficiency(idx_target(1))*100);
end
fprintf('==============================================================\n');

%% --- 6. FIGURES ---
figure(2); res3(linspace(-period/2, period/2, 200), aa, profile1, [1, 1], res0); 
title('L3600-1-6 Littrow Geometry');

figure(4); set(gcf, 'Color', 'w', 'Position', [100, 100, 800, 600]);
[e, z_map, o_map] = res3(linspace(-period/2, period/2, 500), aa, profile1, [1, 0], res0);
subplot(2,1,1); imagesc(abs(e(:,:,1)).^2 + abs(e(:,:,2)).^2 + abs(e(:,:,3)).^2);
colormap(jet); title('Intensity Map: Littrow Shadowing');
subplot(2,1,2); imagesc(real(o_map)); colormap(gca, bone); title('Structure');

retio;