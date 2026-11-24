"""Independently audit inputs and metrics, then write the Chinese report."""
from pathlib import Path
import csv, json, hashlib, math, re, subprocess, io, time
from datetime import datetime, timedelta
from collections import defaultdict
import numpy as np
import pandas as pd
import openpyxl
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

BASE=Path(__file__).resolve().parent
ROOT=BASE.parent
OUT=BASE/'results/comparison'
MODELS=['ARIMA(0,0,0)','ETS-NN','ETS-AN','UC-RW','UC-LLT']
plt.rcParams.update({'font.family':'Microsoft YaHei','axes.unicode_minus':False,'font.size':10})
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(df,path): df.to_csv(path,index=False,encoding='utf-8-sig',float_format='%.12g')
def md(df):
    def fmt(x):
        if isinstance(x,(float,np.floating)) and np.isnan(x): return '—'
        return f'{x:,.3f}' if isinstance(x,(float,np.floating)) else str(x)
    return '\n'.join(['| '+' | '.join(map(str,df.columns))+' |','| '+' | '.join(['---']*len(df.columns))+' |']+['| '+' | '.join(fmt(x) for x in r)+' |' for r in df.itertuples(index=False,name=None)])
def near(a,b): np.testing.assert_allclose(a,b,rtol=1e-9,atol=1e-7)
provenance=json.loads((OUT/'provenance.json').read_text(encoding='utf-8'))
series={}; audits=[]; remote_audits=[]
for person in 'ABC':
    path=ROOT/'data'/f'{person}_个人总支付_自然周.xlsx'
    assert digest(path)==provenance['data'][path.name]
    w=openpyxl.load_workbook(path,data_only=True,read_only=True)
    rows=list(w['UC数据'].values)
    assert rows[0]==('周期起始日','个人总支付_元')
    dates=[pd.Timestamp(r[0]).date() for r in rows[1:]]
    y=np.array([float(r[1]) for r in rows[1:]])
    assert len(y)==112 and np.isfinite(y).all() and (y>=0).all()
    assert dates==[(datetime(2024,9,2)+timedelta(weeks=i)).date() for i in range(112)]
    series[person]=(dates,y)
    weekly=defaultdict(float)
    if person=='A':
        raw=ROOT/'raw_data/A_个人总支付_自然周.csv'
        for r in csv.DictReader(raw.open(encoding='utf-8-sig')):
            weekly[pd.Timestamp(r['周期起始日']).date()]+=float(r['个人总支付_元'])
        scope='个人总支付；未减退款'
    else:
        raw=ROOT/'raw_data'/f'{person}_个人总支付_自然周.xlsx'
        rw=openpyxl.load_workbook(raw,data_only=True,read_only=True)
        sh='合并消费明细' if person=='B' else '04_周期内逐笔'
        for r in list(rw[sh].values)[1:]:
            if person=='B': d=pd.Timestamp(r[1]).date(); amount=float(r[7] or 0)
            else:
                d=pd.Timestamp(r[2]).date(); d-=timedelta(days=d.weekday()); amount=float(r[4] or 0)
            weekly[d]+=amount
        scope='净消费、退款回冲原日（既有口径）' if person=='B' else '原总支付、保留校园卡代理及已确认大额事件'
    near(y,[weekly[d] for d in dates])
    audits.append(dict(Person=person,File=str(path.relative_to(ROOT)),SHA256=digest(path),Source=str(raw.relative_to(ROOT)),SourceSHA256=digest(raw),Weeks=112,Total=y.sum(),TrainTotal=y[:108].sum(),TestTotal=y[108:].sum(),FirstWeek=str(dates[0]),LastWeek=str(dates[-1]),SourceMaxDifference=float(max(abs(y-np.array([weekly[d] for d in dates])))),Scope=scope))
    # Remote historical predictions identify version/identity; never used for scoring.
    ref=f'results/tables/{person}_weeks_test/{person}_rolling_predictions.csv'
    blob=subprocess.check_output(['git','show',provenance['ets_commit']+':'+ref],cwd=ROOT)
    rr=pd.read_csv(io.BytesIO(blob))
    remote_audits.append((person,ref,rr))
audit=pd.DataFrame(audits); write(audit,OUT/'data_audit.csv')
identity=[]
for person,ref,rr in remote_audits:
    for canonical in 'ABC':
        y=series[canonical][1]
        target=rr.k.to_numpy(dtype=int) # k=78 forecasts observation 79, zero-based index 78
        delta=np.abs(rr.actual.to_numpy()-y[target])
        identity.append(dict(RemoteLabel=person,CanonicalMember=canonical,Rows=len(rr),MaxActualDifference=delta.max(),MatchingRows=int((delta<1e-6).sum()),RemotePath=ref))
write(pd.DataFrame(identity),OUT/'remote_identity_audit.csv')
p=pd.read_csv(OUT/'all_predictions.csv'); par=pd.read_csv(OUT/'all_parameters.csv'); scales=pd.read_csv(OUT/'ets_scale_audit.csv')
assert len(p)==120 and len(par)==60 and len(scales)==24
assert not p.duplicated(['Person','Model','Protocol','TargetWeek']).any()
for r in p.itertuples():
    y=series[r.Person][1]; n=r.OriginWeek; target=r.TargetWeek
    assert 108<=n<=111 and 109<=target<=112
    assert (r.Protocol=='rolling' and target==n+1) or (r.Protocol=='fixed' and n==108)
    near(r.Actual,y[target-1]); near(r.Error,r.Forecast-r.Actual)
    near(r.MASEScale,np.mean(np.abs(np.diff(y[:n]))))
    if r.Model==MODELS[0]: near(r.Forecast,y[:n].mean())
for person in 'ABC':
    old=pd.read_csv(ROOT/f'experiments/uc_ssm_rebuild/results/{person}/最后四周独立预测与真实值.csv')
    for model in ['RW','LLT']:
        current=p[(p.Person==person)&(p.Model=='UC-'+model)&(p.Protocol=='fixed')].sort_values('TargetWeek')
        near(current.Forecast.to_numpy(),old[old.Model==model].sort_values('TargetWeek').Forecast.to_numpy())
    for model in MODELS:
        z=p[(p.Person==person)&(p.Model==model)&(p.TargetWeek==109)]
        near(z.Forecast.iloc[0],z.Forecast.iloc[1])
metrics=[]
for (person,model,protocol),z in p.groupby(['Person','Model','Protocol'],sort=False):
    assert len(z)==4
    e=z.Forecast.to_numpy()-z.Actual.to_numpy(); den=abs(z.Forecast.to_numpy())+abs(z.Actual.to_numpy())
    sm=np.divide(200*abs(e),den,out=np.zeros_like(e),where=den!=0)
    metrics.append(dict(Person=person,Model=model,Protocol=protocol,N=4,MAE=abs(e).mean(),RMSE=np.sqrt(np.mean(e**2)),sMAPE=sm.mean(),MASE=np.mean(abs(e)/z.MASEScale.to_numpy()),ForecastTotal=z.Forecast.sum(),ActualTotal=z.Actual.sum(),CumulativeAbsoluteError=abs(e.sum()),SumWeeklyAbsoluteError=abs(e).sum()))
metrics=pd.DataFrame(metrics); write(metrics,OUT/'performance.csv')
comparison=[]
for person in 'ABC':
    for model in MODELS:
        z=metrics[(metrics.Person==person)&(metrics.Model==model)].set_index('Protocol')
        r=dict(Person=person,Model=model)
        for m in ['MAE','RMSE','sMAPE','MASE','CumulativeAbsoluteError']:
            r['Fixed'+m]=z.loc['fixed',m];r['Rolling'+m]=z.loc['rolling',m];r['Delta'+m]=r['Rolling'+m]-r['Fixed'+m]
        r['MAEImprovementPct']=100*(1-r['RollingMAE']/r['FixedMAE'])
        comparison.append(r)
comparison=pd.DataFrame(comparison);write(comparison,OUT/'fixed_vs_rolling.csv')
scale_rows=[]
for r in scales.itertuples():
    folder=BASE/'results'/r.Person; code=r.Model[-2:]
    texts=[(folder/f'ETS_{code}_{r.OriginWeek}{suffix}.txt').read_text(encoding='utf-8') for suffix in ['', '_standardized']]
    params=[];stops=[]
    for text in texts:
        matches=re.findall(r'^\s*(level|slope)[ \t]+([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)',text,re.M)
        values={}
        for k,v in matches:
            if k not in values: values[k]=float(v)
        params.append(values)
        stops.append('局部最小值（文本）；无数值退出码' if ('Exit1basic' in text or 'local_min_unconstrained' in text) else ('步长停止（文本）；无数值退出码' if 'Exit2basic' in text else '未确认；见原始优化日志'))
    rawpar=np.fromstring(str(r.RawParameters).strip('[]'),sep=' ')
    stdpar=np.fromstring(str(r.StandardParameters).strip('[]'),sep=' ')
    delta=float(np.max(abs(rawpar-stdpar)))
    forecast_values=np.fromstring(str(r.RawForecasts).strip('[]'),sep=' ')
    relative=r.MaxForecastDifference/max(1,np.max(abs(forecast_values)))
    scale_rows.append(dict(Person=r.Person,Model=r.Model,OriginWeek=r.OriginWeek,RawAlpha=rawpar[0],StandardAlpha=stdpar[0],RawBeta=rawpar[1] if len(rawpar)>1 else np.nan,StandardBeta=stdpar[1] if len(stdpar)>1 else np.nan,MaxSmoothingDifference=delta,MaxForecastDifference=r.MaxForecastDifference,MaxForecastRelativePct=relative*100,RawConvergence=stops[0],StandardConvergence=stops[1],Consistent=bool(delta<=1e-3 and r.MaxForecastDifference<=.10)))
scale_result=pd.DataFrame(scale_rows);write(scale_result,OUT/'ets_scale_parameters.csv')
affine=pd.read_csv(OUT/'ets_affine_diagnostic.csv')
assert len(affine)==16
affine_gap=float(np.max(abs(affine.DivisionOnlyRestored-affine.CenteredRestored)))
assert affine_gap<.001
for person in 'ABC':
    for protocol in ['rolling','fixed']:
        fig,ax=plt.subplots(figsize=(10.5,5.8),layout='constrained')
        dates,y=series[person];x=np.arange(109,113)
        ax.plot(x,y[108:],'k-o',lw=2.6,label='实际消费',zorder=10)
        for i,model in enumerate(MODELS):
            z=p[(p.Person==person)&(p.Protocol==protocol)&(p.Model==model)].sort_values('TargetWeek')
            ax.plot(x,z.Forecast,linestyle=['--','-.',':','--','-.'][i],marker=['s','^','v','D','P'][i],label=model)
        ax.set_xticks(x,[str(d)[5:] for d in dates[108:]])
        ax.set(xlabel='预测目标周起始日（2026年）',ylabel='个人周消费（元）',title=f'成员{person}：'+('滚动一步预测' if protocol=='rolling' else '固定原点四步预测'))
        ax.grid(alpha=.2);ax.legend(ncol=3,fontsize=9,loc='upper center',bbox_to_anchor=(.5,-.16))
        fig.savefig(BASE/f'results/{person}/{protocol}_forecast.png',dpi=160);plt.close(fig)
runtime=json.loads((OUT/'runtime.json').read_text(encoding='utf-8'))
report=['# 五模型最后四周滚动一步预测补充实验','2026年11月24日｜测试期：2026-09-28—2026-10-25｜金额单位：人民币元','## 主要结论']
improved=int((comparison.DeltaMAE<0).sum())
report.append(f'15组“成员×模型”中有{improved}组的滚动MAE低于固定原点MAE。以下最佳模型仅按本次四周MAE作事后描述，不用于重新调参，也不代表统计显著性。')
best=[]
for person in 'ABC':
    z=metrics[metrics.Person==person]
    f=z[z.Protocol=='fixed'].sort_values(['MAE','RMSE']).iloc[0];r=z[z.Protocol=='rolling'].sort_values(['MAE','RMSE']).iloc[0]
    baseline=z[(z.Protocol=='rolling')&(z.Model==MODELS[0])].iloc[0]
    best.append(dict(成员=person,固定原点最佳=f.Model,固定MAE=f.MAE,滚动最佳=r.Model,滚动MAE=r.MAE,均值MAE=baseline.MAE,最佳变化='是' if f.Model!=r.Model else '否'))
report.append(md(pd.DataFrame(best)))
report+=['## 数据身份与统一口径',md(audit[['Person','Weeks','Total','TrainTotal','TestTotal','Scope']].rename(columns={'Person':'成员','Weeks':'周数','Total':'112周合计','TrainTotal':'108周训练合计','TestTotal':'四周实际合计','Scope':'既有消费口径'})),
'三套数据均逐周核对本地原始来源，日期连续且唯一，未删除异常消费。五模型在同一成员内逐值使用相同输入。三人既有来源口径有差异：B保留既定净消费口径，并不把它重新命名为未经退款的总支付；跨人金额不可视为同口径消费水平排名。输入SHA256及原始来源SHA256见[data_audit.csv](data_audit.csv)。',
'Ariel的B脚本读取旧C标签目录、C脚本读取旧B标签目录；本实验不用这些旧路径，按本地已确认成员身份读取data/A、B、C。远端三份历史表的30个真实目标值各自与本地同名成员逐值一致，说明脚本已补偿旧标签互换；这些表不足以证明全部112周及估计版本一致，因此不直接复用远端预测。交叉核对见[remote_identity_audit.csv](remote_identity_audit.csv)。',
'## 扩展窗口协议与估计方法',
'训练长度依次为108、109、110、111周，目标依次为109—112周。每轮重新估计参数及滤波状态，只把截至训练末周的金额传入拟合函数。固定原点对照只用前108周，一次预测4周；第109周两协议来自同一次估计，逐值一致。没有运行30折或27原点回测。测试结果此前已公开，本实验属于事后补充实验。',
'ARIMA(0,0,0)为当轮训练均值，带估计常数；这是与ARIMA同学后续核对的明确实现。ETS沿用Ariel的modelETS(y,[],NN/AN,H,CML)，无变换的原尺度作为预先指定主方案。UC使用本地最新uc_ssm_rebuild的标准化、三个预设起点、对数方差边界[-18,6]、原优化容差及最大似然选择规则；方差乘训练样本标准差平方还原。UC固定原点预测已与新版已有结果逐值核对，未覆盖旧结果。',
'## 五模型滚动一步性能',
md(metrics[metrics.Protocol=='rolling'][['Person','Model','MAE','RMSE','sMAPE','MASE','ForecastTotal','ActualTotal','CumulativeAbsoluteError','SumWeeklyAbsoluteError']]),
'MAE与RMSE单位为元/周；sMAPE为百分数，使用200×|误差|/(|实际|+|预测|)，双零计0。MASE每条预测除以当轮训练集mean(abs(diff(y)))后取均值；固定原点四条预测均用108周训练分母。ForecastTotal是四个完整周直接相加，不是按天折算的十月金额。CumulativeAbsoluteError=|预测总额−实际总额|；SumWeeklyAbsoluteError=Σ|逐周误差|，不能互换。',
'## 固定原点与滚动一步对比',md(comparison[['Person','Model','FixedMAE','RollingMAE','MAEImprovementPct','FixedRMSE','RollingRMSE','FixedCumulativeAbsoluteError','RollingCumulativeAbsoluteError']]),
'MAEImprovementPct为正表示改善。动态更新会改变可用信息集，因此该比较描述实际更新策略收益，不是纯粹固定参数的结构检验。A的固定原点ETS-AN第112周预测为负，保留原模型输出，没有事后截为零。最佳模型依指标而变：A滚动MAE以ETS-AN最低，滚动RMSE以UC-LLT最低；不得把一个指标的胜出泛化到全部指标。',
'## 水平和趋势更新的预测价值']
for person in 'ABC':
    z=metrics[(metrics.Person==person)&(metrics.Protocol=='rolling')].set_index('Model')
    nn,an,rw,llt=[z.loc[m,'MAE'] for m in MODELS[1:]];mean=z.loc[MODELS[0],'MAE']
    better=[m for m in MODELS[1:] if z.loc[m,'MAE']<mean]
    report.append(f'成员{person}：ETS-NN/AN的滚动MAE为{nn:.2f}/{an:.2f}元，UC-RW/LLT为{rw:.2f}/{llt:.2f}元；历史均值为{mean:.2f}元。优于均值的动态候选：'+('、'.join(better) if better else '无')+'。趋势候选应分别与同家族水平候选比较，不能仅从参数存在就断言趋势有价值。')
report+=['状态与参数一起重估，本实验不能把收益单独归因于状态更新或参数更新。四周数据只能说明本次目标期的表现；不能据此宣称动态模型普遍有效、普遍无效或具有统计显著性。',
'## 实际消费与预测曲线']
for person in 'ABC':
    report += [f'### 成员{person}',f'![成员{person}滚动一步](../{person}/rolling_forecast.png)',f'![成员{person}固定原点](../{person}/fixed_forecast.png)']
report+=['## ETS原尺度与标准化尺度一致性',md(scale_result),
f'核验采用严格诊断阈值：平滑参数差≤0.001且还原预测最大差≤0.10元。参数和预测均使用完整精度API值，未使用显示表四舍五入参数做判断。{int(scale_result.Consistent.sum())}/24组符合严格阈值，最大平滑参数差为{scale_result.MaxSmoothingDifference.max():.3g}，最大预测差为{scales.MaxForecastDifference.max():.8f}元，最大相对预测差为{scale_result.MaxForecastRelativePct.max():.4f}%。这说明参数估计基本一致，但预测流程没有完全保持尺度等变。',
('两种尺度基本一致，继续使用原CML方案。' if scale_result.Consistent.all() else f'部分预测差异超过严格诊断阈值，不能笼统称所有结果完全一致。仍保留预先指定原尺度主结果，不按测试误差选择版本。额外采用仅除标准差、以及减均值后除标准差两种变换进行训练内诊断，结果见ets_affine_diagnostic.csv：两种变换还原预测的最大差仅{affine_gap:.8f}元，但都与原尺度存在差异。因此差异不主要来自减均值，也不是明显不同的平滑参数局部最优。MATLAB调用追踪确认预测经过fisET、auxmodelESSS及kfiniet；可读源码显示auxmodelESSS返回空P0，fisET和kfiniet对空P0使用固定1e5单位阵，而非随数据方差一起缩放。由这些证据推断，固定有限初始协方差在不同金额单位下改变初始相对权重，是本次尺度差异的主要机制。modelETS0为P-code，其内部完整控制流不可读，故保留这一解释的推断性质，不改动工具箱初始化来追求测试误差。'),
'标准化只使用当轮训练均值和样本标准差，之后还原预测；它不构成新增预测变量。原尺度与标准化的目标函数绝对大小不可直接比较，尺度变换会按标准差平方改变条件平方和。收敛信息来自优化器文本；接口没有提供数值退出标志，不能仅由有限参数推断收敛。',
'## 参数、估计异常与可复现性',
f'最终正式运行估计耗时{runtime["EstimationSeconds"]:.2f}秒，MATLAB {runtime["MATLAB"]}。远端Ariel提交为`{provenance["ets_commit"]}`。必要ETS调用已选择性提取并去除G盘路径，本地ECOTOOL工具箱复用，不复制大型数据或工具箱。',
f'UC共{len(par[par.Model.str.startswith("UC")])}次估计，退出标志≤0的主结果有{int((par.loc[par.Model.str.startswith("UC"),"ExitFlag"]<=0).sum())}次，靠近方差边界的主结果有{int(par.loc[par.Model.str.startswith("UC"),"NearBoundary"].astype(bool).sum())}次。边界与参数协方差不可精确计算提示可识别性限制，不能据此删除大额消费或调参追求更低测试误差。各起点是否缺少协方差及退出标志见每位成员UC多起点.csv；MATLAB警告见matlab.log。',
'逐轮参数及方差见[all_parameters.csv](all_parameters.csv)，ETS level为α、slope为β，完整原始与标准化估计表和优化过程保存在各成员目录。UC Parameters是标准化对数方差，VarianceYuan2依次为RW的水平/观测方差或LLT的水平/斜率/观测方差。ARIMA参数为窗口均值，VarianceYuan2为高斯MLE残差方差。',
'独立Python核验了全部120条预测的训练边界、真实金额、误差和MASE分母、60条均值/动态参数记录数量、24组尺度核验数量、同原点第109周一致性及UC固定原点与已有结果一致性，并从原始来源重算112周金额。报告与CSV由同一份未经四舍五入的预测生成。',
'复现：在项目根目录执行`matlab -batch "addpath(\'rolling_final4\'); run_final4"`，随后执行`python rolling_final4/summarize_verify.py`。ECOTOOL依赖内部结果控件，适配函数保留隐藏控件并禁止显示或激活；计算与绘图均在后台完成。初次正式计算耗时74.53秒；为满足无弹窗要求，第一次纯文本替代因P-code依赖控件而失败，随后改用隐藏控件并成功重算。最终正式估计及额外尺度诊断均未运行旧回测。源代码哈希与数据版本见[provenance.json](provenance.json)。']
(OUT/'中文实验分析报告.md').write_text('\n\n'.join(report)+'\n',encoding='utf-8')
receipt=dict(PredictionRows=len(p),ParameterRows=len(par),ScaleChecks=len(scales),CanonicalSourceReconciliation='ABC each 112 weeks passed',FixedUCComparison='all 24 values matched existing latest UC outputs',Metrics='recomputed from unrounded predictions',FirstTarget='2026-09-28',LastTargetWeekEnd='2026-10-25')
(OUT/'verification.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(md(pd.DataFrame(best)));print('Scale checks:',int(scale_result.Consistent.sum()),'/24; maximum forecast difference',scales.MaxForecastDifference.max());print('VERIFIED')
