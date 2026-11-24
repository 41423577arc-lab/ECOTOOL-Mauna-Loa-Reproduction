"""Freeze existing inputs; does not train models or change prior experiments."""
from pathlib import Path
import hashlib, json, os, subprocess
from datetime import datetime

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=HERE/'results'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8').strip()

def prepare():
    OUT.mkdir(exist_ok=True)
    dest=OUT/'provenance.json'
    assert not dest.exists(),'Existing manifest found; do not silently replace its input snapshot.'
    formal=json.loads((ROOT/'rolling_final4/results/comparison/provenance.json').read_text(encoding='utf-8'))
    toolbox=Path(os.environ.get('ECOTOOL_PATH') or Path(os.environ['APPDATA'])/'MathWorks/MATLAB Add-Ons/Toolboxes/ECOTOOL').resolve()
    for name,h in formal['data'].items():assert sha(ROOT/'data'/name)==h
    for name,h in formal['ecotool_dependencies_sha256'].items():assert sha(toolbox/name)==h
    assert sha(ROOT/formal['uc_source'])==formal['uc_source_sha256']
    protected={}
    for folder in ['data','raw_data','rolling_final4','experiments/uc_ssm_rebuild','experiments/prediction_consistency_audit','output']:
        for p in (ROOT/folder).rglob('*'):
            if p.is_file():protected[p.relative_to(ROOT).as_posix()]=sha(p)
    toolhash={p.name:sha(p) for p in toolbox.iterdir() if p.is_file() and (p.suffix.lower() in ['.m','.p'] or p.name=='testguiSETTINGS.mat')}
    toolmanifest=hashlib.sha256(json.dumps(toolhash,sort_keys=True).encode()).hexdigest()
    local_sources=['run_ets_30.m','prepare_provenance.py','assemble_verify.py']
    manifest=dict(CreatedAt=datetime.now().astimezone().isoformat(),LocalHEAD=git('rev-parse','HEAD'),Branch=git('branch','--show-current'),
        ArielCommit=git('rev-parse','origin/Ariel'),FormalETSCommit=formal['ets_commit'],ECOTOOLPath=str(toolbox),
        DataSHA256=formal['data'],UCSourceSHA256=formal['uc_source_sha256'],
        ReusedETSSourceSHA256={name:sha(ROOT/'rolling_final4/src/ets'/name) for name in ['fit_ets_final4.m','textoutputWINDOW.m']},
        NewCodeSHA256={name:sha(HERE/name) for name in local_sources},ECOTOOLDependenciesSHA256=toolhash,
        ECOTOOLManifestSHA256=toolmanifest,ProtectedOriginalFilesSHA256=protected,
        Protocol={'Origins':list(range(78,108)),'Targets':list(range(79,109)),'Horizon':1,'FitCount':180,'Transformation':'none','OutlierRemoval':False,'NegativeForecastTruncation':False})
    dest.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Frozen',len(protected),'original files;',len(toolhash),'ECOTOOL dependencies.')

if __name__=='__main__':prepare()
