function pr=parma(x,b,a,nofs,e)
% function pr=parma(x,b,a,nofs,e)
% Forecasts of ARMA models
%
% INPUT:
%	x (*): time series
% 	b (*): MA polinomial
% 	a (*): AR polinomial
% 	nofs (*): number of forecasts
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

if nargin< 4, nofs= 24; end
if isempty(nofs), nofs= 24; end

if nargin< 5, e= zeros(size(x)); end
if isempty(e), e= zeros(size(x)); end

a= a(:)'; if a(1)== 1; a= a(2:length(a)); end
b= b(:)'; if b(1)==1; b= b(2:length(b)); end
if isempty(a), a= 0; end
if isempty(b), b= 0; end

n= length(x); p= length(a); q= length(b);
x= [x; zeros(nofs, 1)]; pr= zeros(nofs, 1);
for i= 1 : nofs
  x(n+i)= -a * flipud(x(n+i-p:n+i-1));
  if i<= q
    x(n+i)= x(n+i) + b(i:q)*flipud(e(length(e)+i-q : length(e)));
  end
end
pr= x(n+1 : n+nofs);
