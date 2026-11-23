param()
$here=$PSScriptRoot
$rows=Import-Csv "$here/actual_ecotool_extensions.csv"
$out=foreach($g in ($rows | Group-Object Group,Model)){foreach($mode in @('one','four')){$z=@($g.Group | Where-Object {if($mode -eq 'one'){[int]$_.Horizon -eq 1 -and [int]$_.Origin -le 107}else{[int]$_.Origin -le 104 -and [int]$_.Horizon -gt 0}});if($z.Count -gt 0){$ae=0.0;$se=0.0;$sm=0.0;$mas=0.0;foreach($r in $z){$e=[double]$r.Forecast-[double]$r.Actual;$ae+=[Math]::Abs($e);$se+=$e*$e;$sm+=200*[Math]::Abs($e)/([Math]::Abs([double]$r.Forecast)+[Math]::Abs([double]$r.Actual));$mas+=[Math]::Abs($e)/[double]$r.Scale};[pscustomobject]@{Group=$z[0].Group;Model=$z[0].Model;Protocol=$mode;N=$z.Count;MAE=$ae/$z.Count;RMSE=[Math]::Sqrt($se/$z.Count);sMAPE=$sm/$z.Count;MASE=$mas/$z.Count}}}}
$out | Export-Csv "$here/extension_metrics.csv" -NoTypeInformation -Encoding utf8
function MarkdownTable($file,$columns){
 $r=Import-Csv (Join-Path $here $file)
 '| '+($columns -join ' | ')+' |'
 '| '+(($columns | ForEach-Object {'---'}) -join ' | ')+' |'
 foreach($x in $r){$v=foreach($c in $columns){$s=[string]$x.$c;$d=0.0;if([double]::TryParse($s,[ref]$d)){'{0:0.####}' -f $d}else{$s}};'| '+($v -join ' | ')+' |'}
}
$selected=(Import-Csv "$here/selection.csv" | Select-Object -First 1).Model
$text=@"
# C组个人周消费UC全面诊断与重建报告

实验日期：2026-11-23。仅C组，MATLAB R2026a实际运行。代码、原始输出、数据指纹、日志均在本目录；没有使用Python。独立分支codex/uc-rebuild-c，原output与A/B结果未改写，原先两项删除保持原状。

## 核心结论

RW固定原点多步条件均值恒定，由随机游走结构直接决定；更换优化器也不会使同一原点的RW四步均值波动。原尺度ECOTOOL估计还存在严重尺度依赖：原RW的q=0.008347、R=32.49945，标准化创新方差14786.15、均值28.53，平均水平增益0.03973；不能信赖这些数值作为校准的金额方差和区间。标准化重估逆变换后q=2760.91、R=457192.08，创新方差0.9990，平均增益0.08539，首步预测1189.995元，明显不同于旧868.503元。LLT也从标准化创新方差6676.47变为0.9813。独立MATLAB原生ssm标量RW估得q/R约0.00748，与标准化ECOTOOL约0.00604处于同一量级，而旧值只有0.000257。

这支持“结构决定平线，加上原尺度数值估计不可靠”的双重定位。旧创新及日期映射可重建一致，旧点预测回测可复现；但旧参数绝对尺度、标准误、条件预测标准差及其推断不可信。白噪声检验通过并不能修复尺度校准。无法读取modelUC0.p内部优化，因此不将黑箱具体故障归因于某一行源码。

按预先记录的训练内综合MAE规则，主实验第一名为 **$selected**。完整比较如下，最终是否推荐还结合可靠性与简单性判断；不能把回测胜者称为已证明的真实机制。

## 数据与统计证据

112个完整自然周、前108训练。训练日期2024-09-02至2026-09-21，末4周为2026-09-28至2026-10-19起始自然周。训练连续7天、无重复、无NaN/Inf、无负金额。均值789.29元，中位数582.68元，标准差713.55元，偏度4.034、峰度25.194，最大5795.96元，明显重尾。训练IQR上限1450.13元。9个大额周的既有明细核查记录保留在outlier_source.csv；不是自动录入错误，真实金额仍参与全部评分。无逐笔业务标签，不能断言某次消费的用途、春节机制或支付日期规律。

ADF带截距、无确定性趋势，0:8阶以共同样本BIC选阶（本次均选0）；原假设单位根。KPSS原假设常数水平平稳、带宽4/8。ADF均拒绝单位根，而KPSS均拒绝水平平稳，提示水平变化、短期依赖、异常和检验有限样本性质不能被单一标签概括。p值表端点属于MATLAB临界值插值截断，不是精确尾概率。不拒绝从不等于证明。

$(MarkdownTable 'stationarity.csv' @('Data','Test','Lag','Statistic','P','Reject') | Out-String)

## 参数估计核验

modelUC可读包装器的method默认字段为EML，但四位置调用底层默认实际输出CONDITIONAL SUM OF SQUARES（CML），证据见ecotool_table_RW.txt和LLT对应文件。auxmodelUC用10.^par构造Q/R，covpar在log10 score尺度。SSestimET可读部分调用fminunc，仅接收参数和目标值，没有返回exitflag；clliket以创新和预测方差的数值导数构建近似协方差。它与黑箱CML优化内部目标是否一致无法完整审查。初始化P0=10^5 I、首状态为首观测、前2期舍弃。

原始score整体加2/4后，独立高斯负对数似然从RW的819692降为8722/854，但RMSE仍约716.9元；这直接表明预测误差近似相同不意味着方差尺度正确。对应表common_scale_profile.csv。逐期重建与工具箱创新最大误差RW约2.3e-13元，LLT约2.6e-11元，确认创新对应第3至108周。ECOTOOL三个输入初值的输出完全相同；这不足以证明黑箱真正接受了不同初值，仅能报告接口调用结果。独立实现保留两初值优化轨迹和退出状态，不把方差score的普通t检验当作非零证据。

原生ssm重复标量RW交叉核验见native_scalar_rw.txt；两状态LLT出现近边界及协方差求逆困难警告，不能把该估计的标准误解释为可靠推断。它采用全样本高斯目标且初始化不同，AIC不能与条件目标混排。

## 模型、公式与估计

完整观测方程、转移方程、参数、Kalman滤波/平滑、条件似然、指标和限制写在同目录《方法与复现.md》，构成本报告的方法部分。保留EC_RW/EC_LLT为正式旧基线；ML_为标准化独立高斯条件似然；W_为每窗口IQR缩尾；Log_RW用log1p且作近似正态均值回变换；Q_为预先给定方差比约束；S4_/WS4_为固定谐波两阶段对照，实际随机季节RW4/LLT4另表记录。估参方法并未默默替换为Python或另一工具箱。

原生模型和条件似然的不同初始化、log变换雅可比缺失、缩尾响应改变及季节两阶段拟合使某些AIC不直接可比。下表AIC/BIC仅供相近ML结构内部参考，不依据跨变换最小值选模。

$(MarkdownTable 'diagnostics.csv' @('Model','ZMean','ZVariance','LB6P','LB13P','LB26P','AIC','BIC') | Out-String)

## 季节与稳健性

原始4周ACF0.0942，缩尾后0.2596，log1p后0.2572。但4周固定谐波p值分别0.738、0.647、0.649；13/26/52周也无通过保守多重检验门槛的证据，故不盲目拓展大量周期。缩尾后前几阶相关共同抬升，周期图较长周期峰也可能是水平变化，而不是稳定四周季节。仅约两年度的数据无法可靠排除所有年度效应。

$(MarkdownTable 'season_evidence.csv' @('Data','Period','ACF','HarmonicF','ExploratoryP') | Out-String)

实际ECOTOOL随机周期4及趋势扩展回测：

$(MarkdownTable 'extension_metrics.csv' @('Group','Model','Protocol','N','MAE','RMSE') | Out-String)

旧RW4一步MAE631.66、LLT4为1131.69元；缩尾RW4仍593.24、LLT4仍735.70，不能支持季节模型改善。失败与缺少稳定周期证据、随机季节状态增加估计负担、异常扰动及原尺度数值问题相一致；这不是已识别的单一因果机制。大额周没有掩盖出一个经验证可靠的4/13/26/52周周期。

## 样本外比较与选择

30折一步和27原点四步完整同目标评分。每窗口重新处理；最后4周不用于选择。主实验综合得分是两协议MAE各除历史均值MAE后平均，RMSE破平；复杂度、收敛、诊断须作为推荐复核。季节证据弱，相关模型只作对照。多原点预测窗口重叠、候选比较带来选择偏差，未作独立外部盲测，细小差距不宜夸大。

$(MarkdownTable 'metrics.csv' @('Model','Protocol','N','MAE','RMSE','sMAPE','MASE') | Out-String)

## 历史保留集复评

先保存locked.mat，再读取真实末4周。虽然本次保持了此顺序，历史上这些金额已经见过，所以不是全新盲测；仅4周也无法稳定识别赢家。

$(MarkdownTable 'holdout_metrics.csv' @('Model','MAE','RMSE','sMAPE','MASE') | Out-String)

## 图表阅读与无法解决的问题

01_data为原始/缩尾/log时序和分布；02_dependence为ACF/PACF及周期图。diagnostic_ML_RW/ML_LLT区分训练期估参的一步拟合、过滤、利用全部训练未来的平滑、平滑不规则成分、Kalman增益及标准化创新分布。08_rolling才是严格窗口外一步；09_four_origin比较27原点四步损失；10_holdout为选定模型固定原点4步。平滑状态绝不当未来预测。

极端消费无法从仅周总额可靠预知。增加Q使增益变大、追随突发事件更快，也可能把一次性支出持久化；是否有益只能读Q_回测各指标，不能凭波动曲线。训练108周不足以牢固估计多种趋势/季节状态；方差近边界、重尾、潜在均值改变仍限制高斯UC解释和区间。没有证明未来改善，也没有获得可信消费因果解释。

作者及模型定义来源：[Time series analysis and forecasting with ECOTOOL](https://pmc.ncbi.nlm.nih.gov/articles/PMC6822939/)；实际接口以本机审计快照为准。
"@
$text | Set-Content -Encoding utf8 "$here/技术报告.md"

Get-Content -Raw "$here/结论复核.md" | Add-Content -Encoding utf8 "$here/技术报告.md"
