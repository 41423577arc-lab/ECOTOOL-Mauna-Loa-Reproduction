%% ============================================================
%  成员A 应用案例：日度消费 ETS（s = 7）
%  数据：2024-09-01 ~ 2026-10-31，791 天
%  模型：ETS AA7（加法趋势 + 星期季节） vs ETS AN（仅趋势）
%  划分：前 700 天训练，后 91 天（13 周）测试
%  说明：vspectrum 与 R2026a 不兼容，周期图改用 fft 实现
%% ============================================================
clear; close all; clc

% 统一工作目录，保证相对路径 results/... 能找到
cd('G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction');

%% 0. 读取数据
csvPath = 'G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction\data\成员A_日.csv';
T = readtable(csvPath, 'VariableNamingRule', 'preserve');

y_all = T.("当日消费_元") / 1000;      % 换算成千元
t_all = datetime(T.("日期"));
n = numel(y_all);

fprintf('样本: %d 天，%s ~ %s\n', n, datestr(t_all(1)), datestr(t_all(end)));
fprintf('零消费天: %d (%.1f%%)\n', sum(y_all == 0), 100*mean(y_all == 0));
fprintf('日均: %.3f 千元，最大: %.3f 千元\n', mean(y_all), max(y_all));

%% 1. 诊断一：ACF / PACF
% vident 在 R2026a 下可正常使用
vident(y_all, 40, 7);

%% 2. 诊断二：周期图（fft 实现，不依赖 ECOTOOL）
x = y_all - mean(y_all);
X = fft(x);
P = abs(X).^2 / numel(x);
P = P(1:floor(numel(x)/2)+1);
f = (0:floor(numel(x)/2))' / numel(x);     % 每天多少个周期

f1 = figure('Color','w','Position',[100 100 800 380]);
plot(1./f(2:end), P(2:end), 'LineWidth', 1.2);
xlim([1 60]);
xlabel('Period (days)'); ylabel('Power');
title('Periodogram of daily spending');
grid on; box off;
exportgraphics(f1, 'results/figures/A_weeks_test/A_case_periodogram.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

%% 3. 诊断三：星期几的平均消费（最能说明 s=7 的依据）
wd = weekday(t_all);                        % 1=周日 ... 7=周六
meanByDay = accumarray(wd, y_all, [], @mean);

f2 = figure('Color','w','Position',[100 100 700 350]);
bar(1:7, meanByDay);
set(gca, 'XTick', 1:7, 'XTickLabel', ...
    {'Sun','Mon','Tue','Wed','Thu','Fri','Sat'});
ylabel('Mean spending (thousand CNY)');
title('Average daily spending by weekday');
grid on; box off;
exportgraphics(f2, 'results/figures/A_weeks_test/A_case_weekday.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

fprintf('\n星期均值（千元）:\n');
disp(array2table(meanByDay(:)', 'VariableNames', ...
    {'Sun','Mon','Tue','Wed','Thu','Fri','Sat'}));

%% 4. 原始序列
f3 = figure('Color','w','Position',[100 100 1000 380]);
plot(t_all, y_all, 'LineWidth', 0.8);
xlabel('Date'); ylabel('Spending (thousand CNY)');
title('Member A: daily spending, 2024-09-01 to 2026-10-31');
grid on; box off;
exportgraphics(f3, 'results/figures/A_weeks_test/A_case_daily_series.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

%% 5. 划分训练 / 测试
L = 700;               % 训练 700 天
H = 91;                % 测试 91 天 = 13 周
y      = y_all(1:L);
actual = y_all(L+1:L+H);
t_y    = t_all(1:L);
t_a    = t_all(L+1:L+H);

fprintf('\n训练: %s ~ %s\n', datestr(t_y(1)), datestr(t_y(end)));
fprintf('测试: %s ~ %s\n', datestr(t_a(1)), datestr(t_a(end)));

%% 6. 拟合两个模型
mAA = modelETS(y, [], 'AA7', H);       % 有星期季节
mAN = modelETS(y, [], 'AN',  H);       % 无季节，只有趋势

fAA = mAA.py(:);  fAA(fAA < 0) = 0;    % 消费不能为负
fAN = mAN.py(:);  fAN(fAN < 0) = 0;

disp('===== ETS AA7 ====='); disp(mAA.table);
disp('===== ETS AN  ====='); disp(mAN.table);

%% 7. 指标
smape = @(a,f) mean(200*abs(a-f)./(abs(a)+abs(f)));
mase  = @(a,f,tr,s) mean(abs(a-f)) / mean(abs(tr(s+1:end) - tr(1:end-s)));

% 全样本
smAA = smape(actual, fAA);   maAA = mase(actual, fAA, y, 7);
smAN = smape(actual, fAN);   maAN = mase(actual, fAN, y, 7);

% 只在非零实际值的日子上算 sMAPE（零值会让 sMAPE 失去意义）
mask = actual > 0;
smAA_nz = smape(actual(mask), fAA(mask));
smAN_nz = smape(actual(mask), fAN(mask));

% 按周汇总后算 sMAPE（91 天恰好 13 周，周总和几乎没有 0）
aw  = sum(reshape(actual, 7, []), 1)';
wAA = sum(reshape(fAA, 7, []), 1)';
wAN = sum(reshape(fAN, 7, []), 1)';
smAA_w = smape(aw, wAA);
smAN_w = smape(aw, wAN);

fprintf('\n%-6s %12s %12s %12s %10s\n', ...
    '模型', 'sMAPE(全部)', 'sMAPE(非零日)', 'sMAPE(周汇总)', 'MASE');
fprintf('%-6s %12.2f %12.2f %12.2f %10.3f\n', 'AA7', smAA, smAA_nz, smAA_w, maAA);
fprintf('%-6s %12.2f %12.2f %12.2f %10.3f\n', 'AN',  smAN, smAN_nz, smAN_w, maAN);

%% 8. 预测图
f4 = figure('Color','w','Position',[100 100 1000 420]);
hold on;
plot(t_y, y, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.7);
plot(t_a, actual, 'k-',  'LineWidth', 1.6);
plot(t_a, fAA,    'r--', 'LineWidth', 1.5);
plot(t_a, fAN,    'b-.', 'LineWidth', 1.5);
xlabel('Date'); ylabel('Spending (thousand CNY)');
legend({'Training','Actual','ETS AA7','ETS AN'}, 'Location', 'northwest');
title('Daily spending: ETS forecasts, last 91 days');
grid on; box off; hold off;
exportgraphics(f4, 'results/figures/A_weeks_test/A_case_ets_forecast.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

%% 9. 保存预测结果，供组内汇总
Tout = table( ...
    [repmat("ETS_AA7", H, 1); repmat("ETS_AN", H, 1)], ...
    [t_a; t_a], ...
    [actual; actual], ...
    [fAA; fAN], ...
    'VariableNames', {'model', 'date', 'actual', 'predicted'});
writetable(Tout, 'results/tables/A_weeks_test/A_case_ets_daily.csv');

fprintf('\n已保存：\n');
fprintf('  results/figures/A_weeks_test/A_case_periodogram.png\n');
fprintf('  results/figures/A_weeks_test/A_case_weekday.png\n');
fprintf('  results/figures/A_weeks_test/A_case_daily_series.png\n');
fprintf('  results/figures/A_weeks_test/A_case_ets_forecast.png\n');
fprintf('  results/tables/A_weeks_test/A_case_ets_daily.csv\n');
