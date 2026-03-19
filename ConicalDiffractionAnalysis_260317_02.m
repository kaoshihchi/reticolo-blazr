% =========================================================================
% CDS Blazed Grating Efficiency - Final Stable Solution
% =========================================================================
clear; clc; close all;

% --- 1. Environment ---
% Ensure the library path is correct
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir'), addpath(genpath(lib_path)); end

%% 1. Define Specifications
G = 3600; d = 1000/G;      
lambda_nm = linspace(3.5, 12.0, 50); 
lambda_um = lambda_nm / 1000;
m_order = 1;

% Mounting Geometry (CDS Specs)
gamma_deg = 3.75; alpha_deg = 15.41;
blaze_angle_deg = 13.5;
n_layers = 25; % Number of staircase layers
blaze_height = d * tan(deg2rad(blaze_angle_deg)); 
layer_thickness = blaze_height / n_layers;

%% 2. Initialize Reticolo & Bug Fixes
parm = res0(1);
% Solver fixes
parm.res1.angles = 0; parm.res1.li = 0; parm.res1.sog = 0;
% Plotting limit fixes (to prevent "ylimite" errors)
parm.res1.nx = 200; parm.res1.ny = 200;
parm.res1.xlimite = [-d/2, d/2]; parm.res1.ylimite = [-d/2, d/2];

nn = 25; 
eff_plus_1 = zeros(length(lambda_um), 1);

%% 3. Iterate Over Wavelengths
fprintf('Calculating efficiencies for %d nm to %d nm...\n', lambda_nm(1), lambda_nm(end));

for k = 1:length(lambda_um)
    current_lambda = lambda_um(k);
    n_Au = get_Au_refractive_index(lambda_nm(k)); 
    
    % --- 1. Define Textures ---
    % 1: Vacuum, 2..N+1: Staircase, N+2: Substrate
    TEXTURES = cell(1, n_layers + 2);
    TEXTURES{1} = {1}; % Vacuum (Superstrate)
    for j = 1:n_layers
        f = (n_layers - j + 0.5) / n_layers; 
        TEXTURES{j+1} = {[1-f, 1], [f, n_Au]};
    end
    TEXTURES{n_layers+2} = {n_Au}; % Gold (Substrate)
    
    % --- 2. Compute Eigenvalues (Standard Call) ---
    [a, ~] = res1(current_lambda, d, TEXTURES, nn, alpha_deg, gamma_deg, parm);
    
    % --- 3. Define PROFIL (Correct 1D Cell Structure) ---
    % Structure must be: { {thickness, texture_index}, ... }
    PROFIL = cell(1, n_layers + 2);
    PROFIL{1} = {0, 1}; % Top infinite Vacuum
    for j = 1:n_layers
        PROFIL{j+1} = {layer_thickness, j + 1}; % The steps
    end
    PROFIL{n_layers+2} = {0, n_layers + 2}; % Bottom infinite Gold
    
    % --- 4. Solve Diffraction ---
    ef = res2(a, PROFIL, parm);
    
    % --- 5. Extract Efficiency ---
    fields = fieldnames(ef);
    target_idx = find(contains(fields, 'inc_top'));
    if ~isempty(target_idx)
        res_struct = ef.(fields{target_idx(1)});
        [~, idx] = min(abs(res_struct.order - m_order)); 
        if isfield(res_struct, 'efficiency_TE')
            eff_plus_1(k) = 0.5 * (res_struct.efficiency_TE(idx) + res_struct.efficiency_TM(idx));
        else
            eff_plus_1(k) = res_struct.efficiency(idx);
        end
    end
end

fprintf('Calculation Complete!\n');

%% 4. Final Efficiency Plot
figure;
plot(lambda_nm, eff_plus_1 * 100, 'b-', 'LineWidth', 2);
grid on; 
xlabel('Wavelength (nm)'); 
ylabel('Absolute Efficiency (%)');
title(['CDS Blazed Au Grating (m=', num2str(m_order), ', Blaze=', num2str(blaze_angle_deg), '°)']);

% --- Calculate Beta for the central wavelength for display ---
lambda_mid = lambda_um(round(length(lambda_um)/2));
% Modified grating equation for conical mount: 
% sin(gamma)*(sin(alpha) + sin(beta)) = m*lambda/d
term1 = (m_order * lambda_mid) / (d * sin(deg2rad(gamma_deg)));
beta_mid_deg = rad2deg(asin(term1 - sin(deg2rad(alpha_deg))));

% --- Add Parameter Text Box ---
param_str = { ...
    ['Lines/mm: ', num2str(G)], ...
    ['Period d: ', num2str(d, '%.4f'), ' \mum'], ...
    ['Incidence \alpha: ', num2str(alpha_deg), '^\circ'], ...
    ['Grazing \gamma: ', num2str(gamma_deg), '^\circ'], ...
    ['Blaze \theta_B: ', num2str(blaze_angle_deg), '^\circ'], ...
    ['Diff. \beta (mid): ', num2str(beta_mid_deg, '%.2f'), '^\circ']};

% Place text in the top-right corner (using normalized axes units)
annotation('textbox', [0.65, 0.65, 0.25, 0.25], 'String', param_str, ...
    'BackgroundColor', 'white', 'EdgeColor', 'black', 'FontSize', 10);

%% 5. Manual Geometry Output (Stable Grating View)
figure; hold on;
% Draw the staircase
for j = 1:n_layers
    f = (n_layers - j + 0.5) / n_layers;
    fill([0, f*d, f*d, 0], [(j-1)*layer_thickness, (j-1)*layer_thickness, j*layer_thickness, j*layer_thickness], [0.85 0.7 0.1]);
end
% Draw the substrate
fill([0, d, d, 0], [-blaze_height/4, -blaze_height/4, 0, 0], [0.85 0.7 0.1]);
title('Blazed Grating Geometry (Staircase Approximation)');
xlabel('x (\mum)'); ylabel('z (\mum)'); axis equal; grid on;

% --- Helper: Refractive Index ---
function n = get_Au_refractive_index(w_nm)
    % Placeholder approximation for Gold (n = 1-delta + i*beta)
    % In real applications, interpolate actual Henke/CXRO data tables here.
    delta = 0.04 * (w_nm/10); beta = 0.03 * (w_nm/10);
    n = (1-delta) + 1i*beta;
end