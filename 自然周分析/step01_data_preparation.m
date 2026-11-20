%% 第1步：七天周期数据读取与初步分析（仅训练期金额）
clear;
clc;
close all;
projectDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(projectDir, 'output');
if ~isfolder(outputDir), mkdir(outputDir); end
filePath = fullfile(fileparts(projectDir), 'data', '自然周.xlsx');
assert(isfile(filePath), '数据文件不存在：%s', filePath);
periodLabel = '自然周';
modelSheet = '02_UC直接建模';
summarySheet = '03_周期统计';
cutoff = datetime(2026,10,1);

%% 1.1 仅读取全部周期日期，按周期结束日确定训练范围
% 02表仅包含完整周期；自然周05表中的首尾不完整周期不参与建模。
% 此处只读取日期列，测试期金额不进入工作区、图表或模型。
dateCells = readcell(filePath, 'Sheet', modelSheet, 'Range', 'A2:A113');
allDates = datetime(string(dateCells(:)), 'InputFormat', 'yyyy-MM-dd');
expectedDates = datetime(2024,9,2) + caldays(7*(0:111)');
assert(isequal(allDates, expectedDates), '周期日期应完整、唯一且按起始日升序排列。');
allEndDates = allDates + caldays(6);
trainMask = allEndDates < cutoff;
assert(sum(trainMask)==108 && all(trainMask(1:108)) && ~any(trainMask(109:end)), ...
    '训练期应为截至2026年9月的108个完整周期，跨月周期不得进入训练集。');
tTest = allDates(~trainMask); % 仅保留测试周期日期，不读取金额
nTrain = sum(trainMask);

%% 1.2 只读取训练期建模表及组成核对字段
% Range限定至训练末行，包含表头；禁止先读全部金额再切分。
data = readtable(filePath, 'Sheet', modelSheet, ...
    'Range', sprintf('A1:C%d', nTrain+1), ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
summary = readtable(filePath, 'Sheet', summarySheet, ...
    'Range', sprintf('A1:F%d', nTrain+1), ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
tTrain = datetime(string(data{:, '周期起始日'}), 'InputFormat', 'yyyy-MM-dd');
yTrain = double(data{:, '个人总支付_元'});
regularTrain = double(data{:, '常规支付_元'});
irregularTrain = double(summary{:, '偶发支出剔除_元'});
summaryStart = datetime(string(summary{:, '起始日期'}), 'InputFormat', 'yyyy-MM-dd');
summaryEnd = datetime(string(summary{:, '终止日期'}), 'InputFormat', 'yyyy-MM-dd');
assert(isequal(tTrain, allDates(trainMask)) && isequal(summaryStart,tTrain) && ...
    isequal(summaryEnd,tTrain+caldays(6)), '建模表与周期统计日期不一致。');
assert(all(isfinite([yTrain;regularTrain;irregularTrain])) && ...
    all([yTrain;regularTrain;irregularTrain]>=0), '训练金额存在缺失、无效或负数。');
assert(all(abs(yTrain-double(summary{:, '个人总支付_元'}))<1e-6) && ...
    all(abs(regularTrain-double(summary{:, '常规支付_元'}))<1e-6) && ...
    all(abs(yTrain-regularTrain-irregularTrain)<1e-6), '训练金额及组成核对失败。');
% 偶发支出是原表提供的组成金额，不在本分析中再次删除或重新分类。

%% 1.3 训练集描述性统计
fprintf('\n========== %s：训练数据检查通过 ==========\n',periodLabel);
fprintf('完整周期总数：%d；训练：%d；保留测试：%d（未读取测试金额）\n', ...
    numel(allDates),nTrain,numel(tTest));
fprintf('训练覆盖：%s 至 %s；测试起始日：%s\n', ...
    datestr(tTrain(1),'yyyy-mm-dd'), datestr(summaryEnd(end),'yyyy-mm-dd'), ...
    datestr(tTest(1),'yyyy-mm-dd'));
[maxExpense,maxIdx] = max(yTrain);
fprintf('每期平均：%.2f 元；中位数：%.2f 元；标准差：%.2f 元\n', ...
    mean(yTrain),median(yTrain),std(yTrain));
fprintf('每期最低：%.2f 元；最高：%.2f 元（起始日 %s）\n', ...
    min(yTrain),maxExpense,datestr(tTrain(maxIdx),'yyyy-mm-dd'));
seriesNames = ["个人总支付";"常规支付";"偶发支出"];
values = [yTrain,regularTrain,irregularTrain];
description = table(seriesNames, mean(values,1)',median(values,1)',std(values,0,1)', ...
    min(values,[],1)',max(values,[],1)',sum(values,1)', ...
    'VariableNames',{'Series','MeanYuan','MedianYuan','SDYuan','MinYuan','MaxYuan','SumYuan'});
writetable(description,fullfile(outputDir,'训练期描述性统计.csv'),'Encoding','UTF-8');

%% 1.4 绘制训练集趋势和支出结构
f = figure('Name','个人总支付时间序列','Color','w');
plot(tTrain,yTrain,'-o','LineWidth',1.5,'MarkerSize',3); grid on;
xlabel('周期起始日'); ylabel('每期个人总支付（元）');
title([periodLabel '个人总支付训练期趋势']);
xtickformat('yyyy-MM-dd'); xtickangle(45);
exportFigureByTitle(f,outputDir);
f = figure('Name','支出结构比较','Color','w');
plot(tTrain,yTrain,'-o','LineWidth',1.5,'MarkerSize',3); hold on;
plot(tTrain,regularTrain,'-s','LineWidth',1.2,'MarkerSize',3); hold off; grid on;
xlabel('周期起始日'); ylabel('每期支付金额（元）');
title([periodLabel '个人总支付与常规支付对比']);
legend('个人总支付','常规支付','Location','best');
xtickformat('yyyy-MM-dd'); xtickangle(45);
exportFigureByTitle(f,outputDir);
save(fullfile(outputDir,'step01_training_data.mat'), ...
    'tTrain','yTrain','regularTrain','irregularTrain','tTest', ...
    'periodLabel','cutoff','filePath');
if exist('modelUC','file')~=2
    disp('尚未检测到ECOTOOL；第三步将尝试加载原项目的工具箱路径。');
end
disp('========== 第1步运行完成 ==========');
