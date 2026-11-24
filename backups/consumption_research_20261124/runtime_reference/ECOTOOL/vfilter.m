function z= vfilter(B, A, u)
% VFILTER   Filters a vector of inputs with a vector digital filter
%    y = vfilter(B, A, u)
%
% INPUTS:
%  B:  (*) Numerator vector polynomial (m x Nb*Nu)
%  A:  Denominator vector polynomial (m x Na*m)
%  u:  Inputs vector (T x Nu)
%
% OUTPUTS:
%  y:  Filtered outputs (T x m  or  T x m)
%
% See Also: vdif, vConv, vRoots
%
% Examples:
%    u= [zeros(100, 1); ones(100, 1)];
%    y= vfilter([2; 1], [1 0 -1.2 0 0.8 0.4; 0 1 0.3 -0.8 -0.3 0.6], u)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[rB, cB]= size(B);
[rA, cA]= size(A);
[Nu, T]= size(u);
if Nu> T, u= u'; [Nu, T]= size(u); end

if rA== 1, z= filter(B, A, u); return, end

A0= A(:, 1:rA); I0= eye(rA);
if ~all(A0(:)== I0(:))
   errorSSpace('First block coefficient of polynomial A is not the identity matrix.', 'vfilter');
end

oA= cA / rA -1;
oB= cB / Nu -1;
order= max(oA, oB);

z= zeros(rA, T);
for i= order+1 : T
   for j= 0 : order
      if (j<= oA & j>0), z(:, i)= z(:, i) - A(:, j*rA+1 : (j+1)*rA)*z(:, i-j); end
      if j<= oB, z(:, i)= z(:, i) + B(:, j*Nu+1 : (j+1)*Nu)*u(:, i-j); end
   end
end
