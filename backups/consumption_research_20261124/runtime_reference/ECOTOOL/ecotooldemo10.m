%% ECOTOOL Demo #10: Data interpolation and signal extraction
% Great Britain killed passengers and seriously injured in road accidents in cars
% Data are monthly from January 1969 to December 1984
%
% Load data and have a look
load victims

toolTEST(acc)
%%
% Let's take logarithms and introduce some artifitial missing values
y= log(acc);

y(100:124)= nan;

toolTEST(y);
%%
% Estimation with Unobserved Components with a Local Linear Trend
m1 = modelUC(y, [], 'LLT12', 12, 'eml', 3.8);

toolTEST([y m1.y0 m1.comp(:, 1)])

figure
toolTEST(m1.e);
%%
% In case smoother trend is prefered, try with the IRW trend
close all

m2 = modelUC(y, [], 'IRW12', 12, 'eml', 3.8);

toolTEST([y m2.y0 m2.comp(:, 1)])

figure
toolTEST(m2.e);


