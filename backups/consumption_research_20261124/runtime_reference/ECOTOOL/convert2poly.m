function polysnum= convert2poly(strucnumerical, x)
% Convert a numerical structure into an ARMAX model
% armaxpoly= {A, C, B1, B2, ...} 
%    A(B) y(t)= B1(B) u1(t) + B2(B) u2(t) + ... + C(B) a(t)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

N= size(strucnumerical, 1);
polysnum= num2cell(ones(N, 2));
for i= 1 : N
    polysnum{i, 1}= eval(strucnumerical{i, 1});
    polysnum{i, 2}= eval(strucnumerical{i, 2});
end

