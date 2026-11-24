import csv
import json
from pathlib import Path
from datetime import date, timedelta
from statistics import mean
from math import sqrt

from PIL import Image, ImageDraw, ImageFont


ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs'
WORK=ROOT/'work'


def read(path):
    with path.open(encoding='utf-8-sig') as stream:
        return list(csv.DictReader(stream))


raw=read(Path('D:/电脑管家迁移文件/xwechat_files/wxid_a1rf8kib9lsh22_0945/msg/file/2026-11/原始账单_时间粒度为日.csv'))
test=[row for row in raw if '2026-09-01'<=row['日期']<='2026-10-31']
assert len(test)==61
import sys
if sys.argv[-1]=='prepare':
    with (WORK/'newbill_test.csv').open('w',newline='',encoding='utf-8') as stream:
        writer=csv.writer(stream)
        writer.writerow(['Date','Actual'])
        writer.writerows([row['日期'],row['总支出_元']] for row in test)
    sys.exit()

rows=read(WORK/'newbill_rolling_output.csv')
fixed=read(WORK/'newbill_model_output.csv')
assert len(rows)==61 and len(fixed)==61
for index,row in enumerate(rows):
    assert int(row['Round'])==index+1 and int(row['TrainingDays'])==730+index
    assert date.fromisoformat(row['TrainingEnd'])+timedelta(days=1)==date.fromisoformat(row['Date'])
    assert row['Date']==test[index]['日期']
    assert abs(float(row['Actual'])-float(test[index]['总支出_元']))<1e-8
    for key in ('Actual','Forecast','StdForecast','MeanBaseline'):
        assert __import__('math').isfinite(float(row[key]))
metrics={}
for label,predictions in [('逐日滚动ARIMA',[float(row['Forecast']) for row in rows]),
                          ('固定起点ARIMA',[float(row['Forecast']) for row in fixed]),
                          ('滚动历史均值',[float(row['MeanBaseline']) for row in rows])]:
    errors=[pred-float(row['Actual']) for pred,row in zip(predictions,rows)]
    metrics[label]={'MAE':mean(map(abs,errors)),'RMSE':sqrt(mean(error*error for error in errors))}
with (OUT/'新日账单_ARIMA逐日滚动预测.csv').open('w',newline='',encoding='utf-8-sig') as stream:
    writer=csv.writer(stream)
    writer.writerow(['轮次','预测日期','训练截止日','训练天数','实际消费（元）','次日预测（元）',
                     '预测减实际（元）','滚动均值（元）','近似95%下限','近似95%上限','模型结构'])
    for row in rows:
        actual,pred,std,baseline=[float(row[key]) for key in ('Actual','Forecast','StdForecast','MeanBaseline')]
        writer.writerow([row['Round'],row['Date'],row['TrainingEnd'],row['TrainingDays'],
                         *[f'{value:.2f}' for value in (actual,pred,pred-actual,baseline,pred-1.96*std,pred+1.96*std)],
                         row['Model']])
monthly=[]
for month in ('2026-09','2026-10'):
    subset=[row for row in rows if row['Date'].startswith(month)]
    actual=sum(float(row['Actual']) for row in subset)
    predicted=sum(float(row['Forecast']) for row in subset)
    monthly.append([month,actual,predicted,predicted-actual])
with (OUT/'新日账单_ARIMA滚动预测月度核对.csv').open('w',newline='',encoding='utf-8-sig') as stream:
    writer=csv.writer(stream)
    writer.writerow(['月份','实际消费（元）','逐日一步预测合计（元）','预测减实际（元）'])
    writer.writerows([row[0],*[f'{value:.2f}' for value in row[1:]]] for row in monthly)

image=Image.new('RGB',(1800,1120),'white')
draw=ImageDraw.Draw(image)
font=lambda size:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',size)
draw.text((145,28),'ARIMA 逐日滚动一步预测与实际',font=font(36),fill='#172f43')
draw.text((145,90),'首轮训练 2024-09-01 至 2026-08-31  ·  每天加入前一天实际值并重新拟合',
          font=font(25),fill='#526679')
draw.text((145,140),f'61 轮  ·  2026 年 9–10 月  ·  每日 MAE {metrics["逐日滚动ARIMA"]["MAE"]:,.2f} 元',
          font=font(25),fill='#526679')
for index,(label,color) in enumerate([('实际消费','#21628a'),('次日滚动预测','#b95027')]):
    x=145+index*380
    draw.line((x,208,x+55,208),fill=color,width=5)
    draw.text((x+70,208),label,font=font(24),fill='#344f63',anchor='lm')


def panel(top,bottom,maximum,title):
    left,right=145,1720
    draw.text((left,top-42),title,font=font(24),fill='#344f63')
    for tick in range(5):
        value=maximum*tick/4
        y=bottom-(bottom-top)*tick/4
        draw.line((left,y,right,y),fill='#e1e8ed',width=2)
        draw.text((left-18,y),f'{value:,.0f}',font=font(22),fill='#526679',anchor='rm')
    for key,color in [('Actual','#21628a'),('Forecast','#b95027')]:
        points=[(left+index/60*(right-left),bottom-min(float(row[key]),maximum)/maximum*(bottom-top))
                for index,row in enumerate(rows)]
        draw.line(points,fill=color,width=4)
    for index in (0,12,24,36,48,60):
        draw.text((left+index/60*(right-left),bottom+16),rows[index]['Date'],
                  font=font(22),fill='#526679',anchor='mt')


maximum=max(float(row[key]) for row in rows for key in ('Actual','Forecast'))*1.07
panel(305,590,maximum,'完整金额范围（元）')
panel(775,1005,1000,'局部放大 0 至 1,000 元  ·  超出范围的峰值见上图')
draw.text((145,1080),'月度数字是逐日更新后的预测合计，评估时只使用目标日期之前的数据。',
          font=font(23),fill='#526679')
image.save(OUT/'新日账单_ARIMA逐日滚动预测折线图.png')
result={'rounds':61,'metrics':metrics,'monthly':monthly,'forecast_min':min(float(row['Forecast']) for row in rows),
        'forecast_max':max(float(row['Forecast']) for row in rows)}
(WORK/'newbill_rolling_summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
