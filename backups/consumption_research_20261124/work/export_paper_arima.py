import csv
from pathlib import Path


root = Path(__file__).resolve().parents[1]
actuals = {'2026-09-01': 11772.04, '2026-10-01': 4323.72}
months = {*actuals, '2026-11-01'}
with (root / 'work/paper_arima_matlab.csv').open(encoding='utf-8-sig') as stream:
    results = [row for row in csv.DictReader(stream) if row['TargetMonth'] in months]
assert len(results) == 12
assert sum(row['Status'] == 'OK' for row in results) == 3
with (root / 'work/paper_arima_inverse.csv').open() as stream:
    inverse = [tuple(map(float, row)) for row in csv.reader(stream)]
assert len(inverse) == 24
with (root / 'outputs/ECOTOOL原版_ARIMA_2026年9至11月.csv').open('w', encoding='utf-8-sig', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['训练截止日', '目标月份', '预测步数（月）', '训练月数', '模型', '模型结构',
                     'Box-Cox 尺度原始输出', '反变换预测（元）', '实际净消费（元）', '运行状态'])
    for row in results:
        forecast = float(row['Forecast']) if row['Status'] == 'OK' else None
        yuan = None
        if forecast is not None:
            original, yuan = inverse[int(row['Horizon']) - 1]
            assert abs(original - forecast) < 1e-9
            yuan = round(yuan, 2)
        writer.writerow([row['TrainingEnd'], row['TargetMonth'][:7], row['Horizon'], row['TrainingMonths'],
                         row['Model'], row['Specification'], forecast, yuan, actuals.get(row['TargetMonth']),
                         '返回数值' if row['Status'] == 'OK' else row['Status']])
