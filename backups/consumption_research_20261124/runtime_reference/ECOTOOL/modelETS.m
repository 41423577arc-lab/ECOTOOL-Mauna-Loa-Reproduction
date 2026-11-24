function model = modelETS(y, varargin)
% modelETS   Exponential Smoothing modelling
%
% model = modelETS(y, u, model, nofs, method, outlier, par0)
%                  1  2    3      4     5       6      7
%
% model = modelETS(y, 'property1', value1, 'property2', value2, ...)
%
% INPUTS:
%   y:     (*) Output time series data (1 x T or T x 1)
%   u:     Vector of input time series data (Nu x T or T x Nu)
%   model: Model Structure. Cell of strings with k+1 elements 
%          containing the ratio of polynomials written as a function 
%          of the backwardshift operator B.
%          The first element is the ES model for the noise. The rest 
%          are the k TF functions
%          Types of ES models are:
%                'NN':  No trend, no seasonal
%                'AN':  Additive trend, no seasonal
%                'DN':  Damped trend, no seasonal
%                'NA#': No trend, additive seasonal of period #
%                'AA#': Additive trend, additive seasonal of period #
%                'DA#': Damped trend, additive seasonal of period #
%   nofs:  Forecast information. 
%          If model is univariate ES, nofs is just the number of 
%          forecasts ahead (1 x 1) 
%          If model is TF with deterministic inputs, nofs are the forecasts
%               for all the inputs into the future (any x k)
%   method:  'EML' or -1 for Exact Maximum Likelihood
%            'CML' or  0 for Conditional Sum of Squares (Default)
%   outlier: Automatic detection of Additive (AO), Innovative (IO), 
%                 Level Shift (LS) and Transitory Change (TC) outliers
%            (1x1, 1x2 or 1x3). First element is the constant reference (default 4)
%                               Second element is the number of iterations (default is 3)
%                               Third element is the denominator for TC outliers
%   par0:    Vector of inital estimates to start the search
% 
% OUTPUT:
%   model is a structure with a number of fields, including all the inputs
%   and the following ones, that are considered outputs to the function.
%     e:        Residuals of model
%     py:       Forecasts of output variable
%     stdpy:    Standard deviations of forecasts
%     comp:     Level, seasonal, irregular, and outlier components
%     par:      Vector of parameter estimates
%     covpar:   Covariance matrix of estimates
%     y0:       Output series with outliers removed and interpolation 
%               of missing values
%     table:    Estimation table of final model
%   
% Examples:
%    m1 = modelETS(z, [], 'AA12', 24, 4);
%    m1 = modelETS(z, u, {'AA12', 'w0/(1+d1B)'}, ones(12, 1));
%
% See Also: modelVARX, modelTF, modelUC, modelAUTO, modelNAIVE

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
INPUTS = {'u', 'model', 'nofs', 'method', 'outlier', 'par0'};
model = struct('type', 'modelETS', ...
               'y', y, ...
               'u', [], ...
               'model', 'AA12', ...
               'nofs', 12, ...
               'method', 'EML', ...
               'outlier', [0 1 1 1 1 0.7 3], ...
               'par0', [], ...
               'e', [], ...
               'py', [], ...
               'stdpy', [], ...
               'comp', [], ...
               'par', [], ...
               'covpar', [], ...
               'y0', [], ...
               'table', '');
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
    [model.e, model.py, model.stdpy, ...
     model.comp, model.par, model.covpar, ...
     model.y0, model.table]= ...
            modelETS0(model.y, model.u, model.model, ...
                     model.nofs, model.method, model.outlier, model.par0);
else
    for i = 1 : length(varargin)
        model = setfield(model, INPUTS{i}, varargin{i});
    end
    [model.e, model.py, model.stdpy, ...
     model.comp, model.par, model.covpar, ...
     model.y0, model.table]= ...
            modelETS0(model.y, varargin{:});
end

