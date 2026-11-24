function result= auxsumstats(z, stats, Nsimul)
% result= auxsumstats(z, stats, Nsimul)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[T, m]= size(z);
sqrtT= sqrt(T);
bins= ceil(sqrtT);
simul= nan(Nsimul, m);
result= nan(1, m);
for i= 1 : Nsimul
    ind= floor(rand(T, 1)*T)+1;
    zi= z(ind, :);
    simul(i, :)= nanmean(zi)./(nanstd(zi)/sqrtT);
end
rangez= nanmax(simul) - nanmin(simul);
for i= 1 : m
%     zi= z(find(~isnan(z(:, i))), i);
%     mz= nanmean(zi);
%     stdz= nanstd(zi);
    zi= simul(:, i);
    [frec, posbins]=hist(zi, bins);
%     axislim= axis;
     axislim= [floor(min(posbins)) ceil(max(posbins))];

    xaxis= (axislim(1) : (diff(axislim(1:2)))./180 : axislim(2));
    fi= cumsum(ksdensity(zi, xaxis')*rangez*size(zi, 1)*size(xaxis, 1)/bins);
    fi= fi/nanmax(fi);
%     plot(xaxis, fi);
%     result(i)= interpol(xaxis, fi, stats(i));
    result(i)= interpol(xaxis, fi, 0);
    if stats(i)<0, result(i)= 1-result(i); end
%     if nanmax(simul(:, i))< 0, result(i)= 1-result(i); end
    result(i)= max(0, result(i));
    result(i)= min(1, result(i));
end
