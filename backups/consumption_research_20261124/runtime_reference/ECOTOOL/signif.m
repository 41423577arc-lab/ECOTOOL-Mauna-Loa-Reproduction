function x = signif(y,liminf,limsup)
% Auxiliar function of Vident

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% INPUT conditions
if nargin < 3 limsup=  2; end
if nargin < 2 liminf= -2; end

[m, n]= size(y);
x= zeros(m, n);
xx= ones(m, n);
x= x + (y> xx*limsup)*abs('+');
x= x + (y< xx*liminf)*abs('-');
x= char(x + (y<= xx*limsup & y>= xx*liminf)*abs('.'));
x= char(x + isnan(y)*abs('@'));
