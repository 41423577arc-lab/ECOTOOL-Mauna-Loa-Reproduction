import csv
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs'
FONT = 'C:/Windows/Fonts/msyh.ttc'


def draw_chart(source, date_key, actual_key, predicted_key, baseline_key, title, subtitle, target):
    with (OUT / source).open(encoding='utf-8-sig', newline='') as stream:
        rows = list(csv.DictReader(stream))
    dates = [date.fromisoformat(row[date_key]) for row in rows]
    series = [(label, [float(row[key]) for row in rows], color)
              for label, key, color in [('实际总额', actual_key, '#21628a'),
                                       ('ARIMA预测', predicted_key, '#b95027'),
                                       ('历史均值', baseline_key, '#82919c')]]
    image = Image.new('RGB', (1800, 740), 'white')
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(FONT, 34)
    text_font = ImageFont.truetype(FONT, 24)
    small_font = ImageFont.truetype(FONT, 21)
    draw.text((140, 32), title, fill='#172f43', font=title_font)
    draw.text((140, 89), subtitle, fill='#506779', font=text_font)
    left, top, right, bottom = 140, 205, 1730, 625
    maximum = max(value for _, values, _ in series for value in values) * 1.08
    for tick in range(6):
        value = maximum * tick / 5
        y = bottom - (bottom - top) * tick / 5
        draw.line((left, y, right, y), fill='#e1e8ec', width=2)
        draw.text((left-20, y), f'{value:,.0f}', fill='#506779', font=small_font, anchor='rm')
    draw.text((left, top-31), '消费金额（元）', fill='#506779', font=small_font)
    first, last = dates[0].toordinal(), dates[-1].toordinal()
    for index in [round((len(rows)-1)*portion/5) for portion in range(6)]:
        x = left + (dates[index].toordinal()-first)/(last-first)*(right-left)
        draw.text((x, bottom+23), dates[index].isoformat(), fill='#506779', font=small_font, anchor='mt')
    draw.text(((left+right)/2, 710), '横轴为每轮训练截止日，每个点对应随后预测期的累计消费',
              fill='#506779', font=small_font, anchor='mm')
    for offset, (label, values, color) in enumerate(series):
        legend_x = left + offset*300
        draw.line((legend_x, 157, legend_x+55, 157), fill=color, width=5)
        draw.text((legend_x+70, 157), label, fill='#344f63', font=text_font, anchor='lm')
        points = [(left+(day.toordinal()-first)/(last-first)*(right-left),
                   bottom-value/maximum*(bottom-top)) for day, value in zip(dates, values)]
        draw.line(points, fill=color, width=4 if offset < 2 else 3)
    image.save(OUT / target)


draw_chart('ECOTOOL_ARIMA_49轮周频回测.csv', '训练截止日',
           '4周实际合计', '4周预测合计', '历史均值预测',
           '周频 ARIMA 49 轮预测与实际折线图',
           '每轮预测未来 4 周总消费  ·  ECOTOOL 原版 modelAUTO  ·  MAE 2,240.38 元',
           'arima-weekly49-line.png')
draw_chart('AutoARIMA_220轮滚动回测.csv', '当轮训练截止日',
           '30天实际（元）', '30天预测（元）', '30天历史均值基准（元）',
           '日频 ARIMA 220 轮预测与实际折线图',
           '每轮预测未来 30 天总消费  ·  Python pmdarima  ·  MAE 5,842.36 元',
           'arima-daily220-line.png')
