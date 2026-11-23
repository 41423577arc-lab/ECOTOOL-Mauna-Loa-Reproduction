function prepare_report_results(projectRoot)
% 补充报告所需的同原点四模型展示，不改变原UC选模或锁定预测。
out=fullfile(projectRoot,'output'); figures=fullfile(out,'报告图表');
if ~isfolder(figures),mkdir(figures);end
configure_ecotool();
models=["RW","LLT","朴素","三期移动平均"];
colors=[0.145 0.388 0.922;0.486 0.227 0.929;0.918 0.345 0.047;0.020 0.588 0.412];
people=["A","B","C"];allMetrics=table;allForecasts=table;allSums=table;
set(groot,'DefaultFigureVisible','off');
for person=people
 p=fullfile(out,person);r=load(fullfile(p,'step05_rolling.mat'));e=load(fullfile(p,'step06_evaluation.mat'));
 original=load(fullfile(p,'step03_UC_models.mat'));lock=load(fullfile(p,'step06_forecast_locked.mat'));
 y=r.tr.yTrain(:);dates=r.tr.tTest(:);actual=e.evaluation.Actual(:);H=numel(dates);
 pred=nan(H,4);
 for b=1:2
  if models(b)==r.selected(1),pred(:,b)=lock.forecasts(:,1);
  else
   m=modelUC(y,[],char(models(b)),H);
   fitted=original.("ucTotal_"+models(b));
   assert(max(abs(m.par(:)-fitted.par(:)))<1e-8,'补充模型参数与原全训练期估计不同');
   pred(:,b)=m.py(:);
  end
 end
 pred(:,3)=y(end);
 history=y;
 for h=1:H,pred(h,4)=mean(history(end-2:end));history=[history;pred(h,4)];end %#ok<AGROW>
 scale=mean(abs(diff(y)));assert(scale>0);
 for b=1:4
  z=r.summary(r.summary.Model==models(b),:);
  allMetrics=[allMetrics;table(person,"滚动30折",models(b),30,z.MAE,z.RMSE,z.sMAPE,z.MASE,'VariableNames',{'Person','Stage','Model','N','MAE','RMSE','sMAPE','MASE'})]; %#ok<AGROW>
  err=pred(:,b)-actual;den=abs(pred(:,b))+abs(actual);sm=200*abs(err)./den;sm(den==0)=0;
  allMetrics=[allMetrics;table(person,"测试4期",models(b),H,mean(abs(err)),sqrt(mean(err.^2)),mean(sm),mean(abs(err))/scale,'VariableNames',{'Person','Stage','Model','N','MAE','RMSE','sMAPE','MASE'})]; %#ok<AGROW>
  allForecasts=[allForecasts;table(repmat(person,H,1),repmat(models(b),H,1),(1:H)',dates,pred(:,b),actual,err,'VariableNames',{'Person','Model','Horizon','PeriodStart','Forecast','Actual','Error'})]; %#ok<AGROW>
  allSums=[allSums;table(person,models(b),sum(pred(:,b)),sum(actual),sum(err),sum(err)/sum(actual),'VariableNames',{'Person','Model','ForecastSum','ActualSum','ErrorSum','RelativeError'})]; %#ok<AGROW>
 end
 for stage=1:2
  f=figure('Color','w','Position',[80 80 1100 290]);hold on;
  if stage==1
   rows=r.detail.Model=="RW";x=r.detail.PeriodStart(rows);act=r.detail.Actual(rows);plot(x,act,'k-o','LineWidth',1.1,'MarkerSize',3);
   for b=1:4,z=r.detail(r.detail.Model==models(b),:);plot(x,z.Forecast,'Color',colors(b,:),'LineWidth',1.15);end
   heading=person+" 30折扩展窗口一步预测";name=person+"_rolling.png";
  else
   x=dates;plot(x,actual,'k-o','LineWidth',1.2,'MarkerSize',4);
   for b=1:4,plot(x,pred(:,b),'Color',colors(b,:),'LineWidth',1.2,'Marker','.');end
   heading=person+" 固定原点四周预测";name=person+"_fixed.png";
  end
  grid on;title(heading);ylabel('每周总支付（元）');xlabel('目标周起始日');xtickformat('MM-dd');
  legend(["实际",models],'Location','northoutside','Orientation','horizontal','FontSize',9);
  set(gca,'FontName','Microsoft YaHei','FontSize',10);exportgraphics(f,fullfile(figures,name),'Resolution',220);close(f);
 end
end
writetable(allMetrics,fullfile(out,'报告四模型性能汇总.csv'),'Encoding','UTF-8');
writetable(allForecasts,fullfile(out,'报告四模型固定原点预测.csv'),'Encoding','UTF-8');
writetable(allSums,fullfile(out,'报告四模型累计预测.csv'),'Encoding','UTF-8');
f=figure('Color','w','Position',[50 50 1100 700]);
for k=1:4
 subplot(2,2,k);if k<=2,stage="滚动30折";else,stage="测试4期";end
 if mod(k,2)==1,metric='MAE';unit='MAE（元）';else,metric='sMAPE';unit='sMAPE（%）';end
 values=zeros(3,4);
 for a=1:3
  for b=1:4,z=allMetrics(allMetrics.Person==people(a)&allMetrics.Stage==stage&allMetrics.Model==models(b),:);values(a,b)=z.(metric);end
 end
 bars=bar(values);for b=1:4,bars(b).FaceColor=colors(b,:);end
 xticklabels(people);ylabel(unit);title(stage+" "+string(metric));grid on;legend(models,'Location','northoutside','Orientation','horizontal','FontSize',8);set(gca,'FontName','Microsoft YaHei','FontSize',10);
end
exportgraphics(f,fullfile(figures,'三人四模型误差比较.png'),'Resolution',220);close(f);
fprintf('REPORT_RESULTS_READY\n');
end
