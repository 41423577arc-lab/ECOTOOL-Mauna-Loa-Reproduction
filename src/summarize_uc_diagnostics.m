function summarize_uc_diagnostics
% 由已保存预测独立重算诊断，抽样估计结果不混入正式220轮实验。
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results','comparison','uc_diagnostics');
D=load(fullfile(out,'probe_checkpoint.mat')); P=D.P; assert(all(P.done,'all'));
D=load(fullfile(root,'results','comparison','sliding_480','checkpoint.mat')); A=D.C;
D=load(fullfile(root,'results','rolling_c','checkpoint.mat')); E=D.C;
T=readtable(fullfile(out,'existing_round_metrics.csv'),'TextType','string');
M=readtable(fullfile(out,'existing_horizon_metrics.csv'),'TextType','string');
Q=readtable(fullfile(out,'probe_metrics.csv'),'TextType','string');
names=["扩展逐轮lambda" "滑动固定A_lambda" "滑动首轮训练lambda"];
preds={reshape(E.pred(:,1,:),24,220),reshape(A.pred(:,3,:),24,220),reshape(A.pred(:,6,:),24,220)};
S=table; W=table; G=table;
for j=1:3
 p=preds{j}; a=A.actual; e=abs(a-p); scale=A.scales; if j==1, scale=E.scales; end
 % 年均值差仅作为预测增长的诊断代理，不等同于模型的潜在斜率状态。
 pg=(mean(p(13:24,:),1)-mean(p(1:12,:),1))'/12;
 ag=(mean(a(13:24,:),1)-mean(a(1:12,:),1))'/12;
 G=[G;table(repmat(names(j),220,1),(1:220)',pg,ag,pg-ag, ...
  'VariableNames',{'protocol','round','forecast_growth','actual_growth','growth_error'})]; %#ok<AGROW>
 for h=[1 6 12 24]
  sm=200*e(1:h,:)./(abs(a(1:h,:))+abs(p(1:h,:))); ma=e(1:h,:)./scale';
  R=sortrows(T(T.protocol==names(j)&T.horizon==h,:),'round');
  assert(height(R)==220 && max(abs(R.sMAPE-mean(sm,1)'))<1e-9 && max(abs(R.MASE-mean(ma,1)'))<1e-9);
  [~,idx]=sort(R.MAE_ppm,'descend'); top=idx(1:10); share=sum(R.MAE_ppm(top))/sum(R.MAE_ppm);
  if h>=12
   S=[S;table(names(j),h,mean(sm,'all'),mean(ma,'all'),mean(e(1:h,:),'all'),mean(p(1:h,:)-a(1:h,:),'all'),share, ...
    'VariableNames',{'protocol','horizon','sMAPE','MASE','MAE_ppm','bias_ppm','worst10_error_share'})]; %#ok<AGROW>
  end
  if h==24, W=[W;R(top,:)]; end %#ok<AGROW>
 end
 R=sortrows(M(M.protocol==names(j),:),'horizon');
 fullSM=200*e./(abs(a)+abs(p)); fullMA=e./scale';
 assert(max(abs(R.sMAPE-mean(fullSM,2)))<1e-9 && max(abs(R.MASE-mean(fullMA,2)))<1e-9);
end
writetable(S,fullfile(out,'diagnostic_summary.csv'),'Encoding','UTF-8');
writetable(W,fullfile(out,'worst_rounds.csv'),'Encoding','UTF-8');
writetable(G,fullfile(out,'growth_diagnostics.csv'),'Encoding','UTF-8');
% 检查试验CSV与检查点一致，并验证相同数据、尺度和接口的预测。
for row=1:height(Q)
 i=find(P.config.rounds==Q.round(row)); k=find(abs(P.config.lambdas-Q.lambda(row))<1e-12); v=find(P.config.variants==Q.variant(row));
 assert(isscalar(i)&&isscalar(k)&&isscalar(v)); r=Q.round(row); p=P.pred(:,i,v,k); a=A.actual(:,r);
 sm=200*abs(a-p)./(abs(a)+abs(p)); ma=abs(a-p)/A.scales(r);
 assert(abs(Q.sMAPE24(row)-mean(sm))<1e-9 && abs(Q.MASE24(row)-mean(ma))<1e-9);
 assert(max(abs(P.models{i,v,k}.input-vboxcox(A.y(r:r+479),Q.lambda(row))))<1e-10);
 z=P.models{i,v,k}.model.py(:); lambda=Q.lambda(row);
 assert(max(abs(p-exp(log1p(lambda*z)/lambda)))<1e-9);
 reference=preds{k+1}(:,r);
 assert(abs(Q.max_change_ppm(row)-max(abs(p-reference)))<1e-9);
end
assert(height(Q)==numel(P.config.rounds)*5*2);
fid=fopen(fullfile(out,'diagnosis.md'),'w','n','UTF-8'); cleaner=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# UC与论文差异排查\n\n');
fprintf(fid,'本次只排查UC（LLT12）；AR12是补充模型，不能与论文的自动AR视为同一种模型。所有诊断均在独立目录进行，既有滚动结果未覆盖，未通过修改原模型来追赶论文数字。\n\n');
fprintf(fid,'## 已有220轮证据\n\n|协议|前h步|sMAPE（%%）|MASE|MAE（ppm）|预测减真实值的均值（ppm）|最差10轮占绝对误差比例|\n|---|---:|---:|---:|---:|---:|---:|\n');
for r=1:height(S), fprintf(fid,'|%s|%d|%.6f|%.6f|%.6f|%+.6f|%.2f%%|\n',S.protocol(r),S.horizon(r),S.sMAPE(r),S.MASE(r),S.MAE_ppm(r),S.bias_ppm(r),100*S.worst10_error_share(r)); end
fprintf(fid,'\n论文UC前12、24步累计sMAPE为0.114、0.145，MASE为0.290、0.371。必须使用累计平均，不能把第24步的误差直接与论文2年行比较。此前独立核验已排除预测月份错位、重复逆变换和MASE公式错误；本次又独立重算现有逐轮指标。\n\n');
fprintf(fid,'固定480月窗口与原调用完全相同，只将lambda由0.2461改为首轮训练估计值，前24步sMAPE从0.224531降为0.174631；因此lambda选择是已验证的实质影响因素。原扩展窗口同时改变了窗口与逐轮lambda，不能仅据三组总误差把全部变化归于窗口。\n\n');
fprintf(fid,'固定A参数的整体有符号偏差反而比首轮训练lambda小，但绝对误差更大，说明正负误差会互相抵消。不能把全部差距解释为统一方向的低估，也不能据此直接给所有预测加常数修正。\n\n');
fprintf(fid,'旧UC预测不变、仅改用滑动窗口MASE分母时，两年MASE为0.501589；实际滑动固定A参数为0.575251，预测变化贡献+0.073662，分母变化贡献-0.044134。这说明差异不是只靠修正评价分母即可消除，原始ppm预测误差也确实上升。\n\n');
fprintf(fid,'固定A参数下最差两轮为第78、123轮，前24步平均绝对误差分别约4.555、4.378 ppm，且均为系统性低估；首轮训练lambda下，同轮sMAPE分别降为0.365217%%、0.276291%%。最差10轮仅占全部轮次的4.55%%，却贡献约16.74%%的绝对误差；但其余轮次仍贡献超过八成，不能解释成只有两个坏点。\n\n');
fprintf(fid,'|协议|预测增长代理最小值|最大值|增长代理误差的平均绝对值|\n|---|---:|---:|---:|\n');
for j=1:3
 R=G(G.protocol==names(j),:);
 fprintf(fid,'|%s|%.6f|%.6f|%.6f|\n',names(j),min(R.forecast_growth),max(R.forecast_growth),mean(abs(R.growth_error)));
end
fprintf(fid,'\n增长代理单位为ppm/月，定义为预测或真实值的第二年均值减第一年均值再除12，不能直接称为UC潜在斜率参数。较大代理误差与长期趋势外推失准相容；不能单凭此诊断断言优化失败。\n\n');
fprintf(fid,'在上述问题轮次，lambda还会改变各成分相对方差和预测增长，不能只把Box-Cox视为一次不影响模型动态的单位换算。估计表的SCORE为对数方差参数，本机公开auxmodelUC.m使用10的SCORE次方构造方差；PARAM列显示0.00000只是四舍五入，不能据此断言方差为零或估计碰到边界。\n\n');
fprintf(fid,'|轮次|lambda|斜率方差/不规则方差|预测增长代理|真实增长代理|\n|---|---:|---:|---:|---:|\n');
for k=1:2
 for i=1:numel(P.config.rounds)
  r=P.config.rounds(i); par=P.models{i,1,k}.model.par(:); R=G(G.protocol==names(k+1)&G.round==r,:);
  fprintf(fid,'|%d|%.6f|%.6f|%.6f|%.6f|\n',r,P.config.lambdas(k),10^(par(2)-par(4)),R.forecast_growth,R.actual_growth);
 end
end
fprintf(fid,'## 同输入接口及估计方法试验\n\n选取轮次%s：第1轮，加上固定A参数下平均绝对误差最大的两轮。后两轮是事后挑选的问题案例，不能把此抽样均值当作220轮估计或无偏排名。每个轮次比较两种固定lambda、五种调用方法，共%d次拟合。\n\n',mat2str(P.config.rounds),nnz(P.done));
fprintf(fid,'|轮次|lambda|调用|实际估计方法|前24步sMAPE|前24步MASE|相对原预测最大变化（ppm）|\n|---|---:|---|---|---:|---:|---:|\n');
for r=1:height(Q), fprintf(fid,'|%d|%.6f|%s|%s|%.6f|%.6f|%.9f|\n',Q.round(r),Q.lambda(r),Q.variant(r),Q.actual_method(r),Q.sMAPE24(r),Q.MASE24(r),Q.max_change_ppm(r)); end
fprintf(fid,'\n公开modelUC.m中，位置参数调用直接把已有实参传给modelUC0；省略method时，包装器返回的method仍写EML，而后端可能用CML/CSS。名称参数调用则把包装器补全的method、outlier、par0一起传给后端。本试验同时比较位置显式CML、位置显式EML和名称显式CML/EML；实际方法只看估计表，不以包装器字段为准。\n\n');
fprintf(fid,'本次30次拟合中，所有调用对相应原预测的最大差异均为%.12g ppm。因此，在所测三轮与两种lambda下，改成显式EML并没有改善预测，不能把CML/EML标签差异认定为主要原因，也没有依据为此直接重跑整套220轮。此结果不证明加密后端完全忽略method，只说明本次预测对这个开关不敏感。\n\n',max(Q.max_change_ppm));
fprintf(fid,'论文给出的UC示例恰好也是省略method的位置调用，因此不能仅因本机实际为CSS，就断言是我们没有按示例运行，或断言论文Table 4必然使用EML。论文没有提供完整逐轮估计表及优化器轨迹，当前后端又是加密P代码。\n\n');
fprintf(fid,'## 已确认与仍待确认\n\n已确认：lambda和训练策略能明显改变本样本结果；误差有长步长累积，偏差方向与集中程度见上表及逐步长CSV；AR12与论文AR定义不一致。实际接口默认存在方法字段与估计表不一致的现象。方法试验只能说明所选案例的敏感性，不能替代完整220轮方法对照。\n\n');
fprintf(fid,'尚不能确认：论文滚动实验采用哪种左边界、每轮lambda与估计方法；默认初值、局部最优或边界方差是否解释剩余差异。论文理论部分描述dummy季节项，案例部分却称trigonometric，并统一给出LLT12接口；单凭这些文字不能证明本机季节项与原作者不同，也不应擅自换成另一模型。没有原作者实际逐轮程序或同版可审查后端，就不能唯一归因于版本差异。\n\n');
fprintf(fid,'自定义par0的首个附加试验超过约3分钟仍未返回，已终止且未获得可用拟合。手册没有明确其数值尺度；不能将该次未完成试验当作优化失败、参数尺度错误或局部最优的证据，也未纳入上述30次有效试验。\n\n');
fprintf(fid,'建议保留所有已完成结果，把无前视固定lambda作为独立、可解释的协议。当前不优先仅为CML/EML标签再重跑220轮；应先向作者或同版参考实现确认实际滚动代码、季节项实现及初值定义。若未来开展方法对照，需预先固定同一窗口和lambda，不能按论文接近程度选参数。\n\n');
fprintf(fid,'来源：[原论文案例及Table 4](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0221238)，本机公开modelUC.m与checkInputs.m，以及既有两份检查点。MATLAB %s；ECOTOOL 1.0。\n',version);
% 用MATLAB生成误差随预测步长的图，避免把点误差当累计误差。
f=figure('Visible','off','Color','w','Position',[50 50 1350 550]); closeFigure=onCleanup(@()close(f)); %#ok<NASGU>
t=tiledlayout(f,1,2); colors=lines(3);
for panel=1:2
 ax=nexttile(t); hold(ax,'on');
 for j=1:3
  R=sortrows(M(M.protocol==names(j),:),'horizon'); vals=cumsum(R.sMAPE)./(1:24)';
  if panel==2, vals=R.bias_ppm; end
  plot(ax,R.horizon,vals,'LineWidth',1.8,'Color',colors(j,:),'DisplayName',names(j));
 end
 set(ax,'FontName','Microsoft YaHei','FontSize',11,'XColor','k','YColor','k','Color','w'); grid(ax,'on'); xlabel(ax,'预测步长（月）');
 if panel==1, ylabel(ax,'累计sMAPE（%）'); title(ax,'前h步累计预测误差'); else, ylabel(ax,'平均预测偏差（ppm）'); title(ax,'第h步：预测减真实值'); yline(ax,0,':'); end
 if panel==1, lg=legend(ax,'NumColumns',3,'TextColor','k','Color','w'); lg.Layout.Tile='south'; end
end
exportgraphics(f,fullfile(out,'diagnostic.png'),'Resolution',150);
fprintf(fid,'\n![UC误差与偏差](diagnostic.png)\n');
audit=fullfile(out,'audit.txt'); f2=fopen(audit,'w','n','UTF-8'); fprintf(f2,'PASS：现有三协议逐轮指标独立重算一致；%d项受控拟合均成功，输入和指标与检查点一致。\n此PASS不证明优化收敛或复现论文完整协议。\n',nnz(P.done)); fclose(f2);
disp(S);
end
