%% A3-0 载入数据并划分样本（论文口径）
clear; close all; clc

S = load(fullfile('data','dataPLOSpaper.mat'));
x_all = S.CO2;
n = numel(x_all);
t_all = datetime(1958,3,1) + calmonths((0:n-1)');

y       = x_all(25:504);       % 训练：1960-03 ～ 2000-02，480 个月
actual  = x_all(505:528);      % 测试：2000-03 ～ 2002-02，24 个月
t_y     = t_all(25:504);
t_act   = t_all(505:528);

size(y), size(actual)


%% A3-1 Box-Cox 变换（论文 p.11）
[ty, lambda] = vboxcox(y);
disp(lambda)


%% A3-2 Seasonal Naive（论文 p.11）
mN = modelNAIVE(ty, 24, 12);
size(mN.py)


%% A3-3 逆变换（论文 p.12）
fN = vboxcoxinv(mN.py(:,3), lambda);
fN = fN(:);

fN(1:3)
actual(1:3)
min(fN), max(fN)


%% A3-4 预测图
f5 = figure('Color','w','Position',[100 100 1000 420]);
hold on;
plot(t_y, y, 'Color',[0.6 0.6 0.6], 'LineWidth', 0.8);
plot(t_act, actual, 'k-', 'LineWidth', 1.8);
plot(t_act, fN, 'b--', 'LineWidth', 1.6);
xlabel('Year'); ylabel('CO_2 (ppm)');
legend({'Training (480 months)','Actual','Seasonal naive'}, 'Location','northwest');
title('Seasonal naive forecast, 2000-03 to 2002-02');
grid on; box off;
exportgraphics(f5, 'results/figures/A_naive_forecast.png', 'Resolution', 200);




