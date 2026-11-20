%% 第4步：四个UC模型的一步预测残差诊断（仅训练期）
% 第三步已经数值核验：e是元尺度的一步创新，不是标准化创新。
% 前2个周期为初始化期，工具箱e已删去；modelDetails保留完整周期起始日位置。
projectDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(projectDir, 'output');
modelFile = fullfile(outputDir, 'step03_UC_models.mat');
assert(isfile(modelFile), '请先运行第三步。');
results = load(modelFile);
assert(isequal(results.tTrain(:), datetime(2024,9,1)+caldays(7*(0:107)')), ...
    '模型文件训练日期不符合要求。');
currentTraining = load(fullfile(outputDir,'step01_training_data.mat'));
assert(isequaln(results.training, currentTraining), '训练数据已更新，请重新运行第三步。');
alpha = 0.05;
LB_Lags = [3 6]; % 预先固定，避免为了显著性反复更改；本步不追加第8阶。
diagnosticSummary = table;
anomalySummary = table(strings(0,1),NaT(0,1),zeros(0,1),zeros(0,1),false(0,1), ...
    'VariableNames',{'Model','PeriodStart','ErrorYuan','EmpiricalZ','BeyondBonferroniReference'});
distributionSummary = table;
for i = 1:4
    name = results.modelNames{i};
    detail = results.modelDetails{i};
    dates = results.tTrain(detail.valid);
    e = detail.error(detail.valid);
    assert(all(isfinite(e)) && all(dates(2:end)==dates(1:end-1)+caldays(7)), ...
        '残差有效期应连续，不能删除内部缺失后拼接计算ACF。');
    assert(numel(e)>max(LB_Lags)+1, '有效残差过少。');
    % UC方差参数数量不等于ARMA自由度修正。本步使用df=滞后阶数的
    % 常规渐近端口检验，108期训练样本且参数已估计，p值仅为近似诊断。
    [h,p,Q] = lbqtest(e, 'Lags',LB_Lags,'DoF',LB_Lags,'Alpha',alpha);
    for j = 1:numel(LB_Lags)
        conclusion = "未检出指定滞后范围内显著自相关";
        if h(j), conclusion = "检出指定滞后范围内显著自相关"; end
        diagnosticSummary = [diagnosticSummary; table(string(name),numel(e), ...
            LB_Lags(j),Q(j),p(j),logical(h(j)),conclusion, ...
            'VariableNames',{'Model','N','Lag','Q','PValue','RejectH0','Conclusion'})]; %#ok<AGROW>
    end
    % 分布图用经验中心和标准差缩放，不冒充工具箱标准化创新。
    center = mean(e); scale = std(e);
    assert(isfinite(scale) && scale>0, '残差经验尺度无效。');
    z = (e-center)/scale;
    pointCut = norminv(1-alpha/2);
    familyCut = norminv(1-alpha/(2*numel(e)));
    % 仅作探索性正态参照筛查：均值/方差同样本估计，非正式异常值判定。
    % 同时报出逐期与Bonferroni参照阈值；不删除观测、不重估模型。
    flag = abs(z)>pointCut;
    if any(flag)
        anomalySummary = [anomalySummary; table(repmat(string(name),sum(flag),1), ...
            dates(flag),e(flag),z(flag),abs(z(flag))>familyCut, ...
            'VariableNames',{'Model','PeriodStart','ErrorYuan','EmpiricalZ','BeyondBonferroniReference'})]; %#ok<AGROW>
    end
    distributionSummary = [distributionSummary; table(string(name),center,scale, ...
        skewness(e),kurtosis(e),pointCut,familyCut, ...
        'VariableNames',{'Model','MeanYuan','SDYuan','Skewness','Kurtosis', ...
        'PointwiseReference','BonferroniReference'})]; %#ok<AGROW>

    f = figure('Color','w','Position',[80 80 1200 780]);
    subplot(2,2,1);
    plot(dates,e,'-o','LineWidth',1.2); hold on;
    plot(dates(flag),e(flag),'rs','MarkerSize',9,'LineWidth',1.5);
    yline(0,':','HandleVisibility','off');
    yline(center+pointCut*scale,'--','HandleVisibility','off');
    yline(center-pointCut*scale,'--','HandleVisibility','off');
    hold off; grid on; title('一步预测残差与逐期正态参照筛查');
    xlabel('周期起始日'); ylabel('预测误差（元）'); xtickformat('yyyy-MM-dd'); xtickangle(45);
    legend('一步预测残差','超出参照线的周期起始日','Location','best');
    subplot(2,2,2);
    autocorr(e,'NumLags',8,'NumSTD',norminv(1-alpha/2));
    title('残差自相关函数'); xlabel('滞后（期，每期7天）'); ylabel('自相关系数');
    subplot(2,2,3);
    histogram(z,'Normalization','pdf'); hold on;
    xx = linspace(min(-4,min(z)-0.5),max(4,max(z)+0.5),200);
    plot(xx,normpdf(xx),'r-','LineWidth',1.2); hold off;
    title('经验标准化残差分布'); xlabel('（残差−均值）/经验标准差'); ylabel('概率密度');
    legend('经验分布','标准正态参照','Location','best'); grid on;
    subplot(2,2,4);
    qqplot(z); title('经验标准化残差的正态Q-Q图');
    xlabel('标准正态理论分位数'); ylabel('经验残差分位数'); grid on;
    sgtitle([name '一步预测残差诊断']);
    exportFigureByTitle(f,outputDir);
end
disp('========== Ljung–Box诊断汇总（显著性水平0.05） ==========');
disp(diagnosticSummary);
disp('========== 残差分布描述 =========='); disp(distributionSummary);
disp('========== 异常残差候选周期起始日（仅探索筛查） ==========');
if isempty(anomalySummary), disp('未发现超出逐期参照线的残差。'); else, disp(anomalySummary); end
fprintf(['未拒绝白噪声原假设仅表示未检出指定滞后范围内的显著自相关，不能证明模型完全正确。\n' ...
    '有效残差为106个，检验采用渐近近似；两种固定滞后作为探索性诊断，不据此自动选择模型。\n' ...
    '异常候选不是AO/IO/LS/TC分类结果；不得因此删除非经常大额支出。\n' ...
    '下一步须结合仅训练期的滚动预测比较，并核验CML下预测标准差的尺度后再计算最终区间。\n']);
save(fullfile(outputDir,'step04_UC_diagnostics.mat'), ...
    'diagnosticSummary','distributionSummary','anomalySummary','alpha','LB_Lags');
writetable(diagnosticSummary,fullfile(outputDir,'UC模型残差诊断汇总.csv'),'Encoding','UTF-8');
writetable(distributionSummary,fullfile(outputDir,'UC模型残差分布统计.csv'),'Encoding','UTF-8');
writetable(anomalySummary,fullfile(outputDir,'UC模型异常残差候选.csv'),'Encoding','UTF-8');
