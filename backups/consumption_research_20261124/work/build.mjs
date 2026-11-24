import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const requireBundle = createRequire(path.join(process.argv[2], 'artifact-loader.cjs'));
const { Workbook, SpreadsheetFile } = await import(pathToFileURL(requireBundle.resolve('@oai/artifact-tool')).href);
const merged = process.argv[4] === 'merged';
const data = JSON.parse(await fs.readFile(new URL(merged ? 'merged-data.json' : 'data.json', import.meta.url), 'utf8'));
const workbook = Workbook.create();
const specs = merged ? [
  ['合并消费明细', 'details', [166, 118, 92, 128, 100, 116, 105, 116, 104, 112]],
  ['清洗说明', 'notes', [230, 760, 116, 116]],
  ['清洗流水', 'audit', [166, 95, 104, 105, 139, 96, 122, 116, 226, 245, 116]],
] : [
  ['周度模型输入', 'weekly', [140, 160]],
  ['合并消费明细', 'details', [166, 118, 92, 128, 100, 180, 116, 105, 116, 112]],
  ['清洗说明', 'notes', [202, 680, 116, 116]],
  ['清洗流水', 'audit', [92, 106, 166, 144, 96, 122, 116, 192, 132, 116]],
];
const sheets = {};
for (const [name, key, widths] of specs) {
  const sheet = workbook.worksheets.add(name);
  sheets[key] = sheet;
  const rows = data[key];
  const range = sheet.getRangeByIndexes(0, 0, rows.length, widths.length);
  range.values = rows;
  range.format.font.name = 'Microsoft YaHei';
  range.format.font.size = 10;
  range.format.verticalAlignment = 'center';
  range.format.rowHeightPx = 28;
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);
  const header = sheet.getRangeByIndexes(0, 0, 1, widths.length);
  header.format.rowHeightPx = 34;
  header.format.fill = '#16445A';
  header.format.font.color = '#FFFFFF';
  header.format.font.bold = true;
  widths.forEach((width, index) => {
    sheet.getRangeByIndexes(0, index, rows.length, 1).format.columnWidthPx = width;
  });
  if (key === 'details' || key === 'audit') {
    const table = sheet.tables.add(range.address.split('!').at(-1), true, key === 'details' ? 'CleanSpending' : 'CleaningAudit');
    table.style = 'TableStyleMedium2';
  } else {
    for (let index = 1; index < rows.length; index += 2) {
      sheet.getRangeByIndexes(index, 0, 1, widths.length).format.fill = '#EDF5F7';
    }
  }
}

const formatColumn = (key, index, format) =>
  sheets[key].getRangeByIndexes(1, index, data[key].length - 1, 1).setNumberFormat(format);
const currency = '#,##0.00';
formatColumn('details', 0, 'yyyy-mm-dd hh:mm:ss');
formatColumn('details', 1, 'yyyy-mm-dd');
for (const index of merged ? [5, 6, 7] : [6, 7, 8]) formatColumn('details', index, currency);
for (const index of merged ? [7, 10] : [6, 9]) formatColumn('audit', index, currency);
if (merged) formatColumn('audit', 0, 'yyyy-mm-dd hh:mm:ss');
sheets.notes.getRange('B2:B18').format.wrapText = true;
sheets.notes.getRange('A2:D18').format.rowHeightPx = 41;

if (!merged) {
  formatColumn('weekly', 0, 'yyyy-mm-dd');
  formatColumn('weekly', 1, currency);
  const detailLast = data.details.length;
  const modelRange = sheets.weekly.getRange('B2:B53');
  modelRange.formulas = data.weekly.slice(1).map((_, index) =>
    [`=ROUND(SUMIF('合并消费明细'!$B$2:$B$${detailLast},A${index + 2},'合并消费明细'!$I$2:$I$${detailLast}),2)`]);
  workbook.recalculate();
  modelRange.values.forEach(([actual], index) => {
    if (actual !== data.weekly[index + 1][1]) throw new Error(`Weekly mismatch at ${index + 1}: ${actual}`);
  });
}
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(process.argv[3]);
for (const [name, key, widths] of specs) {
  try {
    const last = String.fromCharCode(64 + widths.length);
    const blob = await workbook.render({ sheetName: name, range: `A1:${last}${key === 'notes' ? 18 : 9}`, scale: 1 });
    await fs.writeFile(new URL(`render-${merged ? 'merged-' : ''}${key}.png`, import.meta.url), new Uint8Array(await blob.arrayBuffer()));
  } catch (error) {
    console.error(`Preview unavailable for ${key}: ${error.message}`);
  }
}
