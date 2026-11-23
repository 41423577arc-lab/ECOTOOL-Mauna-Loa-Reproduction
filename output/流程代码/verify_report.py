"""Independent arithmetic, document identity and diagram coverage checks."""
from pathlib import Path
import csv,json,math,re,zipfile,argparse
from docx import Document
import openpyxl
root=Path(__file__).resolve().parents[2];out=root/'output'
def read(name):
 with (out/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def close(a,b):return math.isclose(float(a),float(b),rel_tol=1e-9,abs_tol=1e-7)
metrics=read('报告四模型性能汇总.csv');forecast=read('报告四模型固定原点预测.csv');totals=read('报告四模型累计预测.csv')
assert len(metrics)==24 and len(forecast)==48 and len(totals)==12
for person in ['A','B','C']:
 wb=openpyxl.load_workbook(root/'data'/f'{person}_个人总支付_自然周.xlsx',data_only=True)
 values=[r[1] for r in list(wb.active.values)[1:]]
 scale=sum(abs(values[i]-values[i-1]) for i in range(1,108))/107
 for model in ['RW','LLT','朴素','三期移动平均']:
  detail=[r for r in forecast if r['Person']==person and r['Model']==model];assert len(detail)==4
  pred=[float(r['Forecast']) for r in detail];actual=values[108:]
  assert all(close(r['Actual'],y) for r,y in zip(detail,actual))
  if model=='朴素':assert all(close(p,values[107]) for p in pred)
  if model=='三期移动平均':
   h=values[:108]
   for v in pred:
    assert close(v,sum(h[-3:])/3)
    h.append(v)
  original=read(person+'/UC最终预测结果.csv')
  if model==original[0]['Model']:
   assert all(close(p,r['Forecast']) for p,r in zip(pred,original))
  errors=[p-a for p,a in zip(pred,actual)];mae=sum(map(abs,errors))/4
  m=next(r for r in metrics if r['Person']==person and r['Model']==model and r['Stage']=='测试4期')
  assert close(m['MAE'],mae) and close(m['RMSE'],math.sqrt(sum(e*e for e in errors)/4))
  sm=sum(200*abs(p-a)/(abs(p)+abs(a)) if abs(p)+abs(a) else 0 for p,a in zip(pred,actual))/4
  assert close(m['sMAPE'],sm) and close(m['MASE'],mae/scale)
  t=next(r for r in totals if r['Person']==person and r['Model']==model)
  assert close(t['ForecastSum'],sum(pred)) and close(t['ActualSum'],sum(actual))
  assert close(t['ErrorSum'],sum(errors)) and close(t['RelativeError'],sum(errors)/sum(actual))
md=(out/'UC分析流程简述.md').read_text(encoding='utf8')
blocks=re.findall(r'```mermaid\s*(.*?)```',md,re.S)
assert len(blocks)==5 and blocks[0].startswith('sequenceDiagram')
assert all(b.startswith('flowchart TD') for b in blocks[1:])
assert all('classDef common fill:#F1F5F9,stroke:#64748B,color:#0F172A' in b for b in blocks[1:])
for color in ['#DBEAFE','#EDE9FE','#FFEDD5','#D1FAE5']:assert color in md
assert 'output（2）' not in (root/'run_all_uc.m').read_text(encoding='utf8')
assert not (root/'output（2）').exists()
parser=argparse.ArgumentParser(description='核对报告数值和流程图；可选核对Word参考模板。')
parser.add_argument('--template',type=Path)
args=parser.parse_args()
reference=args.template
docx=out/'A_B_C成员周消费_UC与基准预测报告.docx'
b=Document(docx)
assert len(b.sections)==1
if reference is not None:
 a=Document(reference)
 assert len(a.sections)==1
 for k in ['page_width','page_height','top_margin','bottom_margin','left_margin','right_margin']:
  assert getattr(a.sections[0],k)==getattr(b.sections[0],k)
assert len(b.inline_shapes)==10
text='\n'.join(p.text for p in b.paragraphs)
assert all('成员'+p in text for p in ['A','B','C']) and 'AutoARIMA' not in text and 'Jarque–Bera检验' in text
assert '60条' in text and '11张表' in text
assert all(c.text for t in b.tables for row in t.rows for c in row.cells)
preserved=None
if reference is not None:
 with zipfile.ZipFile(reference) as old,zipfile.ZipFile(docx) as new:
  preserved={p:old.read(p)==new.read(p) for p in ['word/styles.xml','word/numbering.xml','word/theme/theme1.xml']}
  assert all(preserved.values()),preserved
result=json.loads((out/'报告核验.json').read_text(encoding='utf8')) if (out/'报告核验.json').exists() else {}
result.update({'supplementary_metric_rows_checked':24,'supplementary_fixed_forecast_rows':48,'mermaid_sequence_count':1,'mermaid_model_flow_count':4,'shared_module_colors_consistent':True,'output_renamed':True,'reference_template_checked_this_run':reference is not None,'document_figures':10,'all_checks_passed':True})
if preserved is not None:result['reference_layout_and_style_parts_preserved']=preserved
(out/'报告核验.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(result,ensure_ascii=False,indent=2))
