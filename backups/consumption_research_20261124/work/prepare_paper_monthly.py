import csv
from datetime import date, timedelta

from ecotool_rolling import ACTUAL, ADJUSTMENTS, MONTHS, ROOT, START


with (ROOT / 'work/paper_monthly_input.csv').open('w', encoding='utf-8', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['Origin', 'Month', 'Spending'])
    for target, _ in MONTHS:
        cutoff = target - timedelta(days=1)
        history = ACTUAL[:(cutoff - START).days + 1].copy()
        for bought, refunded, cents in ADJUSTMENTS:
            if bought <= cutoff < refunded:
                history[(bought - START).days] += cents
        monthly = {}
        for step, cents in enumerate(history):
            month = (START + timedelta(days=step)).replace(day=1)
            monthly[month] = monthly.get(month, 0) + int(cents)
        assert len(monthly) == 24 + target.month - 9
        for month, cents in monthly.items():
            writer.writerow([cutoff.isoformat(), month.isoformat(), f'{cents / 100:.2f}'])
