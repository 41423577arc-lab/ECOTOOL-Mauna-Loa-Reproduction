function model = modelAUTO(y, varargin)
% modelAUTO   Automatic identification of ARIMA models
%
% model = modelAUTO(y, u, s, diffs, boxcox, nofs, outlier, method)
% 
% model = modelAUTO(y, 'property1', value1, 'property2', value2, ...)
%
% INPUTS or Property values (string variables):
%   y:      (*) Output time series data (1 x T or T x 1)
%   u:      Vector of input time series data (Nu x T or T x Nu)
%   s:      Seasonal periods including 'regular' period, e.g. for 
%           regular and monthly operators on monthly data s = [1 12]
%   diffs:  Test for differencing on/off in the identification 
%           procedure (1/0)
%   boxcox: Transform data with boxcox transformation before running 
%           identification 
%   nofs:   Forecast information. 
%           If model is univariate ARIMA, nofs is just the number of 
%               forecasts ahead (1 x 1)
%           If model is TF with deterministic inputs, nofs are the 
%               forecasts for all the inputs into the future (any x k)
%           If model is TF with stochastic inputs, nofs is the model 
%               for each input, the format is the same as the output 
%               'polys' to this function (a cell of vectors with the
%               polynomial values). Forecasts for the inputs and 
%               standard deviations are computed inside the function
%   outlier: Automatic detection of Additive (AO), Innovative (IO), 
%                 Level Shift (LS) and Transitory Change (TC) outliers
%            (1xn, n=1 ... 7).  First element is the constant reference
%                               (default 3)
%                               Second to fifth are [AO IO LS TC]
%                               on/off outliers detection
%                               Sixth element is the denominator for 
%                               TC outliers Seventh element is the 
%                               number of iterations (default is 3)
%   method: Either a single string or a cell 1x2
%           method{1} may be either 'EML' or -1 for Exact Maximum 
%                                         Likelihood, or
%                                   'CML' or  0 for Conditional Sum 
%                                         of Squares (Default)
%                                   'NONE' for no estimation, then 
%                                         par0 are used as parameters
%           method{2} are the initial values (out of sample) of the 
%                     input variables u
% 
% OUTPUT:
%   model is a structure with a number of fields, including all the inputs
%   and the following ones, that are considered outputs to the function.
%     e:        Residuals of model
%     py:       Forecasts of output variable
%     stdpy:    Standard deviations of forecasts
%     model:    String containing the model identified (input to modelTF)
%     par:      Vector of parameter estimates
%     covpar:   Covariance matrix of estimates
%     y0:       Output series with outliers removed and interpolation 
%               of missing values
%     tfout:    Transfer funciton responses for all inputs
%     uout:     All inputs in the final model
%     table:    Estimation table of final model
%
% See Also: modelTF, modelVARX, modelETS, modelUC, modelNAIVE

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
INPUTS = {'u', 's', 'diffs', 'boxcox', 'nofs', 'outlier', 'method'};
model = struct('type', 'modelAUTO', ...
               'y', y, ...
               'u', [], ...
               's', 1, ...
               'diffs', 1, ...
               'boxcox', 1, ...
               'nofs', 12, ...
               'outlier', [0 1 1 1 1 0.7 3], ...
               'method', 'CML', ...
               'e', [], ...
               'py', [], ...
               'stdpy', [], ...
               'model', [], ...
               'par', [], ...
               'covpar', [], ...
               'y0', [], ...
               'tfout', [], ...
               'uout', [], ...
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
     model.model, model.par, model.covpar, ...
     model.y0, model.tfout, model.uout, ...
     AIC, obj, model.table]= ...
            modelAUTO0(model.y, model.u, model.s, ...
                       model.diffs, model.boxcox, ...
                       model.nofs, model.outlier, model.method);
else
    for i = 1 : length(varargin)
        model = setfield(model, INPUTS{i}, varargin{i});
    end
    [model.e, model.py, model.stdpy, ...
     model.model, model.par, model.covpar, ...
     model.y0, model.tfout, model.uout, ...
     AIC, obj, model.table]= ...
            modelAUTO0(model.y, varargin{:});
end

