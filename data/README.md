# 数据说明

## 来源与范围

- NOAA Mauna Loa CO₂ 数据来源：[NOAA Global Monitoring Laboratory：Trends in Atmospheric Carbon Dioxide](https://gml.noaa.gov/ccgg/trends/data.html)。
- 原论文使用的历史范围：1958 年 3 月—2018 年 5 月，月度观测。
- 数据单位：ppm。
- NOAA 页面说明其记录可能因质量控制检查而更新；为提高与论文结果的可比性，优先使用论文作者提供的固定版本数据（ECOTOOL 官方仓库中的 dataPLOSpaper.mat），并在实验记录中注明版本和来源。

## 后续数据准备

后续下载时在本目录保存原始来源文件，并记录文件名、下载日期、来源链接和版本信息。检查文件格式、列名或列序、日期范围、月度连续性、缺失值标记、单位及 CO₂ 观测列；依据复现协议核对论文所用数据版本和索引。

## 原始数据与预处理序列

原始观测文件应保持原样并与预处理结果区分。预处理后的序列应另行保存并记录变换步骤、样本范围和生成依据，不覆盖原始观测值。

本机已经存在`data/dataPLOSpaper.mat`，但它在当前C分支中为未跟踪文件，克隆当前分支不会自动得到它。已完成实验使用其中的`CO2`列：723个月，1958-03至2018-05，无缺失，单位ppm。不要用更新后的NOAA序列替换该固定版本。

使用的完整MAT文件SHA-256为：

`4227a1d932b5765418957df172b767e5a9db3422979be01e5e56eb4ad7d25092`

## 从固定Git对象准备数据

A分支历史提交`f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6`已经保存了同版本数据。新克隆的同学先在项目根目录执行`git fetch origin Ariel`，获取该提交历史；此操作不会切换或修改组员分支。随后在MATLAB项目根目录运行以下代码。已有数据只核验，不覆盖。

```matlab
% 使用固定历史对象，禁止以当前远端分支头替代固定提交。
dataPath=fullfile(pwd,'data','dataPLOSpaper.mat');
expected='4227a1d932b5765418957df172b767e5a9db3422979be01e5e56eb4ad7d25092';
if ~isfile(dataPath)
    tmp=[tempname '.mat'];
    [status,msg]=system(sprintf('git show f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6:data/dataPLOSpaper.mat > "%s"',tmp));
    assert(status==0,'%s',msg);
    source=tmp;
else
    source=dataPath;
end
% 验证完整文件指纹，通过后才复制到数据目录。
fid=fopen(source,'rb'); assert(fid>=0);
bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(bytes,'int8'));
actual=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
assert(strcmp(actual,expected),'数据版本不符，请保留现有文件并排查来源');
S=load(source,'CO2'); assert(numel(S.CO2)==723 && all(isfinite(S.CO2(:))));
if ~isfile(dataPath), [ok,msg]=movefile(source,dataPath); assert(ok,'%s',msg); end
```

ECOTOOL需另行安装。本次环境为MATLAB R2026a Update 5、ECOTOOL 1.0，接口和后端SHA-256记录在检查点中。使用其他工具箱版本时可检查既有预测，但若重新估计，结果不保证完全一致；运行入口会拒绝使用不同依赖继续旧检查点。
