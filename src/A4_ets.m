%% A4-0 载入数据并划分样本
clear; close all; clc

S = load(fullfile('data','dataPLOSpaper.mat'));
x_all = S.CO2;
n = numel(x_all);
t_all = datetime(1958,3,1) + calmonths((0:n-1)');

y      = x_all(25:504);
actual = x_all(505:528);
t_y    = t_all(25:504);
t_act  = t_all(505:528);


%% A4-1 Box-Cox 变换
[ty, lambda] = vboxcox(y);
disp(lambda)


%% A4-2 ETS（AA12，论文 p.11）
mE = modelETS(ty, [], 'AA12', 24);
size(mE.py)
disp(mE.table)


%% A4-3 逆变换
fE = vboxcoxinv(mE.py, lambda);
fE = fE(:);

fE(1:3)
min(fE), max(fE)


%% A4-4 ETS vs 季节朴素
mN = modelNAIVE(ty, 24, 12);
fN = vboxcoxinv(mN.py(:,3), lambda);
fN = fN(:);

f4 = figure('Color','w','Position',[100 100 1000 420]);
hold on;
plot(t_y, y, 'Color',[0.7 0.7 0.7], 'LineWidth', 0.7);
plot(t_act, actual, 'k-',  'LineWidth', 1.9);
plot(t_act, fE,     'r--', 'LineWidth', 1.6);
plot(t_act, fN,     'b-.', 'LineWidth', 1.5);
xlabel('Year'); ylabel('CO_2 (ppm)');
legend({'Training','Actual','ETS (AA12)','Seasonal naive'}, 'Location','northwest');
title('24-month forecasts: ETS vs seasonal naive');
grid on; box off;
exportgraphics(f4, 'results/figures/A_ets_vs_naive.png', 'Resolution', 200);
