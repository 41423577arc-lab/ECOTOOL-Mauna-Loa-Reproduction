%% ECOTOOL Demo #8: SCC example
% The SCC data is composed of three quarterly time series, from the third quarter
% of 1952 up to the fourth quarter of 1967:
%     (1) Finantial Times ordinary share index
%     (2) U.K. car production index
%     (3) Finantial Times commodity price index
%
% Taken from chapter 14 of D. Peña, G.C. Tiao and R.S. Tsay, (2001),
% 'A course in Time Series Analysis', Wiley: US.

%%
% Load and plot data
% Check the multivariate ACF and PACF functions in 'Tests' menu
% But also the problems with unit roots
load scc

toolTEST(scc, 'names', 'FTordinary UKcar FTcommodity')
%%
% VAR(1) in first differences with constants
% Here Granger causality test may be checked 
toolTEST(vdif(scc), 'names', 'FTordinary UKcar FTcommodity');

m1= modelVARX(scc, ones(62, 1), {1, 0}, [], 1, 1);

figure
toolTEST(m1.e);
%%
% Based on the previous estimation, a constrained model is sensible
% Is there a simultaneous relation? It seems that only trough the perturbations
model= [1 0 0 nan   0 0; ...
        0 1 0 nan nan 0; ...
        0 0 1 nan nan nan];
    
m2 = modelVARX(scc, ones(62, 1), {model, [nan nan nan]'}, [], 1, 1);

toolTEST(m2.e);
%%
% The impulse response function may be estimated
ARp= [m2.ARpoly-2*m2.seARpoly; m2.ARpoly+2*m2.seARpoly];
varstep(m2.ARpoly, 10, 0, ARp, 1000);

zplane(0, vRoots(m2.ARpoly));
