import csv
import json
from collections import Counter
from pathlib import Path
from statistics import mean
from math import sqrt

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn


ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs'
summary=json.loads((ROOT/'work/newbill_rolling_summary.json').read_text(encoding='utf-8'))
with (ROOT/'work/newbill_rolling_output.csv').open(encoding='utf-8-sig') as stream:
    rows=list(csv.DictReader(stream))
assert len(rows)==61 and rows[0]['Date']=='2026-09-01' and rows[-1]['Date']=='2026-10-31'
assert [int(row['TrainingDays']) for row in rows]==list(range(730,791))
counts=Counter(row['Model'] for row in rows)
assert sorted(counts.values())==[1,13,47]
model_labels={
    '(1+a1*B)/(1-B) | Constant/(1-B)':'ARIMA(0,1,1) 带漂移',
    '(1+a1*B+a2*B2)/(1+c1*B)(1-B) | Constant/(1-B)':'ARIMA(1,1,2) 带漂移',
    '(1+a1*B+a2*B2)/(1+c1*B+c2*B2)(1-B) | Constant/(1-B)':'ARIMA(2,1,2) 带漂移',
}
assert set(counts)==set(model_labels)
doc=Document()
sec=doc.sections[0]
sec.page_width,sec.page_height=Inches(8.5),Inches(11)
sec.top_margin=sec.bottom_margin=Inches(.65)
sec.left_margin=sec.right_margin=Inches(.7)
for name,size in [('Normal',11),('Title',22),('Heading 1',15),('Heading 2',12)]:
    style=doc.styles[name]
    style.font.name='Microsoft YaHei'
    style.element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'Microsoft YaHei')
    style.font.size=Pt(size)
    style.font.color.rgb=RGBColor(0,0,0)
doc.styles['Normal'].paragraph_format.line_spacing=1.08
doc.styles['Normal'].paragraph_format.space_after=Pt(6)
footer=sec.footer.paragraphs[0]
footer.alignment=WD_ALIGN_PARAGRAPH.RIGHT
footer.add_run('日消费 ARIMA 滚动预测实验  |  ')
field=OxmlElement('w:fldSimple')
field.set(qn('w:instr'),'PAGE')
footer._p.append(field)


def text(value):
    doc.add_paragraph(value)


def table(headers,values,widths):
    result=doc.add_table(rows=1,cols=len(headers))
    result.autofit=False
    for column,width in zip(result.columns,widths):
        column.width=Inches(width)
    for cell,value in zip(result.rows[0].cells,headers):
        cell.text=str(value)
    for row in values:
        for cell,value in zip(result.add_row().cells,row):
            cell.text=str(value)
    for index,row in enumerate(result.rows):
        row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        for col,cell in enumerate(row.cells):
            cell.width=Inches(widths[col])
            props=cell._tc.get_or_add_tcPr()
            shading=OxmlElement('w:shd')
            shading.set(qn('w:fill'),'DDE8EE' if index==0 else 'F2F6F8' if index%2==0 else 'FFFFFF')
            props.append(shading)
            borders=OxmlElement('w:tcBorders')
            for edge in ('top','bottom','left','right'):
                border=OxmlElement(f'w:{edge}')
                for key,val in [('val','single'),('sz','4'),('color','D9D9D9')]:
                    border.set(qn('w:'+key),val)
                borders.append(border)
            props.append(borders)
            margin=OxmlElement('w:tcMar')
            for edge in ('top','bottom','left','right'):
                node=OxmlElement('w:'+edge)
                node.set(qn('w:w'),'85')
                node.set(qn('w:type'),'dxa')
                margin.append(node)
            props.append(margin)
            for p in cell.paragraphs:
                p.paragraph_format.space_after=Pt(2)
                p.paragraph_format.line_spacing=1.06
                if col:
                    p.alignment=WD_ALIGN_PARAGRAPH.CENTER
                for run in p.runs:
                    run.font.size=Pt(10)
                    run.bold=index==0
    spacer=doc.add_paragraph()
    spacer.paragraph_format.space_after=Pt(0)
    spacer.paragraph_format.line_spacing=Pt(1)
    spacer.add_run().font.size=Pt(1)


doc.add_paragraph('个人日消费 ARIMA 滚动预测报告','Title')
text('基于本人负责的日账单数据  2026 年 9 至 10 月检验')
text('本实验使用日消费数据，通过每日重新选阶和拟合的 Auto ARIMA 预测下一天消费，共完成 61 轮。每日平均绝对误差为 317.12 元，均方根误差为 947.90 元。本次设定对突发大额支出的预测能力较弱，平均绝对误差高于滚动历史均值基准。')
doc.add_heading('1 数据与预测任务',level=1)
text('数据来源为提供的《原始账单_时间粒度为日.csv》，字段为日期和总支出_元，共 791 天，覆盖 2024-09-01 至 2026-10-31。日期连续且无重复，含 91 个零支出日。金额沿用该表已有的总支出口径，791 天支出合计为 117,882.28 元。')
table(['项目','实验设定'],[
    ['初始训练期','2024-09-01 至 2026-08-31，共 730 天'],
    ['滚动检验期','2026-09-01 至 2026-10-31，共 61 天'],
    ['观测频率和目标','每天一个观测值，每轮预测下一天的总支出'],
    ['更新方式','扩展窗口，每次加入前一天实际值，重新选阶并拟合'],
    ['运行工具','MATLAB R2026a 与原版 ECOTOOL modelAUTO'],
], [1.7,5.4])
doc.add_heading('2 模型和滚动流程',level=1)
text('使用非季节性自动 ARIMA，s=1、boxcox=0、nofs=1。自动识别差分和阶数，金额以元直接输入。首轮只使用截至 8 月 31 日的数据预测 9 月 1 日；第 2 轮加入 9 月 1 日实际支出，预测 9 月 2 日。末轮使用截至 10 月 30 日的 790 天数据预测 10 月 31 日。每轮训练期均早于目标日。')
table(['自动选出的模型','出现轮数'],[[model_labels[key],count] for key,count in counts.most_common()], [5.2,1.9])

doc.add_heading('3 预测与实际折线图',level=1).paragraph_format.page_break_before=True
text('蓝线为当天实际支出，橙线为只使用前一天及更早数据得到的次日预测。每个日期对应一个提前作出的预测值。上图保留完整金额范围，下图放大日常支出范围，以便看清预测变化。')
doc.add_picture(str(OUT/'新日账单_ARIMA逐日滚动预测折线图.png'),width=Inches(7.05))
text(f'61 个次日预测值介于 {summary["forecast_min"]:.2f} 元至 {summary["forecast_max"]:.2f} 元。预测在 9 月中旬大额支出发生后上调，此后在较高水平持续一段时间。实际消费回落时，模型反应较慢，因而出现高估。该描述依据图形和逐日结果，尚未进行额外的因果识别。')
text('图中展示模型点预测，未加入未来随机扰动模拟。点预测的平滑程度反映模型对条件消费水平的估计，曲线起伏本身不能代表准确度高低。')

doc.add_heading('4 预测误差和基准比较',level=1).paragraph_format.page_break_before=True
text('MAE 为 61 天绝对预测误差的平均值。RMSE 为误差平方均值的平方根，对大额误差更敏感。两项指标均以元计，数值越小越好。下表在同一份新日账单、相同的 61 天检验期上比较。')
metrics=summary['metrics']
table(['预测方法','MAE 元','RMSE 元'],[
    [label,f'{metrics[label]["MAE"]:,.2f}',f'{metrics[label]["RMSE"]:,.2f}']
    for label in ('逐日滚动ARIMA','滚动历史均值','固定起点ARIMA')
], [3.5,1.8,1.8])
text('滚动历史均值使用每轮训练期内的日均支出预测次日。固定起点 ARIMA 为同一份账单的此前实验，仅在 8 月 31 日拟合一次，随后一次性预测 61 天。滚动 ARIMA 的 MAE 比滚动均值高约 17.3%，但 RMSE 略低，两个指标对日常误差和极端误差的侧重不同。')
doc.add_heading('5 按月汇总的核对结果',level=1)
table(['月份','实际总支出','滚动预测合计','预测减实际'],[
    [row[0],*[f'{number:,.2f}' for number in row[1:]]] for row in summary['monthly']
], [1.2,1.9,2.0,2.0])
text('表内金额单位为元。9 月的预测合计比实际低 6,812.69 元，约低估 50.5%；10 月比实际高 4,167.77 元，约高估 96.5%。月度预测合计由当月逐日更新后的一步预测相加得到，使用了当月已经发生的消费信息，解释时须保留这一更新口径。')
doc.add_heading('6 实验结论',level=1)
text('在这份日消费数据和当前非季节性设定下，原版 ECOTOOL Auto ARIMA 的逐日滚动预测尚未在 MAE 上超过滚动历史均值。集中大额消费和其后的消费回落造成较大偏差。模型提供了可追查的每日预测，但现有结果不足以支持其直接作为可靠的个人消费预算。')
text('UC 是否更优，应在相同数据和相同 61 个预测日期上检验。后续可在训练期内选择季节项及窗口，再用独立时段评价。')
text('方法参考 Pedregal DJ（2019），Time series analysis and forecasting with ECOTOOL，PLOS ONE 14(10)，e0221238。https://doi.org/10.1371/journal.pone.0221238')
for root in (doc.styles.element,doc.element):
    for border in list(root.iter(qn('w:pBdr'))):
        border.getparent().remove(border)
target=OUT/'本人日账单_ARIMA滚动预测实验报告.docx'
doc.save(target)
print(target)
