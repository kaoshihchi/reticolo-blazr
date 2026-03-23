%% ========================================================================
%  RETICOLO: BLAZED GRATING - GRAZING INCIDENCE (REVISED VISUALS)
%  =======================================================================
clear; clc; close all;
%% --- 1. SETTINGS & SWITCHES ---
plot_textures = false;  % Set to true to see Figure 1 (Slow!)
plot_geometry = true;   % Set to true to see Figure 2 (The Staircase)
plot_fields   = true;   % Set to true to see Figure 4 (Shadowing/Fields)
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir'), addpath(genpath(lib_path)); end
%% --- 2. PHYSICAL PARAMETERS (Units: nm, deg, L/mm) ---
% --- Basic Grating & Light Properties ---
wavelength = 4;                 % [nm]  Wavelength (LD)
groove_density = 5000;          % [L/mm] G: lines/mm
period = 1e6 / groove_density;  % [nm]  D: ~200 nm
m_order = -1;                   % Target diffraction order

% --- Geometric Inputs (Experimental xz-plane definition) ---
grazing_angle = 2;              % [deg] gamma: Angle between beam and groove (y-axis)

% --- Calculate the Quasi-Littrow Alpha (for beta = alpha) ---
% Formula: sin(alpha) = |m|*lambda / (2 * d * sin(gamma))
sin_alpha_littrow = abs(m_order * wavelength / (2 * period * sind(grazing_angle)));

if sin_alpha_littrow > 1
    error('Physical Limit: Order m=%d is evanescent at lambda=%.1fnm, gamma=%.1fdeg.', ...
        m_order, wavelength, grazing_angle);
end
alpha_xz = asind(sin_alpha_littrow); % Alpha in the xz-plane

% --- RETICOLO COORDINATE TRANSFORMATION ---
% theta_inc: acos(sin(gamma)*cos(alpha))
% delta_conical: atan(cos(gamma) / (sin(gamma)*sin(alpha)))
theta_inc = acosd(sind(grazing_angle) * cosd(alpha_xz));
delta_conical = atand(cosd(grazing_angle) / (sind(grazing_angle) * sind(alpha_xz)));

% --- Polarization Settings ---
% alpha_pol: 0 = TE (E perp to incident plane), 90 = TM (E in incident plane)
alpha_pol = 0;                  
num_harmonics = 50;             
rho = 1 * sind(theta_inc);
%% --- 3. TEXTURE DEFINITIONS (Blazed Staircase) ---
n_vacuum = 1.0; 
n_BK7    = 1.516; 
n_PEC    = 1000i;               % Perfect Conductor
blaze_angle_deg = 14;         % [deg]
num_steps = 100;                 
blaze_height = period * tand(blaze_angle_deg); % [nm]
step_height = blaze_height / num_steps;        % [nm]
textures = cell(1, num_steps + 2);
textures{1} = {n_vacuum}; textures{2} = {n_BK7};
for j = 1:num_steps
    fill_factor = (num_steps - j + 0.5) / num_steps; 
    edge = fill_factor * period;
    textures{j+2} = { [0, edge], [n_PEC, n_vacuum] };
end
%% --- 4. STEP 1: MODAL SOLVER ---
parm = res0;
parm.sym.x = [];       
parm.sym.pol = 0;      
parm.res1.champ = 1;            
parm.res1.trace = plot_textures; % Control via switch (Figure 1)
aa = res1(wavelength, period, textures, num_harmonics, rho, delta_conical, parm);
if plot_textures, figure(1); title('Figure 1: Texture Permittivity'); end
%% --- 5. PROFILE & GEOMETRY (Figure 2) ---
heights = [0, repmat(step_height, 1, num_steps), 0];
sequence = [1, 3:(num_steps+2), 2];
profile1 = {heights, sequence};
if plot_geometry
    figure(2); 
    x_mesh = linspace(-period/2, period/2, 200);
    parm_geom = res0;
    parm_geom.res3.cale = [];       
    parm_geom.res3.trace = 1;       
    [~, ~, ~] = res3(x_mesh, aa, profile1, [1, 1], parm_geom); 
    title(sprintf('Figure 2: %.1f^o Blazed Staircase Geometry [nm]', blaze_angle_deg));
    xlabel('X Position [nm]'); ylabel('Z Depth [nm]');
end
%% --- 6. STEP 2: EFFICIENCIES (Figure 3 - Expanded Range) ---
ef = res2(aa, profile1);
res_TE = ef.TEinc_top_reflected; 
res_TM = ef.TMinc_top_reflected;
% --- ADJUST THIS RANGE ---
target_orders = -5:5; 
% -------------------------
num_o = length(target_orders);
te_eff = zeros(1, num_o); 
tm_eff = zeros(1, num_o);
for i = 1:num_o
    m = target_orders(i);
    % Find matching order in TE results
    idx_te = find(res_TE.order == m);
    if ~isempty(idx_te)
        te_eff(i) = res_TE.efficiency(idx_te(1)) * 100; 
    end
    
    % Find matching order in TM results
    idx_tm = find(res_TM.order == m);
    if ~isempty(idx_tm)
        tm_eff(i) = res_TM.efficiency(idx_tm(1)) * 100; 
    end
end
figure(3); set(gcf, 'Color', 'w', 'Name', 'Efficiency vs Order');
bar(target_orders, [te_eff; tm_eff]');
xlabel('Diffraction Order [m]', 'FontWeight', 'bold');
ylabel('Efficiency [%]', 'FontWeight', 'bold');
title(sprintf('Figure 3: Efficiency vs Order (Grazing = %.2f^o)', grazing_angle));
legend('TE (S-pol)', 'TM (P-pol)'); 
grid on;
%% --- 7. FIELD MAPPING / SHADOWING (Manual Plotting) ---
if plot_fields
    % Calculate fields without automatic tracing
    incident_field = [cosd(alpha_pol), sind(alpha_pol)]; 
    parm_field = res0;
    parm_field.res3.trace = 0; % DISABLE internal plotting
    
    % We increase the x_mesh density for a sharper map
    x_map = linspace(-period/2, period/2, 400);
    [e, z_map, o_map] = res3(x_map, aa, profile1, incident_field, parm_field);
    
    % --- NEW FIGURE 4: MANUAL SHADOW PLOT ---
    figure(4); set(gcf, 'Color', 'w', 'Position', [100, 100, 900, 600]);
    
    % Calculate Intensity |Ex|^2 for the Shadow Map
    Ex_intensity = abs(e(:,:,1)).^2; 
    
    % Plot 1: Field Intensity (The Shadowing)
    subplot(2,1,1);
    % We use 'pcolor' for manual control. (XX, ZZ) coordinates
    [XX, ZZ] = meshgrid(x_map, z_map);
    p = pcolor(XX, ZZ, Ex_intensity);
    set(p, 'EdgeColor', 'none'); % Remove grid lines
    shading interp;             % Smooth the colors
    colormap(jet); colorbar;
    ylabel('Z [nm]'); title(sprintf('Field Intensity |E|^2 at alpha = %.1f deg', alpha_pol));
    
    % Plot 2: Refractive Index Map (To see where the teeth are)
    subplot(2,1,2);
    p2 = pcolor(XX, ZZ, real(o_map));
    set(p2, 'EdgeColor', 'none');
    shading flat; colormap(gca, bone); % Use 'bone' colormap for structure
    xlabel('X [nm]'); ylabel('Z [nm]'); title('Structure Map [Refractive Index n]');
    
    % Synchronize axes
    linkaxes(findall(gcf,'type','axes'), 'x');
end
%% --- 8. EXPERIMENTAL TOTAL EFFICIENCY ANALYSIS ---
idx_m1 = find(res_TE.order == m_order);
fprintf('\n================== EXPERIMENTAL DATA SUMMARY ==================\n');
fprintf('Input Parameters (Experimental Layout):\n');
fprintf('  - Grazing Angle (gamma):  %.2f deg\n', grazing_angle);
fprintf('  - Incident Alpha (xz):    %.2f deg\n', alpha_xz);
fprintf('  - Wavelength (lambda):    %.2f nm\n', wavelength);
fprintf('\nInput Parameters (RETICOLO Internals):\n');
fprintf('  - Polar Angle (theta):    %.4f deg\n', theta_inc);
fprintf('  - Azimuthal (delta):      %.4f deg\n', delta_conical);
fprintf('--------------------------------------------------------------\n');

if ~isempty(idx_m1)
    eff_te = res_TE.efficiency(idx_m1(1)) * 100;
    eff_tm = res_TM.efficiency(idx_m1(1)) * 100;
    total_eff = eff_te * (cosd(alpha_pol)^2) + eff_tm * (sind(alpha_pol)^2);
    
    % --- Calculate Diffracted Beta (xz-plane) from RETICOLO K-vectors ---
    % In RETICOLO: kx = sin(theta)*cos(delta). In xz: sin(gamma)*sin(beta) = kx.
    kx_out = res_TE.K(idx_m1(1), 1); 
    beta_xz_out = asind(kx_out / sind(grazing_angle));
    
    fprintf('Results for Order m = %d:\n', m_order);
    fprintf('  - TE Efficiency:            %7.4f %%\n', eff_te);
    fprintf('  - TM Efficiency:            %7.4f %%\n', eff_tm);
    fprintf('  >>> TOTAL EFFICIENCY:       %7.4f %%\n', total_eff);
    fprintf('  - Diffracted Beta (xz):     %7.4f deg (Target: %.2f)\n', beta_xz_out, alpha_xz);
else
    fprintf('[WARNING] Order m = %d is currently EVANESCENT.\n', m_order);
end
fprintf('--------------------------------------------------------------\n');
fprintf('System Health (Total Reflectivity):\n');
fprintf('  - TE: %7.4f %% | TM: %7.4f %%\n', sum(res_TE.efficiency)*100, sum(res_TM.efficiency)*100);
fprintf('==============================================================\n\n');
%% --- 9. CLEANUP ---
retio;