% =========================================================================
% RETICOLO Example: Conical Diffraction Losses (Absorption)
% =========================================================================
clear; clc; close all;

% --- 1. Physical Parameters ---
wavelength = 8;        % Wavelength (LD)
period = 10;           % Grating period (D)
theta0 = 30;           % Angle of incidence (theta in degrees)
n_super = 1.5;         % Refractive index of superstrate (nh)
n_sub = 1.2;           % Refractive index of substrate (nb)
delta0 = 20;           % Conical azimuthal angle (delta in degrees)

% Normalized wavevector component (n * sin(theta))
% 'ro' represents the projection of the incident wave in the grating plane
rho = n_super * sind(theta0); 

% --- 2. Solver Settings ---
num_harmonics = 20;    % Number of Fourier harmonics (nn)
parm = res0;           % Initialize default parameters
parm.res1.champ = 1;   % 1 = Enable accurate field calculation for loss analysis

% --- 3. Iteration over different Grating Types ---
for grating_case = 1:3
    % textures{1} = Incident medium index
    % textures{2} = Transmission medium index
    textures{1} = n_super;   
    textures{2} = n_sub; 
    
    switch grating_case
        case 1
            % Case 1: Dielectric Grating
            % Texture defined by regions: [-2.5 to 2.5] is one material, the rest another
            textures{3} = { [-2.5, 2.5], [0.1 + 5i, 1]};
        case 2
            % Case 2: "Electric" Metallic Grating
            % Defined by coordinates [0 to D/2]
            textures{3} = { inf, [0, period/2, 0.1 + 5i]};
        case 3
            % Case 3: "Magnetic" Metallic Grating
            textures{3} = { -inf, [0, period/2, 0.1 + 5i]};
    end
    
    % --- 4. STEP 1: Modal Calculation (res1) ---
    % aa contains the modes of the grating layers
    aa = res1(wavelength, period, textures, num_harmonics, rho, delta0, parm);
    
    % --- 5. STEP 2: Profile Definition & S-Matrix (res2) ---
    % profil = { [thicknesses], [texture_index_for_each_layer] }
    % Here: Layer 1 is 5 units thick (texture 1), Layer 2 is 0.2 units (texture 3), etc.
    profil = {[5, 0.2, 5], [1, 3, 2]};
    [ef, tab] = res2(aa, profil);
    
    % --- 6. Field & Loss Calculation (res3) ---
    x_range = [-period/2, period/2]; % Horizontal range to calculate field
    parm.res3.npts = [[0, 10, 0]; [1, 5, 1]]; % Sampling points density
    parm.res3.trace = 0; % Disable automatic plotting inside res3
    
    % --- Process for TE Incidence ---
    einc_TE = ef.TEinc_top.PlaneWave_TE_Eu; % Define incident TE field
    [e, z, o, w, PP, P, p, XX, wx] = res3(x_range, aa, profil, einc_TE, parm);
    
    % Check Energy Balance: (Reflectance + Transmittance + Losses) - 1
    % This should be close to zero if the simulation is accurate
    energy_balance_TE = sum(ef.TEinc_top_reflected.efficiency) + ...
                        sum(ef.TEinc_top_transmitted.efficiency) + ...
                        sum(PP) / (0.5 * period) - 1;
    
    % Visualization of Loss Density
    figure('Name', ['Case ', num2str(grating_case), ' - TE Losses']);
    pcolor(XX, z, p); shading flat; colormap(hot); colorbar;
    title(['Loss Density (TE) - Case ', num2str(grating_case)]);
    
    % --- Process for TM Incidence ---
    einc_TM = ef.TMinc_top.PlaneWave_TM_Eu; % Define incident TM field
    [e, z, o, w, PP, P, p, XX, wx] = res3(x_range, aa, profil, einc_TM, parm);
    
    energy_balance_TM = sum(ef.TMinc_top_reflected.efficiency) + ...
                        sum(ef.TMinc_top_transmitted.efficiency) + ...
                        sum(PP) / (0.5 * period) - 1;
    
    figure('Name', ['Case ', num2str(grating_case), ' - TM Losses']);
    pcolor(XX, z, p); shading flat; colormap(hot); colorbar;
    title(['Loss Density (TM) - Case ', num2str(grating_case)]);
    
    fprintf('Case %d: Energy Balance TE: %e, TM: %e\n', ...
            grating_case, energy_balance_TE, energy_balance_TM);
end