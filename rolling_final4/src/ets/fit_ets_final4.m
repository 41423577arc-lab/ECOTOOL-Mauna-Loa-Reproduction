function [m,logtext] = fit_ets_final4(y,model,H)
% Selectively adapted from Ariel A_case_ets_aligned/B_case_ets/C_case_ets.
% Same ECOTOOL CML call; caller supplies canonical member data and horizon.
% No filesystem paths, outlier removal, exogenous variables, or seasonal term.
assert(ismember(string(model),["NN","AN"]));
lastwarn('');
logtext=evalc('m = modelETS(double(y(:)), [], char(model), H, ''CML'');');
[msg,id]=lastwarn;
m.final4Warning=strtrim(string(id)+": "+string(msg));
% ECOTOOL's public API does not expose optimizer exit flags.
% Never infer convergence merely from finite predictions.
m.final4Convergence="未暴露退出标志；有限结果不等于已收敛";
if contains(logtext,'Exit1basic') || contains(logtext,'local_min_unconstrained')
    m.final4Convergence="优化器文本报告局部最小值；退出码未暴露";
elseif contains(logtext,'Exit2basic')
    m.final4Convergence="优化器文本报告步长停止；退出码未暴露";
end
assert(all(isfinite(m.py(:))) && all(isfinite(m.par(:))), 'ETS returned nonfinite values');
end
