%% ============================================================
%  成员A 的 ETS：在成员A 的数据上，对齐 UC 组员协议 v2
%  自然周 × 个人总支付 × 无季节 × 无变换 × CML
%% ============================================================
clear; close all; clc

root = 'G:\大学\课程\时间序列分析\ECOTOOL-Mauna-Loa-Reproduction';
cd(root);
base = 'G:\大学\课程\时间序列分析\银行流水提取\A_对齐';
smape = @(a,f) 200*abs(a-f)./(abs(a)+abs(f));

Tw = readtable(fullfile(base,'A_个人总支付_自然周.csv'), ...
    'VariableNamingRule','preserve');
y     = Tw.("个人总支付_元");
dates = datetime(Tw.("周期起始日"));
fprintf('A 自然周：%d 周\n', numel(y));

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

Tpred = table(R(:,1), R(:,2), R(:,3), R(:,4), ...
    'VariableNames', {'k','actual','ETS_NN','ETS_AN'});
writetable(Tpred, 'results/tables/A_weeks_test/A_rolling_predictions.csv');
writeMetrics(R, smape, 'results/tables/A_weeks_test/A_rolling_metrics.csv');

%% 最终五步预测
tr = y(1:108);
mN = modelETS(tr, [], 'NN', 5, 'CML');
mA = modelETS(tr, [], 'AN', 5, 'CML');
fN5 = mN.py(:); fA5 = mA.py(:);
fB5 = tr(end)*ones(5,1);
fM5 = mean(tr(end-2:end))*ones(5,1);
w = [4/7;1;1;1;6/7];

Tm = readtable(fullfile(base,'A_个人总支付_月度.csv'), ...
    'VariableNamingRule','preserve');
vOct = Tm.("个人总支付_元");
actualOct = vOct(end);

T5 = table((1:5)', fN5, fA5, fB5, fM5, ...
    'VariableNames', {'week_ahead','ETS_NN','ETS_AN','Naive','MA3'});
writetable(T5, 'results/tables/A_weeks_test/A_final5_forecast.csv');

cums = [sum(w.*fN5); sum(w.*fA5); sum(w.*fB5); sum(w.*fM5)];
models = ["ETS-NN";"ETS-AN";"Naive";"MA3"];
Tcum = table(models, cums, abs(cums-actualOct), ...
    100*abs(cums-actualOct)/actualOct, ...
    'VariableNames', {'model','oct_cum','abs_error','abs_rel_error_pct'});
writetable(Tcum, 'results/tables/A_weeks_test/A_oct_cum.csv');

fprintf('A 完成：rolling_predictions / rolling_metrics / final5 / oct_cum\n');

function writeMetrics(R, smape, outFile)
    ac = R(:,2); sc = R(:,7);
    names = {'ETS-NN','ETS-AN','Naive','MA3'};
    F = {R(:,3), R(:,4), R(:,5), R(:,6)};
    M = nan(4,5);
    for i = 1:4
        f  = F{i};
        ok = isfinite(f);
        e  = abs(ac(ok) - f(ok));
        M(i,:) = [sum(ok), mean(e), sqrt(mean(e.^2)), ...
            mean(reshape(smape(ac(ok), f(ok)), [], 1)), ...
            mean(reshape(e ./ sc(ok), [], 1))];
    end
    T = table(names', M(:,1), M(:,2), M(:,3), M(:,4), M(:,5), ...
        'VariableNames', {'model','folds','MAE','RMSE','sMAPE','MASE'});
    writetable(T, outFile);
end
