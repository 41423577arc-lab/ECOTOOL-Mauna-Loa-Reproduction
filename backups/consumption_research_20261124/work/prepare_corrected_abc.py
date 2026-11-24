import csv,io,json,hashlib,shutil
from pathlib import Path
from datetime import date,datetime,timedelta
from decimal import Decimal
from collections import defaultdict
from openpyxl import load_workbook
R=Path(__file__).resolve().parents[1];W=R/'work'/'abc_corrected_20261122';W.mkdir(exist_ok=True)
O=R/'outputs'/'ABC周消费_ARIMA_修正版_20261122';O.mkdir(exist_ok=True)
sources={'A':Path('C:/Users/aerith/Desktop/成员A_周.csv'),'B':R/'work'/'abc_final'/'B.xlsx','C':Path('C:/Users/aerith/Desktop/C.xlsx')}
for k,s in sources.items():shutil.copy2(s,W/(k+s.suffix))
def csvrows(path):
    raw=path.read_bytes()
    for enc in ['utf-8-sig','gb18030']:
        try:text=raw.decode(enc);break
        except UnicodeDecodeError:continue
    return list(csv.DictReader(io.StringIO(text))),enc
def asdate(v):
    if isinstance(v,datetime):return v.date()
    if isinstance(v,date):return v
    v=str(v).strip();return datetime.strptime(v,'%Y/%m/%d').date() if '/' in v else date.fromisoformat(v[:10])
def amount(v):
    x=Decimal(str(v));assert x.is_finite() and x>=0;assert abs(x-x.quantize(Decimal('.01')))<Decimal('.000001');return x.quantize(Decimal('.01'))
starts=[date(2024,9,2)+timedelta(weeks=i) for i in range(112)];startset=set(starts);series={};audit=[]
a,enc=csvrows(W/'A.csv');assert {'周期起始日','个人总支付_元'}.issubset(a[0]);ad=[asdate(r['周期起始日']) for r in a]
assert len(a)==112 and ad==starts and len(set(ad))==112
series['A']=[amount(r['个人总支付_元']) for r in a]
audit.append({'Member':'A','File':str(sources['A']),'Sheet':'CSV','DateField':'周期起始日','AmountField':'个人总支付_元','SourceRows':len(a),'WeeklyN':112,'Start':starts[0].isoformat(),'End':'2026-10-25','Total':str(sum(series['A'])),'Encoding':enc})
b=load_workbook(W/'B.xlsx',read_only=True,data_only=True);rows=list(b['合并消费明细'].values);h=list(rows[0]);wi=h.index('周起始日');vi=h.index('净消费（元）');ti=h.index('交易时间');sums=defaultdict(lambda:Decimal('0'));excluded=0
for r in rows[1:]:
    d=asdate(r[wi]);actual=asdate(r[ti]);assert d==actual-timedelta(days=actual.weekday())
    v=amount(r[vi]);
    if d in startset:sums[d]+=v
    else:excluded+=1
assert all(d in sums for d in starts)
series['B']=[sums[d] for d in starts]
audit.append({'Member':'B','File':str(sources['B']),'Sheet':'合并消费明细','DateField':'周起始日','AmountField':'净消费（元）','SourceRows':len(rows)-1,'WeeklyN':112,'Start':starts[0].isoformat(),'End':'2026-10-25','Total':str(sum(series['B'])),'ExcludedTransactions':excluded,'ApprovedSubstitution':'用户确认用已核验留存B.xlsx；附件B.csv为退款前金额，未用于模型'})
c=load_workbook(W/'C.xlsx',read_only=True,data_only=True);rows=list(c['03_周期统计'].values);h=list(rows[0]);di=h.index('起始日期');ei=h.index('终止日期');vi=h.index('个人总支付_元');ri=h.index('常规支付_元');oi=h.index('偶发支出剔除_元');records=rows[1:]
assert len(records)==112 and [asdate(r[di]) for r in records]==starts
assert all(asdate(r[ei])==asdate(r[di])+timedelta(days=6) for r in records)
assert all(abs(amount(r[vi])-amount(r[ri])-amount(r[oi]))<Decimal('.01') for r in records)
series['C']=[amount(r[vi]) for r in records]
regular=sum(amount(r[ri]) for r in records)
audit.append({'Member':'C','File':str(sources['C']),'Sheet':'03_周期统计','DateField':'起始日期','AmountField':'个人总支付_元','SourceRows':112,'WeeklyN':112,'Start':starts[0].isoformat(),'End':'2026-10-25','Total':str(sum(series['C'])),'RegularTotalNotUsed':str(regular),'TotalEqualsRegularPlusIrregular':True})
expected={'A':Decimal('64470.55'),'B':Decimal('114959.44'),'C':Decimal('88773.97')}
for p,values in series.items():
    # Expected totals are checked only after reading and summing source fields.
    assert sum(values)==expected[p],(p,sum(values),expected[p])
    with (O/f'{p}_112周建模输入.csv').open('w',encoding='utf-8-sig',newline='') as f:
        wr=csv.writer(f);wr.writerow(['PeriodStart','Amount']);wr.writerows((d.isoformat(),f'{v:.2f}') for d,v in zip(starts,values))
    with (O/f'{p}_数据核验.json').open('w',encoding='utf-8') as f:json.dump(next(x for x in audit if x['Member']==p),f,ensure_ascii=False,indent=2)
pairwise={p+q:sum(x==y for x,y in zip(series[p],series[q])) for p,q in [('A','B'),('A','C'),('B','C')]}
with (O/'ABC_输入数据核验表.csv').open('w',encoding='utf-8-sig',newline='') as f:
    wr=csv.writer(f);wr.writerow(['Member','Source','Sheet','DateField','AmountField','SourceRows','Weeks','FirstWeekStart','LastWeekStart','LastWeekEnd','ComputedTotal','MissingWeeks','DuplicateWeeks','InvalidAmounts'])
    for r in audit:wr.writerow([r['Member'],Path(r['File']).name,r['Sheet'],r['DateField'],r['AmountField'],r['SourceRows'],112,'2024-09-02','2026-10-19','2026-10-25',r['Total'],0,0,0])
config={'date':'2026-11-22','sources':audit,'source_sha256':{k:hashlib.sha256((W/(k+s.suffix)).read_bytes()).hexdigest() for k,s in sources.items()},'pairwise_equal_weeks':pairwise,'source_identity':'本轮新成员A_周.csv与C.xlsx替代旧同名标签数据；B使用用户已确认的留存工作簿净额。',
 'parameters':{'function':'MATLAB ECOTOOL modelAUTO','u':[],'s':1,'diffs':1,'boxcox':0,'outlier':[0,0,0,0,0,.7,3],'method':'CML'},
 'train_weeks':108,'train_end':'2026-09-27','rolling_folds':30,'rolling_training_lengths':[78,107],'rolling_targets':['2026-03-02','2026-09-21'],'test_weeks':4,'test_interval':['2026-09-28','2026-10-25'],
 'baseline_rules':{'Naive':'滚动用历史最后一期；固定原点4步均取训练最后一期。','HistoricalMean':'滚动每折重算该折全部训练均值；固定原点4步均取108周训练均值。'},
 'metrics':['MAE','RMSE','sMAPE 200x','MASE per-fold training scale'],'processing':'仅统一周期和金额字段，使用原金额，不删除尖峰、不变换、不额外调异常；日期和金额先验证再与提示统计值比对。',
 'residual_diagnostics':'全108周ARIMA训练拟合的一步创新；仅取有限值；ACF 12阶、经验标准化直方图与正态QQ图、Ljung-Box 6/12阶及Jarque-Bera。',
 'limitations':'A/C为已聚合源表，B为净消费明细；相同建模流程不代表可重新核验全部上游逐笔分类。测试只有4周，残差未拒绝检验不能证明白噪声或正态。'}
(O/'实验设置与来源核验.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf-8')
registry={'updated':'2026-11-22','authority':'当前用户修正版要求及原字段重新读取；B替代来源已经用户明确确认','members':{x['Member']:x for x in audit},'current_results':str(O),'note':'此次成员A不是旧A.csv；成员C使用03_周期统计的个人总支付，不是常规支付。旧A/B同源结论仅适用于上一轮旧A.csv，不适用于此次新成员A_周.csv。'}
(R/'work'/'dataset_registry.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(config,ensure_ascii=False))
