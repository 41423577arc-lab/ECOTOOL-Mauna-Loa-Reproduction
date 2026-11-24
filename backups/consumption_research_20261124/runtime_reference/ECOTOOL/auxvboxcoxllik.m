function [out, yr]= auxvboxcoxllik(lambda, zi, group, lim)
% Auxiliar function of vboxcox (computes the log-likelihood of series
%     for a given value of lambda)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if 1
    n = length(zi);
    ny = floor(n / group);
    yr = reshape(zi(end - ny * group + 1 : end), group, ny);
    myr = nanmean(yr)';
    sd = nanstd(yr)';
    yt = sd ./ myr .^ (1 - lambda);
    out = nanstd(yt) / nanmean(yt);
else
    if lambda== 0
       zit= log(zi);
    else
       zit= (zi.^lambda - 1)/lambda;
    end
    out= (size(zi, 1)/2)*log(nancov(zit)) + (1-lambda)*nansum(log(zi))-lim;
end
