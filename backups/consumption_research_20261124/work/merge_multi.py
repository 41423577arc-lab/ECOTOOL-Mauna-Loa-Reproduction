import csv
import io
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path

import openpyxl


START, END = date(2024, 9, 1), date(2026, 11, 1)
SOURCE = Path(sys.argv[1])
FILES = [
    '支付宝交易明细(20240901-20250831).csv',
    '支付宝交易明细(20250901-20260831).csv',
    '支付宝交易明细(20260901-20261101).csv',
    '微信支付账单流水文件(20240901-20250831)_20261118202632.xlsx',
    '微信支付账单流水文件(20250901-20260901)_20261118160810.xlsx',
    '微信支付账单流水文件(20260901-20261101)_20261118202713.xlsx',
]
QR = {(5, 31): '购物', (5, 83): '其他服务', (5, 126): '购物',
      (5, 380): '购物', (5, 437): '生活服务', (5, 684): '文娱',
      (4, 140): '餐饮', (4, 185): '餐饮', (4, 187): '购物', (4, 648): '文娱'}


def read_file(number, filename):
    ali = number <= 3
    path = SOURCE / filename
    if ali:
        raw = path.read_bytes()
        try:
            decoded = raw.decode('utf-8-sig')
        except UnicodeDecodeError:
            decoded = raw.decode('gb18030')
        reader = csv.reader(io.StringIO(decoded))
    else:
        reader = openpyxl.load_workbook(path, read_only=True, data_only=True).active.values
    headers = None
    result = []
    for line, values in enumerate(reader, 1):
        items = [str(value).strip() if value is not None else '' for value in values]
        if '交易时间' in items and '收/支' in items:
            headers = items
            continue
        if not headers or not any(items):
            continue
        data = dict(zip(headers, items))
        record = {
            'ref': (number, line), 'platform': '支付宝' if ali else '微信',
            'stamp': datetime.fromisoformat(data['交易时间']),
            'kind': data['交易分类' if ali else '交易类型'],
            'status': data['交易状态' if ali else '当前状态'],
            'direction': data['收/支'],
            'amount': int(Decimal(data['金额' if ali else '金额(元)'].strip('¥￥').replace(',', '')) * 100),
            'id': data['交易订单号' if ali else '交易单号'],
            'merchant_id': data['商家订单号' if ali else '商户单号'],
            'product': data['商品说明' if ali else '商品'],
            'merchant': data['交易对方'],
        }
        result.append(record)
    assert headers and result
    return result


records = [rec for number, name in enumerate(FILES, 1) for rec in read_file(number, name)]
if 'inspect' in sys.argv:
    for number in range(1, 7):
        subset = [rec for rec in records if rec['ref'][0] == number]
        print(number, len(subset), min(rec['stamp'] for rec in subset), max(rec['stamp'] for rec in subset))
        print(Counter((rec['kind'], rec['direction'], rec['status']) for rec in subset).most_common(100))
        if number in (4, 6):
            print('QR', [(rec['ref'], rec['merchant']) for rec in subset if rec['kind'] == '扫二维码付款'])
            print('refunds', [(rec['ref'], rec['stamp'], rec['kind'], rec['amount'], rec['status'])
                              for rec in subset if ('退款' in rec['kind'] or '退款' in rec['status'])
                              and not rec['kind'].startswith(('转账','微信红包'))])
        if number in (1, 3):
            print('recharge', [(rec['ref'], rec['kind'], rec['product'][:50]) for rec in subset
                               if rec['direction'] == '支出' and ('充值' in rec['product'] or '充值' in rec['kind'] or '缴费' in rec['kind'])])
    for refund in records:
        if refund['platform'] == '支付宝' and refund['status'] == '退款成功':
            matches = [(order['ref'], order['amount'], order['status'], order['direction'])
                       for order in records if order['platform'] == '支付宝' and order['status'] != '退款成功'
                       and order['id'] and refund['id'].startswith(order['id'])]
            print('ali refund', refund['ref'], refund['amount'], matches)
        elif refund['platform'] == '微信' and refund['kind'].endswith('-退款') and not refund['kind'].startswith(('转账','微信红包')):
            matches = [(order['ref'], order['merchant'], bool(order['merchant_id'] not in ('','/','-')
                        and (order['merchant_id'] in refund['merchant_id'] or order['merchant_id'] in refund['id'])),
                        bool(order['id'] and order['id'] in refund['id']))
                       for order in records if order['platform'] == '微信' and order['kind'] == '商户消费'
                       and '退款' in order['status'] and order['stamp'] <= refund['stamp']
                       and refund['stamp'] - order['stamp'] < timedelta(days=20)
                       and (order['amount'] == refund['amount'] or '全额' not in order['status'])]
            print('wx refund', refund['ref'], matches)
    sys.exit()

ALI_GROUPS = {
    '交通出行': '交通', '餐饮美食': '餐饮', '服饰装扮': '购物', '日用百货': '购物',
    '家居家装': '购物', '数码电器': '购物', '母婴亲子': '购物', '运动户外': '购物',
    '文化休闲': '文娱', '美容美发': '生活服务', '生活服务': '生活服务',
    '教育培训': '教育', '医疗健康': '医疗', '商业服务': '其他服务', '充值缴费': '其他服务',
    '保险': '其他服务', '酒店旅游': '住宿旅行',
}
WX_GROUPS = [
    ('医疗', r'医院|药房|门诊|挂号'),
    ('交通', r'地铁|公交|滴滴|打车|出租车|乘车码|网约车|顺风车|铁路|12306|机票|共享单车'),
    ('住宿旅行', r'酒店|民宿|旅馆|住宿'),
    ('餐饮', r'外卖|咖啡|coffee|麦当劳|星巴克|喜茶|肯德基|茉莉奶白|鹿角巷|云饺|拌饭|火锅|茶百道|餐饮|塔可贝尔|煮叶|泉膳|麻辣烫'),
    ('购物', r'罗森|lawson|7-11|muji|无印良品|名创优品|京东|京客隆|服饰|uniqlo|revivo|hollister|玩具|便利店|超市|kkv|wowcolour'),
    ('文娱', r'芒果tv|valve|电影票|电玩|演唱会|博物馆|bts《'),
    ('生活服务', r'理发|维修|打印|印之梦|快递|牧家云柜'),
    ('教育', r'教育科技|培训'),
]


def category(rec):
    if rec['platform'] == '支付宝':
        return ALI_GROUPS.get(rec['kind'], '待分类')
    if rec['ref'] in QR:
        return QR[rec['ref']]
    combined = rec['merchant'] + ' ' + rec['product']
    return next((group for group, pattern in WX_GROUPS if re.search(pattern, combined, re.I)), '待分类')


def exclusion(rec):
    kind, status, direction, product = (rec[key] for key in ('kind', 'status', 'direction', 'product'))
    if rec['platform'] == '支付宝':
        if kind in ('投资理财', '信用借还', '账户存取') or status == '解冻成功':
            return '理财、账户存取或还款'
        if kind == '转账红包' or product == '闲鱼转账':
            return '转账或红包'
        if status == '充值成功' or '充值校园卡' in product or kind == '充值缴费' and re.search(r'^为.*交费', product):
            return '预付充值'
        if status not in ('交易成功', '支付成功'):
            return '未完成或关闭'
        if direction == '不计收支':
            return '不计收支（含亲情卡及代付）'
        if direction != '支出':
            return '非支出'
    else:
        if kind == '零钱充值':
            return '预付充值'
        if kind.startswith(('转账', '微信红包')) or kind == '群收款':
            return '转账、红包或群收款'
        if direction != '支出':
            return '非支出'
        if kind == '扫二维码付款' and rec['ref'] not in QR:
            return '扫码收款用途待确认'
        assert kind in ('扫二维码付款', '商户消费') and (status in ('支付成功', '已转账') or '退款' in status)
    return ''


def serial(stamp):
    return (stamp - datetime(1899, 12, 30)).total_seconds() / 86400


def ref_label(ref):
    return f'账单{ref[0]} · {ref[1]}行'


records.sort(key=lambda rec: (rec['stamp'], rec['ref']))
decisions, links, orders_by_id, refund_amounts = {}, {}, {}, Counter()
unique = []
for rec in records:
    ref = rec['ref']
    key = rec['platform'], rec['id']
    if not START <= rec['stamp'].date() <= END:
        decisions[ref] = '超出账期'
    elif rec['id'] not in ('', '/', '-') and key in orders_by_id:
        original = orders_by_id[key]
        assert all(original[field] == rec[field] for field in ('stamp', 'kind', 'direction', 'amount', 'status'))
        decisions[ref] = '重复流水'
        links[ref] = [original['ref']]
    else:
        orders_by_id[key] = rec
        unique.append(rec)

wx_originals = [rec for rec in unique if rec['platform'] == '微信' and rec['kind'] == '商户消费'
                and '退款' in rec['status']]
ali_originals = [rec for rec in unique if rec['platform'] == '支付宝' and rec['status'] != '退款成功']
hospital_refunds = {(6, 26), (6, 27)}
hospital_orders = {(6, 33), (6, 34)}
assert len([rec for rec in wx_originals if rec['ref'] in hospital_orders and rec['amount'] == 5000]) == 2
assert len([rec for rec in unique if rec['ref'] in hospital_refunds and rec['amount'] == 5000]) == 2

for rec in unique:
    ref = rec['ref']
    if ref in hospital_refunds:
        decisions[ref] = '同额退款组（两笔）'
        links[ref] = sorted(hospital_orders)
        continue
    if rec['platform'] == '支付宝' and rec['status'] == '退款成功':
        matches = [order for order in ali_originals if order['id'] and rec['id'] != order['id']
                   and rec['id'].startswith(order['id'])]
    elif rec['platform'] == '微信' and rec['kind'].endswith('-退款') and not rec['kind'].startswith(('转账', '微信红包')):
        matches = [order for order in wx_originals if order['ref'] not in hospital_orders
                   and order['stamp'] <= rec['stamp'] and rec['stamp'] - order['stamp'] < timedelta(days=20)
                   and re.sub(r'\s+', '', order['merchant']).lower() == re.sub(r'\s+', '', rec['kind'][:-3]).lower()
                   and ((order['status'] == '已全额退款' and order['amount'] == rec['amount'])
                        or (order['status'].startswith('已退款(')
                            and round(Decimal(re.search(r'[\d.]+', order['status']).group()) * 100) == rec['amount']))
                   and refund_amounts[order['ref']] == 0]
    else:
        continue
    if len(matches) != 1:
        print('Review', ref, [order['ref'] for order in matches])
        decisions[ref] = '未明确关联的退款'
        links[ref] = [order['ref'] for order in matches]
        continue
    original, = matches
    assert rec['stamp'] >= original['stamp']
    original_ref = original['ref']
    refund_amounts[original_ref] += rec['amount']
    links.setdefault(original_ref, []).append(ref)
    links[ref] = [original_ref]
    decisions[ref] = '退款已归回原单'

for ref in sorted(hospital_orders):
    refund_amounts[ref] = 5000
    links[ref] = sorted(hospital_refunds)

detail = [['交易时间', '周起始日', '支付平台', '原账单类型', '消费类别', '原支付（元）',
           '退款（元）', '净消费（元）', '来源账单', '原账单行']]
audit = [['交易时间', '支付平台', '来源账单', '原账单行', '原类型', '原收支', '原状态', '原金额（元）',
          '清洗结果', '关联原账单行', '纳入净额（元）']]
counts = defaultdict(Counter)
totals = Counter()
cross_time_amount = defaultdict(list)
cross_ids = defaultdict(list)
for rec in records:
    ref = rec['ref']
    stamp = rec['stamp']
    week = stamp.date() - timedelta(days=stamp.weekday())
    withheld = decisions.get(ref) or exclusion(rec)
    refunded = refund_amounts[ref]
    assert 0 <= refunded <= rec['amount']
    if refunded and refunded == rec['amount'] and withheld in ('', '未完成或关闭'):
        withheld = '全额退款原单'
    if rec['platform'] == '微信' and rec['kind'] == '商户消费' and '退款' in rec['status']:
        assert refunded > 0, ref
    net = 0
    if not withheld and rec['amount'] > refunded:
        net = rec['amount'] - refunded
        detail.append([serial(stamp), serial(datetime.combine(week, datetime.min.time())), rec['platform'], rec['kind'],
                       category(rec), rec['amount'] / 100, refunded / 100, net / 100, f'账单{ref[0]}', ref[1]])
        totals[rec['platform']] += net
        cross_time_amount[stamp, rec['amount']].append(rec)
        if rec['merchant_id'] not in ('', '/', '-'):
            cross_ids[rec['merchant_id']].append(rec)
    label = withheld or ('部分退款后纳入' if refunded and net else '纳入消费' if net else '零金额')
    counts[label][rec['platform']] += 1
    audit.append([serial(stamp), rec['platform'], f'账单{ref[0]}', ref[1], rec['kind'], rec['direction'],
                  rec['status'], rec['amount'] / 100, label, '、'.join(map(ref_label, links.get(ref, []))), net / 100])

cross_candidates = {rec['ref'] for group in [*cross_time_amount.values(), *cross_ids.values()]
                    if len({rec['platform'] for rec in group}) > 1 for rec in group}
assert not cross_candidates, cross_candidates
assert len(audit) - 1 == len(records) == sum(sum(items.values()) for items in counts.values())
assert sum(round(row[7] * 100) for row in detail[1:]) == sum(totals.values())
assert all(left[0] <= right[0] for left, right in zip(detail[1:], detail[2:]))
notes = [
    ['项目', '口径或结果', '支付宝笔数', '微信笔数'],
    ['共同账期', '2024-09-01 至 2026-11-01（含首尾）。按交易时间升序，同秒按来源账单和行号排序。', None, None],
    ['消费口径', '统计自主支付的商品和服务。排除非支出、转账、红包、群收款、储值充值、理财、还款和代付。', None, None],
    ['扫码付款', '收款方明确为商户或服务方时纳入，用途待确认的扫码付款留在清洗流水。', None, None],
    ['重叠去重', '同一平台用交易号去重，并核对金额、时间、收支和状态。消费记录另核对跨平台商户单号及同秒同金额。', None, None],
    ['退款归属', '支付宝按原交易号前缀匹配，可跨账单。微信按商户、时间、金额和状态校验。退款回冲原支付日。', None, None],
    ['同额退款', '两笔同额医院付款与两笔退款按组核销。清洗流水保留组内行号。', None, None],
    ['分类', '支付宝按原分类映射，微信按商户和商品关键词归类。待分类仍计入总消费。', None, None],
    ['行号', '账单编号加原账单行定位原始记录。支付宝按 CSV 记录计数，微信按 Excel 行号。', None, None],
    ['周起始日', '周一作为周起始日。2024-09-01 为账期首日，归属起始于 2024-08-26 的不完整周。', None, None],
    ['合计净消费', f'{sum(totals.values()) / 100:,.2f} 元（支付宝 {totals["支付宝"] / 100:,.2f} 元，微信 {totals["微信"] / 100:,.2f} 元）', None, None],
    ['原始记录', None, sum(rec['platform'] == '支付宝' for rec in records), sum(rec['platform'] == '微信' for rec in records)],
]
for number, filename in enumerate(FILES, 1):
    notes.append([f'账单{number}', filename, None, None])
for label, tally in counts.items():
    notes.append([label, None, tally['支付宝'], tally['微信']])
Path(__file__).with_name('merged-data.json').write_text(
    json.dumps({'details': detail, 'notes': notes, 'audit': audit}, ensure_ascii=False), encoding='utf-8')
print('raw', len(records), 'detail', len(detail) - 1, 'net', sum(totals.values()) / 100)
print('first and last source times', records[0]['stamp'], records[-1]['stamp'])
print('counts', dict(counts))
