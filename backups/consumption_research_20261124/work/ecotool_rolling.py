import csv
import json
import re
import sys
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from datetime import date, timedelta
from pathlib import Path

import numpy as np
from pmdarima import auto_arima


ROOT = Path(__file__).resolve().parents[1]
START = date(2024, 9, 1)
ACTUAL_END = date(2026, 10, 31)
WIDTHS = (7, 28, 30, 31)
ORIGINS = [ACTUAL_END - timedelta(days=31 + 219 - step) for step in range(220)]
MONTHS = [(date(2026, 9, 1), 30), (date(2026, 10, 1), 31), (date(2026, 11, 1), 30)]


def day_from_excel(serial):
    return date(1899, 12, 30) + timedelta(days=int(serial))


def load_series():
    data = json.loads((ROOT / 'work/merged-data.json').read_text(encoding='utf-8'))
    actual = np.zeros((ACTUAL_END - START).days + 1, dtype=np.int64)
    for row in data['details'][1:]:
        day = day_from_excel(row[0])
        if day <= ACTUAL_END:
            actual[(day - START).days] += round(row[7] * 100)
    audit = {(int(row[2][2:]), row[3]): row for row in data['audit'][1:]}
    adjustments = []
    for row in audit.values():
        if row[8] not in ('全额退款原单', '部分退款后纳入') or row[5] != '支出':
            continue
        bought = day_from_excel(row[0])
        linked = [audit[int(source), int(line)] for source, line in re.findall(r'账单(\d+) · (\d+)行', row[9])]
        assert linked
        restored = round((row[7] - row[10]) * 100)
        if linked[0][8] == '同额退款组（两笔）':
            assert len({day_from_excel(refund[0]) for refund in linked}) == 1
            linked = linked[:1]
        assert sum(round(refund[7] * 100) for refund in linked) == restored
        for refund in linked:
            refunded = day_from_excel(refund[0])
            assert refunded >= bought
            adjustments.append((bought, refunded, round(refund[7] * 100)))
    assert int(actual.sum()) == 11523572
    return actual, adjustments


ACTUAL, ADJUSTMENTS = load_series()


def run_forecast(task):
    cutoff, horizon = task
    size = (cutoff - START).days + 1
    history = ACTUAL[:size].copy()
    for bought, refunded, cents in ADJUSTMENTS:
        if bought <= cutoff < refunded:
            history[(bought - START).days] += cents
    train = history.astype(float) / 100
    model = auto_arima(train / 100, seasonal=False, information_criterion='aicc', stepwise=True,
                       start_p=0, start_q=0, max_p=2, max_q=2, max_d=2, maxiter=35,
                       suppress_warnings=True, error_action='ignore')
    predicted = np.asarray(model.predict(n_periods=horizon)) * 100
    assert np.isfinite(predicted).all()
    return cutoff, train, predicted, model.order


def scores(cases):
    forecasts, actuals, scales = np.asarray(cases).T
    errors = forecasts - actuals
    denominator = np.abs(actuals) + np.abs(forecasts)
    relative = np.divide(2 * np.abs(errors), denominator, out=np.zeros_like(errors), where=denominator > 0)
    return [float(np.mean(np.abs(errors))), float(np.sqrt(np.mean(errors ** 2))),
            float(100 * np.mean(relative)), float(np.mean(np.abs(errors) / scales))]


def write_results(rolling, monthly):
    tallies = {}
    audit = []
    for step, (cutoff, train, forecast, order) in enumerate(rolling, 1):
        future = ACTUAL[len(train):len(train) + 31] / 100
        assert len(future) == 31
        result = [step, cutoff.isoformat(), len(train), str(order)]
        for width in WIDTHS:
            totals = np.convolve(train, np.ones(width), mode='valid')
            scale = np.mean(np.abs(totals[width:] - totals[:-width]))
            assert scale > 0
            actual = float(np.sum(future[:width]))
            estimate = float(np.sum(forecast[:width]))
            baseline = float(train.mean() * width)
            result.extend([actual, estimate, baseline])
            for label, predicted in [('Auto ARIMA', estimate), ('历史均值', baseline)]:
                tallies.setdefault((width, label), []).append((predicted, actual, scale))
        audit.append(result)

    month_rows = []
    for (month, horizon), (cutoff, train, forecast, order) in zip(MONTHS, monthly):
        assert cutoff + timedelta(days=1) == month and len(forecast) == horizon
        estimate = float(np.sum(forecast))
        actual = float(np.sum(ACTUAL[len(train):len(train) + horizon]) / 100) if month.month < 11 else None
        month_rows.append([month.isoformat()[:7], cutoff.isoformat(), len(train), str(order), estimate,
                           actual, None if actual is None else estimate - actual])

    metrics = [[width, label, *scores(results)] for (width, label), results in tallies.items()]
    distribution = Counter(str(result[3]) for result in rolling)
    table = {
        'months': month_rows, 'metrics': metrics, 'orders': dict(distribution),
        'start': ORIGINS[0].isoformat(), 'end': ORIGINS[-1].isoformat(),
        'negative_daily_estimates': sum(int(np.sum(result[2] < 0)) for result in rolling + monthly)
    }
    (ROOT / 'work/rolling-results.json').write_text(json.dumps(table, ensure_ascii=False), encoding='utf-8')
    columns = ['轮次', '当轮训练截止日', '训练天数', 'ARIMA阶数']
    columns.extend(f'{width}天{name}（元）' for width in WIDTHS for name in ['实际', '预测', '历史均值基准'])
    with (ROOT / 'outputs/AutoARIMA_220轮滚动回测.csv').open('w', encoding='utf-8-sig', newline='') as report:
        writer = csv.writer(report)
        writer.writerow(columns)
        writer.writerows([*row[:4], *[f'{number:.2f}' for number in row[4:]]] for row in audit)
    print(json.dumps(table, ensure_ascii=False, indent=2), flush=True)


if __name__ == '__main__':
    tasks = [(origin, 31) for origin in ORIGINS] + [(month - timedelta(days=1), days) for month, days in MONTHS]
    with ProcessPoolExecutor(max_workers=6) as pool:
        outcomes = []
        for index, outcome in enumerate(pool.map(run_forecast, tasks, chunksize=3), 1):
            outcomes.append(outcome)
            if index % 40 == 0:
                print(f'Completed {index}/223', flush=True)
    assert len(outcomes) == 223
    write_results(outcomes[:220], outcomes[220:])
