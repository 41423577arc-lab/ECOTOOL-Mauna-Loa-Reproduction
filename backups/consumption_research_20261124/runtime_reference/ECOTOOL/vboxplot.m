function vboxplot(z, s, Names, win, seriesval)
% vboxplot   Vector Time Series boxplot
%
%    vboxplot(y, s)
%
% INPUTS:
%   y: (*) Vector time series data (m x T or T x m)
%   s: Seasonal period for subplots (1 x 1)
% 
% See Also: plotband, vtboxplot, vscatter, sumstats

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
% win= 2:  run from menu Series callback
% win= 3:  run from <<< plotband button
% win= 4:  run from >>> plotband button
% win= 5:  run from edit vboxplot uicontrol

if nargin< 4, win= 0; end

if nargin< 5, seriesval= 1; end

value= 0;
if win> 0
    [z, Names, s, seriesval, h_series, e_handle, value, b_handles]= auxtestGUI;
    if isempty(value), value= 0; end
    seriesval= seriesval(1);
    s= s{1}{1};
end

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end

if nargin< 2, s= 12; end
if isempty(s), s= 12; end
s= min(s, fix(T/2));
seriesval= min(seriesval, m);

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 3, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if win== 0
   if strcmp(get(gcf,'name'), 'Text Output Window')
       figs= findobj(0, 'type', 'figure');
       fig= max(figs.Number);
       if fig== 1, figure, else, figure(fig); end
   end
%   if strcmp(get(gcf,'name'), 'Text Output Window')
%       fig= get(0, 'CurrentFigure')-1;
%       if fig== 0, figure, else, figure(fig); end
%   end
   clf;
   set(gcf, 'number', 'off', 'name', 'Boxplot Tool', 'userdata', {z, {{s}}, Names}, 'toolbar', 'figure');
end

% Setting up Menu Series and additional uicontrols
if win< 2
	if m>1
       MENU_H= findall(gcf, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'vboxplot([], [], [], 2);');
       end      
	end
	% Setting up additional uicontrols
    clearscreen;
    buttonl= uicontrol('units', 'norm', ...
                       'string', '<<<', ...
                       'position', [0.3 0.01 0.1 0.05], ...
                       'enable', 'off', ...
                       'callback', 'vboxplot([], [], [], 3);');
    buttonr= uicontrol('units', 'norm', ...
                       'string', '>>>', ...
                       'position', [0.6 0.01 0.1 0.05], ...
                       'callback', 'vboxplot([], [], [], 4);');
    e_handle= uicontrol('style', 'edit', ...
                     'backg', 'w', ...
                     'units', 'norm', ...
                     'string', '0', ...
                     'position', [0.4 0.01 0.2 0.05], ...
                     'userdata', [' (out of ' int2str(s)  ')'], ...
                     'callback', 'vboxplot([], [], [], 5);');
     b_handles= [buttonl buttonr];
end
MENUopt= findall(gcf, 'label', '&Options');
if (win== 1)
	 if isempty(MENUopt), MENUopt= uimenu('label', '&Options', 'userdata', []); end
     set(MENUopt, 'callback', ['if optionsET({''Enter the seasonal period for Box Plots [2, Inf):''}, 2, 1);' ...
           'vboxplot([], [], [], 2); end']);
end

% What to do when hitting the additional uicontrols
maxX= s;

if win>= 2
    set(e_handle, 'userdata', [' (out of ' int2str(s)  ')']);
    value= max(value, 0);
    value= min(value, s);
end

if win== 3                            % <<< button
    value= max(0, value-1);
elseif win== 4                        % >>> button
    value= min(value+1, maxX);
elseif win== 5                        % Edit button
    value= max(0, value);
    value= min(value, maxX);
end

if value== 0
    set(b_handles(1), 'enable', 'off');
    set(b_handles(2), 'enable', 'on');
    str= ['0' get(e_handle, 'userdata')];
    sample= [];
else
    str= [int2str(value) get(e_handle, 'userdata')];
    set(b_handles, 'enable', 'on');
    if value== maxX, set(b_handles(2), 'enable', 'off'); end
    sample= (value : s : T)';
end
set(e_handle, 'string', str)

% Plotting figure
strtitle= strrep(Names(seriesval, :), ' ', '');

if win< 3
    cTs= ceil(T/s);
    zi= reshape([z(:, seriesval); nan*ones(cTs*s-T, 1)], s, cTs);
    t= (1 : size(zi, 2))';

	HH= plot(t, nanmean(zi)', 'r', t, nanmedian(zi)', 'k', t, [prctileECO(zi, 25)' prctileECO(zi, 75)'], 'r:', t, [nanmin(zi)' nanmax(zi)'], 'b*');
	set(HH(1:2), 'linew', 2);
	v= axis; axis([0 t(end)+1 v(3 : 4)]);

    l_handle= line(t, nan*ones(size(t)), 'color', 'k', 'marker', '.', 'tag', 'this');
    tt= (1 : size(sample, 1))';
    set(l_handle, 'xdata', tt, 'ydata', z(sample, seriesval));

    legend(HH([1 2 3 5]), 'Mean', 'Median', '25% and 75% Percentiles', 'Maximum and Minimum', 'location', 'best')
	
    title(['Series ' strtitle ': Box Plot (every ' int2str(s) ' samples apart)'])
    xlabel(['Groups of every ' int2str(s) ' samples apart']);
    ylabel(['Values of Series ' strtitle])
else
    l_handle= findall(gca, 'tag', 'this');
    tt= (1 : size(sample, 1))';
    set(l_handle, 'ydata', z(sample, seriesval), 'xdata', tt);
end
