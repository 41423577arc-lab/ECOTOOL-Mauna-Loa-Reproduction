function SBCS= varsbc(z, ncoef, out, Names, win, seriesval)
% varsbc   Identification criteria on VAR models
%
%    varsbc(y, ncoef)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   ncoef: Number of autocorrelation coefficients  (1 x 1)
% 
% See Also: vident, vident2, vgranger

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

if win> 0
    [z, Names, ncoef, seriesval]= auxtestGUI;
    if size(ncoef, 2)== 1, ncoef= ncoef{1}{1}; else, ncoef= ncoef{9}{1}; end
    seriesval= seriesval(1);
    out= 1;
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end

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

if nargin<2, ncoef= min([38 ceil(T/4/m*2)]); end
if isempty(ncoef), ncoef= min([38 ceil(T/4/m*2)]); end

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
%       figs= findobj(0, 'type', 'figure');
%       fig= max(figs.Number);
%        aa=get(0, 'CurrentFigure'); 
%        fig= aa-1;
%        fig= get(0, 'CurrentFigure')-1;
%       if fig== 1, figure, else, figure(fig); end
%   end
   clf;
   set(gcf, 'name', 'VAR Identification Criteria Tool', 'userdata', {z, {{ncoef}}, Names}, 'toolbar', 'figure');
end

% Calculations
strlabel= strrep(Names(seriesval, :), ' ', '');
ncoef= min([ncoef T-3]); 
data= get(findall(gcf, 'label', '&Options'), 'userdata');
WIN= win;
if size(data, 1)< ncoef, win= 1; end
if win< 3
    if seriesval> m, seriesval= (1 : m); strlabel= 'All (VAR model)'; end
    zm= z(:, seriesval) - ones(T, 1)*nanmean(z(:, seriesval));
    detSa= det(zm'*zm/T);
    AICS= nan*ones(ncoef+1, 1); SBCS= AICS; CHIS= AICS; HQCS= AICS;
    
    wwaitfor(ncoef+1);

    for i= 0 : ncoef
       [Sigma, FPE, AIC, AICc, SBC, HQC]= auxvarsbc(zm, i);
       AICS(i+1)= AICc; SBCS(i+1)= SBC;
       HQCS(i+1)= HQC;
       detS= det(Sigma);
       CHIS(i+1)= -(T-i-1-0.5-m*i)*log(detS/detSa);
       detSa= detS;
       if wwaitfor; break; end
	end
	PCHIS= 1-chi2cdf(CHIS, m*m);
    indnan= find(isnan(CHIS)); PCHIS(indnan)= nan*ones(size(indnan));
    wwaitfor(0);
    data= real([AICS SBCS HQCS CHIS PCHIS]);
    set(findall(gcf, 'label', '&Options'), 'userdata', data);
end

% Plotting figure
menuopt= findall(gcf, 'label', '&Options');
if ~isempty(menuopt), data= get(menuopt, 'userdata'); end

clearscreen;
ll= (0 : ncoef)';
subplot('position', [0.13 0.31 0.775 0.615]);
[ii1, minAIC]= nanmin(data(ll+1, 1)); minAIC= int2str(minAIC - 1);
[ii2, minSBC]= nanmin(data(ll+1, 2)); minSBC= int2str(minSBC - 1);
[ii3, minHQC]= nanmin(data(ll+1, 3)); minHQC= int2str(minHQC - 1);
iii= [ii1 ii2 ii3];
indx= (1 : 3);
%if length(seriesval)> 1
%    indx= [1 3 4 5];
%elseif seriesval> m
%    indx= [1 3 4 5];
%end
plot(ll, data(ll+1, 1 : 3), '*-');
set(gca, 'xgrid', 'off', 'ygrid', 'on');
title(['Series ' strlabel ': Information Criteria of AR Models'])
ylabel('Information Criteria');
set(gca, 'xticklabel', [])
legend(['AICc(' minAIC ')'], ['SBC(' minSBC ')'], ['HQC(' minHQC ')']);
axis([-0.5 ncoef+1 min(iii(indx)) max(max(data(ll+1, indx)))]);

subplot('position', [0.13 0.11 0.775 0.19]);
plot(ll, data(ll+1, 5), 'k*-')
if all(data(ll+1, 5)> 0.3)
    axis([-0.5 ncoef+1 0 max(data(ll+1, 5))])
else
    axis([-0.5 ncoef+1 0 0.3])
end    
line([-0.5 ncoef+1], [0.05 0.05], 'color', 'r', 'lines', ':')
line([-0.5 ncoef+1], [0.1 0.1], 'color', 'b', 'lines', ':')
xlabel('lags');
ylabel('P-Chi');
plotw= gcf;
data(1, 4 : 5)= [nan nan];

% Text output
if win< 3
	table= printwf([(0:ncoef)' data], [0 4], 'Lag AICc SBC HQC CHI P-CHI');
    tab= char(['AICc(' minAIC '): '], ['SBC(' minSBC '): '], ['HQC(' minHQC '): '], 'CHI: ');
    tab= [tab char('Corrected Akaike Information Criterion ', ...
            'Schwarz Information Criterion ', ...
            'Hannan and Quinn Criterion ', 'Lagrange Multiplier Test ')];
	textoutputWINDOW(charcat(' ', '-', ' Identification Criteria ', ...
        '-', [' Series ' strlabel ' '], '-', tab, ...
        '-', table(1, :), '-', table(2 : end, :), '-'), ...
        'Identification Criteria');
    figure(plotw);
end

% Setting up Menu Series and Options
if win< 2
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu(plotw, 'label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'varsbc([], [], [], [], 2);');
       end
       uimenu(MENU_H, 'label', 'All (VAR)', ...
           'callback', 'varsbc([], [], [], [], 2);');
    end
end
MENUopt= findall(plotw, 'label', '&Options');
if WIN== 1
    if isempty(MENUopt), MENUopt= uimenu(plotw, 'label', '&Options', 'userdata', []); end
    set(MENUopt, 'callback', ['if optionsET({''Number of lags for plot [4, Inf):''}, 4, 9);' ...
      'varsbc([], [], [], [], 3); end']);
end
