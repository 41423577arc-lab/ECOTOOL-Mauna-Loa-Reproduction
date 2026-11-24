%% ECOTOOL Demo #2: Overview on hourly Spanish electricity demand and prices
% This is a demo of robustness and dimensionallity of models that ECOTOOL support
% The data comprises hourly loa demand and prices for the Spanish market,
% from July 1st 2009 up to 5th October 2009.
%
% Adapted from Pedregal, D.J., Contreras, J., and Sánchez, A. (2010),
%   "ECOTOOL: A general MATLAB Forecasting Toolbox with 
%   applications to Electricity Markets", in: P.M. Pardalos, M.V.F. Pereira, N.A. Iliadis, 
%   S. Rebennack and A. Sorokin(eds), Handbook of Networks in Power
%   Systems, Springer Verlag.
%%
% Let's load the hourly data and have a look at them
load electricity

z= y(1 : end-24, :);

zf= y(end-23 : end, :);

u= ones(2448, 1); uf= ones(24, 1);

toolTEST(z, 'Names', 'Price Demand');

z= log(z);
%%
% Let's estimate a big ARIMA model for Demand
modeld1={['(1-ma23*B23-ma24*B24-ma25*B25-ma48*B48-ma96*B96)(1-ma168*B168)/' ...
    '(1-ar1*B-ar2*B2-ar3*B3-ar4*B4-ar5*B5)(1-ar24*B24-ar48*B48-ar96*B96)' ...
    '(1-ar168*B168-ar336*B336-ar504*B504)(1-B)(1-B24)(1-B168)'], ...
    'constant/(1-B)(1-B24)(1-B168)'};

m1 = modelTF(z(:, 2), u, modeld1, uf, 'cml');

toolTEST(m1.e);
%%
% It may be identified automatically!!

m1b = modelAUTO(z(:, 2), [], [1 24 168]);

%%
% Now we can forecast still a bigger price model on the basis of a Transfer Function
model={['(1-ma24*B24-ma48*B48-ma96*B96)(1-ma168*B168)/' ...
    '(1-ar1*B-ar2*B2-ar3*B3-ar4*B4-ar5*B5- ar6*B6-ar7*B7-ar8*B8)' ...
    '(1-ar23*B23-ar24*B24-ar25*B25-ar48*B48-ar96*B96)' ...
    '(1-ar168*B168-ar336*B336-ar504*B504)(1-B)(1-B24)(1-B168)'], ...
    '(constant)/(1-B)(1-B24)(1-B168)', ...
    ['(1-d1*B-d2*B2-d3*B3-d4*B4-d5*B5)' ...
    '(1-d24*B24-d25*B25-d48*B48-d49*B49-d72*B72-d73*B73-d96*B96-d97*B97-d120*B120-d121*B121-d144*B144-d145*B145)' ...
    '(1-d168*B168-d169*B169-d192*B192-d193*B193-d336*B336-d504*B504)']};

m2 = modelTF(z(:, 1), [u z(:, 2)], model, [uf m1.py], 'cml');

toolTEST(m2.e);
%%
% Finally we evaluate price forecasts
toolFORECAST(zf(:, 1), exp(m2.py), [exp(m2.py-2*m2.stdpy) exp(m2.py+2*m2.stdpy)]);
