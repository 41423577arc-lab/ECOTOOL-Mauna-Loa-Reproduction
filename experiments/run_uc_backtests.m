function run_uc_backtests(root,experiment)
% A、B、C统一使用原UC的CML调用、相同窗口和原始真实金额评分。
arguments
 root (1,1) string
 experiment (1,1) string {mustBeMember(experiment,["multi_origin_4step","outlier_sensitivity"])}
end
addpath(fullfile(root,'output','流程代码'));configure_ecotool();
out=fullfile(root,'experiments',experiment,'results');if ~isfolder(out),mkdir(out);end
set(groot,'DefaultFigureVisible','off');
people=["A","B","C"];origins=78:104;H=4;
models=["RW","LLT","朴素","三期移动平均"];groups="原始";
if experiment=="outlier_sensitivity",models=models(1:2);groups=["原始","训练缩尾"];end
predictions=table;parameters=table;thresholds=table;clipped=table;diagnostics=table;
fixed=table;selections=table;modelObjects=cell(3,numel(groups),numel(models),28);
for a=1:3
 person=people(a);file=fullfile(root,'data',person+"_个人总支付_自然周.xlsx");
 dates=readcell(file,'Sheet','UC数据','Range','A2:A113');
 if all(cellfun(@isnumeric,dates)),dates=datetime(cell2mat(dates),'ConvertFrom','excel');
 else,dates=vertcat(dates{:});end
 assert(isequal(dates(:),datetime(2024,9,2)+caldays(7*(0:111)')));
 train=readmatrix(file,'Sheet','UC数据','Range','B2:B109');train=train(:);
 assert(numel(train)==108&&all(isfinite(train))&&all(train>=0));
 for g=1:numel(groups)
  group=groups(g);
  for n=[origins 108]
   history=train(1:n);q=quantile(history,[.25 .75]);upper=q(2)+1.5*(q(2)-q(1));
   fitY=history;flag=false(n,1);
   if group=="训练缩尾",flag=history>upper;fitY(flag)=upper;end
   thresholds=[thresholds;table(person,group,n,q(1),q(2),upper,sum(history>upper),sum(flag),sum(history-fitY), ...
    'VariableNames',{'Person','Group','Origin','Q1','Q3','Upper','DetectedCount','ClippedCount','RemovedAmount'})]; %#ok<AGROW>
   for k=find(flag)'
    clipped=[clipped;table(person,group,n,k,dates(k),history(k),fitY(k),upper, ...
     'VariableNames',{'Person','Group','Origin','WeekIndex','PeriodStart','Original','Treated','Upper'})]; %#ok<AGROW>
   end
   for b=1:numel(models)
    model=models(b);pass=true;
    if b<=2
     m=modelUC(fitY,[],char(model),H);
     assert(numel(m.py)==4&&all(isfinite(m.py))&&all(isfinite(m.par)));
     assert(any(contains(string(m.table),'CONDITIONAL SUM OF SQUARES')),'CML口径变化');
     forecast=m.py(:);modelObjects{a,g,b,find([origins 108]==n)}=m;
     names=["水平扰动","观测噪声"];if b==2,names=["水平扰动","斜率扰动","观测噪声"];end
     assert(numel(m.par)==numel(names));
     for j=1:numel(names)
      parameters=[parameters;table(person,group,n,model,names(j),m.par(j),10.^m.par(j), ...
       'VariableNames',{'Person','Group','Origin','Model','Parameter','Log10Variance','Variance'})]; %#ok<AGROW>
     end
     if n==108
      [reject,pval,Q]=lbqtest(m.e(:),'Lags',[3 6],'DoF',[3 6],'Alpha',.05);pass=all(~reject);
      for j=1:2
       lag=[3 6];diagnostics=[diagnostics;table(person,group,model,lag(j),Q(j),pval(j),logical(reject(j)), ...
        'VariableNames',{'Person','Group','Model','Lag','Q','PValue','RejectH0'})]; %#ok<AGROW>
      end
     end
    elseif b==3,forecast=repmat(fitY(end),4,1);
    else
     forecast=zeros(4,1);recursive=fitY;
     for h=1:4,forecast(h)=mean(recursive(end-2:end));recursive=[recursive;forecast(h)];end %#ok<AGROW>
    end
    if n<108
     for h=1:4
      predictions=[predictions;table(person,group,model,n,dates(n),h,n+h,dates(n+h),forecast(h),train(n+h),forecast(h)-train(n+h), ...
       'VariableNames',{'Person','Group','Model','Origin','OriginStart','Horizon','TargetIndex','PeriodStart','Forecast','Actual','Error'})]; %#ok<AGROW>
     end
    else
     for h=1:4
      fixed=[fixed;table(person,group,model,h,dates(n+h),forecast(h),pass, ...
       'VariableNames',{'Person','Group','Model','Horizon','PeriodStart','Forecast','PassResidual'})]; %#ok<AGROW>
     end
    end
   end
  end
  fprintf('%s %s %s：27原点及108周预测完成\n',experiment,person,group);
 end
end
metrics=summarize(predictions);
for person=people
 for group=groups
  z=metrics(metrics.Person==person&metrics.Group==group&metrics.Horizon==0,:);
  uc=z(ismember(z.Model,["RW","LLT"]),:);rank=sortrows(uc,{'MAE','RMSE','Model'});pure=rank.Model(1);
  d=diagnostics(diagnostics.Person==person&diagnostics.Group==group,:);
  passes=[all(~d.RejectH0(d.Model=="RW")),all(~d.RejectH0(d.Model=="LLT"))];
  selected=pure;if sum(passes)==1,candidates=["RW","LLT"];selected=candidates(passes);end
  allRank=sortrows(z,{'MAE','RMSE','Model'});
  selections=[selections;table(person,group,pure,selected,allRank.Model(1),passes(1),passes(2), ...
   'VariableNames',{'Person','Group','LowestMAEUC','SelectedUC','LowestMAEAll','RWPass','LLTPass'})]; %#ok<AGROW>
 end
end
lockedAt=datetime('now','TimeZone','Asia/Shanghai');
save(fullfile(out,'训练内选模与测试预测锁定.mat'),'predictions','metrics','parameters','thresholds','clipped','diagnostics','fixed','selections','modelObjects','lockedAt','origins','H','experiment','-v7.3');
writetable(fixed,fullfile(out,'测试预测锁定.csv'),'Encoding','UTF-8');
writetable(selections,fullfile(out,'训练内选模结果.csv'),'Encoding','UTF-8');
% 全部成员的选模与预测均锁定之后，才在本次运行读取原保留测试金额。
for person=people
 actual=readmatrix(fullfile(root,'data',person+"_个人总支付_自然周.xlsx"),'Sheet','UC数据','Range','B110:B113');
 ix=find(fixed.Person==person);fixed.Actual(ix)=actual(fixed.Horizon(ix));
end
fixed.Error=fixed.Forecast-fixed.Actual;testMetrics=summarize(fixed);
writetable(predictions,fullfile(out,'多原点四步预测明细.csv'),'Encoding','UTF-8');
writetable(metrics,fullfile(out,'多步预测误差对比.csv'),'Encoding','UTF-8');
writetable(fixed,fullfile(out,'保留四周测试预测.csv'),'Encoding','UTF-8');
writetable(testMetrics,fullfile(out,'保留四周测试指标.csv'),'Encoding','UTF-8');
writetable(parameters,fullfile(out,'各原点模型参数.csv'),'Encoding','UTF-8');
writetable(thresholds,fullfile(out,'各原点异常阈值.csv'),'Encoding','UTF-8');
if ~isempty(clipped),writetable(clipped,fullfile(out,'各原点训练缩尾记录.csv'),'Encoding','UTF-8');end
writetable(diagnostics,fullfile(out,'108周训练残差诊断.csv'),'Encoding','UTF-8');
save(fullfile(out,'实验完整结果.mat'),'predictions','metrics','parameters','thresholds','clipped','diagnostics','fixed','testMetrics','selections','origins','H','experiment','lockedAt','-v7.3');
plotErrors(metrics,out,people,models,groups);
fprintf('%s COMPLETE\n',experiment);
end

function result=summarize(detail)
result=table;
for person=unique(detail.Person)'
 for group=unique(detail.Group)'
  for model=unique(detail.Model)'
   for horizon=0:4
    mask=detail.Person==person&detail.Group==group&detail.Model==model;
    if horizon>0,mask=mask&detail.Horizon==horizon;end
    z=detail(mask,:);assert(~isempty(z));e=z.Forecast-z.Actual;
    den=abs(z.Forecast)+abs(z.Actual);sm=zeros(height(z),1);ok=den>0;sm(ok)=200*abs(e(ok))./den(ok);
    result=[result;table(person,group,model,horizon,height(z),mean(abs(e)),sqrt(mean(e.^2)),mean(sm), ...
     'VariableNames',{'Person','Group','Model','Horizon','N','MAE','RMSE','sMAPE'})]; %#ok<AGROW>
   end
  end
 end
end
end

function plotErrors(metrics,out,people,models,groups)
colors=[.145 .388 .922;.486 .227 .929;.918 .345 .047;.020 .588 .412];
for person=people
 f=figure('Color','w','Position',[60 60 1200 380]);
 measures=["MAE","RMSE","sMAPE"];
 for j=1:3
  subplot(1,3,j);hold on;labels=strings(0);
  for b=1:numel(models)
   for g=1:numel(groups)
    z=metrics(metrics.Person==person&metrics.Model==models(b)&metrics.Group==groups(g)&metrics.Horizon>0,:);
    z=sortrows(z,'Horizon');style='-o';if g==2,style='--s';end
    plot(z.Horizon,z.(measures(j)),style,'Color',colors(b,:),'LineWidth',1.4,'MarkerSize',5);
    labels(end+1)=models(b)+" "+groups(g); %#ok<AGROW>
   end
  end
  xticks(1:4);xlim([.8 4.2]);ylim([0 inf]);xlabel('预测步长（周）');
  unit='元';if j==3,unit='%';end
  ylabel(measures(j)+"（"+unit+"）");grid on;title(person+" 27个固定原点");
  legend(labels,'Location','northoutside','FontSize',8);set(gca,'FontName','Microsoft YaHei');
 end
 exportgraphics(f,fullfile(out,person+"_不同预测步长误差.png"),'Resolution',180);close(f);
end
end
