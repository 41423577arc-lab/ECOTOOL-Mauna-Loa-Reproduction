function align_arima_uc
% Same input, targets and forecast origins as the supplied UC project.
root=fileparts(mfilename('fullpath')); out=fullfile(fileparts(root),'outputs','ARIMA_UC同口径');
if ~isfolder(out),mkdir(out);end
inputs=fullfile(root,'uc_alignment_inputs');if ~isfolder(inputs),mkdir(inputs);end
source=fullfile(getenv('LOCALAPPDATA'),'Temp');
names=["UC个人总支出_月度_含美元.csv","自然周.xlsx","连续七天.xlsx", ...
    "UC最终模型比较.csv","UC最终模型比较 (11).csv","UC最终模型比较 (59).csv"];
for name=names,copyfile(fullfile(source,name),fullfile(inputs,name));end
addpath(getenv('CONSUMPTION_ECOTOOL'));set(groot,'DefaultFigureVisible','off');
monthly=readtable(fullfile(inputs,names(1)),'VariableNamingRule','preserve','TextType','string');
octoberActual=monthly{26,'个人总支付_元'};assert(abs(octoberActual-3702.17)<1e-6);
detail=table; comparison=table; future=table; october=table; records=cell(3,1);
labels=["月度","自然周","连续七天"];
for f=1:3
 if f==1
  dates=datetime(string(monthly{:,1}),'InputFormat','yyyy-MM');values=monthly{:,'个人总支付_元'};
  n=25;initial=15;H=1;weights=1;
 else
  t=readtable(fullfile(inputs,names(f)),'Sheet','02_UC直接建模','VariableNamingRule','preserve','TextType','string');
  dates=datetime(string(t{:,1}),'InputFormat','yyyy-MM-dd');values=t{:,'个人总支付_元'};
  n=108;initial=78;H=5;
  if f==2,weights=[4/7;1;1;1;6/7];else,weights=[3/7;1;1;1;1];end
 end
 y=double(values(1:n));assert(all(isfinite(y))&&all(y>=0));
 if f==1,assert(dates(n)==datetime(2026,9,1));
 elseif f==2,assert(dates(n)+caldays(6)==datetime(2026,9,27));
 else,assert(dates(n)+caldays(6)==datetime(2026,9,26));end
 predictions=nan(n-initial,3);
 for k=initial:n-1
  history=y(1:k);scale=mean(abs(diff(history)));assert(scale>0);
  captured=evalc('m=modelAUTO(history,''s'',1,''diffs'',1,''boxcox'',0,''nofs'',1,''method'',''CML'');');
  assert(any(contains(upper(string(m.table)),'CONDITIONAL')),'Unexpected estimation criterion');
  p=m.py(1);assert(isreal(p)&&isfinite(p));
  predictions(k-initial+1,:)=[p,history(end),mean(history(end-2:end))];
  spec=strjoin(strtrim(string(m.model))',' | ');
  detail=[detail;table(labels(f),k,dates(k),dates(k+1),y(k+1),p,p-y(k+1),scale,spec, ...
   'VariableNames',{'Frequency','TrainingN','TrainingEnd','TargetDate','Actual','Forecast','Error','MASEScale','Model'})];
  if mod(k-initial+1,10)==0,fprintf('%s ROLLING %d/%d\n',labels(f),k-initial+1,n-initial);end
  close all;
 end
 actual=y(initial+1:n); scales=arrayfun(@(k)mean(abs(diff(y(1:k)))),(initial:n-1)');
 models=["AutoARIMA","朴素","三期移动平均"];
 for b=1:3
  e=predictions(:,b)-actual;den=abs(predictions(:,b))+abs(actual);sm=200*abs(e)./den;sm(den==0)=0;
  comparison=[comparison;table(labels(f),models(b),numel(e),mean(abs(e)),sqrt(mean(e.^2)),mean(sm),mean(abs(e)./scales), ...
   'VariableNames',{'Frequency','Model','N','MAE','RMSE','sMAPE','MASE'})];
 end
 uc=readtable(fullfile(inputs,names(f+3)),'TextType','string');uc=uc(uc.Target=="总支付",:);
 % Baselines must reproduce the supplied UC project before comparison.
 assert(abs(comparison.MAE(end-1)-uc.MAE(uc.Model=="朴素"))<1e-6);
 base=uc(contains(uc.Model,'移动平均'),:);assert(abs(comparison.MAE(end)-base.MAE)<1e-6);
 ucModels=["RW","LLT"];
 for b=1:2
  row=uc(uc.Model==ucModels(b),:);
  comparison=[comparison;table(labels(f),"UC-"+row.Model,row.N,row.MAE,row.RMSE,row.sMAPE,row.MASE, ...
   'VariableNames',{'Frequency','Model','N','MAE','RMSE','sMAPE','MASE'})];
 end
 captured=evalc('m=modelAUTO(y,''s'',1,''diffs'',1,''boxcox'',0,''nofs'',H,''method'',''CML'');');
 p=m.py(:);assert(numel(p)==H&&all(isfinite(p))&&isreal(p));
 if f==1,targetDates=dates(n)+calmonths((1:H)');else,targetDates=dates(n)+caldays(7*(1:H)');end
 truth=nan(H,1);available=min(H,numel(values)-n);truth(1:available)=values(n+(1:available));
 spec=strjoin(strtrim(string(m.model))',' | ');
 future=[future;table(repmat(labels(f),H,1),(1:H)',targetDates,p,truth,weights,repmat(spec,H,1), ...
  'VariableNames',{'Frequency','Horizon','PeriodStart','Forecast','PeriodActual','OctoberWeight','Model'})];
 total=sum(weights.*p);october=[october;table(labels(f),spec,total,octoberActual,total-octoberActual,100*(total-octoberActual)/octoberActual, ...
  'VariableNames',{'Frequency','Model','Forecast','OctoberActual','Error','RelativeErrorPct'})];
 records{f}=m;
 writetable(comparison,fullfile(out,'同口径滚动验证比较.csv'),'Encoding','UTF-8');
 writetable(detail,fullfile(out,'ARIMA逐折模型与预测.csv'),'Encoding','UTF-8');
 writetable(future,fullfile(out,'ARIMA固定原点多步预测.csv'),'Encoding','UTF-8');
 writetable(october,fullfile(out,'ARIMA完整十月预测.csv'),'Encoding','UTF-8');
 fprintf('%s DONE | October %.4f | model %s\n',labels(f),total,spec);
end
save(fullfile(root,'aligned_arima_uc.mat'),'comparison','detail','future','october','records');
disp(comparison);disp(october);
end
