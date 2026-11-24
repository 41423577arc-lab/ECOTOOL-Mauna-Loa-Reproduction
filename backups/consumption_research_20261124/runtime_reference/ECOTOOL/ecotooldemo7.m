%% ECOTOOL Demo #7: Steel consumption in the UK
% Data is quarterly steel consumption in the UK, measured in thousands of metric tons,
% from the last quarter of 1953 until the end of 1992.
%
% Load data and check the mean features
load steel

toolTEST(steel);

y= log(steel(1 : end-12));
%%
% Unobserved Components modelling
m1 = modelUC(y, [], 'LLT4', 12, 'eml', 4);

toolTEST(m1.e);
%%
% We may also have a look at the actual values compared to the series without the outliers
% or the components
toolTEST([y y - sum(m1.comp(:, 4 : 5), 2)]);

figure
toolTEST(m1.comp);
%%
% Exponential Smoothing modelling
close all
m2 = modelETS(y, [], {'AA4'}, 12, 'eml', 4);

toolTEST(m2.e);
%%
% We may also have a look at the actual values compared to the series without the outliers
% or the components
toolTEST([y y - sum(m2.comp(:, 4 : 5), 2)]);

figure
toolTEST(m2.comp);
%%
% ARIMA model is also possible
model= '(1+ma1*B)(1+ma4*B4)/(1-B)(1-B4)';

m3 = modelTF(y, [], model, 12, 'eml', 4);
%%
% Finally, forecast comparisons
toolFORECAST(steel, exp([m1.py m2.py m3.py]));
