# 最后四周滚动一步预测补充实验

结果入口：[中文实验分析报告](results/comparison/中文实验分析报告.md)。

本目录只运行训练长度108、109、110、111的四轮扩展窗口预测，并以同一108周估计生成固定原点四步对照。不运行既有30折或27原点回测。第109周来自本次重新估计，在两协议间共享。

## 运行

在项目根目录执行：

```powershell
matlab -batch "addpath('rolling_final4'); run_final4; close all force" -logfile rolling_final4/results/comparison/matlab.log
matlab -batch "addpath('rolling_final4'); check_ets_affine" -logfile rolling_final4/results/comparison/ets_affine.log
python rolling_final4/summarize_verify.py
```

需要 MATLAB Econometrics Toolbox、Optimization Toolbox、Statistics and Machine Learning Toolbox、本机ECOTOOL，以及Python的numpy、pandas、openpyxl、matplotlib。ECOTOOL优先使用环境变量`ECOTOOL_PATH`，否则使用当前用户常规安装目录，不复制工具箱。ECOTOOL依赖结果窗口内部控件，局部适配保留隐藏控件、禁止显示和激活；不修改工具箱安装。Python绘图使用Agg后台，不创建窗口。

## 来源与复用

- `prepare_sources.py`从已fetch的`origin/Ariel`检查三份ETS脚本及其调用，记录SHA，再从本地`experiments/uc_ssm_rebuild/run_uc_ssm.m`选择性提取原估计函数。它仅用于更新来源快照，不是每次运行的必要步骤。
- `src/ets/fit_ets_final4.m`沿用远端CML调用，移除旧G盘路径和成员文件映射；实际输入由统一入口提供。来源为Ariel `f69ea4c27d261bc657d66b8e8e64f958abb0471f`的`src/单人测试（无异常值处理）/A_case_ets_aligned.m`、`B_case_ets.m`、`C_case_ets.m`。已检查该提交`docs/A_uc_alignment.md`及`results/tables/`历史表。
- `src/uc/fit_uc_final4.m`只提取配置、估计、预测及其必要帮助函数，不调用原实验主入口、不修改原结果。源文件哈希保存在`provenance.json`；本目录可独立运行，不要求把尚未提交的新版UC结果一并提交。
- `src/arima/fit_mean_final4.m`明确实现当轮均值，等待与ARIMA同学后续结果统一。没有声称已经获取其最新代码。
- 输入统一使用根目录`data/`中的112周三份Excel，原始来源只核验、不复制。本地原始文件未随本次提交发布。核验脚本需要这些原始文件及已有UC固定原点CSV，正式估计入口仅需data与原output训练MAT。

## 结果

各成员目录含逐周预测、预测锁定记录、各轮参数、UC多起点、ETS原尺度/标准化估计日志、两协议曲线。`comparison/performance.csv`含两协议的MAE、RMSE、sMAPE、MASE、四周预测合计、累计金额绝对误差及逐周绝对误差总和；`fixed_vs_rolling.csv`提供配对比较。MASE每轮只使用当轮训练分母；四周累计为完整四周之和，不使用十月天数权重。

`runtime.json`记录正式估计耗时，`provenance.json`记录远端提交和输入版本，`verification.json`记录独立核验。ETS的数值退出码不由接口公开，保留优化文本；UC协方差和边界异常保留，不据测试误差改模型。

仅对本目录执行Git暂存、中文提交与推送，保留用户原有未提交修改。
