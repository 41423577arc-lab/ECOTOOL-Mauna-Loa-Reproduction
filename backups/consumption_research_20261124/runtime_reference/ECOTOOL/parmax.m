function pr=parmax(x,b,a,c,nofs,e)
% function pr= parmax(y, B, A, C, nofs, e)
% Forecasts of ARMAX models
%           
%    A(B) y(t)= B1(B) u1(t) + B2 (B) u2(t)  + ... + C(B) a(t)
%
% INPUT:
%	y (*): time series
% 	b (*): inputs polinomials
% 	a (*): AR polinomial
%   c (*): MA polinomial
% 	nofs (*): inputs forecasts
%   e:     residuals of model
% OUTPUT:
%	pr: forecasts

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 2, b= 1; end
if isempty(b), b= 1; end

if nargin< 3, a= 1; end
if isempty(a), a= 1; end

if nargin<4, c= 1; end
if isempty(c), c= 1; end

if nargin< 5, nofs= 24; end
if isempty(nofs), nofs= 24; end

if nargin<6, e= zeros(size(x, 1), 1); end
if isempty(e), e= zeros(size(x, 1), 1); end

a= a(:)'; if a(1)==1; a= a(2 : length(a)); end
c= c(:)'; if c(1)==1; c= c(2 : length(c)); end
if isempty(a), a= 0; end
if isempty(c), c= 0; end

[n, Nu]= size(x); Nu= Nu-1;
%Nu= size(nofs, 1);
nfor= size(nofs, 1);
p= length(a); q= length(c);
pr= zeros(nfor, 1);
if Nu== 0
   x= [x; zeros(nfor, 1)];
else
   x= [x; [zeros(nfor, 1) nofs]];
end
[uu, border]= size(b);
for i= 1 : nfor
  x(n+i, 1)= -a*flipud(x(n+i-p:n+i-1, 1));
  for k= 1 : Nu
     x(n+i, 1)= x(n+i, 1) + b(k, 1:border)*flipud(x(n+i-border+1:n+i, k+1));
  end
  if i<= q
    x(n+i, 1)= x(n+i, 1) + c(i:q)*flipud(e(length(e)+i-q:length(e)));
 end
end
pr= x(n+1:n+nfor, 1);

