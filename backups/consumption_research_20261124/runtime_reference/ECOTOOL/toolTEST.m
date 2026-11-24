function toolTEST(z, varargin)
% toolTEST   Graphical User Interface to access diagnostic tools
%
%    tooltest(y, 'names', stringnames, 'fun1', opt1, 'fun2', opt2, ...)
%
% INPUTS:
%   y: (*) Vector time series data (m x T or T x m)
%      The rest of inputs are optional and have to be supplied by pairs of 
%      variables, the first indicate a function name, the second the inputs
%      to that function. opt1, opt2, ... has to be cell variables
%      Valid Function names are (see the help of all these functions to 
%      know what the pair input can be):
%          plotband, vboxplot, vtboxplot, vscatter, sumstats, vhist,
%          vqqplot, gausstest, vident, vident2, varsbc, vgranger, vcusum,
%          stdmean, testhet, vboxcox, adftest, vphillips, johansentest,
%          nltests, vtsay, varsbc2, vbds, vcumperiod, vspectrum,
%          varspectrum
%      'names' is used to supply a set of names for the variables in input y 
%               (may be a string or a string matrix)
%      All the options for any function may be changed within the GUI, 
%          making the first
%          input the only one compulsory
% 
% See Also: toolFORECAST
%
% Examples:
%   y= randn(300, 3);
%   toolTEST(y);
%   toolTEST(y, 'names', 'Series1 Series2 Series3');
%   toolTEST(y, 'vident', {50, 4, 1}, 'varspectrum', 11);

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

toolTEST0(z, varargin{:});
