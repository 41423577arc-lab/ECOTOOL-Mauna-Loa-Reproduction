function varspectrum(z, smooth, nfreq, xlog, Names, win, seriesval)
% varspectrum   AR spectrum
%
%    varspectrum(y, order, nfreq, xlog)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   order: Order of AR model (1 x 1)
%   nfreq: Number of frequencies to estimate the spectrum 
%          (1 x 1, use 0 or T/2 for periodogram frequencies)
%   xlog:  Frequency and Power axis log on/off (1 x 2)
%          [0 0]: linear scale for both axes
%          [1 0]: log scale for frequency axis
%          [0 1]: log scale for power axis
%          [1 1]: log scale for both axes
% 
% See Also: vcumperiod, vspectrum

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
% win= 2: running from Series menu
% win= 3: running from Options menu

if nargin< 7, seriesval= 1; end

if nargin< 6, win= 0; end

if win> 0
    [z, Names, opts, seriesval]= auxtestGUI;
    if size(opts, 2)== 1, indx= 1; else, indx= 25; end
    smooth= opts{indx}{1}; nfreq= opts{indx}{2}; xlog= opts{indx}{3};
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end
seriesval= min(seriesval, m);

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 5, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 4, xlog= [0 1]; end
if isempty(xlog), xlog= [0 1]; end

T2= floor(T/2);
if nargin<3, nfreq= []; end
if isempty(nfreq)
   freq= 2*pi*(0 : T2)'/T;
else
   if nfreq== 0
      freq= 2*pi*(0 : T2)'/T;
   else
      if nfreq< 10, nfreq= floor(T/2); end
      freq= (0 : pi/nfreq : pi-pi/nfreq)';
   end
end
freq= freq(:);
T2= size(freq, 1)-1;

if nargin<2, smooth= 16; end
if isempty(smooth), smooth= 16; end
smooth= min(floor(T/2), smooth);
smooth= max(smooth, 1);

if win== 0
   if strcmp(get(gcf,'name'), 'Text Output Window')
       figs= findobj(0, 'type', 'figure');
       fig= size(figs, 1);
       if strcmp(get(fig,'name'), 'Text Output Window') && fig> 1
           fig= fig-1;
       end
       if fig== 1, figure, else, figure(fig); end
   end
%   if strcmp(get(gcf,'name'), 'Text Output Window')
%       fig= get(0, 'CurrentFigure')-1;
%       if fig== 0, figure, else, figure(fig); end
%   end
   clf;
   set(gcf, 'name', 'Vector Autoregression Spectrum tool', 'userdata', {z, {{smooth, freq, xlog}}, Names}, 'toolbar', 'figure');
end

% Calculations
[P, seP, Sigma, AIC, SBC, e, ARpoly, C]= mVAR(z(:, seriesval), (1 : smooth), 1);
cumP= freqz(1, [1 -P(1 : end-1)'], freq); cumP= pi*real(cumP.*conj(cumP));

% Plotting figure
clearscreen;
strlabel= strrep(Names(seriesval, :), ' ', '');
if all(xlog== [0 0])
    plot(freq, cumP, 'k');
    v= axis; axis([0 pi v(3 : 4)]);
    xlabel('Period'), ylabel('Power')
    periodaxis;
elseif all(xlog== [0 1])
    plot(freq, log10(cumP), 'k');
    v= axis; axis([0 pi v(3 : 4)]);
    xlabel('Period'), ylabel('Log10(Power)')
    periodaxis;
elseif all(xlog== [1 0])
    indx= find(freq== 0); freq(indx)= 1;
    freq= log10(freq); freq(indx)= Inf;
    plot(freq, cumP, 'k');
    v= axis; axis([v(1) log10(pi) v(3 : 4)]);
    xlabel('log10(Period)'), ylabel('Power')
    periodaxis(v(1));
elseif all(xlog== [1 1])
    indx= find(freq== 0); freq(indx)= 1;
    freq= log10(freq); freq(indx)= Inf;
    plot(freq, log10(cumP), 'k');
    v= axis; axis([v(1) log10(pi) v(3 : 4)]);
    xlabel('log10(Period)'), ylabel('log10(Power)')
    periodaxis(v(1));
end
str0= ''; str1= ' Spectrum '; str2= ' (No smoothing)';
if nfreq== 0, str1= ' Periodogram '; end
if smooth> 1, str0= 'Smoothed'; str2= [' (Triangular window of length ' int2str(smooth) ')']; end
title(['Series ' strlabel ': AR Spectrum(' int2str(smooth) ')']);
plotw= gcf;
    
% Setting up Menu Series and Options
if win< 2
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu(plotw, 'label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
               'callback', 'varspectrum([], [], [], [], [], 2);');
       end
%       if m> 1
%           uimenu(MENU_H, 'label', 'Multivariate', ...
%               'callback', 'vspectrum2([], [], [], [], [], 1);');
%       end
	end
end
MENUopt= findall(plotw, 'label', '&Options');
if win== 1
     if isempty(MENUopt), MENUopt= uimenu(plotw, 'label', '&Options', 'userdata', []); end
     set(MENUopt, 'callback', ['if optionsET({''Order for AR model [1, N/4]:'',' ...
       '''Number of divisions in frequency axis:'', ' ...
       '''Logaritmic or Linear Period and Power axis ([1/0 1/0]):''}, ' ...
       '[1; 10; 0], [25 1;25 2; 25 3]);' ...
       'varspectrum([], [], [], [], [], 3); end']);
end


% Auxiliary function
function periodaxis(logon)

if nargin< 1, logon= 0; end

if logon== 0
    set(gca, 'xtick', [0 2*pi./[12 6 4 3 2.4 2]]);
    set(gca, 'xticklabel', char('Inf', ' 12', ' 6 ', ' 4 ', ' 3 ', '2.4', ' 2 '));
else
    set(gca, 'xtick', [logon log10(2*pi./[12 6 4 3 2.4 2])]);
    set(gca, 'xticklabel', char('Inf', ' 12', ' 6 ', ' 4 ', ' 3 ', '2.4', ' 2 '));
end
