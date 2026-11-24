import csv
from datetime import date, timedelta
from ecotool_rolling import ACTUAL, ADJUSTMENTS, ROOT, START


CUTOFF = date(2026, 8, 31)
history = ACTUAL[:(CUTOFF - START).days + 1].copy()
for bought, refunded, cents in ADJUSTMENTS:
    if bought <= CUTOFF < refunded:
        history[(bought - START).days] += cents
assert len(history) == 730
with (ROOT / 'work/holdout_daily_train.csv').open('w', encoding='utf-8', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['Date','Spending'])
    writer.writerows((START + timedelta(days=index), f'{cents/100:.2f}') for index,cents in enumerate(history))
with (ROOT / 'work/holdout_daily_actual.csv').open('w', encoding='utf-8', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['Date','Actual'])
    begin = date(2026,9,1)
    for index in range(61):
        day=begin+timedelta(days=index)
        writer.writerow([day, f'{ACTUAL[(day-START).days]/100:.2f}'])
