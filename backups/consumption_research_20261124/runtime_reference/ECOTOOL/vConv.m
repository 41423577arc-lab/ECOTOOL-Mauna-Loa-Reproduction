function C = vConv(A, B, coefA, coefB)
% vConv  Multiplication of vector polynomials
%
%   C = vConv(A, B, cA, cB);
%
% INPUTS:
%  A:  (*) Vector polynomial
%  B:  (*) Vector polynomial
%  cA: Number of columns that define block parameters of poly A
%  cB: Number of columns that define block parameters of poly B
%
% OUTPUTS:
%  C: Multiplication of vector polynomials A and B
%
% See Also: vdif, vfilter, vRoots

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin==1 errorSSpace('Not enought inputs arguments', 'vConv'); end
[rA, cA]= size(A);
[rB, cB]= size(B);

if (rA== 1 & rB== 1), C= conv(A, B); return, end

% INPUT conditions
if nargin<3; coefA= rA; end;
if nargin<4; coefB= rB; end;

if coefA~= rB, errorSSpace('Inner matrix dimensions must agree.', 'vConv'); end

oA= cA / coefA -1;
oB= cB / coefB -1;

oC= oA + oB;
C= zeros(rA, (oC+1)*coefB);
coefC= coefB;

for i= 0:oA
   for j= 0:oB
      Ai= A(:, i*coefA+1 : (i+1)*coefA);
      Bj= B(:, j*coefB+1 : (j+1)*coefB);
      indx= ((i + j)*coefC +1 : (i + j + 1)*coefC); 
      C(:, indx)= C(:, indx) + Ai * Bj;
   end
end
