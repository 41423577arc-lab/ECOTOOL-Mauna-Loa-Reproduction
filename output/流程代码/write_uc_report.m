function write_uc_report(projectRoot)
out=fullfile(projectRoot,'output');
c=load(fullfile(out,'新旧比较.mat'));
f=fopen(fullfile(out,'新旧结果对比说明.md'),'w','n','UTF-8');
clean=onCleanup(@() fclose(f));
fprintf(f,'# 三人总支付 UC 分析及新旧结果对比\n\n');
fprintf(f,'本次运行 MATLAB %s，使用原 ECOTOOL。三人分别从 data 中读取总支付，均重新估计，不复用旧模型。\n\n',version);
fprintf(f,'训练为 2024-09-02 至 2026-09-27 的 108 个完整自然周。滚动验证以 78 周为初始窗口，逐周扩展，验证 30 周；固定原点测试覆盖 2026-09-28 至 2026-10-25 的 4 周。预测先锁定再读取测试金额。测试数据此前已经观察过，本次属于历史复现，不能视为新的前瞻验证。\n\n');
fprintf(f,'UC 候选为 RW、LLT，基准为朴素及三期移动平均。若只有一个 UC 模型通过残差 3、6 阶 Ljung–Box 检验则选它；否则按滚动 MAE、RMSE 排序。基准不参与 UC 内部选模，但单独报告其预测表现。\n\n');
fprintf(f,'## 三人结果\n\n| 人员 | 选定UC | 四模型最低MAE | UC滚动MAE | UC滚动RMSE | 测试MAE | 测试预测合计 | 测试真实合计 |\n| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |\n');
for i=1:height(c.summary)
 s=c.summary(i,:);
 fprintf(f,'| %s | %s | %s | %.6f | %.6f | %.6f | %.6f | %.2f |\n',s.Person,s.SelectedUC,s.LowestMAEAllModels,s.RollingMAE,s.RollingRMSE,s.TestMAE,s.ForecastSum,s.ActualSum);
end
fprintf(f,'\n金额单位为元，误差为每周误差；上述合计覆盖保留的四个完整周，并非完整十月金额。各人的源账单清洗口径沿用原数据，参见根目录 README。\n\n');
fprintf(f,'## 与旧 C 结果的关系\n\n');
if c.reproduced
 fprintf(f,'**新 C 自然周结果复现成功。** 输入的 108 周训练金额与 4 周测试金额逐项完全一致；12 张结果表共 %d 个列项目全部通过核对。数值容差为 1e-6 + 1e-8 × 该列旧结果最大绝对值，非数值字段按精确匹配检查。\n\n',height(c.checks));
elseif c.coreReproduced
 fprintf(f,'**新 C 的主要分析数值和结论与旧自然周一致，但稳定性日志不同。** 输入的 108 周训练金额和 4 周测试金额完全一致；12 张结果表中除“UC滚动估计稳定性.csv”外的 11 张表，所有列均通过核对。数值容差为 1e-6 + 1e-8 × 该列旧结果最大绝对值，非数值字段按精确匹配检查。\n\n');
 fprintf(f,'旧稳定性日志在 60 次总支付 UC 滚动估计中有 %d 条“数组索引必须为正整数或逻辑值”记录，相应 MaxScoreSE 为 NaN；本次异常记录为 %d 条，标准误记录完整。旧表中这些周期的 Forecast 仍为有限值，且逐期与本次一致；旧实现先赋预测再计算后续诊断，异常记录不能等同于预测缺失。仅凭旧日志不能定位其历史运行时的具体错误点，本次不修改旧结果或抹去差异。因此不能声称所有输出完全相同。差异见“旧稳定性日志差异.csv”和“C新旧数值逐项核对.csv”。\n\n',c.stabilityDifference.LoggedFailureRows(1),c.stabilityDifference.LoggedFailureRows(2));
else
 fprintf(f,'**新 C 与旧自然周结果存在差异。** 共有 %d 个列项目未通过核对，见 C新旧数值逐项核对.csv，不能声称完全复现。\n\n',sum(~c.checks.Match));
end
fprintf(f,'核对内容包含样本内拟合、模型方差参数、残差自相关与分布、异常候选、滚动预测的每期数值和稳定性记录、异常月份敏感性、最终参数、四周预测及测试汇总。\n\n');
fprintf(f,'| 新人员 | 旧基线 | 新UC | 旧UC | 选模一致 | RW残差结论一致 | LLT残差结论一致 |\n| --- | --- | --- | --- | --- | --- | --- |\n');
for i=1:height(c.conclusion)
 s=c.conclusion(i,:);
 fprintf(f,'| %s | %s | %s | %s | %s | %s | %s |\n',s.Person,s.Baseline,s.NewSelectedUC,s.OldSelectedUC,yesno(s.SameSelection),yesno(s.SameRWConclusion),yesno(s.SameLLTConclusion));
end
fprintf(f,'\n“残差结论一致”指两个固定滞后阶数均未拒绝零自相关的判断是否相同，不表示已经证明残差独立或模型正确。详细 p 值见各人诊断表。\n\n');
fprintf(f,'旧月度总支付选 LLT，旧自然周与连续七天总支付选 RW。与月度结论不同本身不能判为复现失败，因为聚合边界、样本量、验证期及部分选模规则不同。B、A 与旧 C 属于不同文件/人员，金额及模型表现也无需相同；仅 C 自然周具备同数据同流程的直接数值复现条件。\n\n');
fprintf(f,'## 旧整月预测为何不能与本次四周合计直接相比\n\n');
old=projectRoot+"_整理前备份_20261123";
reference=readtable(fullfile(old,'output','三种频率十月累计预测比较.csv'),'TextType','string');
writetable(reference,fullfile(out,'旧三频率整月预测参考.csv'),'Encoding','UTF-8');
fprintf(f,'旧整合结果使用整月预测：月度 LLT 为 %.6f 元，自然周 RW 按天均匀分摊为 %.6f 元，连续七天 RW 按天均匀分摊为 %.6f 元，参照十月实际 %.2f 元。自然周整月方案需预测含 10-26 至 11-01 在内的 5 周，再分摊到十月；本次沿用原自然周六步流程，只评价已有真实数据的 4 个完整保留周。因此新 C 的四周合计应与旧自然周 UC独立测试汇总.csv 对照，不能与整月日分摊金额直接要求一致。\n\n',reference.Forecast(1),reference.Forecast(2),reference.Forecast(3),reference.OctoberActual(1));
fprintf(f,'## 文件与运行\n\n');
fprintf(f,'- B/、A/、C/：各人的六步分析结果、PNG/FIG、CSV/MAT、运行日志及个人结论。\n');
fprintf(f,'- 三人UC结果汇总.csv、与旧结果结论对照.csv：跨人及旧三频率结论对照。\n');
fprintf(f,'- C输入逐项核对.csv、C新旧数值逐项核对.csv：同口径复现证据。\n');
fprintf(f,'- 流程代码/：只包含总支付分析；运行口径.json 记录输入及旧源代码校验值。根目录 run_all_uc.m 为入口。\n\n');
fprintf(f,'原生预测方差的尺度及多步尾部误差未重新校准，沿用旧流程不发布预测区间；不把异常残差候选当作删数据依据，不用测试误差重新选模。\n');
for person=["A","B","C"]
 write_person(fullfile(out,person),person);
end
end

function write_person(p,person)
r=load(fullfile(p,'step05_rolling.mat'));
d=load(fullfile(p,'step04_UC_diagnostics.mat'));
e=load(fullfile(p,'step06_evaluation.mat'));
q=load(fullfile(p,'step02_stationarity.mat'));
f=fopen(fullfile(p,'分析结论.md'),'w','n','UTF-8');
clean=onCleanup(@() fclose(f));
fprintf(f,'# %s 个人总支付自然周 UC 分析\n\n',person);
fprintf(f,'按原自然周流程选定 **%s**；训练 108 周，滚动验证 30 周，固定原点测试 4 周。金额单位：元。\n\n',r.selected(1));
fprintf(f,'## 原始序列检验\n\n| 检验 | 滞后 | p值 | 拒绝原假设 |\n| --- | ---: | ---: | --- |\n');
for i=1:height(q.lb),fprintf(f,'| Ljung–Box（零自相关） | %d | %.8g | %s |\n',q.lb.Lag(i),q.lb.PValue(i),yesno(q.lb.RejectH0(i)));end
for i=1:height(q.adf),fprintf(f,'| ADF（单位根） | %d | %.8g | %s |\n',q.adf.Lag(i),q.adf.PValue(i),yesno(q.adf.RejectUnitRoot(i)));end
fprintf(f,'\nADF 拒绝单位根与 Ljung–Box 是否检出自相关是不同问题，不能相互替代；未拒绝某原假设不构成其成立的证明。\n\n');
fprintf(f,'## 滚动验证\n\n| 模型 | MAE | RMSE | sMAPE（%%） | MASE |\n| --- | ---: | ---: | ---: | ---: |\n');
for i=1:height(r.summary),s=r.summary(i,:);fprintf(f,'| %s | %.6f | %.6f | %.6f | %.6f |\n',s.Model,s.MAE,s.RMSE,s.sMAPE,s.MASE);end
best=sortrows(r.summary,{'MAE','RMSE'});
fprintf(f,'\n四模型中滚动 MAE 最低为 %s。UC 选模仅在 RW/LLT 中进行；即使基准更好也如实保留其结果。\n\n',best.Model(1));
fprintf(f,'## 残差诊断\n\n| 模型 | 滞后 | p值 | 检出自相关 |\n| --- | ---: | ---: | --- |\n');
for i=1:height(d.diagnosticSummary),s=d.diagnosticSummary(i,:);fprintf(f,'| %s | %d | %.8g | %s |\n',s.Model,s.Lag,s.PValue,yesno(s.RejectH0));end
fprintf(f,'\n使用初始化期后 106 个残差、显著性水平 0.05。检验为渐近近似，未拒绝不代表模型完全正确；异常候选仅作探索，不删除观测。\n\n');
fprintf(f,'## 独立保留周期的固定原点预测\n\n| 周起始日 | 预测 | 实际 | 预测减实际 |\n| --- | ---: | ---: | ---: |\n');
for i=1:height(e.evaluation),s=e.evaluation(i,:);fprintf(f,'| %s | %.6f | %.2f | %.6f |\n',string(s.PeriodStart,'yyyy-MM-dd'),s.Forecast,s.Actual,s.Error);end
s=e.aggregate(1,:);
fprintf(f,'\n测试每周 MAE %.6f，RMSE %.6f；四周预测合计 %.6f，实际合计 %.2f。覆盖 2026-09-28 至 2026-10-25，不能当作十月整月金额。\n\n',s.MAE,s.RMSE,s.ForecastSum,s.ActualSum);
fprintf(f,'滚动阶段共 %d 次 UC 估计的标准误或参数越界启发式标记，实际记录到的估计失败 %d 次；该标记不等同于收敛失败，详见稳定性 CSV。\n\n',sum(r.stability.UnstableFlag & ismember(r.stability.Model,["RW","LLT"])),sum(strlength(r.stability.Failure)>0));
fprintf(f,'## 一月异常月份的敏感性描述\n\n| 模型 | 一月误差平方占比 | 排除一月后的MAE | 排除一月后的RMSE |\n| --- | ---: | ---: | ---: |\n');
for i=1:height(r.sensitivity),s=r.sensitivity(i,:);fprintf(f,'| %s | %.4f%% | %.6f | %.6f |\n',s.Model,100*s.JanuarySSEShare,s.MAE_WithoutJanuary,s.RMSE_WithoutJanuary);end
fprintf(f,'\n滚动验证自 2026-03-02 开始，不包含一月，所以一月误差占比的 0 是空子集结果，排除一月后的指标自然等于原指标；这不能说明一月大额事件对模型估计没有影响。此处保留旧流程计算以便复现，不改变正式训练数据或选模结果。完整参数和成分分解见同目录 CSV、MAT 和图形。不发布尚未校准的预测区间。\n');
end

function t=yesno(value)
if value,t="是";else,t="否";end
end