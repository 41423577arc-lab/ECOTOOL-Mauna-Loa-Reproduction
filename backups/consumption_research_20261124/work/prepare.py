import json
import re
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path

from bills import sources


START = date(2025, 9, 1)
END = date(2026, 8, 31)
LAST_FULL = START + timedelta(days=364)
WX_QR = {31: '购物', 83: '其他服务', 126: '购物', 380: '购物', 437: '生活服务', 684: '文娱'}
WX_REFUNDS = {101: 102, 142: 146, 334: 335, 427: 429}
ALI_GROUPS = {
    '交通': ['交通出行'], '餐饮': ['餐饮美食'], '购物': ['服饰装扮', '日用百货', '家居家装',
    '数码电器', '母婴亲子', '运动户外'], '文娱': ['文化休闲'], '生活服务': ['美容美发',
    '生活服务'], '教育': ['教育培训'], '医疗': ['医疗健康'], '其他服务': ['商业服务',
    '充值缴费', '保险'], '住宿旅行': ['酒店旅游']
}
WX_GROUPS = [
    ('医疗', r'医院|药房|门诊|挂号'),
    ('交通', r'地铁|公交|滴滴|打车|出租车|乘车码|网约车|顺风车|铁路|12306|机票|共享单车'),
    ('住宿旅行', r'酒店|民宿|旅馆|住宿'),
    ('餐饮', r'外卖|咖啡|coffee|麦当劳|星巴克|喜茶|肯德基|茉莉奶白|鹿角巷|云饺|拌饭|火锅|茶百道|餐饮|塔可贝尔|煮叶|泉膳'),
    ('购物', r'罗森|lawson|7-11|muji|无印良品|名创优品|京东|京客隆|服饰|uniqlo|revivo|hollister|玩具|便利店|超市|kkv|wowcolour'),
    ('文娱', r'芒果tv|valve|电影票|电玩|演唱会|博物馆|bts《'),
    ('生活服务', r'理发|维修|打印|印之梦|快递|牧家云柜'),
    ('教育', r'教育科技|培训')
]
ALI_CATEGORY = {original: group for group, originals in ALI_GROUPS.items() for original in originals}


def classify(platform, line, kind, raw):
    if platform == '支付宝':
        return ALI_CATEGORY.get(kind, '待分类'), '支付宝原分类映射'
    if line in WX_QR:
        return WX_QR[line], '扫码商户人工识别'
    combined = raw['交易对方'] + ' ' + raw['商品']
    for group, pattern in WX_GROUPS:
        if re.search(pattern, combined, re.I):
            return group, '微信商户或商品关键词'
    return '待分类', '账单信息不足'


def read_records():
    filenames = {}
    records = []
    for platform, filename, rows in sources():
        filenames[platform] = filename
        for line, raw in rows:
            ali = platform == '支付宝'
            records.append({
                'platform': platform, 'line': line, 'raw': raw,
                'time': datetime.fromisoformat(raw['交易时间']),
                'kind': raw['交易分类' if ali else '交易类型'],
                'status': raw['交易状态' if ali else '当前状态'],
                'amount': int(Decimal(raw['金额' if ali else '金额(元)'].replace('¥', '').replace('￥', '')) * 100),
                'direction': raw['收/支'],
                'id': raw['交易订单号' if ali else '交易单号'],
                'merchant_id': raw['商家订单号' if ali else '商户单号'],
                'product': raw['商品说明' if ali else '商品']
            })
    return filenames, records


def reason(record):
    platform, line, kind, status, direction, product = (
        record[key] for key in ['platform', 'line', 'kind', 'status', 'direction', 'product'])
    if platform == '支付宝':
        if kind in ('投资理财', '信用借还'):
            return '理财或信用还款'
        if kind == '转账红包' or product == '闲鱼转账':
            return '转账或红包'
        if '充值校园卡' in product or kind == '充值缴费' and re.search(r'^为.*交费', product):
            return '预付充值'
        if status != '交易成功':
            return '未完成或关闭'
        if direction == '不计收支':
            return '亲情卡或他人代付'
        if direction != '支出':
            return '收入'
    else:
        if kind not in ('商户消费', '扫二维码付款'):
            return '转账、红包或群收款'
        if kind == '扫二维码付款' and line not in WX_QR:
            return '扫码收款用途待确认'
        if direction != '支出':
            return '收入'
        if status not in ('支付成功', '已转账', '已全额退款'):
            raise ValueError((platform, line, status))
    return ''


def yuan(cents):
    return cents / 100


def serial(day):
    return (day - date(1899, 12, 30)).days


filenames, records = read_records()
by_row = {(rec['platform'], rec['line']): rec for rec in records}
reasons = {}
seen = {}
refund_map = defaultdict(list)
linked = {}
for rec in records:
    ref = rec['platform'], rec['line']
    key = rec['platform'], rec['id']
    if not START <= rec['time'].date() <= END:
        reasons[ref] = '超出共同区间'
    elif rec['id'] not in ('', '/', '-') and key in seen:
        assert rec['raw'] == seen[key]['raw']
        reasons[ref] = '重复流水'
        linked[ref] = [seen[key]['line']]
    else:
        seen[key] = rec

ali_orders = [rec for rec in records if rec['platform'] == '支付宝' and rec['status'] != '退款成功']
for rec in records:
    ref = rec['platform'], rec['line']
    if ref in reasons:
        continue
    if rec['platform'] == '支付宝' and rec['status'] == '退款成功':
        matched = [order for order in ali_orders if order['id'] and rec['id'].startswith(order['id'])
                   and rec['id'] != order['id']]
        original, = matched
    elif rec['platform'] == '微信' and rec['kind'] == '美团-退款':
        original = by_row['微信', WX_REFUNDS[rec['line']]]
        assert original['amount'] == rec['amount'] and original['status'] == '已全额退款'
    else:
        continue
    original_ref = original['platform'], original['line']
    assert original_ref not in reasons and original['time'] <= rec['time']
    refund_map[original_ref].append(rec)
    linked[ref] = [original['line']]
    reasons[ref] = '退款已归回原单'

details = []
audit = []
totals = defaultdict(Counter)
weekly = Counter()
included = Counter()
for rec in sorted(records, key=lambda item: (item['time'], item['platform'], item['line'])):
    platform, line = rec['platform'], rec['line']
    ref = platform, line
    stamp = rec['time']
    week = stamp.date() - timedelta(days=stamp.weekday())
    refunds = refund_map.get(ref, [])
    refunded = sum(item['amount'] for item in refunds)
    if refunds:
        linked[ref] = [item['line'] for item in refunds]
    assert 0 <= refunded <= rec['amount']
    loss_reason = reasons.get(ref) or reason(rec)
    if refunds and refunded == rec['amount'] and loss_reason in ('', '未完成或关闭'):
        loss_reason = '全额退款原单'
    if rec['platform'] == '微信' and rec['kind'] == '商户消费' and rec['status'] == '已全额退款':
        assert loss_reason == '全额退款原单'
    net = 0
    if not loss_reason:
        net = rec['amount'] - refunded
        category, basis = classify(platform, line, rec['kind'], rec['raw'])
        details.append([serial(stamp.date()) + (stamp.hour * 3600 + stamp.minute * 60 + stamp.second) / 86400,
                        serial(week), platform, rec['kind'], category, basis, yuan(rec['amount']),
                        yuan(refunded), yuan(net), line])
        weekly[week] += net
        included[platform] += net
    label = loss_reason or ('部分退款后纳入' if refunded else '纳入消费')
    totals[platform][label] += 1
    audit.append([platform, line, stamp.isoformat(sep=' '), rec['kind'], rec['direction'], rec['status'],
                  yuan(rec['amount']), label, '、'.join(map(str, linked.get(ref, []))), yuan(net)])

buyers = {platform: [rec for rec in records if rec['platform'] == platform] for platform in filenames}
across_same_merchant = {rec['merchant_id'] for rec in buyers['支付宝']} & {rec['merchant_id'] for rec in buyers['微信']}
across_same_txn = {rec['id'] for rec in buyers['支付宝']} & {rec['id'] for rec in buyers['微信']}
across_same_time_amount = {(rec['time'], rec['amount']) for rec in buyers['支付宝']} & {
    (rec['time'], rec['amount']) for rec in buyers['微信']}
assert not (across_same_merchant - {'', '/', '-'}) and not (across_same_txn - {'', '/', '-'})
assert not across_same_time_amount
assert len(audit) == len(records) == sum(sum(counts.values()) for counts in totals.values())
assert len({(row[0], row[1]) for row in audit}) == len(audit)
assert all(START <= day <= END for day in weekly)
assert sum(weekly.values()) == sum(included.values())
weeks = [[serial(START + timedelta(weeks=index)), yuan(weekly[START + timedelta(weeks=index)])]
         for index in range(52)]
assert LAST_FULL == END and len(weeks) == 52
model_total = sum(weekly[START + timedelta(weeks=index)] for index in range(52))
assert model_total + weekly[LAST_FULL] == sum(included.values())
notes = [
    ['项目', '口径或结果', '支付宝笔数', '微信笔数'],
    ['账期', '2025-09-01 至 2026-08-31（含首尾），按账单本地时间。', None, None],
    ['模型输入', 'ARIMA、ETS、UC 共用周起始日和每周净消费金额。周一至周日，共 52 个完整周，空周补 0。', None, None],
    ['模型表覆盖', '2025-09-01 至 2026-08-30，最后一周起始于 2026-08-24。', None, None],
    ['末尾一天', f'2026-08-31 仅覆盖周一，净消费 {yuan(weekly[LAST_FULL]):,.2f} 元，保留在消费明细，排除出模型表。', None, None],
    ['消费范围', '统计自主支付的商品和服务。排除收入、转账、红包、群收款、理财、还款、话费预存及校园卡充值。', None, None],
    ['代付', '支付宝亲情卡和他人代付标为不计收支，从自主支付口径排除。', None, None],
    ['扫码付款', '收款方能识别为商户或服务提供者时纳入。用途不明确的扫码付款在清洗流水标记待确认。', None, None],
    ['退款', '支付宝以原交易号前缀关联。微信美团逐笔按金额、退款状态、先付款后退款和商户线索配对。', None, None],
    ['退款归属', '退款回冲原支付日。全额退款的原单和退款行只留在清洗流水。关联原账单行可双向追查。', None, None],
    ['去重', '核对平台内交易号、跨平台交易号、商户单号与同秒同金额，未发现重复。', None, None],
    ['消费类别', '支付宝使用原分类映射，微信用商户或商品关键词归类。待分类仍计入总消费。', None, None],
    ['追查原账单', '平台与原账单行共同定位原始记录。支付宝行号按 CSV 记录计数，微信对应 Excel 行。', None, None],
    ['支付宝来源', filenames['支付宝'], None, None],
    ['微信来源', filenames['微信'], None, None],
    ['全区间净消费', f'{yuan(sum(included.values())):,.2f} 元', None, None],
    ['52 周净消费', f'{yuan(model_total):,.2f} 元', None, None],
    ['原始记录', None, len(buyers['支付宝']), len(buyers['微信'])]
]
for label in ['纳入消费', '部分退款后纳入', '超出共同区间', '重复流水', '全额退款原单',
              '退款已归回原单', '理财或信用还款', '转账或红包', '预付充值', '未完成或关闭',
              '亲情卡或他人代付', '收入', '转账、红包或群收款', '扫码收款用途待确认']:
    notes.append([label, None, totals['支付宝'][label], totals['微信'][label]])
assert sum(row[2] for row in notes[18:]) == len(buyers['支付宝'])
assert sum(row[3] for row in notes[18:]) == len(buyers['微信'])
data = {
    'weekly': [['周起始日', '净消费金额（元）'], *weeks],
    'details': [['交易时间', '周起始日', '支付平台', '原账单类型', '消费类别', '分类依据',
                 '原支付（元）', '退款（元）', '净消费（元）', '原账单行'], *details],
    'audit': [['支付平台', '原账单行', '原交易时间', '原类型', '原收支', '原状态', '原金额（元）',
               '清洗结果', '关联原账单行', '纳入净额（元）'], *audit],
    'notes': notes,
}
Path(__file__).with_name('data.json').write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
print('detail', len(details), 'total', yuan(sum(included.values())), '52 weeks', yuan(model_total),
      'last day', yuan(weekly[LAST_FULL]), 'platforms', dict(totals))
