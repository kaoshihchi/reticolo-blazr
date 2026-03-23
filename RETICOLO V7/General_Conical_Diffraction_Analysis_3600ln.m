%% ========================================================================
%  RETICOLO: BLAZED GRATING - GRAZING INCIDENCE & SHADOWING ANALYSIS
%  =======================================================================
clear; clc; close all;

%% --- 1. ENVIRONMENT & PATH SETUP ---
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');
if exist(lib_path, 'dir'), addpath(genpath(lib_path)); end

%% --- 2. GLOBAL PHYSICAL PARAMETERS (Units: nm) ---
wavelength = 10;                % LD: 10 nm
groove_density = 3600;          % G: lines/mm
period = 1e6 / groove_density;  % D: ~277.78 nm

% Incidence (Grazing)
theta_inc = 86.25;              % 3.75 deg grazing from surface
delta_conical = 15;             % Conical rotation (phi)
num_harmonics = 60;             % Higher precision for grazing/shadowing

rho = 1 * sind(theta_inc);      % Vacuum incidence

%% --- 3. TEXTURE DEFINITIONS (Blazed Staircase) ---
n_vacuum = 1.0; 
n_BK7    = 1.516; 
n_PEC    = 1000i;               % Perfect Conductor coating

blaze_angle_deg = 13.5;
num_steps = 30;                 % Steps for smooth triangular profile
blaze_height = period * tand(blaze_angle_deg);
step_height = blaze_height / num_steps;

textures = cell(1, num_steps + 2);
textures{1} = {n_vacuum};       % Superstrate
textures{2} = {n_BK7};          % Substrate

% Build the staircase textures (Bottom to Top)
for j = 1:num_steps
    fill_factor = (num_steps - j + 0.5) / num_steps; 
    edge = fill_factor * period;
    textures{j+2} = { [0, edge], [n_PEC, n_vacuum] };
end

%% --- 4. STEP 1: MODAL SOLVER (Figure 1) ---
parm = res0;
parm.sym.x = [];       
parm.sym.pol = 0;      
parm.res1.champ = 1;            % Needed for field mapping
parm.res1.trace = 1;            % GENERATES FIGURE 1: Texture Trace
aa = res1(wavelength, period, textures, num_harmonics, rho, delta_conical, parm);
shg; % Bring texture plot to front

%% --- 5. PROFILE DEFINITIONS ---
heights = [0, repmat(step_height, 1, num_steps), 0];
sequence = [1, 3:(num_steps+2), 2];
profile1 = {heights, sequence};

%% --- 6. FIGURE 2: GEOMETRY VERIFICATION ---
x_mesh = linspace(-period/2, period/2, 200);
parm_geom = res0;
parm_geom.res3.cale = [];       
parm_geom.res3.trace = 1;       % GENERATES FIGURE 2
figure(2);
[~, ~, ~] = res3(x_mesh, aa, profile1, [1, 1], parm_geom); 
title('Figure 2: 13.5^o Blazed Staircase Geometry');



%% --- 7. STEP 2: DIFFRACTION STUDY ---
ef = res2(aa, profile1);

% Print Energy Balance to Command Window
fprintf('--- Energy Balance ---\n');
fprintf('TE Reflection: %.2f%%\n', sum(ef.TEinc_top_reflected.efficiency)*100);
fprintf('TM Reflection: %.2f%%\n', sum(ef.TMinc_top_reflected.efficiency)*100);

%% --- 8. FIGURE 3: FIELD MAPPING (Shadowing Visualization) ---
% We look at TE incidence [1, 0] to see clear shadowing
incident_field = [1, 0]; 
parm_field = res0;
parm_field.res3.trace = 1;      % GENERATES FIGURE 3: Field Maps
figure(3);
[e, z, o] = res3(x_mesh, aa, profile1, incident_field, parm_field);
subplot(2,2,1); title('Shadowing/Field Map (Ex)');



%% --- 9. FIGURE 4: ORDER EFFICIENCY BAR CHART ---
target_orders = -2:2; 
num_o = length(target_orders);
te_ref = zeros(1, num_o); tm_ref = zeros(1, num_o);
rTE = ef.TEinc_top_reflected; rTM = ef.TMinc_top_reflected;

for i = 1:num_o
    m = target_orders(i);
    idx_te = find(rTE.order == m);
    if ~isempty(idx_te), te_ref(i) = rTE.efficiency(idx_te(1)) * 100; end
    idx_tm = find(rTM.order == m);
    if ~isempty(idx_tm), tm_ref(i) = rTM.efficiency(idx_tm(1)) * 100; end
end

figure(4); set(gcf, 'Color', 'w');
bar(target_orders, [te_ref; tm_ref]');
xlabel('Diffraction Order (m)'); ylabel('Efficiency (%)');
title(['Figure 4: Efficiency at Grazing Incidence (\theta = 86.25^o)']);
legend('TE Incident', 'TM Incident'); grid on;



[Image of diffraction orders from a grating]


%% --- 10. CLEANUP ---
retio;