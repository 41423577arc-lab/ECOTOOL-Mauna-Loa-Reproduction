from datetime import date, timedelta
from pathlib import Path

import matplotlib

matplotlib.use('Agg')
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.ticker import StrMethodFormatter

from forecast import forecasts, first_future_week, observations


font = Path('C:/Windows/Fonts/msyh.ttc')
font_manager.fontManager.addfont(font)
plt.rcParams['font.family'] = font_manager.FontProperties(fname=font).get_name()
history_dates = [date(1899, 12, 30) + timedelta(days=day) for day, _ in observations]
history_amounts = [amount for _, amount in observations]
future_dates = [first_future_week + timedelta(weeks=index) for index in range(len(forecasts))]
december = date(2026, 12, 1)
january = date(2027, 1, 1)
december_total = sum(
    float(amount) * max(0, (min(start + timedelta(days=7), january) - max(start, december)).days) / 7
    for start, amount in zip(future_dates, forecasts)
)

fig, axis = plt.subplots(figsize=(11.4, 5.7), dpi=165)
fig.patch.set_facecolor('#ffffff')
fig.subplots_adjust(left=.095, right=.963, top=.73, bottom=.205)
fig.text(.095, .925, '支付宝与微信净消费预测', size=23, color='#15283d', weight='bold')
fig.text(.095, .855, 'Auto ARIMA  ·  52 个完整周  ·  ARIMA(0,0,0)', size=11, color='#4c6174')
fig.text(.957, .918, f'{december_total:,.0f} 元', size=23, ha='right', color='#9a410c', weight='bold')
fig.text(.957, .856, '2026 年 12 月净消费估计', size=11, ha='right', color='#695044')

axis.axvspan(december, january, color='#fff2df', zorder=0)
axis.axvline(first_future_week, color='#8596a5', linewidth=1)
axis.plot(history_dates, history_amounts, color='#276186', linewidth=1.7,
          marker='o', markersize=2.5, label='历史实际', zorder=3)
axis.plot(future_dates + [january], [*forecasts, forecasts[-1]], color='#ae4b13',
          linestyle=(0, (5, 3)), linewidth=2.05, label='周度预测', zorder=4)
axis.text(date(2026, 10, 8), forecasts[0] + 315, f'{forecasts[0]:,.2f} 元／周',
          ha='center', color='#913a0b', fontsize=10)
axis.text(first_future_week + timedelta(days=7), 6000, '8 月 31 日起为预测', color='#4c6174', fontsize=10)
axis.set_title('每周净消费（元）', loc='left', color='#4c6174', fontsize=10, pad=8)
axis.set_xlim(date(2025, 8, 25), january + timedelta(days=3))
axis.set_ylim(0, 7400)
axis.set_yticks(range(0, 7001, 1000))
axis.yaxis.set_major_formatter(StrMethodFormatter('{x:,.0f}'))
axis.set_xticks([date(2025, 9, 1), date(2025, 11, 1), date(2026, 1, 1), date(2026, 3, 1),
                 date(2026, 5, 1), date(2026, 7, 1), date(2026, 9, 1), date(2026, 11, 1), december])
axis.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m'))
axis.grid(axis='y', color='#e5ebef', linewidth=.8)
axis.tick_params(axis='both', length=0, pad=8, colors='#4c6174', labelsize=9)
for spine in ['left', 'right', 'top']:
    axis.spines[spine].set_visible(False)
axis.spines['bottom'].set_color('#bac7d0')
axis.legend(loc='upper right', frameon=False, fontsize=10, ncol=2)
fig.text(.095, .086, '历史训练数据截至 2026-08-30。12 月总额按跨月周落在当月的天数折算。',
         size=10, color='#4c6174')
target = Path(__file__).resolve().parents[1] / 'outputs' / 'auto-arima-spending-forecast.png'
fig.savefig(target, facecolor=fig.get_facecolor())
plt.close(fig)
