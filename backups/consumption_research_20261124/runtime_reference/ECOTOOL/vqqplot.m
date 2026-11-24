function vqqplot(z, Names, win, seriesval)
% vqqplot   Histogram with gaussian distribution and non-parametric estimate
%
%    vqqplot(y)
%
% INPUTS:
%   y: (*) Vector time series data (m x T or T x m)
% 
% See Also: vhist, gausstest


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
%    if strcmp(get(gcf,'name'), 'Text Output Window')
%        fig= get(0, 'CurrentFigure')-1;
%        if fig== 0, figure, else, figure(fig); end
%    end
   clf;
   set(gcf, 'number', 'off', 'name', 'QQ Plot Tool', 'userdata', {z, [], Names}, 'toolbar', 'figure');
end

% Setting up Menu Series
if win< 2
	if m>1
       MENU_H= findall(gcf, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'vqqplot([], [], 2);');
       end      
	end
end
delete(findall(gcf, 'label', '&Options'));

% Plotting figure
strlabel= strrep(Names(seriesval, :), ' ', '');

clearscreen;
zi= sort(z(:, seriesval));
Dist= 'Normal'; varargin{1}= nanmean(zi); varargin{2}= nanstd(zi);

rz= size(zi, 1);
emppc= (0.5/rz : 1/rz : 1-0.5/rz)';
qtheo= norminv(emppc, varargin{:});

plot(qtheo, zi, 'k*')

x1= [prctileECO(qtheo, 25) prctileECO(qtheo, 75)];
y1= [prctileECO(zi, 25) prctileECO(zi, 75)];
beta= (diff(y1))/(diff(x1));
yini= x1(1) - (x1(1) - qtheo(1))*beta;
yend= x1(2) + (qtheo(end) - x1(2))*beta;
line([qtheo(1) qtheo(end)], [yini yend], 'color', 'r', 'linesty', ':')
line(x1, y1, 'color', 'r', 'linew', 2)
line(x1, y1, 'color', 'r', 'marker', 'o', 'linew', 2)

title(['Series ' strlabel ': Empirical Quantiles vs Gaussian Theoretical Quantiles'])
xlabel([Dist ' Theoretical Quantiles'])
ylabel('Empirical Quantiles')
