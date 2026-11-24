import csv
import json
from collections import Counter
from pathlib import Path
from statistics import mean
from math import sqrt


ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work'
OUT=ROOT/'outputs'


def read(name):
    with (WORK/name).open(encoding='utf-8-sig') as stream:
        return list(csv.DictReader(stream))


old=read('originalbill_rolling_output.csv')
new=read('newbill_rolling_output.csv')
assert len(old)==len(new)==61
metrics={}
for label,rows in [('最初合并账单',old),('新日账单',new)]:
    errors=[float(row['Forecast'])-float(row['Actual']) for row in rows]
    baseline=[float(row['MeanBaseline'])-float(row['Actual']) for row in rows]
    metrics[label]={
        'MAE':mean(map(abs,errors)),
        'RMSE':sqrt(mean(value*value for value in errors)),
        'baseline_MAE':mean(map(abs,baseline)),
        'actual_daily_mean':mean(float(row['Actual']) for row in rows),
        'monthly':[[month,sum(float(row['Actual']) for row in rows if row['Date'].startswith(month)),
                    sum(float(row['Forecast']) for row in rows if row['Date'].startswith(month))]
                   for month in ['2026-09','2026-10']],
        'models':dict(Counter(row['Model'] for row in rows)),
    }
output=[]
for index,(before,after) in enumerate(zip(old,new)):
    assert before['Date']==after['Date'] and before['TrainingEnd']==after['TrainingEnd']
    assert int(before['TrainingDays'])==int(after['TrainingDays'])==730+index
    output.append([before['Date'],*[float(row[key]) for row in (before,after) for key in ('Actual','Forecast')],
                   float(after['Actual'])-float(before['Actual'])])
with (OUT/'两版账单_ARIMA同口径滚动预测比较.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.writer(stream)
    writer.writerow(['预测日期','最初账单实际','最初账单预测','新账单实际','新账单预测','新减旧实际差额'])
    writer.writerows([row[0],*[f'{number:.2f}' for number in row[1:]]] for row in output)
print(json.dumps(metrics,ensure_ascii=False,indent=2))
differences=sorted([(row[0],row[-1]) for row in output],key=lambda row:abs(row[1]),reverse=True)
print('changed_test_days',sum(abs(row[-1])>.001 for row in output),'largest_differences',differences[:5])
(WORK/'bill_version_comparison.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf-8')
