"""用输入数据独立核对MATLAB导出结果；不重新拟合或修改结果。"""
from pathlib import Path
from datetime import datetime, timedelta
import csv, json, math, hashlib
import openpyxl

root=Path(__file__).resolve().parents[2]
out=root/'output'
def read(path):
    with path.open(encoding='utf-8-sig',newline='') as f:
        return list(csv.DictReader(f))
def near(a,b):
    return math.isclose(float(a),float(b),rel_tol=1e-9,abs_tol=1e-7)
checks=[]
manifest=json.loads((out/'运行口径.json').read_text(encoding='utf-8'))
for name,digest in manifest['input_sha256'].items():
    assert hashlib.sha256((root/'data'/name).read_bytes()).hexdigest()==digest
missing_raw_sources=[]
for name,digest in manifest['raw_data_sha256'].items():
    source_path=root/'raw_data'/name
    if source_path.exists():assert hashlib.sha256(source_path.read_bytes()).hexdigest()==digest
    else:missing_raw_sources.append(name) # 公开仓库不包含原始账单，缺少时明确记录。
for person in ('A','B','C'):
    p=out/person
    assert (p/'运行完成.mat').exists()
    wb=openpyxl.load_workbook(root/'data'/f'{person}_个人总支付_自然周.xlsx',data_only=True)
    assert wb.sheetnames==['UC数据']
    raw=list(wb.active.values)[1:]
    assert len(raw)==112 and all(isinstance(r[0],datetime) for r in raw)
    assert [r[0] for r in raw]==[datetime(2024,9,2)+timedelta(weeks=i) for i in range(112)]
    values=[r[1] for r in raw]
    rolling=read(p/'UC滚动预测明细.csv')
    assert len(rolling)==120
    summary=read(p/'UC最终模型比较.csv')
    assert len(summary)==4
    for row in summary:
        model=row['Model']
        detail=[r for r in rolling if r['Model']==model]
        assert len(detail)==30
        abs_errors=[];squared=[];smape=[];mase=[]
        for k,r in enumerate(detail,start=78):
            date=datetime.fromisoformat(r['PeriodStart'][:10])
            assert date==raw[k][0]
            assert near(r['Actual'],values[k])
            pred=float(r['Forecast']);actual=float(r['Actual']);error=pred-actual
            assert math.isfinite(pred) and near(r['Error'],error)
            scale=sum(abs(values[i]-values[i-1]) for i in range(1,k))/(k-1)
            assert near(r['MASEScale'],scale)
            if model=='朴素':assert near(pred,values[k-1])
            if model=='三期移动平均':assert near(pred,sum(values[k-3:k])/3)
            abs_errors.append(abs(error));squared.append(error*error)
            smape.append(200*abs(error)/(abs(pred)+abs(actual)) if abs(pred)+abs(actual) else 0)
            mase.append(abs(error)/scale)
        assert near(row['MAE'],sum(abs_errors)/30)
        assert near(row['RMSE'],math.sqrt(sum(squared)/30))
        assert near(row['sMAPE'],sum(smape)/30)
        assert near(row['MASE'],sum(mase)/30)
    diagnostics=read(p/'UC模型残差诊断汇总.csv')
    assert len(diagnostics)==4
    passes={model:all(float(r['PValue'])>=.05 for r in diagnostics if r['Model']==f'总支付-{model}') for model in ['RW','LLT']}
    uc=[r for r in summary if r['Model'] in ('RW','LLT')]
    passing=[m for m,v in passes.items() if v]
    selected=passing[0] if len(passing)==1 else min(uc,key=lambda r:(float(r['MAE']),float(r['RMSE'])))['Model']
    test=read(p/'UC最终预测结果.csv')
    assert len(test)==4 and all(r['Model']==selected for r in test)
    for k,r in enumerate(test,start=108):
        assert r['PeriodStart'][:10]==raw[k][0].strftime('%Y-%m-%d')
        assert near(r['Actual'],values[k])
        assert near(r['Error'],float(r['Forecast'])-float(r['Actual']))
    agg=read(p/'UC独立测试汇总.csv')[0]
    errors=[float(r['Forecast'])-float(r['Actual']) for r in test]
    assert near(agg['MAE'],sum(map(abs,errors))/4)
    assert near(agg['RMSE'],math.sqrt(sum(e*e for e in errors)/4))
    assert near(agg['ForecastSum'],sum(float(r['Forecast']) for r in test))
    assert near(agg['ActualSum'],sum(values[108:]))
    stability=read(p/'UC滚动估计稳定性.csv')
    assert len(stability)==120 and not any(r['Failure'].strip() for r in stability)
    checks.append({'person':person,'rolling_rows':120,'test_rows':4,'selected_uc':selected,'independently_recomputed_metrics':'pass','failures':0})
comparison=read(out/'C新旧数值逐项核对.csv')
assert len({r['File'] for r in comparison})==12
core_comparison=[r for r in comparison if r['File']!='UC滚动估计稳定性.csv']
assert all(r['Match'] in ('1','true') for r in core_comparison)
unmatched=[r for r in comparison if r['Match'] not in ('1','true')]
assert {(r['File'],r['Column']) for r in unmatched}=={('UC滚动估计稳定性.csv','MaxScoreSE'),('UC滚动估计稳定性.csv','Failure')}
input_checks=read(out/'C输入逐项核对.csv')
assert all(r['ExactlyEqual'] in ('1','true') for r in input_checks)
result={'person_checks':checks,'missing_raw_sources':missing_raw_sources,'C_comparison_columns':len(comparison),'C_comparison_files':12,
    'C_core_results_reproduced':True,'C_all_files_identical':False,'C_recorded_differences':unmatched,'independent_calculations_passed':True}
(out/'独立计算核验.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
