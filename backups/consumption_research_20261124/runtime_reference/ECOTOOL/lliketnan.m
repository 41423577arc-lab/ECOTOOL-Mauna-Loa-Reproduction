function out= lliketnan(p, z, u, model_struc, x, P, Miss, timev, charsys, Inter, PInter, HANDLES, call_varargin, varargin)
% LLIKNAN    Evaluation of the Log-Likelihood function of time varying SS models    
%            System outputs with NaN's and numerical system matrices

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

out= 0;

nn= length(timev);
if (nn==0 | (nn>0 &((~any(timev==1) & ~any(timev==3) & ~any(timev==7)))))
      [P, iP0, x, sta]= kfiniet(Phit, Et*Qt*Et', x, P, u);
end
Ns= size(x, 1);

eqe= 0;
if nn>0, if (~any(timev== 3) & ~any(timev==7)), EQE= Et*Qt*Et'; eqe= 1; end, end
%if nn>0, if (~timev(3) & ~timev(7)), EQE= Et*Qt*Et'; eqe= 1; end, end

kint= 1; Inter= [Inter N+10];

for t=1:N
% Time varying system
   for ii=1:nn
      eval([MAT(timev(ii), :) '=' MAT(timev(ii), 1:lMAT(timev(ii))) 't(:, :, t);']);
   end
   
   if Nu, Gam_u= Gam*u(:, t); end
   
   tobs= find(~Miss(:, t));
   if (isempty(tobs) & t<N)
     x= Phi*x+Gam_u;
     if (t+1== Inter(kint))
        P= Phi*P*Phi'+E*Q*E'+diag(PInter(:, kint));
        kint= kint+1;
     else
        P= Phi*P*Phi'+E*Q*E';
     end
   else
     Htobs= H(tobs, :);
     PHtobs= P*Htobs';
     CRC= C(tobs, :)*R*C(tobs, :)';
     F= Htobs*PHtobs + CRC;
     iFt= inv(F);
     ESC= E*S*C(tobs, :)';
     K= (Phi*PHtobs + ESC)*iFt;
     if Nu, D_u= D(tobs, :)*u(:, t); end
     v= z(tobs, t)-Htobs*x-D_u;
     if t>Ns
        out= out+log(det(F))+v'*iFt*v;
         if det(F)<0, disp([det(F) t]), end
     end
     Phi1= Phi-K*Htobs;
     if t<N
       x= Phi*x+Gam_u+K*v;
       KESC= K*ESC';
       if (t+1== Inter(kint))
          P= Phi1*P*Phi1'+K*CRC*K'-KESC-KESC'+diag(PInter(:, kint));
          kint= kint+1;
       else
          P= Phi1*P*Phi1'+K*CRC*K'-KESC-KESC';
       end
       if eqe,  P= P + EQE;
       else, P= P + E*Q*E';
       end
     end
   end
end

out= 0.5*((N/(N-Ns))*out+Nz*N*log(2*pi));

if ~isempty(HANDLES)
   set(HANDLES(2), 'userdata', p, 'string', num2str(out));
   drawnow   
end
