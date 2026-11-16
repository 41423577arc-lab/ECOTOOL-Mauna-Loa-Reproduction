%% A5-0 数据与模型（沿用 A3/A4 口径）
clear; close all; clc
addpath('src');

S = load(fullfile('data','dataPLOSpaper.mat'));
x_all = S.CO2;
n = numel(x_all);
t_all = datetime(1958,3,1) + calmonths((0:n-1)');

y      = x_all(25:504);
actual = x_all(505:528);
t_y    = t_all(25:504);
t_act  = t_all(505:528);

[ty, lambda] = vboxcox(y);

mN = modelNAIVE(ty, 24, 12);
fN = vboxcoxinv(mN.py(:,3), lambda);  fN = fN(:);

mE = modelETS(ty, [], 'AA12', 24);
fE = vboxcoxinv(mE.py, lambda);       fE = fE(:);


%% A5-1 指标函数（论文 Eq.8 / Eq.9）
smape = @(a,f) mean(200 * abs(a - f) ./ (abs(a) + abs(f)));
mase  = @(a,f,tr,s) mean(abs(a - f)) / mean(abs(tr(s+1:end) - tr(1:end-s)));


%% A5-2 计算指标
smapN = smape(actual, fN);
smapE = smape(actual, fE);
masN  = mase(actual, fN, y, 12);
masE  = mase(actual, fE, y, 12);

fprintf('\n%-16s %10s %10s\n', 'Model', 'sMAPE(%)', 'MASE');
fprintf('%-16s %10.3f %10.3f\n', 'SeasonalNaive', smapN, masN);
fprintf('%-16s %10.3f %10.3f\n', 'ETS(AA12)',     smapE, masE);


%% A5-3 误差随预测步长
f6 = figure('Color','w','Position',[100 100 800 400]);
plot(1:24, abs(actual-fN), 'b-o', 'LineWidth',1.2); hold on;
plot(1:24, abs(actual-fE), 'r-s', 'LineWidth',1.2);
xlabel('Forecast horizon (months)');
ylabel('Absolute error (ppm)');
legend({'Seasonal naive','ETS (AA12)'}, 'Location','northwest');
title('Absolute forecast error by horizon');
grid on; box off; hold off;

exportgraphics(f6, 'results/figures/A_error_by_horizon.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');


%% A5-4 保存预测结果（六字段）
origin  = string(t_y(end));
hv      = (1:24)';

T = table( ...
    [repmat("ETS",24,1); repmat("SeasonalNaive",24,1)], ...
    [repmat(origin,24,1); repmat(origin,24,1)], ...
    [t_act; t_act], ...
    [hv; hv], ...
    [actual; actual], ...
    [fE; fN], ...
    'VariableNames', {'model','forecast_origin','target_month','horizon','actual','predicted'});

writetable(T, 'results/tables/A_forecast_ETS_Naive.csv');

%% A5-5 保存指标表
M = table(["SeasonalNaive";"ETS"], [smapN;smapE], [masN;masE], ...
    'VariableNames', {'model','sMAPE','MASE'});
writetable(M, 'results/tables/A_model_metrics.csv');

