function lagy= delay(y, lags)
% delay  Lags a vector of variables
%
%   ylag = delay(y, lags)
%
% INPUTS:
%  y:     (*) Vector time series data (m x T or T x m)
%  lags:  (*) Vector or matrix of lags (1 x any)
%
% OUTPUTS:
%  ylag:  Matrix of lagged variables
%
% Examples:
%   y= repmat((1 : 10)', 1, 3);
%   delay(y, [0 1 2])
%   delay(y(:, 1), [0 2 4])

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[T, m]= size(y);
if T< m, y= y'; [T, m]= size(y); end

nlags= size(lags, 2);

maxlag= max(lags);
lagy= zeros(T-maxlag, m*nlags);

for i=1:nlags
   lagy(:, (i-1)*m+1:i*m)= y(maxlag-lags(i)+1:T-lags(i), :);
end
