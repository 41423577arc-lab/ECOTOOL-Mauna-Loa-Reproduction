%% 单面板 × 三人：实际值 vs ETS-NN / ETS-AN 一步预测（结构仿 UC 示例图）
clear; close all; clc

root = 'G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction';
cd(root);
base = 'G:\大学\课程\时间序列分析\银行流水提取';
people = {'A','B','C'};

% 三人的周起始日完全相同，统一用 A_对齐 的日期轴
W = readtable(fullfile(base,'A_对齐','A_个人总支付_自然周.csv'), ...
    'VariableNamingRule','preserve');
dates = datetime(W.("周期起始日"));

for p = 1:3
    nm = people{p};

    T = readtable(sprintf('results/tables/%s_weeks_test/%s_rolling_predictions.csv', nm, nm), ...
        'VariableNamingRule','preserve');

    x  = dates(T.k + 1);      % 目标周（第 79～108 周）
    yA = T.actual;            % 实际值
    yN = T.ETS_NN;            % ETS-NN 预测值
    yT = T.ETS_AN;            % ETS-AN 预测值

    f = figure('Color','w','Position',[100 100 1100 500]);
    plot(x, yA, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 5, 'MarkerFaceColor','w');
    hold on;
    plot(x, yN, 'r--s', 'LineWidth', 1.5, 'MarkerSize', 5, 'MarkerFaceColor','w');
    plot(x, yT, 'g-.^', 'LineWidth', 1.5, 'MarkerSize', 5, 'MarkerFaceColor','w');
    hold off;

    xlabel('周起始日', 'FontName','Microsoft YaHei');
    ylabel('消费金额（元）', 'FontName','Microsoft YaHei');
    title(sprintf('ETS模型消费预测与实际值对比（成员%s）', nm), 'FontName','Microsoft YaHei');
    legend({'实际值','ETS-NN预测值','ETS-AN预测值'}, ...
        'Location','northwest', 'FontName','Microsoft YaHei');
    set(gca, 'FontName','Microsoft YaHei', 'FontSize', 11);
    grid on; box off;

    exportgraphics(f, sprintf('results/figures/case_summary/case_ets_fit_%s.png', nm), ...
        'Resolution', 200, 'BackgroundColor', 'white');
    fprintf('已生成 case_ets_fit_%s.png\n', nm);
    close(f);
end
