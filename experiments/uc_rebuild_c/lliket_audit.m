function out= lliket(p, z, u, model_struc, x, P, Miss, timev, charsys, Inter, PInter, HANDLES, call_varargin, varargin)
% LLIK    Evaluation of the Log-Likelihood function of time invariate SS models    
%         System outputs without NaN's and numerical system matrices

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
Nu= size(u, 1); 
if Nu==0, D_u= 0; Gam_u= 0; end

eval(model_struc);

out= 0;

ESC= Et*St*Ct';
EQE= Et*Qt*Et';
CRC= Ct*Rt*Ct';
[P, iP0, x, sta]= kfiniet(Phit, EQE, x, P, u);
Ns= size(x, 1);
kint= 1; Inter= [Inter N+10];

for t=1:N
   PH= P*Ht';
   F= Ht*PH+CRC;
   iFt= inv(F);
   K= (Phit*PH + ESC)*iFt;
   if Nu, D_u= Dt*u(:, t); Gam_u= Gamt*u(:, t); end
   v= z(:, t)-Ht*x-D_u;
   if t> Ns
      out= out+log(det(F))+v'*iFt*v;
   end
   Phi1= Phit-K*Ht;
   if t<N
     x= Phit*x+Gam_u+K*v;
     KESC= K*ESC';
     if (t+1== Inter(kint))
        P= Phi1*P*Phi1'+EQE+K*CRC*K'-KESC-KESC'+diag(PInter(:, kint));
        kint= kint+1;
     else
        P= Phi1*P*Phi1'+EQE+K*CRC*K'-KESC-KESC';
     end
   end
end

out= 0.5*((N/(N-Ns))*out+Nz*N*log(2*pi));

if ~isempty(HANDLES)
   set(HANDLES(2), 'userdata', p, 'string', num2str(out));
   drawnow   
end


