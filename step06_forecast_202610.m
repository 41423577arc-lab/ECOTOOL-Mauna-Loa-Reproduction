%% 第六步：先锁定预测，再单独读测试金额；重复运行复用锁定值
projectDir=fileparts(mfilename('fullpath')); out=fullfile(projectDir,'output');
r=load(fullfile(out,'step05_rolling.mat')); lockFile=fullfile(out,'step06_forecast_locked.mat');
if isfile(lockFile)
 locked=load(lockFile); assert(isequaln(locked.training,r.tr)&&locked.selectedModel==r.selectedModel,'锁定结果与训练/选模不一致，禁止自动覆盖首次预测');
 finalModel=locked.finalModel; point=locked.point; selectedModel=locked.selectedModel;
else
 addpath('C:\Users\86139\AppData\Roaming\MathWorks\MATLAB Add-Ons\Toolboxes\ECOTOOL');
 selectedModel=r.selectedModel; training=r.tr;
 finalModel=modelUC(training.yTrain,[],char(selectedModel),1); point=finalModel.py;
 assert(isscalar(point)&&isfinite(point));
 % 原生stdpy虽匹配状态递推，但CML绝对方差尺度未校准；不生成虚假的95%区间。
 intervalStatus="不可可靠计算：CML预测方差尺度未校准；10个滚动误差亦不足以可靠标定95%尾部";
 lockedAt=datetime('now','TimeZone','Asia/Shanghai');
 save(lockFile,'training','selectedModel','finalModel','point','intervalStatus','lockedAt');
end
% 上述文件已落盘后，才仅读2026-10对应的金额行。
path=fullfile(projectDir,'data','UC个人总支出_月度_含美元.csv');
opts=detectImportOptions(path,'VariableNamingRule','preserve','TextType','string'); opts.SelectedVariableNames={'月份'};
d=readtable(path,opts); dates=datetime(string(d{:,1}),'InputFormat','yyyy-MM'); row=find(dates==datetime(2026,10,1)); assert(isscalar(row));
opts.SelectedVariableNames={'月份','个人总支付_元'}; opts.DataLines=[row+1,row+1]; test=readtable(path,opts); actual=test{:,'个人总支付_元'};
forecastResult=table(datetime(2026,10,1),selectedModel,point,actual,point-actual,abs(point-actual),abs(point-actual)/abs(actual),NaN,NaN,"不可判定（未发布可靠区间）",'VariableNames',{'Month','Model','Forecast','Actual','Error','AbsoluteError','RelativeError','Lower95','Upper95','IntervalCoverage'});
writetable(forecastResult,fullfile(out,'UC最终预测结果.csv'),'Encoding','UTF-8');
save(fullfile(out,'step06_evaluation.mat'),'forecastResult');
f=figure('Visible','off','Color','w'); plot(r.tr.tTrain,r.tr.yTrain,'-o'); hold on; plot(datetime(2026,10,1),point,'rs','MarkerSize',9); plot(datetime(2026,10,1),actual,'kx','MarkerSize',10); title('个人总支付历史与2026年10月预测'); xlabel('月份'); ylabel('金额（元）'); legend('历史训练数据','锁定预测','独立测试真实值','Location','best'); grid on; exportIfMissing(f,out); close(f);
f=figure('Visible','off','Color','w'); bar([point,actual]); xticks(1:2); xticklabels({'锁定预测','真实值'}); title('2026年10月个人总支付预测与真实值对比'); xlabel('结果类型'); ylabel('金额（元）'); exportIfMissing(f,out); close(f);
disp(forecastResult);

function exportIfMissing(fig,out)
% 已存在同标题成对导出时不重复生成；源数据变化后应另行管理旧结果。
ax=findall(fig,'Type','axes'); name=char(string(ax(1).Title.String));
if ~(isfile(fullfile(out,[name '.png']))&&isfile(fullfile(out,[name '.fig'])))
 exportFigureByTitle(fig,out);
end
end
