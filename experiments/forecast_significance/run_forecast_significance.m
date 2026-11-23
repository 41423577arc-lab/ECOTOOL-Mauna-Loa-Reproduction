function run_forecast_significance()
% 已有预测的配对损失推断；不训练、不读取保留测试预测、不调用ECOTOOL。
here=string(fileparts(mfilename('fullpath')));out=fullfile(here,'results');
if ~isfolder(out),mkdir(out);end
[pairs,validation,inputFiles]=significance_inputs(); % 全部输入核验先于统计计算
cfg=struct('alpha',.05,'main_lag',3,'lags',[2 3 4 6],'main_block',4,'blocks',[3 4 5], ...
 'bootstrap_repetitions',10000,'base_seed',20261123,'n_origins',27,'horizons',4, ...
 'hac_distribution','asymptotic standard normal, two-sided', ...
 'hac_normalization','autocovariance denominator N; no degrees-of-freedom correction', ...
 'bootstrap_method','non-circular overlapping moving blocks, percentile intervals', ...
 'bootstrap_seed_rule','base_seed + 1000*comparison_id + block_length');
originalRng=rng;restoreRng=onCleanup(@() rng(originalRng));
results=table;origins=table;itemLoss=table;hacSensitivity=table;bootSensitivity=table;
bootstrapMeans=cell(9,3);
for i=1:9
 p=pairs{i};d=p.meanDiff;mae1=mean(p.loss1,'all');mae2=mean(p.loss2,'all');
 for n=1:27
  origins=[origins;table(i,p.person,p.model1,p.model2,p.origins(n),mean(p.loss1(n,:)),mean(p.loss2(n,:)),d(n), ...
   'VariableNames',{'比较编号','成员','对照模型','比较模型','预测原点','对照平均绝对损失','比较平均绝对损失','四步平均损失差'})]; %#ok<AGROW>
  for h=1:4
   itemLoss=[itemLoss;table(i,p.person,p.model1,p.model2,p.origins(n),h,p.targets(n,h),p.dates(n,h),p.loss1(n,h),p.loss2(n,h),p.diff(n,h), ...
    'VariableNames',{'比较编号','成员','对照模型','比较模型','预测原点','预测步长','目标周索引','目标周起始日','对照绝对损失','比较绝对损失','损失差'})]; %#ok<AGROW>
  end
 end
 for lag=cfg.lags
  [se,z,pvalue,lrv]=neweyWest(d,lag);
  hacSensitivity=[hacSensitivity;table(i,p.person,lag,mean(d),lrv,se,z,pvalue, ...
   'VariableNames',{'比较编号','成员','HAC滞后','平均损失差','长期方差','HAC标准误','检验统计量','原始p值'})]; %#ok<AGROW>
 end
 for j=1:3
  block=cfg.blocks(j);seed=cfg.base_seed+1000*i+block;
  rng(seed,'twister');means=movingBlocks(d,block,cfg.bootstrap_repetitions);bootstrapMeans{i,j}=means;
  ci=prctile(means,[2.5 97.5]);
  bootSensitivity=[bootSensitivity;table(i,p.person,block,seed,cfg.bootstrap_repetitions,mean(d),mean(means),ci(1),ci(2),ci(1)>0||ci(2)<0, ...
   'VariableNames',{'比较编号','成员','区块长度','随机种子','重复次数','平均损失差','Bootstrap均值','区间下限','区间上限','区间排除零'})]; %#ok<AGROW>
 end
 r=hacSensitivity(hacSensitivity.('比较编号')==i&hacSensitivity.('HAC滞后')==3,:);
 b=bootSensitivity(bootSensitivity.('比较编号')==i&bootSensitivity.('区块长度')==4,:);
 results=[results;table(i,p.question,p.person,p.model1,p.model2,27,108,mae1,mae2,100*(mae1-mae2)/mae1,mean(d), ...
  r.('HAC标准误'),r.('检验统计量'),r.('原始p值'),b.('区间下限'),b.('区间上限'), ...
  'VariableNames',{'比较编号','研究问题','成员','对照模型','比较模型','原点数','逐项配对数','对照MAE','比较MAE','MAE改善率百分比','平均损失差', ...
  'HAC标准误','检验统计量','原始p值','Bootstrap区间下限','Bootstrap区间上限'})]; %#ok<AGROW>
end
results.('Holm校正p值')=holmAdjust(results.('原始p值'));
results.('原始显著')=results.('原始p值')<cfg.alpha;
results.('Holm校正显著')=results.('Holm校正p值')<cfg.alpha;
results.('Bootstrap区间排除零')=results.('Bootstrap区间下限')>0|results.('Bootstrap区间上限')<0;
results.('显著性结论')=repmat("未达到Holm校正后显著",9,1);
results.('显著性结论')(results.('Holm校正显著')&results.('平均损失差')>0)="模型2显著更优（探索性）";
results.('显著性结论')(results.('Holm校正显著')&results.('平均损失差')<0)="模型1显著更优（探索性）";
for lag=cfg.lags
 ix=hacSensitivity.('HAC滞后')==lag;hacSensitivity.('Holm校正p值')(ix)=holmAdjust(hacSensitivity.('原始p值')(ix));
end
hacSensitivity.('原始显著')=hacSensitivity.('原始p值')<cfg.alpha;
hacSensitivity.('Holm校正显著')=hacSensitivity.('Holm校正p值')<cfg.alpha;
% 固定参数均完整保留，稳健性结果不用于更换主参数。
writetable(results,fullfile(out,'预测损失差异检验.csv'),'Encoding','UTF-8');
writetable(origins,fullfile(out,'原点级预测损失差.csv'),'Encoding','UTF-8');
writetable(itemLoss,fullfile(out,'不同预测步长损失差.csv'),'Encoding','UTF-8');
writetable(hacSensitivity,fullfile(out,'HAC滞后稳健性.csv'),'Encoding','UTF-8');
writetable(bootSensitivity,fullfile(out,'区块长度敏感性.csv'),'Encoding','UTF-8');
inputHashes=struct('relative_path',{},'sha256',{});root=fileparts(fileparts(here));
for k=1:numel(inputFiles)
 inputHashes(k)=struct('relative_path',strrep(extractAfter(inputFiles(k),strlength(root)+1),'\','/'),'sha256',file_sha256(inputFiles(k)));
end
save(fullfile(out,'统计检验完整结果.mat'),'results','origins','itemLoss','hacSensitivity','bootSensitivity','cfg','bootstrapMeans','inputHashes','validation');
plotIntervals(results,out);
write_significance_report(results,hacSensitivity,bootSensitivity,cfg,out);
verification=verify_significance();
assert(verification.all_checks_passed);
disp(results(:,{'比较编号','成员','对照模型','比较模型','平均损失差','原始p值','Holm校正p值','显著性结论'}));
fprintf('FORECAST_SIGNIFICANCE_COMPLETE：MATLAB统计计算及独立核验通过；未重训模型。\n');
end

function [se,z,pvalue,lrv]=neweyWest(d,lag)
% gamma(k)=sum(u(t)*u(t-k))/N；Bartlett权重1-k/(L+1)。
n=numel(d);u=d-mean(d);lrv=sum(u.^2)/n;
for k=1:lag,lrv=lrv+2*(1-k/(lag+1))*sum(u(k+1:end).*u(1:end-k))/n;end
assert(isfinite(lrv)&&lrv>0,'长期方差退化，无法作有效正态近似检验，应人工复核');
se=sqrt(lrv/n);z=mean(d)/se;pvalue=erfc(abs(z)/sqrt(2));
end

function adjusted=holmAdjust(p)
assert(all(isfinite(p)&p>=0&p<=1));[sorted,idx]=sort(p);m=numel(p);
adjusted=zeros(m,1);adjusted(idx)=min(1,cummax((m-(1:m)'+1).*sorted));
end

function means=movingBlocks(d,block,B)
% N-b+1个不环绕重叠块等概率抽取；拼接ceil(N/b)块后截取前N点。
n=numel(d);nb=ceil(n/block);starts=randi(n-block+1,nb,B);means=zeros(B,1);
for r=1:B
 index=reshape((starts(:,r)+(0:block-1))',[],1);index=index(1:n);
 means(r)=mean(d(index));
end
end

function plotIntervals(T,out)
f=figure('Visible','off','Color','w','Position',[80 80 1250 760]);ax=axes(f);hold(ax,'on');
colors=[.145 .388 .922;.918 .345 .047];labels=strings(9,1);
for i=1:9
 row=T(i,:);y=10-i;c=colors(1+(i>6),:);d=row.('平均损失差');
 lo=row.('Bootstrap区间下限');hi=row.('Bootstrap区间上限');
 plot(ax,[lo hi],[y+.09 y+.09],'-','Color',c,'LineWidth',2.8,'HandleVisibility','off');
 plot(ax,[lo lo hi hi],[y+.04 y+.14 y+.14 y+.04],'.','Color',c,'HandleVisibility','off');
 margin=1.95996398454005*row.('HAC标准误');
 plot(ax,[d-margin d+margin],[y-.11 y-.11],'--','Color',[.45 .45 .45],'LineWidth',1.5,'HandleVisibility','off');
 plot(ax,d,y+.09,'o','MarkerFaceColor',c,'Color',c,'MarkerSize',6,'HandleVisibility','off');
 labels(i)=sprintf('%d  %s：%s → %s',i,row.('成员'),row.('对照模型'),row.('比较模型'));
end
h1=plot(ax,nan,nan,'-o','Color',colors(1,:),'LineWidth',2);
h2=plot(ax,nan,nan,'--','Color',[.45 .45 .45],'LineWidth',1.5);
xline(ax,0,':k','LineWidth',1.2);yticks(ax,1:9);yticklabels(ax,flipud(labels));ylim(ax,[.4 9.7]);
grid(ax,'on');xlabel(ax,'平均绝对损失差（元）；正值表示箭头右侧方法更好');
title(ax,{'九组预测损失差及95%置信区间','27个原点，四步等权；所有图示区间均未作多重比较校正'});
legend(ax,[h1 h2],{'移动区块Bootstrap：长度4，百分位区间','HAC：滞后3，渐近正态区间'},'Location','southoutside');
set(ax,'FontName','Microsoft YaHei','FontSize',10);ax.Position=[.40 .16 .57 .70];
exportgraphics(f,fullfile(out,'预测损失差置信区间.png'),'Resolution',200);close(f);
end
