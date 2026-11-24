%% ECOTOOL Demo #4: Unemployment in Spain
% On 5th May 2010, after a bad unemployment data for the first quarter of
% the year according to the Spanish Economically Active Population Survey
% (EAPS - EPA in Spanish), the Spanish Government said that registered unemployment
% had reduced by 24,188 people during April.
%
% Just the following day, several newspapers announced that such information
% was misleading because, once several especial effects were removed from 
% the data (like seasonallity, calendar, good weather and others),
% unemployment rised up by 62,769 people.
%
% Whose estimations were correct?

%%
% Let's load the Official Spanish unemployment data in 06/05/2010 in thousands
load unemployment

toolTEST(unem, 'names', 'Unemployment Adjusted');

disp('Official Statistics:');

printwf(unem(end, :)-unem(end-1, :), 0, 'Unemployed Adjusted');

y= unem(:, 1);
%%
% We may try a raw estimation of the seasonal adjusted series with modelUC:
% model may be of several types
model= 'SRW12';   % Damped trend
model= 'IRW12';   % Smooth trend (Integrated Random Walk)
model= 'LLT12';   % Local Linear trend

m1 = modelUC(log(y), 'model', model, 'method', 'eml', 'outlier', 4);

toolTEST([log(y) m1.comp], 'names', 'Unemployment Trend Seasonal Irregular');

toolTEST(m1.e);

ys1= exp(m1.comp(:, 1) + m1.comp(:, 3));

toolTEST([unem(:, 2) ys1], 'names', 'Official Estimated');
%%
% A refined estimation with calendar effects:
u= [easter([2000 1], 124) trading([2000 1], 124) leapy([2000 1], 124)];

model1= {'LLT12', 'EASTER', 'TRADING', 'LEAP'};

m2 = modelUC(log(y), u, model1, [], 'eml', 3.5);

toolTEST([m1.e m2.e]);

ys2= exp(m2.comp(:, 1) + m2.comp(:, 3));

toolTEST([unem(:, 2) ys1 ys2], 'names', 'Official Estimated1 EStimated2');
%%
% This is the unemployment estimation according to several measures
%    and the seasonal shape (check the 'Transpose Boxplot' in the 'Tests' menu)
table= [unem(end, 2)-unem(end-1, 2) ys1(end)-ys1(end-1) ys2(end)-ys2(end-1)];

printwf(table, 0, 'Official 1 2');

toolTEST(m1.comp(:, 2));
