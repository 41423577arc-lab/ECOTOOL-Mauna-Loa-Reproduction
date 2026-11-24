function polyc= mconv(varargin)
% mconv   Convolution of any number of vectors/polynomials
%   A= mconv(poly1, poly2, ...)
%
% INPUTS:
%  poly1:   Polynomial in backshift operator (1 x T)
%  poly2:   Polynomial in backshift operator (1 x T)
%  ...
%
% OUTPUTS:
%  A:   Convolution of all inputs
%
% See Also: conv, vConv

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin== 1
    polyc= varargin{1};
elseif nargin== 2
    polyc= conv(varargin{1}, varargin{2});
else
    polyc= conv(varargin{end}, mconv(varargin{1 : end-1}));
end