%% 十月累计金额：实际 vs ETS-NN / ETS-AN / 均值基线（ARIMA 0,0,0）
clear; close all; clc

root = 'G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction';
cd(root);
base = 'G:\大学\课程\时间序列分析\银行流水提取';
baseMean = 'G:\大学\课程\时间序列分析\成员B 退化基线arima';
people = {'A','B','C'};
% 对齐文件的 B/C 标签与真实成员相反：B 的数据在 C_对齐，C 的数据在 B_对齐
folders = {'A_对齐','C_对齐','B_对齐'};

actual = nan(3,1); predNN = nan(3,1); predAN = nan(3,1); predBM = nan(3,1);

% 均值基线：ARIMA(0,0,0) 固定均值，五步预测恒等于训练均值
Tb = readtable(fullfile(baseMean,'ABC_显著性检验与均值预测汇总.csv'), ...
    'VariableNamingRule','preserve');

w = 31/7;   % 十月累计权重 4/7+1+1+1+6/7

for p = 1:3
    Tm = readtable(fullfile(base,folders{p}, ...
        [folders{p}(1) '_个人总支付_月度.csv']), 'VariableNamingRule','preserve');
    v = Tm.("个人总支付_元");
    actual(p) = v(end);

    O = readtable(fullfile('results/tables',[people{p} '_weeks_test'], ...
        [people{p} '_oct_cum.csv']), 'VariableNamingRule','preserve');
    predNN(p) = O.oct_cum(1);   % ETS-NN
    predAN(p) = O.oct_cum(2);   % ETS-AN

    mu = Tb.WeeklyMeanForecast(strcmp(Tb.Member, people{p}));
    predBM(p) = mu * w;         % 常数预测 × 同一套十月权重
end

Y = [actual, predNN, predAN, predBM];

% 保存数值，便于写稿核对
Tout = table(people', actual, predNN, predAN, predBM, ...
    'VariableNames', {'member','actual','ETS_NN','ETS_AN','mean_baseline'});
writetable(Tout, 'results/tables/case_oct_cum_with_baseline.csv');

f = figure('Color','w','Position',[100 100 1000 560]);
b = bar(Y);
set(gca, 'Position', [0.08 0.19 0.88 0.71]);
set(gca, 'XTickLabel', people, 'FontName','Microsoft YaHei', 'FontSize', 11);
xlabel('成员', 'FontName','Microsoft YaHei');
ylabel('10月累计消费金额（元）', 'FontName','Microsoft YaHei');
title('10月累计消费：实际值 vs ETS预测与均值基线', 'FontName','Microsoft YaHei');
legend({'实际值','ETS-NN','ETS-AN','均值基线'}, 'Location','northwest', ...
    'FontName','Microsoft YaHei');
grid on; box off;

% 数值标签
for k = 1:size(Y,2)
    for p = 1:3
        text(b(k).XEndPoints(p), b(k).YEndPoints(p)+120, ...
            sprintf('%.0f', Y(p,k)), ...
            'HorizontalAlignment','center','FontSize',8, ...
            'FontName','Microsoft YaHei');
    end
end

annotation('textbox', [0.08 0.015 0.88 0.06], ...
    'String', '注：均值基线为 ARIMA(0,0,0) 固定均值 × 31/7，与 ETS 使用同一套十月权重；A 的 ETS-AN 仅 119 元，属趋势外推失效。', ...
    'EdgeColor','none', 'FontName','Microsoft YaHei', 'FontSize', 9, ...
    'Color',[0.4 0.4 0.4]);

exportgraphics(f, 'results/figures/case_summary/case_oct_amount.png', ...
    'Resolution', 200, 'BackgroundColor', 'white');

fprintf('已生成 case_oct_amount.png 与 case_oct_cum_with_baseline.csv\n');
