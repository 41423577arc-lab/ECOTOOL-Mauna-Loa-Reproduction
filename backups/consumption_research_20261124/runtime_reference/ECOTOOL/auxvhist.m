function auxvhist(z, bins, strlabel)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

titles= 1;
if nargin< 3, titles= 0; end

zi= z(find(~isnan(z)));
mz= nanmean(zi);
stdz= nanstd(zi);
rangez= nanmax(zi) - nanmin(zi);

hist(zi, bins);
axislim= axis;

xaxis= (axislim(1) : (diff(axislim(1:2)))./180 : axislim(2));
normline= size(zi, 1)*normpdf(xaxis, mz, stdz)*(rangez/bins);
line(xaxis, normline, 'color', 'r', 'lineWidth', 2);

f= ksdensity(zi, xaxis')*rangez*size(zi, 1)*size(xaxis, 1)/bins;
line(xaxis, f, 'color', 'g', 'lineWidth', 2);

if titles
    title(['Series ' strlabel ': Histogram, Nonparametric estimate(green) & Theoretical normal(red)']);
    xlabel(['Series ' strlabel])
    ylabel('Data points')
else
    set(gca, 'yticklabel', '', 'xticklabel', '', 'xtick', [], 'ytick', []);
end
