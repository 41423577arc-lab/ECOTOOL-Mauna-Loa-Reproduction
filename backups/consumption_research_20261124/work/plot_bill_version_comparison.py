import csv
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs'
results=json.loads((ROOT/'work/bill_version_comparison.json').read_text(encoding='utf-8'))
with (OUT/'两版账单_ARIMA同口径滚动预测比较.csv').open(encoding='utf-8-sig') as stream:
    rows=list(csv.DictReader(stream))
assert len(rows)==61
image=Image.new('RGB',(1800,1950),'white')
draw=ImageDraw.Draw(image)
font=lambda size:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',size)
ink,muted,blue,orange,grid='#172f43','#526779','#216b91','#bc542a','#e3eaf0'
draw.text((115,35),'两份账单 ARIMA 滚动预测比较',font=font(40),fill=ink)
draw.text((115,105),'相同方法  ·  初始训练 730 天  ·  每天更新并预测次日  ·  2026 年 9–10 月共 61 轮',
          font=font(25),fill=muted)


def errors_panel(left,right,key,title,top,maximum):
    draw.text((left,top),title,font=font(28),fill=ink)
    x_start=left+200
    for index,(name,source,color) in enumerate([('最初合并账单',results['最初合并账单'],blue),
                                              ('新日账单',results['新日账单'],orange)]):
        y=top+70+index*73
        value=source[key]
        draw.text((left,y+19),name,font=font(23),fill=muted,anchor='lm')
        end=x_start+value/maximum*(right-x_start-110)
        draw.rectangle((x_start,y,end,y+37),fill=color)
        draw.text((end+12,y+18),f'{value:,.2f}',font=font(24),fill=ink,anchor='lm')


errors_panel(115,855,'MAE','每日平均绝对误差 MAE（元）',190,350)
errors_panel(1010,1715,'RMSE','每日均方根误差 RMSE（元）',190,1000)
draw.text((115,423),'两项误差均越小越好。新日账单的 MAE 高约 3%，RMSE 高约 13%。',font=font(24),fill=muted)


def lines(left,right,top,bottom,old,maximum,heading):
    draw.text((left,top-48),heading,font=font(27),fill=ink)
    for tick in range(5):
        y=bottom-(bottom-top)*tick/4
        value=maximum*tick/4
        draw.line((left,y,right,y),fill=grid,width=2)
        draw.text((left-15,y),f'{value:,.0f}',font=font(21),fill=muted,anchor='rm')
    prefix='最初账单' if old else '新账单'
    for kind,color in [('实际',blue),('预测',orange)]:
        values=[float(row[prefix+kind]) for row in rows]
        draw.line([(left+index/60*(right-left),bottom-min(value,maximum)/maximum*(bottom-top))
                   for index,value in enumerate(values)],fill=color,width=4)
    for index,label in [(0,'09-01'),(30,'10-01'),(60,'10-31')]:
        draw.text((left+index/60*(right-left),bottom+15),label,font=font(22),fill=muted,anchor='mt')


draw.text((115,495),'逐日预测与实际（元）',font=font(30),fill=ink)
for offset,(label,color) in enumerate([('实际消费',blue),('次日预测',orange)]):
    x=1120+offset*300
    draw.line((x,515,x+55,515),fill=color,width=5)
    draw.text((x+70,515),label,font=font(23),fill=muted,anchor='lm')
lines(115,855,620,850,True,8000,'最初合并账单')
lines(1010,1715,620,850,False,8000,'新日账单')
lines(115,855,1010,1225,True,1000,'最初账单 局部放大')
lines(1010,1715,1010,1225,False,1000,'新账单 局部放大')
draw.text((115,1300),'下排放大 0–1,000 元范围，超出范围的实际峰值见上排。',font=font(23),fill=muted)

draw.text((115,1380),'月度实际与逐日滚动预测合计（元）',font=font(30),fill=ink)
left,right,top,bottom=115,1715,1490,1760
maximum=15000
for tick in range(4):
    value=tick*5000
    y=bottom-value/maximum*(bottom-top)
    draw.line((left,y,right,y),fill=grid,width=2)
    draw.text((left-15,y),f'{value:,.0f}',font=font(21),fill=muted,anchor='rm')
for group,(name,index) in enumerate([('最初合并账单',0),('新日账单',0),('最初合并账单',1),('新日账单',1)]):
    month,actual,predicted=results[name]['monthly'][index]
    x=left+200+group*390
    for offset,(value,color) in enumerate([(actual,blue),(predicted,orange)]):
        bx=x-86+offset*92
        y=bottom-value/maximum*(bottom-top)
        draw.rectangle((bx,y,bx+76,bottom),fill=color)
        draw.text((bx+38,y-10),f'{value:,.0f}',font=font(22),fill=ink,anchor='mb')
    label=('原账单' if name=='最初合并账单' else '新账单')+' '+month[-2:]+'月'
    draw.text((x,bottom+22),label,font=font(23),fill=muted,anchor='mt')
draw.text((115,1850),'两份账单有 60 个检验日期的实际金额不同，图中差异同时反映数据内容的变化。',
          font=font(24),fill=muted)
draw.text((115,1900),'月度预测合计包含每日更新时已观察到的消费信息。',font=font(23),fill=muted)
image.save(OUT/'两份账单_ARIMA滚动预测对比图.png')
