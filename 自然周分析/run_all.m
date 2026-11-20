%% 按原流程依次执行四步，所有结果写入本目录的output
run(fullfile(fileparts(mfilename('fullpath')),'step01_data_preparation.m'));
run(fullfile(fileparts(mfilename('fullpath')),'step02_stationarity_test.m'));
run(fullfile(fileparts(mfilename('fullpath')),'step03_UC_model.m'));
run(fullfile(fileparts(mfilename('fullpath')),'step04_UC_diagnostics.m'));

run(fullfile(fileparts(mfilename('fullpath')),'step05_UC_rolling_validation.m'));
run(fullfile(fileparts(mfilename('fullpath')),'step06_forecast.m'));
