function ADFtest(z, lags, Names, win)
% ADFtest   Augmented Dickey-Fuller Unit Roots tests
%
%    ADFtest(y, lags)
%
% INPUTS:
%   y:    (*) Vector time series data (m x T or T x m)
%   lags: Maximum lag (1 x 1) or vector of lags (any x 1) to
%         include in test regression
%
% See Also: vphillips, Johansentest
%   
% Examples: 
%   adftest(y);
%   adftest(y, 10);         
%   adftest(y, (5 : 10));   

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

if nargin< 4, win= 0; end

if win> 0
    [z, Names, lags, seriesval]= auxtestGUI;
    lags= lags{16}{1};
    seriesval= seriesval(1);
end    

[T, m]= size(z);
% if T<m, z= z'; [T, m]= size(z); end

defNames= [char(abs('#')*ones(m, 1)) int2str((1 : m)')];
if nargin< 3, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m, Names= Names(1 : m, :); end
if sNames< m, Names= char(Names, defNames(sNames + 1 : end, :)); end
Names= [Names char(abs('@')*ones(m, 1))]';
Names= Names(:)'; Names= strrep(Names(1 : end-1), ' ', '');
Names= strrep(Names, '@', ' ');

if (nargin< 2 && m==1)
   lags= (1:min([fix(sqrt(T)) 20]));
elseif nargin< 2
   lags= min([fix(sqrt(T)) 20]);
end
if (isempty(lags) && m==1)
   lags= (1:min([fix(sqrt(T)) 20]));
elseif isempty(lags)
   lags= min([fix(sqrt(T)) 20]);
end
lags= lags(:)';
if m> 1, lags= lags(end); end
if lags(end)> T/2
    lags= fix(T/2);
end
nlags= size(lags, 2);

Miss= isnan(z);
Rhont= repmat(nan, nlags, m); tRhont= Rhont;
Rho= repmat(nan, nlags, m); Rhot= Rho; Alfa= Rho; Alfat= Rho;
tRho= Rho; tRhot= Rho; tAlfa= Rho; tAlfat= Rho; D= Rho; tD= Rho;
F= Rho; Ft= Rho;
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
%       X= [z(pj+1 : T-1, i) dzlag];
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
      Resstd= sqrt(e2/(size(X, 1)-size(X, 2))*iXX);
      Rhont(j, i)= param(1); tRhont(j, i)= (param(1)-1)/Resstd(1, 1);
% No trend
%       X= [z(pj+1 : T-1, i) ones(T-pj-1, 1) dzlag];
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
      Resstd= sqrt(e2/(size(X, 1)-size(X, 2))*iXX);
      Rho(j, i)= param(1); tRho(j, i)= (param(1)-1)/Resstd(1, 1);
      Alfa(j, i)= param(2); tAlfa(j, i)= param(2)/Resstd(2, 2);
      vv= [Rho(j, i)-1; Alfa(j, i)];
      F(j, i)= vv'*inv(Resstd(1:2, 1:2).^2)*vv;
% trend
%       X= [z(pj+1 : T-1, i) ones(T-pj-1, 1) (1 : T-pj-1)' dzlag];
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
      Resstd= sqrt(e2/(size(X, 1)-size(X, 2))*iXX);
      Rhot(j, i)= param(1); tRhot(j, i)= (param(1)-1)/Resstd(1, 1);
      Alfat(j, i)= param(2); tAlfat(j, i)= param(2)/Resstd(2, 2);
      D(j, i)= param(3); tD(j, i)= param(3)/Resstd(3, 3);
      vv= [Rho(j, i)-1; D(j, i)];
      covv= zeros(2);
      covv(:, 1)= [Resstd(1,1); Resstd(3, 1)].^2;
      covv(:, 2)= [Resstd(3,1); Resstd(3, 3)].^2;
      Ft(j, i)= vv'*inv(covv)*vv;
      if wwaitfor, break; end
   end
end
wwaitfor(0);

if m==1
   table0= printwf([lags' Rhont tRhont adfcritical(tRhont, T, 1)], [0 4], 'Lags z(t-1) T-test Pvalue');
   table1= printwf([lags' Rho tRho adfcritical(tRho, T, 2) Alfa tAlfa F adfcritical(F, T, 4)], [0 4], 'Lags z(t-1) T-test Pvalue Ct T-Test F-Test Pvalue');
   table2= printwf([lags' Rhot tRhot adfcritical(tRhot, T, 3) Alfat tAlfat D tD Ft adfcritical(Ft, T, 5)], [0 4], 'Lags z(t-1) T-Test Pvalue Ct T-Test D T-Test F-Test Pvalue');
   table0= charcat(' ', '-', ['Series ' Names ' '], '-', ...
       [' Augmented Dickey-Fuller Tests (NO CONSTANT, NO TREND): '], ...
       '-', ' T-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ', ...
       ' P values are approximate based on tables ', ...
       '-', table0(1, :), '-', table0(2 : end, :), '-', ' ');
   table1= charcat(' ', '-', [' Augmented Dickey-Fuller Tests (CONSTANT, NO TREND): '], ...
       '-', ' T-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ', ...
       [' F-Test is for H0: Rho= 1 and Ct= 0. DoF: 2 and (' int2str(T-lags(1)-2) ' : -2 : ' int2str(T-pj-size(X, 2)+1) ') '], ...
       '-', table1(1, :), '-', table1(2 : end, :), '-');
   textoutputWINDOW(charcat([table0 char(abs(' ')*ones(size(table0, 1), 1))], ...
       [table1 char(abs(' ')*ones(size(table1, 1), 1))], ' ', ' ', '-', ...
       [' Augmented Dickey-Fuller Tests (CONSTANT AND TREND): '], ...
       '-', ' T-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ', ...
       [' F-Test is for H0: Rho= 1 and D= 0. DoF: 2 and (' int2str(T-lags(1)-3) ' : -2 : ' int2str(T-pj-size(X, 2)) ') '], ...
       '-', table2(1, :), '-', table2(2 : end, :), '-'), 'Augmented Dickey-Fuller Tests');
else
   table0= printwf([Rhont' tRhont' adfcritical(tRhont, T, 1)], 4, 'z(t-1) T-test Pvalue', Names);
   table1= printwf([Rho' tRho'  adfcritical(tRho, T, 2) Alfa' tAlfa' F' adfcritical(F, T, 4)], 4, 'z(t-1) T-Test Pvalue Ct T-Test F-Test Pvalue', Names);
   table2= printwf([Rhot' tRhot'  adfcritical(tRhot, T, 3) Alfat' tAlfat' D' tD' Ft'  adfcritical(Ft, T, 5)], 4, 'z(t-1) T-Test Pvalue Ct T-Test D T-Test F-Test Pvalue', Names);
   table0= charcat(' ', '-', [' Augmented Dickey-Fuller Tests (lags= ' int2str(lags) ', NO CONSTANT, NO TREND): '], ...
       '-', ' T-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ', ...
       ' P values are approximate based on tables ', ...
       '-', table0(1, :), '-', table0(2 : end, :), '-');
   table1= charcat(' ', '-', ['Augmented Dickey-Fuller Tests (lags= ' int2str(lags) ', CONSTANT, NO TREND): '], ...
       '-', ' T-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ', ...
       [' F-Test is for H0: Rho= 1 and Ct= 0. DoF: 2 and ' int2str(T-pj-size(X, 2)+1) ' '], ...
       '-', table1(1, :), '-', table1(2 : end, :), '-');
   textoutputWINDOW(charcat([table0 char(abs(' ')*ones(size(table0, 1), 1))], ' ', ...
       [table1 char(abs(' ')*ones(size(table1, 1), 1))], ' ', ' ', '-', ...
       [' Augmented Dickey-Fuller Tests (lags= ' int2str(lags) ', CONSTANT AND TREND): '], '-', ...
       ' T-Test for z(t-1) is H0: Rho= 1 (Series is integrated) ', ...
       [' F-Test is for H0: Rho= 1 and D= 0. DoF: 2 and ' int2str(T-pj-size(X, 2)) ' '], ...
       '-', table2(1, :), '-', table2(2 : end, :), '-'), ...
       'Augmented Dickey-Fuller Tests');
end   

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
        'callback', ['if optionsET({''Lags for ADF tests (it can be a row vector) [1, Inf):''}, 1, 16);' ...
            'ADFtest([], [], [], 2);end ']);
end

