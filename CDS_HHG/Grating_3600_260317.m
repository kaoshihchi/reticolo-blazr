% RETICOLO V7 - 3600 lines/mm Grating Simulation
% Following variable definitions in the Technical Note (Institut d'Optique)

clear all; close all;
% 設定路徑 [cite: 7, 516]
addpath("C:\Users\BeamStablizer\Documents\GitHub\reticolo-blazr\RETICOLO V7\reticolo_allege");

% --- 1. Preliminary input parameters (Section 3) ---
lines_per_mm = 3600;
period = (1/lines_per_mm) * 1e6;     % Grating period (d) in nm
nn = 20;                            % Fourier harmonics retained (-nn to nn)
wavelengths_scan = 3:0.5:18;        % Wavelengths (lambda) in vacuum

% 幾何與角度設定 (Geometry in Fig. 2)
grazing_angle = 3.75;               % Experimental grazing angle (deg)
theta_inc = 90 - grazing_angle;     % Polar angle theta_inc
angle_delta = 15;                   % Azimuthal angle delta (phi)

% 初始化參數結構
parm = res0; 
parm.res1.champ = 1;                % Calculate fields accurately

% --- 2. Structure definition (Section 4) ---
blaze_angle = 13.5;                 % Blazed angle (deg)
h_max = period * tan(deg2rad(blaze_angle)); 
num_layers = 15;                    % Staircase approximation layers
layer_thickness = h_max / num_layers;

% 定義 Profile 堆疊資訊
heights = ones(1, num_layers) * layer_thickness;
texture_labels = 3:(num_layers + 2); 
profile = {heights, texture_labels}; % profile variable

eff_1st = zeros(size(wavelengths_scan));

% --- 3. Main Computation Loop ---
for i = 1:length(wavelengths_scan)
    wavelength = wavelengths_scan(i); % wavelength parameter
    
    % 材料設定 (Refractive indices)
    n_inc = 1;                        % Top medium index (Vacuum)
    n_au = 0.998 + 0.005i;            % Placeholder for Gold index
    
    % 定義 Textures (Section 4.1)
    textures = cell(1, num_layers + 2);
    textures{1} = {n_inc};            % Top uniform texture
    textures{2} = {n_au};             % Bottom uniform texture
    
    for j = 1:num_layers
        w_j = (j / num_layers) * period; 
        % 定義閃耀階梯坡度 (使用兩個點確保 N > 1 以避免 retu 錯誤)
        textures{j+2} = {[0, w_j], [n_au, 1]}; 
    end
    
    % 計算歸一化平行波向量
    k_parallel = n_inc * sin(deg2rad(theta_inc)); 
    
    % Solving eigenmode problem (Section 5)
    aa = res1(wavelength, period, textures, nn, k_parallel, angle_delta, parm);
    
    % Computing diffracted waves (Section 6)
    result = res2(aa, profile);
    
    % 提取繞射效率 (Section 6.1)
    % 注意：在 Conical 模式下使用 TEinc_... 或 TMinc_...
    % 提取級次 -1 (閃耀方向)
    try
        eff_1st(i) = result.TEinc_top_reflected.efficiency{1}; 
    catch
        eff_1st(i) = 0; % 若階次不可傳播則為 0
    end
    
    % 清除暫存檔以釋放空間 (Section 10.2)
    retio; 
    
    fprintf('Lambda: %.2f nm | Efficiency: %.4f%%\n', wavelength, eff_1st(i)*100);
end

% --- 4. Plotting Results ---
figure('Color', 'w');
plot(wavelengths_scan, eff_1st * 100, 'b-o', 'LineWidth', 1.5);
grid on; xlabel('Wavelength (nm)'); ylabel('1st Order Efficiency (%)');
title(['3600 lines/mm Grating (Blaze ', num2str(blaze_angle), '^\circ)']);