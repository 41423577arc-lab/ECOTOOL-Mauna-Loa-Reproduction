%% 总支付自然周数据准备；与原流程保持相同训练/测试边界
projectDir = personDir;
outputDir = personDir;
filePath = inputFile;
periodLabel = '自然周';
cutoff = datetime(2026,10,1);
dateCells = readcell(filePath,'Sheet','UC数据','Range','A2:A113');
if all(cellfun(@(v) isa(v,'datetime'),dateCells))
    allDates = vertcat(dateCells{:});
elseif all(cellfun(@isnumeric,dateCells))
    allDates = datetime(cell2mat(dateCells),'ConvertFrom','excel');
else
    allDates = datetime(string(dateCells),'InputFormat','yyyy-MM-dd');
end
assert(isequal(allDates,datetime(2024,9,2)+caldays(7*(0:111)')));
trainMask = allDates+caldays(6)<cutoff;
assert(sum(trainMask)==108);
tTrain=allDates(trainMask); tTest=allDates(~trainMask);
data=readtable(filePath,'Sheet','UC数据','Range','A1:B109','VariableNamingRule','preserve');
yTrain=double(data{:,'个人总支付_元'});
assert(numel(yTrain)==108 && all(isfinite(yTrain)) && all(yTrain>=0));
description=table("个人总支付",mean(yTrain),median(yTrain),std(yTrain),min(yTrain),max(yTrain),sum(yTrain), ...
    'VariableNames',{'Series','MeanYuan','MedianYuan','SDYuan','MinYuan','MaxYuan','SumYuan'});
writetable(description,fullfile(outputDir,'训练期描述性统计.csv'),'Encoding','UTF-8');
f=figure('Visible','off','Color','w');
plot(tTrain,yTrain,'-o','LineWidth',1.5,'MarkerSize',3); grid on;
xlabel('周期起始日'); ylabel('每期个人总支付（元）');
title([periodLabel '个人总支付训练期趋势']); xtickformat('yyyy-MM-dd'); xtickangle(45);
exportFigureByTitle(f,outputDir); close(f);
save(fullfile(outputDir,'step01_training_data.mat'),'tTrain','yTrain','tTest','periodLabel','cutoff','filePath');
fprintf('训练108周：%s至%s；保留测试4周：%s至%s；尚未读取测试金额。\n', ...
    string(tTrain(1)),string(tTrain(end)+caldays(6)),string(tTest(1)),string(tTest(end)+caldays(6)));
