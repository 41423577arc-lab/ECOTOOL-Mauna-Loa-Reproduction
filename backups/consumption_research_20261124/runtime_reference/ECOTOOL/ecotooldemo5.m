%% ECOTOOL Demo #5: Nile data
% The data are annual flow volume measures at Aswan from 1871 to 1970.
% The first Aswan dam was finsihed in 1902 (observation 32)
%
% Let's load and plot the data
load nile

toolTEST(nile);
%%
% Would a simple RW + noise model be good enough?
m1 = modelUC(nile/100, [], 'RW', [], 'eml');

toolTEST([nile/100 m1.comp]);

%%
% Could we test for jumps?
m2 = modelUC(nile/100, [], 'RW', [], 'eml', 3.5);

toolTEST([nile/100 m2.comp]);
%%
% Are the residuals Gaussian white noise?
toolTEST(m2.e);
