function run_corrected_abc
root=fileparts(mfilename('fullpath'));
if isfile(fullfile(root,'A_112周建模输入.csv'))
 out=root;state=fullfile(root,'运行状态');if ~isfolder(state),mkdir(state);end
else
 out=fullfile(fileparts(root),'outputs','ABC周消费_ARIMA_修正版_20261122');state=fullfile(root,'abc_corrected_20261122');
end
toolbox=getenv('CONSUMPTION_ECOTOOL');if ~isempty(toolbox),addpath(toolbox);end
assert(exist('modelAUTO','file')==2,'请先将ECOTOOL加入MATLAB路径。');set(groot,'DefaultFigureVisible','off');
summary=table;rolling=table;fixed=table;final=table;diagnostics=table;residuals=table;acfTable=table;allModels=cell(3,31);m=[];
methodNames=["AutoARIMA","Naive","HistoricalMean"];
for memberIndex=1:3
 names=["A","B","C"];member=names(memberIndex);
 t=readtable(fullfile(out,member+'_112周建模输入.csv'),'TextType','string');dates=t.PeriodStart;if ~isdatetime(dates),dates=datetime(dates);end
 assert(height(t)==112&&isequal(dates,datetime(2024,9,2)+caldays(7*(0:111)')));
 y=t.Amount(1:108);assert(all(isfinite(t.Amount))&&all(t.Amount>=0));predictions=nan(30,3);scales=nan(30,1);
 for k=78:107
  history=y(1:k);i=k-77;scales(i)=mean(abs(diff(history)));assert(scales(i)>0);
  captured=evalc('m=fitSame(history,1);');allModels{memberIndex,i}=m;
  predictions(i,:)=[m.py(1),history(end),mean(history)];assert(all(isfinite(predictions(i,:)))&&isreal(predictions(i,:)));
  spec=strjoin(strtrim(string(m.model))',' | ');
  for b=1:3
   ms=spec;if b>1,ms=methodNames(b);end
   rolling=[rolling;table(member,methodNames(b),i,k,dates(k),dates(k+1),y(k+1),predictions(i,b),predictions(i,b)-y(k+1),scales(i),ms, ...
    'VariableNames',{'Member','Method','Fold','TrainingN','TrainingEnd','TargetDate','Actual','Forecast','Error','MASEScale','Specification'})];
  end
  close all;
  if mod(i,10)==0,fprintf('%s ROLLING %d/30\n',member,i);end
 end
 for b=1:3,summary=[summary;score(member,"30折一步滚动验证",methodNames(b),y(79:108),predictions(:,b),scales)];end
 captured=evalc('m=fitSame(y,4);');allModels{memberIndex,31}=m;p=m.py(:);assert(numel(p)==4&&all(isfinite(p))&&isreal(p));
 save(fullfile(state,member+'_预测锁定.mat'),'m','p','y');
 actual=t.Amount(109:112);testPred=[p,repmat(y(end),4,1),repmat(mean(y),4,1)];scale=mean(abs(diff(y)));
 spec=strjoin(strtrim(string(m.model))',' | ');[ar,diffOrder,ma]=orders(spec);
 for b=1:3
  summary=[summary;score(member,"固定原点四期测试",methodNames(b),actual,testPred(:,b),repmat(scale,4,1))];
  for h=1:4
   fixed=[fixed;table(member,methodNames(b),h,dates(108+h),actual(h),testPred(h,b),testPred(h,b)-actual(h),scale, ...
    'VariableNames',{'Member','Method','Horizon','PeriodStart','Actual','Forecast','Error','MASEScale'})];
  end
  final=[final;table(member,methodNames(b),spec,sum(testPred(:,b)),sum(actual),sum(testPred(:,b))-sum(actual),100*(sum(testPred(:,b))-sum(actual))/sum(actual), ...
   'VariableNames',{'Member','Method','FinalARIMASpecification','ForecastSum','ActualSum','Error','RelativeErrorPct'})];
 end
 % Training one-step innovations only; no test observations enter diagnostics.
 e=m.e(:);e=e(isfinite(e));N=numel(e);assert(N>24&&std(e)>0);x=e-mean(e);den=sum(x.^2);ac=zeros(12,1);
 for lag=1:12,ac(lag)=sum(x(1:end-lag).*x(1+lag:end))/den;end
 Q6=N*(N+2)*sum(ac(1:6).^2./(N-(1:6)'));Q12=N*(N+2)*sum(ac.^2./(N-(1:12)'));
 df6=6-ar-ma;df12=12-ar-ma;p6=NaN;p12=NaN;if df6>0,p6=gammainc(Q6/2,df6/2,'upper');end;if df12>0,p12=gammainc(Q12/2,df12/2,'upper');end
 popStd=sqrt(mean(x.^2));skew=mean((x/popStd).^3);kurt=mean((x/popStd).^4);JB=N/6*(skew^2+(kurt-3)^2/4);JBp=exp(-JB/2);z=x/std(e);
 diagnostics=[diagnostics;table(member,spec,ar,diffOrder,ma,N,mean(e),std(e),Q6,df6,p6,Q12,df12,p12,skew,kurt,JB,JBp, ...
  'VariableNames',{'Member','Specification','AROrder','DiffOrder','MAOrder','EffectiveN','ResidualMean','ResidualSD','LB6_Q','LB6_df','LB6_p','LB12_Q','LB12_df','LB12_p','Skewness','Kurtosis','JB','JB_p'})];
 residuals=[residuals;table(repmat(member,N,1),(1:N)',e,z,'VariableNames',{'Member','InnovationIndex','Residual','EmpiricalStandardizedResidual'})];
 acfTable=[acfTable;table(repmat(member,12,1),(1:12)',ac,repmat(1.96/sqrt(N),12,1),'VariableNames',{'Member','Lag','ACF','ReferenceBound'})];
 diagnosticPlot(member,e,z,ac,N);
 writetable(summary,fullfile(out,'ABC_ARIMA与基准_性能比较表.csv'),'Encoding','UTF-8');
 writetable(rolling,fullfile(out,'ABC_滚动预测明细_含基准.csv'),'Encoding','UTF-8');
 writetable(fixed,fullfile(out,'ABC_固定原点预测明细_含基准.csv'),'Encoding','UTF-8');
 writetable(final,fullfile(out,'ABC_最终模型与四周累计.csv'),'Encoding','UTF-8');
 writetable(diagnostics,fullfile(out,'ABC_ARIMA残差检验.csv'),'Encoding','UTF-8');
 writetable(residuals,fullfile(out,'ABC_ARIMA训练创新残差.csv'),'Encoding','UTF-8');
 writetable(acfTable,fullfile(out,'ABC_ARIMA残差ACF.csv'),'Encoding','UTF-8');
 plotForecast(member,dates(79:108),[y(79:108),predictions],"30折下一周滚动预测",member+'_滚动预测.png');
 plotForecast(member,dates(109:112),[actual,testPred],"固定原点四周预测",member+'_固定原点预测.png');
 fprintf('%s FINISHED | %s | residual n=%d\n',member,spec,N);
end
save(fullfile(state,'ABC_corrected_results.mat'),'summary','rolling','fixed','final','diagnostics','residuals','acfTable','allModels');
comparisonPlot;disp(summary);disp(diagnostics);
 function m=fitSame(history,h)
  m=modelAUTO(history,'u',[],'s',1,'diffs',1,'boxcox',0,'nofs',h,'outlier',[0 0 0 0 0 .7 3],'method','CML');
  assert(any(contains(upper(string(m.table)),'CONDITIONAL')));
  assert(isempty(m.y0)||all(abs(m.y0(:)-history(:))<1e-8));
 end
 function f=lightFigure(position)
  f=figure('Visible','off','Color','w','Position',position);f.Theme='light';
  set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultAxesFontSize',13);
 end
 function plotForecast(member,d,v,description,name)
  f=lightFigure([100 100 1600 560]);ax=axes(f,'Position',[.08 .18 .88 .66]);hold(ax,'on');cols=[.1 .1 .1;.1 .36 .65;.88 .36 .1;.18 .55 .28];styles={'-o','-o','--','-.'};
  for j=1:4,plot(ax,d,v(:,j),styles{j},'Color',cols(j,:),'LineWidth',1.7,'MarkerSize',4);end
  grid(ax,'on');ax.GridAlpha=.14;ax.Box='off';ylabel(ax,'金额 元每周');xlabel(ax,'目标周起始日 2026年');xtickformat(ax,'MM-dd');title(ax,'成员'+member+' '+description,'FontSize',19);
  legend(ax,{'实际金额','AutoARIMA','Naive','历史均值'},'Location','northoutside','Orientation','horizontal','Box','off');
  exportgraphics(f,fullfile(out,name),'Resolution',170,'BackgroundColor','white');close(f);
 end
 function diagnosticPlot(member,e,z,ac,N)
  f=lightFigure([100 100 1500 1060]);tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
  ax=nexttile(tl);plot(ax,e,'-o','LineWidth',1.2,'MarkerSize',3);yline(ax,0,':');grid(ax,'on');title(ax,'训练期一步创新');xlabel(ax,'有效创新序号');ylabel(ax,'残差 元');
  ax=nexttile(tl);stem(ax,1:12,ac,'filled');hold(ax,'on');yline(ax,1.96/sqrt(N),'--r');yline(ax,-1.96/sqrt(N),'--r');yline(ax,0,':');grid(ax,'on');title(ax,'残差 ACF 与近似参照界');xlabel(ax,'滞后 周');ylabel(ax,'自相关系数');
  ax=nexttile(tl);histogram(ax,z,max(8,round(sqrt(N))),'Normalization','pdf','FaceColor',[.3 .6 .8]);hold(ax,'on');xx=linspace(min(-4,min(z)),max(4,max(z)),400);plot(ax,xx,exp(-xx.^2/2)/sqrt(2*pi),'r-','LineWidth',1.7);grid(ax,'on');title(ax,'经验标准化残差分布');xlabel(ax,'残差减均值 再除经验标准差');ylabel(ax,'概率密度');legend(ax,{'经验分布','标准正态参照'},'Box','off');
  ax=nexttile(tl);q=sqrt(2)*erfinv(2*((1:N)'-.5)/N-1);plot(ax,q,sort(z),'+','MarkerSize',6);hold(ax,'on');plot(ax,[min(q) max(q)],[min(q) max(q)],'r--');grid(ax,'on');title(ax,'正态 Q Q 图');xlabel(ax,'标准正态理论分位数');ylabel(ax,'经验标准化残差分位数');
  title(tl,'成员'+member+' AutoARIMA 训练残差诊断','FontName','Microsoft YaHei','FontSize',20);
  exportgraphics(f,fullfile(out,member+'_ARIMA残差诊断.png'),'Resolution',150,'BackgroundColor','white');close(f);
 end
 function comparisonPlot
  f=lightFigure([100 100 1500 980]);tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
  phases=["30折一步滚动验证","固定原点四期测试"];
  for a=1:2
   for metricIndex=1:2
    values=zeros(3,3);
    for personIndex=1:3
     who=["A","B","C"];
     for b=1:3,r=summary(summary.Member==who(personIndex)&summary.Phase==phases(a)&summary.Method==methodNames(b),:);if metricIndex==1,values(personIndex,b)=r.MAE;else,values(personIndex,b)=r.sMAPE;end;end
    end
    ax=nexttile(tl);bar(ax,values);xticks(ax,1:3);xticklabels(ax,{'成员A','成员B','成员C'});grid(ax,'on');
    if metricIndex==1,ylabel(ax,'MAE 元每周');title(ax,phases(a)+' MAE');else,ylabel(ax,'sMAPE 百分比');title(ax,phases(a)+' sMAPE');end
    legend(ax,{'AutoARIMA','Naive','历史均值'},'Location','northoutside','Orientation','horizontal','Box','off');
   end
  end
  title(tl,'三位成员 ARIMA 与基准预测性能比较','FontName','Microsoft YaHei','FontSize',20);
  exportgraphics(f,fullfile(out,'ABC_预测性能比较图.png'),'Resolution',160,'BackgroundColor','white');close(f);
 end
end
function r=score(member,phase,method,actual,prediction,scale)
e=prediction-actual;den=abs(prediction)+abs(actual);s=200*abs(e)./den;s(den==0)=0;
r=table(member,phase,method,numel(actual),mean(abs(e)),sqrt(mean(e.^2)),mean(s),mean(abs(e)./scale), ...
 'VariableNames',{'Member','Phase','Method','N','MAE','RMSE','sMAPE','MASE'});
end
function [p,d,q]=orders(spec)
ar=regexp(char(spec),'c(\d+)','tokens');ma=regexp(char(spec),'a(\d+)','tokens');p=0;q=0;
for i=1:numel(ar),p=max(p,str2double(ar{i}{1}));end;for i=1:numel(ma),q=max(q,str2double(ma{i}{1}));end
d=double(contains(spec,'(1-B)'));if contains(spec,'(1-B)2')||contains(spec,'(1-B)^2'),d=2;end
end
