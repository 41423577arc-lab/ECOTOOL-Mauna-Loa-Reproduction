from pathlib import Path
import hashlib, json, shutil, zipfile, csv
from datetime import datetime

root = Path(__file__).resolve().parent.parent
repo = root / 'work/github_upload_member_b_20261122'
dest = repo / 'backups/consumption_research_20261124'
dest.mkdir(parents=True, exist_ok=True)
excluded = {'forecast_deps', 'github_upload_member_b_20261122', '__pycache__', 'paper-matlab-prefs', '.git'}
records = []

def copy_file(source, relative):
    target = dest / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    assert original == hashlib.sha256(target.read_bytes()).hexdigest()
    records.append({'path': relative.as_posix(), 'bytes': target.stat().st_size, 'sha256': original, 'source': str(source)})

for folder in ['outputs', 'work']:
    for source in sorted((root / folder).rglob('*')):
        relative = source.relative_to(root)
        if any(p in excluded for p in relative.parts) or not source.is_file():
            continue
        if source.suffix.lower() in {'.pyc', '.pem', '.key'} or source.name.startswith('.env'):
            continue
        copy_file(source, relative)

desktop = Path.home() / 'Desktop'
for name in ['成员A_周.csv', 'B.csv', 'C.xlsx']:
    source = desktop / name
    if source.is_file(): copy_file(source, Path('source_attachments') / name)

temp = Path.home() / 'AppData/Local/Temp'
for folder in temp.glob('codex-file-preview-*'):
    for source in folder.iterdir():
        if source.is_file() and (source.name.startswith('支付宝交易明细(') or source.name.startswith('微信支付账单流水文件(')):
            copy_file(source, Path('original_bills/temp_sources') / folder.name / source.name)
bill_root = Path('D:/电脑管家迁移文件/xwechat_files/wxid_a1rf8kib9lsh22_0945/msg/file/2026-11')
if bill_root.is_dir():
    for source in bill_root.iterdir():
        if source.is_file() and (source.name.startswith('支付宝交易明细(') or source.name.startswith('微信支付账单流水文件(')):
            copy_file(source, Path('original_bills/wechat_files') / source.name)

toolbox = desktop / '大三上/文本分析/文本分析报告/ECOTOOL-unpacked/fsroot'
if toolbox.is_dir():
    for source in toolbox.rglob('*'):
        if source.is_file(): copy_file(source, Path('runtime_reference/ECOTOOL') / source.relative_to(toolbox))

notes = '''消费预测研究完整备份（2026-11-24）

本备份包含：本聊天工作区全部 outputs 成果、work 数据快照/清洗记录/脚本/模型/日志/报告渲染，以及找到的相关原始账单、桌面三份附件和 ECOTOOL 代码参考。
不包含：可重新安装的 forecast_deps、Python缓存、MATLAB个人设置、Git克隆自身；不代表整个C盘或其他项目已备份。

最新有效版本：
1. outputs/ABC周消费_ARIMA_修正版_20261122：三人112完整自然周数据、AutoARIMA及Naive/历史均值结果、诊断、Word报告、复现脚本。
2. outputs/ABC_原序列自相关检验与均值基线_20261123：Ljung-Box检验、ACF、均值基线结果和代码。
3. outputs/ABC_均值基线拟合图_每人三张_20261123：每人训练拟合、滚动预测、四周预测共九张及总览、明细。
4. work/abc_corrected_20261122：当前A.csv、B.xlsx、C.xlsx来源快照和模型对象。

身份口径：A为成员A_周.csv，112周64470.55元；B为已核验B.xlsx合并消费明细按净消费汇总，114959.44元；C为C.xlsx的03_周期统计个人总支付，88773.97元。
历史旧A.csv实际是B的周汇总，早期结果保留供追溯，不可当作当前A结果。桌面B.csv是退款前金额，不是当前净消费建模输入。
范围2024-09-02至2026-10-25；周起始日最后为2026-10-19。训练108周，滚动30折，最终独立测试4周。

恢复方法：下载仓库ZIP或git clone后保留本目录。outputs和work相对位置不变。先用现成CSV、报告和图表查看；要重跑模型需自行安装MATLAB及Python依赖（包括openpyxl、python-docx等）。
ECOTOOL路径通过环境变量CONSUMPTION_ECOTOOL指向本目录runtime_reference/ECOTOOL，再运行输出目录中可独立调用的run_corrected_abc.m；均值基线不需要ECOTOOL。
旧脚本中的原机器绝对路径需要改到本备份位置，历史版本运行环境不保证自动恢复。MAT文件保存了当时模型状态。

SHA256_MANIFEST.csv列出每个复制文件的大小、SHA256及来源，复制后已逐一校验。
另有完整ZIP供一次下载。仅在已下载并验证所需备份后清理本地文件。
'''
(dest / '备份说明与恢复方法.txt').write_text(notes, encoding='utf-8-sig')
with (dest / 'SHA256_MANIFEST.csv').open('w', encoding='utf-8-sig', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=['path', 'bytes', 'sha256', 'source'])
    writer.writeheader(); writer.writerows(records)
largest = max(records, key=lambda r:r['bytes'])
assert largest['bytes'] < 95*1024*1024, largest
archive = repo / 'backups/consumption_research_20261124_complete.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    for source in sorted(dest.rglob('*')):
        if source.is_file(): z.write(source, source.relative_to(dest.parent))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
assert archive.stat().st_size < 95*1024*1024
summary = {'files_copied_and_verified':len(records), 'bytes_copied':sum(r['bytes'] for r in records), 'zip_bytes':archive.stat().st_size, 'zip_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(), 'backup':str(dest)}
(repo/'backups/backup_verification_20261124.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
