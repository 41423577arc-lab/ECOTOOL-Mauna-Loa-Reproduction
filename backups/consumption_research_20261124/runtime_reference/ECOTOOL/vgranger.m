function vgranger(z, lags, tests, Names, win)
% vgranger   Granger causality tests on VAR models
%
%    vgranger(y, lags, tests)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   lags:  Vector of lags to include in VAR model (block constraints 
%          are possible, 1 x any)
%   tests: Type of tests to perform (string)
%          Variables are indicated by letters in alphabetical order, 
%          each test is separated by one space, '-' separates 
%          endogenous from exogenous.
%          'a-b b-a':  two tests, i.e. second variable causes first 
%                      and viceversa
%          'a-bc bc-a': two tests, i.e. second and third variable 
%                       cause the first one and first variable causes second and third
%
% Examples:
%   vgranger(y);
%   vgranger(y, [3 10]);
%   vgranger(y, [1 : 10], 'a-b ab-c');
% 
% See Also: vident, vident2, varsbc

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 5, win= 0; end

if win> 0
    [z, Names, lags, seriesval]= auxtestGUI;
    tests= lags{11}{2};
    lags= lags{11}{1}; lags= lags(:)';
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
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 2, lags= (1 : min([fix(sqrt(T)) 20])); end
if isempty(lags), lags= (1:min([fix(sqrt(T)) 20])); end
lags= lags(:)';
if lags(end)> T/2
    lags= [1:2];
end
nlags= size(lags, 2);

ini= abs('a');
t1= repmat((1:m)', m, 1);
t2= repmat((1:m), m, 1);  t2= t2(:);
ind= find(t1== t2);
t1(ind)= []; t2(ind)= [];
testsdef= [char(t1+ini-1) char(repmat(abs('-'), m*(m-1), 1)) char(t2+ini-1)];
if nargin< 3, tests= ''; end
if isempty(tests)
    tests= testsdef;
elseif size(tests, 1)== 1
    tests= divstring(tests);
end
ntests= size(tests, 1);

% Check tests input
indeliminate= [];
for i= 1 : ntests
    testsi= strrep(tests(i, :), ' ', '');
    if isempty(testsi), indeliminate= [indeliminate; i]; end
    ind= findstr(testsi, '-');
    if isempty(ind), indeliminate= [indeliminate; i]; end
    ind= findstr(testsi, ' -');
    if ~isempty(ind), indeliminate= [indeliminate; i]; end
    ind= findstr(testsi, '- ');
    if ~isempty(ind), indeliminate= [indeliminate; i]; end
    testsi= strrep(testsi, '-', '');
    let= 0;
    for j= 1 : size(testsi, 2)
        testsij= abs(testsi(j));
        if (testsij< ini | testsij> ini+m-1), indeliminate= [indeliminate; i]; end
        if any((let-testsij)== 0), indeliminate= [indeliminate; i]; end
        let= [let abs(testsij)];
    end
end
tests(indeliminate, :)= [];
if isempty(tests), tests= testsdef; end
ntests= size(tests, 1);

wwaitfor(ntests+1);
[P, sdP, cu, AIC, SBC, e, ARpoly, C, izz]= mVAR(z-repmat(nanmean(z), T, 1), lags, 0);
wwaitfor;

npar= m*m*nlags;
table= nan*ones(ntests, 4); label= '';
for i= 1 : ntests
    if wwaitfor, break; end
    testi= strrep(tests(i, :), ' ', '');
    ind= findstr(testi, '-');
    t1= testi(ind + 1 : end); l1= size(t1, 2);
    t2= testi(1 : ind - 1); l2= size(t2, 2);
    nconst= l1*l2*nlags;
    C= zeros(nconst, npar);
    k= 1; label1= ''; label2= '';
    for i1= 1 : l1
        t1i1= abs(t1(i1)-ini+1);
        if isempty(label1)
            label1= strrep(Names(t1i1, :), ' ', '');
            verb= 'does';
        else
            label1= [label1 ', ' strrep(Names(t1i1, :), ' ', '')];
            verb= 'do';
        end            
        for i2= 1 : l2
            t2i2= abs(t2(i2)-ini+1);
            if i1== 1
                if isempty(label2)
                    label2= strrep(Names(t2i2, :), ' ', '');
                else
                    label2= [label2 ', ' strrep(Names(t2i2, :), ' ', '')];
                end
            end
            for i3= 1 : nlags
                C(k, (t1i1-1)*m+t2i2+(i3-1)*m*m)= 1;
                k= k + 1;
            end
        end
    end
    ind= max(findstr(label1, ','));
    if ~isempty(ind), label1= [label1(1 : ind-1) ' and' label1(ind+1 : end)]; end
    ind= max(findstr(label2, ','));
    if ~isempty(ind), label2= [label2(1 : ind-1) ' and' label2(ind+1 : end)]; end
    label= char(label, [label1 ' ' verb ' not cause ' label2]);
    beta= -P'; beta= beta(:);
    Cbeta= C*beta;
    df= [nconst T*m-npar+m*m];
    table(i, 1)= nconst;
    table(i, 2)= Cbeta'*inv(C*izz*C')*Cbeta/nconst;
    table(i, 3)= 1 - fcdf(table(i, 2), df(1), df(2));
    table(i, 4)= table(i, 2)*nconst;
    table(i, 5)= 1 - chi2cdf(table(i, 4), nconst);
end
wwaitfor(0);
tablet= printwf(table, [0 4], 'Constraints F-Stat P-value Chi-stat P-value', label(2 : end, :));
tablet(1, 9:10)= 'H0';

if max(lags)== nlags, const= ''; else, const= 'CONSTRAINED '; end
textoutputWINDOW(charcat(' ', '-', 'Granger Causality Tests ', '-', ['Based on a ' const 'VAR(' int2str(max(lags)) ') model '], ...
    '-', tablet(1, :), '-', tablet(2 : end, :), '-'), ...
    'Granger Causality Tests');

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
       'callback', ['if optionsET({''Number of lags for Granger Causality tests [1, Inf):'',' ...
       '''Type of test (string like ''''a-b ab-cd bd-c''''):''}, ' ...
       '[1; 0], [11 1; 11 2]);' ...
       'vgranger([], [], [], [], 3); end']);
end
