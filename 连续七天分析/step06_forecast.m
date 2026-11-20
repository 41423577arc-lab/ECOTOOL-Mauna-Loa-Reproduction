%% 第六步：先锁定全部保留周期预测，再读取独立测试金额
projectDir=fileparts(mfilename('fullpath'));addpath(fileparts(projectDir));
completePeriodForecast(projectDir,"final");
