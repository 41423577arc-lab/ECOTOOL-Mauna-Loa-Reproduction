function model = modelNAIVE(y, varargin)
% modelNAIVE   Forecasting with naive methods (mean, naive, 
%              naive seasonal, mean naive, mean change, mean mean change)
%
% model = modelNAIVE(y, nofs, s)
% 
% model = modelAUTO(y, 'property1', value1, 'property2', value2)
%
% INPUTS:
%   y:     (*) Output time series data (1 x T or T x 1)
%   nofs:  Number of forecasts
%   s:     Seasonal period
%
% OUTPUT:
%   model is a structure with a number of fields, including all the inputs
%   and the following ones, that are considered outputs to the function.
%      py: Forecasts of output variable
%          Column 1: Mean method
%          Column 2: Naive method
%          Column 3: Naive seasonal method
%          Column 4: Mean naive method
%          Column 5: Drift method
%          Column 6: Mean Drift method
%
% See Also: modelVARX, modelETS, modelUC, modelTF, modelAUTO

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% Initializing
INPUTS = {'nofs', 's'};
model = struct('type', 'modelNAIVE', ...
               'y', y, ...
               'nofs', 12, ...
               's', 12, ...
               'py', []);
% Recovering inputs structure from inputs to function
[inputs, tuplets] = checkInputs(INPUTS, varargin{:});
if tuplets
    % Filling inputs to model structure
    for i = 1 : length(INPUTS)
        inputsI = getfield(inputs, INPUTS{i});
        if ~isempty(inputsI)
            model = setfield(model, INPUTS{i}, inputsI);
        end
    end
    % Running function
    model.py = modelNAIVE0(model.y, model.nofs, model.s);
else
    for i = 1 : length(varargin)
        model = setfield(model, INPUTS{i}, varargin{i});
    end
    model.py = modelNAIVE0(model.y, varargin{:});
end

