function subplots(y, series, ylabels, t, xlabels, titles)
% subplots(y, {[1 2], 3, 4}, {'Tendencia y serie', 'Estacional', 'Irregular'}, ...
%          t, xaxis, xlabels, title)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

n= size(y, 2);
if nargin< 2, series= num2cell(1 : n); end
if isempty(series), series= num2cell(1 : n); end
if nargin<3, ylabels= {}; end
if nargin< 4, t= (1 : size(y, 1))'; end
if isempty(t), t= (1 : size(y, 1))'; end
if nargin< 5, xlabels= ''; end
if isempty(xlabels), xlabels= ''; end
if nargin< 6, titles= ''; end
nw= length(series);
heith= 0.8/nw;
% escala= max(1, floor(log10(abs(t(1)))));
% sumar= 10^(-escala);
clf
for i =1 :nw
    subplot('position', [0.1 (i-1)*0.8/nw+0.1 0.8 heith])
    plot(t, y(:, series{end-i+1}))
    if ~isempty(ylabels), ylabel(ylabels{end-i+1}); end
    if i~= 1
        set(gca, 'xticklabel', '')
    else
        xlabel(xlabels);
    end
    yaxis= axis;
    axis([t(1) t(end) nanmin(nanmin(y(:, series{end-i+1}))) nanmax(nanmax(y(:, series{end-i+1})))]);
%     set(gca, 'xlim', [t(1) t(end)]);
end
title(titles);
