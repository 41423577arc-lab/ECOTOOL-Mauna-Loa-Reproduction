function model = modelVARX(y, varargin)
% modelVARX   VAR model with eXogenous variables analysis
%
%       ARpoly(B) z(t)= Xpoly(B) u(t) + e(t)
%
% model = modelVARX(y, u, model, nofs, diffs, s, iter)
%
% model = modelVARX(y, 'property1', value1, 'property2', value2, ...)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   u:     Vector of input time series data (Nu x T or T x Nu)
%   model: (*) Model orders. Cell of vectors or matrices {1 x 1 or 1 x 2}
%          The first element correspondes to polynomial ARpoly(B)
%          The second element corresponds to polynomial Xpoly(B)
%          Each of these element may be a vector of specific orders or
%          a matrix
%          A matrix is the multivariate polynomial (m x any) in which 
%                 the positions to estimate are marked with a NaN
%          First block of coefficients in polynomial ARpoly(B) must be
%                 the identity matrix
%          First block of coefficients in polynomial Xpoly(B) 
%                 corresponds to lag 0, i.e. contemporaneous relation 
%                 between inputs and outputs
%          See examples below
%   nofs:  Forecast information. 
%          If model has no inputs, nofs is just the number of forecasts 
%                  ahead (1 x 1)
%          If model includes inputs, nofs nofs are the forecasts for 
%                  all the inputs (any x k)
%   diffs: Difference orders for outputs (the same as input 'order' to
%          vdif function)
%   s:     Types of differences (the same as input 's' to vdif function)
%   iter:  Maximum number of iterations when constraints are imposed 
%          upon the model (1 x 1)
% 
% OUTPUT:
%   model is a structure with a number of fields, including all the inputs
%   and the following ones, that are considered outputs to the function.
%     e:        Residuals of model
%     py:       Forecasts of output variables
%     stdpy:    Standard deviations of forecasts
%     ARpoly:   Estimated AR polynomial
%     Xpoly:    Estimated eXogenous polynomial
%     seARpoly: Standard Error of AR polynomial
%     seXpoly:  Standard Error of eXogenous polynomial
%     sigma:    Residual covariance matrix
%     table:    Estimation table of final model
%   
% Examples:
%    m1 = modelvarx(z, [], {[1 6]}, 12);
%    m1 = modelvarx(z, [], {[1 0 0 0 nan nan; 0 1 0 0 0 nan]}, 12);
%    m1 = modelvarx(z, u, {[1 6], [0 3]}, ones(12, 1));
%    m1 = modelvarx(z, u, {eye(2), [nan nan; 3 nan]}, ones(12, 1));
% 
% See Also: modelTF, modelETS, modelUC, modelAUTO, modelNAIVE

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
INPUTS = {'u', 'order', 'nofs', 'diffs', 's', 'iter'};
model = struct('type', 'modelVARX', ...
               'y', y, ...
               'u', [], ...
               'order', [], ...
               'nofs', [], ...
               'diffs', [], ...
               's', [], ...
               'iter', 1, ...
               'e', [], ...
               'py', [], ...
               'stdpy', [], ...
               'ARpoly', [], ...
               'Xpoly', [], ...
               'seARpoly', [], ...
               'seXpoly', [], ...
               'sigma', [], ...
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
     model.ARpoly, model.Xpoly, model.seARpoly, ...
     model.seXpoly, model.sigma, yinit, stats, model.table]= ...
            modelVARX0(model.y, model.u, model.order, ...
                     model.nofs, model.diffs, model.s, model.iter, 1);
else
    for i = 1 : length(varargin)
        model = setfield(model, INPUTS{i}, varargin{i});
    end
    [model.e, model.py, model.stdpy, ...
     model.ARpoly, model.Xpoly, model.seARpoly, ...
     model.seXpoly, model.sigma, yinit, stats, model.table]= ...
            modelVARX0(model.y, varargin{:});
end
