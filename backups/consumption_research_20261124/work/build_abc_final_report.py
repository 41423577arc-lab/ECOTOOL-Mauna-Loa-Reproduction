import csv,json,re,math,zipfile,shutil
from pathlib import Path
from collections import Counter
from statistics import mean
from PIL import Image,ImageDraw,ImageFont
from docx import Document
from docx.shared import Inches,Pt,RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
R=Path(__file__).resolve().parents[1];O=R/'outputs'/'ABC_AutoARIMA_正式统一版_20261122';W=R/'work'/'abc_final'
def read(name):
    with (O/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
cfg=json.loads((O/'统一实验设置与来源.json').read_text(encoding='utf-8'))
summary=read('ABC_统一评价指标.csv');detail=read('ABC_30折逐折预测.csv');fixed=read('ABC_固定原点四期预测.csv');final=read('ABC_最终模型与四期累计.csv')
assert len(summary)==6 and len(detail)==90 and len(fixed)==12 and len(final)==3
def fmt(x):return f'{float(x):,.2f}'
def model(spec):
    p=max([int(x) for x in re.findall(r'c(\d+)',spec)] or [0]);q=max([int(x) for x in re.findall(r'a(\d+)',spec)] or [0]);d=1 if '(1-B)' in spec else 0
    if '(1-B)2' in spec or '(1-B)^2' in spec:d=2
    return f'ARIMA({p},{d},{q})'+(' 带漂移' if 'Constant' in spec and d else ' 带常数' if 'Constant' in spec else ' 无漂移')
def metrics(rows):
    errors=[float(r['Forecast'])-float(r['Actual']) for r in rows]
    return mean(abs(x) for x in errors),math.sqrt(mean(x*x for x in errors))
targets=None
for who in 'ABC':
    ds=[r for r in detail if r['Person']==who];fs=[r for r in fixed if r['Person']==who]
    assert len(ds)==30 and len(fs)==4 and [int(r['TrainingN']) for r in ds]==list(range(78,108))
    current=[r['TargetDate'] for r in ds];assert targets is None or current==targets;targets=current
    m=next(r for r in summary if r['Person']==who and r['N']=='30');check=metrics(ds)
    assert abs(float(m['MAE'])-check[0])<1e-7 and abs(float(m['RMSE'])-check[1])<1e-7
    m=next(r for r in summary if r['Person']==who and r['N']=='4');check=metrics(fs)
    assert abs(float(m['MAE'])-check[0])<1e-7 and abs(float(m['RMSE'])-check[1])<1e-7
    assert [r['PeriodStart'] for r in fs]==['2026-09-28','2026-10-05','2026-10-12','2026-10-19']
modelstats=[]
for who in 'ABC':
    for spec,n in Counter(r['Model'] for r in detail if r['Person']==who).items():modelstats.append([who,model(spec),n,spec])
with (O/'ABC_滚动模型规格统计.csv').open('w',encoding='utf-8-sig',newline='') as f:
    wr=csv.writer(f);wr.writerow(['Person','ARIMA','Folds','ECOTOOLSpecification']);wr.writerows(modelstats)

# A standalone overview of the six native MATLAB figures.
canvas=Image.new('RGB',(2100,2380),'white');draw=ImageDraw.Draw(canvas);font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',38)
draw.text((65,25),'A B C 统一 AutoARIMA 预测结果',font=font,fill='black')
for i,who in enumerate('ABC'):
    for j,phase in enumerate(['rolling','fixed']):
        im=Image.open(O/f'{who}_{phase}.png').convert('RGB');im.thumbnail((1020,700),Image.Resampling.LANCZOS)
        canvas.paste(im,(30+j*1040,110+i*750))
canvas.save(O/'ABC_预测图汇总.png')

doc=Document();sec=doc.sections[0];sec.page_width=Inches(8.5);sec.page_height=Inches(11)
sec.top_margin=sec.bottom_margin=Inches(.6);sec.left_margin=sec.right_margin=Inches(.72)
for name,size in [('Normal',11),('Title',22),('Heading 1',16),('Heading 2',12),('Caption',9)]:
    s=doc.styles[name];s.font.name='Microsoft YaHei';s.font.size=Pt(size);s.font.color.rgb=RGBColor(0,0,0);s.element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'Microsoft YaHei');s.paragraph_format.space_after=Pt(6);s.paragraph_format.page_break_before=False
doc.styles['Normal'].paragraph_format.line_spacing=1.1
doc.styles['Heading 1'].paragraph_format.space_before=Pt(0)
doc.styles['Heading 2'].paragraph_format.space_before=Pt(7)
header=sec.header.paragraphs[0];header.text='A B C 统一 AutoARIMA 预测报告';header.style='Caption'
footer=sec.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.RIGHT;footer.add_run('2026年11月22日   |   ')
fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'PAGE');footer._p.append(fld)
for r in footer.runs:r.font.size=Pt(8)
pages=[]
def p(text,style=None):return doc.add_paragraph(text,style)
def page(title):
    if pages:doc.add_page_break()
    pages.append(title);doc.add_heading(title,1)
def table(headers,rows,widths=None,size=9.3):
    widths=widths or [7.06/len(headers)]*len(headers);t=doc.add_table(rows=1,cols=len(headers));t.autofit=False
    for col,w in zip(t.columns,widths):col.width=Inches(w)
    for c,x in zip(t.rows[0].cells,headers):c.text=str(x)
    repeat=OxmlElement('w:tblHeader');t.rows[0]._tr.get_or_add_trPr().append(repeat)
    for row in rows:
        for c,x in zip(t.add_row().cells,row):c.text=str(x)
    for i,row in enumerate(t.rows):
        row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        for j,c in enumerate(row.cells):
            c.width=Inches(widths[j]);c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            pr=c._tc.get_or_add_tcPr();shade=OxmlElement('w:shd');shade.set(qn('w:fill'),'E9EEF2' if i==0 else 'F5F7F8' if i%2==0 else 'FFFFFF');pr.append(shade)
            mar=OxmlElement('w:tcMar')
            for edge in ['top','bottom','left','right']:
                el=OxmlElement('w:'+edge);el.set(qn('w:w'),'65');el.set(qn('w:type'),'dxa');mar.append(el)
            pr.append(mar)
            for para in c.paragraphs:
                para.paragraph_format.space_after=Pt(2);para.paragraph_format.line_spacing=1.04
                if j>0:para.alignment=WD_ALIGN_PARAGRAPH.CENTER
                for r in para.runs:r.font.size=Pt(size);r.bold=i==0
    sp=p('');sp.paragraph_format.line_spacing=Pt(2);sp.paragraph_format.space_after=Pt(2)
    return t
figures=0
def fig(who,phase,caption):
    global figures
    figures+=1;q=p('');q.paragraph_format.space_after=Pt(1);q.add_run().add_picture(str(O/f'{who}_{phase}.png'),width=Inches(6.98));p(f'图{figures}  {caption}','Caption')
def metric_rows(rows):return [[r['Person'],r['N'],*[fmt(r[k]) for k in ['MAE','RMSE','sMAPE','MASE']]] for r in rows]

# Page 1: outcome and scope.
pages.append('总览');p('三份数据统一 AutoARIMA 预测报告','Title')
p('A.csv  B.xlsx  C.csv   自然周同方案实验')
p('本报告仅使用本轮指定的三个文件，分别运行同一种 AutoARIMA 自动选模方法。三份数据统一为周一至周日金额序列，采用相同日期、训练测试划分、滚动折数、估计设置和评价指标。每次拟合允许自动识别不同阶数，所有结果均来自本轮重新运行。')
table(['标记','正式来源','统一处理'],[['A','桌面 A.csv','保留112个自然周金额'],['B','桌面 B.xlsx','合并消费明细的净消费按日期汇总至周'],['C','桌面 C.csv','总支出日金额按日期汇总至周']],[.45,2.0,4.61])
doc.add_heading('30折一步滚动验证',2)
table(['数据','折数','MAE 元每周','RMSE 元每周','sMAPE %','MASE'],metric_rows([r for r in summary if r['N']=='30']),[.5,.5,1.6,1.6,1.4,1.46])
doc.add_heading('固定原点四期测试',2)
table(['数据','期数','MAE 元每周','RMSE 元每周','sMAPE %','MASE'],metric_rows([r for r in summary if r['N']=='4']),[.5,.5,1.6,1.6,1.4,1.46])
p('滚动验证每轮只预测下一周；固定原点测试用前108周一次预测后4周，期间不加入测试真实值。两类任务分别报告，不把它们混为同一项误差。MAE、RMSE、sMAPE、MASE 均越小越好。')
p(f'输入核验发现 A 与 B 的112期中有{cfg["A_B_equal_weeks"]}期金额完全一致，仅两期有差异。报告保留用户给定的文件身份，但不将高度相似的序列解释为三个独立样本的证据。')

# Page 2: one protocol for all.
page('三份数据共同采用的处理与模型设置')
table(['控制项','三份数据完全一致的设置'],[
 ['建模频率','自然周 周一至周日'],['共同观察范围','2024-09-02至2026-10-25 共112个完整周'],['训练集','前108周 截至2026-09-27'],['滚动窗口','扩展窗口 训练长度78至107 每折重新选模和估计'],['滚动目标','2026-03-02至09-21起始的30个周 每次预测下一周'],['测试集','后4周 2026-09-28至10-25'],['测试方式','固定原点 一次向前预测4期 不吸收测试实际值'],['自动选模','MATLAB ECOTOOL modelAUTO 同一程序逐人调用'],['模型控制','s=1 无季节项 diffs=1 允许自动识别差分'],['估计与变换','CML 条件平方和 boxcox=0 无 Box-Cox 或对数变换'],['异常与外生项','关闭自动异常类型调整 不删尖峰 不添加外生变量'],['评价','MAE RMSE sMAPE采用200倍口径 MASE按每折训练尺度计算']],[1.5,5.56],9.5)
doc.add_heading('相同方法允许不同阶数',2)
p('AutoARIMA 是同一种自动识别方法。ARIMA 的 p 表示过去序列的影响阶数，d 表示差分次数，q 表示过去预测冲击的影响阶数。漂移项允许差分序列存在非零平均变化。由于每人的历史金额不同，相同程序选出不同阶数属于预期结果；本实验不把三人的 p、d、q 强行固定成一样。')
p('MAE 表示平均绝对误差；RMSE 更重视大额错误。sMAPE 对每期绝对误差按预测值与实际值的绝对值之和缩放，再乘200；两者均为零时该期记零。MASE 用每折训练序列相邻金额绝对变化的均值缩放，再平均；四期测试统一使用108周训练尺度。')
p('A 没有日数据，因此统一比较采用自然周。本轮统一的是给定金额序列的聚合和预测流程：B 使用工作簿现有净消费，A、C 使用文件现有金额。A、C 无逐笔资料，不能进一步核验三份源数据上游退款和转账分类是否相同。')

# Pages 3--5: identical layout and tests for each input.
for who in 'ABC':
    page(who+' 数据预测结果')
    fin=next(r for r in final if r['Person']==who);rs=[r for r in summary if r['Person']==who]
    p(f'{who} 使用与另外两份数据相同的108周训练、30折滚动验证和后4周测试。全训练期最终识别为 {model(fin["Model"])}。本页两图横轴均为目标周起始日，纵轴为每周金额。')
    fig(who,'rolling',who+' 每折重新选模的下一周预测 共30折')
    fig(who,'fixed',who+' 在同一训练截止日一次预测后4周')
    table(['任务','N','MAE 元','RMSE 元','sMAPE %','MASE'],[[('一步滚动验证' if r['N']=='30' else '固定原点测试'),r['N'],*[fmt(r[k]) for k in ['MAE','RMSE','sMAPE','MASE']]] for r in rs],[1.55,.4,1.3,1.3,1.2,1.31],9.2)
    p(f'4周预测合计 {fmt(fin["FourWeekForecast"])}元，实际 {fmt(fin["FourWeekActual"])}元，预测减实际为 {fmt(fin["Error"])}元，相对偏差为 {fmt(fin["RelativeErrorPct"])}%。该区间含九月底日期，不等于完整十月。')

# Page 6: final models, test detail, interpretation.
page('最终模型与四期预测金额')
table(['数据','全训练期自动识别模型','4周预测','4周实际','相对偏差'],[[r['Person'],model(r['Model']),fmt(r['FourWeekForecast']),fmt(r['FourWeekActual']),fmt(r['RelativeErrorPct'])+'%'] for r in final],[.45,2.8,1.25,1.25,1.31])
for who in 'ABC':
    doc.add_heading(who+' 四期测试明细',2)
    table(['周起始日','预测 元','实际 元','预测减实际 元'],[[r['PeriodStart'],fmt(r['Forecast']),fmt(r['Actual']),fmt(r['Error'])] for r in fixed if r['Person']==who],[1.72,1.78,1.78,1.78],9)
p('三份数据的测试日期完全相同。这里的高估或低估反映各自给定金额序列的预测效果；不能仅按绝对误差认定某个人更可预测，因为支出规模与波动程度不同。相对指标也应结合仅4期测试的样本量解释。')

# Page 7: transparent model count and source provenance.
page('自动识别记录与数据核验')
table(['数据','滚动阶段识别模型','出现折数'],[[p,m,n] for p,m,n,s in modelstats],[.5,5.66,.9],9)
p('表内每人的折数合计均为30。滚动阶段每折使用当时训练窗口重新选择模型；最终四期预测模型则在完整108周上另外识别。因此最终阶数与滚动中最常出现的阶数可以不同。')
doc.add_heading('A 与 B 的相同金额检查',2)
table(['周起始日','A 金额','B 金额','A减B'],[[r['start'],fmt(r['A']),fmt(r['B']),fmt(r['A']-r['B'])] for r in cfg['A_B_difference_weeks']],[1.72,1.78,1.78,1.78])
p('除上表两周外，其余110周金额完全一致。该发现不改变本轮文件归属或模型设置；它解释了 A、B 的预测为什么接近，也限制将结果解读为独立个人间差异。')
doc.add_heading('本轮来源与输出',2)
p('A 直接读取桌面 A.csv 的个人总支付_元；B 读取桌面 B.xlsx 中合并消费明细的净消费（元）列，按交易日期重新计算自然周；C 读取桌面 C.csv 的总支出_元。CSV 按源编码正确解码，未修改源文件。共同范围以外数据不参与拟合。')
p('配套结果包含三份统一自然周输入、90条滚动预测、12条固定原点预测、六行评价指标、最终模型、输入文件哈希与完整设置，以及6张独立预测图。报告不使用此前归属有争议的结果表。')

# Page 8: all common validation targets side by side.
page('30折共同目标周逐折结果')
p('金额单位为元；同一行是完全相同的预测目标周。每份数据均只使用该周之前的历史预测。')
by={who:[r for r in detail if r['Person']==who] for who in 'ABC'}
table(['目标周起始日','A 实际','A 预测','B 实际','B 预测','C 实际','C 预测'],[[targets[i],*[fmt(by[p][i][k]) for p in 'ABC' for k in ['Actual','Forecast']]] for i in range(30)],[1.3,.96,.96,.96,.96,.96,.96],8.6)

for part in [doc.styles.element,doc.element]:
    for border in list(part.iter(qn('w:pBdr'))):border.getparent().remove(border)
path=O/'ABC_统一AutoARIMA预测报告.docx';doc.save(path)
shutil.copy2(R/'work'/'run_uniform_arima.m',O/'run_uniform_arima.m')
audit={'planned_pages':len(pages),'sections':pages,'figures':figures,'validation_rows':90,'test_rows':12,'source_files':cfg['authoritative_sources'],'final_models':{r['Person']:model(r['Model']) for r in final}}
(W/'report_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
bundle=R/'outputs'/'ABC_统一AutoARIMA_预测图与结果包.zip'
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED) as z:
    for file in sorted(O.iterdir()):
        if file.is_file():z.write(file,arcname=file.name)
print(path);print(bundle);print(json.dumps(audit,ensure_ascii=False))
