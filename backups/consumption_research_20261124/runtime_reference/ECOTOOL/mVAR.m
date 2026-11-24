function [P, seP, Sigma, AIC, SBC, e, ARpoly, C, covP, seARpoly, seC, lagy, invXX]= mVAR(y, order, const, partial, Pvalue)

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
% if T<m, y= y'; [T, m]= size(y); end

if nargin< 5, Pvalue= 0; end

if nargin< 4, partial= 0; end

if nargin< 3, const= 1; end

order= order(:)';
if (order(1)== 0 & size(order, 2)> 1)
    order= order(2 : end);
elseif (order(1)== 0 & size(order, 2)== 1)
    P= []; seP= []; Sigma= []; AIC= []; SBC= []; e= []; ARpoly= []; C= [];
    return
end
if partial
    lagy= delay(y, [order(end)+1 order]);
else
    lagy= delay(y, [0 order]);
end
[rlagy, clagy]= size(lagy);

if const, X1= ones(rlagy, 1); else, X1= []; end
X= [lagy(:, m+1:clagy) X1];

if sum(sum(isnan(y)))
   invXX= inv(nanprod(X', X));
   P= invXX*nanprod(X', lagy(:, 1:m));
   e= lagy(:, 1:m) - nanprod(X, P);
   sigma= nanprod(e', e);
else
   invXX= inv(X'*X);
   P= X\lagy(:, 1:m);
   e= lagy(:, 1:m) - X*P;
   sigma= e'*e;
end

detsigma= det(sigma);
Sigma= sigma/T;
covP= kron(Sigma, invXX);
seP= reshape(sqrt(diag(covP)), size(P, 1), size(P, 2));
nP= (clagy-m)/m;
AIC= (T*log(det(Sigma))+2*(nP*m*m+m))/T;
SBC= (T*log(det(Sigma))+(nP*m*m+m)*log(T))/T;

ARpoly= eye(m); seARpoly= zeros(m);
order= [0; order(:)];
sorder= size(order, 1);
for i= 2:sorder
   ARpoly= [ARpoly zeros(m, m*(order(i)-order(i-1)-1)) -P((i-2)*m+1 : (i-1)*m, :)'];
   seARpoly= [seARpoly zeros(m, m*(order(i)-order(i-1)-1)) -seP((i-2)*m+1 : (i-1)*m, :)'];
end
if const, C= P(end, :)'; seC= seP(end, :)'; else, C= []; seC= []; end
if Pvalue, P= ARpoly; end

