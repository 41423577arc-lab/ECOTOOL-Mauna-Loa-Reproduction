function run_uniform_arima
root=fileparts(mfilename('fullpath'));out=fullfile(fileparts(root),'outputs','ABC_AutoARIMA_正式统一版_20261122');
addpath(getenv('CONSUMPTION_ECOTOOL'));set(groot,'DefaultFigureVisible','off');
detail=table;summary=table;fixed=table;models=cell(3,31);modelSummary=table;m=[];
for who=1:3
 person=["A","B","C"];person=person(who);
 input=readtable(fullfile(out,person+'_统一自然周输入.csv'),'TextType','string');
 dates=input.PeriodStart;if ~isdatetime(dates),dates=datetime(dates);end
 assert(height(input)==112&&isequal(dates,datetime(2024,9,2)+caldays(7*(0:111)')));
 y=input.Amount(1:108);assert(all(isfinite(y))&&all(y>=0));
 pr=nan(30,1);scales=nan(30,1);
 for k=78:107
  history=y(1:k);i=k-77;scales(i)=mean(abs(diff(history)));assert(scales(i)>0);
  captured=evalc('m=fitSame(history,1);');models{who,i}=m;pr(i)=m.py(1);assert(isfinite(pr(i))&&isreal(pr(i)));
  spec=strjoin(strtrim(string(m.model))',' | ');
  detail=[detail;table(person,k,dates(k),dates(k+1),y(k+1),pr(i),pr(i)-y(k+1),scales(i),spec, ...
   'VariableNames',{'Person','TrainingN','TrainingEnd','TargetDate','Actual','Forecast','Error','MASEScale','Model'})];
  if mod(i,10)==0,fprintf('%s ROLLING %d/30\n',person,i);end
  close all;
 end
 summary=[summary;score(person,"30折一步滚动验证",y(79:108),pr,scales)];
 captured=evalc('m=fitSame(y,4);');models{who,31}=m;p=m.py(:);assert(numel(p)==4&&all(isfinite(p))&&isreal(p));
 save(fullfile(root,'abc_final',person+'_locked.mat'),'m','p','y');
 actual=input.Amount(109:112);scale=mean(abs(diff(y)));
 summary=[summary;score(person,"固定原点四期测试",actual,p,repmat(scale,4,1))];
 spec=strjoin(strtrim(string(m.model))',' | ');
 fixed=[fixed;table(repmat(person,4,1),(1:4)',dates(109:112),p,actual,p-actual, ...
  'VariableNames',{'Person','Horizon','PeriodStart','Forecast','Actual','Error'})];
 modelSummary=[modelSummary;table(person,spec,sum(p),sum(actual),sum(p)-sum(actual),100*(sum(p)-sum(actual))/sum(actual), ...
  'VariableNames',{'Person','Model','FourWeekForecast','FourWeekActual','Error','RelativeErrorPct'})];
 writetable(detail,fullfile(out,'ABC_30折逐折预测.csv'),'Encoding','UTF-8');
 writetable(summary,fullfile(out,'ABC_统一评价指标.csv'),'Encoding','UTF-8');
 writetable(fixed,fullfile(out,'ABC_固定原点四期预测.csv'),'Encoding','UTF-8');
 writetable(modelSummary,fullfile(out,'ABC_最终模型与四期累计.csv'),'Encoding','UTF-8');
 fprintf('%s FINISHED | %s\n',person,spec);
end
save(fullfile(root,'abc_final','results.mat'),'models','detail','summary','fixed','modelSummary');
set(groot,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
for person=["A","B","C"]
 d=detail(detail.Person==person,:);plotResult(d.TargetDate,[d.Actual d.Forecast],person+' 统一方案30折下一周预测',person+'_rolling');
 d=fixed(fixed.Person==person,:);plotResult(d.PeriodStart,[d.Actual d.Forecast],person+' 统一方案固定原点四期预测',person+'_fixed');
end
disp(summary);disp(modelSummary);
 function m=fitSame(history,h)
  m=modelAUTO(history,'u',[],'s',1,'diffs',1,'boxcox',0,'nofs',h,'outlier',[0 0 0 0 0 .7 3],'method','CML');
  assert(any(contains(upper(string(m.table)),'CONDITIONAL')));
  assert(isempty(m.y0)||all(abs(m.y0(:)-history(:))<1e-8),'Unexpected automatic amount adjustment');
 end
 function plotResult(d,v,titleText,name)
  f=figure('Visible','off','Color','w','Position',[100 100 1450 520]);f.Theme='light';ax=axes(f,'Position',[.09 .18 .87 .66]);hold(ax,'on');
  plot(ax,d,v(:,1),'-o','LineWidth',1.8,'Color',[.1 .36 .58],'MarkerSize',4);plot(ax,d,v(:,2),'-o','LineWidth',1.8,'Color',[.83 .29 .1],'MarkerSize',4);
  ax.FontSize=14;ax.Box='off';grid(ax,'on');ax.GridAlpha=.15;title(ax,titleText,'FontSize',19);ylabel(ax,'金额 元每周');xlabel(ax,'目标周起始日 2026年');xtickformat(ax,'MM-dd');
  legend(ax,{'实际金额','AutoARIMA预测'},'Location','northoutside','Orientation','horizontal','Box','off');
  exportgraphics(f,fullfile(out,name+'.png'),'Resolution',170,'BackgroundColor','white');close(f);
 end
end
function r=score(person,phase,actual,prediction,scale)
e=prediction-actual;den=abs(prediction)+abs(actual);s=200*abs(e)./den;s(den==0)=0;
r=table(person,phase,numel(actual),mean(abs(e)),sqrt(mean(e.^2)),mean(s),mean(abs(e)./scale), ...
 'VariableNames',{'Person','Phase','N','MAE','RMSE','sMAPE','MASE'});
end
