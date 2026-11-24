function testhet(z, timecuts, Names, win, seriesval)
% TESTHET   Heteroskedasticity tests
%    testhet(z, timecuts)
%
% INPUTS:
%   z:        (*) Vector time series data (m x T or T x m)
%   timecuts: Samples at which the full sample is divided to calculate variances
%             It may be a scalar (1 x 1) a vector (n x 1) or a matrix n x 2
%               Scalar: sample for each time series is divided into two non-overlapping subsamples
%               Vector (n x 1): sample is divided in n+1 non-overlapping subsamples
%               Matrix (n x 2): sample is divided in n non-overlapping subsamples from the
%                               samples in the first column up to the ones in the second column
%
% See Also: vcusum, stdmean, vboxcox, vboxcoxinv
%   
% Examples: 
%   testhet(z);
%   testhet(z, 50);
%   testhet(z, [40 80]);
%   testhet(z, [1 30; 50 90; 100 200]);

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


% win= 0: running independently
% win= 1: running from testtool
% win= 2: running form Series menu

if nargin< 5, seriesval= 1; end

if nargin< 4, win= 0; end

if win> 0
    [z, Names, timecuts, seriesval]= auxtestGUI;
    if size(timecuts, 2)== 1, timecuts= timecuts{1}{1}; else, timecuts= timecuts{14}{1}; end
    seriesval= seriesval(1);
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 3, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 2, timecuts= [floor(T/3) floor(2*T/3)+2]; end
if isempty(timecuts), timecuts= [floor(T/3) floor(2*T/3)+2]; end
[rt, ct]= size(timecuts);
if any([rt ct]== 1)
    timecuts= sort(timecuts(:));
    indx= [find(timecuts<5); find(timecuts> T-5)];
    timecuts(indx)= [];
    if ~isempty(timecuts), timecuts= [[1; timecuts+1] [timecuts; T]]; end
else
    timecuts= sort(timecuts')';
    timecuts= sortcol(timecuts, 1);
    indx= [find(timecuts(2 : end, 1)<5); find(timecuts(:, 1)> T-5)];
    timecuts(indx, :)= [];
    indx= 1+find(diff(timecuts(: ,2))< 0);
    timecuts(indx, :)= [];
    indx= find((timecuts(2 : end, 1)-timecuts(1 : end-1, 2))< 0)+1;
    timecuts(indx, :)= [];
end
[rt, ct]= size(timecuts);
if (isempty(timecuts) | any([rt ct]== 1))
    i1= floor(T/3);
    i2= floor(2*T/3)+2;
    timecuts= [1 i1; i1+1 i2; i2+1 T];
end
[rt, ct]= size(timecuts);

% Output
table= zeros(sum(1 : rt-1), 2);
tablet= charcat(' ', '-', ' Variance Ratio Tests ', '-', ' H0: Variances are the same (homoskedasticity). ', ...
    ' (Assumptions: Independence and Normality) ');
for seriesval= 1 : m
	fcol= []; k= 1; 
    for i= 1 : rt-1
        for j= i+1 : rt
            fcol= char(fcol, ['Samples (' int2str(timecuts(i, 1)) ' - ' int2str(timecuts(i, 2)) ') / ' ...
                    '(' int2str(timecuts(j, 1)) ' - ' int2str(timecuts(j, 2)) '):']);
            table(k, 1)= nancov(z(timecuts(i, 1) : timecuts(i, 2), seriesval))/nancov(z(timecuts(j, 1) : timecuts(j, 2), seriesval));
            dofnum= timecuts(i, 2)-timecuts(i, 1)-sum(isnan(z(timecuts(i, 1) : timecuts(i, 2), seriesval)))-1;
            dofden= timecuts(j, 2)-timecuts(j, 1)-sum(isnan(z(timecuts(j, 1) : timecuts(j, 2), seriesval)))-1;
            if table(k, 1)> 1
                table(k, 1)= 1/table(k, 1);
                pp= dofden; dofden= dofnum; dofnum= pp;
            end
            table(k, 2)= fcdf(table(k, 1), dofnum, dofden)*2;
            k= k + 1;
        end
	end
    table1= printwf(table, 4, 'F-Test P-value', fcol(2 : end, :));
    tablet= charcat(tablet, '-', [' Series ' Names(seriesval, :) ': '], '-', table1(1, :), '-', table1(2 : end, :), '-', ' ', ' ');
end
textoutputWINDOW(tablet, 'Heteroskedasticity Tests');

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
       'callback', ['if optionsET({''Time cuts for tests (nx1 or nx2) [5, T-5]:''}, 1, 14);' ...
           'testhet([], [], [], 2); end']);
end
