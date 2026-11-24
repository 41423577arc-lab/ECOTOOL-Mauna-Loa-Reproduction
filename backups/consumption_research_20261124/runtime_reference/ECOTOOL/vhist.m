function vhist(z, bins, Names, win, seriesval)
% vhist   Histogram with gaussian distribution and non-parametric estimate
%
%    vhist(y, bins)
%
% INPUTS:
%   y:    (*) Vector time series data (m x T or T x m)
%   bins: Number of bins for histograms (1 x 1)
% 
% See Also: vqqplot, gausstest

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
    [z, Names, bins, seriesval]= auxtestGUI;
    if size(bins, 2)== 1, bins= bins{1}{1}; else, bins= bins{6}{1}; end
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

if (nargin< 2 & win< 2), bins= ceil(sqrt(T)); end
if isempty(bins), bins= ceil(sqrt(T)); end
seriesval= min(seriesval, m);

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
%       aa= get(0, 'CurrentFigure'); fig= aa.Number-1;
%        fig= get(0, 'CurrentFigure')-1;
%       if fig== 0, figure, else, figure(fig); end
%   end
   clf;
   set(gcf, 'name', 'Histogram Tool', 'userdata', {z, {{bins}}, Names}, 'toolbar', 'figure');
end

% Setting up Menu Series
if win< 2
	if m>1
       MENU_H= findall(gcf, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'vhist([], [], [], 2);');
       end      
	end
end
MENUopt= findall(gcf, 'label', '&Options');
if (win== 1)
	 if isempty(MENUopt), MENUopt= uimenu('label', '&Options', 'userdata', []); end
     set(MENUopt, 'callback', ['if optionsET({''Number of bins for histogram [4, Inf):''}, 4, 6);' ...
           'vhist([], [], [], 2); end']);
end

% Plotting figure
strlabel= strrep(Names(seriesval, :), ' ', '');

clearscreen;
auxvhist(z(:, seriesval), bins, strlabel);
