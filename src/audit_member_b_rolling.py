"""Independent CSV audit of member B rolling results (standard library only)."""
import csv, math, json
from pathlib import Path
from collections import defaultdict
root=Path(__file__).resolve().parents[1]
p=root/'results'/'rolling_b'
rows=list(csv.DictReader((p/'predictions.csv').open(encoding='utf-8-sig')))
metrics=list(csv.DictReader((p/'metrics_by_horizon.csv').open(encoding='utf-8-sig')))
assert len(rows)==10560 and len(metrics)==48
by=defaultdict(list)
for r in rows:
    a,b=float(r['actual']),float(r['predicted'])
    assert math.isfinite(a) and math.isfinite(b) and 200<b<600
    n,h=int(r['round']),int(r['horizon'])
    assert 1<=n<=220 and 1<=h<=24
    oy,om=map(int,r['forecast_origin'][:7].split('-'))
    ty,tm=map(int,r['target_month'][:7].split('-'))
    assert (ty-oy)*12+tm-om==h
    by[r['model'],h].append((n,a,b))
for key,vs in by.items():
    assert sorted(v[0] for v in vs)==list(range(1,221))
for m in metrics:
    vs=by[m['model'],int(m['horizon'])]
    sm=sum(200*abs(a-b)/(abs(a)+abs(b)) for _,a,b in vs)/220
    assert abs(sm-float(m['sMAPE_percent']))<1e-10
# Both models must use identical targets and actuals at every origin/horizon.
assert [(r['round'],r['horizon'],r['actual']) for r in rows[:5280]]==[(r['round'],r['horizon'],r['actual']) for r in rows[5280:]]
report={'passed':True,'prediction_rows':len(rows),'metric_rows':len(metrics),'models':sorted({r['model'] for r in rows}),'rounds_per_model':220,'horizons':24,'checks':['dates','finite predictions','complete unique origin/horizon coverage','independent sMAPE recomputation','shared actuals']}
(p/'audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
