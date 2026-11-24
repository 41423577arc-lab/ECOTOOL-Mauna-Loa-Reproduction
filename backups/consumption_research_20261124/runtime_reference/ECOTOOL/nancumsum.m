function zc= nancumsum(z)
% NANCUMSUM  Cumulative sum of matrix in columns with NaN values
%   yc= nancumsum(y)
%
% INPUTS:
%   y: (*) Vector time series data (m x T or T x m)
%
% OUTPUTS:
%  yc:  Cumulative sum of variables in z
%
% See Also: nancorr, nancov, nanprod, meda

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[T, m]= size(z);
zc= nan*ones(size(z));

NMiss= ~isnan(z);
for i= 1:m
   ind= find(NMiss(:, i));
   zc(ind, i)= cumsum(z(ind, i));
end


