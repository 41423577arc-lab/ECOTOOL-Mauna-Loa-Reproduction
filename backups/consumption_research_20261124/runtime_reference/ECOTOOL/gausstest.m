function [vBJ, PvBJ]= gausstest(z, dec, Names, win);
% gausstest   Gaussianity tests
%
%    gausstest(y, dec)
%
% INPUTS:
%   y:   (*) Vector time series data (m x T or T x m)
%   dec: Number of decimals for table output (1 x 1)
% 
% See Also: vhist, vqqplot

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
    [z, Names, dec, seriesval]= auxtestGUI;
    dec= dec{5}{1};
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

if nargin< 2, dec= 4; end
dec= dec(:)';
ld= size(dec, 2); dec= [dec dec(1, end)*ones(1, m-ld)];

% Bera-Jarque Test
skew= zeros(m, 1); kurto= skew;
NMiss= (~isnan(z));
for i=1:m
   zi= z(find(NMiss(:, i)), i);
   skew(i)= skewness(zi);
   kurto(i)= kurtosis(zi)-3;
end
beraj= T/6*(skew.^2+(kurto.^2)/4);
Pvalue= 1-chi2cdf(beraj, 2);
if m> 1
   vBJ= T*skew'*skew/6+T*kurto'*kurto/24;
   PvBJ= 1-chi2cdf(vBJ, 2*m);
end

% Kolmogorov-Smirnov-Lilliefors test
mz= nanmean(z);
stdz= nanstd(z);

Tn= (1:30)';
Pvalues= [0.2 0.15 0.1 0.05 0.01];
table= [nan nan nan nan nan
    nan nan nan nan nan
    nan nan nan nan nan
    nan nan nan nan nan
    .300 .319 .352 .381 .417
    .285 .299 .315 .337 .405
    .265 .277 .294 .319 .364
    .247 .258 .276 .300 .348
    .233 .244 .261 .285 .331
    .223 .233 .249 .271 .311
    .215 .224 .239 .258 .294
    .206 .217 .230 .249 .284
    .199 .212 .223 .242 .275
    .190 .202 .214 .234 .268
    .183 .194 .207 .227 .261
    .177 .187 .201 .220 .257
    .173 .182 .195 .213 .250
    .169 .177 .189 .206 .245
    .166 .173 .184 .200 .239
    .163 .169 .179 .195 .235
    .160 .166 .174 .190 .231
    .158 .163 .172 .188 .225
    .156 .161 .170 .186 .220
    .153 .158 .169 .184 .214
    .151 .156 .167 .182 .209
    .149 .153 .165 .180 .203
    .145 .150 .161 .176 .200
    .142 .146 .157 .172 .197
    .138 .143 .152 .169 .193
    .135 .139 .148 .165 .190
    .131 .136 .144 .161 .187 ];

Nmiss= ~isnan(z);
D= zeros(m, 1); Dc= zeros(m, 1);
for i= 1:m
   zi= sort(z(find(Nmiss(:, i)), i));
   Ti= size(zi, 1);
   Zemp= (1 : Ti)'/Ti;
   Zth=  normcdf(zi, mz(i), stdz(i));
   D(i)= max(abs(Zemp-Zth));
   if Ti> 30
      tablei= [.736/sqrt(Ti) .768/sqrt(Ti) .805/sqrt(Ti) .886/sqrt(Ti) 1.031/sqrt(Ti)];
   else
      tablei= table(Ti, :);
   end
   Dc(i)= interpol(tablei', Pvalues', D(i), [0 1]);
end

% Output results
TITLE= 'Skewness Kurtosis(-3) Bera-Jarque P-value KSLilliefors P-value';
table= printwf([skew kurto beraj Pvalue D Dc ], dec, TITLE, Names);
if m> 1
    table2= printwf([vBJ PvBJ], dec, 'Multivariate_Bera-Jarque P-value');
    textoutputWINDOW(charcat('-', 'Bera-Jarque and Kolmogorov-Smirnov Lilliefors (KSL) gaussianity tests. ', '-', ...
        'H0: Distribution is gaussian. ', '(Assumptions: Independence) ', '(Approximate P-value for KSL test). ', ...
        '-', table(1, :), '-', table(2 : end, :), '-', ' ', '-', table2(1, :), '-', table2(2 : end, :), '-'), ...
        'Gaussianity tests');
else
    textoutputWINDOW(charcat('-', 'Bera-Jarque and Kolmogorov-Smirnov Lilliefors (KSL) gaussianity tests. ', '-', ...
        'H0: Distribution is gaussian. ', '(Assumptions: Independence) ', '(Approximate P-value for KSL test). ', '-', ...
        table(1, :), '-', table(2 : end, :), '-'), ...
        'Gaussianity tests');
end

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
        'callback', ['if optionsET({''Number of decimals [0, Inf):''}, 0, 5);' ...
            'gausstest([], [], [], 2); end']);
end
