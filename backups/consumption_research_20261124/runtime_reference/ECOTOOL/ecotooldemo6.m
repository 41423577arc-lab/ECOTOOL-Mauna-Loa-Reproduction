%% ECOTOOL Demo #6: US GDP 
% The Hodrick-Prescott filter is a well known low pass filter used very
% often in Economics to detrend time series.
% One of such time series to which it was applied at an early stage
% was the US GNP. Here we are applying it to the seasonally adjusted US GDP.

%%
% Load data and do initial checks
load usgdp

toolTEST(usgdp, 'names', 'GDP');

y= log(usgdp);

%%
% Hodrick and Prescott said in their seminal paper that a reasonable
% value of the smoothing constant for quarterly macroeconomic data was 1600.
m1 = modelUC(y, [], 'HP1600');

toolTEST([y m1.comp], 'names', 'GDP Trend Seasonal Detrended');
%%
% We can explore trend changes depending on the smoothing constant.
m2 = modelUC(y, [], 'HP500000');

m3 = modelUC(y, [], 'HP10');

toolTEST([y m1.comp(:, 1) m2.comp(:, 1) m3.comp(:, 1)]);
%%
% Also the changes on the perturbations may be analysed
toolTEST([m1.comp(:, 3) m2.comp(:, 3) m3.comp(:, 3)]);
%%
% What does happen if the smoothing constant is estimated instead?
m4 = modelUC(y, [], 'HP');

toolTEST([y m4.comp(:, 1)], 'names', 'GDP Trend');
