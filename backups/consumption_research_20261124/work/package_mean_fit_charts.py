from pathlib import Path
import csv,shutil,zipfile
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1];S=R/'outputs'/'ABC_原序列自相关检验与均值基线_20261123';O=R/'outputs'/'ABC_均值基线拟合图_每人三张_20261123'
for name in ['ABC_均值基线30折明细.csv','ABC_均值基线固定原点预测.csv',*[who+'_112周建模输入.csv' for who in 'ABC']]:shutil.copy2(S/name,O/name)
shutil.copy2(R/'work'/'plot_mean_fits_reference.m',O/'plot_mean_fits_reference.m')
readme='''均值基线拟合图 使用说明
本包按参考图的蓝色实线空心圆实际值、红色虚线空心方块模型值绘制。
每位成员三张，共9张：
1 训练期样本内拟合：用前108周估计一个均值，训练区间各期拟合值相同。这是样本内描述，不能作为无未来信息的一步预测。
2 30折一步滚动预测：每折仅用此前78至107周数据的均值预测下一周。图对应参考图片的逐期实际与预测对照；红线随每折均值更新。
3 固定原点四周预测：只用前108周均值一次预测后4周，因此4个预测值相同。

模型：ARIMA(0,0,0)加常数项。p=d=q=0，无AR项、MA项、差分或季节项；没有自动选模，等效于训练历史算术均值。
模型未使用自相关项，不等于数据的实测自相关系数全为零；原序列检验中成员A第9阶ACF越界应保留，不删除。
该模型也不是ARIMA(0,1,0)的上一期朴素预测。

数据仍采用前次确认的正确三组112个自然周：A合计64470.55元、B净消费114959.44元、C总支付88773.97元。
训练前108周，测试后4周2026-09-28至2026-10-25。
训练拟合明细Residual列为实际减拟合，原预测明细Error列为预测减实际，二者符号定义不同。

复现：解压至可写目录，在MATLAB运行plot_mean_fits_reference。程序读取本包已有输入及预测CSV，仅重新制图，不重新识别ARIMA阶数。输出会覆盖同名图和绘图明细CSV。
'''
(O/'图像与模型说明.txt').write_text(readme,encoding='utf-8')
canvas=Image.new('RGB',(2100,1650),'white');draw=ImageDraw.Draw(canvas);font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',35)
draw.text((45,20),'A B C 均值基线逐期预测与实际对比',font=font,fill='black')
for i,who in enumerate('ABC'):
    pic=Image.open(O/(who+'_2_滚动预测拟合图.png')).convert('RGB');pic.thumbnail((2010,510),Image.Resampling.LANCZOS);canvas.paste(pic,(45,75+i*520))
canvas.save(O/'ABC_滚动预测拟合总览.png')
fits=list(csv.DictReader((O/'ABC_训练期均值拟合明细.csv').open(encoding='utf-8-sig')))
assert len(fits)==324
for who in 'ABC':assert len({r['Fitted'] for r in fits if r['Member']==who})==1
zpath=R/'outputs'/'ABC_均值基线拟合图_每人三张.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED) as z:
 for file in O.iterdir():
  if file.is_file():z.write(file,arcname=file.name)
print(zpath)
