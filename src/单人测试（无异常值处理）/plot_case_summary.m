%% ============================================================
%  汇总作图：三人 × 四模型的滚动 MASE 与十月相对误差
%  读取 results/tables/{A,B,C}_weeks_test/*.csv
%  输出 results/figures/case_summary/
%% ============================================================
clear; close all; clc

root = 'G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction';
cd(root);
base = 'results/tables';
people = {'A','B','C'};
models = {'ETS-NN','ETS-AN','Naive','MA3'};

MASE = nan(4,3); MAE = nan(4,3); RMSE = nan(4,3);
REL  = nan(4,3); CUM = nan(4,3);

for p = 1:3
    T = readtable(fullfile(base,[people{p} '_weeks_test'], ...
        [people{p} '_rolling_metrics.csv']), 'VariableNamingRule','preserve');
    MASE(:,p) = T.MASE;
    MAE(:,p)  = T.MAE;
    RMSE(:,p) = T.RMSE;

    O = readtable(fullfile(base,[people{p} '_weeks_test'], ...
        [people{p} '_oct_cum.csv']), 'VariableNamingRule','preserve');
    REL(:,p) = O.abs_rel_error_pct;
    CUM(:,p) = O.oct_cum;
end

%% 图1：30 折滚动 MASE
f1 = figure('Color','w','Position',[100 100 900 420]);
bar(MASE);
hold on;
yline(1, 'k--', 'LineWidth', 1.3);
set(gca, 'XTickLabel', models);
ylabel('MASE (30-fold rolling)');
title('Rolling one-step MASE by model and person');
legend(people, 'Location','northwest');
grid on; box off; hold off;

for i = 1:4
    for p = 1:3
        text(i + (p-2)*0.22, MASE(i,p)+0.03, sprintf('%.3f',MASE(i,p)), ...
            'HorizontalAlignment','center','FontSize',8);
    end
end
exportgraphics(f1, 'results/figures/case_summary/case_mase_by_model.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

%% 图2：十月累计相对误差
f2 = figure('Color','w','Position',[100 100 900 420]);
bar(REL);
set(gca, 'XTickLabel', models);
ylabel('Absolute relative error (%)');
title('October cumulative forecast: relative error');
legend(people, 'Location','northwest');
grid on; box off;

for i = 1:4
    for p = 1:3
        text(i + (p-2)*0.22, REL(i,p)+2, sprintf('%.1f%%',REL(i,p)), ...
            'HorizontalAlignment','center','FontSize',8);
    end
end
exportgraphics(f2, 'results/figures/case_summary/case_oct_error.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

%% 图3：30 折滚动 MAE
f3 = figure('Color','w','Position',[100 100 900 420]);
bar(MAE);
set(gca, 'XTickLabel', models);
ylabel('MAE (CNY per week)');
title('Rolling one-step MAE by model and person');
legend(people, 'Location','northwest');
grid on; box off;
exportgraphics(f3, 'results/figures/case_summary/case_mae_by_model.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

fprintf('已生成：\n');
fprintf('  results/figures/case_summary/case_mase_by_model.png\n');
fprintf('  results/figures/case_summary/case_oct_error.png\n');
fprintf('  results/figures/case_summary/case_mae_by_model.png\n');
