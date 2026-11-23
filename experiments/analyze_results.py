"""独立核验实验CSV、核对本地来源，并生成中文Markdown报告。"""
from pathlib import Path
import csv
import hashlib
import json
import math
from collections import defaultdict
from datetime import datetime, timedelta
import openpyxl

ROOT = Path(__file__).resolve().parents[1]
PEOPLE = ['A', 'B', 'C']


def read(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def write(path, rows):
    with path.open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)


def close(a, b, tol=1e-7):
    assert math.isclose(float(a), float(b), rel_tol=tol, abs_tol=tol), (a, b)


def quantile(y, p):
    # MATLAB默认分位数：排序后位置 n*p+0.5（端点夹取）。
    s = sorted(y); x = len(s)*p - .5
    lo = max(0, min(len(s)-1, math.floor(x)))
    hi = max(0, min(len(s)-1, math.ceil(x)))
    return s[lo] + (x-math.floor(x))*(s[hi]-s[lo])


def scores(rows):
    errors = [float(r['Forecast'])-float(r['Actual']) for r in rows]
    sm = []
    for r, e in zip(rows, errors):
        den = abs(float(r['Forecast']))+abs(float(r['Actual']))
        sm.append(200*abs(e)/den if den else 0)
    return dict(N=len(rows), MAE=sum(map(abs, errors))/len(rows),
                RMSE=math.sqrt(sum(e*e for e in errors)/len(rows)), sMAPE=sum(sm)/len(sm))


def subset(rows, **kwargs):
    return [r for r in rows if all(str(r[k]) == str(v) for k,v in kwargs.items())]


def mdtable(rows, cols):
    def fmt(v):
        if isinstance(v,float): return f'{v:,.2f}'
        return str(v)
    return '\n'.join(['| '+' | '.join(label for key,label in cols)+' |',
                       '| '+' | '.join('---' for _ in cols)+' |']+
                      ['| '+' | '.join(fmt(r[key]) for key,label in cols)+' |' for r in rows])


def date(v):
    if isinstance(v,datetime): return v.date()
    return datetime.fromisoformat(str(v)[:10]).date()


def data():
    result={}
    for person in PEOPLE:
        w=openpyxl.load_workbook(ROOT/'data'/f'{person}_个人总支付_自然周.xlsx', data_only=True)
        result[person]=[(date(d),float(y)) for d,y in w['UC数据'].values if isinstance(y,(int,float))]
        assert len(result[person])==112
        assert all(d==datetime(2024,9,2).date()+timedelta(weeks=i) for i,(d,y) in enumerate(result[person]))
    return result


def audit_sources(series, thresholds, out):
    # 完整108周阈值仅用于事后描述与账单核实；从不回传给逐原点拟合。
    details={}; status={}
    for person in PEOPLE:
        raw=ROOT/'raw_data'/f'{person}_个人总支付_自然周.xlsx'
        byweek=defaultdict(list)
        if person=='A':
            path=ROOT/'raw_data'/'A_个人总支付_自然周.csv'
            if path.exists():
                for idx,r in enumerate(read(path),2):
                    byweek[date(r['周期起始日'])].append((float(r['个人总支付_元']),idx))
                status[person]='仅核对原始周汇总CSV；缺少逐笔账单，不能确认消费业务性质或误记'
            else: status[person]='未找到本地原始CSV，尚未核对来源'
        elif raw.exists():
            w=openpyxl.load_workbook(raw,data_only=True)
            sheet='合并消费明细' if person=='B' else '04_周期内逐笔'
            for idx,r in enumerate(w[sheet].values,1):
                if idx==1: continue
                if person=='B': d=date(r[1]); amount=float(r[7] or 0)
                else:
                    day=date(r[2]);d=day-timedelta(days=day.weekday());amount=float(r[4] or 0)
                byweek[d].append((amount,idx))
            status[person]='已与来源工作簿支付明细按周重算核对；保留真实大额周，统计候选不等于录入错误'
        else: status[person]='本地原始账单未提供，尚未核对来源'
        details[person]=byweek
    audit=[]
    for person in PEOPLE:
        t=subset(thresholds,Person=person,Group='原始',Origin=108)[0]; upper=float(t['Upper'])
        for i,(d,y) in enumerate(series[person][:108],1):
            if y<=upper: continue
            source=details[person].get(d,[])
            total=sum(v for v,idx in source) if source else None
            if total is not None: close(total,y,1e-6)
            audit.append(dict(Person=person,WeekIndex=i,PeriodStart=d.isoformat(),Original=y,Upper108=upper,
                              SourceWeeklySum=total,SourceRowCount=len(source),
                              LargestIncludedAmount=max((v for v,idx in source),default=None),
                              SourceRows=';'.join(str(idx) for v,idx in source),Verification=status[person]))
    write(out/'异常大额周来源核对.csv',audit)
    return audit,status


def validate(folder, series):
    p=read(folder/'多原点四步预测明细.csv'); metrics=read(folder/'多步预测误差对比.csv')
    fixed=read(folder/'保留四周测试预测.csv');tm=read(folder/'保留四周测试指标.csv')
    ts=read(folder/'各原点异常阈值.csv');pars=read(folder/'各原点模型参数.csv')
    groups=sorted(set(r['Group'] for r in p));models=sorted(set(r['Model'] for r in p))
    assert len(p)==3*len(groups)*len(models)*27*4
    keys=set()
    for r in p:
        n=int(r['Origin']);h=int(r['Horizon']);target=int(r['TargetIndex'])
        assert 78<=n<=104 and 1<=h<=4 and target==n+h<=108
        key=tuple(r[k] for k in ['Person','Group','Model','Origin','Horizon']);assert key not in keys;keys.add(key)
        d,y=series[r['Person']][target-1]; close(y,r['Actual']);close(float(r['Forecast'])-y,r['Error'])
        assert date(r['PeriodStart'])==d
    for detail,summary in [(p,metrics),(fixed,tm)]:
        for r in summary:
            z=subset(detail,Person=r['Person'],Group=r['Group'],Model=r['Model'])
            if int(r['Horizon']): z=subset(z,Horizon=r['Horizon'])
            for k,v in scores(z).items():close(v,r[k])
    for r in fixed:
        close(r['Actual'],series[r['Person']][107+int(r['Horizon'])][1])
    clipfile=folder/'各原点训练缩尾记录.csv';clipped=read(clipfile) if clipfile.exists() else []
    for t in ts:
        y=[y for d,y in series[t['Person']][:int(t['Origin'])]]
        q1,q3=quantile(y,.25),quantile(y,.75);upper=q3+1.5*(q3-q1)
        close(q1,t['Q1']);close(q3,t['Q3']);close(upper,t['Upper'])
        flags=[(i,v) for i,v in enumerate(y,1) if v>upper]
        close(len(flags),t['DetectedCount'])
        if t['Group']=='训练缩尾':
            z=subset(clipped,Person=t['Person'],Group=t['Group'],Origin=t['Origin']);assert len(z)==len(flags)
            close(sum(v-upper for i,v in flags),t['RemovedAmount'])
            for r in z:
                close(y[int(r['WeekIndex'])-1],r['Original']);close(upper,r['Treated'])
                assert int(r['WeekIndex'])<=int(t['Origin'])
        else: close(t['ClippedCount'],0);close(t['RemovedAmount'],0)
    for r in pars:close(10**float(r['Log10Variance']),r['Variance'])
    # 原始组h=1必须复现正式一步滚动预测的前27折。
    for person in PEOPLE:
        old=read(ROOT/'output'/person/'UC滚动预测明细.csv')
        for r in subset(p,Person=person,Group='原始',Horizon=1):
            matches=[o for o in old if o['Model']==r['Model'] and date(o['PeriodStart'])==date(r['PeriodStart'])]
            assert len(matches)==1;close(r['Forecast'],matches[0]['Forecast'])
    old=read(ROOT/'output'/'报告四模型固定原点预测.csv')
    for r in subset(fixed,Group='原始'):
        z=subset(old,Person=r['Person'],Model=r['Model'],Horizon=r['Horizon']);assert len(z)==1;close(r['Forecast'],z[0]['Forecast'])
    sel=read(folder/'训练内选模结果.csv');diag=read(folder/'108周训练残差诊断.csv')
    for r in sel:
        uc=[m for m in subset(metrics,Person=r['Person'],Group=r['Group'],Horizon=0) if m['Model'] in ['RW','LLT']]
        best=min(uc,key=lambda m:(float(m['MAE']),float(m['RMSE']),m['Model']))['Model'];assert best==r['LowestMAEUC']
        passes={m:all(float(d['RejectH0'])==0 for d in subset(diag,Person=r['Person'],Group=r['Group'],Model=m)) for m in ['RW','LLT']}
        expected=next(m for m in passes if passes[m]) if sum(passes.values())==1 else best
        assert expected==r['SelectedUC']
    return p,metrics,fixed,tm,ts,pars,sel


def common_methods():
    return '''## 实验口径与限制

三位成员均沿用112周原始建模数据：前108周训练，最后4周（2026-09-28至2026-10-25）保留测试。训练截止索引为78、79、…、104，共27个固定原点，每个原点一次预测后续4周，中途不吸收真实测试金额。MA3从第2步起递归加入自身预测；朴素预测始终使用当时最后一个观测。RW、LLT沿用ECOTOOL四参数位置调用，实际为CML，无季节项。

每个步长有27条误差；总体指标按108个“原点×步长”预测等权计算，RMSE先汇总平方误差再开方。108条误差只覆盖30个不同目标周，同一周可被不同原点重复预测；窗口和误差相关，27个原点并非27次独立实验。本实验报告描述性变化，不宣称统计显著性或因果作用，也不直接混合三人的元尺度误差排名。

误差=预测−原始实际金额。MAE、RMSE单位为元；sMAPE=平均[200×|误差|/(|预测|+|实际|)]，双方均为0时记0，单位为%。小额周会提高相对误差。预测不截断、不事后校准区间。

UC按总体MAE、RMSE依次排序，同时沿用正式流程的诊断优先规则：完整108周训练残差在滞后3、6的Ljung–Box检验仅有一个模型通过时优先选该模型，否则按上述排序。报告同时给出纯误差最佳UC与该规则选择结果。实验一的基准模型不参加UC二选一，但参与四方法比较；实验二仅比较两种UC及其训练处理。所有选模和108周起点的预测先写入锁定MAT/CSV，随后才读取保留4周金额；原保留集已在此前分析中观察，本轮不构成全新盲测，测试成绩不反向改选模型。
'''


def metric_table(rows):
    values=[dict(r, MAE=float(r['MAE']),RMSE=float(r['RMSE']),sMAPE=float(r['sMAPE'])) for r in rows]
    return mdtable(values,[('Person','成员'),('Group','组别'),('Model','模型'),('N','误差数'),('MAE','MAE 元'),('RMSE','RMSE 元'),('sMAPE','sMAPE %')])


def report(experiment,series):
    out=ROOT/'experiments'/experiment/'results';p,m,f,tm,ts,pars,sel=validate(out,series)
    old=read(ROOT/'output'/'三人UC结果汇总.csv')
    title='多个固定原点四步回测分析报告' if experiment=='multi_origin_4step' else '异常大额支出敏感性分析报告'
    parts=[f'# {title}\n\n2026年11月23日｜成员A、B、C\n\n## 主要结论\n']
    for person in PEOPLE:
        s=subset(sel,Person=person,Group='原始')[0];previous=subset(old,Person=person)[0]['SelectedUC']
        best=subset(m,Person=person,Group='原始',Horizon=0,Model=s['SelectedUC'])[0]
        pool='四方法' if experiment=='multi_origin_4step' else '两种UC模型'
        parts.append(f"{person}：原始组四步回测选择{s['SelectedUC']}，总体MAE {float(best['MAE']):,.2f}元；原正式一步流程选择{previous}，本次{'一致' if s['SelectedUC']==previous else '发生变化'}。{pool}中总体MAE最佳为{s['LowestMAEAll']}。")
    comparisons=[]
    if experiment=='outlier_sensitivity':
        for person in PEOPLE:
            for model in ['RW','LLT']:
                for stage,rows in [('训练内四步回测',m),('保留四周测试',tm)]:
                    raw=subset(rows,Person=person,Group='原始',Model=model,Horizon=0)[0]
                    cap=subset(rows,Person=person,Group='训练缩尾',Model=model,Horizon=0)[0]
                    row=dict(Person=person,Stage=stage,Model=model)
                    for k in ['MAE','RMSE','sMAPE']:
                        row['Original'+k]=float(raw[k]);row['Treated'+k]=float(cap[k])
                        row[k+'ImprovementPct']=100*(float(raw[k])-float(cap[k]))/float(raw[k])
                    comparisons.append(row)
            z=subset(comparisons,Person=person,Stage='训练内四步回测')
            parts.append(person+'：缩尾后'+ '；'.join(f"{r['Model']} MAE {r['OriginalMAE']:,.2f}→{r['TreatedMAE']:,.2f}元（改善{r['MAEImprovementPct']:.2f}%）" for r in z)+'。')
        write(out/'原始与缩尾模型性能比较.csv',comparisons)
        audit,status=audit_sources(series,ts,out)
        parts.append('缩尾属于训练扰动实验，未更改原数据或正式模型；负的改善率表示变差。是否保留该处理应以训练内结果为依据，不能根据4周测试挑选。大额周不自动等同于错误，有限样本的变化也不能证明统计显著。')
        improved_all=True
        for person in PEOPLE:
            rawsel=subset(sel,Person=person,Group='原始')[0]
            capsel=subset(sel,Person=person,Group='训练缩尾')[0]
            change=subset(comparisons,Person=person,Stage='训练内四步回测',Model=rawsel['SelectedUC'])[0]
            improved_all &= change['MAEImprovementPct']>0 and change['RMSEImprovementPct']>0
            parts.append(f"{person}：原选{rawsel['SelectedUC']}缩尾后回测MAE改善{change['MAEImprovementPct']:.2f}%，RMSE改善{change['RMSEImprovementPct']:.2f}%；缩尾组纯MAE最佳UC为{capsel['LowestMAEUC']}，按诊断优先规则选择{capsel['SelectedUC']}（RW通过={capsel['RWPass']}，LLT通过={capsel['LLTPass']}）。")
        parts.append('各成员原选模型的MAE和RMSE均改善，可进一步检验该处理能否推广；本轮仍不自动替换正式结果。' if improved_all else '本轮不建议统一采用缩尾：各成员原选模型的MAE和RMSE未同时一致改善。平均绝对偏差改善不一定意味着大误差风险降低，选模变化也需要与诊断结果一同解释，不能直接替换正式结果。')
    else:
        parts.append('总体指标与单个原点的胜出次数衡量不同方面。总体MAE用于原规则选模；RMSE反映较大误差的影响，逐原点胜出次数反映相对表现的分布。应结合下表与误差图判断稳定性，不应声称某模型在每个未来原点均最优。')
    parts.append('\n## 训练集内部的总体表现\n\n'+metric_table(subset(m,Horizon=0)))
    parts.append('\n## 选择是否稳定\n')
    selection_rows=[];wins=[]
    for s in sel:
        previous=subset(old,Person=s['Person'])[0]['SelectedUC']
        selection_rows.append(dict(s,PreviousUC=previous))
        counts=defaultdict(int)
        for n in range(78,105):
            z=subset(p,Person=s['Person'],Group=s['Group'],Origin=n)
            candidates=[]
            for model in sorted(set(r['Model'] for r in z)):
                sc=scores(subset(z,Model=model));candidates.append((sc['MAE'],sc['RMSE'],model))
            best=min(candidates)[2];counts[best]+=1
        wins.extend(dict(Person=s['Person'],Group=s['Group'],Model=k,WinningOrigins=counts[k]) for k in sorted(set(r['Model'] for r in subset(p,Person=s['Person'],Group=s['Group']))))
    parts.append(mdtable(selection_rows,[('Person','成员'),('Group','组别'),('PreviousUC','原正式UC'),('LowestMAEUC','四步纯MAE最佳UC'),('SelectedUC','四步按原规则选择'),('LowestMAEAll','本实验方法中MAE最佳')]))
    parts.append('\n逐原点按该原点4步平均MAE取最佳，平局按RMSE及模型名确定；胜出次数描述稳定性，不是独立显著性检验。\n\n'+mdtable(wins,[('Person','成员'),('Group','组别'),('Model','模型'),('WinningOrigins','27原点胜出次数')]))
    write(out/'逐原点模型胜出次数.csv',wins)
    parts.append('\n## 不同预测步长的误差\n')
    for person in PEOPLE:
        parts.append(f'\n### 成员{person}\n\n![{person}不同预测步长误差]({person}_不同预测步长误差.png)\n')
        z=subset(m,Person=person);z=[dict(r,MAE=float(r['MAE']),RMSE=float(r['RMSE']),sMAPE=float(r['sMAPE'])) for r in z if r['Horizon']!='0']
        parts.append(mdtable(z,[('Group','组别'),('Model','模型'),('Horizon','预测第几周'),('MAE','MAE 元'),('RMSE','RMSE 元'),('sMAPE','sMAPE %')]))
    if experiment=='outlier_sensitivity':
        parts.append('\n## 大额周的来源核对与处理影响\n\n仅对高于上界的训练金额缩尾为上界，不处理低额周，不删除周，不改变预测目标；每个原点重新使用截至当时的全部原始历史计算Q1、Q3和IQR，不沿用上次缩尾结果。完整108周阈值只用于本节事后描述与最终拟合，不用于较早原点。')
        for person in PEOPLE:parts.append(f"{person}：{status[person]}。")
        parts.append(mdtable(audit,[('Person','成员'),('PeriodStart','大额周起始日'),('Original','原始金额 元'),('Upper108','108周上界 元'),('SourceWeeklySum','来源重算 元'),('SourceRowCount','来源行数')]))
        impact=[]
        for person in PEOPLE:
            z=subset(ts,Person=person,Group='训练缩尾');rolling=[r for r in z if r['Origin']!='108'];full=subset(z,Origin=108)[0]
            impact.append(dict(Person=person,MinCount=min(int(r['ClippedCount']) for r in rolling),MaxCount=max(int(r['ClippedCount']) for r in rolling),FullCount=int(full['ClippedCount']),FullRemoved=float(full['RemovedAmount'])))
        write(out/'异常支出影响汇总.csv',impact)
        parts.append('\n'+mdtable(impact,[('Person','成员'),('MinCount','27原点最少缩尾周数'),('MaxCount','最多缩尾周数'),('FullCount','108周缩尾周数'),('FullRemoved','108周拟合减少金额 元')]))
        parts.append('\n### 参数变化\n\n以下为完整108周估计的方差参数，单位元²；log10尺度及全部27原点参数保存在CSV中。边界附近的参数比值可能非常大，不据此声称参数显著变化；缩尾也会机械改变噪声规模。')
        changes=[]
        for raw in subset(pars,Group='原始',Origin=108):
            cap=subset(pars,Person=raw['Person'],Group='训练缩尾',Origin=108,Model=raw['Model'],Parameter=raw['Parameter'])[0]
            changes.append(dict(Person=raw['Person'],Model=raw['Model'],Parameter=raw['Parameter'],OriginalVariance=float(raw['Variance']),TreatedVariance=float(cap['Variance']),OriginalLog10=float(raw['Log10Variance']),TreatedLog10=float(cap['Log10Variance'])))
        write(out/'108周模型参数变化.csv',changes)
        paired=[]
        for raw in subset(pars,Group='原始'):
            cap=subset(pars,Person=raw['Person'],Group='训练缩尾',Origin=raw['Origin'],Model=raw['Model'],Parameter=raw['Parameter'])[0]
            paired.append(dict(Person=raw['Person'],Origin=raw['Origin'],Model=raw['Model'],Parameter=raw['Parameter'],
                               OriginalVariance=float(raw['Variance']),TreatedVariance=float(cap['Variance']),
                               OriginalLog10=float(raw['Log10Variance']),TreatedLog10=float(cap['Log10Variance']),
                               Log10Change=float(cap['Log10Variance'])-float(raw['Log10Variance'])))
        write(out/'各原点参数变化配对比较.csv',paired)
        parts.append(mdtable(changes,[('Person','成员'),('Model','模型'),('Parameter','扰动'),('OriginalVariance','原始方差'),('TreatedVariance','缩尾方差'),('OriginalLog10','原始log10'),('TreatedLog10','缩尾log10')]))
        parts.append('\n### 性能变化\n\n'+mdtable(comparisons,[('Person','成员'),('Stage','评价集'),('Model','模型'),('OriginalMAE','原始MAE 元'),('TreatedMAE','缩尾MAE 元'),('MAEImprovementPct','MAE改善 %'),('RMSEImprovementPct','RMSE改善 %'),('sMAPEImprovementPct','sMAPE改善 %')]))
    parts.append('\n## 最后查看原来保留的4周\n\n以下结果只作已锁定模型的外部检查，不反馈训练内选模。每模型仅4个目标，不能据此保证后续预测稳定。\n\n'+metric_table(subset(tm,Horizon=0)))
    for person in PEOPLE:
        for s in subset(sel,Person=person):
            chosen=subset(tm,Person=person,Group=s['Group'],Model=s['SelectedUC'],Horizon=0)[0]
            candidates=subset(tm,Person=person,Group=s['Group'],Horizon=0)
            best=min(candidates,key=lambda r:(float(r['MAE']),float(r['RMSE']),r['Model']))
            parts.append(f"{person} {s['Group']}组：训练内锁定{s['SelectedUC']}，保留测试MAE为{float(chosen['MAE']):,.2f}元；本实验该组方法中测试MAE最低为{best['Model']}（{float(best['MAE']):,.2f}元）。这只是事后对照，不改选模型。")
    parts.append(common_methods())
    parts.append('''\n## 数据与复现依据

- 输入：根目录`data/A_个人总支付_自然周.xlsx`、B及C同名输入；口径沿用正式分析。A为总支付，B为既有净消费汇总，C为既有个人总支付，三人清洗口径有差别。
- 本目录`多原点四步预测明细.csv`、`多步预测误差对比.csv`：27原点的每条预测及分步长/总体指标；Horizon=0表示总体。
- `各原点模型参数.csv`、`各原点异常阈值.csv`、`训练内选模结果.csv`与`108周训练残差诊断.csv`：可检查拟合、阈值和选模；完整模型保存在锁定MAT中。
- `保留四周测试预测.csv`、`保留四周测试指标.csv`：最终固定原点结果；`测试预测锁定.csv`不含实际测试金额。
- 在对应实验目录执行`run_experiment`；也可在根目录`addpath('experiments')`后调用`run_uc_backtests(string(pwd),'本实验目录名')`。需与正式流程相同的MATLAB及ECOTOOL环境。
- 根目录运行`python experiments/analyze_results.py`独立复算指标、阈值、选择、原始组对正式预测的复现，并重建本报告。`实验核验.json`记录输入SHA256与检查状态。原始账单只供本机核对，不复制逐笔消费内容到报告。
''')
    (out/(title+'.md')).write_text('\n\n'.join(parts).rstrip()+'\n',encoding='utf-8')
    for person in PEOPLE:assert (out/f'{person}_不同预测步长误差.png').exists()
    return dict(prediction_rows=len(p),test_rows=len(f),metric_rows=len(m),all_checks_passed=True)


def main():
    series=data();checks={}
    for experiment in ['multi_origin_4step','outlier_sensitivity']:
        checks[experiment]=report(experiment,series)
    # 两实验原始组必须逐项完全一致。
    a=read(ROOT/'experiments/multi_origin_4step/results/多原点四步预测明细.csv')
    b=read(ROOT/'experiments/outlier_sensitivity/results/多原点四步预测明细.csv')
    bkeys={tuple(r[k] for k in ['Person','Model','Origin','Horizon']):r for r in subset(b,Group='原始')}
    for r in a:
        if r['Model'] not in ['RW','LLT']: continue
        key=tuple(r[k] for k in ['Person','Model','Origin','Horizon']);close(r['Forecast'],bkeys[key]['Forecast'])
    hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'data').glob('*.xlsx'))}
    receipt=dict(checks=checks,input_sha256=hashes,raw_groups_match_across_experiments=True,
                 checks_performed=['全部误差指标独立重算','所有原点阈值仅使用当时训练历史','缩尾记录逐条核验','原始组一步预测及保留四步预测复现正式结果','选模规则独立核验'])
    receipt['code_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sorted((ROOT/'experiments').rglob('*')) if p.suffix in ['.py','.m']}
    receipt['source_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted((ROOT/'raw_data').glob('*')) if p.is_file() and p.name[0] in PEOPLE}
    for experiment in checks:
        (ROOT/'experiments'/experiment/'results/实验核验.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(checks,ensure_ascii=False,indent=2))


if __name__=='__main__': main()
