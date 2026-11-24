import csv,json,re,math,shutil,zipfile
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
R=Path(__file__).resolve().parents[1];O=R/'outputs'/'ABC周消费_ARIMA_修正版_20261122';W=R/'work'/'abc_corrected_20261122'
def read(name):
    with (O/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
cfg=json.loads((O/'实验设置与来源核验.json').read_text(encoding='utf-8'))
summary=read('ABC_ARIMA与基准_性能比较表.csv');roll=read('ABC_滚动预测明细_含基准.csv');fixed=read('ABC_固定原点预测明细_含基准.csv');final=read('ABC_最终模型与四周累计.csv');diag=read('ABC_ARIMA残差检验.csv')
assert len(summary)==18 and len(roll)==270 and len(fixed)==36 and len(final)==9 and len(diag)==3
methods=['AutoARIMA','Naive','HistoricalMean'];name={'AutoARIMA':'AutoARIMA','Naive':'Naive','HistoricalMean':'历史均值'};phases=['30折一步滚动验证','固定原点四期测试']
def f(x):return float(x)
def fmt(x):return f'{float(x):,.2f}' if math.isfinite(float(x)) else '不可计算'
def pv(x):return '不可计算' if not math.isfinite(f(x)) else '<0.0001' if f(x)<.0001 else f'{f(x):.4f}'
def get(member,phase,method):return next(r for r in summary if r['Member']==member and r['Phase']==phase and r['Method']==method)
def model(member):
    r=next(r for r in diag if r['Member']==member);spec=r['Specification'];p,d,q=[int(f(r[k])) for k in ['AROrder','DiffOrder','MAOrder']]
    return f'ARIMA({p},{d},{q})'+(' 带漂移' if 'Constant' in spec and d else ' 带常数' if 'Constant' in spec else ' 无漂移')
for member in 'ABC':
    for method in methods:
        for phase,data in zip(phases,[roll,fixed]):
            rows=[r for r in data if r['Member']==member and r['Method']==method];n=30 if phase==phases[0] else 4
            assert len(rows)==n
            errors=[f(r['Forecast'])-f(r['Actual']) for r in rows];r=get(member,phase,method)
            recomputed=[mean(abs(e) for e in errors),math.sqrt(mean(e*e for e in errors)),mean(200*abs(f(r['Error']))/(abs(f(r['Actual']))+abs(f(r['Forecast']))) if abs(f(r['Actual']))+abs(f(r['Forecast'])) else 0 for r in rows),mean(abs(f(r['Error']))/f(r['MASEScale']) for r in rows)]
            assert all(abs(f(r[k])-v)<1e-7 for k,v in zip(['MAE','RMSE','sMAPE','MASE'],recomputed))
    baseline=[r for r in roll if r['Member']==member and r['Method']=='Naive'];a=[r for r in roll if r['Member']==member and r['Method']=='AutoARIMA'];assert [r['TargetDate'] for r in baseline]==[r['TargetDate'] for r in a]

# Independent input checks repeated from the normalized model matrices.
for source in cfg['sources']:
    rows=read(source['Member']+'_112周建模输入.csv');assert len(rows)==112
    assert abs(sum(f(r['Amount']) for r in rows)-f(source['Total']))<1e-7

doc=Document();sec=doc.sections[0];sec.page_width=Inches(8.5);sec.page_height=Inches(11);sec.top_margin=sec.bottom_margin=Inches(.6);sec.left_margin=sec.right_margin=Inches(.72)
for style,size in [('Normal',10.5),('Title',22),('Heading 1',16),('Heading 2',12),('Caption',9)]:
    st=doc.styles[style];st.font.name='Microsoft YaHei';st.font.size=Pt(size);st.font.color.rgb=RGBColor(0,0,0);st.element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'Microsoft YaHei');st.paragraph_format.space_after=Pt(6);st.paragraph_format.page_break_before=False
doc.styles['Normal'].paragraph_format.line_spacing=1.1;doc.styles['Heading 1'].paragraph_format.space_before=Pt(0);doc.styles['Heading 2'].paragraph_format.space_before=Pt(6)
header=sec.header.paragraphs[0];header.text='三位成员周消费 ARIMA 与基准预测';header.style='Caption'
footer=sec.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.RIGHT;footer.add_run('2026年11月22日   |   ');field=OxmlElement('w:fldSimple');field.set(qn('w:instr'),'PAGE');footer._p.append(field)
for r in footer.runs:r.font.size=Pt(8)
pages=[]
def p(text,style=None):return doc.add_paragraph(text,style)
def page(title):
    newpage=bool(pages);pages.append(title);heading=doc.add_heading(title,1)
    heading.paragraph_format.page_break_before=newpage
def table(headers,rows,widths=None,size=9.2):
    widths=widths or [7.06/len(headers)]*len(headers);t=doc.add_table(rows=1,cols=len(headers));t.autofit=False
    for col,w in zip(t.columns,widths):col.width=Inches(w)
    for c,v in zip(t.rows[0].cells,headers):c.text=str(v)
    repeat=OxmlElement('w:tblHeader');t.rows[0]._tr.get_or_add_trPr().append(repeat)
    for row in rows:
        for c,v in zip(t.add_row().cells,row):c.text=str(v)
    for i,row in enumerate(t.rows):
        row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        for j,c in enumerate(row.cells):
            c.width=Inches(widths[j]);c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER;pr=c._tc.get_or_add_tcPr();shade=OxmlElement('w:shd');shade.set(qn('w:fill'),'E9EEF2' if i==0 else 'F5F7F8' if i%2==0 else 'FFFFFF');pr.append(shade)
            mar=OxmlElement('w:tcMar')
            for edge in ['top','bottom','left','right']:
                n=OxmlElement('w:'+edge);n.set(qn('w:w'),'60');n.set(qn('w:type'),'dxa');mar.append(n)
            pr.append(mar)
            for para in c.paragraphs:
                para.paragraph_format.space_after=Pt(2);para.paragraph_format.line_spacing=1.02
                if j>0:para.alignment=WD_ALIGN_PARAGRAPH.CENTER
                for r in para.runs:r.font.size=Pt(size);r.bold=i==0
    spacer=p('');spacer.paragraph_format.line_spacing=Pt(2);spacer.paragraph_format.space_after=Pt(2)
figures=0
def picture(file,caption,width=6.98):
    global figures
    figures+=1;par=p('');par.paragraph_format.space_after=Pt(1);par.add_run().add_picture(str(O/file),width=Inches(width));p(f'图{figures}  {caption}','Caption')
def rowmetrics(r):return [fmt(r[k]) for k in ['MAE','RMSE','sMAPE','MASE']]
def improvement(member,phase,baseline):
    return 100*(f(get(member,phase,baseline)['MAE'])-f(get(member,phase,'AutoARIMA')['MAE']))/f(get(member,phase,baseline)['MAE'])
def pct(value):return (f'{value:.2f}%').replace('-','−')

pages.append('数据核验与主要结果');p('三位成员周消费 ARIMA 预测报告','Title');p('修正版数据核验  AutoARIMA  Naive  历史均值')
p('本实验重新读取三位成员的输入，分别建立独立周序列。三组主模型均使用同一种 AutoARIMA 自动选模方法，并使用相同训练测试日期、滚动方案及误差指标；阶数允许由各自训练数据自动识别。每组另外运行 Naive 和历史均值基准。')
table(['成员','实际使用来源及字段','周数','实读金额合计 元'],[['A','成员A_周.csv 的个人总支付_元',112,'64,470.55'],['B','经确认留存B.xlsx 合并消费明细的净消费（元）',112,'114,959.44'],['C','C.xlsx 03_周期统计的个人总支付_元',112,'88,773.97']],[.45,4.1,.45,2.06])
p('三份输入均通过日期检查：首周2024-09-02至09-08，末周2026-10-19至10-25，共112个完整自然周；日期无重复、无缺失，金额均有限且非负。合计由实际读取求和得到，再与要求数字比对。')
p('附件 B.csv 为退款前周金额，合计115,040.44元，未作为净消费输入。经用户明确确认，B改用此前逐行核验的留存B.xlsx，排除共同范围外22条明细后汇总。C的常规支付合计69,730.96元，未用于总消费模型。')
doc.add_heading('AutoARIMA 主模型误差',2)
table(['成员','任务','N','MAE 元','RMSE 元','sMAPE %','MASE'],[[member,('一步滚动' if phase==phases[0] else '四期测试'),get(member,phase,'AutoARIMA')['N'],*rowmetrics(get(member,phase,'AutoARIMA'))] for member in 'ABC' for phase in phases],[.4,1.05,.4,1.25,1.25,1.25,1.46],9)
p('滚动验证评价下一周预测；四期测试评价同一训练截止日一次向前预测4周。预测测试区间为2026-09-28至10-25，包含九月底日期，不代表完整十月。')

page('统一建模流程与评价方法')
table(['项目','三位成员统一设置'],[['建模范围','2024-09-02至2026-10-25 112个完整自然周'],['训练与测试','前108周训练至2026-09-27 后4周保留测试'],['滚动验证','扩展窗口 训练长度78至107 共30折 每折预测下一周'],['滚动目标日期','2026-03-02至09-21起始的30个周'],['固定原点测试','用108周训练数据重新选模 一次预测后4周 不吸收测试值'],['自动ARIMA','MATLAB ECOTOOL modelAUTO 每折同一设置重选阶数'],['模型控制','s=1 无季节项 diffs=1 允许自动差分识别 CML估计'],['变换与异常','不做Box-Cox或对数 不删峰值 不开启自动异常调整 无外生变量'],['Naive','滚动取该折最后一期金额 固定原点4步均取第108周金额'],['历史均值','滚动取该折全部训练金额均值 固定原点4步均取108周训练均值'],['指标','MAE RMSE sMAPE采用200倍口径 MASE按训练尺度缩放']],[1.55,5.51],9.4)
p('ARIMA的p是历史序列影响阶数，d是差分次数，q是历史预测冲击影响阶数；漂移项允许差分序列具有非零平均变化。同一种自动选模程序不要求三人最终p、d、q相同。本轮不根据测试误差回头修改模型设置。')
p('MAE为绝对误差均值；RMSE为误差平方均值的平方根。sMAPE逐期用200倍绝对误差除以真实值与预测值的绝对值之和，两者均零记零。MASE逐折用该折训练期相邻观测绝对变化均值缩放后平均；固定四期使用108周共同训练尺度。三种方法在每个人的同一目标日期评价。')
p('残差诊断使用最终108周训练拟合的一步创新，不使用保留测试值。仅删除非有限初始化输出；图的横轴为有效创新序号，不强行将其对应到未知初始化日期。Ljung–Box在6和12阶检验残差自相关，近似自由度取滞后阶数减AR和MA阶数；Jarque–Bera用于检查正态偏离。')

for member in 'ABC':
    page('成员'+member+' 预测曲线与误差结果')
    p(f'成员{member}最终全训练期识别为{model(member)}。本页实际金额、AutoARIMA、Naive和历史均值对应相同目标周，三种预测在每个阶段使用完全相同的可用历史。')
    picture(member+'_滚动预测.png','成员'+member+' 三种方法30折扩展窗口一步预测')
    picture(member+'_固定原点预测.png','成员'+member+' 三种方法固定原点四期预测')
    table(['阶段','方法','MAE 元','RMSE 元','sMAPE %','MASE'],[[('滚动30折' if phase==phases[0] else '测试4期'),name[method],*rowmetrics(get(member,phase,method))] for phase in phases for method in methods],[1.05,1.1,1.2,1.2,1.2,1.31],8.9)
    p(f'AutoARIMA 相对 Naive 的MAE改善：滚动{pct(improvement(member,phases[0],"Naive"))}，测试{pct(improvement(member,phases[1],"Naive"))}；相对历史均值：滚动{pct(improvement(member,phases[0],"HistoricalMean"))}，测试{pct(improvement(member,phases[1],"HistoricalMean"))}。正值表示ARIMA误差更低，负值表示基准更低。')
    page('成员'+member+' ARIMA 残差诊断')
    dr=next(r for r in diag if r['Member']==member)
    p(f'诊断对象为{model(member)}在108周训练数据上的一步创新，有效创新数{dr["EffectiveN"]}。标准化采用残差自身的均值与样本标准差，不是以模型预测方差标准化。')
    picture(member+'_ARIMA残差诊断.png','成员'+member+' 训练创新时序 ACF 经验分布及正态Q Q图')
    table(['诊断项目','统计量','自由度','p值'],[['Ljung–Box 6阶',fmt(dr['LB6_Q']),dr['LB6_df'],pv(dr['LB6_p'])],['Ljung–Box 12阶',fmt(dr['LB12_Q']),dr['LB12_df'],pv(dr['LB12_p'])],['Jarque–Bera',fmt(dr['JB']),2,pv(dr['JB_p'])]],[2.7,1.5,1.0,1.86])
    table(['有效创新数','残差均值 元','残差标准差 元','偏度','峰度'],[[dr['EffectiveN'],fmt(dr['ResidualMean']),fmt(dr['ResidualSD']),fmt(dr['Skewness']),fmt(dr['Kurtosis'])]],[1.1,1.6,1.7,1.3,1.36])
    decisions=[]
    for h in ['6','12']:
        value=f(dr['LB'+h+'_p']);decisions.append(h+'阶'+('不可计算' if not math.isfinite(value) else '检出自相关' if value<.05 else '未检出显著自相关'))
    normal='存在显著正态偏离' if f(dr['JB_p'])<.05 else '未检出显著正态偏离'
    p('按0.05阈值，'+ '，'.join(decisions)+'；Jarque–Bera结果为'+normal+'。未拒绝零假设不能证明残差独立、白噪声或正态；残差图与检验也不能替代样本外误差评价。')

page('三位成员 ARIMA 与基准性能比较')
for phase in phases:
    doc.add_heading(phase,2)
    table(['成员','方法','N','MAE 元','RMSE 元','sMAPE %','MASE'],[[member,name[method],get(member,phase,method)['N'],*rowmetrics(get(member,phase,method))] for member in 'ABC' for method in methods],[.4,1.1,.35,1.25,1.25,1.25,1.46],8.9)
p('同一成员、同一阶段的三种方法可直接比较；不同成员的绝对误差同时受到支出规模与波动影响，不能单凭MAE或RMSE排名个人可预测性。四期测试仅含4个周，结论应与30折滚动结果合看。MASE小于1表示低于训练期朴素变化尺度，不等于必然超过本次测试Naive。')

page('三位成员预测性能比较图')
p('上排展示30折一步滚动验证，下排展示固定原点四期测试；每个阶段分别比较MAE和sMAPE。每一组中的三根柱对应同一成员、同一目标期，均越低越好。不同面板纵轴尺度不同。')
picture('ABC_预测性能比较图.png','三位成员三种方法在两类任务中的误差比较')
table(['成员','滚动MAE最低方法','四期测试MAE最低方法','ARIMA残差12阶p值'],[[member,name[min(methods,key=lambda method:f(get(member,phases[0],method)['MAE']))],name[min(methods,key=lambda method:f(get(member,phases[1],method)['MAE']))],pv(next(r for r in diag if r['Member']==member)['LB12_p'])] for member in 'ABC'],[.5,2.1,2.4,2.06])
p('本次三个成员的滚动MAE及四期测试MAE均以历史均值更低；AutoARIMA没有稳定超过这一简单基准。成员C滚动RMSE为637.77元，低于Naive及历史均值，说明不同指标对大额错误的权重不同。')
p('成员A的12阶Ljung–Box检出残差相关，B、C在本次两阶检验中未检出显著相关；三组残差均明显偏离正态。主要预测图显示突发大额周难以提前识别，而大额周之后的ARIMA或Naive预测又可能偏高。')

page('四期累计预测与来源追溯')
table(['成员','方法','4周预测 元','4周实际 元','预测减实际 元','相对偏差'],[[r['Member'],name[r['Method']],fmt(r['ForecastSum']),fmt(r['ActualSum']),fmt(r['Error']),fmt(r['RelativeErrorPct'])+'%'] for r in final],[.4,1.1,1.4,1.4,1.45,1.31],8.8)
doc.add_heading('最终ARIMA模型与数据身份',2)
table(['成员','最终模型','金额来源'],[[member,model(member),next(x for x in cfg['sources'] if x['Member']==member)['AmountField']] for member in 'ABC'],[.45,3.3,3.31])
p('本轮成员A来自新提供的成员A_周.csv，其金额合计64,470.55元；不是旧A.csv的115,040.44元。同理，本轮C从C.xlsx的03_周期统计取总支付，不能替换为常规支付。三份归一化周序列两两相同金额的周数均为0，本轮不再沿用此前旧A与B同源的判断。')
p('B实际使用的留存B.xlsx已经与最初清洗合并总表逐行逐列核对；本轮又按周起始日重新汇总净消费，所得112周114,959.44元。提示中B(2).xlsx未作为附件出现，B来源替代已经用户明确确认。C实际附件名为C.xlsx，所需工作表与字段均已实读核验。')
p('配套文件包含：3份112周建模输入、输入字段和日期核验表、270条滚动预测、36条固定原点预测、18行性能结果、最终模型和累计金额、训练创新残差及ACF、检验表、源文件SHA256和同一MATLAB复现程序。模型在各自给定金额上估计，未额外删除大额周或按测试表现改设置。')

for part in [doc.styles.element,doc.element]:
    for border in list(part.iter(qn('w:pBdr'))):border.getparent().remove(border)
target=O/'三位成员周消费_ARIMA与基准预测报告.docx';doc.save(target)
shutil.copy2(R/'work'/'run_corrected_abc.m',O/'run_corrected_abc.m')
audit={'planned_pages':len(pages),'sections':pages,'figures':figures,'summary_rows':18,'rolling_rows':270,'fixed_rows':36,'diagnostic_members':3,'input_sums':{x['Member']:x['Total'] for x in cfg['sources']},'models':{member:model(member) for member in 'ABC'}}
(W/'report_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
bundle=R/'outputs'/'三位成员周消费_ARIMA图像与完整结果_修正版.zip'
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED) as z:
    for file in sorted(O.iterdir()):
        if file.is_file():z.write(file,arcname=file.name)
print(target);print(bundle);print(json.dumps(audit,ensure_ascii=False))
