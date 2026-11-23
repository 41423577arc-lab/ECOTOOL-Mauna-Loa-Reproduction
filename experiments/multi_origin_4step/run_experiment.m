function run_experiment()
% 实验一：27个训练内固定原点的四步回测；不修改正式output。
here=fileparts(mfilename('fullpath'));addpath(fileparts(here));
run_uc_backtests(fileparts(fileparts(here)),"multi_origin_4step");
end
