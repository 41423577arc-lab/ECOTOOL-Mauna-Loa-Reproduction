function run_mean_baseline
root=fileparts(mfilename('fullpath'));
if isfile(fullfile(root,'A_112周建模输入.csv'))
 source=root;out=root;
else
 source=fullfile(fileparts(root),'outputs','ABC周消费_ARIMA_修正版_20261122');
 out=fullfile(fileparts(root),'outputs','ABC_原序列自相关检验与均值基线_20261123');
end
if ~isfolder(out),mkdir(out);end
checks=table;acfRows=table;forecasts=table;scores=table;rolling=table;
for who=["A","B","C"]
 t=readtable(fullfile(source,who+'_112周建模输入.csv'));dates=t.PeriodStart;if ~isdatetime(dates),dates=datetime(dates);end
 assert(height(t)==112&&isequal(dates,datetime(2024,9,2)+caldays(7*(0:111)')));
 y=t.Amount(1:108);n=numel(y);x=y-mean(y);ac=zeros(12,1);
 for k=1:12,ac(k)=sum(x(1:end-k).*x(1+k:end))/sum(x.^2);end
 for h=[6 12]
  Q=n*(n+2)*sum(ac(1:h).^2./(n-(1:h)'));prob=gammainc(Q/2,h/2,'upper');
  checks=[checks;table(who,n,h,Q,h,prob,prob<.05, ...
   'VariableNames',{'Member','TrainingN','Lag','LjungBoxQ','DF','PValue','RejectAt005'})];
 end
 acfRows=[acfRows;table(repmat(who,12,1),(1:12)',ac,repmat(1.96/sqrt(n),12,1), ...
  'VariableNames',{'Member','Lag','ACF','ApproximateReferenceBound'})];
 mu=mean(y);p=repmat(mu,4,1);actual=t.Amount(109:112);scale=mean(abs(diff(y)));
 forecasts=[forecasts;table(repmat(who,4,1),dates(109:112),p,actual,p-actual,repmat(mu,4,1), ...
  'VariableNames',{'Member','PeriodStart','Forecast','Actual','Error','TrainingMean'})];
 scores=[scores;metrics(who,"固定原点四期测试",actual,p,repmat(scale,4,1))];
 pred=zeros(30,1);sc=zeros(30,1);
 for k=78:107
  i=k-77;pred(i)=mean(y(1:k));sc(i)=mean(abs(diff(y(1:k))));
  rolling=[rolling;table(who,k,dates(k+1),y(k+1),pred(i),pred(i)-y(k+1),sc(i), ...
   'VariableNames',{'Member','TrainingN','TargetDate','Actual','Forecast','Error','MASEScale'})];
 end
 scores=[scores;metrics(who,"30折扩展窗口均值验证",y(79:108),pred,sc)];
 f=makeFig([100 100 1500 850]);tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
 ax=nexttile(tl);plot(ax,dates(1:108),y,'-o','LineWidth',1.2,'MarkerSize',3);grid(ax,'on');xtickformat(ax,'yyyy-MM');title(ax,'原始训练序列 未差分');ylabel(ax,'金额 元每周');
 ax=nexttile(tl);stem(ax,1:12,ac,'filled');hold(ax,'on');yline(ax,1.96/sqrt(n),'r--');yline(ax,-1.96/sqrt(n),'r--');grid(ax,'on');title(ax,'训练原序列 ACF');xlabel(ax,'滞后 周');ylabel(ax,'自相关系数');
 ax=nexttile(tl);r=checks(checks.Member==who,:);bar(ax,r.Lag,r.PValue);hold(ax,'on');yline(ax,.05,'r--','0.05');ylim(ax,[0 1]);xticks(ax,[6 12]);title(ax,'Ljung Box 检验 p值');xlabel(ax,'联合检验滞后阶数');ylabel(ax,'p值');grid(ax,'on');
 ax=nexttile(tl);axis(ax,'off');text(ax,0,.85,sprintf('训练样本 n = %d\n6阶 Q = %.4f   p = %.6f\n12阶 Q = %.4f   p = %.6f\n仅使用前108周，不含后4周测试\np小于0.05：拒绝各滞后相关共同为零',n,r.LjungBoxQ(1),r.PValue(1),r.LjungBoxQ(2),r.PValue(2)),'FontName','Microsoft YaHei','FontSize',15,'VerticalAlignment','top');
 title(tl,'成员'+who+' 建模前原序列自相关检验','FontSize',20,'FontName','Microsoft YaHei');
 exportgraphics(f,fullfile(out,who+'_原序列ACF与显著性检验.png'),'Resolution',160,'BackgroundColor','white');close(f);
 f=makeFig([100 100 1500 820]);tl=tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
 ax=nexttile(tl);plot(ax,dates(89:112),t.Amount(89:112),'k-o','LineWidth',1.4);hold(ax,'on');plot(ax,dates(109:112),p,'r-s','LineWidth',2);xline(ax,dates(109),'--','测试开始');grid(ax,'on');xtickformat(ax,'MM-dd');ylabel(ax,'金额 元每周');title(ax,'训练尾部与固定原点均值预测');legend(ax,{'实际金额','训练均值预测'},'Box','off');
 ax=nexttile(tl);plot(ax,dates(109:112),actual,'k-o','LineWidth',1.5);hold(ax,'on');plot(ax,dates(109:112),p,'r-s','LineWidth',2);grid(ax,'on');xtickformat(ax,'MM-dd');ylabel(ax,'金额 元每周');xlabel(ax,'目标周起始日 2026年');title(ax,sprintf('后4周测试 训练均值 %.2f 元',mu));legend(ax,{'实际金额','均值基线'},'Box','off');
 title(tl,'成员'+who+' 均值基线 ARIMA 0 0 0 加常数','FontName','Microsoft YaHei','FontSize',20);
 exportgraphics(f,fullfile(out,who+'_均值基线预测.png'),'Resolution',160,'BackgroundColor','white');close(f);
end
writetable(checks,fullfile(out,'ABC_原训练序列LjungBox显著性检验.csv'),'Encoding','UTF-8');
writetable(acfRows,fullfile(out,'ABC_原训练序列ACF.csv'),'Encoding','UTF-8');
writetable(forecasts,fullfile(out,'ABC_均值基线固定原点预测.csv'),'Encoding','UTF-8');
writetable(scores,fullfile(out,'ABC_均值基线误差指标.csv'),'Encoding','UTF-8');
writetable(rolling,fullfile(out,'ABC_均值基线30折明细.csv'),'Encoding','UTF-8');
save(fullfile(out,'均值基线与自相关检验.mat'),'checks','acfRows','forecasts','scores','rolling');disp(checks);disp(scores);
end
function f=makeFig(position)
f=figure('Visible','off','Color','w','Position',position);f.Theme='light';set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultAxesFontSize',13);
end
function r=metrics(who,phase,a,p,sc)
e=p-a;den=abs(p)+abs(a);s=200*abs(e)./den;s(den==0)=0;
r=table(who,phase,numel(a),mean(abs(e)),sqrt(mean(e.^2)),mean(s),mean(abs(e)./sc), ...
 'VariableNames',{'Member','Phase','N','MAE','RMSE','sMAPE','MASE'});
end
