function tsi=arma2tsi(ar, ma, n)
% tsi=arma2tsi(ar, ma, n)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin<3, n= 100; end

tsi= filter(ma, ar, [1;zeros(n-1, 1)]);

