%% ECOTOOL Demo #9: Lydia Pynkham advertisement - sales data
% Lydia Pinkham annual advertising and sales (1907-1960)
% 
% W.W.S. Wei (2006), 'Time Series Analysis : Univariate and Multivariate Methods',
% Addison-Wesley.
%
% Are time series stationary?
load Lydia_Pinkham

u= Lydia_Pinkham(:, 1)/100;
y= Lydia_Pinkham(:, 2)/100;

z= [u y];

toolTEST(z, 'names', 'Advert Sales');
%%
% Identify model and reserve the last 14 years for forecasting assessment
% Check Granger causality
% Does a constrained model make any sense?
toolTEST(vdif(z), 'names', 'Advert Sales');

m1 = modelVARX(z(1:40, :), [], [1 2], 14, 1, 1);
%%
% Estimating constrained model
model= [1 0 nan nan nan 0;0 1 nan nan nan 0];

m2 = modelVARX(z(1:40, :), [], model, 14, 1, 1);

toolTEST(m2.e);
%%
% Stationarity, impulse response function and forecasting
close all
zplane(0, vRoots(m2.ARpoly));

figure
varstep(m2.ARpoly, 20, 0);

figure
toolFORECAST(z, m2.py, [m2.py-2*m2.stdpy m2.py+2*m2.stdpy]);
