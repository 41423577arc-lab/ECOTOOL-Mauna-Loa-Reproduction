import csv
from pathlib import Path

import matplotlib

matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.ticker import StrMethodFormatter


out = Path(__file__).resolve().parents[1] / 'outputs'
with (out / 'ECOTOOL_ARIMA_49轮周频回测.csv').open(encoding='utf-8-sig') as stream:
    rolling = list(csv.DictReader(stream))
with (out / 'ECOTOOL_ARIMA_周频转月度预测.csv').open(encoding='utf-8-sig') as stream:
    months = list(csv.DictReader(stream))
font = Path('C:/Windows/Fonts/msyh.ttc')
font_manager.fontManager.addfont(font)
plt.rcParams['font.family'] = font_manager.FontProperties(fname=font).get_name()
fig, (backtest, calendar) = plt.subplots(1, 2, figsize=(12.0, 5.1), dpi=170,
                                         gridspec_kw={'width_ratios': [1.5, 1]})
fig.subplots_adjust(left=.074, right=.96, top=.73, bottom=.16, wspace=.30)
fig.text(.074, .9, 'ECOTOOL 周频 Auto ARIMA 消费预测', fontsize=23, weight='bold', color='#172f43')
fig.text(.074, .834, '支付宝与微信净消费  ·  49 轮扩展窗口  ·  每轮预测未来 4 周', fontsize=10.5, color='#496075')
blue, orange, gray = '#246687', '#ac4d1e', '#6b7d89'
steps = range(1, len(rolling) + 1)
for label, key, color, style in [
    ('实际', '4周实际合计', blue, '-'),
    ('Auto ARIMA', '4周预测合计', orange, '-'),
    ('历史均值', '历史均值预测', gray, '--'),
]:
    backtest.plot(steps, [float(row[key]) for row in rolling], color=color, linestyle=style, label=label)
backtest.set_title('49 轮回测｜未来 4 周净消费（元）', fontsize=11, loc='left', pad=10)
backtest.set_xlabel('回测轮次', color=gray, fontsize=9)
backtest.legend(loc='upper right', frameon=False, fontsize=8, ncol=3)
backtest.set_ylim(top=backtest.get_ylim()[1] * 1.14)

actuals = [float(row['实际净消费（元）']) for row in months if row['实际净消费（元）']]
predictions = [float(row['预测净消费（元）']) for row in months]
real_bars = calendar.bar([-.17, .83], actuals, width=.30, color=blue)
predicted_bars = calendar.bar([.17, 1.17, 2.0], predictions, width=.30, color=orange)
for bars, numbers, color in [(real_bars, actuals, blue), (predicted_bars, predictions, orange)]:
    calendar.bar_label(bars, labels=[f'{number:,.0f}' for number in numbers], padding=4, fontsize=8, color=color)
calendar.set_xticks([0, 1, 2], ['9 月', '10 月', '11 月\n实际待核对'])
calendar.set_ylim(0, max(actuals + predictions) * 1.17)
calendar.set_title('9–11 月｜自然月净消费（元）', fontsize=11, loc='left', pad=10)

for axis in [backtest, calendar]:
    axis.yaxis.set_major_formatter(StrMethodFormatter('{x:,.0f}'))
    axis.set_axisbelow(True)
    axis.grid(axis='y', color='#e6edf1', linewidth=.7)
    axis.tick_params(axis='both', length=0, pad=6, colors=gray, labelsize=8)
    for spine in axis.spines.values():
        spine.set_visible(False)
fig.savefig(out / 'ecotool-weekly49-forecast.png', facecolor='white')
