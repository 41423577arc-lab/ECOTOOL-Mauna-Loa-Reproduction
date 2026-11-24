function [y, difpoly]= vdif(x, order, s)
% VDIF    Differenciation of a vector of variables
%    yd = vdif(y, order, s)
%
% INPUTS:
%  y:     (*) Vector time series data (m x T or T x m)
%  order: Difference orders for multiplicative polynomials (1 x any, 
%         default is 1)
%  s:     Seasonal parameter for each polynomial (1 x any, 
%         default is 1)
%
% OUTPUTS:
%  yd:    Differenced data (m x <T)
%
%  Examples:
%    y= randn(500, 3);
%    vdif(y, [2 1], [1 12])
%    vdif(y, [2 1; 1 0], [1 12])
%    vdif(y, [2 1; 1 0; 2 1], [1 12])
%    vdif(y, [1 1 1], [1 24 168])
%
% See Also: vfilter, vConv, vRoots

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[T, m]= size(x);
if T< m, x= x'; [T, m]= size(x); end
y= nan* ones(T, m);

if nargin<3, s= ones(m, 1); end
if isempty(s), s= ones(m, 1); end
[rs, cs]= size(s);
if rs< m, send= s(end, :); s= [s; send(ones(m-rs, 1), :)]; end

if nargin<2, order= ones(m, 1); end
if isempty(order), order= ones(m, 1); end
[ro, co]= size(order);
if ro< m, oend= order(end, :); order= [order; oend(ones(m-ro, 1), :)]; end

lA= 0; difpoly= zeros(m, max(sum(s'))*m+m);
for i= 1:m
   A= 1;
   for j= 1:co
     for k= 1:order(i, j)
         if s(i, j)>0, A= conv(A, [1 zeros(1, s(i, j)-1) -1]); end
     end
  end
  sA= size(A, 2);
  lA= max([lA sA]);
  y(:, i)= filter(A, 1, x(:, i));
  difpoly(i, i : m : sA*m)= A;
end
y= y(lA:T, :); 


