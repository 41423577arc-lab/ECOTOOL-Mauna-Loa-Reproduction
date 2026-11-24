function sumstats(z, dec, Names, gaussian, Nsimul, win);
% sumstats   Summary descriptive statistics
%
%    sumstats(y, dec)
%
% INPUTS:
%   y:   (*) Vector time series data (m x T or T x m)
%   dec: Number of decimals for table output (1 x 1)
% 
% See Also: plotband, vboxplot, vtboxplot, vscatter

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
    seriesval= seriesval(1);
    gaussian= dec{5}{2};
    Nsimul= dec{5}{3};
    dec= dec{5}{1};
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

if nargin< 5, Nsimul= 3000; end
if nargin< 4, gaussian= 1; end
if nargin< 2, dec= 4; end
dec= dec(:)';
ld= size(dec, 2); dec= [dec dec(1, end)*ones(1, m-ld)];
if gaussian== 1, textgauss= 'Gaussian '; else, textgauss= 'Empirical'; end

value= zeros(21, m);
NMiss= (~isnan(z));
for i=1:m
   zi= z(find(NMiss(:, i)), i);
   if all(zi > 0), value(8, i)= geomean(zi); else, value(8, i)= nan; end
   value(4, i)= prctileECO(zi, 10);
   value(5, i)= prctileECO(zi, 25);
   value(11, i)= prctileECO(zi, 75);
   value(12, i)= prctileECO(zi, 90);
   ind= find(abs(zi)>1e-5); li= length(ind);
   value(9, i) = 1./(sum(ones(li, 1)./zi(ind))/li);
   value(18, i)= mad(zi);
   value(21, i)= skewness(zi);
   value(22, i)= kurtosis(zi)-3;
end
value(1, :)= ones(1, m)*T;
value(2, :)= sum(isnan(z));
value(3, :)= nanmin(z);
value(10, :)= nanmedian(z);
% value(11, :)= prctileECO(z, 75);
% value(12, :)= prctileECO(z, 90);
value(13, :)= nanmax(z);
value(14, :)= value(11, :)-value(5, :); %iqr(z);
value(15, :)= value(12, :)-value(4, :); %range(z);
value(6, :)= nanmean(z);
value(16, :)= nanstd(z);
stats= value(6, :)./(value(16,:)./(sqrt(value(1, :)-value(2, :))));
if gaussian
    value(7, :)= 1-tcdf(abs(stats), value(1, :)-value(2, :)-1);
else
    value(7, :)= auxsumstats(z, stats, Nsimul);
end
value(17, :)= value(16, :).^2;
value(19, :)= meda(z);
value(20, :)= value(6, :)./value(16, :);

firstcol= ['Data points:               ';
          'Missing:                   ';
          'Minimum:                   ';
          '10% percentile:            ';
          '25% percentile:            ';
          'Mean:                      ';
          ['P(Mean= 0, ' textgauss ')      '];
          'Geometric Mean:            ';
          'Harmonic Mean:             ';
          'Median:                    ';
          '75% percentile:            ';
          '90% percentile:            ';
          'Maximum:                   ';
          'Interquartile Range:       ';
          'Range:                     ';
          'Standard Deviation:        ';
          'Variance:                  ';
          'Mean Absolute Deviation:   ';
          'Median Absolute Deviation: ';
          'Mean/Standard Deviation:   ';
          'Skewness:                  ';
          'Kurtosis (-3):             '];

table= printwf(value, dec, Names, firstcol);
table= charcat('-', table(1, :), '-', table(2 : 3, :), '-', table(4 : 14, :), '-', table(15 : 21, :), '-', table(22 : end, :), '-');

if m> 1
    seacf0= 1/sqrt(T)*ones(m);
    sacf0= nancov(transform(z));
    colspace= char(abs(' ')*ones(m+1, 3)); colline= [' '; char(abs('|')*ones(m, 1))];
    table1= [colspace printwf(sacf0, dec, Names, Names) colspace colline colspace [colspace(1 : end-1, 1)'; signif(sacf0./seacf0)] colspace(:, 1)];
    textoutputWINDOW(charcat(table, ' ', ' ', '-', 'Correlation Matrix: ', '-', table1(1, :), '-', table1(2:end, :), '-'), ...
        'Summary Statistics');
else
    textoutputWINDOW(table, 'Summary Statistics');
end

delete(findall(gcf, 'label', '&Options'));
% if win> 0
%     uimenu(gcf, 'label', '&Options', ... 
%         'callback', ['if optionsET({''Number of decimals [0, Inf):''}, 0, 5);' ...
%             'sumstats([], [], [], 2); end']);
% end
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
        'callback', ['if optionsET({''Number of decimals [0, Inf):'',' ...
        '''Gaussian / Empirical distribution (1/0):'', ''Simulations for mean test [0, Inf):''},' ...
        '[0 Inf; 0 1; 0 Inf], [5 1; 5 2; 5 3]);' ...
            'sumstats([], [], [], [], [], 2); end']);
end

   
   
   
   
   