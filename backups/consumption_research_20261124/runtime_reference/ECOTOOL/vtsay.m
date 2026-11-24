function vtsay(z, lags, Names, win)
% vtsay   Tsay non-linearity tests
%
%    vtsay(y, ncoef)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   lags: Maximum lag lags for regression tests (1 x 1)
% 
% See Also: nltests, varsbc2, vbds   

% win= 0:  run independently
% win= 1:  run from testtool call
% win= 2:  run from Options menu

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 4, win= 0; end

if win> 0
    [z, Names, lags, seriesval]= auxtestGUI;
    lags= lags{20}{1};
    seriesval= seriesval(1);
end    

[T, m]= size(z);
% if T<m, z= z'; [T, m]= size(z); end

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 3, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 2, lags= 4; end
if isempty(lags), lags= 4; end
lags= max(lags, 2);
lags= max(lags);

TABLE= charcat(' ', '-', ' Tsay(1986) Non-Linear Test ', ...
    '-', ' H0: Process is linear ', '-', ...
    [' Summary table based on an AR(' int2str(lags) ') Model: ']);
kk= sum(1 : lags);
fcol= []; FF= zeros(m, 2);
wwaitfor(lags*m);
for seriesval= 1 : m
	X= delay(z(:, seriesval), [0 (1 : lags)]);
	E= lreg(X(:, 1), X(:, 2 : end));
	XX= zeros(size(X, 1), kk);
	h= 1;
	for i= 1 : lags
        for j= i : lags
            XX(:, h)= lreg(X(:, i+1).*X(:, j+1), X(:, 2 : end));
            h= h + 1;
            if seriesval== 1, fcol= char(fcol, ['z(t-' int2str(i) ')*z(t-' int2str(j) '):']); end
        end
        if wwaitfor, return; end
	end
	[E, beta, t, probt, F, probF]= lreg(E, XX);
    FF(seriesval, :)= [F probF];
    tablei= [charcat(' Variable ', fcol(2:end, :)) printwf([beta t probt], 4, 'Betas T P-value')];
    tablei= charcat('-', [' Series: ' Names(seriesval, :) ' '], '-', ...
           tablei(1, :), '-', tablei(2 : end, :), '-', [' P-value Tsay: ' num2str(probF) ' '], '-');
    if seriesval== 1, table= tablei; else, table= char(table, tablei); end
end

tablei= printwf(FF, 4, 'Tsay-F P-value', Names(1:m, :));
TABLE= charcat(TABLE, '-', tablei(1, :), '-', tablei(2 : end, :), ...
    '-', ' ', ' ', '=', ' Auxiliary Regressions: ', '=');
TABLE= [TABLE char(ones(size(TABLE, 1), 1)*abs(' '))];

wwaitfor(0);
textoutputWINDOW(charcat(TABLE, table), 'Tsay(1986) Non-Linear Test');

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
        'callback', ['if optionsET({''Lags for AR model [1, Inf):''}, 1, 20);' ...
            'vtsay([], [], [], 2); end']);
end


%% AUXILIARY FUNCTION
function [e, beta, t, probt, F, probF]= lreg(y, X)
[T, k]= size(X);
iXX= inv(nanprod(X', X));
beta= iXX*nanprod(X', y);
e= y - X*beta;
sigma= nanprod(e', e)/(T - k);
esbeta= sqrt(diag(sigma*(iXX)));
t= beta./esbeta;
probt= 1 - tcdf(t, T - k);
yh= X*beta - nanmean(y);
F= (nanprod(yh', yh) / (k - 1)) / sigma;
probF = 1 - fcdf(F, k - 1, T - k);
