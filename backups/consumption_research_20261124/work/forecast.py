from datetime import date, timedelta
from pathlib import Path
from zipfile import ZipFile
import xml.etree.ElementTree as ET

from pmdarima import auto_arima


ROOT = Path(__file__).resolve().parents[1]
with ZipFile(next((ROOT / 'outputs').glob('消费预测*.xlsx'))) as workbook:
    namespace = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    sheets = ET.fromstring(workbook.read('xl/workbook.xml'))
    assert sheets.find('s:sheets/s:sheet', namespace).attrib['name'] == '周度模型输入'
    sheet = ET.fromstring(workbook.read('xl/worksheets/sheet1.xml'))
    rows = sheet.findall('s:sheetData/s:row', namespace)[1:]
    observations = []
    for row in rows:
        cells = {cell.attrib['r']: cell for cell in row.findall('s:c', namespace)}
        observations.append([float(cells[f'{col}{row.attrib["r"]}'].find('s:v', namespace).text)
                             for col in 'AB'])
assert len(observations) == 52
assert sum(round(amount * 100) for _, amount in observations) == 6455212
assert all(day == observations[0][0] + index * 7 for index, (day, _) in enumerate(observations))
last_week = date(1899, 12, 30) + timedelta(days=observations[-1][0])
first_future_week = last_week + timedelta(weeks=1)
assert first_future_week == date(2026, 8, 31)
model = auto_arima([amount for _, amount in observations], seasonal=False,
                   information_criterion='aicc', error_action='ignore', suppress_warnings=True)
forecasts = model.predict(n_periods=18)
print('order', model.order, 'AICc', model.aicc(), 'params', model.params())
for month_start, month_end in [(date(2026, 9, 1), date(2026, 10, 1)),
                               (date(2026, 12, 1), date(2027, 1, 1))]:
    month_total = 0.
    for index, value in enumerate(forecasts):
        week_start = first_future_week + timedelta(weeks=index)
        week_end = week_start + timedelta(weeks=1)
        days = (min(week_end, month_end) - max(week_start, month_start)).days
        if days > 0:
            print(week_start, value, days)
            month_total += value * days / 7
    print(month_start, round(month_total, 2))
print('first four weeks', round(sum(forecasts[:4]), 2))
