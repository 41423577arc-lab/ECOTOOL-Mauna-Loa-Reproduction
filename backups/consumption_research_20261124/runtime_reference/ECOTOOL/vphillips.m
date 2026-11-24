function vphillips(z, lags, ncovs, Names, win)
% vphillips   Phillips Perron Unit Roots tests
%
%    vphillips(y, lags, ncovs)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   lags:  Maximum lag (1 x 1) or vector of lags (any x 1) to include 
%          in test regression
%   ncovs: Number of autocovariances of residuals to include 
%          in the tests
%   
% Examples: 
%   vphillips(z);
%   vphillips(z, 10);         % output different depending on univariate or multivariate time series
%   vphillips(z, (5 : 10), 3);   % output different depending on univariate or multivariate time series
%
% See Also: ADFtest, Johansentest

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


% win= 0:  run independently
% win= 1:  run from testtool call
% win= 2:  run from Options menu

if nargin< 5, win= 0; end

if win> 0
    [z, Names, opts, seriesval]= auxtestGUI;
    lags= opts{16}{1}; ncovs= opts{17}{2};
    seriesval= seriesval(1);
end    

[T, m]= size(z);
% if T<m, z= z'; [T, m]= size(z); end

defNames= [char(abs('#')*ones(m, 1)) int2str((1 : m)')];
if nargin< 4, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m, Names= Names(1 : m, :); end
if sNames< m, Names= char(Names, defNames(sNames + 1 : end, :)); end
Names= [Names char(abs('@')*ones(m, 1))]';
Names= Names(:)'; Names= strrep(Names(1 : end-1), ' ', '');
Names= strrep(Names, '@', ' ');

if (nargin< 2 & m==1)
   lags= (1:min([fix(sqrt(T)) 20]));
elseif nargin< 2
   lags= min([fix(sqrt(T)) 20]);
end
if (isempty(lags) & m==1)
   lags= (1:min([fix(sqrt(T)) 20]));
elseif isempty(lags)
   lags= min([fix(sqrt(T)) 20]);
end
lags= lags(:)';
if m> 1, lags= lags(end); end
nlags= size(lags, 2);
if lags(end)> T/2
    lags= fix(T/2);
end

if nargin< 3, ncovs= fix(4*(T/100)^0.25); end
if isempty(ncovs), ncovs= fix(4*(T/100)^0.25); end

Miss= isnan(z);
Rhont= repmat(nan, nlags, m); tRhont= Rhont; PRhont= Rhont;
Rho= Rhont; Rhot= Rho;
tRho= Rho; tRhot= Rho;
wwaitfor(m*nlags);
for i= 1:m
   for j= 1:nlags
      pj= lags(j);
      dzlag= delay(vdif(z(:, i)), 1 : pj);
      XX= [z(pj+1 : T-1, i) ones(T-pj-1, 1) (1 : T-pj-1)' dzlag];
      if size(XX, 2)> 1
          ind= isnan(sum(XX'))';
      else
          ind= isnan(XX);
      end
      ind= find(ind);
      y= z(pj+2 : T, i);
      if ~isempty(ind), XX(ind, :)= []; y(ind)= []; end
% No trend and No constant
      X= XX(:, [1 4:end]);
      if sum(Miss(:, i))
         iXX= inv(nanprod(X', X));
         param= iXX*nanprod(X', y); %z(pj+2 : T, i));
%          e= z(pj+2 : T, i) - X*param;
         e= y - X*param;
         e2= nanprod(e', e);
      else
         iXX= inv(X'*X);
         param= X \ y; %z(pj+2 : T, i);
%          e= z(pj+2 : T, i) - X*param;
         e= y - X*param;
         e2= e'*e;
      end
%       X= [z(pj : T-1, i) dzlag];
%       if sum(Miss(:, i))
%          iXX= inv(nanprod(X', X));
%          param= iXX*nanprod(X', z(pj+1 : T, i));
%          e= z(pj+1 : T, i) - X*param;
%          e2= nanprod(e', e);
%       else
%          iXX= inv(X'*X);
%          param= X \ z(pj+1 : T, i);
%          e= z(pj+1 : T, i) - X*param;
%          e2= e'*e;
%       end
      sigma= e2/(size(X, 1)-size(X, 2));
      Resstd= sqrt(sigma*iXX);
      Rhont(j, i)= param(1); tRhont(j, i)= (param(1)-1)/Resstd(1, 1);
      NW = e2;
 	  for kk = 1 : ncovs
        NW = NW + 2 * (1 - kk/(ncovs + 1))*(e(1 : end - kk)'*e(kk + 1 : end));
	  end
	  NW = NW / T;
	  tRhont(j, i)= sqrt(e2 / T / NW) * tRhont(j, i) - 1/2 * (NW - e2 / T) / sqrt(NW) * T * Resstd(1, 1) / sigma;
% No trend
      X= XX(:, [1 2 4:end]);
      if sum(Miss(:, i))
         iXX= inv(nanprod(X', X));
         param= iXX*nanprod(X', y); %z(pj+2 : T, i));
%          [ajuste, yp, ep, beta, es, t, Pt, ixx, xy]=regresion(z(pj+2 : T, i), X);
%          e= z(pj+2 : T, i) - X*param;
         e= y - X*param;
         e2= nanprod(e', e);
      else
         iXX= inv(X'*X);
         param= X \ y; %z(pj+2 : T, i);
%          e= z(pj+2 : T, i) - X*param;
         e= y - X*param;
         e2= e'*e;
      end
%       X= [z(pj : T-1, i) ones(T-pj, 1) dzlag];
%       if sum(Miss(:, i))
%          iXX= inv(nanprod(X', X));
%          param= iXX*nanprod(X', z(pj+1 : T, i));
%          e= z(pj+1 : T, i) - X*param;
%          e2= nanprod(e', e);
%       else
%          iXX= inv(X'*X);
%          param= X \ z(pj+1 : T, i);
%          e= z(pj+1 : T, i) - X*param;
%          e2= e'*e;
%       end
      sigma= e2/(size(X, 1)-size(X, 2));
      Resstd= sqrt(sigma*iXX);
      Rho(j, i)= param(1); tRho(j, i)= (param(1)-1)/Resstd(1, 1);
      NW = e2;
 	  for kk = 1 : ncovs
        NW = NW + 2 * (1 - kk/(ncovs + 1))*(e(1 : end - kk)'*e(kk + 1 : end));
	  end
	  NW = NW / T;
	  tRho(j, i)= sqrt(e2 / T / NW) * tRho(j, i) - 1/2 * (NW - e2 / T) / sqrt(NW) * T * Resstd(1, 1) / sigma;
% trend
      X= XX;
      if sum(Miss(:, i))
         iXX= inv(nanprod(X', X));
         param= iXX*nanprod(X', y); %z(pj+2 : T, i));
%          e= z(pj+2 : T, i) - X*param;
         e= y - X*param;
         e2= nanprod(e', e);
      else
         iXX= inv(X'*X);
         param= X \ y; %z(pj+2 : T, i);
%          e= z(pj+2 : T, i) - X*param;
         e= y - X*param;
         e2= e'*e;
      end     
%       X= [z(pj : T-1, i) ones(T-pj, 1) (1 : T-pj)' dzlag ];
%       if sum(Miss(:, i))
%          iXX= inv(nanprod(X', X));
%          param= iXX*nanprod(X', z(pj+1 : T, i));
%          e= z(pj+1 : T, i) - X*param;
%          e2= nanprod(e', e);
%       else
%          iXX= inv(X'*X);
%          param= X \ z(pj+1 : T, i);
%          e= z(pj+1 : T, i) - X*param;
%          e2= e'*e;
%       end     
      sigma= e2/(size(X, 1)-size(X, 2));
      Resstd= sqrt(sigma*iXX);
      Rhot(j, i)= param(1); tRhot(j, i)= (param(1)-1)/Resstd(1, 1);
      NW = e2;
 	  for kk = 1 : ncovs
        NW = NW + 2 * (1 - kk/(ncovs + 1))*(e(1 : end - kk)'*e(kk + 1 : end));
	  end
	  NW = NW / T;
	  tRhot(j, i)= sqrt(e2 / T / NW) * tRhot(j, i) - 1/2 * (NW - e2 / T) / sqrt(NW) * T * Resstd(1, 1) / sigma;
      if wwaitfor, break; end
   end
end
wwaitfor(0);

if m==1
   table0= printwf([lags' Rhont tRhont adfcritical(tRhont, T, 1)], [0 4], 'Lags z(t-1) PP-test Pvalue');
   table1= printwf([lags' Rho tRho adfcritical(tRhont, T, 2)], [0 4], 'Lags z(t-1) PP-test Pvalue');
   table2= printwf([lags' Rhot tRhot adfcritical(tRhont, T, 3)], [0 4], 'Lags z(t-1) PP-test Pvalue');
   table0= charcat(' ', '-', ['Series ' Names ' '], '-', ...
       [' Phillips-Perron Tests (NO CONSTANT, NO TREND): '], ...
       [' Number of residual covs= ' int2str(ncovs) ' '], ...
       '-', ' PP-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ' , ...
       ' P values are approximate based on tables ', ...
       '-', table0(1, :), '-', table0(2 : end, :), '-', ' ');
   table1= charcat(' ', '-', [' Phillips-Perron Tests (CONSTANT, NO TREND): '], ...
       '-', table1(1, :), '-', table1(2 : end, :), '-');
   textoutputWINDOW(charcat([table0 char(abs(' ')*ones(size(table0, 1), 1))], ...
       [table1 char(abs(' ')*ones(size(table1, 1), 1))], ' ', ' ', '-', ...
       [' Phillips-Perron Tests (CONSTANT AND TREND): '], '-', ...
       table2(1, :), '-', table2(2 : end, :), '-'), 'Phillips-Perron Tests');
else
   table0= printwf([Rhont' tRhont' adfcritical(tRhont, T, 1)], 4, 'z(t-1) PP-test Pvalue', Names);
   table1= printwf([Rho' tRho' adfcritical(tRhont, T, 2)], 4, 'z(t-1) PP-Test Pvalue', Names);
   table2= printwf([Rhot' tRhot' adfcritical(tRhont, T, 3)], 4, 'z(t-1) PP-Test Pvalue', Names);
   table0= charcat(' ', '-', ' Phillips-Perron Tests (NO CONSTANT, NO TREND): ', '-', ...
       [' Lags= ' int2str(lags) '; Number of residual covs= ' int2str(ncovs) ' '], ...
       '-', ' PP-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ', ...
       ' P values are approximate based on tables ', ...
       '-', table0(1, :), '-', table0(2 : end, :), '-');
   table1= charcat(' ', '-', [' Phillips-Perron Tests (CONSTANT, NO TREND): '], ...
       '-', table1(1, :), '-', table1(2 : end, :), '-');
   textoutputWINDOW(charcat([table0 char(abs(' ')*ones(size(table0, 1), 1))], ' ', ...
       [table1 char(abs(' ')*ones(size(table1, 1), 1))], ' ', ' ', '-', ...
       [' Phillips-Perron Tests (CONSTANT AND TREND): '], '-', ...
       table2(1, :), '-', table2(2 : end, :), '-'), ...
       'Phillips-Perron Tests');
end   

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
        'callback', ['if optionsET({''Lags for PP regressions (it can be a row vector) [1, Inf):'', ' ...
            '''Number of covariances for PP test: [1 Inf): ''}, [1; 1], [16 1; 17 2]);' ...
            'vphillips([], [], [], [], 2); end']);
end
