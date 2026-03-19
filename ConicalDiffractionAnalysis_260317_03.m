% =========================================================================
% CDS Blazed Grating Efficiency - Alpha Scan (Beta = Alpha Condition)
% =========================================================================
clear; clc; close all;

% --- 1. Environment & Path Setup ---
% Ensure the library path is correct for Reticolo
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir'), addpath(genpath(lib_path)); end

%% 1. Define Specifications
G = 3600;               % Lines per mm
d = 1000/G;             % Grating period in micrometers (~0.2778 um)
lambda_nm = linspace(20, 30, 60); 
lambda_um = lambda_nm / 1000;
m_order = 1;

% Fixed Mounting Parameters
gamma_deg = 90 - 3.75;       % Grazing angle (conical)
blaze_angle_deg = 13.5; 
n_layers = 25;          % Staircase approximation layers
nn = 25;                % Number of Fourier harmonics

% Initialize result arrays
eff_scan = zeros(length(lambda_um), 1);
alpha_required = zeros(length(lambda_um), 1);

%% 2. Initialize Reticolo & Solver Settings
parm = res0(1);
parm.res1.angles = 0; 
parm.res1.li = 0; 
parm.res1.sog = 0;
parm.res1.nx = 200; 
parm.res1.ny = 200;
parm.res1.xlimite = [-d/2, d/2]; 
parm.res1.ylimite = [-d/2, d/2];

%% 3. Iterate Over Wavelengths (The Alpha Scan)
fprintf('Starting Alpha Scan for Beta = Alpha condition...\n');

% Physical constants for the loop
gamma_grazing = 3.75; % The actual grazing angle from your model

for k = 1:length(lambda_um)
    current_lambda = lambda_um(k);
    
    % --- 1. Calculate Alpha for the Beta = Alpha Condition ---
    % sin(alpha) = (m * lambda) / (2 * d * sin(gamma_grazing))
    sin_alpha_val = (m_order * current_lambda) / (2 * d * sind(gamma_grazing));
    
    % Propagation Check: If sin(alpha) > 1, the order is evanescent (zero efficiency)
    if abs(sin_alpha_val) >= 1
        continue; 
    end
    
    current_alpha = asind(sin_alpha_val);
    alpha_required(k) = current_alpha;
    
    % --- 2. RETICOLO ANGLE MAPPING ---
    % theta: Angle from the normal to the cone.
    % phi: Azimuthal rotation (your alpha).
    theta_reticolo = 90 - gamma_grazing; 
    phi_reticolo = current_alpha; 
    
    % --- 3. Update Material & Geometry ---
    % For X-rays, n is very close to 1. Using 1000i for debugging PEC.
    n_Au = 1000i; 
    blaze_height = d * tand(blaze_angle_deg); 
    layer_thickness = blaze_height / n_layers;
    
    % Define Textures (Staircase)
    TEXTURES = cell(1, n_layers + 2);
    TEXTURES{1} = {1}; 
    for j = 1:n_layers
        f = (n_layers - j + 0.5) / n_layers; 
        TEXTURES{j+1} = {[1-f, 1], [f, n_Au]};
    end
    TEXTURES{n_layers+2} = {n_Au};
    
    % --- 4. Call Reticolo Solver ---
    [a, ~] = res1(current_lambda, d, TEXTURES, nn, theta_reticolo, phi_reticolo, parm);
    
    % Define Profile
    PROFIL = cell(1, n_layers + 2);
    PROFIL{1} = {0, 1}; 
    for j = 1:n_layers
        PROFIL{j+1} = {layer_thickness, j + 1};
    end
    PROFIL{n_layers+2} = {0, n_layers + 2};
    
    % Solve Diffraction
    ef = res2(a, PROFIL, parm);
    
    % --- 5. Robust Efficiency Extraction ---
    fn = fieldnames(ef);
    if isempty(fn), continue; end
    
    % Find field containing 'inc'
    target_field = '';
    for f_idx = 1:length(fn)
        if contains(fn{f_idx}, 'inc')
            target_field = fn{f_idx};
            break;
        end
    end
    
    if ~isempty(target_field)
        res_struct = ef.(target_field);
        [~, idx] = min(abs(res_struct.order - m_order)); 
        
        if isfield(res_struct, 'efficiency_TE')
            eff_scan(k) = 0.5 * (res_struct.efficiency_TE(idx) + res_struct.efficiency_TM(idx));
        elseif isfield(res_struct, 'efficiency')
            eff_scan(k) = res_struct.efficiency(idx);
        end
    end
end

fprintf('Scan Complete!\n');

%% 4. Visualization
figure('Color', 'w', 'Position', [100, 100, 800, 600]);

% Plot 1: Efficiency vs Wavelength
subplot(2,1,1);
plot(lambda_nm, eff_scan * 100, 'r-', 'LineWidth', 2);
grid on; hold on;
ylabel('Absolute Efficiency (%)');
title(['CDS Efficiency Scan (m=', num2str(m_order), ') where \beta = \alpha']);
legend('Efficiency (+1 order)', 'Location', 'best');

% Plot 2: Required Alpha vs Wavelength
subplot(2,1,2);
plot(lambda_nm, alpha_required, 'b--', 'LineWidth', 1.5);
grid on;
xlabel('Wavelength (nm)');
ylabel('\alpha Required (deg)');
title('Incidence Angle Required for Symmetry');

% --- Summary Annotation ---
param_str = { ...
    ['Grating G: ', num2str(G), ' lines/mm'], ...
    ['Grazing \gamma: ', num2str(gamma_deg), '^\circ'], ...
    ['Blaze Angle: ', num2str(blaze_angle_deg), '^\circ']};
annotation('textbox', [0.15, 0.75, 0.3, 0.15], 'String', param_str, ...
    'BackgroundColor', 'white', 'FontSize', 9);
%% 5. Grating Geometry Visualization
figure('Color', 'w', 'Name', 'Grating Profile');
hold on;

% We visualize the geometry used in the last iteration of the loop
% Draw the staircase steps
for j = 1:n_layers
    % Calculate the fill factor used for this specific layer
    f = (n_layers - j + 0.5) / n_layers; 
    
    % Draw the gold part of the step
    % Logic: [x_start, x_end, x_end, x_start], [z_bottom, z_bottom, z_top, z_top]
    fill([0, f*d, f*d, 0], ...
         [(j-1)*layer_thickness, (j-1)*layer_thickness, j*layer_thickness, j*layer_thickness], ...
         [0.85 0.7 0.1], 'EdgeColor', 'none');
end

% Draw a block for the substrate
fill([0, d, d, 0], [-layer_thickness*5, -layer_thickness*5, 0, 0], [0.85 0.7 0.1], 'EdgeColor', 'none');

% Formatting the plot
title(['Blazed Grating Geometry (Staircase: ', num2str(n_layers), ' layers)']);
xlabel('Width x (\mum)');
ylabel('Height z (\mum)');
axis equal; 
grid on;
xlim([-0.1*d, 1.1*d]);
%% 5. Helper Functions
function n = get_Au_refractive_index(w_nm)
    % Gold refractive index approximation (1 - delta + i*beta)
    % These values are placeholders; replace with Henke table interpolation.
    delta = 0.04 * (w_nm/10); 
    beta = 0.03 * (w_nm/10);
    n = (1-delta) + 1i*beta;
end