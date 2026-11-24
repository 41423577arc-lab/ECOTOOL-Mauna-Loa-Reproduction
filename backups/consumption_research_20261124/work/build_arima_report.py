import csv
import json
from pathlib import Path
from statistics import mean
from math import sqrt

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.section import WD_SECTION_START, WD_ORIENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs'
WORK = ROOT / 'work'


def read(name):
    with (OUT / name).open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))


daily = read('AutoARIMA_220轮滚动回测.csv')
weekly = read('ECOTOOL_ARIMA_49轮周频回测.csv')
comparison = read('ECOTOOL_49轮_ARIMA_ETS_UC比较.csv')
paper = read('ECOTOOL原版_ARIMA_2026年9至11月.csv')
summary = json.loads((WORK / 'rolling-results.json').read_text(encoding='utf-8'))
assert len(daily) == 220 and len(weekly) == 49
assert len(comparison) == 51


def amount(value):
    return f'{float(value):,.2f}'


document = Document()
section = document.sections[0]
section.page_width, section.page_height = Inches(8.5), Inches(11)
section.top_margin = section.bottom_margin = Inches(.65)
section.left_margin = section.right_margin = Inches(.7)
for name in ('Normal', 'Title', 'Heading 1', 'Heading 2', 'Caption'):
    style = document.styles[name]
    style.font.name = 'Microsoft YaHei'
    style.element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'), 'Microsoft YaHei')
    style.font.color.rgb = RGBColor(0, 0, 0)
    style.font.size = Pt(10.5 if name == 'Normal' else 22 if name == 'Title' else 15 if name == 'Heading 1' else 11)
document.styles['Normal'].paragraph_format.space_after = Pt(7)
document.styles['Normal'].paragraph_format.line_spacing = 1.16
footer = section.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
footer.add_run('ARIMA 消费预测实验汇总  |  ')
field = OxmlElement('w:fldSimple')
field.set(qn('w:instr'), 'PAGE')
footer._p.append(field)


def paragraph(text):
    return document.add_paragraph(text)


def heading(text):
    document.add_heading(text, level=1)


def new_page(text):
    document.add_page_break()
    heading(text)


def table(headers, rows, widths=None, size=9):
    grid = document.add_table(rows=1, cols=len(headers))
    grid.autofit = False
    if widths:
        for column, width in zip(grid.columns, widths):
            column.width = Inches(width)
    for cell, title in zip(grid.rows[0].cells, headers):
        cell.text = str(title)
    for row in rows:
        for cell, value in zip(grid.add_row().cells, row):
            cell.text = '' if value is None else str(value)
    for number, row in enumerate(grid.rows):
        row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        for index, cell in enumerate(row.cells):
            if widths:
                cell.width = Inches(widths[index])
            props = cell._tc.get_or_add_tcPr()
            shading = OxmlElement('w:shd')
            shading.set(qn('w:fill'), 'DDE8EE' if number == 0 else 'F3F6F8' if number % 2 == 0 else 'FFFFFF')
            props.append(shading)
            borders = OxmlElement('w:tcBorders')
            for edge in ('top', 'left', 'bottom', 'right'):
                border = OxmlElement(f'w:{edge}')
                border.set(qn('w:val'), 'single')
                border.set(qn('w:sz'), '4')
                border.set(qn('w:color'), 'D9D9D9')
                borders.append(border)
            props.append(borders)
            margins = OxmlElement('w:tcMar')
            for edge in ('top', 'bottom', 'left', 'right'):
                margin = OxmlElement(f'w:{edge}')
                margin.set(qn('w:w'), '65')
                margin.set(qn('w:type'), 'dxa')
                margins.append(margin)
            props.append(margins)
            for line in cell.paragraphs:
                line.paragraph_format.space_after = Pt(1)
                line.paragraph_format.line_spacing = 1.05
                if index:
                    line.alignment = WD_ALIGN_PARAGRAPH.CENTER
                for run in line.runs:
                    run.font.size = Pt(size)
                    run.bold = number == 0
    repeat = OxmlElement('w:tblHeader')
    grid.rows[0]._tr.get_or_add_trPr().append(repeat)
    spacer = document.add_paragraph()
    spacer.paragraph_format.space_after = Pt(0)
    spacer.paragraph_format.space_before = Pt(0)
    spacer.paragraph_format.line_spacing = Pt(1)
    spacer.add_run().font.size = Pt(1)
    return grid


document.add_paragraph('个人消费 ARIMA 预测实验汇总', 'Title')
paragraph('支付宝与微信账单  2024 年至 2026 年')
paragraph('整理日期  2026 年 11 月 20 日')
paragraph('本文汇总已经运行的周频、日频和原版 ECOTOOL 月频 ARIMA 实验，包括预测结果、回测误差、运行设定和逐轮记录。月度核对使用 2026 年 9 月及 10 月。')
paragraph('当前主要实验是原版 ECOTOOL 的 49 轮周频扩展窗口回测。它预测未来 4 周净消费的 MAE 为 2,240.38 元，历史均值基准为 1,915.17 元。日频 220 轮实验的误差更大。现有证据支持用历史均值作预算基准，并继续报告复杂模型在这份消费数据上的表现。')
heading('数据和清洗口径')
paragraph('六份原始账单覆盖 2024-09-01 至 2026-11-01。共有 3,449 条原始记录，按自主支付的商品与服务口径保留 2,155 笔，净消费合计 115,235.72 元。转账、红包、群收款、充值、理财、还款及代付等记录按既定清洗规则排除，15 笔用途待确认的扫码付款也未纳入。')
paragraph('合并明细按交易时间升序排列。退款冲回原付款日。日频和 49 轮周频滚动训练按当时可获得的退款信息恢复训练值，未来发生的退款不会提前冲减历史训练数据。评估实际值使用最终清洗后的净消费。')
heading('实验版本索引')
table(['版本', '训练频率和方法', '评价规模'], [
    ['早期周频', 'Python pmdarima，52 周', '单次拟合及 17 次回测'],
    ['日频滚动', 'Python pmdarima，日数据', '220 次日步长回测'],
    ['论文原版月频', 'MATLAB ECOTOOL，季节周期 12', '1 轮返回预测，后 2 轮报错'],
    ['主要周频实验', 'MATLAB ECOTOOL，非季节性', '49 次周步长回测'],
], [1.35, 3.65, 2.1])
paragraph('各版本的训练期、频率、预测期限和实现方式不同。跨版本误差需要结合设定阅读，同一批起点上的模型与基准误差可以直接比较。')

new_page('早期周频实验')
paragraph('输入为首份工作簿中的 52 个完整周，覆盖 2025-09-01 至 2026-08-30。2026-08-31 的 9.90 元保留在交易明细，未作为完整周参与训练。Python pmdarima 使用非季节性 Auto ARIMA，按 AICc 选阶。')
paragraph('模型选出带均值的 ARIMA(0,0,0)。每周预测固定为 1,241.39 元，未来 4 周合计 4,965.55 元。自然月按跨月周在月内覆盖的天数比例汇总，2026 年 9 月预测为 5,320.23 元。')
table(['结果', '金额或设定'], [
    ['历史 52 周消费总额', '64,552.12 元'],
    ['未来每周点预测', '1,241.39 元'],
    ['未来 4 周合计', '4,965.55 元'],
    ['2026 年 9 月估计', '5,320.23 元'],
    ['17 次回测设置', '从 32 周起步，每次加入 1 周，保留未来 4 周实际值'],
], [3.1, 4])
paragraph('17 次滚动回测每次都选出 ARIMA(0,0,0)。由于它的预测与历史均值一致，二者误差相同。该回测只反映首个一年账期内的表现。')
table(['模型', '未来 1 周 MAE', '未来 4 周总额 MAE'], [
    ['Auto ARIMA', '662.56 元', '1,621.64 元'],
    ['历史均值', '662.56 元', '1,621.64 元'],
    ['以上一周为预测', '668.66 元', '2,213.19 元'],
], [2.5, 2.3, 2.3])
heading('对早期结果的理解')
paragraph('该模型给出的水平预测等于历史周均值。它适合描述消费的长期平均水平，对单周大额支出的发生时间没有额外信息。随后扩大账期并切换到日频后，所选阶数和近期水平的影响发生变化，预测金额随之改变。')
paragraph('来源为 work/forecast.py、work/backtest.py 和首份周度模型输入表。17 轮误差来自会话中已执行的结果记录，逐轮输出当时未单独保存。')

new_page('日频 220 轮滚动实验')
paragraph('本实验把清洗后的消费按日求和，账期内没有消费记录的日期补零。使用 Python pmdarima 2.1.1 的 auto_arima，关闭季节项，以 AICc 为选择标准，采用逐步搜索，p 和 q 的上限为 2，差分上限为 2，每次拟合最多 35 次迭代。估计时金额除以 100，输出再乘回 100。')
paragraph('220 个训练截止日从 2026-02-23 至 2026-09-30，逐日扩充训练集。首轮有 541 天训练数据，每轮预测未来 31 天，并分别计算未来 7、28、30 和 31 天的消费总额误差。每轮都重新选阶。')
table(['目标期限', 'ARIMA MAE', '均值 MAE', 'ARIMA RMSE'], [
    [f'{int(row[0])} 天', amount(row[2]), amount(summary['metrics'][index + 1][2]), amount(row[3])]
    for index, row in enumerate(summary['metrics']) if row[1] == 'Auto ARIMA'
], [1.2, 1.9, 1.9, 2.1])
paragraph('上表单位均为元。MAE 是总额预测绝对误差的平均值，RMSE 对大误差赋予更大权重。日频 30 天预测 MAE 为 5,842.36 元，历史均值基准为 2,719.79 元。模型阶数出现次数为 ARIMA(2,1,0) 189 次、ARIMA(2,1,1) 5 次、ARIMA(0,1,1) 25 次和 ARIMA(0,1,2) 1 次。')
heading('自然月预测核对')
table(['月份', '训练截止日', '预测', '实际', '预测减实际'], [
    [row[0], row[1], amount(row[4]), amount(row[5]), amount(row[6])]
    for row in summary['months'][:2]
], [1.05, 1.45, 1.45, 1.5, 1.65])
paragraph('9 月和 10 月均选出 ARIMA(2,1,0)，分别使用 730 天和 760 天训练数据。这里的月度结果来自各月开始前的单独拟合，日预测直接相加得到月总额。220 轮的训练截止日覆盖到 9 月底，因此 9–10 月不能作为这套日频实验完全独立的留出检验。')
paragraph('本实验沿用论文逐步扩充训练集的思路。日频、非季节性和 Python 自动选阶均是针对本数据的调整，论文原版的 MATLAB modelAUTO 实验见后文。附录甲保留 220 轮的训练截止日与各期限实际和预测总额。')

new_page('误差诊断与原版月频实验')
heading('日频预测低估的证据')
paragraph('10 月最后 3 天消费分别为 10 元、4 元和 15.48 元。原日频 ARIMA(2,1,0) 的预测在较低水平上稳定下来，反映了该设定对近期水平的敏感性。9 月 7 日消费 6,043.20 元，9 月 13 日消费 2,632.50 元，两天合计占 9 月消费约 74%，大额交易进一步放大了低估。')
paragraph('使用相同日数据，把差分固定为 d=0 后，自动选择的模型变成带均值的 ARIMA(0,0,0)。9 月预测由 1,599.29 元变为 4,074.24 元，10 月由 2,810.40 元变为 4,524.04 元。这个检查说明差分设定影响很大，尚不能证明固定 d=0 在所有未来时段都更准确。')
heading('直接运行 ECOTOOL 原版')
paragraph('运行环境为 MATLAB R2026a Update 5，调用本机 ECOTOOL 的 modelAUTO。月数据的季节周期设为 [1 12]，每次预测 24 个月，使用工具箱默认的自动差分与变换。这对应论文月度案例的模型调用形式。')
table(['目标月份', '预测起点', '原版反变换预测', '实际净消费'], [
    [row['目标月份'], row['训练截止日'], amount(row['反变换预测（元）']), amount(row['实际净消费（元）'])]
    for row in paper if row['训练截止日'] == '2026-08-31' and row['模型'] == 'Auto ARIMA'
    and row['目标月份'] in ('2026-09', '2026-10')
], [1.15, 1.55, 2.2, 2.2])
paragraph('首轮使用 24 个月训练。modelAUTO 返回的 y0 与 Box–Cox 变换后的训练值一致，经独立核对 λ 为 0.24785156，使用 ECOTOOL 自带 vboxcoxinv 把输出还原为元。上表的 9 月和 10 月预测来自同一轮，分别为提前 1 个月和提前 2 个月的预测。')
paragraph('训练集扩充到 25 个月和 26 个月后，modelAUTO 均出现赋值维度错误。按论文固定阶数运行的 Airline 模型 ARIMA(0,1,1)×(0,1,1)₁₂ 出现数组索引错误。原版内核含受保护的 P 代码，本次记录错误并保留输入和日志。')
paragraph('论文从 480 个月训练样本起步，逐月扩展并预测未来 24 个月，共 220 轮。消费账单只有 26 个完整月，无法在同样样本长度与评价范围上复现该月度实验。')

new_page('原版 ECOTOOL 的 49 轮周频实验')
paragraph('本实验按用户确认的周频方案实施。每周从周一到周日，完整训练周从 2024-09-02 开始。账期首日 2024-09-01 属于不完整周，未纳入本实验。首轮训练截止 2025-08-31，有 52 周训练数据；末轮截止 2026-08-02，有 100 周训练数据，目标为 2026-08-03 至 2026-08-30。')
paragraph('调用原版 modelAUTO，s=1、boxcox=0、nofs=4，每轮重新选阶。默认运行时逐轮输出量纲无法可靠确认，因此统一关闭 Box–Cox，直接使用人民币原尺度。这是对论文默认设置的调整。49 轮均成功返回 4 周预测。')
table(['模型', '4 周总额 MAE', '4 周总额 RMSE'], [
    ['ECOTOOL Auto ARIMA', '2,240.38', '2,780.63'],
    ['历史均值', '1,915.17', '2,695.99'],
], [2.8, 2.15, 2.15])
paragraph('Auto ARIMA 的 MAE 比历史均值高约 17%。大多数轮次选出带漂移项的 ARIMA(0,1,1)，部分轮次使用更复杂的 ARIMA(2,1,3)。每轮预测的是 4 周总消费，连续轮次的目标区间存在重叠。49 轮提供多个评价起点，不能视为 49 个彼此独立的实验。')
heading('9 月和 10 月的自然月核对')
table(['月份', '训练截止日', '训练周数', 'ARIMA 预测', '实际', '偏差'], [
    ['2026-09', '2026-08-30', '104', '3,897.63', '11,772.04', '−7,874.41'],
    ['2026-10', '2026-09-27', '108', '6,602.19', '4,323.72', '+2,278.47'],
], [1.05, 1.4, .85, 1.25, 1.3, 1.35])
paragraph('月度输出另行拟合，使用月初前最后一个完整周作为训练截止，每次向前预测 6 周，再按各周落在当月的天数比例汇总。这个折算假定周内预测消费均匀分布。10 月预测使用了 9 月已经发生的消费，9–10 月未计入 49 轮的回测误差。')
paragraph('9 月低估约 67%，10 月高估约 53%。周频减少了日末低额记录的直接影响，但仍未充分预测集中大额支出。')

new_page('模型比较与结果使用')
paragraph('同样的 49 个预测起点上，另外运行原版 ECOTOOL 的 ETS 加性趋势无季节模型 AN 和 UC 无季节局部线性趋势 LLT。三种复杂模型均直接使用人民币原尺度。这里只比较这些已运行的设定。')
table(['模型', 'MAE', 'RMSE'], [
    ['历史均值', '1,915.17', '2,695.99'],
    ['Auto ARIMA', '2,240.38', '2,780.63'],
    ['UC 局部线性趋势', '2,344.07', '2,793.54'],
    ['ETS 加性趋势', '3,278.72', '4,111.71'],
], [3.1, 2, 2])
paragraph('历史均值在这套回测中误差最低。报告通过下一页的时间折线图展示预测值是否跟随实际总额变化，以及各轮次高估与低估的幅度。')
paragraph('当前结果为点预测，本次汇总未给出月总额预测区间。日频实验和周频实验的测试日期不同，不能仅按各自 MAE 大小判定频率优劣。固定 d=0 的检查使用了已观察的结果，进一步验证需要保留新的独立测试时段。')
heading('来源与追查方式')
paragraph('方法参考 Pedregal DJ（2019）Time series analysis and forecasting with ECOTOOL，PLOS ONE 14(10)，e0221238。https://doi.org/10.1371/journal.pone.0221238')
paragraph('本地结果依据 AutoARIMA_220轮滚动回测.csv、ECOTOOL_ARIMA_49轮周频回测.csv、ECOTOOL_49轮_ARIMA_ETS_UC比较.csv，以及原版 MATLAB 运行日志和 Box–Cox 量纲诊断结果。附录数值统一保留两位小数，误差由未四舍五入的运行输出计算，末位可能略有差异。')

new_page('日频和周频预测折线图')
paragraph('蓝线为各轮目标期的实际总消费，橙线为 ARIMA 预测总消费，灰线为历史均值基准。横轴按每轮训练截止日排列，纵轴为元。相邻预测区间重叠，因此蓝线显示目标期总额随起点的变化。')
document.add_picture(str(OUT / 'arima-weekly49-line.png'), width=Inches(7.05))
paragraph('周频结果存在明显滞后。第 27 至 31 轮附近实际消费升高时，预测反应较慢；实际消费回落后，预测又持续偏高。')
document.add_picture(str(OUT / 'arima-daily220-line.png'), width=Inches(7.05))
paragraph('日频 30 天总额预测在部分起点出现很高的尖峰，而实际总额更平缓。这些尖峰对应较大的高估误差。两张图使用各自的真实尺度，日频和周频的评价日期及目标长度不同。')

landscape = document.add_section(WD_SECTION_START.NEW_PAGE)
landscape.orientation = WD_ORIENT.LANDSCAPE
landscape.page_width, landscape.page_height = Inches(11), Inches(8.5)
landscape.left_margin = landscape.right_margin = Inches(.55)
landscape.top_margin = landscape.bottom_margin = Inches(.55)
for start in range(0, 220, 17):
    heading(f'附录甲 日频 220 轮逐轮记录 第 {start + 1} 至 {min(start + 17, 220)} 轮')
    if start:
        document.paragraphs[-1].paragraph_format.page_break_before = True
    paragraph('每列金额单位为元，截止日为训练集最后一天。7、28、30 和 31 天分别累计未来日消费。')
    table(['轮次', '训练截止日', '7天实际', '7天预测', '28天实际', '28天预测', '30天实际', '30天预测', '31天实际', '31天预测'],
          [[row['轮次'], row['当轮训练截止日'],
            *[amount(row[f'{days}天{kind}（元）']) for days in (7, 28, 30, 31) for kind in ('实际', '预测')]]
           for row in daily[start:start + 17]],
          [.4, 1.05, *[1.05] * 8], size=8.5)

for start in range(0, 49, 17):
    heading(f'附录乙 周频 49 轮逐轮记录 第 {start + 1} 至 {min(start + 17, 49)} 轮')
    document.paragraphs[-1].paragraph_format.page_break_before = True
    paragraph('每轮在截止日后预测未来 4 个完整周。金额单位为元，偏差为预测总额减实际总额。')
    table(['轮次', '训练截止日', '周数', '第1周预测', '第2周预测', '第3周预测', '第4周预测', '4周预测', '4周实际', '偏差'],
          [[row['轮次'], row['训练截止日'], row['训练周数'],
            *[amount(row[key]) for key in ('第1周预测', '第2周预测', '第3周预测', '第4周预测',
                                          '4周预测合计', '4周实际合计', 'ARIMA有符号误差')]]
           for row in weekly[start:start + 17]],
          [.4, 1.05, .5, *[1.1] * 7], size=8.5)

path = OUT / 'ARIMA消费预测实验汇总_折线图版.docx'
for part in (document.styles.element, document.element):
    for border in list(part.iter(qn('w:pBdr'))):
        border.getparent().remove(border)
document.save(path)
print(path)
