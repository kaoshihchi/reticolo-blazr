% MATLAB Script: Create_AI_Knowledge_Base.m
% 功能：遞迴合併當前目錄及子目錄下所有 .m 檔案，建立 AI 專用知識庫。

outputFileName = 'MATLAB_Knowledge_Base.txt';
files = dir('**/*.m'); % 遞迴搜尋所有 .m 檔案
thisScriptName = [mfilename, '.m']; % 取得目前腳本名稱以利排除

fid_out = fopen(outputFileName, 'w', 'n', 'UTF-8');
if fid_out == -1
    error('無法建立輸出檔案，請檢查權限。');
end

fprintf('開始掃描檔案...\n');
count = 0;

for i = 1:length(files)
    % 排除資料夾項目與本腳本自身
    if files(i).isdir || strcmp(files(i).name, thisScriptName)
        continue;
    end
    
    filePath = fullfile(files(i).folder, files(i).name);
    
    try
        % 讀取原始碼內容
        content = fileread(filePath);
        
        % 寫入結構化標籤
        fprintf(fid_out, '========================================\n');
        fprintf(fid_out, '[FILE_PATH]: %s\n', filePath);
        fprintf(fid_out, '[CODE_START]\n');
        fprintf(fid_out, '%s\n', content);
        fprintf(fid_out, '[CODE_END]\n');
        fprintf(fid_out, '----------------------------------------\n\n');
        
        count = count + 1;
        fprintf('已加入: %s\n', files(i).name);
    catch
        warning('無法讀取檔案: %s', filePath);
    end
end

fclose(fid_out);
fprintf('\n掃描完成！總共合併了 %d 個檔案。\n', count);
fprintf('結果已儲存至: %s\n', outputFileName);