import csv
from datetime import date, timedelta

from ecotool_rolling import ACTUAL, ADJUSTMENTS, ROOT, START


MONDAY = date(2024, 9, 2)
FIRST = MONDAY + timedelta(weeks=52, days=-1)
EXPERIMENT_END = date(2026, 8, 30)
ORIGINS = [FIRST + timedelta(weeks=index) for index in range(49)]
assert ORIGINS[-1] + timedelta(weeks=4) == EXPERIMENT_END
TARGETS = [
    (date(2026, 9, 1), date(2026, 10, 1)),
    (date(2026, 10, 1), date(2026, 11, 1)),
    (date(2026, 11, 1), date(2026, 12, 1)),
]


def amounts(begin, end):
    return ACTUAL[(begin - START).days:(end - START).days]


def historical_week_totals(cutoff):
    history = amounts(MONDAY, cutoff + timedelta(days=1)).copy()
    for bought, refunded, cents in ADJUSTMENTS:
        if MONDAY <= bought <= cutoff < refunded:
            history[(bought - MONDAY).days] += cents
    return history.reshape(-1, 7).sum(axis=1) / 100


with (ROOT / 'work/weekly49_input.csv').open('w', encoding='utf-8', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['Origin', 'Week', 'Spending'])
    monthly_origins = [begin - timedelta(days=begin.weekday() + 1) for begin, _ in TARGETS]
    for cutoff in sorted(set(ORIGINS + monthly_origins)):
        history = historical_week_totals(cutoff)
        for index, value in enumerate(history):
            writer.writerow([cutoff, MONDAY + timedelta(weeks=index), f'{value:.2f}'])
