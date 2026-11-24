function yi= interpol(x, y, xi, limits)
% Interpolates a point xi according to the grid given by x and y
% If xi is outside the range defined in x, extrapolation is done instead

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 4, limits= []; end

% Eliminating equal values of x
ind= [find(diff(x(:))') length(x)];
x= x(ind);
y= y(ind);

if xi< x(1)
   X= [1 x(1);1 x(2)];
   b= X\y(1 : 2);
   yi= [1 xi]*b;
elseif xi> x(end)
   X= [1 x(end-1);1 x(end)];
   b= X\y(end-1 : end);
   yi= [1 xi]*b;
else
   yi= interp1(x, y, xi);
end

if ~isempty(limits)
   yi= max(yi, limits(1));
   yi= min(yi, limits(2));
end
