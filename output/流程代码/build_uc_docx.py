"""Use the retained DOCX's styles and component patterns for the UC report."""
from pathlib import Path
from copy import deepcopy
import csv,json,hashlib,zipfile,argparse,os
from docx import Document
from docx.shared import Inches,Pt,RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT,WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output'
parser=argparse.ArgumentParser(description='使用给定Word参考模板生成UC报告。')
parser.add_argument('--template',type=Path,default=Path(os.environ['UC_REPORT_TEMPLATE']) if os.environ.get('UC_REPORT_TEMPLATE') else None)
args=parser.parse_args()
if args.template is None or not args.template.is_file():
 parser.error('请使用 --template 指定参考DOCX，或设置 UC_REPORT_TEMPLATE；参考文件不随公开仓库分发。')
REFERENCE=args.template.resolve()
def rows(p):
 with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
metrics=rows(OUT/'报告四模型性能汇总.csv')
forecast=rows(OUT/'报告四模型固定原点预测.csv')
sums=rows(OUT/'报告四模型累计预测.csv')
models=['RW','LLT','朴素','三期移动平均'];people=['A','B','C']
source_hash=hashlib.sha256(REFERENCE.read_bytes()).hexdigest()
ref=Document(REFERENCE);doc=Document(REFERENCE)
patterns={len(t.columns):deepcopy(t._tbl) for t in ref.tables}
body=doc._element.body
for element in list(body):
 if element.tag!=qn('w:sectPr'):body.remove(element)
for rel in list(doc.part.rels.values()):
 if rel.reltype.endswith('/image'):doc.part.drop_rel(rel.rId)
WIDTH=doc.sections[0].page_width-doc.sections[0].left_margin-doc.sections[0].right_margin

def font(run,size=None,bold=None):
 run.font.name='微软雅黑'
 run._element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'),'微软雅黑')
 if size is not None:run.font.size=Pt(size)
 if bold is not None:run.bold=bold
 run.font.color.rgb=RGBColor(0,0,0)
 return run
def para(text='',style='Normal',bold=False):
 p=doc.add_paragraph(style=style);font(p.add_run(text),bold=bold)
 return p
def heading(text,level=1):return para(text,'Heading '+str(level))
def page(text):doc.add_page_break();heading(text)
def table(headers,data,widths=None,size=9):
 n=len(headers);prototype=deepcopy(patterns[n]);body.insert(len(body)-1,prototype)
 from docx.table import Table
 t=Table(prototype,doc._body)
 header=deepcopy(t.rows[0]._tr);normal=deepcopy(t.rows[1]._tr)
 for tr in list(t._tbl.findall(qn('w:tr'))):t._tbl.remove(tr)
 for idx,values in enumerate([headers]+data):
  tr=deepcopy(header if idx==0 else normal);t._tbl.append(tr)
  cells=t.rows[-1].cells
  for j,(cell,text) in enumerate(zip(cells,values)):
   cell.text='';cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
   p=cell.paragraphs[0];p.paragraph_format.space_before=Pt(0);p.paragraph_format.space_after=Pt(0)
   p.paragraph_format.line_spacing=Pt(12)
   snap=OxmlElement('w:snapToGrid');snap.set(qn('w:val'),'0');p._p.get_or_add_pPr().append(snap)
   p.alignment=WD_ALIGN_PARAGRAPH.LEFT if j==0 else WD_ALIGN_PARAGRAPH.CENTER
   font(p.add_run(str(text)),size,idx==0)
   tcPr=cell._tc.get_or_add_tcPr()
   shading=tcPr.find(qn('w:shd'))
   if shading is None:shading=OxmlElement('w:shd');tcPr.append(shading)
   shading.set(qn('w:fill'),'E7EDF2' if idx==0 else ('F3F6F8' if idx%2==0 else 'FFFFFF'))
   margins=tcPr.find(qn('w:tcMar'))
   if margins is None:margins=OxmlElement('w:tcMar');tcPr.append(margins)
   for side in ['top','bottom','left','right']:
    node=margins.find(qn('w:'+side))
    if node is None:node=OxmlElement('w:'+side);margins.append(node)
    node.set(qn('w:w'),'65' if side in ['left','right'] else '35');node.set(qn('w:type'),'dxa')
  trPr=tr.get_or_add_trPr()
  for h in list(trPr.findall(qn('w:trHeight'))):trPr.remove(h)
  cant=OxmlElement('w:cantSplit');trPr.append(cant)
  if idx==0:
   repeat=OxmlElement('w:tblHeader');trPr.append(repeat)
 t.alignment=WD_TABLE_ALIGNMENT.CENTER;t.autofit=False
 if widths is None:widths=[1/n]*n
 for j,w in enumerate(widths):
  width=int(WIDTH*w)
  t.columns[j].width=width
  for row in t.rows:row.cells[j].width=width
 borders=t._tbl.tblPr.find(qn('w:tblBorders'))
 if borders is None:borders=OxmlElement('w:tblBorders');t._tbl.tblPr.append(borders)
 for side in ['top','left','bottom','right','insideH','insideV']:
  edge=borders.find(qn('w:'+side))
  if edge is None:edge=OxmlElement('w:'+side);borders.append(edge)
  for key,val in [('val','single'),('sz','4'),('color','D9D9D9')]:edge.set(qn('w:'+key),val)
 spacer=para('');spacer.paragraph_format.space_before=Pt(0);spacer.paragraph_format.space_after=Pt(2);spacer.paragraph_format.line_spacing=Pt(2)
 return t
fig_number=0
def picture(path,caption,width=None):
 global fig_number
 p=doc.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER
 p.paragraph_format.space_before=Pt(0);p.paragraph_format.space_after=Pt(1);p.paragraph_format.keep_with_next=True
 p.add_run().add_picture(str(path),width=WIDTH if width is None else width)
 fig_number+=1
 cap=para(f'图{fig_number}  {caption}','Caption',True)
 cap.paragraph_format.space_after=Pt(5)
 for r in cap.runs:font(r,9,True)
 return p
def fmt(v):return f'{float(v):,.2f}'
def find(person,stage,model):return next(r for r in metrics if (r['Person'],r['Stage'],r['Model'])==(person,stage,model))
def metric_rows(person=None,stage=None):
 result=[]
 for p in people if person is None else [person]:
  for st in ['滚动30折','测试4期'] if stage is None else [stage]:
   for m in models:
    r=find(p,st,m);prefix=[p,m,r['N']] if person is None else [st,m]
    result.append(prefix+[fmt(r[k]) for k in ['MAE','RMSE','sMAPE','MASE']])
 return result

# Retain the source header/footer layout but replace its report identity and date.
for section in doc.sections:
 for p in section.header.paragraphs:
  if p.text:p.clear();font(p.add_run('三位成员周消费 UC 与基准预测'),8,True)
 for p in section.footer.paragraphs:
  if p.text or p._p.findall('.//'+qn('w:fldChar')):
   p.clear();p.alignment=WD_ALIGN_PARAGRAPH.RIGHT;font(p.add_run('2026年11月23日  |  '),8)
   r=p.add_run();field=OxmlElement('w:fldSimple');field.set(qn('w:instr'),'PAGE');r._r.addnext(field)
doc.core_properties.title='三位成员周消费 UC 与基准预测报告'
doc.core_properties.subject='三人总支付自然周 UC 分析及 C 新旧复现核对'
doc.core_properties.author=''

summary=rows(OUT/'三人UC结果汇总.csv')
selected={r['Person']:r['SelectedUC'] for r in summary}
manifest=json.loads((OUT/'运行口径.json').read_text(encoding='utf8'))
totals={'A':88167.33,'B':114959.44,'C':88773.97}
def best(person,stage,key='MAE'):
 return min((r for r in metrics if r['Person']==person and r['Stage']==stage),key=lambda r:float(r[key]))['Model']

para('三位成员周消费 UC 与基准预测报告','Title')
para('成员A数据修正版  自然周总支付  RW  LLT  朴素预测  三期移动平均')
para('本轮以成员A新确认的原始CSV重建输入，三人统一使用A、B、C标识，全部模型重新估计。按预定训练期规则选定的UC分别为'+ '，'.join(f"{p}为{selected[p]}" for p in people)+'。预测评价使用相同目标周，具体优劣由下表和各人结果判断。')
table(['成员','实际来源和提取口径','周数','112周总支付 元'],[
 ['A','A_个人总支付_自然周.csv 的个人总支付_元','112',fmt(totals['A'])],
 ['B','B_个人总支付_自然周.xlsx 合并消费明细净消费按周汇总','112',fmt(totals['B'])],
 ['C','C_个人总支付_自然周.xlsx 的UC建模表总支付列','112',fmt(totals['C'])]], [.09,.58,.08,.25])
para('三份输入均覆盖2024-09-02至2026-10-25的112个完整自然周，日期唯一连续，金额有限且非负。A使用总支付88,167.33元；退款11,220.62元及净支付76,946.71元保留作来源核对，不替换总支付建模目标。旧A输入115,040.44元已弃用。')
heading('按原规则选定UC的预测误差',2)
main=[]
for p in people:
 for stage in ['滚动30折','测试4期']:
  r=find(p,stage,selected[p]);main.append([p,selected[p]+' '+stage,r['N']]+[fmt(r[k]) for k in ['MAE','RMSE','sMAPE','MASE']])
table(['成员','模型和任务','N','MAE 元','RMSE 元','sMAPE %','MASE'],main,[.07,.23,.05,.17,.17,.17,.14])
para('滚动验证评价下一周；四周测试评价同一训练截止日向前预测四周。测试覆盖2026-09-28至10-25，包含九月底，不代表十月整月。原A错误数据上的结果不再用于当前三人比较。')

page('统一建模流程与评价方法')
table(['项目','三人统一设置'],[
 ['建模目标','112周个人总支付；A取CSV总支付列，B与C沿用其确认口径'],
 ['训练与测试','前108周训练至2026-09-27；后4周保留测试'],
 ['滚动验证','扩展窗口；历史长度78至107；共30折，每折预测下一周'],
 ['目标周日期','2026-03-02至2026-09-21起始的30周'],
 ['UC候选','ECOTOOL modelUC 的RW与LLT，采用相同CML调用'],
 ['RW','潜在水平按随机游走演化，并带观测噪声，不单设斜率'],
 ['LLT','水平和斜率均可变化，另有观测噪声'],
 ['朴素预测','取当前最后一期；固定原点四步保持第108周金额'],
 ['三期移动平均','取最近三周均值，多步递归追加预测，不吸收测试值'],
 ['选择规则','只有一个UC通过两阶残差检验时优先选它，否则按滚动MAE、RMSE'],
 ['变换与异常','无外生变量、无季节，不作Box-Cox或对数，不删大额周']], [.22,.78])
para('先以108周训练数据估计RW和LLT，重建Kalman一步创新核对工具箱输出。前2周用于初始化，106个后续创新参与3、6阶Ljung–Box诊断；自由度取滞后阶数，不把方差参数个数当作ARMA阶数扣除。基准不参加UC内部选模，但如实比较误差。')
para('MAE为绝对误差均值，RMSE为误差平方均值的平方根。sMAPE采用200倍口径，两者均为0时记0。MASE逐折以当时历史相邻变化的平均绝对值缩放；四周测试统一使用108周训练尺度。')
para('原流程先锁定选定UC的四步预测，再读取测试金额。报告另补齐另一UC及两个基准的同原点四步展示，参数与全训练期估计核对，不依据测试误差重选模型。本轮全部结果重新估计，不复用旧A缓存。')
para('测试数据已在此前研究中观察过，本轮为历史重算，不是新前瞻验证。原生预测方差和多步尾部误差未校准，因此不发布预测区间；平滑成分不能当作实时预测，残差未拒绝零自相关也不证明正态。')

for p in people:
 model=selected[p]
 page('成员'+p+' 预测曲线与误差结果')
 para(f'成员{p}按训练期规则选定{model}。四种方法在相同目标周评价，每折使用同样的可用历史；固定原点均从第108周向前预测四周，不吸收测试实际值。')
 picture(OUT/'报告图表'/f'{p}_rolling.png',f'成员{p} 四种方法30折扩展窗口一步预测')
 picture(OUT/'报告图表'/f'{p}_fixed.png',f'成员{p} 四种方法固定原点四周预测')
 table(['阶段','方法','MAE 元','RMSE 元','sMAPE %','MASE'],metric_rows(p),[.16,.19,.17,.17,.17,.14],8.5)
 effects=[]
 for stage in ['滚动30折','测试4期']:
  value=float(find(p,stage,model)['MAE']);naive=float(find(p,stage,'朴素')['MAE']);ma=float(find(p,stage,'三期移动平均')['MAE'])
  effects.append(f'{stage}相对朴素改善{100*(1-value/naive):.2f}%，相对三期均值改善{100*(1-value/ma):.2f}%')
 para(model+'的MAE比较：'+'；'.join(effects)+'。正值为误差更低，负值为更高。')
 page('成员'+p+' UC 残差诊断')
 para('诊断对象为108周全训练期估计的一步创新，排除前2周初始化。经验标准化采用残差自身均值和样本标准差，不等于以可靠预测方差标准化。图示选定模型，表中保留两个候选。')
 picture(OUT/p/f'总支付-{model}一步预测残差诊断.png',f'成员{p} {model}创新时序 ACF 经验分布及正态Q Q图',Inches(6.65))
 diagnostic=rows(OUT/p/'UC模型残差诊断汇总.csv')
 table(['模型','有效创新数','LB滞后阶','Q统计量','p值'],[[r['Model'].replace('总支付-',''),r['N'],r['Lag'],fmt(r['Q']),f"{float(r['PValue']):.6f}"] for r in diagnostic],[.15,.20,.20,.22,.23])
 distribution=rows(OUT/p/'UC模型残差分布统计.csv')
 table(['模型','残差均值 元','残差标准差 元','偏度','峰度'],[[r['Model'].replace('总支付-','')]+[fmt(r[k]) for k in ['MeanYuan','SDYuan','Skewness','Kurtosis']] for r in distribution],[.14,.23,.25,.19,.19])
 flags={m:sum(r['RejectH0'] in ['1','true'] for r in diagnostic if r['Model']=='总支付-'+m) for m in ['RW','LLT']}
 para(f'两项固定滞后检验中，RW拒绝零自相关{flags["RW"]}项，LLT拒绝{flags["LLT"]}项；按既定诊断与滚动规则选定{model}。未拒绝不证明模型正确或残差正态；异常候选仅作探索，不删除观测，本流程未进行Jarque–Bera检验。')

page('三位成员 UC 与基准性能比较')
heading('30折一步滚动验证',2)
table(['成员','方法','N','MAE 元','RMSE 元','sMAPE %','MASE'],metric_rows(stage='滚动30折'),[.08,.20,.06,.18,.18,.16,.14],8.5)
heading('固定原点四周测试',2)
table(['成员','方法','N','MAE 元','RMSE 元','sMAPE %','MASE'],metric_rows(stage='测试4期'),[.08,.20,.06,.18,.18,.16,.14],8.5)
para('同一成员同一阶段的四种方法可直接比较；跨成员绝对误差受金额规模和波动影响，不能只按MAE或RMSE排名个人可预测性。四周测试较短，必须与30折验证合看。MASE小于1不保证所有未来区间超过朴素预测。')

page('三位成员预测性能比较图')
para('上排为30折一步滚动验证，下排为固定原点四周测试。蓝色RW、紫色LLT、橙色朴素、绿色三期均值；MAE与sMAPE均越低越好。不同面板采用各自纵轴尺度。')
picture(OUT/'报告图表'/'三人四模型误差比较.png','三人四种方法在两类任务中的误差比较')
table(['成员','选定UC','滚动MAE最低','测试MAE最低','滚动RMSE最低'],[[p,selected[p],best(p,'滚动30折'),best(p,'测试4期'),best(p,'滚动30折','RMSE')] for p in people],[.10,.15,.25,.25,.25])
para('上述最低方法按实际计算生成，不预设三人应有同一结论。UC选择仅使用训练诊断和滚动结果；基准或测试误差更低时如实报告，不回头改变规则。MAE与RMSE的最优方法可能不同，因为后者更重视大额预测错误。')
para('潜在水平与直接使用最后一个金额的朴素预测不同。短期大额支付也可能推高三期均值及其递归预测；这描述方法对既有观测的响应，不构成对支出发生原因的因果解释。')

page('四周累计预测与数据来源')
table(['成员','方法','四周预测 元','四周实际 元','预测减实际 元','相对偏差'],[[r['Person'],r['Model'],fmt(r['ForecastSum']),fmt(r['ActualSum']),fmt(r['ErrorSum']),f"{float(r['RelativeError'])*100:.2f}%"] for r in sums],[.08,.18,.20,.18,.21,.15],8.5)
heading('最终UC与成员数据身份',2)
notes={'A':'原始CSV的个人总支付列，未减去退款','B':'原明细净消费按周汇总，退款回冲原支付日','C':'原表总支付，含已确认大额事件及校园卡代理支付'}
table(['成员','最终模型','统计口径'],[[p,selected[p],notes[p]] for p in people],[.10,.15,.75])
para('全部来源按A、B、C归档在raw_data，建模输入位于data。三人的前置清洗口径不完全相同，不能把总额或误差的跨人差异解释为个人消费倾向或可预测性的直接排名。')
para('累计区间为2026-09-28至10-25。旧整合的自然周“十月预测”另含10-26起始周并按天分摊到整月，不能与这里四周金额直接要求相同。')

page('成员A数据修正与来源核对')
para('此前成员A误用了另一份周金额序列，112周合计115,040.44元。本轮以新确认的CSV重建A输入：112周总支付88,167.33元，全部112个周金额均与旧A输入不同。旧数据及旧结果移至项目目录外备份，当前输出为重新估计结果。')
table(['字段','112周合计 元','用途'],[['个人总支付_元','88,167.33','本轮唯一建模目标'],['退款_元','11,220.62','原始来源核对 不作为预测目标'],['净支付_元','76,946.71','原始来源核对 不替换总支付']],[.28,.25,.47])
para('逐周核验个人总支付减退款等于净支付，日期为2024-09-02至2026-10-19的112个周起始日，未缺失、未重复。修正只替换A的数据身份，训练与测试边界、UC结构、估计调用、评价公式及选模规则均保持不变。')
table(['项目','旧A错误输入','修正后A输入'],[['周数','112','112'],['总支付 元','115,040.44','88,167.33'],['金额发生变化的周数','—','112'],['来源','已弃用的旧周金额','新确认CSV的总支付列']],[.32,.34,.34])
para('A的模型、残差、滚动验证、四周预测及季节周期4对照均重新运行；B和C也按统一命名重新估计。所有图表和段落使用本轮CSV导出的结果，不沿用旧A结论。逐周修正证据见A成员数据修正逐周核对.csv，来源校验值记录于运行口径.json。')
heading('季节周期4另行验证',2)
para('主报告仍为原无季节UC流程。RW4和LLT4在同一数据和窗口上作为附加测试，独立保存在季节周期4测试目录；效果以该目录本轮结论为准，不把旧A上的季节结果用于新A判断，也不据测试误差修改主模型。')

page('成员C历史复现与结论边界')
para('成员C数据未更换。108周训练金额和4周测试金额与原自然周基线逐项一致；ECOTOOL三份可读实现也与原运行保存的版本一致。12张结果表中主要结果所在的11张表在预设数值容差内一致，稳定性日志另有记录差异。')
cr=next(r for r in summary if r['Person']=='C')
table(['核对范围','原自然周基线','本轮成员C','结论'],[['选定UC','RW',cr['SelectedUC'],'一致'],['滚动MAE 元','481.943595',f"{float(cr['RollingMAE']):.6f}",'一致'],['滚动RMSE 元','681.089188',f"{float(cr['RollingRMSE']):.6f}",'一致'],['四周预测合计 元','3474.010622',f"{float(cr['ForecastSum']):.6f}",'一致'],['四周真实合计 元','3530.54',fmt(cr['ActualSum']),'一致'],['稳定性日志索引异常','60条','0条','记录不同']],[.35,.22,.22,.21])
para('数值容差为1e-6加该列旧结果最大绝对值的1e-8倍。核对覆盖方差参数、样本内拟合、残差诊断和分布、异常候选、逐折预测、敏感性字段、最终参数及测试预测。详见C新旧数值逐项核对.csv。')
para('原稳定性日志有60条索引异常，相应MaxScoreSE缺失；本轮没有这些异常。原表的预测值仍有限并与本轮一致，无法仅凭原日志定位当时具体错误位置。因此主要数值及选模一致，不代表所有文件完全相同。该历史复现判断仅针对C，不用于证明A数据正确。')
table(['原时间聚合','原UC','本轮成员C','比较边界'],[['月度','LLT',selected['C'],'不同聚合 不要求相同'],['自然周','RW',selected['C'],'同人同数据 可逐项复现'],['连续七天','RW',selected['C'],'仅比较结论 不直接比较数值']],[.20,.15,.23,.42])
para('一月异常敏感性字段沿用旧流程，但滚动验证从2026-03-02开始，不含一月。其0占比是空子集结果，不能作为一月事件不影响模型的证据。结论限于当前样本和窗口，测试仅四周且已被观察，不能保证未来表现或证明残差正态。')
heading('复现和配套文件',2)
para('根目录run_all_uc.m运行主流程；成员目录为output/A、B、C。prepare_report_results生成四模型表及图；run_season4_test另跑周期4实验。UC分析流程简述.md包含总体sequence及四种方法的彩色流程图。逐笔来源和本机日志不上传公开仓库。')

assert hashlib.sha256(REFERENCE.read_bytes()).hexdigest()==source_hash
final_path=OUT/'A_B_C成员周消费_UC与基准预测报告.docx'
doc.save(final_path)
preserve={'word/styles.xml','word/numbering.xml','word/theme/theme1.xml'}
temp_path=final_path.with_suffix('.docx.tmp')
with zipfile.ZipFile(REFERENCE) as source,zipfile.ZipFile(final_path) as generated,zipfile.ZipFile(temp_path,'w',zipfile.ZIP_DEFLATED) as result:
 for info in generated.infolist():result.writestr(info,source.read(info.filename) if info.filename in preserve else generated.read(info.filename))
temp_path.replace(final_path)
print('Saved',final_path)
