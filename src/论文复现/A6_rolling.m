%% A6-1 滚动预测
clear; close all; clc

S = load(fullfile('data','dataPLOSpaper.mat'));
x_all = S.CO2;
n = numel(x_all);

L = 480;              % 训练长度
H = 24;               % 预测步长
s = 12;               % 季节周期
lambda = 0.2461;      % 固定，初始 480 个月的估计值

nRounds = 220;          % ← 先 5 轮验证，之后改成 220

SMA_N = nan(nRounds,H);  MAS_N = nan(nRounds,H);
SMA_E = nan(nRounds,H);  MAS_E = nan(nRounds,H);

tic;
for j = 1:nRounds
    i0 = j;                                  % 起点从第 1 行开始
    tr = x_all(i0 : i0+L-1);                 % 480 个月
    ac = x_all(i0+L : i0+L+H-1);             % 未来 24 个月

    ty = vboxcox(tr, lambda);                % 固定 lambda，不重复估

    pN = vboxcoxinv(modelNAIVE(ty,H,s).py(:,3), lambda);  pN = pN(:);
    evalc('mE = modelETS(ty, [], ''AA12'', H);');          % 屏蔽优化迭代输出
    pE = vboxcoxinv(mE.py, lambda);                         pE = pE(:);

    denom = mean(abs(tr(s+1:end) - tr(1:end-s)));           % 当轮 MASE 分母

    SMA_N(j,:) = (200*abs(ac-pN)./(abs(ac)+abs(pN)))';
    MAS_N(j,:) = (abs(ac-pN)/denom)';
    SMA_E(j,:) = (200*abs(ac-pE)./(abs(ac)+abs(pE)))';
    MAS_E(j,:) = (abs(ac-pE)/denom)';

    fprintf('round %d / %d  (%.1f s)\n', j, nRounds, toc);
    if mod(j,10) == 0
        save('results/tables/A_rolling_partial.mat','SMA_N','MAS_N','SMA_E','MAS_E','j');
    end

end


%%
mean(SMA_N,1)'      % 季节朴素各步长平均
mean(SMA_E,1)'      % ETS 各步长平均


%% A6-2 汇总（与论文 Table 4 一致：累计平均）
smaN = mean(SMA_N,1)';  masN = mean(MAS_N,1)';
smaE = mean(SMA_E,1)';  masE = mean(MAS_E,1)';

steps = [1 2 3 4 5 6 12 24]';
sE = arrayfun(@(k) mean(smaE(1:k)), steps);
mE = arrayfun(@(k) mean(masE(1:k)), steps);
sN = arrayfun(@(k) mean(smaN(1:k)), steps);
mN = arrayfun(@(k) mean(masN(1:k)), steps);

label = ["h1";"h2";"h3";"h4";"h5";"h6";"1 year";"2 years"];
Tsum = table(label, sE, mE, sN, mN, ...
    'VariableNames', {'step','ETS_sMAPE','ETS_MASE','Naive_sMAPE','Naive_MASE'});
disp(Tsum)
writetable(Tsum, 'results/tables/A_rolling_summary.csv');
