import csv
from collections import defaultdict
from datetime import date, timedelta
from math import sqrt
from pathlib import Path
from statistics import mean


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs'


def read(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))


arima = read(OUT / 'ECOTOOL_ARIMA_49轮周频回测.csv')
months = [row for row in read(OUT / 'ECOTOOL_ARIMA_周频转月度预测.csv')
          if row['月份'] in ('2026-09', '2026-10')]
input_rows = read(ROOT / 'work/weekly49_input.csv')
results = defaultdict(list)
historical = defaultdict(list)
for row in input_rows:
    historical[row['Origin']].append(float(row['Spending']))
for row in read(ROOT / 'work/weekly49_ets_uc.csv'):
    assert row['Status'] == 'OK', row
    result = results[row['Origin'], row['Model']]
    assert int(row['Step']) == len(result) + 1
    result.append(float(row['Forecast']))
assert len(arima) == 49 and len(months) == 2 and len(results) == 104

output = []
metrics = defaultdict(list)
for row in arima:
    origin = row['训练截止日']
    actual = float(row['4周实际合计'])
    assert len(results[origin, 'ETS']) == len(results[origin, 'UC']) == 4
    estimate = {
        'Auto ARIMA': float(row['4周预测合计']),
        'ETS': sum(results[origin, 'ETS']),
        'UC': sum(results[origin, 'UC']),
        '历史均值': mean(historical[origin]) * 4,
    }
    for model, value in estimate.items():
        metrics[model].append(value - actual)
    output.append(['未来4周', row['轮次'], origin, row['预测开始'], row['预测结束'], actual, *estimate.values()])

for row in months:
    origin = row['训练截止日']
    first_week = date.fromisoformat(origin) + timedelta(days=1)
    begin = date.fromisoformat(row['月份'] + '-01')
    end = (begin + timedelta(days=31)).replace(day=1)
    weights = []
    for index in range(6):
        start = first_week + timedelta(weeks=index)
        weights.append(max(0, (min(end, start + timedelta(days=7)) - max(begin, start)).days) / 7)
    assert abs(sum(weights) * 7 - (end - begin).days) < 1e-10
    predictions = []
    for model in ('ETS', 'UC'):
        weekly = results[origin, model]
        assert len(weekly) == 6
        predictions.append(sum(value * weight for value, weight in zip(weekly, weights)))
    actual = float(row['实际净消费（元）']) if row['实际净消费（元）'] else None
    baseline = mean(historical[origin]) * sum(weights)
    output.append(['自然月', None, origin, begin, end - timedelta(days=1), actual,
                   float(row['预测净消费（元）']), *predictions, baseline])

for model, errors in metrics.items():
    print(model, 'MAE', f'{mean(map(abs, errors)):.2f}', 'RMSE', f'{sqrt(mean(val ** 2 for val in errors)):.2f}')
for row in output[-len(months):]:
    print(row)
with (OUT / 'ECOTOOL_49轮_ARIMA_ETS_UC比较.csv').open('w', encoding='utf-8-sig', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['结果类型', '回测轮次', '训练截止日', '目标开始日', '目标结束日',
                     '实际净消费（元）', 'Auto ARIMA（元）', 'ETS（元）', 'UC（元）', '历史均值（元）'])
    writer.writerows([[f'{value:.2f}' if isinstance(value, float) else value for value in row] for row in output])
