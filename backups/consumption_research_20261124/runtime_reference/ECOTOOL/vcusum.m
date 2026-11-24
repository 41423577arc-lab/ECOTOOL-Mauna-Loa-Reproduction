function vcusum(z, Names, win, seriesval)
% vcusum   CUSUM and CUSUM of squares tests
%
%    vcusum(y)
%
% INPUTS:
%   y: (*) Vector time series data (m x T or T x m)
% 
% See Also: stdmean, testhet, vboxcox, vboxcoxinv

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
% win= 2: running from series menu

if nargin< 4, seriesval= 1; end

if nargin< 3, win= 0; end

if win> 0
    [z, Names, bins, seriesval]= auxtestGUI;
    seriesval= seriesval(1);
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end
seriesval= min(seriesval, m);

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 2, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

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
   set(gcf, 'number', 'off', 'name', 'CUSUM and CUSUMSQ Tests Tool', 'userdata', {z, [], Names}, 'toolbar', 'figure');
end

% Setting up Menu Series
if win< 2
	if m>1
       MENU_H= findall(gcf, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'vcusum([], [], 2);');
       end      
	end
end
delete(findall(gcf, 'label', '&Options'));

% Plotting figure
strlabel= strrep(Names(seriesval, :), ' ', '');

clearscreen;
mz= nanmean(z(:, seriesval));
stdz= nanstd(z(:, seriesval));

NMiss= (~isnan(z(:, seriesval)));
Miss= isnan(z(:, seriesval));
standz= nan*ones(T, 1);  %size(z(:, seriesval)));
cusum= standz; cusumsq= standz;
NMissi= find(NMiss);
zmi= z(NMissi, seriesval)-mz;
standz(NMissi)= (zmi)./(stdz);
cusum(NMissi)= cumsum(standz(NMissi));
cusumsq(NMissi)= cumsum(zmi.^2/(sum(zmi.^2)));

T= size(cusum, 1);
t= (1 : T)';

bands= zeros(T, 2);
bands(:, 1)= [0.948*sqrt(T)+2*0.948*t/sqrt(T)];
bands(:, 2)= -bands(:, 1);

subplot(211)
plot(t, bands, 'r:', t, zeros(T, 1), 'r', t, cusum, 'k')
axis([1 T nanmin(nanmin([cusum bands])) nanmax(nanmax([cusum bands]))]); 
title(['Series ' strlabel ': CUSUM test with 5% Confidence Band'])
ylabel('CUSUM test')

wu = .948*sqrt(T) + 2*.948*t/sqrt(T);
bands= [-.32894 + t/T .32894 + t/T];
subplot(212)
plot(t, bands, 'r:', t, cusumsq, 'k')
line([t(1) t(T)], [nanmin(cusumsq) nanmax(cusumsq)], 'color', 'r')
axis([1 T min(nanmin([cusumsq bands])) max(nanmax([cusumsq bands]))]); 
title(['Series ' strlabel ': CUSUMSQ test with 5% Confidence Band'])
ylabel('CUSUMSQ test')
xlabel('Samples')


