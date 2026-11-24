import csv,json,re,math
from pathlib import Path
from collections import Counter
from statistics import mean
from datetime import date,timedelta
from docx import Document
from docx.shared import Inches,Pt,RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT

ROOT=Path(__file__).resolve().parents[1];W=ROOT/'work';O=ROOT/'outputs';CH=W/'three_arima_charts'
def read(p):
    with Path(p).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def num(x):return float(x)
def fmt(x):return f'{float(x):,.2f}' if x is not None and math.isfinite(float(x)) else '—'
def metric(a,p,s=None):
    e=[x-y for x,y in zip(p,a)]
    return [mean(abs(x) for x in e),math.sqrt(mean(x*x for x in e)),mean(200*abs(x-y)/(abs(x)+abs(y)) if abs(x)+abs(y) else 0 for x,y in zip(p,a)),mean(abs(x)/z for x,z in zip(e,s)) if s else None]
def label(spec):
    p=max([int(x) for x in re.findall(r'c(\d+)',spec)] or [0]);q=max([int(x) for x in re.findall(r'a(\d+)',spec)] or [0])
    return f'ARIMA({p},1,{q})'+(' 带漂移' if 'Constant' in spec else ' 无漂移')

A=O/'A_自然周_ARIMA';C=O/'ARIMA_UC同口径'
ar=read(A/'A_ARIMA逐折预测.csv');af=read(A/'A_ARIMA固定原点预测.csv');am=read(A/'A_ARIMA及基准评价.csv')
bd=read(W/'originalbill_rolling_output.csv');cd=read(W/'newbill_rolling_output.csv')
ba=read(W/'holdout_daily_actual.csv');bf=read(W/'holdout_daily_forecast.csv');cf=read(W/'newbill_model_output.csv');ca=read(W/'newbill_test.csv')
bw=read(O/'ECOTOOL_ARIMA_49轮周频回测.csv');bh=read(O/'ARIMA固定训练集_9至10月实际预测对照.csv');bwtest=[r for r in bh if r['频率']=='完整周']
cr=read(C/'ARIMA逐折模型与预测.csv');cm=read(C/'同口径滚动验证比较.csv');ct=read(C/'ARIMA固定原点多步预测.csv');co=read(C/'ARIMA完整十月预测.csv')
assert len(ar)==30 and len(bd)==len(cd)==61 and len(bw)==49 and len(bwtest)==7 and len(cr)==70
bs=json.loads((W/'bill_version_comparison.json').read_text(encoding='utf-8'))['最初合并账单'];cs=json.loads((W/'newbill_rolling_summary.json').read_text(encoding='utf-8'))
old=json.loads((W/'rolling-results.json').read_text(encoding='utf-8'))

doc=Document();sec=doc.sections[0];sec.page_width=Inches(8.5);sec.page_height=Inches(11)
sec.top_margin=sec.bottom_margin=Inches(.6);sec.left_margin=sec.right_margin=Inches(.72)
for name,size in [('Normal',10.5),('Title',23),('Heading 1',16),('Heading 2',12),('Caption',9)]:
    st=doc.styles[name];st.font.name='Microsoft YaHei';st.font.size=Pt(size);st.font.color.rgb=RGBColor(0,0,0);st.element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'Microsoft YaHei')
    st.paragraph_format.space_after=Pt(6);st.paragraph_format.page_break_before=False
doc.styles['Normal'].paragraph_format.line_spacing=1.12
doc.styles['Heading 1'].paragraph_format.space_before=Pt(0)
doc.styles['Heading 2'].paragraph_format.space_before=Pt(7)
header=sec.header.paragraphs[0];header.text='A B C 个人支付 ARIMA 实验汇总';header.style='Caption'
footer=sec.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.RIGHT
footer.add_run('整理日期 2026年11月21日   |   ')
field=OxmlElement('w:fldSimple');field.set(qn('w:instr'),'PAGE');footer._p.append(field)
for r in footer.runs:r.font.size=Pt(8)
pages=[]
def p(t,style=None):return doc.add_paragraph(t,style)
def page(title):
    if pages:doc.add_page_break()
    pages.append(title);doc.add_heading(title,1)
def table(headers,rows,widths=None,size=9.3):
    t=doc.add_table(rows=1,cols=len(headers));t.autofit=False
    widths=widths or [7.06/len(headers)]*len(headers)
    for c,w in zip(t.columns,widths):c.width=Inches(w)
    for c,x in zip(t.rows[0].cells,headers):c.text=str(x)
    repeat=OxmlElement('w:tblHeader');t.rows[0]._tr.get_or_add_trPr().append(repeat)
    for row in rows:
        for c,x in zip(t.add_row().cells,row):c.text=str(x)
    for i,row in enumerate(t.rows):
        row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        for j,c in enumerate(row.cells):
            c.width=Inches(widths[j]);c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            props=c._tc.get_or_add_tcPr();shade=OxmlElement('w:shd');shade.set(qn('w:fill'),'E9EEF2' if i==0 else ('F5F7F8' if i%2==0 else 'FFFFFF'));props.append(shade)
            margin=OxmlElement('w:tcMar')
            for edge in ['top','bottom','left','right']:
                n=OxmlElement('w:'+edge);n.set(qn('w:w'),'65');n.set(qn('w:type'),'dxa');margin.append(n)
            props.append(margin)
            for par in c.paragraphs:
                par.paragraph_format.space_after=Pt(2);par.paragraph_format.line_spacing=1.04
                if j>0:par.alignment=WD_ALIGN_PARAGRAPH.CENTER
                for r in par.runs:r.font.size=Pt(size);r.bold=i==0
    spacer=p('');spacer.paragraph_format.space_after=Pt(2);spacer.paragraph_format.line_spacing=Pt(2)
    return t
fig_no=0
def fig(name,caption):
    global fig_no
    fig_no+=1
    par=p('');par.paragraph_format.space_after=Pt(1);par.add_run().add_picture(str(CH/(name+'.png')),width=Inches(6.98))
    cap=p(f'图{fig_no}  {caption}','Caption');cap.paragraph_format.space_after=Pt(5)
def metric_table(rows):table(['实验','N','MAE 元','RMSE 元','sMAPE %','MASE'],[[n,k,*map(fmt,v)] for n,k,v in rows],[1.62,.40,1.2,1.2,1.12,1.52],9)
def daily_scale(rows,trainfile):
    h=[num(r['Spending']) for r in read(W/trainfile)];total=sum(abs(x-y) for x,y in zip(h[1:],h[:-1]));result=[]
    for r in rows:
        result.append(total/(len(h)-1));v=num(r['Actual']);total+=abs(v-h[-1]);h.append(v)
    return result
def daily_metrics(rows,trainfile):return metric([num(r['Actual']) for r in rows],[num(r['Forecast']) for r in rows],daily_scale(rows,trainfile))
def dailymonth(rows,forecastkey='Forecast'):
    return [[m,sum(num(r['Actual']) for r in rows if r['Date'].startswith(m)),sum(num(r[forecastkey]) for r in rows if r['Date'].startswith(m))] for m in ['2026-09','2026-10']]
def cmrow(freq):return next(r for r in cm if r['Frequency']==freq and r['Model']=='AutoARIMA')
def metric_fields(r):return [num(r[k]) for k in ['MAE','RMSE','sMAPE','MASE']]
def ctest(freq):
    r=[r for r in ct if r['Frequency']==freq and r['PeriodActual']!='NaN'];hist=[r for r in cr if r['Frequency']==freq];n=int(hist[-1]['TrainingN']);scale=(num(hist[-1]['MASEScale'])*(n-1)+abs(num(hist[-1]['Actual'])-num(hist[-2]['Actual'])))/n
    return r,metric([num(x['PeriodActual']) for x in r],[num(x['Forecast']) for x in r],[scale]*len(r))

# 1 Overview
pages.append('总览');p('三位个人支付数据 ARIMA 预测汇总','Title');p('日度与周度预测图  模型说明  滚动验证与固定原点测试')
p('本报告按最新人员命名整合已经完成的实验：A 为最新提供的自然周数据，B 为本人原始合并账单，C 为此前提供的日账单及 UC 聚合数据。报告以结果文件重新制图并核算指标，保留各实验的训练边界、预测步长和金额口径。')
p('主要结果是：A 的 ARIMA 在30折周度验证中优于两个基准，但最后4期测试不及朴素预测；B、C 的日度滚动预测都未在 MAE 上超过历史均值；C 的同口径周度实验中，ARIMA 也未在全部指标上优于 UC。')
table(['人员','数据身份','本报告覆盖'],[
 ['A','本次附件 文件名虽以 C 开头仍按 A','自然周 30折验证及4期测试'],
 ['B','本人最初支付宝与微信合并账单','日度与自然周 固定原点及滚动实验'],
 ['C','后来提供的另一位数据','日度及 UC 聚合版本的自然周 连续七天 月度']],[.45,3.1,3.51])
doc.add_heading('主要滚动结果',2)
table(['人员与实验','评价对象','N','MAE 元','RMSE 元'],[
 ['A 自然周','下一周',30,'976.82','1,881.62'],['B 日度','下一天',61,fmt(bs['MAE']),fmt(bs['RMSE'])],
 ['B 自然周旧实验','未来四周合计',49,'2,240.38','2,780.63'],['C 日度','下一天',61,'317.12','947.90'],
 ['C 自然周聚合版','下一周',30,'509.51','637.77'],['C 连续七天聚合版','下一期七天',30,'479.76','626.49'],
 ['C 月度聚合版','下一月',10,'2,401.19','3,051.53']],[1.55,1.55,.4,1.78,1.78])
p('阅读规则：每行只对应自己的评价单位。不同个人、不同频率或不同预测步长的 MAE 与 RMSE 不作直接排名。A 尚无日度数据；C 的日账单与 UC 聚合版十月实际分别为4,319.87元和3,702.17元，作为两个口径版本分别展示。')

# 2 Methods
page('模型含义与实验方法')
p('主模型为 ECOTOOL 的 modelAUTO 自动 ARIMA。每次拟合使用当时训练窗口，自动识别阶数并估计参数。ARIMA 的 p 表示过去序列的影响阶数，d 表示差分次数，q 表示过去预测冲击的影响阶数；带漂移意味着差分后的序列允许存在非零平均变化。')
table(['组成','作用','消费数据中的解释'],[['AR','利用历史相关性','近期支出或支出变化是否延续'],['I','差分处理','一阶差分观察本期相对上期的增减'],['MA','利用历史预测冲击','根据过去未预料到的波动修正预测']],[.5,2.1,4.46])
p('ARIMA 中的 MA 与三期移动平均基准含义不同。基准直接取最近三期金额的算术平均；ARIMA 的 MA 项使用过去的误差或冲击。漂移项也不代表已知某项固定账单。')
table(['设置','采用的方法'],[['估计','CML 条件平方和准则 主结果均为 MATLAB ECOTOOL'],['季节与变换','s=1 无季节项 boxcox=0 不做 Box-Cox'],['外生变量','未加入收入 节假日或已知大额支付计划等变量'],['A 和 C 周度验证','训练长度78至107 每折预测下一期 共30折'],['C 月度验证','训练长度15至24 每折预测下一月 共10折'],['B 和 C 日度验证','初始730天 每天吸收前日实际值 重选模型 共61折'],['固定原点预测','训练结束一次预测后续各期 不吸收测试实际'],['基准','A 和 C 聚合版用朴素及三期均值 日度用历史均值']],[1.7,5.36])
p('MAE 表示平均绝对误差；RMSE 对大额错误更敏感；sMAPE 是以真实值与预测值绝对值之和缩放的百分比误差，采用200倍口径；MASE 使用每折训练期相邻观测绝对变化的平均值缩放误差。MASE 小于1是相对于训练期朴素变化尺度较小，不自动等于击败测试集朴素预测。表中横线表示未核算该项指标或没有实际值。')
p('周预测汇总到自然月时，按预测周在当月覆盖天数除以7加权。例如九月底起点覆盖十月的五个自然周权重为4/7、1、1、1、6/7。此规则假设预测金额在周内均匀分布。')

# 3 A
page('A 自然周预测结果')
p('输入为112个周一至周日的完整自然周。前108期覆盖2024-09-02至2026-09-27；后4期覆盖2026-09-28至10-25。最终固定原点模型为 ARIMA(0,1,1) 带漂移。')
fig('A_rolling','A 的30折下一周预测 实际尖峰与平滑预测的差距构成主要误差')
fig('A_fixed','A 的固定原点预测 第5期仅有预测 没有实际值')
table(['模型','滚动 MAE','滚动 RMSE','4期测试 MAE','4期测试 RMSE'],[[m,fmt(next(r for r in am if r['Model']==m and r['N']=='30')['MAE']),fmt(next(r for r in am if r['Model']==m and r['N']=='30')['RMSE']),fmt(next(r for r in am if r['Model']==m and r['N']=='4')['MAE']),fmt(next(r for r in am if r['Model']==m and r['N']=='4')['RMSE'])] for m in ['AutoARIMA','朴素','三期移动平均']],[1.4,1.415,1.415,1.415,1.415],9)
p('ARIMA 的4期预测合计6,032.95元，实际4,325.00元，高估39.49%。完整十月日分摊预测为6,664.51元；尚无完整十月实际值，因此不计算完整十月累计误差。')

# 4 B daily
page('B 本人日度预测结果')
p('采用最初合并账单的净消费口径。日度训练为2024-09-01至2026-08-31，共730天；检验为2026-09-01至10-31，共61天。固定原点模型为 ARIMA(0,1,1) 无漂移，预测保持在每天约152.30元。')
fig('B_daily_rolling','B 每天重新拟合的次日预测')
fig('B_daily_fixed','B 八月底锁定的日度多步预测 仅展示已有实际的九至十月')
bfix=metric([num(r['Actual']) for r in ba],[num(r['Forecast']) for r in bf[:61]],[daily_scale(bd,'holdout_daily_train.csv')[0]]*61)
metric_table([('日度滚动',61,daily_metrics(bd,'holdout_daily_train.csv')),('日度固定原点',61,bfix)])
p(f'滚动历史均值基准的 MAE 为{fmt(bs["baseline_MAE"])}元，低于 ARIMA 的308.04元。实际大额支付的发生日难以仅由历史金额确定，导致预测线难以跟随尖峰。')
table(['月份','实际金额','滚动预测合计','固定原点预测合计'],[[m,fmt(a),fmt(pr),fmt(sum(num(bf[i]['Forecast']) for i,r in enumerate(ba) if r['Date'].startswith(m)))] for m,a,pr in dailymonth(bd)],[1.1,1.8,2.08,2.08],9)

# 5 B weekly
page('B 本人自然周预测结果')
p('B 的周度旧实验以52周起步，逐周扩展，共49个起点；每轮一次预测未来4周，并评价四周合计。固定原点实验另用104个完整周训练至2026-08-30，后续有7个完整周能与现有日账单核对。')
fig('B_weekly_49','B 的49轮四周累计预测 横轴为各轮训练截止日')
fig('B_weekly_fixed','B 固定原点周预测 仅展示检验期内实际齐全的7个完整周')
bwmetric=metric([num(r['4周实际合计']) for r in bw],[num(r['4周预测合计']) for r in bw]);bwm=metric([num(r['实际消费（元）']) for r in bwtest],[num(r['预测消费（元）']) for r in bwtest])
metric_table([('49轮四周累计',49,bwmetric),('固定原点完整周',7,bwm)])
p('49轮四周累计的历史均值基准 MAE 为1,915.17元、RMSE 为2,695.99元，优于 ARIMA。该实验包含重叠的四周目标窗口，其统计单位与 A、C 的下一周验证不同。')
bweek=read(W/'holdout_weekly_forecast.csv');bmonths=[]
for month in (9,10):
    actual=sum(num(r['Actual']) for r in ba if date.fromisoformat(r['Date']).month==month);daily=sum(num(bf[i]['Forecast']) for i,r in enumerate(ba) if date.fromisoformat(r['Date']).month==month);weekly=0
    for i,r in enumerate(bweek):
        start=date(2026,8,31)+timedelta(weeks=i);covered=sum((start+timedelta(days=j)).month==month and (start+timedelta(days=j)).year==2026 for j in range(7));weekly+=num(r['Forecast'])*covered/7
    bmonths.append([f'2026-{month:02d}',actual,daily,weekly])
table(['月份','实际金额','日度固定预测','周度日分摊预测'],[[m,*map(fmt,v)] for m,*v in bmonths],[1.1,1.8,2.08,2.08],9)

# 6 C daily
page('C 日账单版本预测结果')
p('本页对应后来提供的《原始账单_时间粒度为日.csv》。共有791天，训练730天、检验61天，与 B 日度实验具有相同的训练和检验日期。金额沿用该文件已有总支出口径。')
fig('C_daily_rolling','C 日账单版本 每天更新的次日预测')
fig('C_daily_fixed','C 日账单版本 八月底一次锁定的多步预测')
cfix=metric([num(r['Actual']) for r in ca],[num(r['Forecast']) for r in cf],[daily_scale(cd,'newbill_train.csv')[0]]*61)
metric_table([('日度滚动',61,daily_metrics(cd,'newbill_train.csv')),('日度固定原点',61,cfix)])
p('固定原点模型为 ARIMA(2,1,2) 带漂移。61折滚动中，ARIMA(0,1,1)带漂移出现47次，ARIMA(2,1,2)带漂移13次，ARIMA(1,1,2)带漂移1次。滚动历史均值基准 MAE 为270.40元，低于 ARIMA。')
table(['月份','实际金额','滚动预测合计','固定原点预测合计'],[[m,fmt(a),fmt(pr),fmt(sum(num(cf[i]['Forecast']) for i,r in enumerate(ca) if r['Date'].startswith(m)))] for m,a,pr in dailymonth(cd)],[1.1,1.8,2.08,2.08],9)

# 7,8,9 C aggregates
for freq,code,title in [('自然周','weekly','C 自然周聚合版本预测结果'),('连续七天','seven','C 连续七天聚合版本预测结果'),('月度','monthly','C 月度聚合版本预测结果')]:
    page(title)
    if freq=='自然周':intro='前108个完整周训练至2026-09-27；训练长度78至107开展30折验证。原保留4个完整周，额外预测第5周以按6/7权重覆盖十月末。'
    elif freq=='连续七天':intro='以2024-09-01为七天周期起点，前108期训练至2026-09-26；开展30折验证，后5期测试。跨九十月第一期取3/7，之后四期全额计入十月。'
    else:intro='训练为2024-09至2026-09共25个月，2026-10为测试月。训练长度15至24开展10折下一月验证。最终模型为 ARIMA(0,1,1) 带漂移。'
    p(intro+' 本页输入直接采用 UC 源表中的个人总支付，十月总额实际为3,702.17元。')
    fig('C_'+code+'_rolling','C '+freq+'聚合版的训练期滚动验证')
    fig('C_'+code+'_fixed','C '+freq+'聚合版的固定原点测试')
    rr=cmrow(freq);tt,tm=ctest(freq);metric_table([('训练期滚动',int(rr['N']),metric_fields(rr)),('固定原点测试',len(tt),tm)])
    row=next(x for x in co if x['Frequency']==freq)
    p(f'完整十月预测为{fmt(row["Forecast"])}元，实际3,702.17元，高估{fmt(row["RelativeErrorPct"])}%。'+('周度最终模型为 ARIMA(1,1,1) 带漂移。' if freq!='月度' else ''))
    ucrw=next(r for r in cm if r['Frequency']==freq and r['Model']=='UC-RW');ucllt=next(r for r in cm if r['Frequency']==freq and r['Model']=='UC-LLT')
    p(f'同目标滚动验证中 UC-RW 的 MAE 为{fmt(ucrw["MAE"])}元，UC-LLT 为{fmt(ucllt["MAE"])}元。'+('本次 ARIMA 的 RMSE 低于两个 UC，但 MAE 高于 UC-RW。' if freq=='自然周' else 'ARIMA 的 MAE 均高于这两个 UC。'))

# 10 interpretation
page('如何比较日度与周度结果')
p('判断日频还是周频更准，需要同一份金额口径、同一训练截止日、同一测试区间以及同一种更新方式。最直接的比较是让日预测和周预测都累计到同一个自然月，再比较月累计误差。')
table(['数据版本','十月实际','日度固定预测','日度相对误差','周度固定预测','周度相对误差'],[
 ['B 原合并账单',fmt(bmonths[1][1]),fmt(bmonths[1][2]),fmt(100*abs(bmonths[1][2]-bmonths[1][1])/bmonths[1][1])+'%',fmt(bmonths[1][3]),fmt(100*abs(bmonths[1][3]-bmonths[1][1])/bmonths[1][1])+'%'],
 ['C 日账单',fmt(4319.87),fmt(sum(num(r['Forecast']) for r in cf[30:])), '11.07%','无同口径结果','—'],
 ['C UC 聚合版',fmt(3702.17),'无同口径结果','—',fmt(next(r['Forecast'] for r in co if r['Frequency']=='自然周')),'43.80%'],
 ['A 自然周','未提供完整十月','无日数据','—','6,664.51','未评价']],[1.4,1.08,1.2,1.08,1.2,1.1],8.6)
p('B 的日度训练截止为8月31日，周度截至8月30日，并存在按预测时点处理退款的差别。这个比较可以描述本次两个方案的十月误差，不能完全排除训练信息差异。')
p('C 日账单的固定原点十月相对误差为11.07%，聚合版本自然周为43.80%。两者实际值与训练截止日均不同，因此不能由此确定日频本身更好。此前“日度更接近实际”的说法只针对这两个已运行方案的描述性结果。')
doc.add_heading('滚动预测与提前预测回答的问题',2)
p('B 日度滚动十月累计7,966.68元、C 日度滚动累计8,487.64元，每天都已吸收之前真实支出。这些累计值适合描述逐日更新方案的结果，不作为九月底一次性预测十月的结果。固定原点方案在整个测试阶段保持起点不变，更接近提前制定整月预算的任务。')
doc.add_heading('从模型表现得到的结论',2)
p('现有 ARIMA 在突发大额支付附近容易漏掉峰值，随后又可能受到峰值影响而提高未来预测。A 最后4期真实金额逐步下降，ARIMA 预测保持在约1,500元，因此连续高估；B 和 C 日度滚动也表现出大额支付后预测偏高的问题。')
p('后续若需要比较频率，优先从每个人同一份日账单同时生成日、自然周与连续七天输入，固定相同可用信息和测试月份，再评价整月累计金额。收入、学费或大额购买计划等已知信息，可作为后续外生变量实验。')

# 11 previous experiment
page('B 早期日数据多步回测补充')
p('早期另有基于 B 数据的 Python 自动 ARIMA 实验，共220个扩展窗口起点，训练截止日为2026-02-23至09-30。每轮一次向前预测多天，再累计未来7、28、30、31天金额。本页保留该历史结果，与后续 MATLAB ECOTOOL 一步滚动结果分别呈现。')
par=p('');par.add_run().add_picture(str(O/'arima-daily220-line.png'),width=Inches(6.98));p(f'图{fig_no+1}  B 早期220轮多步累计预测 图中为原有30天累计结果','Caption');fig_no+=1
table(['累计预测天数','ARIMA MAE','ARIMA RMSE','均值基准 MAE','均值基准 RMSE'],[[h,fmt(old['metrics'][i][2]),fmt(old['metrics'][i][3]),fmt(old['metrics'][i+1][2]),fmt(old['metrics'][i+1][3])] for i,h in [(0,7),(2,28),(4,30),(6,31)]],[1.3,1.44,1.44,1.44,1.44])
p('该实验主要选出 ARIMA(2,1,0)，共189次；其余为 ARIMA(2,1,1) 5次、ARIMA(0,1,1) 25次、ARIMA(0,1,2) 1次。四个预测期限下，历史均值基准的 MAE 和 RMSE 均低于 ARIMA。')
p('早期30天累计 MAE 为5,842.36元，表示未来30天支出总额的误差；当前日度一步 MAE 为308.04元，表示下一天支出的误差。两者的变化同时来自算法实现与任务变化，不能解释为同一个实验的精度提升。')

# 12 test detail
page('固定原点测试金额明细')
p('金额单位为元。A 和 C 的自然周4期合计均含九月底的天数，不等于完整十月。第5周没有实际值的单元格保留空缺。')
doc.add_heading('A 自然周',2)
table(['周期起始日','预测','实际','预测减实际'],[[r['PeriodStart'],fmt(r['Forecast']),fmt(r['Actual']),fmt(r['Error'])] for r in af],[1.75,1.77,1.77,1.77])
for freq in ['自然周','连续七天']:
    doc.add_heading('C '+freq+'聚合版',2);rr=[r for r in ct if r['Frequency']==freq]
    table(['周期起始日','预测','实际','预测减实际'],[[r['PeriodStart'],fmt(r['Forecast']),fmt(r['PeriodActual']),fmt(num(r['Forecast'])-num(r['PeriodActual']))] for r in rr],[1.75,1.77,1.77,1.77])

# 13 provenance and models
page('数据来源与模型记录')
p('人员名称依据用户2026年11月21日的明确命名。A 源文件虽为 C_个人总支付_自然周.csv，本报告全部按 A 标记。B 为本人最初合并账单；后来提供的日账单按 C 标记。历史文件标题中的“本人”或“新账单”不再作为本报告的身份依据。')
table(['结果组','可追溯输入或结果文件'],[
 ['A 自然周','C_个人总支付_自然周.csv；A_ARIMA逐折预测.csv；A_ARIMA及基准评价.csv'],
 ['B 日度','merged-data.json；holdout_daily_train.csv；originalbill_rolling_output.csv'],
 ['B 自然周','weekly49_input.csv；ECOTOOL_ARIMA_49轮周频回测.csv；holdout_weekly_forecast.csv'],
 ['C 日度','原始账单_时间粒度为日.csv；newbill_train.csv；newbill_rolling_output.csv；newbill_model_output.csv'],
 ['C 聚合版','UC个人总支出_月度_含美元.csv；自然周.xlsx；连续七天.xlsx；ARIMA_UC同口径目录中的结果CSV']],[1.3,5.76],9)
doc.add_heading('最终固定原点模型',2)
table(['数据与频率','最终模型'],[['A 自然周','ARIMA(0,1,1) 带漂移'],['B 日度','ARIMA(0,1,1) 无漂移'],['B 自然周','ARIMA(0,1,1) 带漂移'],['C 日账单','ARIMA(2,1,2) 带漂移'],['C 自然周及连续七天聚合版','ARIMA(1,1,1) 带漂移'],['C 月度聚合版','ARIMA(0,1,1) 带漂移']],[3.5,3.56])
p('滚动阶段每折重新识别，因此会出现多个模型。A 的30折中，ARIMA(0,1,1)带漂移26次、ARIMA(1,1,1)带漂移1次、ARIMA(2,1,3)无漂移3次。B 日度61折为 ARIMA(0,1,1)无漂移8次、带漂移49次，以及 ARIMA(1,1,2)带漂移4次。')
p('本次整理从已有预测CSV核算指标并重新制图，没有新增 A 日度实验，也没有将 A、B、C 当作同一份账单合并估计。C 的 UC 比较数值来自此前提供的 UC 结果表；ARIMA 来自本项目实际运行结果。')
p('复现脚本：run_person_a_arima.m、newbill_rolling.m、holdout_arima.m、weekly49_matlab.m、align_arima_uc.m。图像由 plot_three_arima.m 从结果CSV生成。早期220轮图保留原有输出。')

for part in [doc.styles.element,doc.element]:
    for border in list(part.iter(qn('w:pBdr'))):border.getparent().remove(border)
target=O/'A_B_C三份数据_ARIMA预测综合报告.docx';doc.save(target)
audit={'planned_pages':len(pages),'sections':pages,'new_charts':14,'total_figures':fig_no,'B_fixed_daily':bfix,'B_fixed_weekly':bwm,'B_49':bwmetric,'B_fixed_monthly':bmonths,'C_fixed_daily':cfix}
(W/'three_arima_report_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
print(target);print(json.dumps(audit,ensure_ascii=False))
