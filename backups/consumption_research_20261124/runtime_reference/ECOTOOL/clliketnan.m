function [covpar, inn]= clliketnan(p, z, u, model_struc, x0, P0, Miss, timev, charsys, Inter, PInter, call_varargin, varargin)
% CLLIKNAN    Computes the Covariance matrix of ML estimates in vector p
%             only for models without system matrices defined as strings.
%             System outputs with NaNs

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

eval(model_struc);

% Covariance matrix initial values
npar= length(p);
covpar= zeros(npar);

% Increments to compute numerical derivatives
inc= 0.01*ones(npar, 1);
iii= find(abs(p)<=0.1 & abs(p)>0);
inc(iii)= 10.^(-ceil(-log10(abs(p(iii)))+1));
B0= [p p(:, ones(1, npar))+diag(inc)];

MAT= ['Phi   ';'Gam   ';'E     ';'H     ';'D     '; ...
      'C     ';'Q     ';'R     ';'S     ';'Phider';'Hder  '];
lMAT= [3 3 1 1 1 1 1 1 1 6 4];

R= Rt(:,:,1);
Q= Qt(:,:,1);

Ns= size(x0, 1);
x= zeros(Ns, 1, npar+1);
P= zeros(Ns, Ns, npar+1);
IFTdF= zeros(Nz, Nz, npar);
dv= zeros(Nz, npar);

nn= length(timev);
if (nn==0 | (nn>0 &((~any(timev==1) & ~any(timev==3) & ~any(timev==7)))))
      [P0, iP0, x0, sta]= kfiniet(Phit, Et*Qt*Et', x0, P0, u);
end
x= x0(:, :, ones(1, npar+1));
P= P0(:, :, ones(1, npar+1));
inn= nan*ones(size(z)); v= inn(:, 1);

kint= 1; Inter= [Inter N+10];

for t=1:N
  tobs= find(~Miss(:, t));
  if (t+1== Inter(kint)), if kint>1, kint= kint+1; end, end
  for i=1:npar+1
     p= B0(:, i);
     eval(model_struc);
     Inter= [Inter N+10];
     
     R= Rt(:,:,1);
     Q= Qt(:,:,1);
     S= St(:,:,1);
     C= Ct(:,:,1);
     D= Dt(:,:,1);
     H= Ht(:,:,1);
     E= Et(:,:,1);
     Gam= Gamt(:,:,1);
     Phi= Phit(:,:,1);
     
     if nn>0
        for ii=1:nn
           eval([MAT(timev(ii), :) '=' MAT(timev(ii), 1:lMAT(timev(ii))) 't(:, :, t);']);
        end
     end
     if Nu, Gam_u= Gam*u(:, t); end
     if (isempty(tobs) & t<N)
       x(:, :, i)= Phi*x(:, :, i)+Gam_u;
       if (t+1== Inter(kint))
          P(:, :, i)= Phi*P(:, :, i)*Phi'+E*Q*E'+diag(PInter(:, kint));
       else
          P(:, :, i)= Phi*P(:, :, i)*Phi'+E*Q*E';
       end
     else
        Htobs= H(tobs, :);
        PHtobs= P(:, :, i)*Htobs';
        CRC= C(tobs, :)*R*C(tobs, :)';
        F= Htobs*PHtobs + CRC;
        iFt= inv(F);
        ESC= E*S*C(tobs, :)';
        K= (Phi*PHtobs + ESC)*iFt;
        if Nu, D_u= D(tobs, :)*u(:, t); end
        v(tobs)= z(tobs, t)-Htobs*x(:, :, i)-D_u;
        inn(tobs, t)= v(tobs);
        Phi1= Phi-K*Htobs;
        if t<N
          x(:, :, i)= Phi*x(:, :, i)+Gam_u+K*v(tobs);
          KESC= K*ESC';
          if (t+1== Inter(kint))
             P(:, :, i)= Phi1*P(:, :, i)*Phi1'+E*Q*E'+K*CRC*K'-KESC-KESC'+diag(PInter(:, kint));
          else
             P(:, :, i)= Phi1*P(:, :, i)*Phi1'+E*Q*E'+K*CRC*K'-KESC-KESC';
          end
        end
     end
     if ~isempty(tobs)
        if i==1
           IFT= iFt; V= v(tobs); Ft= F;                % Storing F(t)^-1, v(t) and F(t)
        else
%           IFTdF(:, :, i-1)= IFT*(F-Ft)/inc(i-1);
%           if ~isempty(tobs), dv(:, i-1)= (v(:)-V)/inc(i-1); end
           IFTdF(tobs, tobs, i-1)= IFT*(F-Ft)/inc(i-1);   %%%% CUIDADO CON ESTE CAMBIO
           if ~isempty(tobs), dv(tobs, i-1)= (v(tobs)-V)/inc(i-1); end   %%% CUIDADO CON ESTE CAMBIO
           for j=1:i-1
              k= i-1;
%              covpar(k, j)= covpar(k, j)+0.5*trace(IFTdF(:, :, k)*IFTdF(:, :, j))+dv(:, k)'*IFT*dv(:, j);
              covpar(k, j)= covpar(k, j)+0.5*trace(IFTdF(tobs, tobs, k)*IFTdF(tobs, tobs, j))+dv(tobs, k)'*IFT*dv(tobs, j);
           end
        end  
     end
  end    % for i=1:npar+1
end
covpar= covpar+tril(covpar, -1)';
covpar= pinv(covpar);
