function [x0, P0, Phi, Gam, E, H, D, C, Q, R, S, Phider, Hder, Inter, PInter, Label]= ...
              auxmodelUC(p, Phis, E, H, C, S, trend, x01, landa)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin== 9
    p= [log10(landa); 0];
end

% Code defining matrix Gam
Gam= [];

% Code defining matrix D
D= [];

ind= 1;
% Code defining matrix Q
if size(Phis, 1)== 2   % No seasonal
    if strcmp(trend, 'RW')
        Q= [10.^p(ind) 0; 0 0];
        ind= ind+1; Label= 'Level Irregular';
    elseif strcmp(trend, 'IR')
        Q= [0 0; 0 10.^p(ind)];
        ind= ind+1; Label= 'Slope Irregular';
    else
        Q= [10.^p(ind) 0; 0 10.^p(ind+1)];
        ind= ind+2; Label= 'Level Slope Irregular';
    end
else
    if strcmp(trend, 'RW')
        Q= [10.^p(ind) 0 0; 0 0 0; 0 0 10.^p(ind+1)];
        ind= ind+2; Label= 'Level Seasonal Irregular';
    elseif strcmp(trend, 'IR')
        Q= [0 0 0; 0 10.^p(ind) 0; 0 0 10.^p(ind+1)];
        ind= ind+2; Label= 'Slope Seasonal Irregular';
    else
        Q= [10.^p(ind) 0 0; 0 10.^p(ind+1) 0; 0 0 10.^p(ind+2)];
        ind= ind+3; Label= 'Level Slope Seasonal Irregular';
    end
end

if nargin== 9, Label= 'Lambda'; end

% Code defining matrix R
R= 10.^p(ind);

% Code defining matrix Phi
Phi= Phis;
if strcmp(trend, 'SR')
    Phi(1, 1)= constrain(p(ind+1), [0 1]);
    Label= [Label ' Smooth'];
end

% Initial conditions for Kalman Filtering
x0= [x01; 0];
P0= [];

% Code defining matrix Phider
Phider= [];

% Code defining matrix Hder
Hder= [];

% Code defining Variance intervention samples (row vector)
Inter= [];

% Code defining Variance intervention size (N_states x N_interventions)
PInter= [];

