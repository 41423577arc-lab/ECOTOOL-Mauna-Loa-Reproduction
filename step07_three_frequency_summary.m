%% 第七步：三种频率累计预测与十月真实总额比较
% 用户指定完整十月优先：跨月周按覆盖天数/7分摊，不使用真实逐日金额。
% 自然周需5个相交周期；已选RW的固定原点多步点预测恒定，可精确延长第5步。
% 这是用户在原始测试后指定的汇总口径，模型和参数未重新选择，不能宣称新增独立验证。
projectDir=fileparts(mfilename('fullpath'));out=fullfile(projectDir,'output');
m=load(fullfile(out,'step06_forecast_locked.mat'));
n=load(fullfile(projectDir,'自然周分析','output','step06_forecast_locked.mat'));
w=load(fullfile(projectDir,'连续七天分析','output','step06_forecast_locked.mat'));
assert(size(n.forecasts,1)==4&&size(w.forecasts,1)==5);
left=max(w.tr.tTest,datetime(2026,10,1));right=min(w.tr.tTest+caldays(6),datetime(2026,10,31));
weights=max(0,hours(right-left)/24+1)/7; % datetime相减为duration；用小时换算以规避ECOTOOL同名days函数。

assert(all(n.selected=="RW"),'第五周延长仅适用于已锁定的无漂移RW');
assert(max(abs(diff(n.forecasts(:,1))))<1e-8,'已锁定RW预测应为常数');
naturalDates=[n.tr.tTest;n.tr.tTest(end)+caldays(7)];
naturalPred=[n.forecasts(:,1);n.forecasts(end,1)];
naturalLeft=max(naturalDates,datetime(2026,10,1));naturalRight=min(naturalDates+caldays(6),datetime(2026,10,31));
naturalWeights=max(0,hours(naturalRight-naturalLeft)/24+1)/7;
assert(abs(sum(naturalWeights)*7-31)<1e-8&&abs(sum(weights)*7-31)<1e-8);
forecasts=[m.point;sum(naturalPred.*naturalWeights);sum(w.forecasts(:,1).*weights)];
lockedAt=datetime('now','TimeZone','Asia/Shanghai');
save(fullfile(out,'three_frequency_aggregation_locked.mat'),'forecasts','weights','naturalWeights','naturalPred','naturalDates','lockedAt');
t=readtable(fullfile(out,'UC最终预测结果.csv'),'TextType','string');actual=t.Actual(1);
Frequency=["月度";"自然周日分摊";"连续七天日分摊"];
Model=[string(m.selectedModel);n.selected(1);w.selected(1)];
Coverage=["2026-10-01至10-31";"2026-10-01至10-31（均匀分摊）";"2026-10-01至10-31（均匀分摊）"];
comparison=table(Frequency,Model,Coverage,forecasts,repmat(actual,3,1),forecasts-actual,abs(forecasts-actual),abs(forecasts-actual)/abs(actual),'VariableNames',{'Frequency','Model','Coverage','Forecast','OctoberActual','Error','AbsoluteError','RelativeError'});
writetable(comparison,fullfile(out,'三种频率十月累计预测比较.csv'),'Encoding','UTF-8');
f=figure('Visible','off','Color','w');bar([forecasts,repmat(actual,3,1)]);xticks(1:3);xticklabels(Frequency);title('三种频率累计预测与十月真实总支付');xlabel('预测方案（跨月周期按天数分摊）');ylabel('金额（元）');legend('累计预测','完整十月真实值');grid on;
exportFigureByTitle(f,out);
close(f);disp(comparison);

