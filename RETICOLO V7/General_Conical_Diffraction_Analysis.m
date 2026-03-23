%% ========================================================================
%  RETICOLO: MODULAR CONICAL DIFFRACTION ANALYSIS
%  ========================================================================
%  A modular script for analyzing diffraction efficiencies, geometry,
%  and electromagnetic field distributions in conical mounting.
%  ========================================================================

clear; clc; close all;

%% --- 1. ENVIRONMENT & PATH SETUP ---
% Ensure the library path is correct for your local RETICOLO installation
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir')
    addpath(genpath(lib_path));
else
    warning('RETICOLO library not found at: %s', lib_path);
end

%% --- 2. GLOBAL PHYSICAL PARAMETERS (Units: nanometers) ---
wavelength = 15;                % LD: 15 nm (Extreme UV / Soft X-ray)
groove_density = 3600;          % G: Lines per mm
period = 1e6 / groove_density;  % D: ~277.78 nm

theta_inc = 10;        % Incident angle relative to the normal (deg)
n_incident = 1;        % Refractive index of superstrate (Vacuum = 1)
delta_conical = 20;    % Azimuthal rotation (delta0) - defines the cone
num_harmonics = 30;    % Increased to 30 for better precision with high G

% Calculate rho (transverse wavevector component)
rho = n_incident * sind(theta_inc); 

fprintf('Simulation set for Lambda = %g nm and Period = %.2f nm\n', wavelength, period);

%% --- 3. TEXTURE DEFINITIONS (Horizontal Slices) ---
% Define the horizontal refractive index distributions
textures = cell(1, 5);
textures{1} = {1};     % Superstrate (Air)
textures{2} = {1.5};   % Substrate (Glass)
textures{3} = {[-4, 4], [1, 1.5]};   
textures{4} = {[-1, -0.5, 0.5, 1], [2, 1.3, 1.5, 1.3]};   
textures{5} = {[-1, 1], [1.5, 2.5]};

%% --- 4. STEP 1: MODAL SOLVER INITIALIZATION (res1) ---
% This solves the eigenproblem for the textures. 
% Must be rerun if wavelength, period, or incidence angles change.
parm = res0;
parm.sym.x = [];       % Disable symmetry for conical coupling
parm.sym.pol = 0;      % Calculate both TE and TM responses
parm.res1.li = 0;      % Longitudinal integration
parm.res1.ftemp = 0;   
parm.res1.champ = 1;   % Enable accurate field calculation for res3
parm.res1.trace = 1;   % FIGURE SET 1: Visualizes the defined textures

% Execute Step 1
aa = res1(wavelength, period, textures, num_harmonics, rho, delta_conical, parm);

%% --- 5. PROFILE DEFINITIONS (Vertical Stacking) ---
% syntax: { [thicknesses], [texture_indices] }
profile1 = {[0, 1, 0.5, 0.6, 0], [1, 4, 5, 4, 2]};      % Baseline
profile2 = {{0, 1}, {[1, 0.5, 0.6], [3, 2, 4], 2}, {[2, 0], [5, 2]}}; % Repetitive
profile3 = {{1, 1}, {[1, 0.5, 0.6], [3, 2, 4], 2}, {[2, 1], [5, 2]}}; % Field Map

%% --- 6. GEOMETRY VERIFICATION (res3 Geometry Mode) ---
x_mesh = linspace(-period/2, period/2, 100);
parm_geom = res0;
parm_geom.res3.cale = [];   % Skip field calculation
parm_geom.res3.trace = 1;    % FIGURE SET 2: Visualizes the profile stacking

[~, ~, ~] = res3(x_mesh, aa, profile1, [1, 1], parm_geom); title('Profile 1 Geometry');
[~, ~, ~] = res3(x_mesh, aa, profile2, [1, 1], parm_geom); title('Profile 2 (Repetitive)');

%% --- 7. STEP 2: DIFFRACTION EFFICIENCIES (res2) ---
% Solves the S-matrix for the chosen profile
ef = res2(aa, profile1);

% Print Energy Balance for Troubleshooting
ref_TE = sum(ef.TEinc_top_reflected.efficiency);
tra_TE = sum(ef.TEinc_top_transmitted.efficiency);
fprintf('--- Energy Balance (Profile 1) ---\n');
fprintf('TE Inc: R=%.4f, T=%.4f, Sum=%.4f (Losses=%.4f)\n', ...
        ref_TE, tra_TE, ref_TE+tra_TE, 1-(ref_TE+tra_TE));

%% --- 8. STEP 3: ELECTROMAGNETIC FIELD MAPPING (res3 Field Mode) ---
% Incident field: [TE component, TM component]
incident_vector = [1, 1]; 
parm_field = res0;
parm_field.res3.trace = 1; % FIGURE SET 3: Plots Ex, Ey, Ez, and n(x,z)

% Calculate internal fields for profile3
[field_map, z_coords, index_map] = res3(x_mesh, aa, profile3, incident_vector, parm_field);

%% --- 9. POST-PROCESSING: EXTENDED ENERGY ANALYSIS ---

% 1. Setup target orders (-2 to +2)
target_orders = -2:2; 
num_o = length(target_orders);

% Initialize arrays for Reflection and Transmission
te_ref = zeros(1, num_o); tm_ref = zeros(1, num_o);
te_tra = zeros(1, num_o); tm_tra = zeros(1, num_o);

% 2. Extract structures from 'ef'
rTE = ef.TEinc_top_reflected;   rTM = ef.TMinc_top_reflected;
tTE = ef.TEinc_top_transmitted; tTM = ef.TMinc_top_transmitted;

% 3. Extract efficiency for each order
for i = 1:num_o
    m = target_orders(i);
    
    % Reflection (R)
    idx_re_te = find(rTE.order == m);
    if ~isempty(idx_re_te), te_ref(i) = rTE.efficiency(idx_re_te(1)) * 100; end
    idx_re_tm = find(rTM.order == m);
    if ~isempty(idx_re_tm), tm_ref(i) = rTM.efficiency(idx_re_tm(1)) * 100; end
    
    % Transmission (T)
    idx_tr_te = find(tTE.order == m);
    if ~isempty(idx_tr_te), te_tra(i) = tTE.efficiency(idx_tr_te(1)) * 100; end
    idx_tr_tm = find(tTM.order == m);
    if ~isempty(idx_tr_tm), tm_tra(i) = tTM.efficiency(idx_tr_tm(1)) * 100; end
end

% 4. Overall Energy Budget (R + T + Absorption)
total_R_te = sum(rTE.efficiency); total_T_te = sum(tTE.efficiency);
abs_te = 1 - (total_R_te + total_T_te);

total_R_tm = sum(rTM.efficiency); total_T_tm = sum(tTM.efficiency);
abs_tm = 1 - (total_R_tm + total_T_tm);

%% --- 10. VISUALIZATION: THE FULL ENERGY PICTURE ---

% FIGURE A: Order-by-Order Distribution
figure('Color', 'w', 'Name', 'Order-by-Order Analysis', 'Position', [100, 100, 1100, 500]);

% Left Side: Reflected Orders
subplot(1,2,1);
bar(target_orders, [te_ref; tm_ref]');
title('Reflected Efficiency (Orders -2 to 2)');
xlabel('Order (m)'); ylabel('Efficiency (%)'); grid on;
legend('TE Incident', 'TM Incident');

% Right Side: Transmitted Orders
subplot(1,2,2);
bar(target_orders, [te_tra; tm_tra]');
title('Transmitted Efficiency (Orders -2 to 2)');
xlabel('Order (m)'); ylabel('Efficiency (%)'); grid on;
legend('TE Incident', 'TM Incident');

% FIGURE B: Total Energy Budget (FIXED BAR CHART)
figure('Color', 'w', 'Name', 'Total Energy Budget');

% Prepare data and categorical labels to fix the MATLAB error
budget_data = [total_R_te, total_T_te, abs_te; total_R_tm, total_T_tm, abs_tm] * 100;
x_labels = categorical({'TE Incident', 'TM Incident'});
x_labels = reordercats(x_labels, {'TE Incident', 'TM Incident'}); % Keeps the order correct

b3 = bar(x_labels, budget_data, 'stacked');
title('Total Energy Distribution: R + T + Absorption');
ylabel('Energy Percentage (%)');
legend('Total Reflection (R)', 'Total Transmission (T)', 'Absorption (A)', 'Location', 'northeastoutside');
grid on;

% Add percentage labels inside the bars for clarity
text(1, 5, sprintf('R=%.1f%%', total_R_te*100), 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(1, 50, sprintf('T=%.1f%%', total_T_te*100), 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(2, 5, sprintf('R=%.1f%%', total_R_tm*100), 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(2, 50, sprintf('T=%.1f%%', total_T_tm*100), 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

retio; % Clean up temp files