
%% 第1步：数据读取与初步分析
clear;
clc;
close all;

%% 1.1 读取CSV文件

% 获取当前脚本所在目录
projectDir = fileparts(mfilename('fullpath'));

% 指定CSV文件路径
filePath = fullfile(projectDir, 'data', ...
    'UC个人总支出_月度_含美元.csv');

% 检查文件是否存在
if ~isfile(filePath)
    error('CSV文件不存在，请检查路径：%s', filePath);
end

% 先仅读月份列，按日期定位训练行；测试月金额在第六步锁定预测前不读入。
opts = detectImportOptions(filePath, 'VariableNamingRule', 'preserve', 'TextType', 'string');
opts.SelectedVariableNames = {'月份'};
monthTable = readtable(filePath, opts);
allMonths = datetime(string(monthTable{:, '月份'}), 'InputFormat', 'yyyy-MM');
assert(isequal(sort(allMonths), datetime(2024,9,1)+calmonths((0:25)')), ...
    'CSV应恰好包含2024-09至2026-10的连续月份。');
trainingRows = find(allMonths >= datetime(2024,9,1) & allMonths <= datetime(2026,9,1));
opts.SelectedVariableNames = opts.VariableNames;
% 每个区间对应一行CSV（第一行为表头），支持原始行顺序不按月排列。
opts.DataLines = [trainingRows+1, trainingRows+1];
data = readtable(filePath, opts);
disp('========== 训练数据读取成功（未读取测试金额） ==========');
disp(head(data, 5));
%% 1.2 提取日期和目标变量

% 将月份字符串转换成MATLAB日期类型
dates = datetime(string(data{:,'月份'}), ...
    'InputFormat', 'yyyy-MM');

% 统一为每月第一天，便于检查月份是否连续
dates = dateshift(dates, 'start', 'month');

% 目标变量：个人总支付金额，单位为元
y = data{:,'个人总支付_元'};

% 额外提取两个组成字段，只用于描述性分析
regular = data{:,'个人常规支付_元'};
irregular = data{:,'非经常大额_元'};

% 按照时间从早到晚排序
[dates, idx] = sort(dates);
y = y(idx);
regular = regular(idx);
irregular = irregular(idx);


%% 1.3 数据质量检查

fprintf('\n========== 数据质量检查 ==========\n');

fprintf('原始样本数量：%d\n', length(y));
fprintf('缺失或非有限金额数量：%d\n', sum(~isfinite(y)));

% 验证不存在缺失金额
assert(all(isfinite([y; regular; irregular])), '支出金额存在缺失或无效数据');

% 验证没有重复月份
assert(length(unique(dates)) == length(dates), ...
    '存在重复月份，请检查原始数据');

% 检查训练期是否逐月连续
expectedDates = datetime(2024,9,1) ...
    + calmonths(0:24);
expectedDates = expectedDates(:);

assert(isequal(dates, expectedDates), ...
    '月份存在缺失、重复或超出预期范围');

% 验证总支付金额的组成关系
assert(all(abs(y - regular - irregular) < 1e-6), ...
    '个人总支付与其组成金额不一致');

disp('数据质量检查通过。');


%% 1.4 划分训练集和测试集

% 训练：2024年9月到2026年9月
trainMask = dates >= datetime(2024,9,1) & ...
            dates <= datetime(2026,9,1);

% 测试：2026年10月
testMask = dates == datetime(2026,10,1);

% 防止日期划分错误
assert(sum(trainMask) == 25, ...
    '训练集月份数量应为25');
assert(~any(testMask), '本步不应读入测试月金额');

tTrain = dates(trainMask);
yTrain = y(trainMask);

regularTrain = regular(trainMask);
irregularTrain = irregular(trainMask);

tTest = dates(testMask);
% 不创建yTest；测试金额仅在第六步预测锁定后读取。

fprintf('\n训练集样本量：%d\n', length(yTrain));
fprintf('独立测试月2026-10已保留，本步未读取测试金额。\n');

% 注意：
% 后续建模、参数选择、滚动验证只使用yTrain
% yTest只在最终预测完成后用于评价


%% 1.5 训练集描述性统计

fprintf('\n========== 训练集描述性统计 ==========\n');

fprintf('平均月支出：%.2f 元\n', mean(yTrain));
fprintf('月支出中位数：%.2f 元\n', median(yTrain));
fprintf('月支出标准差：%.2f 元\n', std(yTrain));
fprintf('最低月支出：%.2f 元\n', min(yTrain));
fprintf('最高月支出：%.2f 元\n', max(yTrain));

% 找出最高支出月份
[maxExpense, maxIdx] = max(yTrain);

fprintf('最高支出月份：%s，%.2f 元\n', ...
    datestr(tTrain(maxIdx), 'yyyy-mm'), maxExpense);


%% 1.6 绘制训练集时间序列图

figure('Name','个人总支付时间序列', ...
    'Color','w');

plot(tTrain, yTrain, '-o', ...
    'LineWidth', 1.5, ...
    'MarkerSize', 4);

grid on;

xlabel('月份');
ylabel('个人总支付金额（元）');
title('2024年9月至2026年9月个人总支付趋势');

xtickformat('yyyy-MM');
xtickangle(45);


exportFigureByTitle(gcf);

%% 1.7 绘制常规支出与总支付对比图

figure('Name','支出结构比较', ...
    'Color','w');

plot(tTrain, yTrain, '-o', ...
    'LineWidth', 1.5);

hold on;

plot(tTrain, regularTrain, '-s', ...
    'LineWidth', 1.2);

hold off;
grid on;

xlabel('月份');
ylabel('支付金额（元）');
title('个人总支付与常规支付对比');

legend('个人总支付','个人常规支付', ...
    'Location','best');

xtickformat('yyyy-MM');
xtickangle(45);


exportFigureByTitle(gcf);
outputDir = fullfile(projectDir, 'output');
save(fullfile(outputDir, 'step01_training_data.mat'), ...
    'tTrain', 'yTrain', 'regularTrain', 'irregularTrain');

%% 1.8 检查ECOTOOL是否已经配置

fprintf('\n========== ECOTOOL环境检查 ==========\n');

if exist('modelUC', 'file') == 2
    disp('已检测到ECOTOOL的modelUC函数。');
    which modelUC
else
    disp('暂未检测到ECOTOOL的modelUC函数。');
    disp('后续建模前需要安装并添加ECOTOOL路径。');
end

disp('========== 第1步运行完成 ==========');

