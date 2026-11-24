function [Sigma, FPE, AIC, AICc, SBC, HQC, e]= auxvarsbc(y, order)
% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


[T, m]= size(y);

if order== 0
    lagy= y;
else
    lagy= delay(y, [0 (1 : order)]);
end
[rlagy, clagy]= size(lagy);
X= [lagy(:, m+1:clagy) ones(rlagy, 1)];

if sum(sum(isnan(y)))
   if order== 0
       e= y;
   else
       e= lagy(:, 1:m) - nanprod(X, inv(nanprod(X', X))*nanprod(X', lagy(:, 1:m)));
   end
   sigma= nanprod(e', e);
else
   if order== 0
       e= y;
   else
       e= lagy(:, 1:m) - X*(X\lagy(:, 1:m));
   end
   sigma= e'*e;
end

detsigma= det(sigma);
Sigma= sigma/T;
nP= (clagy-m)/m;
ldetSigma= log(det(Sigma));
k= (nP*m*m+m);
AIC= (ldetSigma + 2*k/T);
AICc= (ldetSigma + (2*k+2)/(T-k-2));
SBC= (ldetSigma + k*log(T)/T);
FPE= (ldetSigma + log((T+k)/(T-k)));
HQC= (ldetSigma + 2*k*log(log(T))/T);
% AICc=[]; FPE= [];