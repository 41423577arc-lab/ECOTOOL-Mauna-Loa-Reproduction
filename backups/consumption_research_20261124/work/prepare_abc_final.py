import csv,json,hashlib,shutil,io
from pathlib import Path
from datetime import date,datetime,timedelta
from decimal import Decimal
from openpyxl import load_workbook
R=Path(__file__).resolve().parents[1];W=R/'work'/'abc_final';W.mkdir(exist_ok=True)
O=R/'outputs'/'ABC_AutoARIMA_正式统一版_20261122';O.mkdir(exist_ok=True)
S=Path('C:/Users/aerith/Desktop');files={p:S/(p+ext) for p,ext in [('A','.csv'),('B','.xlsx'),('C','.csv')]}
for p,f in files.items():shutil.copy2(f,W/f.name)
def rows_csv(path):
    raw=path.read_bytes()
    for encoding in ['utf-8-sig','gb18030']:
        try:text=raw.decode(encoding);break
        except UnicodeDecodeError:continue
    rows=list(csv.reader(io.StringIO(text)));assert all(len(r)==2 for r in rows)
    return rows,encoding
def day(s):return datetime.strptime(s,'%Y/%m/%d').date() if '/' in s else date.fromisoformat(s)
a,ae=rows_csv(W/'A.csv');c,ce=rows_csv(W/'C.csv')
starts=[date(2024,9,2)+timedelta(weeks=i) for i in range(112)]
assert [day(r[0]) for r in a[1:]]==starts
series={'A':[Decimal(r[1]) for r in a[1:]]};cday={day(r[0]):Decimal(r[1]) for r in c[1:]}
assert len(cday)==len(c)-1==791
assert all(date(2024,9,1)+timedelta(days=i) in cday for i in range(791))
book=load_workbook(W/'B.xlsx',read_only=True,data_only=True);sheet=book['合并消费明细'];items=list(sheet.iter_rows(values_only=True));headers=list(items[0]);di=headers.index('交易时间');vi=headers.index('净消费（元）');wi=headers.index('周起始日')
bday={};record_dates=[]
for row in items[1:]:
    if row[di] is None:continue
    d=row[di].date();v=Decimal(str(row[vi]));assert v.is_finite() and v>=0
    assert row[wi].date()==d-timedelta(days=d.weekday())
    bday[d]=bday.get(d,Decimal('0'))+v;record_dates.append(d)
def aggregate(daily):return [sum((daily.get(s+timedelta(days=j),Decimal('0')) for j in range(7)),Decimal('0')) for s in starts]
series['B']=aggregate(bday);series['C']=aggregate(cday)
for p,v in series.items():
    assert len(v)==112 and all(x.is_finite() and x>=0 for x in v)
    with (O/f'{p}_统一自然周输入.csv').open('w',encoding='utf-8-sig',newline='') as f:
        wr=csv.writer(f);wr.writerow(['PeriodStart','Amount']);wr.writerows((d.isoformat(),f'{x:.2f}') for d,x in zip(starts,v))
equal=sum(x==y for x,y in zip(series['A'],series['B']))
config={
 'date':'2026-11-22','authoritative_sources':{p:str(f) for p,f in files.items()},
 'source_sha256':{p:hashlib.sha256((W/f.name).read_bytes()).hexdigest() for p,f in files.items()},
 'identity_rule':'以用户本轮提供的A.csv B.xlsx C.csv对应A B C，替代此前推断归属。',
 'input_details':{'A':{'frequency':'自然周','rows':112,'field':a[0][1],'encoding':ae},'B':{'frequency':'交易明细','sheet':'合并消费明细','field':'净消费（元）','rows':len(record_dates),'first':min(record_dates).isoformat(),'last':max(record_dates).isoformat()},'C':{'frequency':'日','rows':791,'field':c[0][1],'encoding':ce}},
 'common_frequency':'自然周 周一至周日','input_periods':112,'input_start':'2024-09-02','input_end':'2026-10-25','train_periods':108,'train_end':'2026-09-27',
 'rolling_training_lengths':[78,107],'rolling_folds':30,'rolling_target_start':'2026-03-02','rolling_target_end':'2026-09-21',
 'test_periods':4,'test_start':'2026-09-28','test_end':'2026-10-25',
 'function':'MATLAB ECOTOOL modelAUTO','parameters':{'u':[],'s':1,'diffs':1,'boxcox':0,'method':'CML','outlier':[0,0,0,0,0,.7,3]},
 'rolling_forecast_horizon':1,'fixed_forecast_horizon':4,'order_policy':'每折与全训练期分别自动识别阶数及漂移，不强制相同阶数。',
 'metrics':['MAE','RMSE','sMAPE 200x','MASE'],'processing':'A保留原周金额；B按交易日期汇总净消费；C按日期汇总给定总支出。共同日期范围外的数据不进入模型。不删尖峰、不做对数或Box-Cox、不额外启用自动异常调整。',
 'scope':'统一给定金额序列的聚合、划分、选模与评价；A、C无逐笔清洗资料，不能据此证明上游退款、转账等分类完全相同。',
 'A_B_equal_weeks':equal,'A_B_difference_weeks':[{'start':d.isoformat(),'A':float(x),'B':float(y)} for d,x,y in zip(starts,series['A'],series['B']) if x!=y],
 'test_totals':{p:float(sum(v[108:])) for p,v in series.items()},
 'weekly_sha256':{p:hashlib.sha256((O/f'{p}_统一自然周输入.csv').read_bytes()).hexdigest() for p in series}
}
(O/'统一实验设置与来源.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf-8')
registry={'updated':'2026-11-22','authority':'本轮用户提供的桌面A.csv B.xlsx C.csv为唯一正式来源','A':{'source':str(files['A'])},'B':{'source':str(files['B'])},'C':{'source':str(files['C'])},'current_results':str(O),'note':'此前实验身份推断作废，保留旧文件仅供历史追溯。'}
(R/'work'/'dataset_registry.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(config,ensure_ascii=False))
