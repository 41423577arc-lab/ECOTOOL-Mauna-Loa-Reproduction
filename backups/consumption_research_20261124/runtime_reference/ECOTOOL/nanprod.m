function [AB, indx]= nanprod(A, B)
% NANPROD  Product of matrices with NaN values
%   [AB, indx]= nanprod(A, B)
%
% INPUTS:
%  A:  (*) Matrix (m1 x m2)
%  B:  (*) Matrix (m2 x m3)
%
% OUTPUTS:
%  AB:   Product A*B
%  indx: Number of non NaN elements in each row by column product
%
% See Also: nancov, nancorr, nancumsum, nanprod, meda

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[rA, cA]= size(A);
[rB, cB]= size(B);

if cA~=rB, errorSSpace('Inner matrix dimensions must agree', 'nanprod'); end
AB= zeros(rA, cB); indx= AB;

for i=1:rA
   ABi= repmat(A(i, :), cB, 1)'.*B;
   ind= ~isnan(ABi);
   indx(i, :)= sum(ind);
   AB(i, :)= nansum(ABi);
end
