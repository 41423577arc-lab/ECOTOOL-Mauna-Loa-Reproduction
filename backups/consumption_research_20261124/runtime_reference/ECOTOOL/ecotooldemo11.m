%% ECOTOOL Demo #11: Gas furnace
% Box-Jenkins gas furnace data
% 
% Box, G.P.E., Jenkins, G.M., and Reinsel, G.C. (2008),
%   Time Series Analysis Forecasting and Control, Fourth Edition, Wiley's Series
%   in Probability and Statistics.
load furnace

y= furnace(:, 1);
u= furnace(:, 2);

toolTEST([u y], 'names', 'Input Output');

y= y-nanmean(y); u= u-nanmean(u);
%%
% Model for input variable
modelu= '1/(1+ar1*B+ar2*B2+ar3*B3)';

m1 = modelTF(u, [], modelu, 12, 'eml');

alpha = m1.e;
toolTEST(alpha);

figure
zplane(0, m1.polys{2})
%%
% Prewhitening
% Check the cross-correlation function
beta= filter(m1.polys{2}, 1, y);
beta= beta(5 : end);

toolTEST([alpha beta], 'names', 'Input Output')
%%
% Transfer Function estimation
model= {'(1)/(1+ar1*B+ar2*B2)', '(w3*B3+w4*B4+w5*B5)/(1+d1*B+d2*B2)'};

m2 = modelTF(y, u, model, 0, 'eml');

toolTEST(m2.e);
%%
% Are the residuals correlated with input?
vident2([alpha m2.e(2 : end)]);

%%
% Are there any outliers?
m3 = modelTF(y, u, model, 0, 'eml', 4);
%%
% Is there any feedback? Try a bivariate model
m4 = modelVARX([u y], [], [1 2 3 4 5 6 ]);

%%
% Stationarity and Impulse response function
close all
zplane(0, vRoots(m4.ARpoly))

figure
varstep(m4.ARpoly, 20, 0);

%%
% Constrained estimation with VAR model
model= [1 0 nan 0   nan 0   nan 0   0   0   0   0 0   0; ...
        0 1 0   nan 0   nan nan nan nan nan nan 0 nan 0];
    
m5 = modelVARX([u y], [], model);

toolTEST(m5.e);
