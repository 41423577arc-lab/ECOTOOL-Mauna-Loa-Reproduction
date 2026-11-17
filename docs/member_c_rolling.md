# 成员C：UC与AR12滚动实验

## 运行

在项目目录打开MATLAB：

```matlab
addpath('src');
run_member_c_rolling(3);
audit_member_c_rolling(3);  % 只核验3轮试跑，不代表220轮完成
run_member_c_rolling(220); % 从有效检查点续跑
audit_member_c_rolling;    % 默认要求两种模型均有完整220轮
compare_member_c_models;   % 只读Git中的B结果，核算后生成比较表和曲线
verify_member_c_rolling;   % 验证免重估续跑，并以临时副本测试核验能否拒绝错误
```

已有220轮检查点时，入口仅验证检查点并重新导出，不重新估计。此时调用`audit_member_c_rolling(3)`会失败，因为它要求恰好3轮；应调用默认核验。

默认使用MATLAB当前路径中已安装的ECOTOOL，以及项目的`data/dataPLOSpaper.mat`。可配置路径：

```matlab
run_member_c_rolling(220,'C:/your/ECOTOOL','D:/your/dataPLOSpaper.mat');
% 第4个参数可指定独立输出目录；核验和比较的第3个参数传相同目录。
run_member_c_rolling(220,'','D:/your/dataPLOSpaper.mat','D:/your/output');
audit_member_c_rolling(220,'D:/your/dataPLOSpaper.mat','D:/your/output');
```

不要同时向同一输出目录运行两个入口。MATLAB版本、三个ECOTOOL入口源码、`modelUC0`后端指纹或数据发生变化时，续跑会拒绝混用；应另指定输出目录。源码和后端相同而安装路径不同可以续跑。ECOTOOL若手工安装而非add-on，版本表可能为空，检查点仍保存入口路径和源码；本次实际使用已安装的1.0版。

## 审查与协议

- 从本地`main`（`a11ad5e`）创建`member-c-uc-ar`。开始时只有原始MAT数据、`uc_initial_test.m`、原有UC单次CSV与三张图为未跟踪文件；未改动、删除或纳入本轮提交。
- 已阅读README、分工、复现协议、B的单次/滚动程序、结果及核验方法。B的Python核验覆盖CSV结构及sMAPE，另有MATLAB MASE核验文字记录；本轮全部计算、独立核验和错误注入均使用MATLAB。
- B对照提交固定为`9225da80af22d5bbb2ddf6d727cc9db51a82968c`。比较程序通过`git show`读取两个CSV至系统临时文件，随后清理；不切换分支、不复制B目录、不修改B成果。
- 数据：作者MAT文件中的`CO2(:)`，723个月；1958-03至2018-05。原始文件SHA-256：`4227a1d932b5765418957df172b767e5a9db3422979be01e5e56eb4ad7d25092`。
- 第r轮训练`CO2(1:479+r)`，测试`CO2(480+r:503+r)`，r=1,...,220；H=24，扩展窗口。
- `forecast_origin`是最后可见训练月。首轮为1998-02，目标1998-03至2000-02；末轮为2016-05，目标2016-06至2018-05。
- UC每轮只对训练集调用`[ty,lambda]=vboxcox(y)`，再调用`modelUC(ty, [], 'LLT12', 24)`，最后`vboxcoxinv(m.py(:),lambda)`。无逆变换偏差修正或事后调参。额外检查逆变换定义域，避免工具箱内部`real()`掩盖无效复数结果。
- 本机：MATLAB `26.1.0.3346908 (R2026a) Update 5`，ECOTOOL add-on `1.0`。**包装器`m.method`返回EML，但位置参数调用的后端估计表报告CONDITIONAL SUM OF SQUARES。实际方法以逐轮估计表为准。** 检查点保留原字段、估计表及提取的`effectiveMethod`，不把包装器字段当作实际估计方法证据。后端为`modelUC0.p`，不能从其加密源码推断内部优化细节。

## AR12补充基准

项目原有协议未指定可执行的纯AR规范。论文说明其纯AR专用程序未随ECOTOOL公开，因此这里的**AR12是新增基准，不声称严格复现论文的AR**。

模型为`y(t)=c+phi(1)*y(t-1)+...+phi(12)*y(t-12)+e(t)`。在原始ppm尺度构建设计矩阵，用MATLAB反斜杠进行含截距OLS估计；不差分、不变换、不自动选阶。训练后将未来值初始化为NaN，并仅用历史观测和已经生成的预测递推24步；不读测试值。检查点保存13个系数。

单次AR使用`CO2(25:504)`训练、`CO2(505:528)`测试，与原有UC单次和B单次一致，单独保存`ar12_single_predictions.csv`。原有UC文件不覆盖。单次每行保存该步误差，前24步平均需对这24行另求均值。

## 指标口径

逐轮逐步计算：

```matlab
scale = mean(abs(y(13:end)-y(1:end-12)));
sMAPE = 200*abs(actual-predicted)./(abs(actual)+abs(predicted));
MASE = abs(actual-predicted)/scale;
```

然后对**相同步长的220轮等权平均**。`metrics_by_horizon.csv`中h=24是第24步跨轮平均，不是前24步累计平均。单次实验的累计均值不能与滚动结果混比。

**2026-11-17核实更新：** [原论文第9页公式(8)、(9)](https://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0221238&type=printable)明确对前1至h步误差取平均，因此Table 4的1年、2年行应按前12、24步累计平均对照。上轮只核对了表格附近网页文字，将口径列为待确认；现更正这一不完整判断。本文原有CSV仍保留逐步长口径，不能把h=24直接当作论文2年行。本轮整合目录另给累计指标及差值，见[最终实验总结](final_experiment_summary.md)。窗口、工具箱默认估计、变换和异常值处理仍可能造成差异，AR12也不是论文的专用AR程序。

## 文件与续跑

所有输出位于`results/rolling_c/`：

|文件|用途|
|---|---|
|`checkpoint.mat`|结构体C：数据快照、配置、环境、24×2×220预测、真实值、逐轮scale/lambda、模型参数/估计表、耗时、220×2完成标记、单次AR|
|`predictions.csv`|两模型各5280条，共10560条；附加scale列便于核查|
|`metrics_by_horizon.csv`|两模型各24行，共48行|
|`ar12_single_predictions.csv`|单次24步AR预测和逐步误差|
|`status.txt`|两模型完成数、记录数、环境、总模型耗时、最近错误|
|`audit.txt`|独立核验PASS/FAIL、范围和具体原因|
|`model_comparison.csv`|B与C四模型共96行，可按h=1、12、24筛选|
|`comparison_audit.txt`|B来源提交、共同样本与重算指标核查|
|`sMAPE_percent.png`、`MASE.png`|四模型逐步长比较|

每个模型成功后先写同目录临时MAT，重新读取检查，再替换正式检查点。预测CSV和指标CSV各自先写临时文件再替换；多文件之间不保证同时替换，核验会发现不一致。中断后正式检查点为准，忽略未完成的`.tmp`，重跑入口重建导出并继续未完成模型。异常记录到status并重新抛出，不补造预测。完成标记只表示模型返回并通过形状/有限值/尺度检查，不等同于优化器收敛证明。

完成数、预测、scale在续跑前会校验；损坏的正式检查点直接报错，不静默从零重跑。恢复时应先保留损坏文件，使用可靠备份或独立输出目录。不要手改检查点。每次入口更新输出会使旧`audit.txt`失效，需重新核验。

独立核验从原始MAT及CSV重新检查样本、唯一键、日历、真实值、ppm尺度、训练期scale和48行指标；与检查点逐值比较，并独立实现AR最小二乘及24步递推，按代数公式核对UC逆变换。绝对容差1e-9；独立AR递推容差1e-7 ppm。核验不重新估计全部UC模型，也不证明其最优化收敛或与论文数值完全一致。

## 本次运行记录

- 2026-11-16：先完成UC和AR12各3轮，144条预测、48行指标，`audit_member_c_rolling(3)`通过；随后从第4轮开始续跑。
- 另审查A分支`Ariel`（`f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6`）：`A6_rolling.m`实际为固定480个月滑动窗口`CO2(r:r+479)`，固定lambda=0.2461；与B/C的扩展窗口、逐轮重估lambda不一致。其summary CSV还是前1..h累计平均。尽管测试月份相同，训练信息与MASE分母不同，故不混入本轮同协议比较表，也不改动A代码或重跑A模型。
- 上一条为初步四模型比较时的历史处理。最终整合已在C分支增加独立的`run_member_a_unified.m`适配A模型，原A/B/C成果保留；六模型正式比较转至`results/comparison/`，原`rolling_c/model_comparison.csv`仍是历史四模型表。
- UC和AR12均已完成220轮，10,560条滚动预测和48行逐步长指标，默认220轮独立核验通过。模型计算总耗时约603.31秒；写检查点和导出CSV的额外时间不计入模型耗时。
- `verify_member_c_rolling`实测通过：已有220轮检查点续跑后预测、耗时和完成标记不变；六类故意损坏的临时数据均因预期原因被核验程序拒绝，临时文件已清理。B的10,560条预测与48行指标也已从原始数据在MATLAB中重算核对通过；比较图已目视检查。

|模型|步长|sMAPE (%)|MASE|
|---|---:|---:|---:|
|UC|1|0.077067|0.212451|
|UC|12|0.170657|0.473926|
|UC|24|0.278363|0.776801|
|AR12|1|0.082719|0.228796|
|AR12|12|0.126848|0.352756|
|AR12|24|0.150973|0.422239|

上述全部是第h步跨220轮平均。同协议四模型比较中，第1步AutoARIMA误差最低；第12、24步本次AR12误差最低。该排序只适用于本次配置和数据，不证明AR12在论文中也有此优势。完整四模型96行结果见`model_comparison.csv`。

本机后端`modelUC0.p` SHA-256：`25fec334ed21ee4d9c05e789f98b5171f43a1fdf16ab98a3f7885fd1b25017db`。所有逐轮估计表均报告CONDITIONAL SUM OF SQUARES；未为了接近论文数值而替换接口、估计方法或窗口。
