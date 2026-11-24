function zt= vboxcoxinv(z, lambdas, const)
% vboxcoxinv   Inverse of Box-Cox transformation
%
%    yt= vboxcoxinv(y, lambdas, const)
%
% INPUTS:
%   y:       (*) Vector time series data previously transformed with 
%            vboxcox (m x T or T x m)
%   lambdas: Lambdas for each time series (1 x n, with n<= m)
%   const:   Constants that were added to the original series in order 
%            to avoid negative values (1 x m)
%
% OUTPUTS:
%   yt:       Transformed data according to lambdas (either supplied 
%             by the user or estimated)
%
% See Also: vcusum, stdmean, testhet, vboxcox

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

if nargin< 2, lambdas= zeros(m, 1); end
lambdas= lambdas(:);
lambdas= [lambdas; repmat(lambdas(end), m-size(lambdas, 1), 1)];

if nargin< 3, const= 0; end

for i= 1 : m
    if lambdas(i)== 0
        zt(:, i)= real(exp(z(:, i))) - const;
    else
        zt(:, i)= real((z(:, i)*lambdas(i) + 1).^(1/lambdas(i))) - const;
    end
end
