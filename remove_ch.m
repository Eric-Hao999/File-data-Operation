% removeChineseAndNonASCII.m
% 说明：
%   此脚本自动检测输入文件的编码，读取文件内容后：
%   1. 直接根据 Unicode 码点过滤掉常用汉字（U+4E00 到 U+9FFF）。
%   2. 再对结果进行后处理，删除所有非 ASCII 可打印字符（只保留代码 32～126 的字符，
%      同时保留换行 (10)、回车 (13) 和制表符 (9)）。
%   最终以 UTF-8 编码写入新文件。
%
% 使用前请确保输入文件与 MATLAB 工作目录对应，或修改 inputFile 和 outputFile。

%% 1. 设置输入和输出文件名
inputFile  = 'LBM_DEM2_correct4.cu';       % 输入文件（请根据实际情况修改）
outputFile = 'LBM_DEM2_correct4_noch.cu';    % 输出文件

%% 2. 检测文件编码
detectedEncoding = detectEncoding(inputFile);
fprintf('检测到的文件编码：%s\n', detectedEncoding);
% 若检测到 GBK，则使用 GB2312（MATLAB 对 GB2312 的支持较好）
if strcmpi(detectedEncoding, 'GBK')
    fileEncoding = 'GB2312';
else
    fileEncoding = detectedEncoding;
end

%% 3. 读取文件内容并转换为 Unicode 文本
fid = fopen(inputFile, 'rb'); % 以二进制方式打开
if fid == -1
    error('无法打开文件: %s', inputFile);
end
rawBytes = fread(fid, Inf, '*uint8'); % 读取所有字节 
fclose(fid);

try
    fileContent = native2unicode(rawBytes, fileEncoding);
    % 若 fileContent 是列向量，则转换为一行（1×N 的字符数组）
    fileContent = reshape(fileContent, 1, []);
    fprintf('读取的文件内容类型: %s, 大小: %s\n', class(fileContent), mat2str(size(fileContent)));
catch ME
    error('字符编码转换失败: %s', ME.message);
end

%% 4. 删除中文汉字
% 第一阶段：按 Unicode 码点过滤中文字符（常用汉字范围：U+4E00 到 U+9FFF，对应十进制 [19968,40959]）
codepoints = double(fileContent);
isChinese = (codepoints >= 19968 & codepoints <= 40959);
contentNoChinese = fileContent(~isChinese);

%% 5. 删除非 ASCII 杂质字符
% 这里保留 ASCII 可打印字符（码点 32～126）以及换行 (10)、回车 (13) 与制表符 (9)。
codepoints2 = double(contentNoChinese);
allowed = ((codepoints2 >= 32 & codepoints2 <= 126) | (codepoints2==10) | (codepoints2==13) | (codepoints2==9));
finalContent = contentNoChinese(allowed);

fprintf('处理后内容大小: %s\n', mat2str(size(finalContent)));

%% 6. 写入新文件（统一以 UTF-8 编码）
fid = fopen(outputFile, 'w', 'n', 'UTF-8');
if fid == -1
    error('无法写入文件: %s', outputFile);
end
fwrite(fid, finalContent, 'char');
fclose(fid);

fprintf('处理完成，生成文件：%s\n', outputFile);

%% --- 子函数：检测文件编码 ---
function encoding = detectEncoding(filename)
    % detectEncoding 自动检测文件的编码
    % 本函数通过读取文件前 4 个字节（BOM）来判断：
    %   若检测到 UTF-8 BOM（EF BB BF）则返回 'UTF-8'
    %   若检测到 UTF-16BE BOM（FE FF）则返回 'UTF-16BE'
    %   若检测到 UTF-16LE BOM（FF FE）则返回 'UTF-16LE'
    %   否则，默认返回 'GBK'
    
    fid = fopen(filename, 'rb');
    if fid == -1
        error('无法打开文件: %s', filename);
    end
    raw = fread(fid, 4, 'uint8');
    fclose(fid);
    
    if numel(raw) >= 3 && isequal(raw(1:3)', [239, 187, 191])
        encoding = 'UTF-8';
    elseif numel(raw) >= 2 && isequal(raw(1:2)', [254, 255])
        encoding = 'UTF-16BE';
    elseif numel(raw) >= 2 && isequal(raw(1:2)', [255, 254])
        encoding = 'UTF-16LE';
    else
        encoding = 'GBK';
    end
end
