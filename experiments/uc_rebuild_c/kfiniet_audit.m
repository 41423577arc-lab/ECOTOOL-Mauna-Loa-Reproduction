function [P1, iP1, x1, sta]= kfiniet(Phi, Q, x0, P0, u)
% [P1, iP1, x1, sta]= kfini(Phi, Q, withu)
%
% Initial conditions for Exact Maximum Likelihood estimation
% P1: Conditional covariance matrix of initial state vector
% iP1: Inverse of P1
% x1: Initial state vector
% sta: Stationary(1), non-stationary(0) or partially stationary(2) system
%
% Phi: Phi matrix of transition equation
% Q:   E*Q*E'
% W:   W
% w:   w
% x0: Initial value of states.
%     If empty x0= 0 and P0= kI
%     If string it uses EML:
%        'noinputs' or shorter:      system without inputs
%        'stochastic' or shorter:    system with stochastic inputs
%        'deterministic' or shorter: system with deterministic inputs

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% if ~ischar(x0)
    Ns= size(Phi, 1);
    if isempty(x0), x0= zeros(Ns, 1); end
    lx0= size(x0, 1);
    if lx0< Ns
        x0= [x0; repmat(x0(end), Ns-lx0, 1)];
    elseif lx0> Ns
        x0= x0(1 : Ns);
    end

    if isempty(P0), P0= eye(Ns)*1e5; end
    lP0= size(P0, 1);
    if lP0< Ns
        P0= blkdiag(P0, diag(repmat(P0(end, end), Ns-lP0, 1)));
    elseif lP0> Ns
        P0= P0(1 : Ns, 1 : Ns);
    end
    x1= x0; P1= P0; iP1= []; sta= 0;
    return
% end
%noinp= 'noinputs'; stoch= 'stochastic'; deter= 'deterministic';
% De momento lo único que hace es asignar x0=0 y P0= kI para raíces de
% Phi no estacionarias y solución de Lyapunov para estacionarias.
% Esto se tiene que mejorar en el futuro, además de mejorar la solución
% de la ecuación de Lyapunov, que es muy lenta

Ns= size(Phi, 1);
x1= zeros(Ns, 1);
P1= zeros(Ns);

L= eig(Phi);
LM1= find(L>=1);
Lm1= find(L<1);
P1(LM1, LM1)= 1e5*eye(size(LM1, 1));
if ~isempty(Lm1)
   P1(Lm1, Lm1)= lyapunov(Phi(Lm1, Lm1), Q(Lm1, Lm1));  % esto con función E4
end
iP1= []; sta= 0;

return

% Solución de lyapunov más lenta (Harvey (1989), pág. 121)
q= Q(Lm1, Lm1); phi= Phi(Lm1, Lm1);
Nms= size(Lm1, 1);
P1(Lm1, Lm1)= reshape(pinv(eye(Nms*Nms)-kron(phi, phi))*q(:), Nms, Nms);





return







if all(L<1), sta= 1;         % Stationary system
  elseif all(L>=1), sta= 0;  % Non stationary system
  else sta= 2;               % Parcially stationary system
end

if sta== 1                   % Stationary system without u variables
   [P1, nonstat] = lyapunov(Phi, Q);
   iP1= [];
elseif sta== 0               % Non-stationary system without u variables              
   P1= zeros(Ns);
   iP1= zeros(Ns);
else                         % Partially stationary system without u variables              
%   [P Q U1 U2 R S]  = bkjordan(Phi);
%   M = lyapunov(Q, S*EQEt*S');
%   M = lyapunov(Q, S*EQEt*S');
%   P0 = U2*M*U2' + k*U1*U1';
%      U = pinv(M, tolM);
%      iP0 = S'*U*S;
   [P, QQ, U1, U2, R, S]  = bkjordan(Phi,1e-10);
   M = lyapunov(QQ, S*Q*S');
   P1 = U2*M*U2' + 1e6*U1*U1';
   U = pinv(M);
   iP1 = S'*U*S;
%   P1= zeros(Ns);
end


return


if withu   % System with inputs
   if sta== 1                 % Stationary system
      x1= pinv(W)*w;
      [P1, nonstat] = lyapunov(Phi, Q);
      iP1= pinv(P1);
   elseif sta== 0             % Non-stationary system       ?????????????????
      iP1= P1;
      P1= eye(Ns);
   else                       % Parcially stationary system
%      x1= ; %???????????????????????????????????????????????????????
      
   end
else       % System without inputs
   if sta== 1                 % Stationary system
      [P1, nonstat] = lyapunov(Phi, Q);
      iP1= pinv(P1);
   elseif sta== 0             % Non-stationary system       ?????????????????
      iP1= P1;
      P1= eye(Ns);
      else                    % Parcially stationary system
   end
end
