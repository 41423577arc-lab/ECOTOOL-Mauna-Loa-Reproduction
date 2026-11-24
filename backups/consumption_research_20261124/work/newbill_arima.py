import csv
import json
import sys
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from statistics import mean
from math import sqrt

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('D:/电脑管家迁移文件/xwechat_files/wxid_a1rf8kib9lsh22_0945/msg/file/2026-11/原始账单_时间粒度为日.csv')
with SOURCE.open(encoding='utf-8-sig', newline='') as stream:
    rows = list(csv.DictReader(stream))
daily = {}
for row in rows:
    day = date.fromisoformat(row['日期'])
    assert day not in daily, ('duplicate day', day)
    daily[day] = Decimal(row['总支出_元'])
dates = sorted(daily)
missing = [dates[0]+timedelta(days=index) for index in range((dates[-1]-dates[0]).days+1)
           if dates[0]+timedelta(days=index) not in daily]
assert not missing, missing
assert all(value >= 0 and value.is_finite() for value in daily.values())
cutoff = date(2026,8,31)
assert dates[0] <= cutoff < dates[-1]
train = [day for day in dates if day <= cutoff]
test = [day for day in dates if cutoff < day <= date(2026,10,31)]
assert len(test) == 61
if sys.argv[-1] == 'prepare':
    with (ROOT/'work/newbill_train.csv').open('w',newline='',encoding='utf-8') as stream:
        writer=csv.writer(stream)
        writer.writerow(['Date','Spending'])
        writer.writerows([day,daily[day]] for day in train)
    print('rows',len(rows),'date range',dates[0],dates[-1],'train',len(train),'test',len(test),
          'zero days',sum(value==0 for value in daily.values()),'sum',sum(daily.values()))
    sys.exit()

with (ROOT/'work/newbill_model_output.csv').open(encoding='utf-8-sig') as stream:
    predictions=list(csv.DictReader(stream))
assert len(predictions) == len(test)
predicted=[float(row['Forecast']) for row in predictions]
standard=[float(row['StdForecast']) for row in predictions]
assert all(value>=0 for value in standard)
errors=[prediction-float(daily[day]) for prediction,day in zip(predicted,test)]
mae=mean(map(abs,errors))
rmse=sqrt(mean(value*value for value in errors))
baseline=float(sum(daily[day] for day in train)/len(train))
baseline_mae=mean(abs(baseline-float(daily[day])) for day in test)
output=ROOT/'outputs'
with (output/'新日账单_ARIMA预测与实际.csv').open('w',newline='',encoding='utf-8-sig') as stream:
    writer=csv.writer(stream)
    writer.writerow(['日期','实际消费（元）','ARIMA预测（元）','近似95%预测下限（元）',
                     '近似95%预测上限（元）','历史均值预测（元）','预测减实际（元）'])
    writer.writerows([day,*[f'{value:.2f}' for value in [float(daily[day]),estimate,
                    estimate-1.96*std,estimate+1.96*std,baseline,error]]]
                    for day,estimate,std,error in zip(test,predicted,standard,errors))
months=[]
for month in (9,10):
    indexes=[index for index,day in enumerate(test) if day.month==month]
    real=float(sum(daily[test[index]] for index in indexes))
    forecast=sum(predicted[index] for index in indexes)
    months.append([f'2026-{month:02d}',round(real,2),round(forecast,2),round(forecast-real,2)])
with (output/'新日账单_ARIMA月度核对.csv').open('w',newline='',encoding='utf-8-sig') as stream:
    writer=csv.writer(stream)
    writer.writerow(['月份','实际消费（元）','预测消费（元）','预测减实际（元）'])
    writer.writerows(months)

image=Image.new('RGB',(1800,850),'white')
draw=ImageDraw.Draw(image)
font=lambda size:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',size)
draw.text((140,30),'新日账单 ARIMA 固定训练集预测',font=font(36),fill='#172f43')
draw.text((140,90),f'训练 {train[0]} 至 {cutoff}  ·  实际对照 2026 年 9–10 月',font=font(25),fill='#526679')
draw.text((140,140),f'每日 MAE {mae:,.2f} 元  ·  历史均值 MAE {baseline_mae:,.2f} 元',font=font(24),fill='#526679')
left,top,right,bottom=140,270,1720,690
lower=[value-1.96*std for value,std in zip(predicted,standard)]
upper=[value+1.96*std for value,std in zip(predicted,standard)]
low=min(0,min(lower))
high=max(max(upper),max(float(daily[day]) for day in test))*1.08
xy=lambda index,value:(left+index/(len(test)-1)*(right-left),bottom-(value-low)/(high-low)*(bottom-top))
for tick in range(6):
    value=low+(high-low)*tick/5
    y=xy(0,value)[1]
    draw.line((left,y,right,y),fill='#e1e8ed',width=2)
    draw.text((left-18,y),f'{value:,.0f}',font=font(22),fill='#526679',anchor='rm')
draw.polygon([xy(index,value) for index,value in enumerate(upper)]+
             [xy(index,lower[index]) for index in reversed(range(len(test)))],fill='#fae5d8')
for values,color in [([float(daily[day]) for day in test],'#21628a'),(predicted,'#b95027')]:
    draw.line([xy(index,value) for index,value in enumerate(values)],fill=color,width=4)
for index in [0,12,24,36,48,60]:
    x=xy(index,0)[0]
    draw.text((x,bottom+25),test[index].isoformat(),font=font(22),fill='#526679',anchor='mt')
for index,(label,color) in enumerate([('实际消费','#21628a'),('ARIMA点预测','#b95027'),('近似95%预测区间','#fae5d8')]):
    x=left+index*400
    draw.line((x,218,x+55,218),fill=color,width=10 if index==2 else 5)
    draw.text((x+70,218),label,font=font(24),fill='#344f63',anchor='lm')
draw.text((left,top-32),'每日消费（元）',font=font(22),fill='#526679')
draw.text((left,785),'预测区间采用模型标准差的正态近似，保留负下限以显示模型假设。',font=font(22),fill='#526679')
image.save(output/'新日账单_ARIMA预测折线图.png')
result={'model':predictions[0]['Model'],'train_start':str(train[0]),'train_end':str(cutoff),
        'train_days':len(train),'test_days':len(test),'daily_mae':mae,'daily_rmse':rmse,
        'baseline_mae':baseline_mae,'forecast_min':min(predicted),'forecast_max':max(predicted),
        'monthly':months}
(ROOT/'work/newbill_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
