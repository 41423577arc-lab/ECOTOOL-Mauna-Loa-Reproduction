%% 三人自然周：实际值 vs ETS 一步预测（第 79～108 周）
clear; close all; clc

root = 'G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction';
cd(root);
people = {'A','B','C'};

f = figure('Color','w','Position',[100 100 1100 850]);

for p = 1:3
    T = readtable(sprintf('results/tables/%s_weeks_test/%s_rolling_predictions.csv', ...
        people{p}, people{p}), 'VariableNamingRule','preserve');

    subplot(3,1,p);
    x = T.k + 1;                    % 目标周（79～108）
    plot(x, T.actual, 'k-o', 'LineWidth', 1.1, 'MarkerSize', 3); hold on;
    plot(x, T.ETS_NN, 'r--', 'LineWidth', 1.4);
    plot(x, T.ETS_AN, 'b-.', 'LineWidth', 1.1);
    title(sprintf('Member %s: actual vs ETS one-step forecasts', people{p}));
    ylabel('Spending (CNY)');
    grid on; box off; hold off;
    if p == 1
        legend({'Actual','ETS-NN','ETS-AN'}, 'Location','northwest');
    end
end

xlabel('Week index (79-108)');
exportgraphics(f, 'results/figures/case_summary/case_fit_rolling.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

fprintf('已生成 results/figures/case_summary/case_fit_rolling.png\n');
