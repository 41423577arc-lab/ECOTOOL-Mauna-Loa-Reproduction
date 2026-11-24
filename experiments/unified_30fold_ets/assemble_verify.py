"""Reuse 270 existing records, audit 180 new ETS records, and export 450 rows.

No model estimation or significance test is performed by this script.
"""
from pathlib import Path
import hashlib, io, json, re, subprocess
import numpy as np
import pandas as pd
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=HERE/'results'
MODELS=['ARIMA(0,0,0)','ETS-NN','ETS-AN','UC-RW','UC-LLT']
plt.rcParams.update({'font.family':'Microsoft YaHei','axes.unicode_minus':False,'font.size':10})
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return pd.read_csv(p,encoding='utf-8-sig')
def write(df,name):df.to_csv(OUT/name,index=False,encoding='utf-8-sig',float_format='%.15g')
def close(a,b):np.testing.assert_allclose(np.asarray(a,float),np.asarray(b,float),rtol=1e-9,atol=1e-7)
def prefix_hash(d,y):return hashlib.sha256('\n'.join(f'{a:%Y-%m-%d},{b:.17g}' for a,b in zip(d,y)).encode()).hexdigest()
def scores(z):
    e=z.Forecast.to_numpy()-z.Actual.to_numpy();den=abs(z.Forecast.to_numpy())+abs(z.Actual.to_numpy())
    sm=np.divide(200*abs(e),den,out=np.zeros_like(e),where=den!=0)
    return dict(N=len(z),MAE=float(np.mean(abs(e))),RMSE=float(np.sqrt(np.mean(e**2))),sMAPE=float(sm.mean()),MASE=float(np.mean(abs(e)/z.MASEScale.to_numpy())))
def md(df):
    def f(x):
        if isinstance(x,(float,np.floating)):return f'{x:,.4f}'
        return str(x)
    return '\n'.join(['| '+' | '.join(df.columns)+' |','| '+' | '.join(['---']*len(df.columns))+' |']+['| '+' | '.join(f(v) for v in row)+' |' for row in df.itertuples(index=False,name=None)])
def manifest_check(m):
    for name,h in m['ProtectedOriginalFilesSHA256'].items():assert sha(ROOT/name)==h,('Protected input changed',name)
    for name,h in m['ECOTOOLDependenciesSHA256'].items():assert sha(Path(m['ECOTOOLPath'])/name)==h
    for name,h in m['NewCodeSHA256'].items():assert sha(HERE/name)==h
    for name,h in m['ReusedETSSourceSHA256'].items():assert sha(ROOT/'rolling_final4/src/ets'/name)==h

def main():
    manifest=json.loads((OUT/'provenance.json').read_text(encoding='utf-8'));manifest_check(manifest)
    runtime=json.loads((OUT/'ets_runtime.json').read_text(encoding='utf-8'));assert runtime['FitCount']==180
    data={};dates={};audits=[];combined=[];ucfits=0
    for person in 'ABC':
        file=ROOT/'data'/f'{person}_个人总支付_自然周.xlsx';assert sha(file)==manifest['DataSHA256'][file.name]
        t=pd.read_excel(file,sheet_name='UC数据');d=pd.to_datetime(t.iloc[:,0]);y=t.iloc[:,1].to_numpy(float)
        assert len(y)==112 and np.isfinite(y).all() and (y>=0).all()
        # Count rows, not matrix elements. Repeated amounts on different dates are valid.
        duplicate_dates=len(d)-d.nunique();duplicate_rows=len(t)-len(t.drop_duplicates())
        assert duplicate_dates==duplicate_rows==0 and d.tolist()==pd.date_range('2024-09-02',periods=112,freq='7D').tolist()
        data[person]=y;dates[person]=d
        folder=ROOT/'experiments/uc_ssm_rebuild/results'/person
        with h5py.File(folder/'完整实验结果.mat','r') as f:
            np.testing.assert_array_equal(f['result/yTrain'][()].ravel(),y[:108])
            np.testing.assert_array_equal(f['result/cfg/oneStepOrigins'][()].ravel(),np.arange(78,108))
        path=folder/'30折滚动一步预测.csv';old=read(path);assert len(old)==90
        fits=read(folder/'优化收敛与似然记录.csv');fits=fits[fits.OriginWeek<108];assert len(fits)==60 and (fits.ExitFlag>0).all();ucfits+=len(fits)
        variances=read(folder/'各原点估计参数.csv')
        for r in variances.itertuples():close(r.VarianceYuan2,np.exp(r.LogVarianceStandardized)*y[:r.OriginWeek].std(ddof=1)**2)
        legacy_metadata=read(folder/'数据核验.csv')
        audits.append(dict(Person=person,Weeks=112,TrainingWeeks=108,DuplicateDates=duplicate_dates,DuplicateRows=duplicate_rows,LegacyDuplicateWeekField=int(legacy_metadata['训练重复周记录数'].iloc[0]),SSMFull108MaxDifference=0,DataSHA256=sha(file)))
        for r in old.itertuples():
            assert r.Model in ['RW','LLT','历史均值']
            canonical={'RW':'UC-RW','LLT':'UC-LLT','历史均值':'ARIMA(0,0,0)'}[r.Model]
            if r.Model=='历史均值':close(r.Forecast,y[:r.OriginWeek].mean())
            combined.append(dict(Person=person,OriginalModel=r.Model,Model=canonical,OriginWeek=r.OriginWeek,TargetWeek=r.TargetWeek,OriginDate=r.OriginDate,TargetDate=r.TargetDate,Actual=r.Actual,Forecast=r.Forecast,Error=r.Error,MASEScale=float(np.mean(abs(np.diff(y[:r.OriginWeek])))),DataSHA256=sha(file),TrainingPrefixSHA256=prefix_hash(d[:r.OriginWeek],y[:r.OriginWeek]),SourcePath=path.relative_to(ROOT).as_posix(),SourceSHA256=sha(path),SourceVersion='uc_ssm_source:'+manifest['UCSourceSHA256'],EstimationMethod='window_mean_equivalent_ARIMA000' if r.Model=='历史均值' else 'MATLAB_SSM_standardized_ML_3starts'))
    new=read(OUT/'ets_predictions.csv');params=read(OUT/'ets_parameters.csv')
    assert len(new)==len(params)==180 and not params.duplicated(['Person','Model','OriginWeek']).any()
    assert all(params.SampleN==params.OriginWeek)
    for r in params.itertuples():
        tr=data[r.Person][:r.OriginWeek];close(r.TrainMean,tr.mean());close(r.TrainSD,tr.std(ddof=1));close(r.MASEScale,np.mean(abs(np.diff(tr))))
        v=np.fromstring(r.ParameterVector.strip('[]'),sep=' ');assert np.isfinite(v).all();close(r.Alpha,v[0])
        if r.Model=='ETS-AN':assert len(v)==2;close(r.Beta,v[1])
        else:assert len(v)==1 and pd.isna(r.Beta)
    log=(OUT/'ets_optimizer.log').read_text(encoding='utf-8')
    calls=re.findall(r'^=== ([ABC]) (ETS-(?:NN|AN)) origin=(\d+) target=(\d+) elapsed=',log,re.M)
    assert len(calls)==180 and len(set(calls))==180
    for r in new.itertuples():
        assert (r.Person,r.Model,str(r.OriginWeek),str(r.TargetWeek)) in calls
        y=data[r.Person];d=dates[r.Person];file=ROOT/'data'/f'{r.Person}_个人总支付_自然周.xlsx'
        combined.append(dict(Person=r.Person,OriginalModel=r.Model,Model=r.Model,OriginWeek=r.OriginWeek,TargetWeek=r.TargetWeek,OriginDate=r.OriginDate,TargetDate=r.TargetDate,Actual=r.Actual,Forecast=r.Forecast,Error=r.Error,MASEScale=r.MASEScale,DataSHA256=sha(file),TrainingPrefixSHA256=prefix_hash(d[:r.OriginWeek],y[:r.OriginWeek]),SourcePath=(OUT/'ets_predictions.csv').relative_to(ROOT).as_posix(),SourceSHA256=sha(OUT/'ets_predictions.csv'),SourceVersion='ets_runner:'+manifest['NewCodeSHA256']['run_ets_30.m']+';ecotool:'+manifest['ECOTOOLManifestSHA256'],EstimationMethod='ECOTOOL_CML_raw_scale'))
    unified=pd.DataFrame(combined).sort_values(['Person','Model','OriginWeek']).reset_index(drop=True)
    assert len(unified)==450 and not unified.duplicated(['Person','Model','OriginWeek']).any()
    assert np.isfinite(unified[['Forecast','Actual','Error','MASEScale']].to_numpy(float)).all()
    for r in unified.itertuples():
        n=r.OriginWeek;y=data[r.Person];d=dates[r.Person]
        assert 78<=n<=107 and r.TargetWeek==n+1<=108
        assert pd.Timestamp(r.OriginDate)==d.iloc[n-1] and pd.Timestamp(r.TargetDate)==d.iloc[n]
        close(r.Actual,y[n]);close(r.Error,r.Forecast-r.Actual);close(r.MASEScale,np.mean(abs(np.diff(y[:n]))))
        assert r.TrainingPrefixSHA256==prefix_hash(d[:n],y[:n])
    grouped=[]
    for person in 'ABC':
        for model in MODELS:
            z=unified[(unified.Person==person)&(unified.Model==model)];assert len(z)==30 and z.OriginWeek.tolist()==list(range(78,108))
            grouped.append(dict(Person=person,Model=model,**scores(z)))
    metrics=pd.DataFrame(grouped)
    deltas=[];oldmetrics=[]
    for person in 'ABC':
        path=f'results/tables/{person}_weeks_test/{person}_rolling_predictions.csv'
        blob=subprocess.check_output(['git','show',manifest['ArielCommit']+':'+path],cwd=ROOT)
        old=pd.read_csv(io.BytesIO(blob));assert len(old)==30 and old.k.tolist()==list(range(78,108))
        close(old.actual,data[person][78:108])
        for model,col in [('ETS-NN','ETS_NN'),('ETS-AN','ETS_AN')]:
            z=unified[(unified.Person==person)&(unified.Model==model)].sort_values('OriginWeek')
            oz=z.copy();oz['Forecast']=old[col].to_numpy();oz['Error']=oz.Forecast-oz.Actual
            os=scores(oz);ns=scores(z)
            oldmetrics.append(dict(Person=person,Model=model,**{'Ariel'+k:v for k,v in os.items()},**{'Unified'+k:v for k,v in ns.items()},MaxAbsForecastDifference=float(max(abs(z.Forecast.to_numpy()-old[col].to_numpy()))),MeanAbsForecastDifference=float(np.mean(abs(z.Forecast.to_numpy()-old[col].to_numpy())))))
            for r,previous in zip(z.itertuples(),old[col]):deltas.append(dict(Person=person,Model=model,OriginWeek=r.OriginWeek,TargetWeek=r.TargetWeek,TargetDate=r.TargetDate,Actual=r.Actual,ArielForecast=previous,UnifiedForecast=r.Forecast,ForecastDifference=r.Forecast-previous,ArielError=previous-r.Actual,UnifiedError=r.Error))
    comparison=pd.DataFrame(oldmetrics)
    # Compare member-internal rankings with the same accepted baselines on both sides.
    rankings=[]
    for person in 'ABC':
        u=metrics[metrics.Person==person].copy();o=u.copy()
        for model in ['ETS-NN','ETS-AN']:
            c=comparison[(comparison.Person==person)&(comparison.Model==model)].iloc[0]
            for metric in ['MAE','RMSE','sMAPE','MASE']:o.loc[o.Model==model,metric]=c['Ariel'+metric]
        rankings.append(dict(Person=person,OldETSWithinUnifiedPeersBestMAE=o.sort_values(['MAE','RMSE']).iloc[0].Model,UnifiedBestMAE=u.sort_values(['MAE','RMSE']).iloc[0].Model,OldETSFamilyBestMAE=o[o.Model.str.startswith('ETS')].sort_values('MAE').iloc[0].Model,UnifiedETSFamilyBestMAE=u[u.Model.str.startswith('ETS')].sort_values('MAE').iloc[0].Model))
    findings=[]
    for rank in rankings:
        person=rank['Person'];z=metrics[metrics.Person==person].set_index('Model')
        best=rank['UnifiedBestMAE'];baseline=z.loc['ARIMA(0,0,0)','MAE']
        changed='发生变化' if rank['OldETSWithinUnifiedPeersBestMAE']!=best else '未变'
        family='发生变化' if rank['OldETSFamilyBestMAE']!=rank['UnifiedETSFamilyBestMAE'] else '未变'
        findings.append(f'成员{person}：统一后MAE最佳为{best}（{z.loc[best,"MAE"]:.2f}元/周），历史均值MAE为{baseline:.2f}元/周。替换ETS前后五模型最佳{changed}，ETS家族内部最佳{family}。')
    # Check existing final-four records only through protected hashes; never rewrite/retrain.
    manifest_check(manifest)
    write(unified,'unified_predictions_450.csv');write(metrics,'metrics_15.csv');write(params,'ets_parameters.csv')
    write(pd.DataFrame(deltas),'ets_vs_ariel_180.csv');write(comparison,'ets_vs_ariel_summary.csv')
    for person in 'ABC':
        z=unified[unified.Person==person]
        fig,ax=plt.subplots(figsize=(11,5.4),layout='constrained');actual=z[z.Model==MODELS[0]].sort_values('TargetWeek')
        x=pd.to_datetime(actual.TargetDate);ax.plot(x,actual.Actual,'k-o',markersize=3,lw=1.6,label='真实消费')
        for model,style in [('ETS-NN','--s'),('ETS-AN','-.^')]:
            q=z[z.Model==model].sort_values('TargetWeek');ax.plot(x,q.Forecast,style,markersize=3,lw=1.4,label=model)
        ax.set(title=f'成员{person}：训练期30折滚动一步回测（ETS）',ylabel='个人周消费（元）',xlabel='预测目标周起始日：2026-03-02—09-21')
        ax.legend(ncol=3,loc='upper center',bbox_to_anchor=(.5,-.16));ax.grid(alpha=.2)
        fig.savefig(OUT/f'{person}_ets_30fold.png',dpi=160);plt.close(fig)
        fig,axes=plt.subplots(2,2,figsize=(11,7),layout='constrained');mm=metrics[metrics.Person==person].set_index('Model').loc[MODELS]
        for ax,metric,unit in zip(axes.flat,['MAE','RMSE','sMAPE','MASE'],['元/周','元/周','%','无量纲']):
            bars=ax.bar(range(5),mm[metric],color=['#777777','#e68624','#377eb8','#5b49a7','#2b956a'])
            ax.set_xticks(range(5),['ARIMA\n(0,0,0)','ETS-NN','ETS-AN','UC-RW','UC-LLT']);ax.set_title(metric);ax.set_ylabel(unit);ax.set_ylim(0,float(mm[metric].max())*1.2)
            ax.bar_label(bars,fmt='%.2f',fontsize=8,padding=3);ax.grid(axis='y',alpha=.15);ax.set_axisbelow(True)
        fig.suptitle(f'成员{person}：训练期30折滚动一步回测｜五模型性能比较',fontsize=14)
        fig.savefig(OUT/f'{person}_five_models_30fold.png',dpi=160);plt.close(fig)
    # Independent scalar arithmetic, using exported numbers, not the vectorized scores helper.
    exported=read(OUT/'unified_predictions_450.csv');savedmetrics=read(OUT/'metrics_15.csv');max_delta=0.
    for row in savedmetrics.itertuples():
        z=exported[(exported.Person==row.Person)&(exported.Model==row.Model)]
        errors=[float(r.Forecast)-float(r.Actual) for r in z.itertuples()]
        values={'MAE':sum(abs(e) for e in errors)/30,'RMSE':(sum(e*e for e in errors)/30)**.5,'sMAPE':sum(200*abs(r.Forecast-r.Actual)/(abs(r.Forecast)+abs(r.Actual)) if abs(r.Forecast)+abs(r.Actual) else 0 for r in z.itertuples())/30,'MASE':sum(abs(r.Forecast-r.Actual)/r.MASEScale for r in z.itertuples())/30}
        for k,v in values.items():close(v,getattr(row,k));max_delta=max(max_delta,abs(v-getattr(row,k)))
    # MATLAB emits padded display tables; trimming whitespace preserves the raw numbers.
    for p in [OUT/'ets_optimizer.log',OUT/'matlab.log']:
        if p.exists():p.write_text('\n'.join(s.rstrip() for s in p.read_text(encoding='utf-8-sig').splitlines()).rstrip()+'\n',encoding='utf-8')
    verification=dict(PredictionRows=450,Groups=15,RecordsPerGroup=30,NewETSFits=180,ReusedSSMUCRows=180,ReusedMeanRows=90,SelectedUCFitExitFlagsPositive=ucfits,
        Origins=[78,107],Targets=[79,108],TargetDates=['2026-03-02','2026-09-21'],Duplicates=0,MissingOrNonfinite=0,MetricsIndependentMaxDifference=max_delta,
        DataAudit=audits,KnownLegacyMetadataError='duplicate week field -108 caused by numel(matrix), corrected independently with row/date counts; original files untouched',
        ExistingFilesUnchanged=len(manifest['ProtectedOriginalFilesSHA256']),FinalFourReestimated=False,UCReestimated=False,MeanReestimated=False,SignificanceTestsExecuted=False)
    (OUT/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report=['# 统一五模型训练期30折滚动一步回测',
        '2026年11月24日｜目标周：2026-03-02—2026-09-21（周末截至09-27）｜每人成员内部比较',
        '## 结论与范围',
        f'已补跑ABC三人的原尺度ETS-NN、ETS-AN，各30折，共180次CML估计，正式估计耗时{runtime["EstimationSeconds"]:.2f}秒。直接复用新版SSM的180条UC预测及90条历史均值预测，得到450条统一明细。每成员每模型30条均通过核验。本轮没有重新运行UC、均值基线、最后四周或任何显著性检验。',
        md(metrics),
        'MAE、RMSE单位为元/周，sMAPE单位为%，MASE无量纲。最佳模型依指标而定，表中排序不构成统计显著性证据。ARIMA(0,0,0)是带估计常数的历史均值等价点预测，原名称“历史均值”保留在明细OriginalModel中，并非声称已获得同学独立ARIMA拟合导出。',
        *findings,
        md(pd.DataFrame(rankings).rename(columns={'Person':'成员','OldETSWithinUnifiedPeersBestMAE':'替换前五模型最佳MAE','UnifiedBestMAE':'统一后五模型最佳MAE','OldETSFamilyBestMAE':'旧ETS家族最佳MAE','UnifiedETSFamilyBestMAE':'新ETS家族最佳MAE'})),
        '旧ETS列仅指将Ariel已有ETS预测放入同一组已通过UC/均值候选后的事后排名，用于隔离ETS更新影响；不冒充当时报告使用的全部旧候选，也不将旧ECOTOOL UC纳入比较。',
        '## 与Ariel原有180条预测逐折比较',md(comparison[['Person','Model','MaxAbsForecastDifference','MeanAbsForecastDifference','ArielMAE','UnifiedMAE','ArielRMSE','UnifiedRMSE']]),
        '全部180个旧目标真实值与正式数据一致。逐折差异详见ets_vs_ariel_180.csv，含两套预测、误差及差值；旧预测指标也用当前正式数据和逐折训练分母重算，并非直接复制旧汇总表。上表与排名共同说明统一版本后ETS家族和五模型内部结论是否改变。远端历史完整训练输入、初始化及工具箱指纹仍未提供，因此不能把差异唯一归因于某一个参数或数据周。本次新增结果具有完整正式输入、代码和依赖哈希，替代旧ETS作为后续统一检验来源。',
        '## 数据、模型和泄漏控制',
        '规范输入仍为根目录data/ABC_个人总支付_自然周.xlsx，逐文件SHA256与rolling_final4正式来源一致，且三人的新版UC保存108周训练快照逐值相同。每轮输入仅为前1—n周，n=78—107；目标为n+1，目标值只用于评分，不传入估计。ETS入口只读前108周，不读取最后四周金额。每轮重新调用modelETS(tr,[],NN/AN,1,CML)，使用训练原尺度；无异常删除、季节项、外生项、阻尼趋势或负预测截断。',
        'ETS直接复用rolling_final4/src/ets/fit_ets_final4.m和隐藏窗口适配，默认估计/状态初始化沿用同一ECOTOOL二进制及可读依赖；没有复制数据或工具箱。逐折Alpha、Beta、参数向量、训练均值/样本标准差（仅记录、不用于变换）、优化文本状态、警告及耗时见ets_parameters.csv；完整180折优化文本集中保存在ets_optimizer.log。接口不提供数值退出码，ExitCodeFromText仅来自优化器消息标识，不把有限预测当作已收敛证明。',
        f'逐折文本状态分布：{params.OptimizationStatus.value_counts().to_dict()}。未识别消息标识数：{int(params.ExitCodeFromText.isna().sum())}；负预测数：{int((new.Forecast<0).sum())}，全部按原值保留。',
        'SSM与均值记录仅来自experiments/uc_ssm_rebuild/results/ABC/30折滚动一步预测.csv；源文件哈希、原名称、规范名称、来源路径、代码版本、数据版本、训练前缀哈希逐条保留。UC使用当轮标准化、三起点优化及预测/方差还原方法；已核验其原点参数台账和正退出标志，未混入output旧ECOTOOL UC或缩尾、季节实验结果。',
        '## 图表：训练期30折回测',
    ]
    for person in 'ABC':report += [f'### 成员{person}',f'![成员{person} ETS训练期30折](results/{person}_ets_30fold.png)',f'![成员{person}五模型训练期30折](results/{person}_five_models_30fold.png)']
    report += ['## 独立核验与旧字段修正',
        f'全量450条检查成员/模型覆盖、30个唯一原点、OriginWeek+1=TargetWeek、日期、实际金额、误差及训练期MASE分母；全部有限，无缺失和重复。每个成员同一原点五模型的训练前缀哈希一致。再从导出的450条数据，用独立逐条标量公式重算15组指标，与评价表最大差为{max_delta:.3g}。MASE分母为当轮训练mean(abs(diff(y)))，sMAPE为mean(200|e|/(|a|+|f|))、双零计0。',
        md(pd.DataFrame(audits)[['Person','Weeks','DuplicateDates','DuplicateRows','LegacyDuplicateWeekField','SSMFull108MaxDifference']]),
        '旧版数据核验字段−108源于numel对日期金额二维矩阵计算元素数。本轮采用记录行数减唯一日期数，另核查完整记录去重数，均为0；不把相同金额的不同周误判为重复。旧实验文件及上一份核验报告均不修改，新报告明确记录错误及独立计算结果。',
        f'运行前后核对{len(manifest["ProtectedOriginalFilesSHA256"])}个既有数据、结果和源码文件的SHA256，均未改变。最后四周仍只是补充实验，原固定原点预测、最后四周滚动预测、旧十月累计图均保留，未用旧均值图片替代本次统一图表。',
        '## 文件与版本',
        f'起始代码提交：`{manifest["LocalHEAD"]}`；Ariel比较提交：`{manifest["ArielCommit"]}`。新代码及复用代码SHA256、正式输入哈希、ECOTOOL逐文件依赖及总体指纹、全部受保护文件哈希保存在results/provenance.json。MATLAB版本与运行耗时见results/ets_runtime.json。',
        '运行异常：初次尝试在A/ETS-NN/原点78估计完成后，fprintf对MATLAB字符串进行整数格式化时报错，未保存该次参数/预测。修复仅涉及日志类型转换及逐折保存；最终重新运行并保留完整180折，此外有这1次未保留的初始估计尝试。失败消息及修复前后代码哈希保存在provenance.json，未隐瞒额外尝试，也未因此改变估计方法或选择测试误差更低的结果。',
        '统一明细：results/unified_predictions_450.csv；指标表：results/metrics_15.csv；ETS参数：results/ets_parameters.csv；Ariel逐折差异及汇总：results/ets_vs_ariel_180.csv、ets_vs_ariel_summary.csv；独立核验：results/verification.json。',
        '复现顺序（从项目根目录）：python experiments/unified_30fold_ets/prepare_provenance.py；matlab -batch "addpath(\'experiments/unified_30fold_ets\'); run_ets_30"；python experiments/unified_30fold_ets/assemble_verify.py。已完成目录的准备及拟合入口会拒绝重复运行，防止误重复180次估计。核验汇总脚本仅重算本目录表图，不训练模型、不写入原实验。']
    (HERE/'中文实验报告.md').write_text('\n\n'.join(report)+'\n',encoding='utf-8')
    manifest_check(manifest)
    print(metrics.to_string(index=False));print('VERIFIED 450 rows; 180 ETS fits; reused 270; previous files unchanged.')

if __name__=='__main__':main()
