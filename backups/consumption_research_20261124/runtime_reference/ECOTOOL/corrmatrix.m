function corr= corrmatrix(covar, d)
% corrmatrix  Builds correlation matrix from covariance matrix
%
%   corrmat= corrmatrix(covmat)
%
% INPUTS:
%  covmat: (*) Covariance matrix, squared and semipositive 
%          definite (any x any)
%
% OUTPUTS:
%  corrmat: Correlation matrix
%
% See Also: nancorr, nancov, nanprod

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 2
    d = diag(covar);
    corr = covar./sqrt(d*d');
else
    corr= covar.*sqrt(d*d');
end






