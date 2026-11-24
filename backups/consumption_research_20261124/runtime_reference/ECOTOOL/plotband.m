function plotband(z, s, standard, fixed, Names, win, seriesval)
% plotband   Vector Time Series plot with confidence bands
%
%    plotband(y, s, standard, fixedscale)
%
% INPUTS:
%   y: (*)      Vector time series data (m x T or T x m)
%   s:          Seasonal period for subplots (1 x 1)
%   standard:   Standard plot on/off (1 / 0)
%   fixedscale: Fixed vertical scale on/off (1 / 0)
% 
% See Also: vboxplot, vtboxplot, vscatter, sumstats

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
% win= 5:  run from edit plotband uicontrol
% win= 6:  run from transpose data uicontrol

if nargin< 6, win= 0; end

if nargin< 7, seriesval= 1; end

value= -1;
if win> 0
    [z, Names, s, seriesval, h_series, e_handle, value, b_handles]= auxtestGUI;
    if isempty(value), value= 0; end
    seriesval= seriesval(1);
    standard= s{1}{2};
    fixed= s{1}{3};
    s= s{1}{1};
end

[T, m]= size(z);
% if T< m && T<20, z= z'; [T, m]= size(z); end

if nargin< 2, s= 12; end
if isempty(s), s= 12; end
s= min(s, T);

if nargin< 3, standard= 0; end
if isempty(standard), standard= 0; end

if nargin< 4, fixed= 1; end
if isempty(standard), fixed= 1; end

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 5, Names= []; end
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
   set(gcf, 'number', 'off', 'name', 'Plot Tool', 'userdata', {z, {{s, standard, fixed}}, Names}, 'toolbar', 'figure');
end

% Setting up Menu Series and additional uicontrols
if win< 2
	if m>1
       MENU_H= findall(gcf, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'plotband([], [], [], [], [], 2);');
       end      
       uimenu(MENU_H, 'label', 'All', ...
           'callback', 'plotband([], [], [], [], [], 2);');
	end
	% Setting up additional uicontrols
	if s< T
        clearscreen;
        buttonl= uicontrol('units', 'norm', ...
                           'string', '<<<', ...
                           'position', [0.3 0.01 0.1 0.05], ...
                           'enable', 'off', ...
                           'callback', 'plotband([], [], [], [], [], 3);');
        buttonr= uicontrol('units', 'norm', ...
                           'string', '>>>', ...
                           'position', [0.6 0.01 0.1 0.05], ...
                           'callback', 'plotband([], [], [], [], [], 4);');
        transpose= uicontrol('units', 'norm', ...
                           'string', 'Transpose data', ...
                           'position', [0.75 0.01 0.15 0.05], ...
                           'callback', 'plotband([], [], [], [], [], 6);');
        editc= uicontrol('style', 'edit', ...
                         'backg', 'w', ...
                         'units', 'norm', ...
                         'string', 'Full sample', ...
                         'position', [0.4 0.01 0.2 0.05], ...
                         'userdata', [' (out of ' int2str(ceil(T/s))  ')'], ...
                         'callback', 'plotband([], [], [], [], [], 5);');
	end
end
MENUopt= findall(gcf, 'label', '&Options');
if (win== 1)
	 if isempty(MENUopt), MENUopt= uimenu('label', '&Options', 'userdata', []); end
     set(MENUopt, 'callback', ['if optionsET({''Enter the seasonal period for plots [2, Inf):'',' ...
       '''Standardized plot on/off (1 / 0):'', ''Fixed vertical scale on/off (1 / 0):''},' ...
       '[2 Inf; 0 1; 0 1], [1 1; 1 2; 1 3]);' ...
           'plotband([], [], [], [], [], 2); end']);
end

% What to do when hitting the additional uicontrols
t= (1 : T)';
if win< 2
    set(findall(gcf, 'style', 'edit'), 'string', 'Full sample')
    maxX= t(end) + 1;
    value= max(value, -1);
    value= min(value, ceil(T/s));
else
    set(e_handle, 'userdata', [' (out of ' int2str(ceil(T/s))  ')']);
end
if win== 3                            % <<< button
    if value== -1, value= ceil(T/s)+1; end
    value= max(0, value-1);
    if value== 0
        str= 'Full sample'; maxX= T + 1;
        set(b_handles(1), 'enable', 'off');
    else
        t= ((value-1)*s+1 : min(value*s, T))';
        maxX= (value-1)*s+s+1;
        str= [int2str(value) get(e_handle, 'userdata')];
        set(b_handles(1), 'enable', 'on');
    end
    set(b_handles(2), 'enable', 'on');
    set(e_handle, 'string', str)
elseif win== 4                             % >>> button
    maximum= ceil(T/s)+1;
    if value== -1, value= maximum; end
    value= min(value+1, maximum);
    if value== maximum
        t= (1 : s)'; maxX= s + 1;
        str= 'All subsamples';
        set(b_handles(2), 'enable', 'off');
    else
        t= ((value-1)*s+1 : min(value*s, T))';
        maxX= (value-1)*s+s+1;
        str= [int2str(value) get(e_handle, 'userdata')];
        if (value== maximum-1 & seriesval== m+1)
            set(b_handles(2), 'enable', 'off');
        else
            set(b_handles(2), 'enable', 'on');
        end
    end
    set(e_handle, 'string', str)
    set(b_handles(1), 'enable', 'on');
elseif win== 6
   if m> 1
       toolTEST(z, 'cambia', 1);
       return;
   end
elseif (win== 5 | win== 2)                            % edit uicontrol
   if value== 0
        str= 'Full sample';
        t= (1 : T)'; maxX= T + 1;
        if ~isempty(b_handles)
            set(b_handles(1), 'enable', 'off');
            set(b_handles(2), 'enable', 'on');
        end
   elseif value== -1
       if seriesval< m+1
           value= ceil(T/s)+1;
           str= 'All subsamples';
           t= (1 : s)'; maxX= s + 1;
           set(b_handles(2), 'enable', 'off');
           set(b_handles(1), 'enable', 'on');
       else
           value= ceil(T/s);
           str= [int2str(value) get(e_handle, 'userdata')];
           t= ((value-1)*s+1 : min(value*s, T))';
           maxX= (value-1)*s+s+1;
           set(b_handles(2), 'enable', 'off');
           set(b_handles(1), 'enable', 'on');
       end
   else
        value= max(value, 1);
        value= min(value, ceil(T/s));
        str= [int2str(value) ' (out of ' int2str(ceil(T/s))  ')'];
        t= ((value-1)*s+1 : min(value*s, T))';
        maxX= (value-1)*s+s+1;
        set(b_handles(1), 'enable', 'on');
        set(b_handles(2), 'enable', 'on');
   end
   set(e_handle, 'string', str)
end

% Plotting figure
strtitle= strrep(Names(seriesval, :), ' ', '');

if seriesval< m+1   % Plot only one series
    zm= nanmean(z(:, seriesval));
    zs= nanstd(z(:, seriesval));
    maximum= ceil(T/s)+1;
    if value< maximum       % Plot only one subsample
       plot(t, z(t, seriesval), 'k')
       title(['Series ' strtitle ': Series Plot with 2*S.D. bands'])
       if fixed
           rangez= [nanmin(zm-2*zs, nanmin(z(:, seriesval))) nanmax(zm+2*zs, nanmax(z(:, seriesval)))];
       else
           rangez= [nanmin(zm-2*zs, nanmin(z(t, seriesval))) nanmax(zm+2*zs, nanmax(z(t, seriesval)))];
       end
       if (rangez(1)== rangez(2)), rangez= rangez + [-1 1]; end
   else             % Plot all subsamples
        t= (1 : s)'; maxX= s + 1;
		cTs= ceil(T/s);
		z= reshape([z(:, seriesval); nan*ones(cTs*s-T, 1)], s, cTs);
        rangez= [nanmin(zm-2*zs, nanmin(nanmin(z))) nanmax(zm+2*zs, nanmax(nanmax(z)))];
		plot(t, z);
        title(['Series ' strtitle ': Series plot every ' int2str(s) ' samples'])
   end
   line([t(1)-1 maxX], [zm zm], 'color', 'r');
   line([t(1)-1 maxX], [zm-2*zs zm-2*zs], 'color', 'r', 'lines', ':');
   line([t(1)-1 maxX], [zm+2*zs zm+2*zs], 'color', 'r', 'lines', ':');
   v=axis; axis([t(1)-1 maxX rangez]);
   xlabel('Samples')
   ylabel(['Series ' strtitle])
elseif seriesval== m+1
   if standard, z= transform(z); end
   plot(t, z(t, :))
   legend(Names(1 : m, :), 'location', 'best');
   if fixed
%        rangez= [nanmin(-2, nanmin(nanmin(z))) nanmax(2, nanmax(nanmax(z)))];
       rangez= [nanmin(nanmin(z)) nanmax(nanmax(z))];
   else
%        rangez= [nanmin(-2, nanmin(nanmin(z(t, :)))) nanmax(2, nanmax(nanmax(z(t, :))))];
       rangez= [nanmin(nanmin(z(t, :))) nanmax(nanmax(z(t, :)))];
   end
   v=axis; axis([t(1)-1 maxX rangez]);
   xlabel('Samples')
   if standard
       title(['Standardised Plot of All Series with 2*S.D. bands'])
       ylabel('Standard scale')
       line([t(1)-1 maxX], [0 0], 'color', 'r');
       line([t(1)-1 maxX], [-2 -2], 'color', 'r', 'lines', ':');
       line([t(1)-1 maxX], [2 2], 'color', 'r', 'lines', ':');
   else
       title(['Plot of All Series'])
       ylabel('Units')
   end
end


