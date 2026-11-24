function stdmean(z, s, opt, numbers, Names, win, seriesval)
% stdmean   Standard Deviation vs Mean type of plots
%
%    stdmean(y, s, opt, numbers)
%
% INPUTS:
%   y:       (*) Vector time series data (m x T or T x m)
%   s:       Seasonal period (1 x 1)
%   opt:     0 for Standard deviation-Mean; 1 for MEDA-Median; 
%            2 for Range-Mean
%   numbers: numbers for each data point on/off (1/0)
%
% See Also: vcusum, testhet, vboxcox, vboxcoxinv

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

if nargin< 7, seriesval= 1; end

if nargin< 6, win= 0; end

if win> 0
    [z, Names, s, seriesval]= auxtestGUI;
    if size(s, 2)== 1, numbers= s{1}{3}; opt= s{1}{2}; s= s{1}{1}; else, numbers= s{13}{2}; opt= s{13}{1}; s= s{1}{1}; end
    seriesval= seriesval(1);
end    

[T, m]= size(z);
% if T<m, z= z'; [T, m]= size(z); end
seriesval= min(seriesval, m);

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 5, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 2, s= 12; end
if nargin< 3, opt= 0; end
if nargin< 4, numbers= 1; end

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
   set(gcf, 'number', 'off', 'name', 'Standard Deviation - Mean Graphical Tool', 'userdata', {z, {{s, opt, numbers}}, Names}, 'toolbar', 'figure');
end

% Setting up Menu Series
if win< 2
	if m>1
       MENU_H= findall(gcf, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'stdmean([], [], [], [], [], 2);');
       end      
	end
end
MENUopt= findall(gcf, 'label', '&Options');
if (win== 1)
	 if isempty(MENUopt), MENUopt= uimenu('label', '&Options', 'userdata', []); end
     set(MENUopt, 'callback', ['if optionsET({'' Enter the seasonal period for plots [2, Inf):'' ', ...
           ''' Type of plot: 0 for S.D. vs Mean; 1 for MEDA-Median; 2 for Range - Mean '' ', ...
           ''' Numbers ON/OFF (1/0):''}, [2; 0; 0], [1 1; 13 1; 13 2]);' ...
           'stdmean([], [], [], [], [], 2); end']);
end

% Plotting figure
strlabel= strrep(Names(seriesval, :), ' ', '');

clearscreen;

i0= rem(T, s)+1;
bins= (T-i0+1)/s;
data= nan*ones(bins, 2);
zi= reshape(z(i0 : T, seriesval), s, bins);

%subplot(211)
if opt== 0
    data(:, 1)= nanmean(zi)';
    data(:, 2)= nanstd(zi)';
	h= plot(data(:, 1), data(:, 2), 'b.');
	xlabel('Mean')
	ylabel('Standard Deviation')
	title(['Series ' strlabel ': Standard Deviation - Mean Plot'])
elseif opt== 1
    data(:, 1)= nanmedian(zi)';
    data(:, 2)= nanmedian(abs(zi-repmat(data(:, 1)', s, 1)))';
	h= plot(data(:, 1), data(:, 2), 'b.');
	xlabel('Median')
	ylabel('MEDA')
	title(['Series ' strlabel ': MEDA - Median Plot'])
else
    data(:, 1)= nanmean(zi)';
    data(:, 2)= nanmax(zi)'-nanmin(zi)';
	h= plot(data(:, 1), data(:, 2), 'b.');
	xlabel('Mean')
	ylabel('Range')
	title(['Series ' strlabel ': Range - Mean Plot'])
end
X= [ones(size(data, 1), 1) data(:, 1)];
if any(isnan(data))
   beta1= inv(nanprod(X', X))*nanprod(X', data(:, 2));
else
   beta1= X\data(:, 2);
end
v= axis; axis(v);
line([v(1) v(2)], [beta1(1)+v(1)*beta1(2) beta1(1)+v(2)*beta1(2)], 'color', 'r');

if numbers~= 0
    tt= (1 : size(data, 1));
    inc= (v(4)-v(3))/30;
    for i= 1 : max(tt)
        text(data(i, 1), data(i, 2)+inc, int2str(i));
    end
end
