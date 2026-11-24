from collections import Counter
from bills import sources


alipay, wechat = [records for _, _, records in sources()]
for line, record in alipay:
    if record['交易状态'] == '退款成功':
        matches = [(other_line, other['金额'], other['收/支'], other['交易状态'])
                   for other_line, other in alipay if record['交易订单号'].startswith(other['交易订单号'])
                   and record['交易订单号'] != other['交易订单号']]
        print(line, record['金额'], matches)
no_count = [(line, rec) for line, rec in alipay if rec['收/支'] == '不计收支'
            and rec['交易状态'] == '交易成功' and rec['交易分类'] not in ['投资理财','转账红包']]
print('no count payment', Counter(rec['收/付款方式'] for _, rec in no_count))
for line, rec in no_count:
    print(line, rec['交易分类'], rec['收/付款方式'], rec['商品说明'][:50], rec['备注'][:25])
for line, rec in wechat:
    if rec['交易类型'] in ('扫二维码付款','群收款') or rec['交易时间'].startswith('2026-09-01'):
        print(line, rec['交易时间'][:10], rec['交易类型'], rec['交易对方'], rec['商品'][:30], rec['备注'][:20])
for ali_line, ali in alipay:
    for wx_line, wx in wechat:
        same_id = (ali['商家订单号'] not in ('','/','-') and ali['商家订单号'] == wx['商户单号']
                   or ali['交易订单号'] == wx['交易单号'])
        same_time = ali['交易时间'] == wx['交易时间'] and float(ali['金额']) == float(wx['金额(元)'].replace('¥',''))
        if same_id or same_time:
            print('cross match', ali_line, wx_line, same_id, same_time)
