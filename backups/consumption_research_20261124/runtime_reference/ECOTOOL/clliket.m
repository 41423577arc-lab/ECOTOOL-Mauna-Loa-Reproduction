function [covpar, inn]= clliket(p, z, u, model_struc, x0, P0, Miss, timev, charsys, Inter, PInter, call_varargin, varargin)
% CLLIK    Computes the Covariance matrix of ML estimates in vector p
%          only for models without system matrices defined as strings.
%          System outputs without NaNs

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[Nz, N]= size(z);
Nu=size(u, 1); 
if Nu==0, D_u= 0; Gam_u= 0; end

% Covariance matrix initial values
npar= length(p);
covpar= zeros(npar);

% Increments to compute numerical derivatives
inc= 0.01*ones(npar, 1);
iii= find(abs(p)<=0.1 & abs(p)>0);
inc(iii)= 10.^(-ceil(-log10(abs(p(iii)))+1));
B0= [p p(:, ones(1, npar))+diag(inc)];

Ns= size(x0, 1);
x= zeros(Ns, 1, npar+1);
P= zeros(Ns, Ns, npar+1);
IFTdF= zeros(Nz, Nz, npar);
dv= zeros(Nz, npar);

for i= 1:npar+1
   p= B0(:, i);
   eval(model_struc);
   if i==1
      lR= size(Rt, 1);
      CRC= zeros(Nz, Nz, npar+1);
      ESC= zeros(Ns, Nz, npar+1);
      EQE= zeros(Ns, Ns, npar+1);
      Phi= zeros(Ns, Ns, npar+1);
      if Nu, Gam= zeros(Ns, Nu, npar+1); D= zeros(Nz, Nu, npar+1); end
      H= zeros(Nz, Ns, npar+1);
   end
   Phi(:, :, i)= Phit;
   Gam(:, :, i)= Gamt;
   H(:, :, i)= Ht;
   D(:, :, i)= Dt;
   CRC(:, :, i)= Ct*Rt*Ct';
   EQE(:, :, i)= Et*Qt*Et';
   ESC(:, :, i)= Et*St*Ct';
   [P0i, iP0, x0i, sta]= kfiniet(Phit, EQE(:, :, i), x0, P0, u);
   x(:, :, i)= x0i;
   P(:, :, i)= P0i;
end

inn= nan*ones(size(z));

kint= 1; Inter= [Inter N+10];

for t=1:N
  if (t+1== Inter(kint)), if kint>1, kint= kint+1; end, end
  for i=1:npar+1
     if Nu, D_u= D(:, :, i)*u(:, t); Gam_u= Gam(:, :, i)*u(:, t); end
     PHt= P(:, :, i)*H(:, :, i)';
     F= H(:, :, i)*PHt + CRC(:, :, i);
     iFt= inv(F);
     K= (Phi(:, :, i)*PHt + ESC(:, :, i))*iFt;
     v= z(:, t)-H(:, :, i)*x(:, :, i)-D_u;
     inn(:, t)= v;
     if i==1, inn(:, t)= v; end
     Phi1= Phi(:, :, i)-K*H(:, :, i);
     if t<N
       x(:, :, i)= Phi(:, :, i)*x(:, :, i)+Gam_u+K*v;
       KESC= K*ESC(:, :, i)';
       if (t+1== Inter(kint))
          P(:, :, i)= Phi1*P(:, :, i)*Phi1'+EQE(:, :, i)+K*CRC(:, :, i)*K'-KESC-KESC'+diag(PInter(:, kint));
       else
          P(:, :, i)= Phi1*P(:, :, i)*Phi1'+EQE(:, :, i)+K*CRC(:, :, i)*K'-KESC-KESC';
       end
     end
     if i==1
        IFT= iFt; V= v; Ft= F;                % Storing F(t)^-1, v(t) and F(t)
     else
        IFTdF(:, :, i-1)= IFT*(F-Ft)/inc(i-1);
        dv(:, i-1)= (v-V)/inc(i-1);
        for j=1:i-1
           k= i-1;
           covpar(k, j)= covpar(k, j)+0.5*trace(IFTdF(:, :, k)*IFTdF(:, :, j))+dv(:, k)'*IFT*dv(:, j);
        end
     end  
  end
end
covpar= covpar+tril(covpar, -1)';
covpar= pinv(covpar);
