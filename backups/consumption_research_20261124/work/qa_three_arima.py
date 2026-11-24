from pathlib import Path
import pypdfium2 as pdfium
from pypdf import PdfReader
from PIL import Image,ImageDraw
import sys
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent/'three_arima_render'
pdf=pdfium.PdfDocument(root/'report.pdf');reader=PdfReader(root/'report.pdf')
for i,page in enumerate(pdf):
    pic=page.render(scale=1.65).to_pil();pic.save(root/f'page-{i+1}.png')
    text=reader.pages[i].extract_text()
    print(i+1,len(text),text[:75].replace('\n',' '),'END',text[-65:].replace('\n',' '))
for start in range(0,len(pdf),4):
    sheet=Image.new('RGB',(1300,1740),'#c8c8c8');draw=ImageDraw.Draw(sheet)
    for j in range(min(4,len(pdf)-start)):
        im=Image.open(root/f'page-{start+j+1}.png');im.thumbnail((630,820));x=(j%2)*650+10;y=(j//2)*870+30;sheet.paste(im,(x,y));draw.text((x,y-22),f'Page {start+j+1}',fill='black')
    sheet.save(root/f'contact-{start//4+1}.png')
