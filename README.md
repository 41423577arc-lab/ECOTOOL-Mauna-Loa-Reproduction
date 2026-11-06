# ECOTOOL-Mauna-Loa-Reproduction

## 项目简介

本项目由三人小组协作，复现 Diego J. Pedregal 2019 年论文中 Mauna Loa 月度大气 CO₂ 浓度预测案例（论文第 10–13 页）。项目关注经典时间序列模型的预测表现；当前阶段仅完成项目初始化与文档，不包含实验结果。

## 资料来源

- 原论文：[Time series analysis and forecasting with ECOTOOL](https://doi.org/10.1371/journal.pone.0221238)
- ECOTOOL 官方代码：[github.com/djpedregal/ECOTOOL](https://github.com/djpedregal/ECOTOOL)
- NOAA Mauna Loa CO₂ 数据：[Trends in Atmospheric Carbon Dioxide](https://gml.noaa.gov/ccgg/trends/data.html)

## 研究问题与复现范围

研究历史月度 CO₂ 浓度中的长期趋势和季节性，并比较不同经典时间序列模型对未来 24 个月的预测表现。复现工作包括趋势图、季节性分析、差分、ACF/PACF；Airline SARIMA、Auto ARIMA、UC、ETS 和 Seasonal Naïve 五种模型；单次预测与原文滚动预测；sMAPE、MASE 评价；以及与论文 Table 4 的对照。论文中的纯 AR 模型暂不纳入必做范围。

## 核心流程

数据 → 预处理 → 模型 → 预测 → 评价

## 项目目录

| 路径 | 用途 |
|---|---|
| docs/ | 项目计划与复现协议 |
| data/ | 数据来源说明及后续使用的数据 |
| src/ | 后续 MATLAB 程序 |
| results/figures/ | 实验图表 |
| results/tables/ | 评价指标及结果表 |
| presentation/ | 最终 PPT 和演讲稿 |

## 三人分工

成员 A 负责数据、项目文档和 PPT 整合；成员 B 负责 MATLAB 环境与模型复现；成员 C 负责预测评价和结果分析。具体职责、时间表和验收标准见[项目计划](docs/project_plan.md)。

## 时间安排

- 第 1 天：环境与数据；验证 MATLAB 可加载数据并完成至少一个模型预测。
- 第 2 天：模型与预测；至少三个核心模型产生可检查的预测结果。
- 第 3 天：结果核验、PPT 与演讲稿整合，完成 12 分钟彩排。
- 第 4–5 天备用：优先补充 220 轮滚动预测，处理兼容性、结果差异及最终材料检查。

## 预计交付物

可运行的 MATLAB 实验代码、结果图表、模型指标表、约 10 页 PPT 和完整 12 分钟演讲稿。

## 当前状态

- [x] 项目目录初始化
- [x] 项目文档建立
- [ ] MATLAB环境验证
- [ ] 数据准备与检查
- [ ] 模型复现
- [ ] 预测结果评价
- [ ] PPT制作
- [ ] 演讲稿撰写
- [ ] 最终汇报

## MATLAB 运行说明（预留）

待后续完成 MATLAB 与 ECOTOOL 环境验证后，补充版本要求、数据准备方式、运行入口和复现步骤。本次初始化未安装软件、下载数据或运行实验。
