function varsbc2(z, ncoef, out, Names, win, seriesval)
% varsbc2   Non-linearity test based on Schwarz Criterion of squares
%
%    varsbc2(y, ncoef)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   ncoef: Number of autocorrelation coefficients (1 x 1)
% 
% See Also: nltests, vtsay, vbds
%   

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

if nargin< 6, seriesval= 1; end

if nargin< 5, win= 0; end

square= 0;
if win> 0
    [z, Names, ncoef, seriesval]= auxtestGUI;
    if size(ncoef, 2)== 1, ncoef= ncoef{1}{1}; else, ncoef= ncoef{19}{1}; end
    seriesval= seriesval(1);
    out= 1;
end    

z= z.^2;
[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end
seriesval= min(m, seriesval);

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 4, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 3, out= 1; end
if isempty(out), out= 1; end

if nargin<2, ncoef= min([38 sqrt(T)]); end
if isempty(ncoef), ncoef= min([38 sqrt(T)]); end

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
   set(gcf, 'number', 'off', 'name', 'VAR Identification Criteria Tool', 'userdata', {z, {{ncoef}}, Names}, 'toolbar', 'figure');
end

% Calculations
strlabel= strrep(Names(seriesval, :), ' ', '');
ncoef= min([ncoef T-3]); 
data= get(findall(gcf, 'label', '&Options'), 'userdata');
WIN= win;
if size(data, 1)< ncoef, win= 1; end
if win< 3
    zm= z(:, seriesval) - ones(T, 1)*nanmean(z(:, seriesval));
    SBCS= nan*ones(ncoef+1, 1);
    
    wwaitfor(ncoef+1);    
	for i= 0 : ncoef
       [aa, bb, cc, dd, SBC]= auxvarsbc(zm, i);
       SBCS(i+1)= SBC;
       if wwaitfor; break; end
	end
    wwaitfor(0);
    data= SBCS;
    set(findall(gcf, 'label', '&Options'), 'userdata', data);
end

% Plotting figure
menuopt= findall(gcf, 'label', '&Options');
if ~isempty(menuopt), data= get(menuopt, 'userdata'); end

clearscreen;
ll= (0 : ncoef)';
plot(ll, data(ll+1, 1), 'b*-');
set(gca, 'xgrid', 'off', 'ygrid', 'on');
[ii2, minSBC]= min(data); minSBC= minSBC - 1;
axis([-0.5 ncoef+1 ii2 max(data)]);
if minSBC== 0, strl= 'Process is Linear)'; else, strl= 'Process is Non-Linear)'; end
title(['Series ' strlabel ': SBC Criterion of Squared data (Min is ' int2str(minSBC) ': ' strl])
ylabel('SBC');
xlabel('lags');
plotw= gcf;

% Setting up Menu Series and Options
if win< 2
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'varsbc2([], [], [], [], 2);');
       end
    end
end
MENUopt= findall(plotw, 'label', '&Options');
if WIN== 1
    if isempty(MENUopt), MENUopt= uimenu('label', '&Options', 'userdata', []); end
    set(MENUopt, 'callback', ['if optionsET({''Number of lags for plot [4, Inf):''}, 4, 19);' ...
       'varsbc2([], [], [], [], 3); end']);
end
