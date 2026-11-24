import csv
from collections import Counter, defaultdict
from datetime import date, timedelta
from math import sqrt
from statistics import mean

from weekly49_input import ORIGINS, ROOT, TARGETS, amounts, historical_week_totals


by_origin = defaultdict(list)
with (ROOT / 'work/weekly49_matlab_yuan.csv').open(encoding='utf-8-sig') as stream:
    for row in csv.DictReader(stream):
        by_origin[date.fromisoformat(row['Origin'])].append(row)
assert len(by_origin) == 52
out = ROOT / 'outputs'
weekly_rows = []
for number, origin in enumerate(ORIGINS, 1):
    rows = by_origin[origin]
    assert len(rows) == 4 and [int(row['Step']) for row in rows] == [1, 2, 3, 4]
    first = origin + timedelta(days=1)
    after = first + timedelta(weeks=4)
    actual = int(amounts(first, after).sum()) / 100
    weekly_mean = 4 * float(mean(historical_week_totals(origin)))
    valid = all(row['Status'] == 'OK' for row in rows)
    predictions = [float(row['Forecast']) for row in rows] if valid else [None] * 4
    forecast = sum(predictions) if valid else None
    weekly_rows.append([number, origin, int(rows[0]['TrainingWeeks']), first, after - timedelta(days=1),
                        rows[0]['Specification'], *predictions, forecast, actual, weekly_mean,
                        None if forecast is None else forecast - actual, weekly_mean - actual,
                        rows[0]['OutputScale'], rows[0]['Status']])

assert all(row[10] is not None for row in weekly_rows), Counter(row[-1] for row in weekly_rows)


def money(value):
    return f'{value:.2f}' if isinstance(value, float) else value


with (out / 'ECOTOOL_ARIMA_49轮周频回测.csv').open('w', encoding='utf-8-sig', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['轮次', '训练截止日', '训练周数', '预测开始', '预测结束', '模型结构',
                     '第1周预测', '第2周预测', '第3周预测', '第4周预测', '4周预测合计', '4周实际合计',
                     '历史均值预测', 'ARIMA有符号误差', '均值有符号误差', '量纲核对', '状态'])
    writer.writerows([money(value) for value in row] for row in weekly_rows)

for label, index in [('Auto ARIMA', 13), ('Historical mean', 14)]:
    errors = [row[index] for row in weekly_rows]
    print(label, 'MAE', round(mean(map(abs, errors)), 2), 'RMSE', round(sqrt(mean(error ** 2 for error in errors)), 2))
print('49 origins', ORIGINS[0], ORIGINS[-1])
month_rows = []
for begin, end in TARGETS:
    origin = begin - timedelta(days=begin.weekday() + 1)
    rows = by_origin[origin]
    assert len(rows) == 6
    assert all(row['Status'] == 'OK' for row in rows)
    forecast = 0.
    for row in rows:
        week = origin + timedelta(days=1, weeks=int(row['Step']) - 1)
        overlap = (min(end, week + timedelta(weeks=1)) - max(begin, week)).days
        forecast += float(row['Forecast']) * max(overlap, 0) / 7
    actual = int(amounts(begin, end).sum()) / 100 if begin.month < 11 else None
    month_rows.append([begin.isoformat()[:7], origin, rows[0]['TrainingWeeks'], rows[0]['Specification'],
                       forecast, actual, None if actual is None else forecast - actual])
    print(*map(money, month_rows[-1]))
with (out / 'ECOTOOL_ARIMA_周频转月度预测.csv').open('w', encoding='utf-8-sig', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['月份', '训练截止日', '训练周数', '模型结构', '预测净消费（元）',
                     '实际净消费（元）', '预测减实际（元）'])
    writer.writerows([money(value) for value in row] for row in month_rows)
