function plot_three_arima
root=fileparts(mfilename('fullpath'));out=fullfile(root,'three_arima_charts');if ~isfolder(out),mkdir(out);end
set(groot,'DefaultFigureVisible','off','DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
o=fullfile(fileparts(root),'outputs');
a=readtable(fullfile(o,'A_自然周_ARIMA','A_ARIMA逐折预测.csv'),'TextType','string');
chart(a.TargetDate,[a.Actual a.Forecast],{'实际金额','一步滚动预测'},'A 自然周扩展窗口一步预测','元每周','A_rolling');
a=readtable(fullfile(o,'A_自然周_ARIMA','A_ARIMA固定原点预测.csv'),'TextType','string');
chart(a.PeriodStart,[a.Actual a.Forecast],{'实际金额','固定原点预测'},'A 自然周固定原点预测','元每周','A_fixed');
for item=["B","C"]
 if item=="B",rolling='originalbill_rolling_output.csv';actual='holdout_daily_actual.csv';fixed='holdout_daily_forecast.csv';else,rolling='newbill_rolling_output.csv';actual='newbill_test.csv';fixed='newbill_model_output.csv';end
 r=readtable(fullfile(root,rolling),'TextType','string');
 chart(r.Date,[r.Actual r.Forecast],{'实际金额','次日滚动预测'},item+' 日度扩展窗口一步预测','元每天',item+'_daily_rolling');
 r=readtable(fullfile(root,actual),'TextType','string');p=readtable(fullfile(root,fixed),'TextType','string');
 chart(r.Date,[r.Actual p.Forecast(1:61)],{'实际金额','固定原点预测'},item+' 日度固定原点预测','元每天',item+'_daily_fixed');
end
b=readtable(fullfile(o,'ECOTOOL_ARIMA_49轮周频回测.csv'),'VariableNamingRule','preserve','TextType','string');
chart(b{:,'训练截止日'},[b{:,'4周实际合计'} b{:,'4周预测合计'}],{'未来四周实际合计','未来四周预测合计'},'B 周度四步预测的49轮验证','元每四周','B_weekly_49');
b=readtable(fullfile(o,'ARIMA固定训练集_9至10月实际预测对照.csv'),'VariableNamingRule','preserve','TextType','string');
mask=string(b{:,1})=="完整周";
chart(datetime(string(b{mask,2})),double(b{mask,3:4}),{'实际金额','固定原点预测'},'B 自然周固定原点预测','元每周','B_weekly_fixed');
c=readtable(fullfile(o,'ARIMA_UC同口径','ARIMA逐折模型与预测.csv'),'TextType','string');
z=readtable(fullfile(o,'ARIMA_UC同口径','ARIMA固定原点多步预测.csv'),'TextType','string');
freq=["月度","自然周","连续七天"];codes=["monthly","weekly","seven"];
for i=1:3
 q=c(c.Frequency==freq(i),:);units='元每周';if i==1,units='元每月';end
 chart(q.TargetDate,[q.Actual q.Forecast],{'实际金额','一步滚动预测'},'C '+freq(i)+'扩展窗口一步预测',units,'C_'+codes(i)+'_rolling');
 q=z(z.Frequency==freq(i),:);
 if i==1
  % Include the last five training months for context around the one test month.
  input=readtable(fullfile(root,'uc_alignment_inputs','UC个人总支出_月度_含美元.csv'),'VariableNamingRule','preserve','TextType','string');
  d=datetime(string(input{21:26,1}),'InputFormat','yyyy-MM');v=double(input{21:26,'个人总支付_元'});p=nan(6,1);p(6)=q.Forecast;
  chart(d,[v p],{'实际金额','十月固定原点预测'},'C 月度十月预测与实际',units,'C_'+codes(i)+'_fixed');
 else
  chart(q.PeriodStart,[q.PeriodActual q.Forecast],{'实际金额','固定原点预测'},'C '+freq(i)+'固定原点预测',units,'C_'+codes(i)+'_fixed');
 end
end
fprintf('Saved charts to %s\n',out);
 function chart(d,v,names,titleText,unit,name)
  if ~isdatetime(d),d=datetime(string(d));end
  f=figure('Visible','off','Color','w','Position',[100 100 1500 520]);f.Theme='light';ax=axes(f,'Position',[.08 .18 .88 .66],'Color','w','XColor',[.2 .2 .2],'YColor',[.2 .2 .2]);hold(ax,'on');
  colors=[.10 .36 .58;.83 .29 .10];
  for j=1:size(v,2),plot(ax,d,v(:,j),'-o','Color',colors(j,:),'LineWidth',1.9,'MarkerSize',4);end
  grid(ax,'on');ax.GridAlpha=.14;ax.FontSize=14;ax.Box='off';ylabel(ax,unit,'Color','k');title(ax,titleText,'FontSize',19,'FontWeight','bold','Color','k');
  if numel(d)>1,xlim(ax,[d(1)-caldays(1),d(end)+caldays(1)]);end
  xtickformat(ax,'MM-dd');xlabel(ax,'目标日期或周期起始日  2026年','Color','k');if name=="B_weekly_49",xlabel(ax,'训练截止日  2025年至2026年','Color','k');end
  legend(ax,names,'Location','northoutside','Orientation','horizontal','Box','off','FontSize',13,'TextColor','k');
  exportgraphics(f,fullfile(out,string(name)+".png"),'Resolution',170,'BackgroundColor','white');close(f);
 end
end
