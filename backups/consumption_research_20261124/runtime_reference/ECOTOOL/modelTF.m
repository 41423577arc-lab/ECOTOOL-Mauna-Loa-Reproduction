function model = modelTF(y, varargin)
% modelTF   MISO Transfer Function analysis
%
%            B1(B)                 Bk(B)           C(B)
%    y(t)= ------- u1(t) + ... + ------- uk(t) + ------ e(t)
%            D1(B)                 Dk(B)           P(B)
%
%    model = modelTF(y, u, model, nofs, method, outlier, par0)
%
%    model = modelTF(y, 'property1', value1, 'property2', value2, ...)
%
% INPUTS:
%   y:     (*) Output time series data (1 x T or T x 1)
%   u:     Vector of input time series data (Nu x T or T x Nu)
%   model: Model Structure. Cell of strings with k+1 elements 
%          containing the ratio of polynomials written as a function 
%          of the backwardshift operator B
%          The first element is the model for the noise. The rest are 
%          the k TF functions. See examples below
%   nofs:  Forecast information. 
%          If model is univariate ARIMA, nofs is just the number of 
%               forecasts ahead (1 x 1)
%          If model is TF with deterministic inputs, nofs are the 
%               forecasts for all the inputs into the future (any x k)
%          If model is TF with stochastic inputs, nofs is the model 
%               for each input, the format is the same as the output 
%               'polys' to this function (a cell of vectors with the
%               polynomial values). Forecasts for the inputs and 
%               standard deviations are computed inside the function
%   method: Either a single string or a cell 1x2
%           method{1} may be either 'EML' or -1 for Exact Maximum Likelihood, or
%                                   'CML' or  0 for Conditional Sum of Squares (Default)
%                                   'NONE' for no estimation, then par0 are used as parameters
%           method{2} are the initial values (out of sample) of the 
%                     input variables u
%   outlier: Automatic detection of Additive (AO), Innovative (IO), 
%                 Level Shift (LS) and Transitory Change (TC) outliers
%            (1xn, n=1 ... 7).  First element is the constant reference
%                               (default 3)
%                               Second to fifth are [AO IO LS TC]
%                               on/off outliers detection
%                               Sixth element is the denominator for 
%                               TC outliers Seventh element is the 
%                               number of iterations (default is 3)
%   par0:    Vector of inital estimates to start the search
% 
% OUTPUT:
%   model is a structure with a number of fields, including all the inputs
%   and the following ones, that are considered outputs to the function.
%     e:        Residuals of model
%     py:       Forecasts of output variable
%     stdpy:    Standard deviations of forecasts
%     polys:    Numerical cell array with estimated polynomials
%     par:      Vector of parameter estimates
%     covpar:   Covariance matrix of estimates
%     y0:       Output series with outliers removed and interpolation 
%               of missing values
%     tfout:    Transfer funciton responses for all inputs
%     uout:     All inputs in the final model
%     modelout: Full model, including models for outliers
%     table:    Estimation table of final model
%   
% Examples:
%    m1 = modeltf(z, [], '(1+ma1B)(1+ma12B12)/(1-B)(1-B12)', 24, 4);
%    m1 = modeltf(z, u, {'(1+ma1B)(1+ma12B12)/(1-B)(1-B12)', 'w0/(1+d1B)'}, ones(12, 1));
%
% See Also: modelVARX, modelETS, modelUC, modelNAIVE, modelAUTO

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
model = struct('type', 'modelTF', ...
               'y', y, ...
               'u', [], ...
               'model', '(1+p1*B)(1+p2*B12)/(1-B)(1-B12)', ...
               'nofs', 12, ...
               'method', 'EML', ...
               'outlier', [0 1 1 1 1 0.7 3], ...
               'par0', [], ...
               'e', [], ...
               'py', [], ...
               'stdpy', [], ...
               'polys', [], ...
               'par', [], ...
               'covpar', [], ...
               'y0', [], ...
               'tfout', [], ...
               'uout', [], ...
               'modelout', [], ...
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
     model.polys, model.par, model.covpar, ...
     model.y0, model.tfout, model.uout, ...
     model.modelout, AIC, obj, model.table]= ...
            modelTF0(model.y, model.u, model.model, ...
                     model.nofs, model.method, model.outlier, model.par0);
else
    for i = 1 : length(varargin)
        model = setfield(model, INPUTS{i}, varargin{i});
    end
    [model.e, model.py, model.stdpy, ...
     model.polys, model.par, model.covpar, ...
     model.y0, model.tfout, model.uout, ...
     model.modelout, AIC, obj, model.table]= ...
            modelTF0(model.y, varargin{:});
end
