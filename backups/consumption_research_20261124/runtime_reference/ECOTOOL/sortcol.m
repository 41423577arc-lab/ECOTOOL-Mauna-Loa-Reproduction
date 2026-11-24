function zs= sortcol(z, i)
% SORTCOL   Sorting of a matrix by a column order
%   ys= sortcol(y, i)
%
% INPUTS:
%   y:  (*) Matrix of numbers (m1 x m2)
%   i:  Column that serves as the basis for the sorting operation (1x1)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 2, i= 1; end

[rows, cols]= size(z);
[zi, indx]= sort(z(:, i));
zs= z(indx, :);
