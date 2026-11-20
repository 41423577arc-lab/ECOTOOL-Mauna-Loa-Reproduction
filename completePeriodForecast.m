function completePeriodForecast(projectDir,phase)
% 周度完整流程：仅使用训练数据选模；固定原点预测全部保留完整周期。
out=fullfile(projectDir,'output'); tr=load(fullfile(out,'step01_training_data.mat'));
addpath('C:\Users\86139\AppData\Roaming\MathWorks\MATLAB Add-Ons\Toolboxes\ECOTOOL');
label=string(tr.periodLabel); n=numel(tr.yTrain); assert(n==108&&all(tr.tTrain+caldays(6)<tr.cutoff));
models=["RW","LLT","朴素","三期移动平均"]; targetNames=["总支付","常规支付"];
if phase=="rolling"
 initial=78; N=n-initial; summary=table; detail=table; stability=table;
 baseline=load(fullfile(out,'step03_UC_models.mat')); diagnostics=load(fullfile(out,'step04_UC_diagnostics.mat'));
 assert(isequaln(baseline.training,tr));
 for a=1:2
  if a==1,y=tr.yTrain(:);else,y=tr.regularTrain(:);end
  for k=initial+1:n
   history=y(1:k-1); scale=mean(abs(diff(history))); assert(scale>0);
   for b=1:4
    reason="";se=NaN;flag=false;pred=NaN;
    try
     if b<=2
      m=modelUC(history,[],char(models(b)),1);pred=m.py;
      assert(isscalar(pred)&&isfinite(pred)&&all(isfinite(m.par)));
      se=max(sqrt(abs(diag(m.covpar))));flag=se>10||any(abs(m.par)>12);
     elseif b==3,pred=history(end);else,pred=mean(history(end-2:end));end
    catch err,reason=string(err.message);end
    detail=[detail;table(targetNames(a),models(b),tr.tTrain(k),y(k),pred,pred-y(k),scale,'VariableNames',{'Target','Model','PeriodStart','Actual','Forecast','Error','MASEScale'})];
    stability=[stability;table(targetNames(a),models(b),tr.tTrain(k),se,flag,reason,'VariableNames',{'Target','Model','PeriodStart','MaxScoreSE','UnstableFlag','Failure'})];
   end
  end
  for b=1:4
   z=detail(detail.Target==targetNames(a)&detail.Model==models(b),:);
   assert(height(z)==N);if any(~isfinite(z.Forecast)),continue;end
   denominator=abs(z.Forecast)+abs(z.Actual);sm=200*abs(z.Error)./denominator;sm(denominator==0)=0;
   summary=[summary;table(targetNames(a),models(b),N,mean(abs(z.Error)),sqrt(mean(z.Error.^2)),mean(sm),mean(abs(z.Error)./z.MASEScale),'VariableNames',{'Target','Model','N','MAE','RMSE','sMAPE','MASE'})];
  end
 end
 writetable(stability,fullfile(out,'UC滚动估计稳定性.csv'),'Encoding','UTF-8');
 assert(height(summary)==8,'部分模型失败：禁止在不同目标期静默排名');
 selected=strings(2,1);
 for a=1:2
  candidates=summary(summary.Target==targetNames(a)&ismember(summary.Model,["RW","LLT"]),:);
  % 综合检查短期自相关：只有一个UC通过两阶诊断时优先选它，否则按MAE、RMSE。
  passes=false(2,1);
  for b=1:2
   rows=contains(string(diagnostics.diagnosticSummary.Model),char(models(b)));
   if a==1,rows=rows&contains(string(diagnostics.diagnosticSummary.Model),'总支付');else,rows=rows&contains(string(diagnostics.diagnosticSummary.Model),'常规支付');end
   passes(b)=any(rows)&&all(~diagnostics.diagnosticSummary.RejectH0(rows));
  end
  if sum(passes)==1,selected(a)=models(find(passes,1));else,candidates=sortrows(candidates,{'MAE','RMSE'});selected(a)=candidates.Model(1);end
  f=figure('Visible','off','Color','w');z=detail(detail.Target==targetNames(a)&detail.Model==models(1),:);plot(z.PeriodStart,z.Actual,'k-o');hold on;
  for b=1:4,z=detail(detail.Target==targetNames(a)&detail.Model==models(b),:);plot(z.PeriodStart,z.Forecast,'-');end
  title(label+targetNames(a)+'扩展窗口滚动预测');xlabel('周期起始日');ylabel('每期金额（元）');legend(["真实值",models],'Location','best');grid on;saveplot(f,out);close(f);
 end
 writetable(summary,fullfile(out,'UC最终模型比较.csv'),'Encoding','UTF-8');writetable(detail,fullfile(out,'UC滚动预测明细.csv'),'Encoding','UTF-8');
 % 已有全训练期异常标记只作事后敏感性解释，不改变正式训练观测和排名。
 sensitivity=table;
 for a=1:2
  for b=1:4
   z=detail(detail.Target==targetNames(a)&detail.Model==models(b),:); idx=tr.tTrain>=datetime(2026,1,1)&tr.tTrain<=datetime(2026,1,31); start=tr.tTrain(idx); abnormal=ismember(z.PeriodStart,start);keep=~abnormal;
   sensitivity=[sensitivity;table(targetNames(a),models(b),sum(z.Error(abnormal).^2)/sum(z.Error.^2),mean(abs(z.Error(keep))),sqrt(mean(z.Error(keep).^2)),'VariableNames',{'Target','Model','JanuarySSEShare','MAE_WithoutJanuary','RMSE_WithoutJanuary'})];
  end
 end
 writetable(sensitivity,fullfile(out,'UC异常月份敏感性.csv'),'Encoding','UTF-8');
 save(fullfile(out,'step05_rolling.mat'),'tr','summary','detail','selected','stability','sensitivity','initial');disp(summary);disp(selected);
else
 r=load(fullfile(out,'step05_rolling.mat'));assert(isequaln(r.tr,tr));
 lock=fullfile(out,'step06_forecast_locked.mat');
 if isfile(lock),locked=load(lock);assert(isequaln(locked.tr,tr)&&isequal(locked.selected,r.selected));forecasts=locked.forecasts;
 else
  H=numel(tr.tTest);forecasts=nan(H,2);finalModels=cell(2,1);parameters=table;
  for a=1:2
   if a==1,y=tr.yTrain;else,y=tr.regularTrain;end
   m=modelUC(y,[],char(r.selected(a)),H);assert(numel(m.py)==H&&all(isfinite(m.py)));forecasts(:,a)=m.py(:);finalModels{a}=m;
   parameters=[parameters;table(repmat(targetNames(a),numel(m.par),1),(1:numel(m.par))',m.par(:),10.^m.par(:),sqrt(abs(diag(m.covpar))),'VariableNames',{'Target','Index','Log10Variance','Variance','ScoreSE'})];
  end
  selected=r.selected;lockedAt=datetime('now','TimeZone','Asia/Shanghai');
  intervalStatus="未发布：原生预测方差尺度解释不足，多步误差尾部亦未校准";
  save(lock,'tr','selected','forecasts','finalModels','parameters','lockedAt','intervalStatus');
  writetable(parameters,fullfile(out,'UC最终模型参数.csv'),'Encoding','UTF-8');
 end
 % 预测矩阵已锁定到磁盘，才读取保留周期金额；不滚动吸收测试观测。
 H=numel(tr.tTest);test=readtable(tr.filePath,'Sheet','02_UC直接建模','Range',sprintf('A%d:C%d',n+2,n+H+1),'ReadVariableNames',false,'TextType','string');
 dates=datetime(string(test{:,1}),'InputFormat','yyyy-MM-dd');assert(isequal(dates,tr.tTest));actual=double(test{:,2:3});
 evaluation=table;aggregate=table;
 for a=1:2
  e=forecasts(:,a)-actual(:,a);evaluation=[evaluation;table(repmat(targetNames(a),H,1),repmat(r.selected(a),H,1),(1:H)',dates,dates+caldays(6),forecasts(:,a),actual(:,a),e,abs(e),abs(e)./abs(actual(:,a)),'VariableNames',{'Target','Model','Horizon','PeriodStart','PeriodEnd','Forecast','Actual','Error','AbsoluteError','RelativeError'})];
  aggregate=[aggregate;table(targetNames(a),r.selected(a),H,mean(abs(e)),sqrt(mean(e.^2)),sum(forecasts(:,a)),sum(actual(:,a)),'VariableNames',{'Target','Model','N','MAE','RMSE','ForecastSum','ActualSum'})];
  f=figure('Visible','off','Color','w');plot(tr.tTrain(end-14:end),tr.yTrain(end-14:end),'-o');if a==2,clf;plot(tr.tTrain(end-14:end),tr.regularTrain(end-14:end),'-o');end
  hold on;plot(dates,forecasts(:,a),'rs-');plot(dates,actual(:,a),'kx-');title(label+targetNames(a)+'固定原点独立测试');xlabel('周期起始日');ylabel('每期金额（元）');legend('训练观测','锁定多步预测','独立测试真实值','Location','best');grid on;saveplot(f,out);close(f);
 end
 writetable(evaluation,fullfile(out,'UC最终预测结果.csv'),'Encoding','UTF-8');writetable(aggregate,fullfile(out,'UC独立测试汇总.csv'),'Encoding','UTF-8');save(fullfile(out,'step06_evaluation.mat'),'evaluation','aggregate');disp(aggregate);
end
end
function saveplot(f,out)
ax=findall(f,'Type','axes');name=char(string(ax(1).Title.String));
if ~(isfile(fullfile(out,[name '.png']))&&isfile(fullfile(out,[name '.fig']))),exportFigureByTitle(f,out);end
end


