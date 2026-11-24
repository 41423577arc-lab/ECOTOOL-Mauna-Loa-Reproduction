import json
from pathlib import Path

import matplotlib

matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.ticker import StrMethodFormatter


root = Path(__file__).resolve().parents[1]
data = json.loads((root / 'work/rolling-results.json').read_text(encoding='utf-8'))
font = Path('C:/Windows/Fonts/msyh.ttc')
font_manager.fontManager.addfont(font)
plt.rcParams['font.family'] = font_manager.FontProperties(fname=font).get_name()

fig, axis = plt.subplots(figsize=(8.9, 5), dpi=180)
fig.subplots_adjust(left=.12, right=.95, top=.73, bottom=.21)
navy, teal, orange, muted = '#172f43', '#256583', '#b14f1c', '#516778'
fig.text(.12, .91, '2026 年 9–11 月消费预测', fontsize=23, weight='bold', color=navy)
fig.text(.12, .835, '支付宝与微信净消费  ·  Auto ARIMA  ·  每月开始前重新拟合', fontsize=10.5, color=muted)

forecasts = [row[4] for row in data['months']]
actuals = [row[5] for row in data['months'][:2]]
positions = [-.175, .825]
actual_bars = axis.bar(positions, actuals, width=.31, color=teal, label='实际')
forecast_bars = axis.bar([.175, 1.175, 2], forecasts, width=.31, color=orange, label='预测')
axis.bar_label(actual_bars, labels=[f'{amount:,.0f}' for amount in actuals], color=teal, padding=5, fontsize=10)
axis.bar_label(forecast_bars, labels=[f'{amount:,.0f}' for amount in forecasts], color=orange, padding=5, fontsize=10)
axis.set_xticks([0, 1, 2], ['9 月', '10 月', '11 月\n整月实际待核对'])
axis.set_xlim(-.53, 2.52)
axis.set_ylim(0, max(actuals + forecasts) * 1.27)
axis.yaxis.set_major_formatter(StrMethodFormatter('{x:,.0f}'))
axis.set_title('净消费（元）', loc='left', color=muted, fontsize=10, pad=6)
axis.tick_params(axis='both', length=0, pad=6, colors=muted)
axis.set_axisbelow(True)
axis.grid(axis='y', color='#e6edf1', linewidth=.7)
for spine in axis.spines.values():
    spine.set_visible(False)
axis.legend(loc='upper right', ncol=2, frameon=False, fontsize=9.5)
fig.text(.12, .056, '训练集按日扩展。9–10 月可以核对实际，11 月预测使用截至 10 月 31 日的数据。',
         fontsize=9.5, color=muted)
fig.savefig(root / 'outputs/ecotool-auto-arima-months.png', facecolor='white')
