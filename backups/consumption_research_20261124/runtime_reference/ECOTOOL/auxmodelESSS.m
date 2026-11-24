function [x0, P0, Phi, Gam, E, H, D, C, Q, R, S, Phider, Hder, Inter, PInter]= ...
         auxmodelESSS(p, model, s, Nu, x01, Phi, Gam, E, H, C, R, S, npar)
      
% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

nalfas= npar-Nu;
PP= p;
PP= 10.^p(1 : nalfas);
if strcmp(model, 'NN')
    E(1)= PP(2);
elseif strcmp(model, 'AN')
    E(1 : 2)= [PP(2); PP(3)];
elseif strcmp(model, 'DN')
    Phi= [1 PP(4) 0; 0 PP(4) 0;1 PP(4) 0];
    E(1 : 2)= [PP(2); PP(3)];
elseif strcmp(model, 'NA')
    E(1 : 2)= [PP(2); PP(3)];
elseif strcmp(model, 'AA')
    E(1 : 3)= [PP(2); PP(3); PP(4)];
elseif strcmp(model, 'DA')
    Phi([1 2 s+3], 2)= PP(4);
    E(1 : 3)= [PP(2); PP(3); PP(5)];
end    
p(1 : npar);

% Code defining matrix Phi
% Gam= [];
% if strcmp(model, 'NN')
%     Phi= [1 0; 1 0];
%     if Nu, Gam= zeros(2, Nu); end
%     E= [PP(2); 1];
%     H= [0 1];
% elseif strcmp(model, 'AN')
%     Phi= [1 1 0; 0 1 0;1 1 0];
%     if Nu, Gam= zeros(3, Nu); end
%     E= [PP(2); PP(3); 1];
%     H= [0 0 1];
% elseif strcmp(model, 'DN')
%     Phi= [1 PP(4) 0; 0 PP(4) 0;1 PP(4) 0];
%     if Nu, Gam= zeros(3, Nu); end
%     E= [PP(2); PP(3); 1];
%     H= [0 0 1];
% elseif strcmp(model, 'NA')
%     Phi= zeros(s+2);
%     Phi(1, 1)= 1; Phi(end, 1)= 1;
%     Phi(3 : s+2, 2 : s+1)= diag(ones(s, 1));
%     Phi(2, end-1)= 1;
%     if Nu, Gam= zeros(s+2, Nu); end
%     E= [PP(2); PP(3); PP(4); zeros(s-2); 1];
%     H= [zeros(1, s+1) 1];
% elseif strcmp(model, 'AA')
%     Phi= zeros(s+3);
%     Phi(1 : 2, 1 : 2)= [1 1;0 1]; Phi(end, 1 : 2)= 1;
%     Phi(4 : s+3, 3 : s+2)= diag(ones(s, 1));
%     Phi(3, end-1)= 1;
%     if Nu, Gam= zeros(s+3, Nu); end
%     E= [PP(2); PP(3); PP(4); zeros(s-1); 1];
%     H= [zeros(1, s+2) 1];
% elseif strcmp(model, 'DA')
%     Phi= zeros(s+3);
%     Phi(1 : 2, 1 : 2)= [1 1;0 1]; Phi(end, 1 : 2)= 1;
%     Phi(4 : s+3, 3 : s+2)= diag(ones(s, 1));
%     Phi(3, end-1)= 1;
%     Phi([1 2 s+3], 2)= PP(4);
%     if Nu, Gam= zeros(s+3, Nu); end
%     E= [PP(2); PP(3); PP(5); zeros(s-1); 1];
%     H= [zeros(1, s+2) 1];
% end    
% Code defining matrix D
D= [];
if Nu, D= p(nalfas+1 : nalfas+Nu)'; end

% Code defining matrix C
% C= 1;

% Code defining matrix Q
Q= PP(1); 

% Code defining matrix R
% R= 0;

% Code defining matrix S
% S= zeros(size(E, 2), size(R, 1));

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

