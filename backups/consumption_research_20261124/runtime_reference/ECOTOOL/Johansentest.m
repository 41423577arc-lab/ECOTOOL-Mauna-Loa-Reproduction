function Johansentest(z, lags, Names, win)
% Johansentest   Johansen cointegration tests
% 
%    johansentest(y, lags)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%          For univariate time series the test is a unit root test
%   lags:  Maximum lag (1 x 1) or vector of lags (any x 1) to include 
%          in test regression
%   
% Examples: 
%   johansentest(z);
%   johansentest(z, 10);         
%   johansentest(z, (5 : 10), 3);
%
% See Also: ADFtest, vphillips

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

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 3, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

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
if lags(end)> T/2
    lags= fix(T/2);
end
if m== 1, ind= find(lags== 1); lags(ind)= []; end
nlags= size(lags, 2);

if m== 1
    ntests= nlags;
    H0= zeros(ntests, 1);
    tlook= ones(ntests, 1);
else
    ntests= 2*m-1;
	H0= repmat(0 : m-1, 2, 1); H0= H0(:); H0= H0(1 : end-1);
	H0st= [repmat('h= ', ntests, 1) int2str(H0) repmat('   -   ', ntests, 1)];
	H1= [1 : m; repmat(m, 1, m)]; H1= H1(:); H1= H1(1 : end-1);
	H1st= [repmat('h= ', ntests, 1) int2str(H1)];
	tlook= repmat((1 : 2)', m, 1); tlook= tlook(1 : end-1);
end
table= repmat(nan, ntests, 6);
table2= [(1 : m)' repmat(nan, m, 6)];

wwaitfor(3*nlags);
for i= 1 : nlags
    if m== 1, order= (1 : lags(i)-1); else, order= (1 : lags-1); end
    % No Trend, No constant
	[P, seP, sigma, AIC, SBC, U, ARpoly, C, covP, seARpoly, seC, Z, invXX]= mVAR(vdif(z), order, 0);
	tZ= size(Z, 1);
	P= invXX*nanprod(Z(:, m+1 : end)', z(end-tZ : end-1, 1:m));
	V= z(end-tZ : end-1, 1:m) - nanprod(Z(:, m+1 : end), P);
	UU= nanprod(U', U)/tZ;
	VV= nanprod(V', V)/tZ;
	UV= nanprod(U', V)/tZ;
	lambdas= flipud(sort(eig(inv(VV)*(UV')*inv(UU)*UV)));
	lik= -T*log(1 - lambdas);
	cumlik= flipud(cumsum(flipud(lik)));
	vvv= [lik cumlik]'; vvv= vvv(:); vvv= vvv(1 : end-1);
	if m== 1
        table(i, 1)= vvv;
    else
        table(:, 1)= vvv;
	    table2(:, 2 : 3)= [lambdas lik];
    end
	if wwaitfor, break; end
    
	% No Trend, with constant
	[P, seP, sigma, AIC, SBC, U, ARpoly, C, covP, seARpoly, seC, Z, invXX]= mVAR(vdif(z), order, 1);
	tZ= size(Z, 1); Z= [Z ones(tZ, 1)];
	P= invXX*nanprod(Z(:, m+1 : end)', z(end-tZ : end-1, 1:m));
	V= z(end-tZ : end-1, 1:m) - nanprod(Z(:, m+1 : end), P);
	UU= nanprod(U', U)/tZ;
	VV= nanprod(V', V)/tZ;
	UV= nanprod(U', V)/tZ;
	lambdas= flipud(sort(eig(inv(VV)*(UV')*inv(UU)*UV)));
	lik= -T*log(1 - lambdas);
	cumlik= flipud(cumsum(flipud(lik)));
	vvv= [lik cumlik]'; vvv= vvv(:); vvv= vvv(1 : end-1);
	if m== 1
        table(i, 3)= vvv;
    else
        table(:, 3)= vvv;
	    table2(:, 4 : 5)= [lambdas lik];
    end
	
	if wwaitfor, break; end
	% With Trend and constant
	timet= (1 : tZ)';
	Z= [Z timet];
	invXX= inv(nanprod(Z(:, m+1 : end)', Z(:, m+1 : end)));
	P= invXX*nanprod(Z(:, m+1 : end)', Z(:, 1:m));
	U= Z(:, 1:m) - nanprod(Z(:, m+1 : end), P);
	P= invXX*nanprod(Z(:, m+1 : end)', z(end-tZ : end-1, 1:m));
	V= z(end-tZ : end-1, 1:m) - nanprod(Z(:, m+1 : end), P);
	UU= nanprod(U', U)/tZ;
	VV= nanprod(V', V)/tZ;
	UV= nanprod(U', V)/tZ;
	lambdas= flipud(sort(eig(inv(VV)*(UV')*inv(UU)*UV)));
	lik= -T*log(1 - lambdas);
	cumlik= flipud(cumsum(flipud(lik)));
	vvv= [lik cumlik]'; vvv= vvv(:); vvv= vvv(1 : end-1);
	if m== 1
        table(i, 5)= vvv;
    else
        table(:, 5)= vvv;
	    table2(:, 6 : 7)= [lambdas lik];
    end
	if wwaitfor, break; end
end
wwaitfor(0);
table(:, 2)= johancritical(table(:, 1), m-H0, tlook, 1);
table(:, 4)= johancritical(table(:, 3), m-H0, tlook, 1);
table(:, 6)= johancritical(table(:, 5), m-H0, tlook, 1);

if m== 1
	table= printwf([lags(:) table], [0 4], 'Lags Stat1 P-value Stat2 P-value Stat3 P-value');
	textoutputWINDOW(charcat(' ', '-', [' Johansen Cointegration Tests '], '-', ...
        ' Stat1: test statistic based on model without deterministic parts ', ...
        ' Stat2: test statistic based on model including a constant term ', ...
        ' Stat3: test statistic based on model including a constant and linear trend ', ...
        ' Critical values are approximate based on tables ', '-', ...
        table(1, :), '-', table(2 : end, :), '-'), 'Johansen Cointegration Tests');
else
	table= printwf(table, 4, 'Stat1 P-value Stat2 P-value Stat3 P-value', [H0st H1st]);
	table(1, 2 : 15)= ' H0         H1';
	table= charcat(' ', '-', [' Johansen Cointegration Tests (lags= ' int2str(lags(end)) ') '], '-', ...
        ' ''h'' is the number of cointegrated relations ', ...
        ' Stat1: test statistic based on model without deterministic parts ', ...
        ' Stat2: test statistic based on model including a constant term ', ...
        ' Stat3: test statistic based on model including a constant and linear trend ', ...
        ' Critical values are approximate based on tables ', '-', ...
        table(1, :), '-', table(2 : end, :), '-');
	table2= printwf(table2, [0 4], 'i Eigen1 -T[1-l(i)] Eigen2 -T[1-l(i)] Eigen3 -T[1-l(i)]');
	textoutputWINDOW(charcat(table, ' ', ' ', ' ', '-', table2(1, :), '-', table2(2 : end, :), '-'), ...
        'Johansen Cointegration Tests');
end

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
        'callback', ['if optionsET({''Maximum lag for Johansen tests (it may be a row vector) [1, Inf):''}, 1, 16);' ...
            'Johansentest([], [], [], 2); end']);
end



% Auxiliary function
function output= johancritical(x, g, table, dist)
% dist= 1: T distribution, no trend, no constant
% dist= 2: T distribution, no trend, constant
% dist= 3: T distribution, trend, constant

% Standard tables
pvalue= [0.5 0.2 0.1 0.05 0.025 0.01]';
t1dist1= [0.58 1.82 2.86 3.84 4.93 6.51
    4.83 7.58 9.52 11.44 13.27 15.69
    9.71 13.31 15.59 17.89 20.02 22.99
    14.94 18.97 21.58 23.8 26.14 28.82
    20.16 24.83 27.62 30.04 32.51 35.17]';
t1dist2= [2.415 4.905 6.691 8.083 9.658 11.576
    7.474 10.666 12.783 14.595 16.403 18.782
    12.707 16.521 18.595 21.279 23.362 26.154
    17.875 22.341 24.917 27.341 29.599 32.616
    23.132 27.953 30.818 33.262 35.7 38.858]';
t1dist3= [0.447 1.699 2.816 3.962 5.332 6.936
    6.852 10.125 12.099 14.036 15.810 17.936
    12.381 16.324 18.697 20.778 23.002 25.521
    17.719 22.113 24.712 27.169 29.335 31.943
    23.211 27.899 30.774 33.178 35.546 38.341]';
t2dist1= [0.58 1.82 2.86 3.84 4.93 6.51
    5.42 8.45 10.47 12.53 14.43 16.31
    14.3 18.83 21.63 24.31 26.64 29.75
    27.1 33.16 36.58 39.89 42.3 45.58
    43.79 51.13 55.44 59.46 62.91 66.52]';
t2dist2= [2.415 4.905 6.691 8.083 9.658 11.576
    9.335 13.038 15.583 17.844 19.611 21.962
    20.188 25.445 28.436 31.256 34.062 37.291
    34.873 41.623 45.248 48.419 51.801 55.551
    53.373 61.566 65.956 69.977 73.031 77.911]';
t2dist3= [0.447 1.699 2.816 3.962 5.332 6.936
    7.638 11.164 13.338 15.197 17.299 19.31
    18.759 23.868 26.791 29.509 32.313 35.397
    33.672 40.25 43.964 47.181 50.424 53.792
    52.588 60.215 65.063 68.905 72.14 76.955]';

x= x(:); output= repmat(nan, size(x));
for i= 1 : size(x, 1)
    if table(i)== 1 & dist== 1
        tablei= t1dist1;
    elseif table(i)== 1 & dist== 2
        tablei= t1dist2;
    elseif table(i)== 1 & dist== 3
        tablei= t1dist3;
    elseif table(i)== 2 & dist== 1
        tablei= t2dist1;
    elseif table(i)== 2 & dist== 2
        tablei= t2dist2;
    elseif table(i)== 2 & dist== 3
        tablei= t2dist3;
    end
    if g(i)> 5
        output(i)= nan;
    else
        output(i)= interpol(tablei(:, g(i)), pvalue, x(i), [0; 1]);
    end
end
