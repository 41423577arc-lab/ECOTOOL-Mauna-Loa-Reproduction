function summarize_bc_sliding480
% 只读取已完成结果；原A/B与既有六模型结果均不重新拟合或改写。
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results','comparison','sliding_480');
D=load(fullfile(out,'checkpoint.mat'),'C'); C=D.C; assert(all(C.done,'all'));
% 记录续跑完成时的墙钟耗时；逐模型耗时始终保存在原检查点中。
if isfield(C,'execution') && isnan(C.execution.wallSeconds)
 C.execution.finished=char(datetime('now'));
 C.execution.wallSeconds=seconds(datetime(C.execution.finished)-datetime(C.execution.started));
 tmp=fullfile(out,'checkpoint.mat.tmp'); save(tmp,'C','-v7'); movefile(tmp,fullfile(out,'checkpoint.mat'),'f');
end
old=readtable(fullfile(root,'results','comparison','all_models_predictions.csv'),'TextType','string');
P=readtable(fullfile(root,'results','comparison','table4_comparison.csv'),'TextType','string');
A=gitTable(root,'f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6','results/tables/A_rolling_by_horizon.csv');
M=readtable(fullfile(out,'metrics_by_horizon.csv'),'TextType','string');
F=readtable(fullfile(out,'first_train_lambda_metrics_by_horizon.csv'),'TextType','string');
V=table; hs=[1:6 12 24]';
for protocol=["原A滑动480固定0.2461" "此前六模型扩展窗口" "本次滑动480照A" "滑动480首轮训练lambda"]
 names=["Airline" "AutoARIMA" "UC" "AR12"];
 if protocol=="原A滑动480固定0.2461", names=["ETS" "SeasonalNaive"]; end
 if protocol=="此前六模型扩展窗口", names=["ETS" "SeasonalNaive" names]; end
 if protocol=="滑动480首轮训练lambda", names=["Airline" "UC"]; end
 for name=names
  if protocol=="原A滑动480固定0.2461"
   prefix='ETS'; if name=="SeasonalNaive", prefix='Naive'; end
   sm=A.([prefix '_sMAPE']); ma=A.([prefix '_MASE']);
  elseif protocol=="此前六模型扩展窗口"
   Q=sortrows(old(old.model==name,:),{'round','horizon'}); e=abs(Q.actual-Q.predicted);
   sm=accumarray(Q.horizon,200*e./(abs(Q.actual)+abs(Q.predicted)),[24 1],@mean);
   ma=accumarray(Q.horizon,e./Q.scale,[24 1],@mean);
  else
   Q=M(M.model==name,:); if protocol=="滑动480首轮训练lambda", Q=F(F.model==name,:); end
   Q=sortrows(Q,'horizon'); sm=Q.sMAPE_percent; ma=Q.MASE;
  end
  cs=cumsum(sm)./(1:24)'; cm=cumsum(ma)./(1:24)'; W=sortrows(P(P.model==name,:),'horizon');
  ps=W.paper_sMAPE_percent; pm=W.paper_MASE;
  V=[V;table(repmat(name,8,1),repmat(protocol,8,1),hs,sm(hs),ma(hs),cs(hs),cm(hs),ps,pm,cs(hs)-ps,cm(hs)-pm, ...
   'VariableNames',{'model','protocol','horizon','point_sMAPE_percent','point_MASE','cumulative_sMAPE_percent','cumulative_MASE','paper_sMAPE_percent','paper_MASE','delta_sMAPE','delta_MASE'})]; %#ok<AGROW>
 end
end
writetable(V,fullfile(out,'table4_comparison.csv'),'Encoding','UTF-8');
% 固定旧预测，仅更换分母，再更换预测；两项贡献精确相加等于总变化。
J=table;
for name=["Airline" "AutoARIMA" "UC" "AR12"]
 O=sortrows(old(old.model==name,:),{'round','horizon'});
 N=readtable(fullfile(out,'predictions.csv'),'TextType','string'); N=sortrows(N(N.model==name,:),{'round','horizon'});
 for h=[12 24]
  k=N.horizon<=h; eo=abs(O.actual(k)-O.predicted(k)); en=abs(N.actual(k)-N.predicted(k));
  oldMASE=mean(eo./O.scale(k)); switched=mean(eo./N.scale(k)); newMASE=mean(en./N.scale(k));
  oldS=mean(200*eo./(abs(O.actual(k))+abs(O.predicted(k)))); newS=mean(200*en./(abs(N.actual(k))+abs(N.predicted(k))));
  J=[J;table(name,h,oldS,newS,mean(eo),mean(en),oldMASE,switched,newMASE,switched-oldMASE,newMASE-switched, ...
   'VariableNames',{'model','horizon','old_sMAPE','new_sMAPE','old_MAE_ppm','new_MAE_ppm','old_MASE','old_prediction_sliding_scale_MASE','new_MASE','denominator_contribution','prediction_contribution'})]; %#ok<AGROW>
 end
end
writetable(J,fullfile(out,'mase_decomposition.csv'),'Encoding','UTF-8');
% 图中四格采用同一模型顺序，论文无AR12对应值，以空值表示。
f=figure('Visible','off','Color','w','Position',[50 50 1500 850]); cl=onCleanup(@()close(f)); %#ok<NASGU>
t=tiledlayout(f,2,2,'TileSpacing','compact'); names=["Airline" "AutoARIMA" "UC" "AR12（补充）"];
for panel=1:4
 ax=nexttile(t); metric='cumulative_sMAPE_percent'; unit='sMAPE（%）'; if panel>2, metric='cumulative_MASE'; unit='MASE'; end
 h=12; if mod(panel,2)==0, h=24; end
 vals=nan(4,4);
 for j=1:4
  name=C.config.names(j);
  protocols=["此前六模型扩展窗口" "本次滑动480照A" "滑动480首轮训练lambda"];
  for q=1:3
   row=V.model==name & V.protocol==protocols(q) & V.horizon==h;
   if any(row), vals(j,q)=V.(metric)(row); end
  end
  row=V.model==name & V.protocol=="本次滑动480照A" & V.horizon==h;
  field='paper_sMAPE_percent'; if panel>2, field='paper_MASE'; end
  vals(j,4)=V.(field)(row);
 end
 bar(ax,vals,'grouped'); set(ax,'XTickLabel',names,'FontName','Microsoft YaHei','FontSize',12,'Color','w','XColor','k','YColor','k');
 ylabel(ax,unit); title(ax,sprintf('前%d步累计平均',h),'Color','k'); grid(ax,'on');
 if panel==1
  lg=legend(ax,{'扩展窗口','照A滑动窗口','首轮训练固定lambda','论文'}, ...
   'NumColumns',4,'FontSize',11,'TextColor','k','Color','w');
  lg.Layout.Tile='south';
 end
end
title(t,'220轮预测协议比较：AR12为补充基准，论文无对应值','FontName','Microsoft YaHei','FontSize',18);
exportgraphics(f,fullfile(out,'comparison.png'),'Resolution',160);
% 中文说明同时保留A原始与六模型统一实验的可审阅年度汇总。
fid=fopen(fullfile(out,'experiment_summary.md'),'w','n','UTF-8'); cl2=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# 固定480个月滑动窗口实验\n\n');
fprintf(fid,'四模型主实验均完成220轮，每轮24步，共21120条预测。另有Airline、UC的首轮训练固定lambda补充实验，各220轮，不混入主实验。\n\n');
fprintf(fid,'## 协议与前视信息\n\n');
fprintf(fid,'每轮训练CO2(r:r+479)，目标CO2(r+480:r+503)，起点1998-02至2016-05，目标1998-03至2018-05。模型结构和估计方法沿用B/C，不调整阶数。Airline外部变换后使用modelTF；UC使用modelUC(ty, [], ''LLT12'', 24)，二者均逆变换到ppm。AR12保持含截距OLS和递推。AutoARIMA使用modelAUTO(train,''s'',[1 12],''nofs'',24)，公开包装器默认boxcox=1，后端自动处理，直接取ppm预测，不重复变换或逆变换。加密后端无法逐行核查。\n\n');
fprintf(fid,'A脚本注释称0.2461来自初始480月，但A4实际在CO2(25:504)估计。按工具箱同一目标函数重算：CO2(1:480)得到%.12f；CO2(25:504)得到%.12f，后者四舍五入为0.2461。故照A主实验可能含前视信息，尤其前24轮参数来源包含其训练期之后的观测；不能称为完全无信息泄漏。补充实验将lambda固定为首轮训练估计的完整精度值，AutoARIMA与AR12无需重跑。\n\n',C.config.lambdaFirst,C.config.lambdaSingle);
fprintf(fid,'## 年度累计汇总\n\n单位：sMAPE为百分数；年度为前12、24步等权累计平均，绝非第12、24步点误差。差值为本实验减论文。AR12不是论文的自动AR，论文差值留空。\n\n');
fprintf(fid,'|模型|实验协议|1年sMAPE|2年sMAPE|1年MASE|2年MASE|与论文差异（s1/s2；M1/M2）|\n|---|---|---:|---:|---:|---:|---|\n');
for name=["ETS" "SeasonalNaive" "Airline" "AutoARIMA" "UC" "AR12"]
 protocols=unique(V.protocol(V.model==name),'stable');
 for p=protocols'
  W=sortrows(V(V.model==name & V.protocol==p & ismember(V.horizon,[12 24]),:),'horizon');
  delta=sprintf('%+.6f / %+.6f；%+.6f / %+.6f',W.delta_sMAPE(1),W.delta_sMAPE(2),W.delta_MASE(1),W.delta_MASE(2));
  if name=="AR12", delta='无论文对应模型'; end
  fprintf(fid,'|%s|%s|%.6f|%.6f|%.6f|%.6f|%s|\n',name,p,W.cumulative_sMAPE_percent(1),W.cumulative_sMAPE_percent(2),W.cumulative_MASE(1),W.cumulative_MASE(2),delta);
 end
end
fprintf(fid,'\n## 变化与论文接近程度\n\n');
for k=1:height(J)
 name=J.model(k); h=J.horizon(k); W=V(V.model==name & V.protocol=="本次滑动480照A" & V.horizon==h,:);
 oldDeltaS=abs(J.old_sMAPE(k)-W.paper_sMAPE_percent); newDeltaS=abs(J.new_sMAPE(k)-W.paper_sMAPE_percent);
 oldDeltaM=abs(J.old_MASE(k)-W.paper_MASE); newDeltaM=abs(J.new_MASE(k)-W.paper_MASE);
 fprintf(fid,'- %s 前%d步：sMAPE变化%+.6f，MASE变化%+.6f；MAE %.6f → %.6f ppm。固定旧预测换分母贡献%+.6f，再换预测贡献%+.6f。',name,h,J.new_sMAPE(k)-J.old_sMAPE(k),J.new_MASE(k)-J.old_MASE(k),J.old_MAE_ppm(k),J.new_MAE_ppm(k),J.denominator_contribution(k),J.prediction_contribution(k));
 if name~="AR12", fprintf(fid,'论文绝对差：sMAPE %.6f → %.6f；MASE %.6f → %.6f。',oldDeltaS,newDeltaS,oldDeltaM,newDeltaM); end
 fprintf(fid,'\n');
end
[~,k]=max(abs(J.new_sMAPE-J.old_sMAPE)); fprintf(fid,'\nsMAPE绝对变化最大：%s前%d步，变化%+.6f个百分点。',J.model(k),J.horizon(k),J.new_sMAPE(k)-J.old_sMAPE(k));
[~,k]=max(abs(J.new_MASE-J.old_MASE)); fprintf(fid,'MASE绝对变化最大：%s前%d步，变化%+.6f。\n\n',J.model(k),J.horizon(k),J.new_MASE(k)-J.old_MASE(k));
fprintf(fid,'两种指标方向是否一致：');
for k=1:height(J)
 if sign(J.new_sMAPE(k)-J.old_sMAPE(k))==sign(J.new_MASE(k)-J.old_MASE(k)), text='一致'; else, text='不一致'; end
 fprintf(fid,'%s前%d步%s；',J.model(k),J.horizon(k),text);
end
fprintf(fid,'\n\n');
fprintf(fid,'上述分解采用先分母后预测的明确路径，属于算术分解，不能当成唯一因果归因。Airline、UC同时改变窗口和lambda策略，需结合首轮固定lambda补充结果判断，不能把全部差异都归因于训练窗口。AutoARIMA、AR12仅改变训练窗口。季节朴素预测仅由末12月决定，原A与扩展窗口sMAPE相同，其MASE变化完全来自分母。\n\n');
fprintf(fid,'与论文比较不存在一个全面占优的协议。照A设置下，Airline的两种年度指标均更接近论文；AutoARIMA的1年两指标及2年MASE更接近，但2年sMAPE反而略远。UC的两年两指标均更远，一年则sMAPE更远、MASE更近。首轮训练固定lambda补充实验中，UC的四个年度指标均比旧扩展窗口及照A主实验更接近论文，但仍未复现论文值；Airline的1年指标更贴近论文，而2年指标由照A固定0.2461更近。\n\n');
fprintf(fid,'从误差分解看，Airline的MASE改善主要来自预测绝对误差下降；AutoARIMA及AR12的MASE改善主要来自分母变化。UC两年预测误差上升的贡献超过分母增大带来的下降，所以两年MASE仍恶化；UC一年及AR12两年都出现sMAPE上升而MASE下降，不能将MASE下降直接解释为预测改善。\n\n');
fprintf(fid,'季节朴素使用滑动480月分母后的年度MASE为1.381332、2.067852，与论文1.381、2.068按三位小数一致，支持论文可能采用固定训练长度的分母。模型数值更接近论文属于额外相容证据，不能唯一确定作者的拟合窗口、变换、初值、估计器或异常值处理；朴素法也不能验证lambda。未进行显著性检验。\n\n');
fprintf(fid,'## 版本、核验与复跑\n\nMATLAB：%s；ECOTOOL：%s。主实验拟合耗时%.3f秒；两模型补充耗时%.3f秒。参数、完整估计表、日志、实际输入、依赖路径和SHA256均在checkpoint.mat。UC包装器method可能显示EML，但实际位置调用后端的估计表应单独核对。核验PASS是数量、输入边界、数据尺度、导出一致性及公式正确性的检查，不证明加密优化器收敛。\n\n',C.env.matlab,strjoin(C.env.ecotool.Version,','),sum(C.seconds(:,1:4),'all'),sum(C.seconds(:,5:6),'all'));
for j=[1 2 3 5 6]
 methods=strings(0,1); flagged=0;
 for r=1:220
  meta=C.models{r,j}; lines=string(cellstr(meta.table));
  methods=[methods;strtrim(lines(contains(lines,'Estimation method:')))]; %#ok<AGROW>
  flagged=flagged+~isempty(regexpi(meta.log,'warning|maximum number|failed|not converge','once'));
 end
 suffix='照A'; if j>4, suffix='首轮训练lambda'; end
 fprintf(fid,'%s（%s）：估计表报告%s；日志含warning/maximum number/failed/not converge关键词的轮数%d。关键词筛查不能证明或否定收敛。\n\n',C.config.names(j),suffix,strjoin(unique(methods),'；'),flagged);
end
if isfield(C,'execution'), fprintf(fid,'本次%d进程续跑墙钟耗时%.3f秒（包括进程池启动，之前中断阶段另计）。\n\n',C.execution.workers,C.execution.wallSeconds); end
fprintf(fid,'原A来源固定提交f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6，原B接口固定提交9225da80af22d5bbb2ddf6d727cc9db51a82968c，旧六模型结果来自本分支4e67c33的results/comparison。论文值复用该已核对的Table 4转录；A文档中的部分论文列曾串列，本实验使用原始CSV与统一转录，不采信其串列说明。所有旧成果保持原样。\n\n');
fprintf(fid,'先完成3轮并独立核验PASS后续跑；为降低内存压力将4个工作进程改为2个。第87轮AutoARIMA的元胞返回字段触发元数据构造错误，改为标量结构逐字段保存后从检查点继续，未修改模型或估计设置。所有此前已保存预测及其耗时在续跑结束后逐值检查不变。运行时间字段为最后一次续跑的墙钟耗时，逐模型累计成功拟合时间另列，不能将其混称为全流程墙钟时间。\n\n');
fprintf(fid,'首次运行时已执行run_bc_sliding480(3)及audit_bc_sliding480(3)。已有完整检查点时，以下命令仅跳过已完成拟合并重建导出与核验，不需要删除检查点。\n\n```matlab\naddpath(''src'');\nrun_bc_sliding480(220,2);\nsummarize_bc_sliding480;\naudit_bc_sliding480(220);\n```\n\n![协议比较](comparison.png)\n');
disp(V(ismember(V.horizon,[12 24]),:));
end

function T=gitTable(root,sha,path)
% 使用固定Git对象只读，不切换或修改任何组员分支。
[code,txt]=system(sprintf('git -C "%s" show %s:%s',root,sha,path)); assert(code==0,'%s',txt);
p=[tempname '.csv']; f=fopen(p,'w','n','UTF-8'); assert(f>=0); fprintf(f,'%s',txt); fclose(f);
c=onCleanup(@()delete(p)); T=readtable(p,'TextType','string'); %#ok<NASGU>
end
