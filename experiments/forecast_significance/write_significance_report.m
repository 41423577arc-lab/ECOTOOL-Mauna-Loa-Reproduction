function write_significance_report(T,HS,BS,cfg,out)
% 由已计算表格生成中文报告，所有结论随数据计算，不预设显著结果。
lines=strings(0,1);
add('# 预测性能显著性检验报告');add('2026年11月23日｜A、B、C｜已有27原点四步预测的统计推断');
add('## 1. 主要结论');
positive=T.('Holm校正显著')&T.('平均损失差')>0;
negative=T.('Holm校正显著')&T.('平均损失差')<0;
add(sprintf('九组预先指定比较中，Holm校正后模型2显著更优%d组、模型1显著更优%d组，其余%d组未达到0.05显著性水平。UC相对基准的显著优势为%d/6组，缩尾相对原选UC的显著改善为%d/3组。主判断固定使用HAC滞后3的双侧渐近正态p值及九组Holm校正。',sum(positive),sum(negative),sum(~T.('Holm校正显著')),sum(positive(1:6)),sum(positive(7:9))));
if any(positive),add('达到校正后显著改善的比较：'+strjoin(labels(T(positive,:)),'；')+'。');
else,add('本轮没有任何比较可表述为“经Holm校正后存在统计显著的模型2预测优势”。');end
numericOnly=T.('平均损失差')>0&~T.('Holm校正显著');
if any(numericOnly),add('仅有MAE数值改善、未达到校正后显著：'+strjoin(labels(T(numericOnly,:)),'；')+'。');end
if any(negative),add('达到校正后显著变差的比较：'+strjoin(labels(T(negative,:)),'；')+'。');end
unadjusted=T.('原始显著')&~T.('Holm校正显著');
add(sprintf('未经校正时显著%d组，其中%d组在Holm校正后不再显著。普通Bootstrap百分位95%%区间有%d组排除0；这不是经过九组多重校正的置信区间，不能替代主检验。',sum(T.('原始显著')),sum(unadjusted),sum(T.('Bootstrap区间排除零'))));
agree=zeros(9,1);lagRaw=false(9,1);lagHolm=false(9,1);blockSensitive=false(9,1);
for i=1:9
 rawDirection=sign(T.('平均损失差')(i))*double(T.('原始显著')(i));
 bootDirection=double(T.('Bootstrap区间下限')(i)>0)-double(T.('Bootstrap区间上限')(i)<0);
 agree(i)=rawDirection==bootDirection;
 h=HS(HS.('比较编号')==i,:);b=BS(BS.('比较编号')==i,:);
 lagRaw(i)=numel(unique(h.('原始显著')))>1;lagHolm(i)=numel(unique(h.('Holm校正显著')))>1;
 directions=double(b.('区间下限')>0)-double(b.('区间上限')<0);blockSensitive(i)=numel(unique(directions))>1;
end
add(sprintf('在可比较的未校正0.05层面，主HAC与主Bootstrap的方向/是否排除0分类一致%d/9组。改变预定HAC滞后2、3、4、6时，原始显著性分类改变%d组、Holm分类改变%d组；区块长度3、4、5的区间方向或是否包含0分类改变%d组。不同方法给出的证据须分别解读，不能将Bootstrap区间当成HAC的p值。',sum(agree),sum(lagRaw),sum(lagHolm),sum(blockSensitive)));
if any(~agree)
 add('主HAC与主Bootstrap分类不一致：'+strjoin(labels(T(~logical(agree),:)),'；')+'；应保留这种差异，谨慎解释。');
 for i=find(~logical(agree))'
  b=BS(BS.('比较编号')==i&BS.('区块长度')==4,:);
  add(sprintf('比较%d：HAC原始p=%.5f；Bootstrap区间[%.2f, %.2f]，原始均值%.2f元、重采样均值%.2f元。重采样分布的偏斜及非环绕端点权重差异可能影响区间，不能仅根据排除0升级为经Holm校正的显著结论。',i,T.('原始p值')(i),b.('区间下限'),b.('区间上限'),T.('平均损失差')(i),b.('Bootstrap均值')));
 end
end
add('本次是选择后探索性比较，不能把校正后的p值解释为已消除模型选择偏差。所有推断仍依赖短序列的近似条件；本实验不据此改写A用LLT、B/C用RW的正式选择，也不统一采用缩尾。');
add('## 2. 九组预测损失差异检验结果');
add('损失差=对照绝对误差−比较方法绝对误差；正值支持模型2。MAE、损失差、标准误及区间单位为元。统计量是渐近z统计量，不是带26自由度的普通t统计量。改善率=100×(对照MAE−比较MAE)/对照MAE。');
add('| 编号 | 成员 | 对照模型 | 比较模型 | 对照MAE | 比较MAE | 改善率% | 平均损失差 | HAC标准误 | z | 原始p | Holm p | 原始显著 | Holm显著 | MBB 95%区间 | 结论 |');
add('|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|');
for i=1:9
 r=T(i,:);add(sprintf('| %d | %s | %s | %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.3f | %.5f | %.5f | %s | %s | [%.2f, %.2f] | %s |', ...
 r.('比较编号'),r.('成员'),r.('对照模型'),r.('比较模型'),r.('对照MAE'),r.('比较MAE'),r.('MAE改善率百分比'),r.('平均损失差'),r.('HAC标准误'),r.('检验统计量'),r.('原始p值'),r.('Holm校正p值'),yesNo(r.('原始显著')),yesNo(r.('Holm校正显著')),r.('Bootstrap区间下限'),r.('Bootstrap区间上限'),r.('显著性结论')));
end
add('![预测损失差置信区间](预测损失差置信区间.png)');
add('图中点为平均损失差，实线为区块长度4的Bootstrap百分位区间，灰色虚线为HAC滞后3的渐近正态区间；两种区间均未作多重比较校正，显著性主结论查上表Holm列。');
add('## 3. 分成员分析');
for person=["A","B","C"]
 add('### 成员'+person);
 ix=find(T.('成员')==person);
 for i=ix'
  r=T(i,:);direction="下降";if r.('平均损失差')<0,direction="上升";end
  add(sprintf('%s相对%s，MAE%s%.2f元（改善率%.2f%%），Holm p=%.5f，%s；主Bootstrap区间[%.2f, %.2f]，%s。', ...
   r.('比较模型'),r.('对照模型'),direction,abs(r.('平均损失差')),r.('MAE改善率百分比'),r.('Holm校正p值'),r.('显著性结论'), ...
   r.('Bootstrap区间下限'),r.('Bootstrap区间上限'),intervalDescription(r.('Bootstrap区间下限'),r.('Bootstrap区间上限'))));
 end
 k=ix(ix<=6);count=sum(positive(k));
 if count==2
  add('相对两个简单基准均出现校正后统计优势，可作为该UC历史表现的探索性支持；仍需新数据检验推广性。');
 elseif count==1
  add('只对一个简单基准出现校正后统计优势，应逐个基准表述，不推广成全面优于简单方法。');
 else
  add('相对两个简单基准均未获得Holm校正后显著优势；可以报告MAE变化，但不能声称已证实该UC更准确，也不能据此证明方法等效。');
 end
end
add('## 4. 预先固定参数的稳健性检查');
add('### HAC滞后2、3、4、6');
add('每个滞后均对相同九组比较单独计算Holm校正，仅作敏感性描述，不将四组滞后结果当作额外四套主要结论，也不挑选最小p值。下表完整列原始p值及四种滞后的Holm显著性。');
add('| 编号 | 滞后2原始p | 滞后3原始p（主） | 滞后4原始p | 滞后6原始p | Holm显著：2/3/4/6 | 原始分类对滞后敏感 | Holm分类对滞后敏感 |');
add('|---|---:|---:|---:|---:|---|---|---|');
for i=1:9
 h=sortrows(HS(HS.('比较编号')==i,:),'HAC滞后');p=h.('原始p值');sig=join(string(h.('Holm校正显著'))','/');
 add(sprintf('| %d | %.5f | %.5f | %.5f | %.5f | %s | %s | %s |',i,p(1),p(2),p(3),p(4),sig,yesNo(lagRaw(i)),yesNo(lagHolm(i))));
end
add('### Moving Block Bootstrap区块长度3、4、5');
add('| 编号 | 长度3的95%区间 | 长度4的95%区间（主） | 长度5的95%区间 | 区间分类对长度敏感 |');
add('|---|---|---|---|---|');
for i=1:9
 b=sortrows(BS(BS.('比较编号')==i,:),'区块长度');lo=b.('区间下限');hi=b.('区间上限');
 add(sprintf('| %d | [%.2f, %.2f] | [%.2f, %.2f] | [%.2f, %.2f] | %s |',i,lo(1),hi(1),lo(2),hi(2),lo(3),hi(3),yesNo(blockSensitive(i))));
end
add('## 5. 方法说明与局限');
add('### 配对、统计对象和信息边界');
add('每组按成员、原点、步长和目标周一一配对，定义d(o,h)=|e1(o,h)|−|e2(o,h)|。每个原点先将四步损失差等权取平均，再用按时间排序的27个原点级均值推断。原点为78至104、目标为79至108，均在原108周训练期内部；未使用第109至112周的保留测试数据参与统计。每组108条逐项差值只是核验记录，不能作为108个独立样本。');
add('输入核验涵盖缺失/非有限值、重复键、完整27×4覆盖、目标索引/日期、同目标实际金额一致、两实验原始UC预测一致、MAE复算与既有结果表一致。该流程只读CSV/既有核验JSON，不重训模型，不调用ECOTOOL，不复制既有预测值或实际金额到新明细。');
add('### HAC/Newey–West：固定截断与渐近近似');
add('令u(o)=d̄(o)−mean(d̄)，γ̂(k)=Σ[o=k+1…N]u(o)u(o−k)/N，N=27。长期方差估计为Ω̂=γ̂(0)+2Σ[k=1…L](1−k/(L+1))γ̂(k)，主L=3；SE=sqrt(Ω̂/N)，z=mean(d̄)/SE，双侧p=2Φ(−|z|)。使用Bartlett权重，不作N/(N−1)自由度修正，不使用普通独立样本t检验，也不宣称这是小样本精确分布。公式按[1]的Newey–West框架自行透明实现。');
add('该正态近似通常需要损失差的稳定均值、适当矩条件和弱依赖等条件。异方差与短程自相关由HAC处理，但固定滞后3不保证涵盖所有依赖：扩展窗口共同训练史、四步预测窗口重叠、大额消费冲击或结构变化可能造成更长或不稳定的依赖。一般HAC一致性还涉及随样本增长的截断选择；本次固定小样本截断是预定近似，不能保证稳健标准误充分。仅27个原点，无法充分验证这些条件，检验功效可能不足；滞后2、4、6结果用于暴露敏感性，而非优化显著性。');
add('### 非环绕重叠移动区块Bootstrap');
add(sprintf('对27个按时间排序的原点级损失差，构造N−b+1个长度b的重叠块，等概率有放回抽取ceil(N/b)块、依次拼接并截取前27点，不首尾环绕。每块包含连续原点；每个原点始终带着其四步配对均值，绝不拆分四个步长。主b=4，另固定b=3、5，均重复%d次；随机数为MATLAB twister，种子=20261123+1000×比较编号+b，运行后恢复调用前RNG状态。采用重采样均值分布的2.5%%和97.5%%百分位区间（MATLAB prctile默认插值），不作学生化、BCa或端点偏差校正，不输出Bootstrap p值。[2]',cfg.bootstrap_repetitions));
add('该Bootstrap依赖足够稳定的时间过程和区块能够描述主要依赖；27点只提供少量有效区块，置信区间覆盖率并无有限样本保证。非环绕方案对边缘原点的抽样权重不完全相等，Bootstrap均值可能偏离原始均值，已在区块长度敏感性CSV保留。区间排除0是补充证据，普通95%区间不自动具有九组同时覆盖率；HAC p值、Holm校正和Bootstrap区间不是同一种检验。');
add('### 多重比较、模型选择与结论边界');
add('九组主检验整体构成一个检验家族，不将六组基准比较与三组缩尾比较分开校正。原始p值升序排列后，Holm调整p为min[1,max(j≤i){(9−j+1)p(j)}]，再还原原顺序；原始与调整p均完整保留。[3] Holm能够处理检验间依赖，但不能修复原始p值近似失真或消除选择偏差。');
add('原正式UC此前根据部分相同历史数据选定，本轮属于探索性的选择后比较，并非独立预注册验证；报告中的“预先指定”只表示本次推断未再挑选九组以外的比较。最后4周保留测试数据已在此前研究中被观察，不属于全新盲测，本实验也没有使用这4周数据来作显著性计算。');
add('未拒绝预测损失相等的原假设，不代表证明两个模型一样好。统计显著不自动代表改善幅度具有实际意义，应同时读元尺度损失差、改善率、区间宽度和跨原点稳定性。残差通过Ljung–Box检验只关乎指定残差自相关诊断，不能当作预测精度差异显著的依据。双侧检验显著时仍须看损失差方向，不能将显著变差写成显著改善。');
add('### 资料与可复现性');
add('- [1] [MathWorks：HAC/Newey–West及Bartlett核说明](https://www.mathworks.com/help/econ/hac.html)。本项目明确采用上述有限滞后、1/N自协方差公式，避免依赖工具默认带宽或缩放。');
add('- [2] [R boot官方文档：时间序列固定长度区块重采样](https://stat.ethz.ch/R-manual/R-devel/library/boot/html/tsboot.html)。本项目实现和端点方案以上述段落为准，并未调用R。');
add('- [3] [R stats官方文档：Holm多重检验校正](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html)。');
add('- 输入只读`../multi_origin_4step/results/多原点四步预测明细.csv`与`../outlier_sensitivity/results/多原点四步预测明细.csv`及两实验的指标/核验表；CSV相对路径以本实验目录为基准。原始预测仍在原位置。');
add('- 新输出：`预测损失差异检验.csv`（9组主结果）、`原点级预测损失差.csv`（243条）、`不同预测步长损失差.csv`（972条）、`HAC滞后稳健性.csv`、`区块长度敏感性.csv`及`统计检验完整结果.mat`。MAT只存派生统计量、损失记录、Bootstrap均值和配置，不重复保存预测明细。');
add('- 根目录运行`addpath(fullfile(pwd,''experiments'',''forecast_significance'')); run_forecast_significance`。独立核验为`verify_significance`：重新配对并通过矩阵二次型核验HAC，独立复算Holm及区块抽样/百分位数，核对输入SHA256、图表引用和方法限制。全部通过后写入`实验核验.json`。');
fid=fopen(fullfile(out,'预测性能显著性检验报告.md'),'w','n','UTF-8');assert(fid>=0);done=onCleanup(@() fclose(fid));
nl=string(newline);body=strjoin(lines,nl+nl);
body=replace(body,"|"+newline+newline+"|","|"+newline+"|");
fprintf(fid,'%s\n',body);

 function add(value),lines(end+1,1)=string(value);end
end

function value=yesNo(flag)
value="否";if flag,value="是";end
end

function value=intervalDescription(lo,hi)
if lo>0,value="区间完全为正";elseif hi<0,value="区间完全为负";else,value="区间包含0";end
end

function value=labels(T)
value=string(T.('比较编号'))+"（"+T.('成员')+"："+T.('对照模型')+"→"+T.('比较模型')+"）";
end
