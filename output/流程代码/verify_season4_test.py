"""独立重算季节周期4实验的全部误差与配对比较。"""
from pathlib import Path
import csv,json,math
import openpyxl
root=Path(__file__).resolve().parents[2];out=root/'output'/'季节周期4测试'
def read(path):
 with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def near(a,b):return math.isclose(float(a),float(b),rel_tol=1e-9,abs_tol=1e-6)
def metric(actual,pred,scale):
 errors=[p-a for p,a in zip(pred,actual)]
 return {'MAE':sum(map(abs,errors))/len(errors),'RMSE':math.sqrt(sum(e*e for e in errors)/len(errors)),
         'sMAPE':sum(200*abs(p-a)/(abs(p)+abs(a)) if abs(p)+abs(a) else 0 for p,a in zip(pred,actual))/len(errors),
         'MASE':sum(abs(e)/s for e,s in zip(errors,scale))/len(errors)}
metrics=read(out/'季节周期4误差指标.csv');rolling=read(out/'季节周期4滚动明细.csv');tests=read(out/'季节周期4测试预测.csv')
comparison=read(out/'与无季节模型配对比较.csv');choices=read(out/'按原规则选定的季节模型.csv');diagnostics=read(out/'季节周期4残差诊断.csv')
assert len(metrics)==12 and len(rolling)==180 and len(tests)==24 and len(comparison)==12
base=read(root/'output'/'报告四模型性能汇总.csv')
for person in ['A','B','C']:
 wb=openpyxl.load_workbook(root/'data'/f'{person}_个人总支付_自然周.xlsx',data_only=True)
 rows=list(wb.active.values)[1:];values=[r[1] for r in rows]
 for model in ['RW4','LLT4']:
  for stage in ['滚动30折','测试4期']:
   detail=[r for r in (rolling if stage=='滚动30折' else tests) if r['Person']==person and r['Model']==model]
   begin=78 if stage=='滚动30折' else 108
   assert len(detail)==(30 if begin==78 else 4)
   for k,r in enumerate(detail,start=begin):
    assert r['PeriodStart'][:10]==rows[k][0].strftime('%Y-%m-%d')
    assert near(r['Actual'],values[k]) and near(r['Error'],float(r['Forecast'])-values[k])
    assert math.isfinite(float(r['Forecast']))
    if stage=='滚动30折':
     assert not r['Failure'].strip()
     scale=sum(abs(values[i]-values[i-1]) for i in range(1,k))/(k-1)
     assert near(r['MASEScale'],scale)
   scales=[float(r['MASEScale']) for r in detail] if begin==78 else [sum(abs(values[i]-values[i-1]) for i in range(1,108))/107]*4
   observed=[float(r['Actual']) for r in detail];predicted=[float(r['Forecast']) for r in detail]
   expect=metric(observed,predicted,scales)
   m=next(r for r in metrics if r['Person']==person and r['Model']==model and r['Stage']==stage)
   assert int(m['N'])==len(detail)
   for key,v in expect.items():assert near(m[key],v),(person,model,stage,key)
   old_model=model[:-1]
   old=next(r for r in base if r['Person']==person and r['Model']==old_model and r['Stage']==stage)
   c=next(r for r in comparison if r['Person']==person and r['Seasonal']==model and r['Stage']==stage)
   for metric_name in ['MAE','RMSE','sMAPE','MASE']:
    suffix={'sMAPE':'SMAPE'}.get(metric_name,metric_name)
    assert near(c['Baseline'+suffix],old[metric_name]) and near(c['Seasonal'+suffix],m[metric_name])
   for key in ['MAE','RMSE']:assert near(c[key+'ImprovementPct'],100*(float(old[key])-float(m[key]))/float(old[key]))
 selected=next(r for r in choices if r['Person']==person)['SelectedSeasonalUC']
 passes={model:all(float(r['PValue'])>=.05 for r in diagnostics if r['Person']==person and r['Model']==model) for model in ['RW4','LLT4']}
 passing=[m for m,p in passes.items() if p]
 ranking=[r for r in metrics if r['Person']==person and r['Stage']=='滚动30折']
 expected=passing[0] if len(passing)==1 else min(ranking,key=lambda r:(float(r['MAE']),float(r['RMSE'])))['Model']
 assert selected==expected
result={'models':['RW4','LLT4'],'rolling_forecast_rows_checked':180,'fixed_forecast_rows_checked':24,'metric_rows_checked':12,'paired_comparison_rows_checked':12,'all_checks_passed':True}
(out/'独立核验.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
