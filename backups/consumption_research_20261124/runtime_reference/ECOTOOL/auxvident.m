function auxvident(lags, XX, seacfXX, season, title_s)
% Auxiliar function of vident

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[lX, cX]= size(XX);

delete(findobj(gcf, 'type', 'axes'));
for k= 1:cX
   subplot(cX, 1, k);
   title(title_s(k, :))
   ylabel('Correlation')
   X= XX(:, k); seacfX= seacfXX(:, k);
   for j= 1:lX
      i= lags(j);
      if rem(i, season)== 0
          line([i, i], [0, X(j)], 'color', 'r', 'linestyle', ':');
      else
          line([i, i], [0, X(j)], 'color', 'b');
      end
   end
   line([lags(1)-1 lags(lX)+1],[0 0], 'color', 'b');
   confband= [2*seacfX -2*seacfX];
   line(lags, confband, 'color', 'r', 'linestyle', ':');
   axis([lags(1)-1 lags(lX)+1 min(min([X confband]))-0.05 max(max([X confband]))+0.05])
   xtick=min(diff(get(gca, 'xtick')));
   poss= season./(season:-1:1);
   [ii, jj]=min(abs(poss-xtick));
   inc= ceil(poss(jj));
   if lags(1)== 1
      if lags(lX)/inc> 10, inc= ceil(lags(lX)/10/inc)*inc; end
      xticks= (inc : inc: lags(lX));
   else
      if (lags(lX)/inc)*2> 10, inc= ceil(lags(lX)/5/inc)*inc; end
%      xticks= (lags(1)+mod(abs(lags(1)), inc) : inc : lags(lX));
      xticks= (lags(1)+mod(abs(lags(1)), inc) : inc : lags(lX));
   end
   set(gca, 'xtick', xticks);
end
xlabel('Lags')
