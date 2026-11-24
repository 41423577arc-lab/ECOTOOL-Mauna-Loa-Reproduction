from pathlib import Path

import pypdfium2 as pdfium
from pypdf import PdfReader
from PIL import Image, ImageDraw


folder = Path(__file__).resolve().parent / 'arima-report-render'
pdf = pdfium.PdfDocument(folder / 'report.pdf')
reader = PdfReader(folder / 'report.pdf')
for index, page in enumerate(pdf):
    bitmap = page.render(scale=1.5).to_pil()
    bitmap.save(folder / f'page-{index + 1}.png')
    print(index + 1, len(reader.pages[index].extract_text()), reader.pages[index].extract_text()[:36].replace('\n',' '))
for begin in range(0, len(pdf), 6):
    contact = Image.new('RGB', (1500, 1200), '#c8c8c8')
    draw = ImageDraw.Draw(contact)
    for offset in range(min(6, len(pdf)-begin)):
        page = Image.open(folder / f'page-{begin+offset+1}.png')
        page.thumbnail((490, 560))
        left = (offset % 3) * 500
        top = (offset // 3) * 600 + 25
        contact.paste(page, (left, top))
        draw.text((left + 8, top - 20), f'Page {begin+offset+1}', fill='black')
    contact.save(folder / f'contact-{begin//6+1}.png')
