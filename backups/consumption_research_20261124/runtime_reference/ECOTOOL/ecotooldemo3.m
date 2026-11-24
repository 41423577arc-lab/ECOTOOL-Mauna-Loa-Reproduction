%% ECOTOOL Demo #3: ARIMA modelling
% The classical Airline Box-Jenkins data presented as a tutorial on ARIMA modelling with ECOTOOL
% 
% Taken from Box, G.P.E., Jenkins, G.M., and Reinsel, G.C. (2008),
%   Time Series Analysis Forecasting and Control, Fourth Edition, Wiley's Series
%   in Probability and Statistics. 

%%
% Let's load the airline data and have a look at them
load airpas

toolTEST(airpas);
%%
% What is the optimal Box-Cox transformation?
% It may be seen both by 'Tests' -> 'Box Cox Transformation'
% or by 'Tests' -> 'S.D.-Mean and MEDA-Median Plots'
% or by running the vboxcox function
y= vboxcox(airpas);

y= log(airpas);
%%
% Why not using toolTEST in a sophisticated way?
% Check the 'Series' menu
dy= vdif([y y y y], [0 0; 1 0; 0 1; 1 1], [1 12]);

toolTEST(dy, 'names', 'z (1-B)z (1-B12)z (1-B)(1-B12)z');
%%
% toolTEST may be used to identify an ARIMA model
%    'Tests' -> 'Univariate ACF and PACF'
toolTEST(vdif(y, [1 1], [1 12]));
%%
% Estimation by Exact Maximum Likelihood
% Last year of data is preserved for forecasting purposes
% Check the residuals
model= '(1+Ma1*B)(1+Ma12*B12)/(1-B)(1-B12)';

m1 = modelTF(y(1:132), [], model, 12, 'eml');

toolTEST(m1.e);
%%
% Forecast comparisons. In this way ...
toolFORECAST(airpas, exp(m1.py), exp([m1.py-2*m1.stdpy m1.py+2*m1.stdpy]));
%%
% ... in this way ...
toolFORECAST(airpas(133:144), exp(m1.py), exp([m1.py-2*m1.stdpy m1.py+2*m1.stdpy]));
%%
% ... or even in this way (in logs)
PY= [adjust(y(1 : 132), m1.e); m1.py];

toolFORECAST(y, PY, [m1.py-2*m1.stdpy m1.py+2*m1.stdpy], 132);
