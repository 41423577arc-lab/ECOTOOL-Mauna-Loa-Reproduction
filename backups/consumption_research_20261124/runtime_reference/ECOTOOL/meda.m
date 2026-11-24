function zc= meda(z)
% MEDA    Median Absolute deviation with respect to the median
%   zmeda= meda(z)
%
% INPUTS:
%   z: (*) Vector time series data (m x T or T x m)
%
% OUTPUTS:
%  zmeda:  Median Absolute deviation of each variables
%
% See Also: nancov, nancumsum, nanprod

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

zc= nanmedian(abs(z - repmat(nanmedian(z), T, 1)));


