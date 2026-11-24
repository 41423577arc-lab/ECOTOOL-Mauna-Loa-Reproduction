function [z, lambdas, lambdasv]= vboxcox(z, lambdas, group, axislambdas, Names, win, seriesval)
% vboxcox   Box-Cox homokedasticity family of transformations
%
%    [yt, lambdas, lambdasv]= vboxcox(y, lambdas, group, axislambdas)
%
% INPUTS:
%   y:           (*) Vector time series data (m x T or T x m)
%   lambdas:     Lambdas for each time series (1 x n, with n<= m)
%                If is empty or not supplied the lamdas are 
%                estimated by ML
%   group:       Number of elements for grouping for Guerrero (1993)
%   axislambdas: Lambda axis for graphical output (1 x any)
%
% OUTPUTS:
%   yt:       Transformed data according to lambdas (either supplied by the user or estimated)
%   lambdas:  Estimated lambdas (univariate estimation for each time series)
%   lambdasv: Estimated lambdas (multivariate estimation)
%   
% Examples: 
%   vboxcox(z);
%   zt= (z);
%   zt= (z, 0);
%
% See Also: vcusum, stdmean, testhet, vboxcoxinv

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

if nargin< 7, seriesval= 1; end

if nargin< 6, win= 0; end

if ~isempty(get(0, 'currentfigure')), plotw= gcf; else, plotw= []; end
textw= findall(0, 'name', 'Text Output Window');
if (strcmp(get(plotw, 'name'), 'Text Output Window') & win> 0)
    plotw= get(0, 'CurrentFigure')-1;
    figure(plotw);
end
if win> 0
    [z, Names, axislambdas, seriesval]= auxtestGUI;
    if size(axislambdas, 2)== 1, axislambdas= axislambdas{1}{1}; else, axislambdas= axislambdas{15}{1}; end
    seriesval= seriesval(1);
end    

[T, m]= size(z);
% if T<m, z= z'; [T, m]= size(z); end
seriesval= min(m, seriesval);

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 5, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 4, axislambdas= []; end
axislambdas= axislambdas(:);

if nargin < 3, group = 12; end
if isempty(group)
    aux = get(gcf, 'UserData');
    group = aux{2}{1}{1};
end

lambdasv= [];
if nargin< 2, lambdas= []; end
lambdas= lambdas(:);
if ~isempty(lambdas), lambdas= [lambdas; repmat(lambdas(end), m-size(lambdas, 1), 1)]; end

if (win== 0 & ~isempty(axislambdas))
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
   set(gcf, 'number', 'off', 'name', 'Box-Cox Transformation Tool', 'userdata', {z, {{axislambdas}}, Names}, 'toolbar', 'figure');
end

% Estimating the lambdas
if (isempty(lambdas) & win< 2)
%    wwaitfor(m+(m~=1));
   options= optimset('Display', 'off'); %, 'LargeScale', 'off', 'LevenbergM', 'on', 'linesearch', 'cubicpoly');
   lambdas= ones(1, m); lambdasv= lambdas; lim95i= lambdas; lim95s= lambdas; 
   for i= 1:m
      zi= z(:, i);
      minzi= nanmin(zi);
      if minzi<= 0, zi= zi + abs(minzi) + 1e-4; end
      lambdas(i)= fminsearch('auxvboxcoxllik', 1, options, zi, group, 0);
      obj= auxvboxcoxllik(lambdas(i), zi, group, 0);
      inc= 0.1; trials= 1;
%       while abs(lim95i(i)-lim95s(i))< 0.001
%          lim95i(i)= fzero('auxvboxcoxllik', lambdas(i)-inc, options, zi, obj+1.92);
%          lim95s(i)= fzero('auxvboxcoxllik', lambdas(i)+inc, options, zi, obj+1.92);
%          if abs(lim95i(i)-lim95s(i))< 0.001
%             inc= inc+0.1;
%             trials= trials+1;
%             if trials> 9, lim95i(i)= nan; lim95s(i)= nan; break; end
%          end
%       end
%       if wwaitfor, return; end
   end
%    lambdasv= repmat(nan, m, 1);
%    if m>1
%       lambdasv= fminsearch('auxvboxcoxllikv', lambdas', options, z);
% %       if wwaitfor, return; end
%    end
%    wwaitfor(0);
%    table1= printwf([lambdasv lambdas' lim95i' lim95s'], 4, 'Lambda_Multivariate Lambda_Univariate >95% <95%', Names);
%    textoutputWINDOW(charcat(' ', '-', ' ML estimation of Box-Cox Lambdas: ', '-', ...
%        table1(1, :), '-', table1(2 : end, :), '-'), ...
%        'Box - Cox Transformations');
   table1= printwf(lambdas', 4, 'Lambdas', Names);
   textoutputWINDOW(charcat(' ', '-', ' Estimation of Box-Cox Lambdas: ', '-', ...
       table1(1, :), '-', table1(2 : end, :), '-'), ...
       'Box - Cox Transformations');
   delete(findall(gcf, 'label', '&Options'));
   textw= gcf;
end

% Plotting figure
if ~isempty(axislambdas)
   strlabel= strrep(Names(seriesval, :), ' ', '');
   figure(plotw);
%   if strcmp(get(gcf,'name'), 'Text Output Window')
%       fig= get(0, 'CurrentFigure')-1;
%       if fig== 0, figure, else, figure(fig); end
%   end
   clearscreen;
   
   zi= z(:, seriesval); nlam= size(axislambdas, 1);
   minz= nanmin(zi);
   table= zeros(nlam, 3);
   if minz<= 0, zi= zi + abs(minz) + 1e-4; end
   for j= 1 : nlam
      lambda= axislambdas(j);
      if lambda== 0, zit= log(zi); else, zit= (zi.^lambda - 1)/lambda; end
      mzit= nanmean(zit);
      sdzit= nanstd(zit);
      table(j, 1)= sdzit;
      table(j, 2)= mzit/sdzit;
      table(j, 3)= -auxvboxcoxllik(lambda, zi, group, 0);
   end
	
	table= transform(table);
	h= plot(axislambdas, table(:, 1), 'b*-', axislambdas, table(:, 2), 'r*-', axislambdas, table(:, 3), 'k*-');
    axislimits= [axislambdas(1)-0.1 axislambdas(end)+0.1 nanmin(nanmin(table))-0.1 nanmax(nanmax(table))+0.1];
    axis(axislimits);
	[opt, indz]= nanmin(table);
	[ii, ij]= nanmax(table); indz(3)= ij(3); opt(3)= ii(3);
    line(repmat(axislambdas(indz(1)), 1, 2), [axislimits(3) opt(1)], 'color', 'b', 'linesty', ':')
    line(repmat(axislambdas(indz(2)), 1, 2), [axislimits(3) opt(2)], 'color', 'r', 'linesty', ':')
    line(repmat(axislambdas(indz(3)), 1, 2), [axislimits(3) opt(3)], 'color', 'k', 'linesty', ':')
	title(['Series ' strlabel ': ' ...
          'S.D.(blue; ' num2str(axislambdas(indz(1))) '), Mean/S.D.(red; ' num2str(axislambdas(indz(2))) ...
          ') & L-Lik(black; ' num2str(axislambdas(indz(3))) ')'])
	xlabel('Lambda')
	ylabel('Normalised S.D., Mean/S.D. & L-Lik')
    if (~isempty(textw) & win< 2), figure(textw); end
end

% Calculating the Box-Cox transformation of the series
if nargout> 0
	for i= 1:m
      zi= z(:, i);
      minzi= nanmin(zi);
      if minzi<= 0, zi= zi + abs(minzi) + 1e-4; end
      if lambdas(i)== 0
         z(:, i)= real(log(zi));
     else
         z(:, i)= real((zi.^lambdas(i) - 1)/lambdas(i));
      end
	end
end

% Setting up Menu Series
if win== 1
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
              'callback', 'vboxcox([], [], [], [], [], 2);');
       end      
	end
    MENUopt= findall(plotw, 'label', '&Options');
    if isempty(MENUopt), MENUopt= uimenu('label', '&Options', 'userdata', []); end
    set(MENUopt, 'callback', ['if optionsET({''Axis Lambdas for plots (it must be a row vector) (-Inf, Inf):''}, [-100 100], 15);' ...
          'vboxcox([], [], [], [], [], 2); end']);
end
