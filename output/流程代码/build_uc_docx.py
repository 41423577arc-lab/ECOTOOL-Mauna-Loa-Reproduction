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
models=['RW','LLT','朴素','三期移动平均'];people=['cyx','tg','yyl']
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
doc.core_properties.subject='三人总支付自然周 UC 分析及 yyl 新旧复现核对'
doc.core_properties.author=''

para('三位成员周消费 UC 与基准预测报告','Title')
para('自然周总支付  RW  LLT  朴素预测  三期移动平均')
para('三份总支付序列按相同日期、滚动窗口和评价指标独立建模。三人均按预定规则选中 RW，且 RW 在本次滚动验证与四周测试中的 MAE 均低于另外三种方法。yyl 的主要分析结果复现了旧自然周结论，稳定性日志存在已单独记录的差异。')
table(['成员','实际来源和处理口径','周数','112周总支付 元'],[
 ['cyx','同名 Excel 由合并消费明细按周汇总净消费','112','114,959.44'],
 ['tg','同名 Excel 原有个人总支付自然周序列','112','115,040.44'],
 ['yyl','同名 Excel 的 UC 建模表总支付列','112','88,773.97']], [.09,.58,.08,.25])
para('三份输入均覆盖 2024-09-02 至 2026-10-25 的 112 个完整自然周，日期唯一连续，金额有限且非负。cyx 与 tg 有 110 周金额相同，两周分别相差 75 元与 6 元；保留各自文件身份，不把二者视为独立重复证据。')
heading('选定 RW 模型的预测误差',2)
main=[]
for p in people:
 for stage in ['滚动30折','测试4期']:
  r=find(p,stage,'RW');main.append([p,stage,r['N']]+[fmt(r[k]) for k in ['MAE','RMSE','sMAPE','MASE']])
table(['成员','任务','N','MAE 元','RMSE 元','sMAPE %','MASE'],main,[.08,.17,.06,.18,.18,.18,.15])
para('滚动验证评价下一周预测；四周测试评价同一训练截止日向前预测四周。测试覆盖 2026-09-28 至 10-25，包含九月底，不代表十月整月；仅四个测试周的结果不宜单独外推。')

page('统一建模流程与评价方法')
table(['项目','三人统一设置'],[
 ['输入和目标','每人 112 周个人总支付 只分析总支付 不分析常规支付'],
 ['训练与测试','前108周训练 至2026-09-27 后4周保留测试'],
 ['滚动验证','扩展窗口 历史长度78至107 共30折 每折预测下一周'],
 ['滚动目标日期','2026-03-02至2026-09-21起始的30个周'],
 ['UC候选','ECOTOOL modelUC 的 RW 与 LLT 均采用相同 CML 调用'],
 ['RW','潜在水平按随机游走演化 并带观测噪声 不单设斜率'],
 ['LLT','水平和斜率均可变化 另有观测噪声'],
 ['朴素预测','下一周取当前最后一期金额 固定原点四步保持第108周金额'],
 ['三期移动平均','滚动取最近三周均值 多步时递归追加预测 不吸收测试值'],
 ['选模','仅在UC中选择 残差诊断唯一通过者优先 否则按滚动MAE再RMSE'],
 ['变换与异常','无外生变量 无季节 不作Box-Cox或对数 不删除大额周']], [.22,.78])
para('先用108周训练数据估计RW、LLT，并重建Kalman一步创新以核对工具箱残差定义。前2周用于初始化，之后106个创新参与诊断。残差Ljung–Box固定采用3、6阶，自由度按滞后阶数给定，不把UC方差参数个数当作ARMA阶数扣除。')
para('MAE是绝对误差均值，RMSE是误差平方均值的平方根；sMAPE逐期采用200倍绝对误差除以实际和预测绝对值之和，两者均为0时记0。MASE逐折用当时训练历史相邻变化的绝对值均值缩放；固定四周统一采用108周训练尺度。')
para('原流程先将选定UC的四步预测锁定，再读取保留测试金额。为完整展示四模型，本报告另补充未选中LLT及两个基准的同原点四步结果；补充结果不改变选模，LLT参数已与原108周估计核对。历史测试数据此前已经观察过，本次属于复现分析。')
para('不发布预测区间：原生预测方差尺度与多步尾部误差尚未校准。训练期平滑成分不能当作实时预测，残差未检出相关也不能证明正态或保证对未来大额支付的预测能力。')

for p in people:
 page(p+' 预测曲线与误差结果')
 para(f'{p} 的最终UC选择为RW。以下四种方法在相同目标周评价；每折都只使用当时已经可用的历史。固定原点四步均从第108周出发，不逐周更新测试真实值。')
 picture(OUT/'报告图表'/f'{p}_rolling.png',f'{p} 四种方法30折扩展窗口一步预测')
 picture(OUT/'报告图表'/f'{p}_fixed.png',f'{p} 四种方法固定原点四周预测')
 table(['阶段','方法','MAE 元','RMSE 元','sMAPE %','MASE'],metric_rows(p),[.16,.19,.17,.17,.17,.14],8.5)
 effects=[]
 for stage in ['滚动30折','测试4期']:
  rw=float(find(p,stage,'RW')['MAE']);naive=float(find(p,stage,'朴素')['MAE']);ma=float(find(p,stage,'三期移动平均')['MAE'])
  effects.append(f'{stage}相对朴素改善{100*(1-rw/naive):.2f}%，相对三期均值改善{100*(1-rw/ma):.2f}%')
 para('RW的MAE改善：'+'；'.join(effects)+'。正值表示RW误差更低。')
 page(p+' UC 残差诊断')
 para('诊断对象为108周全训练期估计的一步创新，前2周初始化不参与检验。图中经验标准化采用残差自身的均值和样本标准差，不等于以可靠预测方差标准化。下图展示最终RW，表中同时保留LLT候选。')
 picture(OUT/p/'总支付-RW一步预测残差诊断.png',f'{p} RW创新时序 ACF 经验分布和正态Q Q图',Inches(6.65))
 diagnostic=rows(OUT/p/'UC模型残差诊断汇总.csv')
 table(['模型','有效创新数','LB滞后阶','Q统计量','p值'],[[r['Model'].replace('总支付-',''),r['N'],r['Lag'],fmt(r['Q']),f"{float(r['PValue']):.6f}"] for r in diagnostic],[.15,.20,.20,.22,.23])
 distribution=rows(OUT/p/'UC模型残差分布统计.csv')
 table(['模型','残差均值 元','残差标准差 元','偏度','峰度'],[[r['Model'].replace('总支付-','')]+[fmt(r[k]) for k in ['MeanYuan','SDYuan','Skewness','Kurtosis']] for r in distribution],[.14,.23,.25,.19,.19])
 para('RW与LLT在本次3、6阶检验中均未检出显著自相关，因此按滚动MAE选RW。分布与Q Q图仍有明显右尾和大额创新，不能把“未检出自相关”理解为正态性或预测完全可靠。异常候选不用于删观测，本流程未进行Jarque–Bera检验。')

page('三位成员 UC 与基准性能比较')
heading('30折一步滚动验证',2)
table(['成员','方法','N','MAE 元','RMSE 元','sMAPE %','MASE'],metric_rows(stage='滚动30折'),[.08,.20,.06,.18,.18,.16,.14],8.5)
heading('固定原点四周测试',2)
table(['成员','方法','N','MAE 元','RMSE 元','sMAPE %','MASE'],metric_rows(stage='测试4期'),[.08,.20,.06,.18,.18,.16,.14],8.5)
para('同一成员同一阶段的四种方法可直接比较；不同成员的绝对误差同时受到金额规模和大额支付波动影响，不能只按MAE或RMSE排名个人可预测性。四周测试的MASE小于1不等于在所有未来区间都超过朴素预测。')

page('三位成员预测性能比较图')
para('上排为30折一步滚动验证，下排为固定原点四周测试；每个阶段分别比较MAE和sMAPE，均越低越好。蓝色RW、紫色LLT、橙色朴素、绿色三期均值，颜色在各图中保持一致。不同面板纵轴尺度不同。')
picture(OUT/'报告图表'/'三人四模型误差比较.png','三人四种方法在两类任务中的误差比较')
table(['成员','滚动MAE最低','四周测试MAE最低','滚动RMSE最低'],[[p,'RW','RW','LLT' if p=='yyl' else 'RW'] for p in people],[.12,.29,.30,.29])
para('三人本次两类任务的MAE均以RW较低，但yyl滚动RMSE以LLT的658.89元较低，RW为681.09元。选模按预先固定的MAE优先规则执行，不因为RMSE或测试期个别指标改变结论。')
para('cyx与tg的单周突发大额支付使最近三期均值在测试开始时偏高，递归预测又将这一偏高延续。RW使用估计的潜在水平，而不是机械采用最后一个观测，所以与朴素预测的点预测并不相同。以上解释对应图中模式，不构成对支出原因的因果判断。')

page('四周累计预测与数据来源')
table(['成员','方法','四周预测 元','四周实际 元','预测减实际 元','相对偏差'],[[r['Person'],r['Model'],fmt(r['ForecastSum']),fmt(r['ActualSum']),fmt(r['ErrorSum']),f"{float(r['RelativeError'])*100:.2f}%"] for r in sums],[.08,.18,.20,.18,.21,.15],8.5)
heading('最终UC模型与数据身份',2)
table(['成员','最终模型','总支付口径'],[['cyx','RW','已清洗净消费 退款回冲原支付日'],['tg','RW','原表个人总支付周金额'],['yyl','RW','总支付 含原表保留的大额事件及校园卡代理支付']],[.10,.15,.75])
para('cyx与tg两处差异为2025-04-07起始周435.09与510.09元、2026-09-28起始周1268.57与1274.57元。除这两周外金额相同；本报告不据文件标签声称其独立性。yyl采用总支付，未替换为常规支付。三份原始文件保存在raw_data，归一化输入保存在data。')
para('累计结果覆盖2026-09-28至10-25。旧整合结果中自然周“十月预测”另含10-26起始周并按天分摊到整月，不能直接与上表四周金额要求一致。原始净消费、充值代理支付等口径差异也限制跨人比较。')

page('yyl 新旧结果核对与结论边界')
para('新yyl与旧自然周的108周训练金额和4周测试金额逐项完全一致；ECOTOOL的modelUC、auxmodelUC、clliket可读实现与旧估计保存的实现一致。12张结果表共79个列项目经过核对，其中主要结果所在的11张表均在预设数值容差内一致。')
table(['核对范围','旧结果','新结果','结论'],[
 ['自然周UC选择','RW','RW','相同'],['滚动MAE 元','481.943595','481.943595','相同'],['滚动RMSE 元','681.089188','681.089188','相同'],['四周预测合计 元','3474.010622','3474.010622','相同'],['四周真实合计 元','3530.54','3530.54','相同'],['稳定性日志索引异常','60条','0条','记录不同']], [.35,.22,.22,.21])
para('数值容差为1e-6加该列旧结果最大绝对值的1e-8倍。除上表摘要，还核对了方差参数、样本内拟合、残差检验与分布、异常候选、30折逐期预测、敏感性字段、最终参数及逐期测试预测。详细核对见yyl新旧数值逐项核对.csv。')
para('稳定性表的MaxScoreSE和Failure两列没有完全复现：旧表记录60条“数组索引必须为正整数或逻辑值”，对应标准误为缺失；新表没有这些异常。旧表相应预测值仍有限并与新值一致；仅凭旧日志不能确定历史运行时具体错误位置。因此主要数值及选模结论一致，不代表全部文件完全相同。')
table(['旧时间聚合','旧UC选择','本次自然周UC','比较边界'],[['月度','LLT','RW','不同聚合 不能要求相同'],['自然周','RW','RW','同人同数据 可直接数值复现'],['连续七天','RW','RW','模型一致 具体数值不可直接等同']],[.18,.18,.23,.41])
para('一月异常月份敏感性字段沿用旧流程，但30折验证从2026-03-02开始，不包含一月。其一月误差占比0属于空子集结果，不表示一月大额事件对参数估计没有影响。保留字段用于复现，不将其作为稳健性证据。')
para('结论适用于当前数据、当前自然周边界和当前窗口：RW在本次MAE比较中较好，不能保证未来最优。测试仅4周，已观察的历史数据不构成新的前瞻验证；残差重尾和数据口径差异仍需保留。')
heading('复现入口与配套文件',2)
para('根目录run_all_uc.m运行原六步总支付流程；output下cyx、tg、yyl分别存放结果。报告四模型性能汇总.csv、报告四模型固定原点预测.csv和报告四模型累计预测.csv支撑本报告补充比较；流程代码含报告生成程序。同目录UC分析流程简述.md提供总体sequence及四种方法的彩色流程图。')

assert hashlib.sha256(REFERENCE.read_bytes()).hexdigest()==source_hash
final_path=OUT/'三位成员周消费_UC与基准预测报告.docx'
doc.save(final_path)
# python-docx may reserialize untouched parts. Retain the reference bytes exactly.
preserve={'word/styles.xml','word/numbering.xml','word/theme/theme1.xml'}
temp_path=final_path.with_suffix('.docx.tmp')
with zipfile.ZipFile(REFERENCE) as source,zipfile.ZipFile(final_path) as generated,zipfile.ZipFile(temp_path,'w',zipfile.ZIP_DEFLATED) as result:
 for info in generated.infolist():
  result.writestr(info,source.read(info.filename) if info.filename in preserve else generated.read(info.filename))
temp_path.replace(final_path)
print('Saved',final_path)
