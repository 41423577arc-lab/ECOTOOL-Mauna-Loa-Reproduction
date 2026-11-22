%% A2-0 载入数据
clear; close all; clc

S = load(fullfile('data','dataPLOSpaper.mat'));
x_all = S.CO2;
n = numel(x_all);
t_all = datetime(1958,3,1) + calmonths((0:n-1)');


%% A2-1 Fig.1 原始序列
f1 = figure('Color','w','Position',[100 100 1000 420]);
plot(t_all, x_all, 'LineWidth', 0.9);
xlabel('Year');
ylabel('CO_2 concentration (ppm)');
title('Mauna Loa monthly CO_2 concentration, 1958-03 to 2018-05');
grid on; box off;
exportgraphics(f1, 'results/figures/A_fig1_co2_series.png', 'Resolution', 200);


%% A2-2 年均值与线性趋势
yr  = year(t_all);
ann = accumarray(yr - min(yr) + 1, x_all, [], @mean);
yrs = (min(yr):max(yr))';

f2 = figure('Color','w','Position',[100 100 800 400]);
plot(yrs, ann, 'o-', 'LineWidth', 1.4);
xlabel('Year'); ylabel('Annual mean CO_2 (ppm)');
title('Annual mean CO_2 concentration');
grid on; box off;
exportgraphics(f2, 'results/figures/A_annual_mean.png', 'Resolution', 200);

% 全期趋势
tt = (0:n-1)'/12;
p  = polyfit(tt, x_all, 1);
fprintf('全期线性趋势: %.3f ppm/年\n', p(1));

% 最近一段趋势（第505行起，2000-03）
p2 = polyfit(tt(505:end), x_all(505:end), 1);
fprintf('2000-03 起趋势: %.3f ppm/年\n', p2(1));


%% A2-3 月度季节均值
mth  = month(t_all);
seas = accumarray(mth, x_all, [], @mean);

f3 = figure('Color','w','Position',[100 100 700 350]);
bar(1:12, seas);
set(gca,'XTick',1:12);
xlabel('Month'); ylabel('Mean CO_2 (ppm)');
title('Average CO_2 by month of year');
grid on; box off;
exportgraphics(f3, 'results/figures/A_seasonal_monthly.png', 'Resolution', 200);

[~,imax] = max(seas);
[~,imin] = min(seas);
fprintf('峰值: %d月 %.2f ppm\n', imax, seas(imax));
fprintf('谷值: %d月 %.2f ppm\n', imin, seas(imin));
fprintf('季节振幅: %.2f ppm\n', max(seas)-min(seas));


%% A2-4 逐年季节曲线叠加
f4 = figure('Color','w','Position',[100 100 800 450]);
hold on;
for y = min(yr):max(yr)
    idx = (yr == y);
    plot(mth(idx), x_all(idx), '-', 'LineWidth', 0.8);
end
xlabel('Month'); ylabel('CO_2 (ppm)');
title('Seasonal profile by year');
grid on; box off; hold off;
exportgraphics(f4, 'results/figures/A_seasonal_overlay.png', 'Resolution', 200);
