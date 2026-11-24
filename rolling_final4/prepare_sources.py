"""Select remote ETS calls and unchanged local UC estimation helpers."""
from pathlib import Path
import subprocess, hashlib, json, os
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'rolling_final4'
for d in ['src/ets','src/uc','src/arima','results/A','results/B','results/C','results/comparison']:
    (BASE/d).mkdir(parents=True, exist_ok=True)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
remote = subprocess.check_output(['git','rev-parse','origin/Ariel'],cwd=ROOT,text=True).strip()
refs={}
for name in ['A_case_ets_aligned.m','B_case_ets.m','C_case_ets.m']:
    path='src/单人测试（无异常值处理）/'+name
    raw=subprocess.check_output(['git','show',remote+':'+path],cwd=ROOT)
    refs[path]=hashlib.sha256(raw).hexdigest()
    assert b"modelETS(tr, [], 'NN', 5, 'CML')" in raw
    assert b"modelETS(tr, [], 'AN', 5, 'CML')" in raw
src=ROOT/'experiments/uc_ssm_rebuild/run_uc_ssm.m'
text=src.read_text(encoding='utf-8')
def section(a,b): return text[text.index(a):text.index(b)]
helpers=section('function fitted = fitUC(', 'function row = predictionRow(')
helpers+=section('function row = trialRecord(', 'function t = addStartContext(')
(BASE/'src/uc/fit_uc_final4.m').write_text('function [f,p] = fit_uc_final4(y,model,H)\ncfg=experimentConfig();\nf=fitUC(y,model,cfg);\n[p,~]=forecastUC(f,H);\nend\n'+section('function cfg = experimentConfig()', 'function runPerson(')+helpers,encoding='utf-8')
(BASE/'src/arima/fit_mean_final4.m').write_text('function [p,mu,v] = fit_mean_final4(y,H)\n% ARIMA(0,0,0) with estimated constant: training-window mean.\ny=double(y(:)); mu=mean(y); v=mean((y-mu).^2); p=repmat(mu,H,1);\nend\n',encoding='utf-8')
manifest={'ets_commit':remote,'ets_source_sha256':refs,'uc_source_sha256':sha(src),'uc_source':'experiments/uc_ssm_rebuild/run_uc_ssm.m','branch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),'data':{p.name:sha(p) for p in (ROOT/'data').glob('*.xlsx')}}
(BASE/'results/comparison/provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(manifest,ensure_ascii=True,indent=2))
