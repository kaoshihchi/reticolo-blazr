% =========================================================================
% 腳本名稱: 錐面繞射場分佈與效率分析 (Conical Diffraction Analysis)
% 物理背景: 模擬三維空間入射下的一維光柵，並動態顯示不同偏振態下的電磁場近場分佈。
% =========================================================================

clear all; close all; clc;

% --- 1. 環境與路徑設定 ---
% 使用 pwd 直接獲取當前路徑，避免變數名稱混淆
lib_path = fullfile(pwd, 'RETICOLO V7', 'reticolo_allege');

if exist(lib_path, 'dir')
    addpath(genpath(lib_path)); % 使用 genpath 可以包含子資料夾
    fprintf('成功載入 RETICOLO V7 函式庫。\n');
else
    error('找不到路徑：%s\n請確認您的 MATLAB 目前資料夾 (Current Folder) 正確。', lib_path);
end

% --- 2. 物理參數定義 ---
wavelength = 6;      % 照射波長 (Lambda)
period = 10;         % 光柵週期 (D)
theta0 = 30;         % 極角 (Polar angle, θ): 入射光與法線的夾角
delta0 = 20;         % 方位角 (Azimuthal angle, φ): 決定「錐面」繞射的角度
nn = 5;              % 傅立葉階數 (Fourier orders): 數值愈大愈精確，但運算較慢

% 座標變換參數 (ro = n * sin(theta))
n_superstrate = 1;   
ro = n_superstrate * sin(theta0 * pi/180);

% --- 3. 設定模擬器參數 (res0) ---
param = res0;
param.res1.champ = 1; % 開啟「精確場計算」模式，這對於後續繪製近場圖（Near-field）至關重要

% --- 4. 定義光柵紋理 (Textures) ---
% 這裡定義了模擬空間中的每一層材料分佈
textures{1} = 1;                  % 上層介質 (空氣, n=1)
textures{2} = 1.5;                % 下層基板 (Substrate, n=1.5)
textures{3} = {[-2.5, 2.5], [1.5, 1]}; % 繞射層: 在中心 5 單位寬度內 index=1.5，其餘為 1

% 初始化 RCWA 計算引擎
aa = res1(wavelength, period, textures, nn, ro, delta0, param);

% --- 5. 定義光柵縱向剖面 (Profile) ---
% profil = {各層厚度, 各層對應的 texture 編號}
% 這裡定義了：厚度 0 的蓋層, 厚度 20 的光柵層 (使用 texture 3), 厚度 0 的底層
grating_profile = {[0, 20, 0], [1, 3, 2]};

% 執行核心計算：計算本徵模態與繞射場
[eff_struct, tab] = res2(aa, grating_profile);

% --- 6. 提取繞射效率 (Efficiency) ---
% 提取第 0 級繞射的透射 (T) 與反射 (R) 效率
T0 = eff_struct.TEinc_top_transmitted.efficiency_TE{0};
R0 = eff_struct.TEinc_top_reflected.efficiency_TE{0};

fprintf('--- 繞射效率分析 ---\n');
disp(rettexte(R0, T0)); % 使用內部函式格式化輸出結果

% --- 7. 近場電磁場分佈計算 (Field Visualization) ---
% 定義 X 軸取樣點 (橫跨一個週期)
x_coords = linspace(0, period, 150);

% 重新設定參數以進行場掃描
field_param = res0;
field_param.res2.result = 0;      
field_param.res3.npts = [5, 40, 5]; % 定義每一層在 Z 軸方向的取樣點數

% 再次定義剖面深度以進行場繪製 (總深度 5+20+5 = 30)
visual_profile = {[5, 20, 5], [1, 3, 2]};

% 計算基礎偏振態下的場 (TE 與 TM 分量)
e_inc_TE = [0, 1]; [eTE, z_coords, obj_geometry] = res3(x_coords, aa, visual_profile, e_inc_TE, field_param);
e_inc_TM = [1, 0]; [eTM, z_coords, obj_geometry] = res3(x_coords, aa, visual_profile, e_inc_TM, field_param);

% --- 8. 動態繪圖：旋轉偏振方向 (Psi) ---
figure('Name', 'Conical Diffraction Near-Field Mapping', 'Color', 'w');

for psi = 0:20:180
    % 根據偏振角 psi 合成場強度
    % e(:,:,1:3) 是電場 EX, EY, EZ; e(:,:,4:6) 是磁場 HX, HY, HZ
    e_combined = eTE * cos(psi * pi/180) + eTM * sin(psi * pi/180);
    
    % A. 繪製幾何結構
    subplot(3,3,2); retcolor(x_coords, z_coords, real(obj_geometry)); 
    title('Grating Cross-section (n)');
    
    % B. 顯示當前偏振向量方向
    subplot(3,3,3); plot([0, cos(psi*pi/180)], [0, sin(psi*pi/180)], 'LineWidth', 2);
    axis([-1, 1, -1, 1]); axis square; title(['Polarization \psi = ', num2str(psi), '°']);
    
    % C. 繪製電場分量 (Intensity |E|^2)
    subplot(3,3,4); retcolor(x_coords, z_coords, abs(e_combined(:,:,1)).^2); title('|EX|^2');
    subplot(3,3,5); retcolor(x_coords, z_coords, abs(e_combined(:,:,2)).^2); title('|EY|^2');
    subplot(3,3,6); retcolor(x_coords, z_coords, abs(e_combined(:,:,3)).^2); title('|EZ|^2');
    
    % D. 繪製磁場分量 (Intensity |H|^2)
    subplot(3,3,7); retcolor(x_coords, z_coords, abs(e_combined(:,:,4)).^2); title('|HX|^2');
    subplot(3,3,8); retcolor(x_coords, z_coords, abs(e_combined(:,:,5)).^2); title('|HY|^2');
    subplot(3,3,9); retcolor(x_coords, z_coords, abs(e_combined(:,:,6)).^2); title('|HZ|^2');
    
    drawnow; % 即時更新動畫
end

retio; % 結束輸入輸出處理