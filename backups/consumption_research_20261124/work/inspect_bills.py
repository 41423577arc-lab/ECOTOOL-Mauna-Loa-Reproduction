from collections import Counter
from bills import sources


for platform, _, records in sources():
    key = '交易订单号' if platform == '支付宝' else '交易单号'
    merchant = '商家订单号' if platform == '支付宝' else '商户单号'
    id_counts = Counter(record[key] for _, record in records)
    print('duplicate IDs', Counter(id_counts.values()))
    print('combos', Counter((record.get('交易分类', record.get('交易类型')),
                            record['收/支'], record.get('交易状态', record.get('当前状态')))
                           for _, record in records).most_common())
    for line, record in records:
        status = record.get('交易状态', record.get('当前状态'))
        kind = record.get('交易分类', record.get('交易类型'))
        if (platform == '支付宝' and ('退款' in status or kind in ('充值缴费','保险','信用借还','其他','转账红包'))) or (
                platform == '微信' and (kind == '美团-退款' or kind == '扫二维码付款' or
                                         kind == '商户消费' and '退款' in status)):
            match_id = [other_line for other_line, other in records if other_line != line and
                        (other[key] == record[key] or (other[key] and other[key] in record[key]))]
            match_merchant = [other_line for other_line, other in records if other_line != line and
                              other[merchant] and other[merchant] not in ('/', '-') and
                              (other[merchant] == record[merchant] or other[merchant] in record[merchant])]
            print(line, kind, status, record['收/支'], record.get('金额', record.get('金额(元)')),
                  record.get('商品说明', record.get('商品')), match_id, match_merchant)
