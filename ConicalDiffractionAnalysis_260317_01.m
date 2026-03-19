% =========================================================================
% CDS Grating Efficiency Calculator - Final Corrected Version
% Coating: Gold (Au) | 3600 lines/mm | Conical Mount
% =========================================================================

clear; clc; close all;

% --- 1. Environment & Path Setup ---
% Ensure you have the reticolo_allege subfolder in your path
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir')
    addpath(genpath(lib_path)); 
else
    error('Library path not found. Please check your RETICOLO V7 folder location.');
end

%% 1. Define Grating Specifications (Units in micrometers 'um')
G = 3600;                 % Grating Density (lines/mm)
d = 1000 / G;             % Grating Period (um)
m_order = 1;              % Target diffraction order

% Spectral Range (3.5 nm to 12 nm)
lambda_nm = linspace(3.5, 12.0, 50); 
lambda_um = lambda_nm / 1000;  

% Mounting Geometry (Angles in degrees)
gamma_deg = 3.75;         % Conical tilt (Grazing angle)
alpha_deg = 15.41;        % Incidence angle

% Grating Profile
groove_depth = 0.010;     % 10 nm
fill_factor = 0.5;        % 50% duty cycle

%% 2. Initialize Reticolo & Bug Fixes
parm = res0(1); 

% Fix for missing fields in some Reticolo V7 versions
if ~isfield(parm.res1, 'angles'), parm.res1.angles = 0; end
if ~isfield(parm.res1, 'li'),     parm.res1.li = 0;     end 
if ~isfield(parm.res1, 'sog'),    parm.res1.sog = 0;    end % "Sog" handles singularity checks

nn = 25; % Number of Fourier harmonics
eff_plus_1 = zeros(length(lambda_um), 1);

%% 3. Iterate Over Wavelengths
fprintf('Calculating efficiencies...\n');

for k = 1:length(lambda_um)
    current_lambda = lambda_um(k);
    
    % --- Refractive Index of Au (Gold) ---
    n_Au = get_Au_refractive_index(lambda_nm(k)); 
    
    % --- TEXTURE DEFINITION (Standard 1D Numeric Format) ---
    % Format: { [width1, index1], [width2, index2] }
    % This format prevents the "isfinite" error.
    texture_vacuum = { 1 }; 
    texture_grating = { [1-fill_factor, 1], [fill_factor, n_Au] }; 
    texture_substrate = { n_Au };
    
    TEXTURES = {texture_vacuum, texture_grating, texture_substrate};
    
    % --- Compute Eigenvalues ---
    % alpha_deg = incidence angle (theta), gamma_deg = conical tilt (phi)
    [a, nef] = res1(current_lambda, d, TEXTURES, nn, alpha_deg, gamma_deg, parm);
    
    % --- Define Profile and Solve ---
    PROFIL = {groove_depth, 2}; 
    ef = res2(a, PROFIL, parm);
    
    % --- Extract +1 Order Efficiency (Robust Version) ---
    % We use fieldnames because Reticolo objects are picky about field names.
    fields = fieldnames(ef);
    
    % Find the field that contains "inc_top" (usually inc_top or inc_top_reflected)
    target_idx = find(contains(fields, 'inc_top'));
    
    if ~isempty(target_idx)
        % Access the object field dynamically
        res_struct = ef.(fields{target_idx(1)}); 
        
        orders = res_struct.order; 
        idx_m1 = find(orders == m_order);
        
        if ~isempty(idx_m1)
            % Check for Conical (TE/TM) or Standard (efficiency) outputs
            if isfield(res_struct, 'efficiency_TE') && isfield(res_struct, 'efficiency_TM')
                % Conical case: unpolarized average
                eff_plus_1(k) = 0.5 * (res_struct.efficiency_TE(idx_m1) + res_struct.efficiency_TM(idx_m1));
            elseif isfield(res_struct, 'efficiency')
                % Standard 1D case
                eff_plus_1(k) = res_struct.efficiency(idx_m1);
            end
        end
    else
        warning('Wavelength %.2f nm: Could not find reflection field in "ef" object.', lambda_nm(k));
    end
end

fprintf('Calculation complete!\n');

%% 4. Plot Results
figure;
plot(lambda_nm, eff_plus_1 * 100, 'b-', 'LineWidth', 2);
grid on;
xlabel('Wavelength (nm)');
ylabel('Absolute Efficiency (%)');
title(['CDS Grating Efficiency (m=', num2str(m_order), ', Au Coating)']);

% =========================================================================
% Helper Function for Gold Refractive Index
% =========================================================================
function n_complex = get_Au_refractive_index(wavelength_nm)
    % Approximation for Gold in the soft X-ray regime
    % Real part (1-delta), Imaginary part (beta)
    % In practice, please use CXRO data table interpolation here
    delta = 0.04 * (wavelength_nm / 10); 
    beta = 0.03 * (wavelength_nm / 10);
    n_complex = (1 - delta) + 1i * beta;
end