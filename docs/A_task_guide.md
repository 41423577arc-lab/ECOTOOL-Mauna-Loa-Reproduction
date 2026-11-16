# 成员A任务指南：数据特征分析、ETS 与 Seasonal Naïve

> **适用对象**：ECOTOOL-Mauna-Loa-Reproduction 项目成员 A
> **依据文献**：Pedregal, D. J. (2019). *Time series analysis and forecasting with ECOTOOL*. PLOS ONE, 14(10), e0221238.
> **依据仓库**：`README.md`、`docs/project_plan.md`、`docs/reproduction_protocol.md`、`data/README.md`
> **文档定位**：把 `project_plan.md` §4 的任务 A1–A6 展开成可执行的步骤，并补上原论文中的对应口径。
> **编写日期**：2026-11-15

---

## 0. 这份文档怎么用

本文档**不替代**仓库已有的三份文档，而是它们的执行版：

| 文档 | 作用 | 本文档的关系 |
|---|---|---|
| `README.md` | 项目总览、五人分工、汇报安排 | 摘要引用，不重复 |
| `docs/project_plan.md` | 任务分解、验收标准、时间表 | **主要依据**，逐条展开 |
| `docs/reproduction_protocol.md` | 论文设置与待核实事项 | 全部落实到第 2 节核对表 |
| `data/README.md` | 数据来源与保存要求 | 落实到 A1 任务 |

三条硬原则：

1. **按论文口径**：模型设定、变换、评价指标都以论文原文为准，不自行发明。
2. **按仓库约定**：文件名、字段名、目录结构、PPT 页码都按 `project_plan.md` 和 `README.md` 来。
3. **只写实际结果**：`README.md` §9 明确要求"不得将计划内容标记为已经完成的实验结果"。没有跑出来的，就写"未完成"。

---

## 1. 角色定位与验收标准

### 1.1 职责（`project_plan.md` §4.1）

> 负责原始数据分析，以及 ETS 和 Seasonal Naïve 两种预测方法的复现。

### 1.2 独立交付物（`project_plan.md` §4.3，原文照录）

- [ ] 原始数据检查记录
- [ ] Fig.1 对应的时间序列图
- [ ] 季节性分析结果
- [ ] ETS 模型 MATLAB 代码
- [ ] Seasonal Naïve 模型 MATLAB 代码
- [ ] 两种模型的预测数据
- [ ] 两种模型的评价指标
- [ ] 模型比较结论
- [ ] PPT 第 1～4 页及演讲稿

### 1.3 验收标准（`project_plan.md` §4.4，原文照录）

> 成员A能够独立运行 ETS 和 Seasonal Naïve 模型，得到预测结果，并解释原始序列规律及两种模型的预测差异。

### 1.4 额外整合职责（`README.md` §4、`project_plan.md` §9）

- 统一最终 PPT 的排版与格式（其他成员只管内容）。
- PPT 第 1～4 页，约 **3 分 30 秒**。

> **注意一个优先级差异**：`README.md` §2.3 把 ETS 列在"完整复现（争取完成）"里，但 `project_plan.md` §4.4 把 ETS 写进了 A 的验收标准。**对你个人而言 ETS 是必交项**，不能因为整体门槛低就跳过。Seasonal Naïve 则属于"基础复现（必须完成）"。

---

## 2. 开始前必须核对的 9 个事实

下表把 `reproduction_protocol.md` 的"必须核对并记录"落到可操作层面。**每一条都要在你的实验记录里留下核实结果**，不能照抄本文档。

| # | 事项 | 论文说法 | 仓库说法 | 你要做什么 |
|---|---|---|---|---|
| 1 | 数据文件 | `load maunaLoa.data`（NOAA 原始多列文件） | 使用 ECOTOOL 官方仓库的 `dataPLOSpaper.mat` | 用 `.mat`，记录文件名、下载日期、来源 URL |
| 2 | 变量与列 | `maunaLoa(25:504, 5)`，第 5 列是 CO₂ | `.mat` 中没有 `maunaLoa`，只有 `CO2`（723×1）、`Sun`、`electricity` | `whos -file` + `fieldnames` + `size` 确认，用 `S.CO2` |
| 3 | 观测范围 | 1958-03 ～ 2018-05，月度 | 同 | 建时间轴后看 `t_all(end)` 是否为 2018-05 |
| 4 | 训练样本 | 480 个月 | 480 个月 | 核对起始行与对应日历月份 |
| 5 | 预测步长 | `nofs = 24` | 24 个月 | 固定 |
| 6 | 季节周期 | `s = 12` | 12 | 固定 |
| 7 | Box-Cox | `[ty, lambda] = vboxcox(y)`，**所有模型（除 Auto）都用 ty** | 未在 A 的任务里明说 | **A 的 ETS/Naïve 必须用**，见 §4.4 |
| 8 | 评价指标 | Eq.(8)(9)，p.9 | 统一用 sMAPE/MASE | 按论文公式，见 §4.5 |
| 9 | 滚动轮数 | 220 轮，480 起点 | 220 轮 | 见 §3.2，需组内确认 |

### 2.1 记录模板（建议照抄到自己的记录文件）

```text
MATLAB 版本:
ECOTOOL 版本:
数据文件:
下载日期 / 来源:
矩阵/变量尺寸:
CO₂ 变量名:
起始月份假设:
验证后末月份:
缺失值情况:
Box-Cox lambda:
```

---

## 3. 实验协议：先分清两件事

### 3.1 单次预测 ≠ 滚动预测（`reproduction_protocol.md` 原文要求）

- **单次 24 个月预测**：一个训练截止点，预测随后 24 个月。用于流程检查和预测图。
- **滚动预测**：训练截止点逐月推进，每轮重新估计，共 220 轮，按步长汇总误差。
- 单次误差**不得**直接与 Table 4 的滚动平均值比较。

### 3.2 论文内部有一个窗口矛盾（重要）

论文第 11 页示例代码：

```matlab
y = maunaLoa(25:504, 5);          % 跳过前两年，取 480 个月
nofs = 24; s = 12;
```

> **本仓库数据的对应写法**：这段代码里的 `maunaLoa` 是作者自己的 `maunaLoa.data`（NOAA 多列原始文件），**本仓库的 `dataPLOSpaper.mat` 里没有这个变量**。该 `.mat` 已经把 CO₂ 提成一列 `CO2`（723×1），所以等价写法是：
>
> ```matlab
> S = load('data/dataPLOSpaper.mat');
> y = S.CO2(25:504);      % 480 个月
> ```
>
> "取第 5 列"这一步在本文件里已经由作者完成，不要再 `raw(:,5)`。

论文第 12 页滚动实验描述：

> "the initial forecast origin is chosen at 480 observations from the beginning (March 1998) ... 220 total rounds"

两者推出的窗口不同：

| | 训练区间 | 预测区间 |
|---|---|---|
| 示例代码（25:504） | 1960-03 ～ 2000-02 | 2000-03 ～ 2002-02 |
| 滚动实验（1:480） | 1958-03 ～ 1998-02 | 1998-03 起，220 轮 |

用数据行数做算术核对：

```text
假设总行数 = 723（1958-03 ～ 2018-05）
480 + 220 + 24 - 1 = 723   → 成立
若训练从第 25 行起：723 - 24 - 480 + 1 = 196 轮，凑不出 220 轮
```

**结论（推断，需组内确认）**：Table 4 的滚动实验很可能从**第 1 行**开始；`25:504` 只是第 11 页的**单次演示**。

**A 的处理方式**：
- 第 1–3 天的单次预测，用论文示例的 `25:504`。
- 第 4–5 天若做滚动，从第 1 行开始，并先在组会上确认。
- 两组结果分开保存、分开表述。

> `reproduction_protocol.md` 明确要求："不得将未核实的设置写成已验证事实"。所以这一条在你的汇报里要写"论文正文与示例代码存在不一致，本组采用 X 方案"，而不是直接说论文错了。

### 3.3 全组统一的三件事（先跟 B、C 确认）

1. 单次预测窗口：`25:504`。
2. 预测结果字段：`model / forecast_origin / target_month / horizon / actual / predicted`（`README.md` §4 表格）。
3. 数值尺度：全部回到原始 ppm 再比较。

---

## 4. 任务分解 A1–A6

### 4.1 任务 A1：数据读取与检查

**对应**：`project_plan.md` §4.2 任务 A1；`data/README.md`。

**步骤**

1. 把 `dataPLOSpaper.mat` 放进项目 `data/` 目录。
2. 先只看文件头，不加载：

```matlab
whos -file 'data/dataPLOSpaper.mat'
```

3. 加载并检查结构：

```matlab
clear; close all; clc
S = load('data/dataPLOSpaper.mat');
fieldnames(S)      % 预期：CO2、Sun、electricity
x_all = S.CO2;     % 723×1 的 CO₂ 月度序列
size(x_all)
x_all(1:5)
```

> **重要**：`dataPLOSpaper.mat` 里**没有** `maunaLoa` 变量，也没有第 5 列可取的矩阵。作者已经把论文用的 CO₂ 序列单独提成一列 `CO2`。`load maunaLoa.data` + `maunaLoa(25:504,5)` 是论文作者用自己那份 NOAA 原始文件时的写法，不要照搬。
>
> 另外两个变量 `Sun`（太阳辐照度）和 `electricity`（西班牙电力负荷）是论文另外两个案例的数据，本项目不用。

4. 检查缺失值与量级：

```matlab
sum(isnan(x_all))
min(x_all), max(x_all)      % 应在 315–412 ppm 之间
```

5. 建立时间轴并核对：

```matlab
n = size(x_all,1);
t_all = datetime(1958,3,1) + calmonths((0:n-1)');
t_all(1), t_all(end)
```

6. 核对关键行号的日期（这一步是后面所有索引的基础）：

```matlab
t_all([1 25 504 505 end])
```

**检查点**

- `size(x_all)` 应为 `723 × 1`。
- `t_all(end)` 应为 `2018-05-01`。若不是，说明起始月份假设要改，回到第 5 步重新反推。
- `x_all` 不应有 NaN；量级应在 315–412 ppm。
- `t_all([1 25 504 505 end])` 应依次为 `1958-03 / 1960-03 / 2000-02 / 2000-03 / 2018-05`。这组对应关系是第 4.3 节训练集划分的依据。
- 把 `whos -file` 的尺寸抄进记录。

**产出**

- 数据检查记录（版本、尺寸、列、起止、缺失、lambda 待补）。

---

### 4.2 任务 A2：时间序列特征分析（复现 Fig.1）

**对应**：`project_plan.md` §4.2 任务 A2；论文 p.10 Fig.1。

**论文对 Fig.1 的描述（可直接用于讲稿）**

> "sixty years of monthly data collected from March 1958 to May 2018. The data show a growing trend during the full period associated with long run emissions and a seasonal component rather stable related to the global net uptake and release of CO2 in summer and winter."

**步骤 1：画全序列（注意是完整数据，不是训练集）**

```matlab
x_all = S.CO2;      % 已在 A1 中读入，这里沿用

figure('Color','w','Position',[100 100 1000 420]);
plot(t_all, x_all, 'LineWidth', 0.9);
xlabel('Year'); ylabel('CO_2 concentration (ppm)');
title('Mauna Loa monthly CO_2 concentration, 1958-03 to 2018-05');
grid on;
exportgraphics(gcf, 'results/figures/A_fig1_co2_series.png', 'Resolution', 200);
```

**步骤 2：量化趋势**

```matlab
% 年均值
yr  = year(t_all);
ann = accumarray(yr - min(yr) + 1, x_all, [], @mean);
yrs = (min(yr):max(yr))';

% 线性趋势斜率（ppm/年）
tt = (0:numel(x_all)-1)' / 12;
p  = polyfit(tt, x_all, 1);
slope_ppm_per_year = p(1)
```

**步骤 3：量化季节性**

```matlab
mth  = month(t_all);
seas = accumarray(mth, x_all, [], @mean);
amplitude = max(seas) - min(seas)
```

**步骤 4：季节性对照图（强烈建议放进 PPT）**

```matlab
figure('Color','w');
hold on;
for y = min(yr):max(yr)
    m = (yr == y);
    plot(1:12, x_all(m), '-', 'LineWidth', 0.8);
end
xlabel('Month'); ylabel('CO_2 (ppm)');
title('Seasonal profile by year');
grid on; hold off;
```

这张图能直观说明"**趋势 = 整体上移，季节 = 固定波形**"，为 ETS 的加法结构做铺垫。

**检查点**

- 趋势斜率应为 **2 ppm/年量级**。
- 季节振幅应为 **3 ppm 量级**。
- 两者对比可以写成一个有力句子："季节振幅约相当于一年半的趋势增量。"

**产出**

- `results/figures/A_fig1_co2_series.png`
- 趋势图、季节图
- 文字结论：趋势方向与速率、季节峰值/谷值月份

---

### 4.3 任务 A3：Seasonal Naïve

**对应**：`project_plan.md` §4.2 任务 A3；论文 p.11、p.12。

**论文原文依据**

> "Naïve: seasonal naïve, i.e. forecasts are taken as the last observation of the same season available (**third column of output from modelNAIVE function**)."

**先划样本**

```matlab
idx0 = 25; nTrain = 480; H = 24; s = 12;

y       = x_all(idx0 : idx0+nTrain-1);       % 480 个月
t_y     = t_all(idx0 : idx0+nTrain-1);
actual  = x_all(idx0+nTrain : idx0+nTrain+H-1);  % 24 个月
t_actual= t_all(idx0+nTrain : idx0+nTrain+H-1);

disp([t_y(1) t_y(end)])
disp([t_actual(1) t_actual(end)])
```

**Box-Cox 变换（论文口径，必做）**

```matlab
[ty, lambda] = vboxcox(y);
```

> `vboxcox` 会弹出一张 lambda 似然曲线图，**可以截图用于 PPT**，说明"按论文做了方差稳定化变换"。

**跑季节朴素**

```matlab
mN = modelNAIVE(ty, H, s);
size(mN.py)          % 应为 24 x 6
fN = vboxcoxinv(mN.py(:,3), lambda);
```

**检查点**

- `size(mN.py)` 必须是 `24 × 6`；第 3 列才是季节朴素。
- 逆变换后 `fN` 应在 **400 ppm 左右**。如果是 5 点几或 0 点几，说明漏了逆变换或重复逆变换。

**产出**

- `src/A3_naive.m`
- 24 个月预测值

---

### 4.4 任务 A4：ETS（AA12）

**对应**：`project_plan.md` §4.2 任务 A4；论文 p.11、Table 2。

**论文原文依据**

> "ETS: additive Exponential Smoothing with level, slope and seasonal (modelES with model option `AA12`)."

原代码：

```matlab
m4 = modelETS(ty, [], 'AA12', nofs);
```

**跑模型**

```matlab
mE = modelETS(ty, [], 'AA12', H);
fE = vboxcoxinv(mE.py, lambda);

disp(mE.table)   % 参数估计表，可截图进 PPT
```

**检查点**

- `fE` 应与 `fN` 同量级（400 ppm 左右）。
- `mE.table` 应有输出；若为空，检查 lambda 与 ty 是否传对。
- 若报错找不到函数，回第 1 步用 `which modelETS` 验证工具箱。

**关于 `AA12` 的含义（讲稿要用）**

- 第一个字母管**趋势**：A = 加法，N = 无，D = 阻尼。
- 第二个字母管**季节**：A = 加法。
- `12` = 周期 12 个月。
- 所以 AA12 = **加法趋势 + 加法季节**，对应 level、slope、seasonal 三部分。

**产出**

- `src/A4_ets.m`
- 24 个月预测值
- 参数估计表

---

### 4.5 任务 A5：评价与对比

**对应**：`project_plan.md` §4.2 任务 A5。

**论文公式（p.9 Eq.8 / Eq.9）**

$$\text{sMAPE}_h=\frac{100}{h}\sum_{i=1}^{h}\frac{2|y_i-\hat y_i|}{|y_i|+|\hat y_i|}$$

$$\text{MASE}_h=\frac{1}{h}\sum_{i=1}^{h}\frac{|y_i-\hat y_i|}{\frac{1}{n-s}\sum_{r=s+1}^{n}|y_r-y_{r-s}|}$$

其中 `n` 是**拟合样本**长度。

**MATLAB 实现**

```matlab
smape = @(a,f) mean(200 * abs(a - f) ./ (abs(a) + abs(f)));
mase  = @(a,f,tr,s) mean(abs(a - f)) / mean(abs(tr(s+1:end) - tr(1:end-s)));

smapN = smape(actual, fN);
smapE = smape(actual, fE);
masN  = mase(actual, fN, y, s);    % 分母用原始尺度训练样本 y
masE  = mase(actual, fE, y, s);

fprintf('Seasonal naive : sMAPE = %.3f%%, MASE = %.3f\n', smapN, masN);
fprintf('ETS (AA12)     : sMAPE = %.3f%%, MASE = %.3f\n', smapE, masE);
```

**两个口径细节，需组内统一**

1. **MASE 分母用哪个序列**：分子在 ppm，分母也应在 ppm，所以用 `y`（原始尺度），不要用 `ty`。
2. **滚动时**：`n` 每轮都在变，**分母必须每轮重算**，不能算一次用 220 轮。

**误差随步长变化**

```matlab
figure('Color','w');
plot(1:H, abs(actual-fN), 'b-o', 1:H, abs(actual-fE), 'r-s', 'LineWidth', 1.2);
xlabel('Forecast horizon (months)'); ylabel('Absolute error (ppm)');
legend({'Seasonal naive','ETS'}, 'Location','northwest');
title('Absolute forecast error by horizon');
grid on;
```

**与论文 Table 4 对照（ETS / Naïve 两列）**

| 步长 | ETS sMAPE | ETS MASE | Naïve sMAPE | Naïve MASE |
|---|---|---|---|---|
| 1 | 0.067 | 0.170 | 0.549 | 1.386 |
| 6 | 0.094 | 0.238 | 0.550 | 1.381 |
| 1 年 | 0.118 | 0.299 | 0.547 | 2.068 |
| 2 年 | 0.168 | 0.426 | 0.818 | 见原表 |

> Table 4 跨论文 p.12–13，列对齐较密，精确数字请以 PDF 原表为准。

**论文的结论（务必引用，不要自己编）**

> "all models show significant performance improvements over the Naïve ... ETS deteriorates importantly for 24 months ahead."

你的分析应回答三件事：

1. ETS 是否明显优于季节朴素？（看 sMAPE/MASE 是否大幅下降）
2. ETS 是否在长步长退化？（看误差-步长曲线是否上扬）
3. 为什么会退化？（加法趋势线性外推，跟不上 CO₂ 加速上升）

**产出**

- `results/tables/A_forecast_ETS_Naive.csv`
- `results/tables/A_model_metrics.csv`
- 误差-步长图

---

### 4.6 任务 A6：汇报材料

**对应**：`project_plan.md` §9；`README.md` §8。

| 页 | 内容 | 你的素材 |
|---|---|---|
| 1 | 论文来源与研究目标 | 论文题名、期刊、年份；复现范围是 Mauna Loa 案例 |
| 2 | CO₂ 浓度预测的现实背景 | 气候变化、Mauna Loa 长期观测、预测的意义 |
| 3 | 数据来源与时间序列特征 | Fig.1 + 年均值图 + 季节图 + 斜率/振幅两个数 |
| 4 | ETS、Naïve 模型及初步比较 | 预测对比图 + sMAPE/MASE 表 + 一句基于实际结果的结论 |

**3 分 30 秒结构建议**

| 段落 | 时长 | 要点 |
|---|---|---|
| 背景 | ~30 s | 研究什么问题、为什么重要 |
| 数据 | ~60 s | 范围、趋势、季节性（用两个具体数字支撑） |
| 模型 | ~60 s | 两个模型的思路：一个不学、一个学趋势和季节 |
| 结果 | ~45 s | 谁更好、差多少、长步长怎么变 |
| 收尾 | ~15 s | 引出 B 的 ARIMA |

**讲稿红线**

- 结论必须来自你实际跑出的数字。
- 不把论文 Table 4 的数字说成"我们复现的结果"。
- 未完成的滚动预测要明说未完成。

---

## 5. 三天时间表（`project_plan.md` §8）

| 时间 | 你的任务 | 当天验收 |
|---|---|---|
| 第 1 天 | 数据核对、Fig.1、趋势与季节性、跑通 Naïve | 能独立读数据 + 完成原始序列图 |
| 第 2 天 | 完成 ETS、两种模型 24 个月预测、算误差、初步比较 | 预测值 + 实际值 + 指标齐全 |
| 第 3 天 | 整理结果、PPT 第 1–4 页、讲稿、统一 PPT 格式 | 可提交版本 + 12 分钟彩排 |
| 第 4–5 天 | 补充 ETS/Naïve 滚动预测（可选） | 多轮误差；未完成要如实说明 |

**第 1 天还需要做的共同任务**：确认数据版本与实验协议、确定预测结果保存格式。

---

## 6. 文件与命名（`README.md` §6、`project_plan.md` §10）

```text
src/
  A1_load_data.m
  A2_features.m
  A3_naive.m
  A4_ets.m
  A5_evaluation.m
results/
  figures/
    A_fig1_co2_series.png
    A_trend_annual.png
    A_seasonal_profile.png
    A_forecast_ETS_Naive.png
    A_error_by_horizon.png
  tables/
    A_forecast_ETS_Naive.csv
    A_model_metrics.csv
    A_ETS_estimation_table.csv
presentation/
  A_slides_1-4.pptx
  A_speech.md
```

**命名规则**：一律以 `A_` 开头，避免覆盖 B、C 的文件（`README.md` §6 要求）。

**预测结果字段（全组统一）**

| 字段 | 含义 |
|---|---|
| model | 模型名称 |
| forecast_origin | 预测起点 |
| target_month | 预测目标月份 |
| horizon | 预测步长 |
| actual | 实际观测值（ppm） |
| predicted | 预测值（ppm） |

```matlab
origin = string(t_y(end));
hv     = (1:H)';

T = table( ...
    [repmat("ETS",H,1); repmat("SeasonalNaive",H,1)], ...
    [repmat(origin,H,1); repmat(origin,H,1)], ...
    [t_actual; t_actual], ...
    [hv; hv], ...
    [actual; actual], ...
    [fE; fN], ...
    'VariableNames', {'model','forecast_origin','target_month','horizon','actual','predicted'});

writetable(T, 'results/tables/A_forecast_ETS_Naive.csv');
```

---

## 7. 第 4–5 天：滚动预测（可选）

**前提**：第 1–9 步全部跑通、图表齐全。否则优先保证单次预测正确。

**论文描述**

> 初始 480 个月，每次加 1 个月，24 步预测，共 220 轮。

**骨架（先跑 5 轮验证，再跑全量）**

```matlab
nRounds = 220;        % 先确认可行轮数，见 §3.2
H = 24; s = 12;
SMA_N = nan(nRounds,1); SMA_E = nan(nRounds,1);

for j = 1:nRounds
    i0  = j;                                  % 起点：第1行（待组内确认）
    tr  = x_all(i0 : i0+480-1);
    ac  = x_all(i0+480 : i0+480+H-1);

    [ttr, lam] = vboxcox(tr);                 % 每轮是否重估 lambda：论文未明说，需记录假设
    pN = vboxcoxinv(modelNAIVE(ttr,H,s).py(:,3), lam);
    pE = vboxcoxinv(modelETS(ttr,[],'AA12',H).py, lam);

    SMA_N(j) = smape(ac, pN);
    SMA_E(j) = smape(ac, pE);

    fprintf('round %d / %d\n', j, nRounds);
end
```

**注意事项**

- ETS 每轮做极大似然估计，220 轮可能要跑很久。**先 `nRounds = 5`**。
- 每轮 MASE 的分母要用**当轮**训练样本重算。
- "lambda 是否每轮重估"论文没写，**必须记录你的假设**，并在汇报里说明。
- 若只跑了部分轮数，写"完成 X 轮，非论文的 220 轮"，不得混称。

---

## 8. 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| `Unrecognized function 'modelETS'` | 工具箱未安装/不在路径 | `which modelETS`，必要时 `addpath(genpath(...))` + `savepath` |
| `Undefined function 'calmonths'` | MATLAB 版本较老 | 改用 `months(...)` 或手工构造 |
| 维度不一致 | `py` 方向不定 | 一律加 `(:)` |
| `fE`/`fN` 只有 5 点几 | 忘做逆变换 | `vboxcoxinv(..., lambda)` |
| `fE`/`fN` 与预期差一个数量级 | 重复逆变换 | 全流程只逆变换一次 |
| 中文标签变方框 | 字体 | `set(gca,'FontName','Microsoft YaHei')`，或改英文 |
| `exportgraphics` 不存在 | MATLAB < R2020a | `print(gcf, 文件名, '-dpng','-r200')` |
| 均值/方差统计报错 | 有 NaN | 检查 `S.CO2` 是否含 NaN |
| `Unrecognized field name "maunaLoa"` | 照搬了论文的 `maunaLoa` 写法 | 改用 `S.CO2`（见 §4.1） |

**自查手段**：论文第 12 页用 `toolFORECAST(ACTUAL, FORECASTS)` 直接出误差表。你可以用它交叉验证手算的 sMAPE/MASE，并在汇报里说明"已用官方工具核对"。

```matlab
FORECASTS = [fN fE];
toolFORECAST(actual, FORECASTS)
```

---

## 9. 禁做清单

1. 不把**单次 24 个月预测**的误差说成与 Table 4 可比。
2. 不把论文的数字当作本组结果。
3. 不重复逆变换，也不忘逆变换。
4. 不覆盖 B、C 的文件（文件名一律 `A_` 前缀）。
5. 不在未与组内确认前修改共同实验协议（`README.md` §7）。
6. 不把未完成的滚动预测描述为已完成。
7. 不提交个人账号、密钥、无关缓存（`README.md` §7）。

---

## 10. 页码与引用索引

| 内容 | 论文位置 |
|---|---|
| sMAPE / MASE 公式 Eq.(8)(9) | p.9 |
| Fig.1 与数据说明 | p.10 |
| 模型清单与 MATLAB 示例代码 | p.11 |
| Fig.2（ACF/PACF） | p.12 |
| 滚动实验说明、Table 4 开始 | p.12 |
| Table 4 主体、讨论、Fig.3 | p.13 |

> `README.md` 说"第 13 页：Table 4 模型结果及 Fig.3"，基本正确；需注意 Table 4 实际跨 p.12–13。

---

## 11. 完成前自检

- [ ] 数据检查记录完整（版本、尺寸、列、起止、缺失、lambda）
- [ ] `t_all(end)` = 2018-05 已核实
- [ ] Fig.1 覆盖 1958-03 ～ 2018-05 全序列
- [ ] 有趋势斜率、季节振幅两个具体数字
- [ ] `vboxcox` 已用于 ETS 和 Naïve
- [ ] `modelNAIVE` 取第 3 列
- [ ] `size(mN.py)` = 24×6
- [ ] 两个模型预测值都在 400 ppm 量级
- [ ] sMAPE/MASE 按论文 Eq.(8)(9) 计算
- [ ] MASE 分母在原始尺度 `y` 上计算
- [ ] 预测 CSV 六字段齐全
- [ ] 图、表文件名以 `A_` 开头
- [ ] PPT 第 1–4 页完成，约 3 分 30 秒
- [ ] 讲稿结论全部来自实际运行结果
- [ ] 已统一全组 PPT 格式

---

*本文档基于论文原文与仓库现有文档编写。凡是论文未明确、仓库标注"需核实"的内容，均已在文中标为待确认，不作为既定事实。*
