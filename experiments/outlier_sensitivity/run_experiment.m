function run_experiment()
% 实验二：每个原点重新计算IQR上界，仅缩尾训练数据。
here=fileparts(mfilename('fullpath'));addpath(fileparts(here));
run_uc_backtests(fileparts(fileparts(here)),"outlier_sensitivity");
end
