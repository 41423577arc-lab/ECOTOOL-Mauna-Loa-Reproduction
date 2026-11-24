import csv,json,hashlib
from pathlib import Path
from datetime import date,timedelta
from decimal import Decimal
R=Path(__file__).resolve().parents[1];W=R/'work';O=R/'outputs'/'ABC统一AutoARIMA';O.mkdir(exist_ok=True)
def read(p):
    with Path(p).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
starts=[date(2024,9,2)+timedelta(weeks=i) for i in range(112)]
a=read(W/'A_个人总支付_自然周.csv');assert [r['周期起始日'] for r in a]==[d.isoformat() for d in starts]
aval=[Decimal(r['个人总支付_元']) for r in a]
# B: final cleaned net amounts from the user's original merged ledger.
merged=json.loads((W/'merged-data.json').read_text(encoding='utf-8'));b={}
for row in merged['details'][1:]:
    day=date(1899,12,30)+timedelta(days=int(row[0]));b[day]=b.get(day,Decimal('0'))+Decimal(str(row[7]))
# C: the supplied daily source, already preserved in the earlier experiment.
c={}
for file,col in [('newbill_train.csv','Spending'),('newbill_test.csv','Actual')]:
    for r in read(W/file):
        d=date.fromisoformat(r['Date']);assert d not in c;c[d]=Decimal(r[col])
assert len(c)==791 and all(date(2024,9,1)+timedelta(days=i) in c for i in range(791))
week=lambda daily:[sum((daily.get(d+timedelta(days=j),Decimal('0')) for j in range(7)),Decimal('0')) for d in starts]
series={'A':aval,'B':week(b),'C':week(c)}
for person,v in series.items():
    assert len(v)==112 and all(x>=0 for x in v)
    with (O/f'{person}_统一自然周输入.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.writer(f);writer.writerow(['PeriodStart','Amount']);writer.writerows((d.isoformat(),f'{x:.2f}') for d,x in zip(starts,v))
assert sum(series['A'][108:])==Decimal('4325.00')
config={
 'date':'2026-11-22','persons':{'A':'最新附件 文件名虽以C开头仍按A','B':'用户本人最初合并账单','C':'此前提供的原始日账单'},
 'common_frequency':'自然周 周一至周日','input_periods':112,'input_start':'2024-09-02','input_end':'2026-10-25',
 'train_periods':108,'train_end':'2026-09-27','rolling_training_lengths':[78,107],'rolling_folds':30,
 'rolling_target_start':starts[78].isoformat(),'rolling_target_end':starts[107].isoformat(),
 'test_periods':4,'test_start':'2026-09-28','test_end':'2026-10-25',
 'function':'ECOTOOL modelAUTO','parameters':{'s':1,'diffs':1,'boxcox':0,'method':'CML','external_inputs':[], 'outlier':[0,1,1,1,1,.7,3]},
 'rolling_forecast_horizon':1,'fixed_forecast_horizon':4,'order':'each fit automatically identifies ARIMA order and drift',
 'metrics':['MAE','RMSE','sMAPE 200x','MASE'], 'cleaning':'直接采用已整理金额 不做变换 不删峰值 不额外处理异常值 B和C按7天相加 A沿用自然周金额',
 'upstream_scope':'A没有原始流水与日账单，不能复核退款、转账等上游分类是否与B和C相同；本次统一的是所给金额序列的聚合及建模流程。B使用原始合并账单最终净额，C使用原始日账单，不使用此前UC聚合版。',
 'sources':{'A':'work/A_个人总支付_自然周.csv','B':'work/merged-data.json details 金额列','C':['work/newbill_train.csv','work/newbill_test.csv']},
 'sha256':{k:hashlib.sha256((O/f'{k}_统一自然周输入.csv').read_bytes()).hexdigest() for k in series},
 'test_totals':{k:float(sum(v[108:])) for k,v in series.items()}
}
(O/'统一实验设置.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(config,ensure_ascii=False))
