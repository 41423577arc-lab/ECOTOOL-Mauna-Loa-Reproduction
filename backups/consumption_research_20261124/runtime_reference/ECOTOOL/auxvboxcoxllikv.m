function out= auxvboxcoxllikv(lambda, z)
% Auxiliar function of vboxcox (computes the log-likelihood of series
%     for a given value of lambda

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
zit= zeros(size(z));
sumzi= 0;
for i= 1:m
   zi= z(:, i);
   minzi= nanmin(zi);
   if minzi<= 0, zi= zi + abs(minzi) + 1e-4; end
   if lambda(i)== 0
      zit(:, i)= log(zi);
   else
      zit(:, i)= (zi.^lambda(i) - 1)/lambda(i);
   end
   sumzi= sumzi + (1 - lambda(i))*nansum(log(zi));
end

out= (T/2)*log(det(nancov(zit))) + sumzi;
