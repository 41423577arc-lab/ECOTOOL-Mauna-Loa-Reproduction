%% ============================================================
%  成员A 的 ETS：在成员C 的数据上，严格对齐 UC 组员协议 v2
%  主实验：自然周 × 个人总支付_元 × 无季节 × 无变换
%  训练：108 周；滚动：扩展窗口、一步、30 折（k=78..107）
%  最终：全部 108 周重新估计，一次预测 5 周
%  十月累计：4/7·f1 + f2 + f3 + f4 + 6/7·f5
%% ============================================================
clear; close all; clc

root = 'G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction';
cd(root);
base = 'G:\大学\课程\时间序列分析\银行流水提取\C_对齐';
smape = @(a,f) 200*abs(a-f)./(abs(a)+abs(f));

%% ---------- 读取自然周数据 ----------
Tw = readtable(fullfile(base,'C_个人总支付_自然周.csv'), ...
    'VariableNamingRule','preserve');
y     = Tw.("个人总支付_元");
dates = datetime(Tw.("周期起始日"));
n     = numel(y);
fprintf('C 自然周：%d 周，%s ～ %s\n', n, datestr(dates(1)), datestr(dates(end)));

%% ---------- 一、30 折滚动一步验证 ----------
kList = 78:107;
nF = numel(kList);
R = nan(nF, 7);

for i = 1:nF
    k  = kList(i);
    tr = y(1:k);
    ac = y(k+1);
    sc = mean(abs(diff(tr)));

    fN = NaN; fA = NaN;
    try
        evalc('mN = modelETS(tr, [], ''NN'', 1, ''CML'');');
        fN = mN.py(1);
    catch
    end
    try
        evalc('mA = modelETS(tr, [], ''AN'', 1, ''CML'');');
        fA = mA.py(1);
    catch
    end

    fB = tr(end);
    fM = mean(tr(end-2:end));

    R(i,:) = [k, ac, fN, fA, fB, fM, sc];
end

fprintf('\n--- 30 折滚动结果（C 数据）---\n');
writeMetrics(R, smape, 'results/tables/C_weeks_test/C_rolling_metrics.csv');

%% ---------- 二、最终五步预测 ----------
tr = y(1:108);
fprintf('\n最终训练：%s ～ %s（108 周）\n', datestr(dates(1)), datestr(dates(108)));

mN = modelETS(tr, [], 'NN', 5, 'CML');
mA = modelETS(tr, [], 'AN', 5, 'CML');

fN5 = mN.py(:);
fA5 = mA.py(:);
fB5 = tr(end) * ones(5,1);
fM5 = mean(tr(end-2:end)) * ones(5,1);

w = [4/7; 1; 1; 1; 6/7];

cumN = sum(w .* fN5);
cumA = sum(w .* fA5);
cumB = sum(w .* fB5);
cumM = sum(w .* fM5);

Tm = readtable(fullfile(base,'C_个人总支付_月度.csv'), ...
    'VariableNamingRule','preserve');
vOct = Tm.("个人总支付_元");
actualOct = vOct(end);

fprintf('\n--- 最终五步预测与 10 月累计 ---\n');
fprintf('week    ETS-NN      ETS-AN      Naive       MA3\n');
for k = 1:5
    fprintf('%2d  %10.2f %10.2f %10.2f %10.2f\n', ...
        k, fN5(k), fA5(k), fB5(k), fM5(k));
end

fprintf('\n10 月累计预测（真实 %.2f）:\n', actualOct);
models = ["ETS-NN";"ETS-AN";"Naive";"MA3"];
cums   = [cumN; cumA; cumB; cumM];
for i = 1:4
    fprintf('  %-7s %10.2f  绝对误差 %8.2f  相对误差 %6.2f%%\n', ...
        models(i), cums(i), abs(cums(i)-actualOct), ...
        100*abs(cums(i)-actualOct)/actualOct);
end

%% ---------- 三、保存 ----------
T5 = table((1:5)', fN5, fA5, fB5, fM5, ...
    'VariableNames', {'week_ahead','ETS_NN','ETS_AN','Naive','MA3'});
writetable(T5, 'results/tables/C_weeks_test/C_final5_forecast.csv');

Tcum = table(models, cums, abs(cums-actualOct), ...
    100*abs(cums-actualOct)/actualOct, ...
    'VariableNames', {'model','oct_cum','abs_error','abs_rel_error_pct'});
writetable(Tcum, 'results/tables/C_weeks_test/C_oct_cum.csv');

%% ---------- 局部函数 ----------
function writeMetrics(R, smape, outFile)
    ac = R(:,2); sc = R(:,7);
    names = {'ETS-NN','ETS-AN','Naive','MA3'};
    F = {R(:,3), R(:,4), R(:,5), R(:,6)};
    M = nan(4,5);
    fprintf('%-8s %10s %10s %10s %10s\n','model','MAE','RMSE','sMAPE%','MASE');
    for i = 1:4
        f  = F{i};
        ok = isfinite(f);
        e  = abs(ac(ok) - f(ok));
        mae  = mean(e);
        rmse = sqrt(mean(e.^2));
        sm   = mean(reshape(smape(ac(ok), f(ok)), [], 1));
        ms   = mean(reshape(e ./ sc(ok), [], 1));
        M(i,:) = [sum(ok), mae, rmse, sm, ms];
        fprintf('%-8s %10.2f %10.2f %10.2f %10.3f\n', names{i}, mae, rmse, sm, ms);
    end
    T = table(names', M(:,1), M(:,2), M(:,3), M(:,4), M(:,5), ...
        'VariableNames', {'model','folds','MAE','RMSE','sMAPE','MASE'});
    writetable(T, outFile);
end
