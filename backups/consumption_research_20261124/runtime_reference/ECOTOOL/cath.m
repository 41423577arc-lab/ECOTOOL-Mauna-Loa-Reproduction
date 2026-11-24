function x= cath(varargin)
% CATH   Horizontal concatenation of matrices of any dimesions
%    x= cath(matrix1, matrix2, ...)
%
% INPUTS:
%  matrix#:  matrices of any dimesions
%
% OUTPUTS:
%  x:  Horizontal concatenation of all input matrices
%
% See Also: delay 
%
% Examples:
%    cath(ones(10,1), zeros(5,3), 2*ones(7,2))

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

N= size(varargin, 2);
sizes= zeros(N+1, 2);
for i= 1 : N
    sizes(i+1, :)= size(varargin{i});
end
sizes(:, 2)= cumsum(sizes(:, 2));
NN= max(sizes(:, 1));
x= nan(NN, sizes(end, 2));
for i= 2 : N+1
    x(end-sizes(i, 1)+1 : end, sizes(i-1, 2)+1 : sizes(i, 2))= varargin{i-1};
end
