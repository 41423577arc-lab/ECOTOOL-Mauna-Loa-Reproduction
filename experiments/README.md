# UC补充实验

实验只写入各自的`results`，保留根目录`data`和`output`现有内容。成员A、B、C及建模口径沿用正式分析。

## MATLAB运行

在项目根目录执行：

```matlab
addpath('experiments');
run_uc_backtests(string(pwd),'multi_origin_4step');
run_uc_backtests(string(pwd),'outlier_sensitivity');
```

也可以进入任一实验目录运行该目录下的`run_experiment`。两个目录有同名函数，切换目录时不要同时把两个目录加入MATLAB路径。

环境与正式流程一致，需要ECOTOOL、Econometrics Toolbox、Statistics and Machine Learning Toolbox。`modelUC`未在路径时，优先检查`ECOTOOL_PATH`及Windows常规用户安装目录。UC实际使用原流程的CML调用，无季节项。

计算完成后，在项目根目录运行以下命令，独立核验并生成两份中文报告：

```powershell
python experiments/analyze_results.py
```

Python需要`openpyxl`。报告为中文命名的Markdown文件，图表采用同目录PNG相对链接；请使用支持Markdown的阅读器打开。

## 设计

- `multi_origin_4step`：RW、LLT、朴素、递归三期移动平均，在第78～104周共27个训练截止点分别预测未来4周。
- `outlier_sensitivity`：同27个原点，比较RW/LLT原始组与训练缩尾组。各原点只使用当时原始历史计算`Q3+1.5×IQR`，只缩尾高额训练观测，预测目标保留原值。
- 每步长27条误差，总体108条原点与步长组合，覆盖30个不同目标周，重叠误差不视为独立实验。
- 原108周训练与4周测试划分保留；全部训练内选模及最终四步预测锁定后，才在运行中读取保留测试金额。该测试集此前已观察，不是新盲测。
- 指标同时报告MAE、RMSE、sMAPE。选模沿用原诊断优先规则，并另列纯MAE最优UC；测试误差不参与选择。
- 原始组复现正式一步滚动前27折及原固定四步预测；两个实验的原始UC预测逐项匹配。

## 本机来源核实

敏感性报告将完整108周的IQR大额候选与`raw_data`核对。A只有周汇总CSV，仅能确认金额一致；B按`合并消费明细`的净消费重算；C按`04_周期内逐笔`的个人总支付重算。不能据此推断大额周一定是误记。来源行号等核对线索在`异常大额周来源核对.csv`，不发布逐笔消费描述。公开检出来源缺失时会如实标注尚未核对。

完整模型及预测锁定保存在MAT中，明细、参数、阈值、缩尾记录、选模、最终测试和核验在各实验`results`中分开保存。重跑会更新该实验结果；不会更新正式报告或正式模型。
