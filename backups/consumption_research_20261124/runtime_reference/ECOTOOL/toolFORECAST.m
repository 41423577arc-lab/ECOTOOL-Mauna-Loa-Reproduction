function toolFORECAST(z, zh, stdzh, origin, Names, win, seriesval, numf)
% toolFORECAST   Forecasting tool
%
%    toolFORECAST(y, py, stdpy, origin)
%
% INPUTS:
%   y:      (*) Vector of actual data (m x T or T x m)
%   py:     (*) Vector of forecast data (n*m x any or any x n*m)
%   stdpy:  Confidence bands (2*n*m x any or any x 2*n*m)
%           This is the typical output stdpz of modelTF or modelVARX
%   origin: Forecast origin (1 x 1)
%
%   It is possible to plot as many forecasts as desired for any set of time series.
%   The length of the actual values and the forecasts do not need to be the same
%   and they are adjusted by means of the input 'origin'.
% 
% See Also: modelTF, modelVARX, toolTEST

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


% win= 0:  run independently
% win= 1:  run from menu Forecasts callback
% win= 2:  run from menu Series callback
% win= 3:  run from <<< button
% win= 4:  run from >>> button
% win= 5:  run from edit uicontrol
% win= 6:  print table
% win= 7:  Run from options menu

if nargin == 1
    toolFORECAST0(z)
elseif nargin == 2
    toolFORECAST0(z, zh)
elseif nargin == 3
    toolFORECAST0(z, zh, stdzh)
elseif nargin == 4
    toolFORECAST0(z, zh, stdzh, origin)
else
    toolFORECAST0(z, zh, stdzh, origin, Names)
end







