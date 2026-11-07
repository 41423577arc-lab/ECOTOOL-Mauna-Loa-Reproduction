# 成员 B 运行说明

入口：`src/run_member_b.m`。需要 MATLAB、Optimization Toolbox 及作者 ECOTOOL。

```matlab
addpath('src');
run_member_b('工具箱解压目录/fsroot','数据路径/dataPLOSpaper.mat');
```

依赖来源：https://github.com/djpedregal/ECOTOOL
本次依赖提交：8de5e85af0a9ffe852a9cab71b44bfc063175cb2。
工具箱可用 MATLAB 安装作者的 ECOTOOL.mltbx，也可将其作为 ZIP 解压后传入 fsroot。
第三方工具箱与原始数据不重复提交本仓库。

该入口复现论文单次预测示例：CO2(25:504) 训练、505:528 测试，24 步。
作者 MAT 文件包含 CO2 单列向量（723 个值），不是论文 maunaLoa.data 的五列矩阵。
月份按论文 1958 年 3 月起连续月度索引建立。
Airline 对训练集估计 Box-Cox 后建模；Auto 接收原始训练数据并内部识别。
根据实测输出尺度，仅对 Airline 的 py 逆变换，原始模型结构另存 MAT 以供检查。
sMAPE 使用百分数；MASE 分母仅使用训练集的 12 阶季节差分绝对值均值。

结果：results/tables/B_single_predictions.csv、B_single_metrics.csv、B_single_models.mat、B_environment.txt；图在 results/figures/B_*.png。
指标是单个预测起点、24 步的平均误差，不能与 Table 4 的滚动平均结果直接比较。

当前尚未实现或完成 220 轮滚动实验。论文示例跳过前 24 个样本与正文滚动起点存在差异，需先统一协议再运行正式滚动评价。

实测版本差异：当前 Auto 的 py 已为原始 ppm 尺度（约 370），Airline py 为变换尺度（约 13）。因此只对 Airline 逆变换，避免照搬论文示例产生重复逆变换。

