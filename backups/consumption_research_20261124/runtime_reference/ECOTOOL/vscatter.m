function vscatter(z, bins, Names, win, seriesval)
% vscatter   Scatter plots
%
%    vscatter(y, bins)
%
% INPUTS:
%   y:    (*) Vector time series data (m x T or T x m)
%   bins: Number of bins for histograms (1 x 1)
% 
% See Also: plotband, vboxplot, vtboxplot, sumstats

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

if nargin< 5, seriesval= 1; end

if nargin< 4, win= 0; end

if win> 0
    [z, Names, bins, seriesval]= auxtestGUI;
    if size(bins, 2)== 1, bins= bins{1}{1}; else, bins= bins{6}{1}; end
    seriesval= seriesval(1);
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end
if m< 3, seriesval= 1; end

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
   set(gcf, 'number', 'off', 'name', 'Scatter Plots Tool', 'userdata', {z, {{bins}}, Names}, 'toolbar', 'figure');
end

% Setting up Menu Series
if win< 2
    MENU_H= findall(gcf, 'label', 'Se&ries');
	if m> 2
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1 : m - 1
          MENU_Hi= uimenu(MENU_H, 'label', Names(i, :));
          for j= i+1 : m
              uimenu(MENU_Hi, 'label', Names(j, :), ...
                  'callback', 'vscatter([], [], [], 2);');
          end
       end      
       uimenu(MENU_H, 'label', 'All', ...
            'callback', 'vscatter([], [], [], 2);');
    else
       if ~isempty(MENU_H), delete(MENU_H); end
	end
end

MENUopt= findall(gcf, 'label', '&Options');
if (win== 1 & m> 2)
	 if isempty(MENUopt), MENUopt= uimenu('label', '&Options'); end
     set(MENUopt, 'callback', ['if optionsET({''Number of bins for histograms [4, Inf):''}, 4, 6);' ...
               'vscatter([], [], [], 3); end']);
elseif m< 3
     delete(findall(gcf, 'label', '&Options'));
end

% Plotting figure
if seriesval> m - 1     % All scatterplots together
    clearscreen;
    limits= [nanmin(z); nanmax(z)];
    incx= 0.9/m; incy= 0.9/m;
    for i= 1 : m
        for j= 1 : m
            h= subplot('position', [0.05+(j-1)*incx+0.02 0.03+(m-i)*incy+0.02 incx incy]); box on
            if i == j
                auxvhist(z(:,i), bins);
%             elseif i> j
%                 plot(z(:, i), z(:, j), 'b.')
%                 axis([limits(1, i) limits(2, i) limits(1, j) limits(2, j)]);
%                 ix= i; iy= j;
            else
                plot(z(:, j), z(:, i), 'b.')
                axis([limits(1, j) limits(2, j) limits(1, i) limits(2, i)]);
                ix= j; iy= i;
            end
            if (i== 1 & j== ceil(m/2))
                title('Scatter Plots for All Series');
            end
            set(gca, 'yticklabel', '', 'xticklabel', '', 'xtick', [], 'ytick', []);
            if i== m, xlabel(Names(j, :)); end
            if j== 1, ylabel(Names(i, :)); end
            if i~= j
                X= [ones(T, 1) z(:, ix)];
                if any(isnan(sum(z(:, [ix iy]))))
                    beta= inv(nanprod(X', X))*nanprod(X', z(:, iy));
                else
                    beta= X\z(:, iy);
                end
                v= axis;
                line([v(1) v(2)], [beta(1)+v(1)*beta(2) beta(1)+v(2)*beta(2)], 'color', 'r')
            end
        end
    end
else                    % One scatter plot
    if win< 3
        clearscreen;
        i= seriesval;
        j= seriesval+get(gcbo,'position');
        if win< 2, i= 1; j= 2; end
        plot(z(:, i), z(:, j), 'b*');
        xlabel(Names(i, :))
        ylabel(Names(j, :))
        title(['Scatter Plot: Series ' strrep(Names(i, :), ' ', '') ' vs ' strrep(Names(j, :), ' ', '')])
        X= [ones(T, 1) z(:, i)];
        if any(isnan(sum(z(:, [i j]))))
            beta= inv(nanprod(X', X))*nanprod(X', z(:, j));
        else
            beta= X\z(:, j);
        end
        v= axis;
        line([v(1) v(2)], [beta(1)+v(1)*beta(2) beta(1)+v(2)*beta(2)], 'color', 'r')
    end
end


