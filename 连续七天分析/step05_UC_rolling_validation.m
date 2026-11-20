%% 第五步：训练期滚动验证及基准比较
projectDir=fileparts(mfilename('fullpath'));addpath(fileparts(projectDir));
completePeriodForecast(projectDir,"rolling");
