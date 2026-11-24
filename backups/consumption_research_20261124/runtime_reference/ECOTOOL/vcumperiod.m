function vcumperiod(z, Names, win, seriesval)
% vcumperiod   Cumulative periodogram
%
%    vcumperiod(y)
%
% INPUTS:
%   y:        (*) Vector time series data (m x T or T x m)
% 
% See Also: vspectrum, varspectrum

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
   set(gcf, 'number', 'off', 'name', 'Cumulative Periodogram Tool', 'userdata', {z, [], Names}, 'toolbar', 'figure');
end

% Setting up Menu Series
if win< 2
	if m>1
       MENU_H= findall(gcf, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'vcumperiod([], [], 2);');
       end      
	end
end
delete(findall(gcf, 'label', '&Options'));

% Plotting figure
strlabel= strrep(Names(seriesval, :), ' ', '');

clearscreen;
T2= floor(T/2);
Thalf= (0 : T2)';
w= 2*pi*Thalf/T;

% Periodogram
cumP= nan*ones(T2+1, 1);
t= (1 : T)'; Td2= 2/T;
Miss= isnan(z(:, seriesval));
if sum(Miss)
   wwaitfor(fix((T2+1)/40));
   for j= 1 : T2+1
      if rem(j, 40)== 0, if wwaitfor; break; end, end
      aj= nansum(z(:, seriesval).*cos(w(j)*t));
      bj= nansum(z(:, seriesval).*sin(w(j)*t));
      cumP(j)= Td2*(aj.^2 + bj.^2);
   end
   ind= find(~(isnan(cumP)));
   cumP(ind)= cumsum(cumP(ind))/nancov(z(:, seriesval))/T;
   wwaitfor(0);
else
   fftz= fft(z(:, seriesval)); fftz= fftz.*conj(fftz)/T*2;
   cumP= nancumsum(fftz(1 : T2+1))/nancov(z(:, seriesval));
end
if ~isnan(cumP(end)), cumP= cumP/cumP(end); end
conf= [1.63/sqrt(T2) 1.36/sqrt(T2)];

plot(w/2/pi, cumP, 'k');
line([0 0.5], [0 1], 'color', 'r');
line([0 0; 0.5 0.5], [-conf(1) conf(1); 1-conf(1) 1+conf(1)], 'color', 'r', 'lines', ':');
line([0 0; 0.5 0.5], [-conf(2) conf(2); 1-conf(2) 1+conf(2)], 'color', 'k', 'lines', ':');
line(w/2/pi, cumP, 'color', 'k');
xlabel('Frequency');
ylabel('Cumulative Power')
axis([0 0.5 nanmin(nanmin(cumP), -conf(1)) nanmax(nanmax(cumP), 1+conf(1))]);
title(['Series ' strlabel ': Cumulative Periodogram (1% red; 5% black)']);