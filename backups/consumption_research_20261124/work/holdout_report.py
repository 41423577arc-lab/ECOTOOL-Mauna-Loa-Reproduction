import csv
from datetime import date, timedelta
from pathlib import Path
from statistics import mean
from math import sqrt

from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn


ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs'
WORK=ROOT/'work'


def read(name):
    with (WORK/name).open(encoding='utf-8-sig') as stream:
        return list(csv.DictReader(stream))


actual=read('holdout_daily_actual.csv')
daily=read('holdout_daily_forecast.csv')
weekly=read('holdout_weekly_forecast.csv')
actual_by_date={date.fromisoformat(row['Date']):float(row['Actual']) for row in actual}
assert len(actual_by_date)==61 and len(daily)==91 and len(weekly)==14
day_rows=[]
for index,row in enumerate(actual):
    day_rows.append([row['Date'],float(row['Actual']),float(daily[index]['Forecast'])])
week_rows=[]
for index,row in enumerate(weekly):
    begin=date(2026,8,31)+timedelta(weeks=index)
    days=[begin+timedelta(days=offset) for offset in range(7)]
    if all(day in actual_by_date for day in days):
        week_rows.append([begin.isoformat(),sum(actual_by_date[day] for day in days),float(row['Forecast'])])
assert len(week_rows)==7
monthly=[]
for month in (9,10):
    days=[row for row in day_rows if date.fromisoformat(row[0]).month==month]
    actual_total=sum(row[1] for row in days)
    daily_total=sum(row[2] for row in days)
    weekly_total=0.
    for index,row in enumerate(weekly):
        begin=date(2026,8,31)+timedelta(weeks=index)
        covered=sum(day in actual_by_date and day.month==month for day in [begin+timedelta(days=offset) for offset in range(7)])
        weekly_total+=float(row['Forecast'])*covered/7
    monthly.append([f'2026-{month:02d}',actual_total,daily_total,weekly_total])
assert round(monthly[0][1],2)==11772.04 and round(monthly[1][1],2)==4323.72
for label,rows in [('日频',day_rows),('周频',week_rows)]:
    errors=[pred-real for _,real,pred in rows]
    print(label,'MAE',mean(map(abs,errors)),'RMSE',sqrt(mean(value*value for value in errors)))
for row in monthly:
    print('MONTH',row)
with (OUT/'ARIMA固定训练集_9至10月实际预测对照.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.writer(stream)
    writer.writerow(['频率','目标日期或周起始日','实际消费（元）','预测消费（元）'])
    for label,rows in [('日频',day_rows),('完整周',week_rows)]:
        writer.writerows([label,day,f'{real:.2f}',f'{pred:.2f}'] for day,real,pred in rows)


def chart(rows,title,subtitle,name):
    image=Image.new('RGB',(1800,700),'white')
    draw=ImageDraw.Draw(image)
    font=lambda size:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',size)
    draw.text((145,30),title,font=font(35),fill='#172f43')
    draw.text((145,90),subtitle,font=font(24),fill='#526679')
    left,top,right,bottom=145,210,1720,580
    values=[value for _,real,pred in rows for value in (real,pred)]
    maximum=max(values)*1.10
    for tick in range(5):
        y=bottom-(bottom-top)*tick/4
        draw.line((left,y,right,y),fill='#e1e8ed',width=2)
        draw.text((left-20,y),f'{maximum*tick/4:,.0f}',font=font(22),fill='#526679',anchor='rm')
    dates=[date.fromisoformat(row[0]) for row in rows]
    first,last=dates[0].toordinal(),dates[-1].toordinal()
    for index in sorted({round((len(rows)-1)*portion/5) for portion in range(6)}):
        x=left+(dates[index].toordinal()-first)/(last-first)*(right-left)
        draw.text((x,bottom+25),dates[index].isoformat(),font=font(22),fill='#526679',anchor='mt')
    for offset,(label,column,color) in enumerate([('实际消费',1,'#21628a'),('固定训练集预测',2,'#b95027')]):
        lx=left+offset*360
        draw.line((lx,159,lx+60,159),fill=color,width=5)
        draw.text((lx+80,159),label,font=font(25),fill='#334f62',anchor='lm')
        points=[(left+(day.toordinal()-first)/(last-first)*(right-left),bottom-row[column]/maximum*(bottom-top))
                for day,row in zip(dates,rows)]
        draw.line(points,fill=color,width=4)
        if len(rows)<15:
            for x,y in points:
                draw.ellipse((x-5,y-5,x+5,y+5),fill=color)
    draw.text((left,top-27),'消费金额（元）',font=font(22),fill='#526679')
    draw.text(((left+right)/2,666),'横轴为实际消费发生日期或消费周起始日',font=font(22),fill='#526679',anchor='mm')
    image.save(OUT/name)


chart(day_rows,'固定训练集 日消费预测与实际',
      '训练 2024-09-01 至 2026-08-31  ·  检验 2026-09-01 至 2026-10-31',
      'arima-fixed-holdout-daily.png')
chart(week_rows,'固定训练集 周消费预测与实际',
      '训练 104 个完整周至 2026-08-30  ·  检验期内 7 个完整周',
      'arima-fixed-holdout-weekly.png')

doc=Document()
sec=doc.sections[0]
sec.page_width,sec.page_height=Inches(8.5),Inches(11)
sec.top_margin=sec.bottom_margin=Inches(.65)
sec.left_margin=sec.right_margin=Inches(.7)
for name,size in [('Normal',11),('Title',22),('Heading 1',15)]:
    style=doc.styles[name]
    style.font.name='Microsoft YaHei'
    style.element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'Microsoft YaHei')
    style.font.size=Pt(size)
    style.font.color.rgb=RGBColor(0,0,0)
doc.styles['Normal'].paragraph_format.space_after=Pt(8)
doc.add_paragraph('ARIMA 固定训练集预测检验','Title')
doc.add_paragraph('使用 2024 年至 2026 年 8 月的账单预测 9 月起消费')
doc.add_paragraph('本版按固定留出检验重新运行。先用历史训练数据选择和拟合模型，再一次性预测后续日期。检验期消费用于评估预测误差。之前的 49 轮和 220 轮图展示滚动评价起点，回答的是另一项实验问题。')
doc.add_heading('训练和检验边界',1)
doc.add_paragraph('日频训练集为 2024-09-01 至 2026-08-31，共 730 天。周频训练集为 2024-09-02 至 2026-08-30，共 104 个周一至周日完整周。两个模型都调用 MATLAB 原版 ECOTOOL modelAUTO，s=1、boxcox=0。预测期间保持训练截止日固定。退款按训练截止时可获得的信息处理。')
doc.add_paragraph('两个模型均选出 ARIMA(0,1,1)，周频模型额外包含漂移项。日频预测 9 月至 11 月，周频向前预测 14 周以覆盖同一时期。现有账单只能完整核对 9–10 月，本文展示这两个月的实际与预测。11 月整月实际尚未提供。')
doc.add_heading('自然月净消费核对',1)
table=doc.add_table(rows=1,cols=4)
table.style='Table Grid'
for cell,text in zip(table.rows[0].cells,['月份','实际净消费','日频模型预测','周频模型折算']):
    cell.text=text
for row in monthly:
    for cell,value in zip(table.add_row().cells,[row[0],*[f'{number:,.2f}' for number in row[1:]]]):
        cell.text=value
doc.add_paragraph('金额单位为元。日频月额由每日预测相加得到；周频月额按预测周覆盖当月的天数比例折算。日频和周频的点误差对应不同观测单位。')
doc.add_paragraph('图中预测线较平，是原模型在固定起点给出的实际输出。它难以从过去的消费金额确定未来大额支出的发生日。实际尖峰和预测线的距离直接显示了预测误差。')
doc.add_page_break()
doc.add_heading('按消费发生日期对照实际',1)
doc.add_picture(str(OUT/'arima-fixed-holdout-daily.png'),width=Inches(7.05))
doc.add_paragraph('上图每个点为一天的消费。模型在 8 月 31 日训练结束后直接预测后续日期，9–10 月实际数据用于蓝线核对。')
doc.add_picture(str(OUT/'arima-fixed-holdout-weekly.png'),width=Inches(7.05))
doc.add_paragraph('下图每个点为一个完整周的消费。为保证实际值完整，只展示 2026-09-07 至 2026-10-25 的 7 个完整周，月初及月末跨越检验边界的周未放入该曲线。')
for root in (doc.styles.element,doc.element):
    for border in list(root.iter(qn('w:pBdr'))):
        border.getparent().remove(border)
doc.save(OUT/'ARIMA固定训练集预测与实际对照.docx')
