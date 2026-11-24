function [inn, zh, xt1, F, Pt1]= fisET(z, u, model_struc, p, SMOOTH, varargin)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


% Starting 'global' variables
SSpaceiniET;

% Checking inputs
[Nz, N]= size(z);         % Vector output dimensions
if Nz>N, z= z'; [Nz, N]= size(z); end

[Nu, NNN]= size(u);         % Vector input dimensions
if Nu>NNN, u= u'; [Nu, NNN]= size(u); end
if Nu==0, D_u= 0; Gam_u= 0; end
if (NNN> 0 & N~= NNN), errorSSpace('Output and input data of different sizes', 'fis'); end

if nargin< 5, SMOOTH= 1; end
if isempty(SMOOTH), SMOOTH= 1; end

if nargin< 3 | isempty(model_struc), errorSSpace('No model defined for estimation!!!', 'fis'); end

% Missing values
Miss= isnan(z);

funname= model_struc;
% % % % Evaluating the system matrices
if isempty(varargin)
   [Ns, charsys, timev, Inter, PInter, call_varargin]= checkmodelet([N Nz Nu], model_struc);
   npar= findnpar(model_struc);
   model_struc= ['[x0, P0, Phit, Gamt, Et, Ht, Dt, Ct, Qt, Rt, St, Phidert, Hdert, Inter, PInter]=' model_struc '(p);'];
else
   [Ns, charsys, timev, Inter, PInter, call_varargin]= checkmodelet([N Nz Nu], model_struc, varargin{:});
   npar= findnparet(model_struc, varargin{:});
   model_struc= ['[x0, P0, Phit, Gamt, Et, Ht, Dt, Ct, Qt, Rt, St, Phidert, Hdert, Inter, PInter]=' model_struc '(p, varargin{:});'];
end   
eval(model_struc);
eval(call_varargin);

% Inizialising the variance intervention variables
kint= 1; Inter= [Inter N+10];

% Adjusting the number of parameters
lp= length(p);
if npar~=lp
   errorSSpace(['Number of parameters supplied (' int2str(lp) ') do not match with ' funname ' file (' int2str(npar) ')'], 'fisET');
end
p= p(:);

% Checking for time varying or non-linear systems
nchar= sum(charsys);
findchar= find(charsys);

% Setting initial conditions for filtering
if isempty(x0), x0= zeros(Ns, 1); end
if ischar(x0) & isempty(x0), x0='ppp'; end

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

if ((sum(charsys([1 3 7])) | sum(timev)) & ischar(x0))   % Time variant or non-linear system
   errorSSpace('x0 input inconsistent with time varying or non linear systems.', 'fis')
%else, x0= zeros(Ns, 1); P0= eye(Ns)*1e5;    % Time varying system
end
if ischar(x0)
   x0= lower(x0); lx0= length(x0);
   noinp= 'noinputs'; stoch= 'stochastic'; deter= 'deterministic';
   if strcmp(x0, noinp(1:lx0)) & isempty(u)   %~all(u==0)
      errorSSpace('x0 implies no inputs, but there are inptus in the system.', 'fis');
   end
   if strcmp(x0, stoch(1:lx0)) & isempty(u)    %all(u==0)
      errorSSpace(['x0 implies ' stoch ' inputs, but there are not any in the system.'], 'fis');
   end
   if strcmp(x0, deter(1:lx0)) & isempty(u)    % all(u==0)
      errorSSpace(['x0 implies ' deter ' inputs, but there are not any in the system.'], 'fis');
   end
   if ~strcmp(x0, deter(1:lx0)) & ~strcmp(x0, stoch(1:lx0)) & ~strcmp(x0, noinp(1:lx0))
      errorSSpace('Unknown x0 option.', 'fis');
   end
end

nn= length(timev);
if (nn==0 | (nn>0 &((~any(timev==1) & ~any(timev==3) & ~any(timev==7)))))
   if (sum(charsys([1 3 7]))==0)
      [P0, iP0, x0, sta]= kfiniet(Phit, Et*Qt*Et', x0, P0, u);
   end
end
Ns= size(x0, 1);

% Setting initial values of matrices and vectors
MAT= ['Phi   ';'Gam   ';'E     ';'H     ';'D     '; ...
      'C     ';'Q     ';'R     ';'S     ';'Phider';'Hder  '];
lMAT= [3 3 1 1 1 1 1 1 1 6 4];

S= St(:,:,1);
R= Rt(:,:,1);
Q= Qt(:,:,1);
C= Ct(:,:,1);
D= Dt(:,:,1);
H= Ht(:,:,1);
E= Et(:,:,1);
Gam= Gamt(:,:,1);
Phi= Phit(:,:,1);
Phider= Phidert(:,:,1);
Hder= Hdert(:,:,1);

if ischar(Phit), Phic= Phit; end
if ischar(Gamt), Gamc= Gamt; end
if ischar(Et), Ec= Et; end
if ischar(Ht), Hc= Ht; end
if ischar(Dt), Dc= Dt; end
if ischar(Ct), Cc= Ct; end
if ischar(Qt), Qc= Qt; end
if ischar(Rt), Rc= Rt; end
if ischar(St), Sc= St; end
if ischar(Phidert), Phiderc= Phidert; end
if ischar(Hdert), Hderc= Hdert; end

inn= nan*ones(Nz, N);
x= zeros(Ns, 1);                   
xt1= zeros(Ns, N);                 % x(t|t-1)
Pt1= zeros(Ns, Ns, N);             % P(t|t-1)
F= nan*ones(Nz, Nz, N);
zh= nan*ones(size(z));
Phi1= zeros(Ns, Ns, N);
iB= zeros(Nz, Nz, N);

x= x0;
P= P0;
xt1(:, 1)= x;
Pt1(:, :, 1)= P;

if sum(charsys)    % String system matrices (time varying or non-linear system)
   
   
   
   
   

for t=1:N           % Kalman Filter
% Checking time invariance   
   tobs= find(~Miss(:, t));
   if nn>0
      for ii=1:nn
         eval([MAT(timev(ii), :) '=' MAT(timev(ii), 1:lMAT(timev(ii))) 't(:, :, t);']);
      end
   end
% String matrices   
   for ii= 1:nchar
      iii= findchar(ii);
      eval(eval([MAT(iii, 1:lMAT(iii)) 'c']));
      if iii== 1
         VARi= findname('Phi_x', Phic);      % Modelo no lineal
         if isempty(VARi), Phi_x= Phi*x; end
      elseif iii== 2
         VARi= findname('Gam_u', Gamc);      % Modelo no lineal
         if isempty(VARi), Gam_u= Gam*u(:, t); end
      elseif iii== 4
         VARi= findname('H_x', Hc);          % Modelo no lineal
         if isempty(VARi), Htobs= H(tobs, :); H_x= Htobs*x; end
      elseif iii== 5
         VARi= findname('D_u', Dc);      % Modelo no lineal
         if isempty(VARi), D_u= D(tobs, :)*u(:, t); end
      end
   end
   Htobs= H(tobs, :);
   if ~any(findchar== 1), Phi_x= Phi*x; end
   if ~any(findchar== 4), H_x= Htobs*x; end
   
   if (Nu & ~charsys(2)), Gam_u= Gam*u(:, t); end
   if (Nu & ~charsys(5)), D_u= D(tobs, :)*u(:, t); end
%    if (isempty(tobs) & t<N)
%       x= Phi_x+Gam_u;
%       if (t+1== Inter(kint))
%          P= Phi*P*Phi'+E*Q*E'+diag(PInter(:, kint));
%          kint= kint+1;
%       else
%          P= Phi*P*Phi'+E*Q*E';
%       end
%       xt1(:, t+1)= x;
%       Pt1(:, :, t+1)= P;
%       F(:, :, t)= H*P*H'+C*R*C;
%       zhat= H_x+D_u;
%       zh(:, t)= zhat;
%    elseif ~isempty(tobs)
% %      PHt= P*H';
% %      CRC= C*R*C';
% %      ESC= E*S*C';
% %      F(:, :, t)= H*PHt+CRC;
% %      iB(tobs, tobs, t)= pinv(F(tobs, tobs, t));
% %      K= (Phi*PHt + ESC)*iB(:, :, t);
% %      if Nu, if ~charsys(5), D_u= D*u(:, t); end, end
% %      zhat(:, t)= H*x+D_u;
% %      inn(:, t)= z(:, t)-zhat(:, t);
% %      v= inn(:, t);
%  %     Phi1(:, :, t)= Phi-K*H;
%  %     if t<N
% %        if Nu, if ~charsys(2), Gam_u= Gam*u(:, t); end, end
% %        x= Phi*x+Gam_u+K(:, tobs)*inn(tobs, t);
% %        P= Phi1(:, :, t)*P*Phi1(:, :, t)'+E*Q*E'+K*CRC*K'-K*ESC'-ESC*K';
% %        xt1(:, t+1)= x;
% %        Pt1(:, :, t+1)= P;
% %      end
      PHtobs= P*Htobs';
      CRC= C(tobs, :)*R*C(tobs, :)';
      Ft= Htobs*PHtobs + CRC; iFt= pinv(Ft);
      F(tobs, tobs, t)= Ft;
      if any(Miss(:, t))
         F(:, :, t)= H*P*H'+C*R*C;
      end
      iB(tobs, tobs, t)= iFt;
      ESC= E*S*C(tobs, :)';
      K= (Phi*PHtobs + ESC)*iFt;
      zhat= H_x+D_u;
      zh(:, t)= zhat;
      inn(:, t)= z(:, t)-zhat;
      v= inn(:, t);
      Phi1(:, :, t)= Phi-K*Htobs;
      if t<N
        if isempty(tobs)
            x= Phi_x+Gam_u;
        else
            x= Phi_x+Gam_u+K(:, tobs)*v(tobs);
        end
        KESC= K*ESC';
        if (t+1== Inter(kint))
           P= Phi1(:, :, t)*P*Phi1(:, :, t)'+E*Q*E'+K*CRC*K'-KESC-KESC'+diag(PInter(:, kint));
           kint= kint+1;
        else
           P= Phi1(:, :, t)*P*Phi1(:, :, t)'+E*Q*E'+K*CRC*K'-KESC-KESC';
        end
        xt1(:, t+1)= x;
        Pt1(:, :, t+1)= P;
      end
%    end  
end
if isempty(tobs)
   F(:, :, t)= H*P*H'+C*R*C;
   zh(:, t)= H_x+D_u;
end




if SMOOTH

r= zeros(Ns, 1);
MR= zeros(Ns, Ns);
jj= [4 5 6 8];

for t=N:-1:1        % Smoothing
   tobs= find(~Miss(:, t));
% Checking time invariance   
   if nn>0
      for hh=1:4
         ii= jj(hh)
         eval([MAT(timev(ii), :) '=' MAT(timev(ii), 1:lMAT(timev(ii))) 't(:, :, t);']);
      end
   end
% String matrices   
   if charsys(4), eval(Hc); end
   if charsys(5)
      eval(Dc);
      VARi= findname('D_u', Dc);      % Modelo no lineal
      if isempty(VARi), D_u= D(tobs, :)*u(:, t); end
   end
   if charsys(6), eval(Cc); end
   if charsys(8), eval(Rc); end
   if charsys(11), eval(Hderc); end
   
   Htobs= H(tobs, :);
   HtiB= Htobs'*iB(tobs, tobs, t);
   r= HtiB*inn(tobs, t)+Phi1(:, :, t)'*r;
   MR= HtiB*Htobs+Phi1(:, :, t)'*MR*Phi1(:, :, t);
   xt1(:, t)= xt1(:, t)+Pt1(:, :, t)*r;
   Pt1(:, :, t)= Pt1(:, :, t)-Pt1(:, :, t)*MR*Pt1(:, :, t);
   if (Nu & ~charsys(5)), D_u= D*u(:, t); end
   zhat= H*xt1(:, t)+D_u;
   zh(:, t)= zhat;
   F(:, :, t)= H*Pt1(:, :, t)*H'+C*R*C';
end


end     % if SMOOTH








elseif (sum(sum(Miss)) | nn>0)              % Numerical system matrices or time varying
   
   
   
   
   
for t=1:N           % Kalman Filter
% Checking time invariance   
   if nn>0
      for ii=1:nn
         eval([MAT(timev(ii), :) '=' MAT(timev(ii), 1:lMAT(timev(ii))) 't(:, :, t);']);
      end
   end
% Updating   
   tobs= find(~Miss(:, t));
   Htobs= H(tobs, :);
   if Nu, Gam_u= Gam*u(:, t); end
%    if (isempty(tobs) & t<N)
%       x= Phi*x+Gam_u;
%       if (t+1== Inter(kint))
%          P= Phi*P*Phi'+E*Q*E'+diag(PInter(:, kint));
%          kint= kint+1;
%       else
%          P= Phi*P*Phi'+E*Q*E';
%       end
%       xt1(:, t+1)= x;
%       Pt1(:, :, t+1)= P;
%       F(:, :, t)= H*P*H'+C*R*C';
%       if Nu, D_u= D*u(:, t); end
%       zh(:, t)= H*x+D_u;
%    elseif ~isempty(tobs)
      PHtobs= P*Htobs';
      CRC= C(tobs, :)*R*C(tobs, :)';
      Ft= Htobs*PHtobs + CRC; iFt= pinv(Ft);
      F(tobs, tobs, t)= Ft;
      if any(Miss(:, t))
         F(:, :, t)= H*P*H'+C*R*C';
      end
      iB(tobs, tobs, t)= iFt;
      ESC= E*S*C(tobs, :)';
      K= (Phi*PHtobs + ESC)*iFt;
%       if Nu, D_u= D(tobs, :)*u(:, t); end
      if Nu, D_u= D*u(:, t); end
      zh(:, t)= H*x+D_u;
      inn(:, t)= z(:, t)-zh(:, t);
      v= inn(:, t);
      Phi1(:, :, t)= Phi-K*Htobs;
      if t<N
          if isempty(tobs)
              x= Phi*x+Gam_u;
          else
              x= Phi*x+Gam_u+K*v(tobs);
          end
%        x= Phi*x+Gam_u+K(:, tobs)*v(tobs);   !!!!!!!!!!!!!!CUIDADO
      
        KESC= K*ESC';
        if (t+1== Inter(kint))
           P= Phi1(:, :, t)*P*Phi1(:, :, t)'+E*Q*E'+K*CRC*K'-KESC-KESC'+diag(PInter(:, kint));
           kint= kint+1;
        else
           P= Phi1(:, :, t)*P*Phi1(:, :, t)'+E*Q*E'+K*CRC*K'-KESC-KESC';
        end
        xt1(:, t+1)= x;
        Pt1(:, :, t+1)= P;
      end
%    end  
   
   
   
   
%   PHt= P*H';
%   CRC= C*R*C';
%   ESC= E*S*C';
%   F(:, :, t)= H*PHt+CRC;
%   iB(tobs, tobs, t)= inv(F(tobs, tobs, t));
%   K= (Phi*PHt + ESC)*iB(:, :, t);
%   if Nu, D_u= D*u(:, t); end
%   zhat(:, t)= H*x+D_u;
%   inn(:, t)= z(:, t)-zhat(:, t);
%   Phi1(:, :, t)= Phi-K*H;
%  if t<N
%     if Nu, Gam_u= Gam*u(:, t); end
%     x= Phi*x+Gam_u+K(:, tobs)*inn(tobs, t);
%     P= Phi1(:, :, t)*P*Phi1(:, :, t)'+E*Q*E'+K*CRC*K'-K*ESC'-ESC*K';
%     xt1(:, t+1)= x;
%     Pt1(:, :, t+1)= P;
%  end
  
end
if isempty(tobs)
   F(:, :, t)= H*P*H'+C*R*C';
   zh(:, t)= H*x+D_u;
end

%   tobs= find(~Miss(:, t));
%   PHtobs= P*Ht(tobs, :)';
%   F= Ht(tobs, :)*PHtobs+Ct(tobs, :)*Rt*Ct(tobs, :)';
%   iB(tobs, tobs, t)= inv(F);
%   iFt= iB(:, :, t);
%   PHt= P*Ht';
%   PHtiFt= PHt*iFt;
%   K= Phit*PHtiFt;
%   v(:, t)= z(:, t)-Ht*x(:, t)-Dt*u(:, t);
%   x(:, t)= x(:, t)+PHtobs*iFt(tobs, tobs)*v(tobs, t);
%   P= P-PHtiFt*Ht*P;
%   Phi1(:, :, t)= Phit-K*Ht;
%   zhat(:, t)= Ht*x(:, t)+Dt*u(:, t);
% Forecasting
%  if t<N
%     x(:, t+1)= Phit*x(:,t)+Gamt*u(:, t);
%     P= Phit*P*Phit'+Et*Qt*Et';
%     xt1(:, t+1)= x(:, t+1);
%     Pt1(:, :, t+1)= P;
%  end

if SMOOTH

r= zeros(Ns, 1);
MR= zeros(Ns, Ns);

for t=N:-1:1        % Smoothing
% Checking time invariance   
   if ~isempty(timev)
      nn= length(timev);
      for ii=1:nn
         eval([MAT(timev(ii), :) '=' MAT(timev(ii), 1:lMAT(timev(ii))) 't(:, :, t);']);
      end
   end
   tobs= find(~Miss(:, t));
   Htobs= H(tobs, :);
   HtiB= Htobs'*iB(tobs, tobs, t);
   r= HtiB*inn(tobs, t)+Phi1(:, :, t)'*r;
   MR= HtiB*Htobs+Phi1(:, :, t)'*MR*Phi1(:, :, t);
   xt1(:, t)= xt1(:, t)+Pt1(:, :, t)*r;
   Pt1(:, :, t)= Pt1(:, :, t)-Pt1(:, :, t)*MR*Pt1(:, :, t);
   if Nu, D_u= D*u(:, t); end
   zh(:, t)= H*xt1(:, t)+D_u;
   F(:, :, t)= H*Pt1(:, :, t)*H'+C*R*C';
   
%   HtiB= H'*iB(:, :, t);
%   r= HtiB(:, tobs)*inn(tobs, t)+Phi1(:, :, t)'*r;
%   MR= HtiB*H+Phi1(:, :, t)'*MR*Phi1(:, :, t);
%   xt1(:, t)= xt1(:, t)+Pt1(:, :, t)*r;
%   Pt1(:, :, t)= Pt1(:, :, t)-Pt1(:, :, t)*MR*Pt1(:, :, t);
%   if Nu, D_u= D*u(:, t); end
%   zhat(:, t)= H*xt1(:, t)+D_u;
%   F(:, :, t)= H*Pt1(:, :, t)*H'+C*R*C';
end

end     % if SMOOTH




else               % Numerical system matrices and time invariant
   
   
   
   

CRC= Ct*Rt*Ct';
ESC= Et*St*Ct';
EQE= Et*Qt*Et';
for t=1:N           % Kalman Filter
   if Nu, Gam_u= Gam*u(:, t); D_u= D*u(:, t); end
   PHt= P*Ht';
   Ft= Ht*PHt + CRC; iFt= pinv(Ft);
   F(:, :, t)= Ft;
   iB(:, :, t)= iFt;
   K= (Phit*PHt + ESC)*iFt;
   zh(:, t)= H*x+D_u;
   inn(:, t)= z(:, t)-zh(:, t);
   v= inn(:, t);
   Phi1(:, :, t)= Phit-K*Ht;
   if t<N
     x= Phit*x+Gam_u+K*v;
     KESC= K*ESC';
     if (t+1== Inter(kint))
        P= Phi1(:, :, t)*P*Phi1(:, :, t)'+EQE+K*CRC*K'-KESC-KESC'+diag(PInter(:, kint));
        kint= kint+1;
     else
        P= Phi1(:, :, t)*P*Phi1(:, :, t)'+EQE+K*CRC*K'-KESC-KESC';
     end
     xt1(:, t+1)= x;
     Pt1(:, :, t+1)= P;
   end
end  


if SMOOTH

r= zeros(Ns, 1);
MR= zeros(Ns, Ns);

for t=N:-1:1        % Smoothing
   HtiB= Ht'*iB(:, :, t);
   r= HtiB*inn(:, t)+Phi1(:, :, t)'*r;
   MR= HtiB*Ht+Phi1(:, :, t)'*MR*Phi1(:, :, t);
   xt1(:, t)= xt1(:, t)+Pt1(:, :, t)*r;
   Pt1(:, :, t)= Pt1(:, :, t)-Pt1(:, :, t)*MR*Pt1(:, :, t);
   if Nu, D_u= D*u(:, t); end
   zh(:, t)= Ht*xt1(:, t)+D_u;
   F(:, :, t)= Ht*Pt1(:, :, t)*Ht'+CRC;
end

end     % if SMOOTH




end   % if sum(charsys)

%inn(:, 1:Ns)= nan*ones(Nz, Ns);
