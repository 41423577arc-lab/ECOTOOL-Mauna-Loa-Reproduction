import csv
from pathlib import Path
from statistics import mean

import matplotlib

matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.ticker import StrMethodFormatter


output = Path(__file__).resolve().parents[1] / 'outputs'
with (output / 'ECOTOOL_49轮_ARIMA_ETS_UC比较.csv').open(encoding='utf-8-sig') as stream:
    rows = list(csv.DictReader(stream))
rolling = [row for row in rows if row['结果类型'] == '未来4周']
monthly = [row for row in rows if row['结果类型'] == '自然月']
assert len(rolling) == 49 and [row['目标开始日'] for row in monthly] == ['2026-09-01', '2026-10-01']

font = Path('C:/Windows/Fonts/msyh.ttc')
font_manager.fontManager.addfont(font)
plt.rcParams['font.family'] = font_manager.FontProperties(fname=font).get_name()
models = ['历史均值', 'Auto ARIMA', 'UC', 'ETS']
colors = ['#14766f', '#9870a6', '#397397', '#b5643a']
actual_color = '#1d344c'
actual_key = '实际净消费（元）'
mean_errors = [mean(abs(float(row[f'{name}（元）']) - float(row[actual_key])) for row in rolling)
               for name in models]

figure, (accuracy, comparison) = plt.subplots(1, 2, figsize=(12.4, 5.25), dpi=175,
                                             gridspec_kw={'width_ratios': [1, 1.42]})
figure.subplots_adjust(left=.128, right=.965, top=.69, bottom=.20, wspace=.36)
figure.text(.128, .918, '消费预测模型对比', fontsize=24, color=actual_color, weight='bold')
figure.text(.128, .848, '支付宝与微信净消费  ·  49 轮周频回测  ·  2026 年 9–10 月预测核对',
            fontsize=11, color='#526475')
accuracy.set_title('未来 4 周总额的平均绝对误差（元）', loc='left', pad=13, fontsize=11)
bars = accuracy.barh(models, mean_errors, color=colors, height=.5)
accuracy.bar_label(bars, labels=[f'{value:,.0f}' for value in mean_errors],
                   padding=6, fontsize=9, color=actual_color)
accuracy.invert_yaxis()
accuracy.set_xlim(0, 3800)
accuracy.set_xticks(range(0, 3001, 1000))
accuracy.xaxis.set_major_formatter(StrMethodFormatter('{x:,.0f}'))
accuracy.grid(axis='x', color='#e4ebef', linewidth=.7)

comparison.set_title('自然月预测与实际对照（元）', loc='left', pad=13, fontsize=11)
series = [('实际', actual_key, actual_color), *[(name, f'{name}（元）', color) for name, color in zip(models, colors)]]
for index, (name, key, color) in enumerate(series):
    positions = [month_index + (index - 2) * .152 for month_index in range(2)]
    values = [float(row[key]) for row in monthly]
    monthly_bars = comparison.bar(positions, values, width=.136, color=color, label=name)
    comparison.bar_label(monthly_bars, labels=[f'{value:,.0f}' for value in values],
                         padding=3, fontsize=7.5, color=actual_color)
comparison.set_xticks([0, 1], ['9 月', '10 月'])
comparison.set_ylim(0, 13500)
comparison.set_yticks([0, 3000, 6000, 9000, 12000])
comparison.yaxis.set_major_formatter(StrMethodFormatter('{x:,.0f}'))
comparison.grid(axis='y', color='#e4ebef', linewidth=.7)
comparison.legend(loc='upper center', bbox_to_anchor=(.5, -.15), ncol=5, frameon=False,
                  fontsize=8, handlelength=1.4, columnspacing=1.2)

for axis in (accuracy, comparison):
    axis.set_axisbelow(True)
    axis.tick_params(axis='both', length=0, pad=6, colors='#526475', labelsize=9)
    for spine in axis.spines.values():
        spine.set_visible(False)
figure.text(.128, .07, '误差越小越好。9 月、10 月的自然月预测单独核对，未计入 49 轮回测误差。',
            fontsize=9, color='#526475')
figure.savefig(output / 'ecotool-model-comparison-sep-oct.png', facecolor='white')
