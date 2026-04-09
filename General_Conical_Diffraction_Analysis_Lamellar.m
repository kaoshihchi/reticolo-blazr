%% ========================================================================
%  RETICOLO: LAMINAR REPLICA GRATING - PART L3600-1-6 (ENERGY CHECK)
%  =======================================================================
clear; clc; close all;

%% --- 1. SETTINGS & SWITCHES ---
plot_textures = false;  
plot_geometry = true;   
plot_fields   = true;   
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir'), addpath(genpath(lib_path)); end

%% --- 2. PHYSICAL PARAMETERS (L3600-1-6 Specifications) ---
% Grating Design: 3600 grooves/mm for 1-6nm range 
wavelength = 3.5;               % [nm] Mid-range target 
groove_density = 3600;          % [L/mm] N value 
period = 1e6 / groove_density;  % [nm] d ~ 277.78 nm [cite: 59, 1096]
m_order = -1;                   

% Mounting Parameters: alpha = 88.60 deg 
alpha_inc = 88.60;              
theta_inc = alpha_inc;          
delta_conical = 0;              

% Simulation Precision
num_harmonics = 130;            % High precision for extreme grazing
alpha_pol = 0;                  % 0 = S-pol (TE) [cite: 644]
rho = 1 * sind(theta_inc);

%% --- 3. TEXTURE DEFINITIONS (Gold Coating) ---
n_vacuum = 1.0; 
% Refractive index for Gold (Au) at 3.5nm [cite: 637, 1096]
n_substrate = 0.998 + 0.005i;   

% Laminar Parameters [cite: 1006]
groove_depth = 4.0;             % [nm] h [cite: 1331]
duty_ratio = 0.5;               % a/d [cite: 1329]

edge = duty_ratio * period;     
textures = { {n_vacuum}, {n_substrate}, { [0, edge], [n_substrate, n_vacuum] } };

%% --- 4. STEP 1: MODAL SOLVER ---
parm = res0;
parm.res1.champ = 1;   
parm.res1.vi = 1;               % Mandatory for grazing [cite: 71]
aa = res1(wavelength, period, textures, num_harmonics, rho, delta_conical, parm);

%% --- 5. PROFILE & GEOMETRY ---
heights = [0, groove_depth, 0];
sequence = [1, 3, 2];
profile1 = {heights, sequence};

if plot_geometry
    figure(2); 
    x_mesh = linspace(-period/2, period/2, 200);
    parm_geom = res0;
    parm_geom.res3.trace = 1;       
    res3(x_mesh, aa, profile1, [1, 1], parm_geom); 
    title(sprintf('L3600-1-6 Geometry (N=3600, h=%.1f nm)', groove_depth));
end

%% --- 6. STEP 2: EFFICIENCIES & ENERGY CONSERVATION ---
ef = res2(aa, profile1);
res_TE = ef.TEinc_top_reflected; 
res_TM = ef.TMinc_top_reflected;

% Energy Conservation Check: Sum of all reflected orders
% For lossy materials (X-ray), Total_R + Absorption = 1
total_reflectivity_TE = sum(res_TE.efficiency);
total_reflectivity_TM = sum(res_TM.efficiency);

target_orders = -2:2; 
num_o = length(target_orders);
te_eff = zeros(1, num_o); tm_eff = zeros(1, num_o);

for i = 1:num_o
    m = target_orders(i);
    idx_te = find(res_TE.order == m);
    if ~isempty(idx_te), te_eff(i) = res_TE.efficiency(idx_te(1)) * 100; end
    idx_tm = find(res_TM.order == m);
    if ~isempty(idx_tm), tm_eff(i) = res_TM.efficiency(idx_tm(1)) * 100; end
end

figure(3); set(gcf, 'Color', 'w');
bar(target_orders, [te_eff; tm_eff]');
xlabel('Diffraction Order [m]'); ylabel('Efficiency [%]');
title('Efficiency vs Order (L3600-1-6)');
legend('S-pol (TE)', 'P-pol (TM)'); grid on;

%% --- 7. FIELD MAPPING / SHADOWING ---
if plot_fields
    incident_field = [cosd(alpha_pol), sind(alpha_pol)]; 
    parm_field = res0;
    parm_field.res3.trace = 0; 
    x_map = linspace(-period/2, period/2, 500);
    [e, z_map, o_map] = res3(x_map, aa, profile1, incident_field, parm_field);
    
    figure(4); set(gcf, 'Color', 'w', 'Position', [100, 100, 800, 600]);
    Int = abs(e(:,:,1)).^2 + abs(e(:,:,2)).^2 + abs(e(:,:,3)).^2; 
    subplot(2,1,1);
    imagesc(x_map, z_map, Int); colormap(jet); colorbar;
    title('Shadowing Intensity Map');
    subplot(2,1,2);
    imagesc(x_map, z_map, real(o_map)); colormap(gca, bone);
    title('L3600-1-6 Structure (Au Coating)');
end

%% --- 8. FINAL REPORT ---
idx_m1 = find(res_TE.order == m_order);
fprintf('\n================== L3600-1-6 ENERGY CONSERVATION REPORT ==================\n');
fprintf('Wavelength: %.2f nm | Incident Angle: %.2f deg \n', wavelength, alpha_inc);
fprintf('------------------------------------------------------------------------\n');
fprintf('ENERGY CHECK:\n');
fprintf('  - Total Reflectivity (S-pol): %7.4f %%\n', total_reflectivity_TE * 100);
fprintf('  - Total Reflectivity (P-pol): %7.4f %%\n', total_reflectivity_TM * 100);
fprintf('  (Remainder represents material absorption in the Au coating)\n');
fprintf('------------------------------------------------------------------------\n');
if ~isempty(idx_m1)
    fprintf('TARGET ORDER (m=%d):\n', m_order);
    fprintf('  - S-pol Efficiency: %7.4f %%\n', res_TE.efficiency(idx_m1(1))*100);
    fprintf('  - P-pol Efficiency: %7.4f %%\n', res_TM.efficiency(idx_m1(1))*100);
end
fprintf('==========================================================================\n');

retio;