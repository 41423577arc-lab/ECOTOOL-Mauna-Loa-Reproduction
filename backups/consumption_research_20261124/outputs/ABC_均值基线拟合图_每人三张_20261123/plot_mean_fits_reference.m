function plot_mean_fits_reference
root=fileparts(mfilename('fullpath'));
if isfile(fullfile(root,'A_112周建模输入.csv'))
 source=root;out=root;
else
 source=fullfile(fileparts(root),'outputs','ABC_原序列自相关检验与均值基线_20261123');
 out=fullfile(fileparts(root),'outputs','ABC_均值基线拟合图_每人三张_20261123');
end
if ~isfolder(out),mkdir(out);end
r=readtable(fullfile(source,'ABC_均值基线30折明细.csv'),'TextType','string');
p=readtable(fullfile(source,'ABC_均值基线固定原点预测.csv'),'TextType','string');
fits=table;
for who=["A","B","C"]
 t=readtable(fullfile(source,who+'_112周建模输入.csv'));d=t.PeriodStart;if ~isdatetime(d),d=datetime(d);end
 y=t.Amount(1:108);mu=mean(y);fitted=repmat(mu,108,1);
 fits=[fits;table(repmat(who,108,1),d(1:108),y,fitted,y-fitted,'VariableNames',{'Member','PeriodStart','Actual','Fitted','Residual'})];
 chart(who,d(1:108),y,fitted,'训练期样本内拟合','均值模型样本内拟合值',who+'_1_训练期拟合图.png');
 q=r(r.Member==who,:);assert(height(q)==30);chart(who,q.TargetDate,q.Actual,q.Forecast,'30折一步滚动预测拟合','均值模型一步预测值',who+'_2_滚动预测拟合图.png');
 q=p(p.Member==who,:);assert(height(q)==4&&all(abs(q.Forecast-mu)<1e-8));chart(who,q.PeriodStart,q.Actual,q.Forecast,'固定原点四周预测','均值模型固定原点预测值',who+'_3_四周预测图.png');
end
writetable(fits,fullfile(out,'ABC_训练期均值拟合明细.csv'),'Encoding','UTF-8');
writetable(r,fullfile(out,'ABC_滚动预测拟合明细.csv'),'Encoding','UTF-8');
writetable(p,fullfile(out,'ABC_四周预测明细.csv'),'Encoding','UTF-8');
fprintf('Saved 9 reference-style charts to %s\n',out);
 function chart(who,d,actual,forecast,description,predLabel,name)
  if ~isdatetime(d),d=datetime(d);end
  f=figure('Visible','off','Color','w','Position',[100 100 1700 850]);f.Theme='light';
  ax=axes(f,'Position',[.08 .15 .89 .76],'FontName','Microsoft YaHei','FontSize',18);hold(ax,'on');
  plot(ax,d,actual,'-o','Color',[0 0 1],'LineWidth',2.1,'MarkerSize',6,'MarkerFaceColor','w');
  plot(ax,d,forecast,'--s','Color',[1 0 0],'LineWidth',2.1,'MarkerSize',5,'MarkerFaceColor','w');
  grid(ax,'on');ax.GridAlpha=.18;ax.Box='on';ylim(ax,[0,max([actual(:);forecast(:)])*1.12]);
  if numel(d)>1,xlim(ax,[d(1)-caldays(2),d(end)+caldays(2)]);end
  ylabel(ax,'消费金额（元）','FontName','Microsoft YaHei','FontSize',21);
  xlabel(ax,'周期起始日','FontName','Microsoft YaHei','FontSize',21);
  if year(d(1))~=year(d(end)),xtickformat(ax,'yyyy-MM');else,xtickformat(ax,'MM-dd');end
  title(ax,'成员'+who+' 均值模型'+description+'与实际值对比','FontName','Microsoft YaHei','FontSize',23,'FontWeight','normal');
  legend(ax,{'实际值',predLabel},'Location','northwest','Box','on','FontName','Microsoft YaHei','FontSize',17);
  exportgraphics(f,fullfile(out,name),'Resolution',180,'BackgroundColor','white');close(f);
 end
end
