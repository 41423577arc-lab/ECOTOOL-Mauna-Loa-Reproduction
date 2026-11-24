function npar= findnparet(mfun, varargin)
% Find the number of parameters in a SS model defined in a function

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

npar= 0;
for i= 1 : 1000
    try
        eval([mfun '((1 : i)'', varargin{:});']);
    catch
        npar= npar + 1;
    end
end
npar= npar + 1;
