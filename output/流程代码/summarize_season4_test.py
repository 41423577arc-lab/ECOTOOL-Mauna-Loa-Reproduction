from pathlib import Path
import csv,json,hashlib
root=Path(__file__).resolve().parents[2];out=root/'output/季节周期4测试'
def read(name):
 with (out/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
comparison=read('与无季节模型配对比较.csv');choices=read('按原规则选定的季节模型.csv');tests=read('季节周期4测试预测.csv')
assert len(comparison)==12
gain_mae=sum(float(r['MAEImprovementPct'])>0 for r in comparison);gain_rmse=sum(float(r['RMSEImprovementPct'])>0 for r in comparison)
lines=['# 成员A修正后季节周期4测试','',f'三位成员按A、B、C统一命名并重新运行。12项配对比较中MAE改善{gain_mae}项、RMSE改善{gain_rmse}项。当前结果不支持用周期4替代主流程。','',
 'A使用新确认CSV的个人总支付列，112周合计88,167.33元；B为114,959.44元，C为88,773.97元。此前错误A数据上的季节结果已移出当前目录。','',
 'UC季节周期4对应RW4和LLT4，即周度序列每4周一个周期，不是季度，也不是ARIMA季节AR阶数。训练108周，初始78周扩展验证30折，固定原点测试4周；CML调用和UC选择规则与主流程一致。','',
 '| 成员 | 阶段 | 对照 | 原模型MAE | 周期4 MAE | MAE改善率 | 原RMSE | 周期4 RMSE |',
 '| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |']
for r in comparison:
 lines.append(f"| {r['Person']} | {r['Stage']} | {r['Baseline']}→{r['Seasonal']} | {float(r['BaselineMAE']):,.2f} | {float(r['SeasonalMAE']):,.2f} | {float(r['MAEImprovementPct']):.2f}% | {float(r['BaselineRMSE']):,.2f} | {float(r['SeasonalRMSE']):,.2f} |")
lines+=['','改善率为原误差减新误差后除以原误差，正值表示提升，负值表示退化。sMAPE及MASE见配对CSV。','',
 '## 季节候选选择与异常','',
 '| 成员 | 季节候选内选择 | RW4两阶检验 | LLT4两阶检验 |','| --- | --- | --- | --- |']
for r in choices:
 def label(v):return '均未拒绝零自相关' if v in ['1','true'] else '检出自相关'
 lines.append(f"| {r['Person']} | {r['SelectedSeasonalUC']} | {label(r['RW4Pass'])} | {label(r['LLT4Pass'])} |")
lines+=['','当两种候选同时未通过诊断时，原规则仍以滚动MAE、RMSE选相对较低者，不表示其合格或优于无季节模型。诊断检验不能替代实际预测效果。','']
for person in ['A','B','C']:
 rr=[r for r in tests if r['Person']==person and r['Model']=='RW4']
 lines.append('成员'+person+'的RW4四周预测为'+ '、'.join(f"{float(r['Forecast']):,.2f}" for r in rr)+'元，实际为'+ '、'.join(f"{float(r['Actual']):,.2f}" for r in rr)+'元。')
lines+=['','原始预测未截零或另作修正。大额相位摆动及负金额预测提示所拟合的4周季节结构与保留期不匹配；这并不证明所有季节周期均无效。季节模型返回102个有限创新，无季节为106个，不强行对齐其初始化日期，也不据不同有效样本的样本内拟合排名。','',
 '## 核验和复现','',
 '本轮180次滚动预测、24条季节模型固定预测均完成。独立核验重算12行指标及12项配对改善率，未删除失败折、未填入实际值代替预测。两种季节模型四步预测落盘后读取本轮测试金额，选择只依据训练诊断和滚动结果；已有历史测试此前已观察过，不是新的前瞻验证。','',
 '在MATLAB运行根目录run_season4_test。原无季节主流程的本轮选择为A使用LLT、B和C使用RW；主报告不因季节测试或测试期误差而重新选模。实验模型、逐期数据和图表在A、B、C子目录。']
(out/'季节周期4测试结论.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
settings={'seasonal_period':4,'period_unit':'周','members':['A','B','C'],'models':['RW4','LLT4'],'training_n':108,'rolling_initial':78,'rolling_n':30,'test_n':4,'baseline_label':'本轮修正A后的无季节UC结果','A_total':88167.33,'mae_improved_cases':gain_mae,'rmse_improved_cases':gain_rmse,'input_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'data').glob('*.xlsx')},'experiment_source_sha256':hashlib.sha256((root/'run_season4_test.m').read_bytes()).hexdigest()}
(out/'实验设置.json').write_text(json.dumps(settings,ensure_ascii=False,indent=2),encoding='utf8')
print('Seasonal summary updated')
