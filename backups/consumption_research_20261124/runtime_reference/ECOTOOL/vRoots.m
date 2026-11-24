function r= vRoots(Vpoly)
% vRoots  Calculates the roots of a vector polynomial
%
%    r= vRoots(A)
%
% INPUTS:
%  A: (*) Vector polynomial (m x Na*m)
%
% OUTPUTS:
%  r: Roots of A
%
% See Also: vdif, vfilter, vConv

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[m, lags]= size(Vpoly);
C1= Vpoly(:, 1:m);
iC1= inv(C1);
C2= eye(m);
if any(C1(:)~= C2(:))
   for i= 2:lags/m
      Vpoly(:, (i-1)*m+1 : i*m)= Vpoly(:, (i-1)*m+1 : i*m)*iC1;
   end
end
F= [-Vpoly(:, m+1:lags); [eye(lags-2*m) zeros(lags-2*m, m)]];
r= eig(F);






