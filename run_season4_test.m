function run_season4_test()
% 只将UC季节周期改为4；数据、窗口、CML调用及UC选择规则沿用原实验。
root=fileparts(mfilename('fullpath'));out=fullfile(root,'output','季节周期4测试');
addpath(fullfile(root,'output','流程代码'));configure_ecotool();
if ~isfolder(out),mkdir(out);end
logFile=fullfile(out,'运行日志.txt');fid=fopen(logFile,'w');fclose(fid);diary(logFile);done=onCleanup(@() diary('off'));
people=["A","B","C"];models=["RW4","LLT4"];baseModels=["RW","LLT"];
metrics=table;rolling=table;forecasts=table;diagnostics=table;estimation=table;
selectedSummary=table;comparison=table;failures=table;
set(groot,'DefaultFigureVisible','off');
fprintf('季节周期4实验；MATLAB %s；%s\n',version,string(datetime('now','TimeZone','Asia/Shanghai')));
for person=people
 p=fullfile(out,person);if ~isfolder(p),mkdir(p);end
 tr=load(fullfile(root,'output',person,'step01_training_data.mat'));
 n=numel(tr.yTrain);assert(n==108 && all(tr.tTrain+caldays(6)<tr.cutoff));
 y=tr.yTrain(:);initial=78;H=numel(tr.tTest);assert(H==4);
 fixed=nan(H,2);modelObjects=cell(2,1);passes=false(2,1);available=false(2,1);
 baselineRolling=readtable(fullfile(root,'output',person,'UC滚动预测明细.csv'),'TextType','string');
 personRolling=table;personDiag=table;personMetrics=table;
 for b=1:2
  fprintf('开始 %s %s：108周训练及30折滚动\n',person,models(b));
  failure="";m=[];
  try
   m=modelUC(y,[],char(models(b)),H);
   assert(numel(m.py)==H && all(isfinite(m.py)) && all(isfinite(m.par)));
   assert(any(contains(string(m.table),'CONDITIONAL SUM OF SQUARES')),'估计方法不再与原CML一致');
   assert(numel(m.par)==b+2,'季节模型方差参数数量与预期不符');
   fixed(:,b)=m.py(:);modelObjects{b}=m;
   fid=fopen(fullfile(p,models(b)+"_估计表.txt"),'w','n','UTF-8');fprintf(fid,'%s\n',strip(string(m.table),'right'));fclose(fid);
   e=m.e(:);assert(all(isfinite(e)) && numel(e)>8,'工具箱创新包含无效值或太短');
   lags=[3 6];[h,pval,Q]=lbqtest(e,'Lags',lags,'DoF',lags,'Alpha',0.05);
   passes(b)=all(~h);
   for j=1:2
    personDiag=[personDiag;table(person,models(b),numel(e),lags(j),Q(j),pval(j),logical(h(j)), ...
     'VariableNames',{'Person','Model','NResidual','Lag','Q','PValue','RejectH0'})]; %#ok<AGROW>
   end
   paramNames=["水平扰动";"季节扰动";"观测噪声"];
   if b==2,paramNames=["水平扰动";"斜率扰动";"季节扰动";"观测噪声"];end
   se=sqrt(abs(diag(m.covpar)));
   estimation=[estimation;table(repmat(person,numel(m.par),1),repmat(models(b),numel(m.par),1),paramNames,m.par(:),10.^m.par(:),se(:), ...
    'VariableNames',{'Person','Model','Parameter','Log10Variance','Variance','ScoreSE'})]; %#ok<AGROW>
  catch err
   failure=string(err.message);fprintf('全训练估计失败：%s\n',failure);
   failures=[failures;table(person,models(b),"全训练",NaT,failure,'VariableNames',{'Person','Model','Phase','PeriodStart','Message'})]; %#ok<AGROW>
  end
  pred=nan(n-initial,1);foldFailure=strings(n-initial,1);
  for k=initial+1:n
   history=y(1:k-1);scale=mean(abs(diff(history)));assert(scale>0);
   try
    fold=modelUC(history,[],char(models(b)),1);
    assert(isscalar(fold.py)&&isfinite(fold.py)&&all(isfinite(fold.par)));
    pred(k-initial)=fold.py;
   catch err
    foldFailure(k-initial)=string(err.message);
    failures=[failures;table(person,models(b),"滚动",tr.tTrain(k),string(err.message),'VariableNames',{'Person','Model','Phase','PeriodStart','Message'})]; %#ok<AGROW>
   end
   personRolling=[personRolling;table(person,models(b),tr.tTrain(k),y(k),pred(k-initial),pred(k-initial)-y(k),scale,foldFailure(k-initial), ...
    'VariableNames',{'Person','Model','PeriodStart','Actual','Forecast','Error','MASEScale','Failure'})]; %#ok<AGROW>
  end
  available(b)=all(isfinite(pred)) && all(isfinite(fixed(:,b))) && strlength(failure)==0;
  if all(isfinite(pred))
   scales=personRolling.MASEScale(personRolling.Model==models(b));
   personMetrics=[personMetrics;metricRow(person,"滚动30折",models(b),y(initial+1:end),pred,scales)]; %#ok<AGROW>
  end
  fprintf('完成 %s %s，滚动失败%d\n',person,models(b),sum(strlength(foldFailure)>0));
 end
 writetable(personRolling,fullfile(p,'滚动预测明细.csv'),'Encoding','UTF-8');
 writetable(personDiag,fullfile(p,'季节模型残差诊断.csv'),'Encoding','UTF-8');
 % 沿用原UC选择规则，选择只依据训练内诊断及滚动结果。
 selected="不可选择";
 if all(available)
  if sum(passes)==1,selected=models(find(passes,1));
  else,ranked=sortrows(personMetrics,{'MAE','RMSE'});selected=ranked.Model(1);end
 end
 lockedAt=datetime('now','TimeZone','Asia/Shanghai');
 save(fullfile(p,'季节模型预测锁定.mat'),'fixed','selected','modelObjects','tr','lockedAt','models','passes','available');
 % 季节两模型四步预测锁定后，才读取本轮测试金额。
 test=readtable(tr.filePath,'Sheet','UC数据','Range','A110:B113','ReadVariableNames',false);
 dates=test{:,1};if ~isdatetime(dates),dates=datetime(string(dates),'InputFormat','yyyy-MM-dd');end
 assert(isequal(dates,tr.tTest));actual=double(test{:,2});scale=mean(abs(diff(y)));
 baselineMetric=readtable(fullfile(root,'output','报告四模型性能汇总.csv'),'TextType','string');
 baselineForecast=readtable(fullfile(root,'output','报告四模型固定原点预测.csv'),'TextType','string');
 for b=1:2
  if all(isfinite(fixed(:,b)))
   personMetrics=[personMetrics;metricRow(person,"测试4期",models(b),actual,fixed(:,b),repmat(scale,H,1))]; %#ok<AGROW>
  end
  forecasts=[forecasts;table(repmat(person,H,1),repmat(models(b),H,1),dates,fixed(:,b),actual,fixed(:,b)-actual, ...
   'VariableNames',{'Person','Model','PeriodStart','Forecast','Actual','Error'})]; %#ok<AGROW>
  for stage=["滚动30折","测试4期"]
   old=baselineMetric(baselineMetric.Person==person&baselineMetric.Model==baseModels(b)&baselineMetric.Stage==stage,:);
   new=personMetrics(personMetrics.Model==models(b)&personMetrics.Stage==stage,:);
   if height(new)==1
    comparison=[comparison;table(person,stage,baseModels(b),models(b),old.MAE,new.MAE,100*(old.MAE-new.MAE)/old.MAE,old.RMSE,new.RMSE,100*(old.RMSE-new.RMSE)/old.RMSE, ...
     old.sMAPE,new.sMAPE,old.MASE,new.MASE, ...
     'VariableNames',{'Person','Stage','Baseline','Seasonal','BaselineMAE','SeasonalMAE','MAEImprovementPct','BaselineRMSE','SeasonalRMSE','RMSEImprovementPct','BaselineSMAPE','SeasonalSMAPE','BaselineMASE','SeasonalMASE'})]; %#ok<AGROW>
   end
  end
 end
 if selected~="不可选择"
  selectedSummary=[selectedSummary;table(person,selected,passes(1),passes(2),'VariableNames',{'Person','SelectedSeasonalUC','RW4Pass','LLT4Pass'})]; %#ok<AGROW>
 end
 writetable(personMetrics,fullfile(p,'季节模型误差指标.csv'),'Encoding','UTF-8');
 metrics=[metrics;personMetrics];rolling=[rolling;personRolling];diagnostics=[diagnostics;personDiag]; %#ok<AGROW>
 save(fullfile(p,'季节周期4实验.mat'),'personMetrics','personRolling','personDiag','selected','fixed','actual','models','modelObjects','passes','available');
 if all(available)
  colors=[.145 .388 .922;.486 .227 .929;.027 .588 .412;.918 .345 .047];
  for stage=1:2
   f=figure('Color','w','Position',[80 80 1100 360]);hold on;
   if stage==1
    x=tr.tTrain(initial+1:end);act=y(initial+1:end);plot(x,act,'k-o','LineWidth',1.15,'MarkerSize',3);
    for b=1:2,z=baselineRolling(baselineRolling.Model==baseModels(b),:);plot(x,z.Forecast,'--','Color',colors(b,:),'LineWidth',1.1);end
    for b=1:2,z=personRolling(personRolling.Model==models(b),:);plot(x,z.Forecast,'Color',colors(b+2,:),'LineWidth',1.2);end
    label="滚动30折";
   else
    x=dates;plot(x,actual,'k-o','LineWidth',1.2);
    for b=1:2,z=baselineForecast(baselineForecast.Person==person&baselineForecast.Model==baseModels(b),:);plot(x,z.Forecast,'--','Color',colors(b,:),'LineWidth',1.1);end
    for b=1:2,plot(x,fixed(:,b),'Color',colors(b+2,:),'LineWidth',1.2);end
    label="固定原点4周";
   end
   title(person+" 无季节与4周季节UC对比 "+label);legend(["实际",baseModels,models],'Location','northoutside','Orientation','horizontal');
   xlabel('目标周起始日');ylabel('每周总支付（元）');grid on;xtickformat('MM-dd');
   exportgraphics(f,fullfile(p,label+"预测对比.png"),'Resolution',220);close(f);
  end
 end
 writetable(metrics,fullfile(out,'季节周期4误差指标.csv'),'Encoding','UTF-8');
 writetable(comparison,fullfile(out,'与无季节模型配对比较.csv'),'Encoding','UTF-8');
end
writetable(rolling,fullfile(out,'季节周期4滚动明细.csv'),'Encoding','UTF-8');
writetable(forecasts,fullfile(out,'季节周期4测试预测.csv'),'Encoding','UTF-8');
writetable(diagnostics,fullfile(out,'季节周期4残差诊断.csv'),'Encoding','UTF-8');
writetable(estimation,fullfile(out,'季节模型方差参数.csv'),'Encoding','UTF-8');
writetable(selectedSummary,fullfile(out,'按原规则选定的季节模型.csv'),'Encoding','UTF-8');
if ~isempty(failures),writetable(failures,fullfile(out,'估计失败记录.csv'),'Encoding','UTF-8');end
save(fullfile(out,'季节周期4总结果.mat'),'metrics','rolling','forecasts','diagnostics','estimation','selectedSummary','comparison','failures');
disp(comparison);disp(selectedSummary);fprintf('SEASON4_TEST_COMPLETE\n');
end

function row=metricRow(person,stage,model,actual,pred,scales)
e=pred(:)-actual(:);den=abs(pred(:))+abs(actual(:));sm=200*abs(e)./den;sm(den==0)=0;
row=table(person,stage,model,numel(e),mean(abs(e)),sqrt(mean(e.^2)),mean(sm),mean(abs(e)./scales(:)), ...
 'VariableNames',{'Person','Stage','Model','N','MAE','RMSE','sMAPE','MASE'});
end
