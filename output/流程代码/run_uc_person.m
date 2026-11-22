function run_uc_person(personDir,inputFile)
% 仅总支付；旧流程的算法、时间边界及选模规则不变。
personDir=char(personDir); inputFile=char(inputFile);
codeDir=fileparts(mfilename('fullpath'));
if ~isfolder(personDir),mkdir(personDir);end
logFile=fullfile(personDir,'运行日志.txt');
logHandle=fopen(logFile,'w'); fclose(logHandle);
diary(logFile);
finish=onCleanup(@() diary('off'));
fprintf('开始：%s；MATLAB %s；时间 %s\n',inputFile,version,string(datetime('now','TimeZone','Asia/Shanghai')));
set(groot,'DefaultFigureVisible','off');
run(fullfile(codeDir,'step01_data_preparation.m'));
run(fullfile(codeDir,'step02_stationarity_test.m'));
run(fullfile(codeDir,'step03_UC_model.m'));
close all;
run(fullfile(codeDir,'step04_UC_diagnostics.m'));
close all;
completePeriodForecast(personDir,"rolling");
completePeriodForecast(personDir,"final");
close all;
finishedAt=datetime('now','TimeZone','Asia/Shanghai');
save(fullfile(personDir,'运行完成.mat'),'finishedAt','inputFile');
fprintf('完成：%s\n',personDir);
end
