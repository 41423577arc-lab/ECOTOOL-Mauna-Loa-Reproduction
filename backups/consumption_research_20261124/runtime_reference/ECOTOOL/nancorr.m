function corrz= nancorr(z)
% NANCORR   Correlation matrix of vector variables with NaN values
%
%   corry = nancorr(y)
%
% INPUTS:
%   y: (*) Vector time series data (m x T or T x m)
%
% OUTPUTS:
%  corry:  Correlation matrix
%
% See Also: nancov, nancumsum, nanprod, meda

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
% if T<m, z= z'; [T, m]= size(z); end

corrz= nancov(transform(z));
