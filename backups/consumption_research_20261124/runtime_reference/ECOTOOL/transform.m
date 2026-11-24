function [zt, mz, stdz]= transform(z, mz, stdz)
% TRANSFORM  Standardisation or de-standardisation of a vector of variables
%   [yt, my, stdy]= transform(y, my, stdy)
%
% INPUTS:
%  y:     Matrix of variables (*) (N x m)
%  my:    Mean values for de-standardisation
%  stdy:  Standard deviations for de-standardisation
%
% OUTPUTS:
%  yt:    Standardised y
%  my:    Mean of y
%  stdy:  Standard deviation of y
%
% See Also: varmatrix, vecmatrix, writepoly, sysvariable, evalfun, checkmodel

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
%if T<m, z= z'; [T, m]= size(z); end

onescol= ones(T, 1);

if nargin<2
   mz= nanmean(z);
   stdz= nanstd(z);
   ind= find(stdz== 0);
   stdz(ind)= ones(size(ind));
   zt= (z-onescol*mz)./(onescol*stdz);
else
   zt= z.*(onescol*stdz)+onescol*mz;
end

