%% ECOTOOL Demo #1: Overview on Monthly Spanish electricity and gas demand
% This demo is just an overview of almost everything ECOTOOL can do.
% Data are monthly gas and electricity demand observations from
%   January 1992 to July 2009
%
% Adapted from Pedregal, D.J., Contreras, J., and Sánchez, A. (2010),
%   "ECOTOOL: A general MATLAB Forecasting Toolbox with 
%   applications to Electricity Markets", in: P.M. Pardalos, M.V.F. Pereira, N.A. Iliadis, 
%   S. Rebennack and A. Sorokin(eds), Handbook of Networks in Power
%   Systems, Springer Verlag.
%%
% First of all, let's load the data
load gasElec

%%
% Now display and run some descriptive stats and other tests wity toolTEST.
% You can do it in a simple way or supplying variable names.
% Play with the 'Tests', 'Series' and 'Options' menus
% Unit root tests, Box-Cox transformations, and other tests may be run
toolTEST(y);
%%
% It may be more convenient to use this code, instead
% Windows positions and other options may be stored selecting
% 'File' -> 'Save Windows Positions'
toolTEST(y, 'Names', 'Gas Electricity');

%%
% Taking logs stabilises the variance and differencing stabilises the mean
% This can be checked once more with the toolTEST function
% and we can also identify an ARIMA model with the option
% 'Univariate ACF and PACF' of the 'Tests' menu
% 'Vector ACF and PACF' and 'Granger causality tests' may also be interesting
z= log(y);

dz= vdif(z, [1 1], [1 12]);

toolTEST(dz, 'Names', 'Gas Electricity');

%%
% Usually time series are affected by calendar effects, like moving
%     festivals or trading days
u=[easter([1992 01], 213) trading([1992 01], 213)];

toolTEST(u, 'names', 'EASTER TRADING');

%%
% Let's define the ARIMA model, the estimation interval and the forecasting span
model1={'(1+ma1*B+ma2*B2)(1+ma12*B12)/(1-B)(1-B12)', 'w0', 'w1'};

z1= z(1:201, :); u1= u(1:201, :);

zf= y(202:end, :); uf= u(202:end, :);

%%
% Now is time to estimate ARIMA models for both series
% Mind that we are estimating by Exact Maximum Likelihood ('eml' input)
% with automatic detection and estimation of outliers (AO, IO, TC, LS)
% (indicated by the last 4 in the command line)
% Check how there are two ways to call the same function, i.e., in a
% standard input/output fashion, or by duplets with an object oriented
% flavor
m1 = modelTF(z1(:, 1), u1, model1, uf, 'eml', 4);

m2 = modelTF(z1(:, 2), 'u', u1, 'model', model1, ...
             'nofs', uf, 'method', 'eml', 'outlier', 4);

toolTEST([m1.e m2.e], 'Names', 'Gas Electricity');

%%
% Instead of ARIMA we may try Exponential Smoothing models
model2={'AA12', 'w0', 'w1'};

m3 = modelETS(z1(:, 1), u1, model2, uf, 'eml', 4);

m4 = modelETS(z1(:, 2), 'u', u1, 'model', model2, ...
              'nofs', uf, 'method', 'eml', 'outlier', 4);

toolTEST([m3.e m4.e], 'Names', 'Gas Electricity');

%%
% Another option available are Unobserved Components models
model3={'LLT12', 'w0', 'w1'};

m5 = modelUC(z1(:, 1), u1, model3, uf, 'eml', 4);

m6 = modelUC(z1(:, 2), u1, model3, uf, 'eml', 4);

toolTEST([m5.e m6.e], 'Names', 'Gas Electricity');

%%
% Finally, if a joint estimation is prefered, a VARX model may be run
%  and check the impulse or step response function and the module of roots
model4={[1:4 12:13 24:25], 0};

m7 = modelVARX(z1, 'u', u1, 'order', model4, 'nofs', uf, ...
               'diffs', [1  1], 's', [1  12]);

figure, varstep(m7.ARpoly, 30, 0);

figure, zplane(1, vRoots(m7.ARpoly));

figure, toolTEST(m7.e, 'Names', 'Gas Electricity');

%%
% We can compare forecasts with the toolFORECAST function
toolFORECAST(zf, exp([m1.py m2.py m3.py m4.py m5.py m6.py m7.py]));
