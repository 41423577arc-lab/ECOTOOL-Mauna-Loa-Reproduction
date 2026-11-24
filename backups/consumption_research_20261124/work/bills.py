import csv
import io
import json
from collections import Counter
from pathlib import Path

import openpyxl


def sources():
    root = Path.home() / 'AppData/Local/Temp'
    for platform, folder, suffix in [('支付宝', 'z9Ws5h', 'csv'), ('微信', 'AuSdkr', 'xlsx')]:
        path, = (root / f'codex-file-preview-{folder}').glob(f'*.{suffix}')
        if suffix == 'csv':
            data = path.read_bytes()
            for encoding in ['utf-8-sig', 'gb18030']:
                try:
                    decoded = data.decode(encoding)
                    break
                except UnicodeDecodeError:
                    continue
            rows = csv.reader(io.StringIO(decoded))
        else:
            rows = openpyxl.load_workbook(path, read_only=True, data_only=True).active.values
        header = None
        records = []
        for line, row in enumerate(rows, 1):
            items = [str(value).strip() if value is not None else '' for value in row]
            if '交易时间' in items and ('交易状态' in items or '当前状态' in items):
                header = items
                print(platform, 'header', line, header)
            elif header and any(items):
                records.append((line, dict(zip(header, items))))
        yield platform, path.name, records


if __name__ == '__main__':
    for platform, filename, records in sources():
        print(platform, len(records))
        for key in ['收/支', '交易分类', '交易类型', '交易状态', '当前状态']:
            print(key, Counter(record.get(key) for _, record in records).most_common(120))
        print('date bounds', min(record.get('交易时间', '') for _, record in records),
              max(record.get('交易时间', '') for _, record in records))
        print('refund combinations', Counter(
            tuple(record.get(key, '') for key in ['收/支','交易分类','交易类型','交易状态','当前状态'])
            for _, record in records if any('退款' in record.get(key, '') for key in ['交易分类','交易类型','交易状态','当前状态'])
        ).most_common(60))
