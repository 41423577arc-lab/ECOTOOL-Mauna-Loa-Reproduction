function [Ns, charsys, timev, Inter, PInter, call_varargin]= checkmodelet(sizeszu, mfun, varargin)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

p= rand(200, 1);
if isempty(varargin)
   eval(['[x0, P0, Phi, Gam, E, H, D, C, Q, R, S, Phider, Hder, Inter, PInter]=' mfun '(p);']);
else
   eval(['[x0, P0, Phi, Gam, E, H, D, C, Q, R, S, Phider, Hder, Inter, PInter]=' mfun '(p, varargin{:});']);
end   

% Checking forbidden variable names in string system matrices
charsys= zeros(11, 1);
if ischar(Phi), charsys(1)= 1; end
if ischar(Gam), charsys(2)= 1; end
if ischar(E), charsys(3)= 1; end
if ischar(H), charsys(4)= 1; end
if ischar(D), charsys(5)= 1; end
if ischar(C), charsys(6)= 1; end
if ischar(Q), charsys(7)= 1; end
if ischar(R), charsys(8)= 1; end
if ischar(S), charsys(9)= 1; end
if ischar(Phider), charsys(10)= 1; end
if ischar(Hder), charsys(11)= 1; end
call_varargin= '';
findchar= find(charsys);
nchar= sum(charsys);

   
MAT= ['Phi   ';'Gam   ';'E     ';'H     ';'D     '; ...
      'C     ';'Q     ';'R     ';'S     ';'Phider';'Hder  '];
lMAT= [3 3 1 1 1 1 1 1 1 6 4];
if nchar
% Checking whether variable names used in the definition of string system matrices
%      are in the forbidden list of variable names (already used in functions
%      llik, cllik, lliks, clliks, fis, etc.)
% Forbidden variable names (already used) in functions llik, cllik, fis, etc.
forb= ['model_struc x0 P0 Miss charsys call_varargin varargin Nz N Nu ' ...
       'N3S N3R N3Q N3C N3D N3H N3E N3Gam N3 Phit St Rt Qt Ct Dt Ht Et ' ...
       'Gamt Phit MAT lMAT timev out P0 iP0 x0 sta P ii tobs Phtobs F ' ...
       'iFt ESC K Phi1 covpar inc iii B0 IFTdF dv ii4 IFT V Ft jj kk ' ...
       'N3Phider N3Hder Phic Gamc Ec Hc Dc Cc Qc Rc Sc Phiderc Hderc ' ...
       'nchar findchar VARi Phider Hder Xx smooth funname ntimev xt1 ' ...
       'Pt1 iB nn r MR HtiB inn Inter PInter kint HANDLES'];
[forbidden, lfor]= divstring(forb);      
for i=1:size(forbidden, 1)
   str1= forbidden(i, 1:lfor(i));
   for j=1:nchar
      sss= findname(str1, eval(MAT(findchar(j), :)));
      if ~isempty(sss)
         message=['Variable name ''' str1 ''' in the definition of string system matrix ''' MAT(findchar(j), 1:lMAT(findchar(j))) '''&' ...
                  'in function ''' mfun '.m'' not allowed&' ...
                  'Other variable names may be illegal as well.'];
         message= divstring(message, '&');
         errorSSpace(message, 'checkmodel');
      end
   end
end
% Include in forbvars variable names that may be used in string system
%      matrices without previous definition and should not be inputs to
%      the function model_struc
fid = fopen([mfun '.m'], 'r');
F = setstr(fread(fid)');
fclose(fid);
[forbvars, lfor]= divstring(['z u t x v zhat Phi Gam E H D C Q R S']);
i1= min(find(F==abs('(')))+1;
i2= min(find(F==abs(')')))-1;
i3= min(find(F(i1+1:length(F))==abs(',')))+i1+1;
if i3>i2
   inputs= []; linp= [];
else
   i1= i3; [inputs, linp] = divstring(char(F(i1:i2)), ',');   
end
warn= 1;
for i=1:size(forbvars, 1)
   str1= forbvars(i, 1:lfor(i));
   for j=1:nchar
      sss= []; eval(['matrix=' MAT(findchar(j), 1:lMAT(findchar(j))) ';']);
      sss= findname(str1, matrix);
      if ~isempty(sss)  % Forbidden variable used in string matrices
         if ~strcmp(str1, MAT(findchar(j), 1:lMAT(findchar(j))))
            if warn
               if strcmp(str1, 'z'), msg2= ' the OUTPUT data';
               elseif strcmp(str1, 'u'), msg2= ' the INPUT data';
               elseif strcmp(str1, 't'), msg2= ' the TIME index';
               elseif strcmp(str1, 'x'), msg2= ' the STATE VECTOR';
               elseif strcmp(str1, 'v'), msg2= ' the INNOVATIONS VECTOR';
               elseif strcmp(str1, 'zhat'), msg2= ' the OUTPUT PREDICTION';
               else msg2= ' the corresponding SYSTEM MATRIX';
               end
               message=['Variable name ''' str1 ''' in the definition of string system matrix ''' MAT(findchar(j), 1:lMAT(findchar(j))) '''&' ...
                  'in function ''' mfun '.m'' must be' msg2 '&' ...
                  'Make sure the definition is according to the following convention:&' ...
                  '  z: output data  (Nz x N)&' ...];
                  '  u: input data   (Nu x N)&' ...];
                  '  x: state vector (Ns x 1)&' ...];
                  '  t: time index   (1 x 1)&' ...];
                  '  v: innovations vector (Nz x 1)&' ...];
                  '  zhat: output prediction (Nz x 1)&' ...];
                  '  Phi, Gam, E, H, D, C, Q, R, S: System matrices&' ...
                  'Beware that other string system matrices may have the same problem.'];
               warningsspace(divstring(message, '&'), 'checkmodel');
               warn= 0;
            end
         
            for k=1:size(inputs, 1)  % Forbidden variable is input and string
               SSS= findname(str1, inputs(k, 1:linp(k)));
               if ~isempty(SSS)
                  message=['Variable name ''' str1 ''' in the definition of string system matrix ''' MAT(findchar(j), 1:lMAT(findchar(j))) '''&' ...
                        'in function ''' mfun '.m'' not allowed because it is an input&' ...
                        'to this function at the same time.&' ...
                        'Change the input variable name.&' ...
                        'Other input variable names to this function may be illegal.'];
                  errorSSpace(divstring(message, '&'), 'checkmodel');
               end
            end
         end
      end
   end
end

z= ones(sizeszu(2), sizeszu(1));
zhat= z*0.5; v= z(:, 1); t= floor(sizeszu(1)/2);
u= ones(sizeszu(3), sizeszu(1));
x= ones(max([size(Phi, 1) size(Gam, 1) size(E, 1)]), 1);
N= sizeszu(1);
Nz= sizeszu(2);
Nu= sizeszu(3);
Ns= size(Phi, 1);

for i= 1:nchar
   eval(eval([MAT(findchar(i), 1:lMAT(findchar(i)))]));
end
if exist('Phi_x')
   [rPhi, cPhi]= size(Phi_x); 
   if rPhi~= Ns, errorSSpace('Rows of matrix Phi_x are not the number of states', 'checkmodel'); end
   if cPhi~=  1, errorSSpace('Columns of matrix Phi_x is not 1', 'checkmodel'); end
   Phi= Phi_x;
end
if exist('H_x')
   [rH, cH]= size(H_x); 
   if rH~= Nz, errorSSpace('Rows of matrix H_x are not the number of outputs', 'checkmodel'); end
   if cH~=  1, errorSSpace('Columns of matrix H_x is not 1', 'checkmodel'); end
   H= H_x;
end
if exist('D_u')
   [rD, cD]= size(D_u); 
   if rD~= Nz, errorSSpace('Rows of matrix D_u are not the number of outputs', 'checkmodel'); end
   if cD~=  1, errorSSpace('Columns of matrix D_u is not 1', 'checkmodel'); end
   D= D_u;
end
if exist('Gam_u')
   [rG, cG]= size(Gam_u); 
   if rG~= Ns, errorSSpace('Rows of matrix Gam_u are not the number of states', 'checkmodel'); end
   if cG~=  1, errorSSpace('Columns of matrix Gam_u is not 1', 'checkmodel'); end
   Gam= Gam_u;
end

nn= size(varargin, 2);
str= abs('=varargin{'); str2= '};';
call_varargin= [inputs char(str(ones(nn, 1), :)) int2str((1:nn)') char(str2(ones(nn,1), :))];
call_varargin= call_varargin'; call_varargin= call_varargin(:)';


end    % if nchar
% End of checking forbidden variable names in string system matrices







% Checking consistency of system matrix dimensions
% Checking for time varying or non-linear systems
% Matrices orders
orders= ones(11, 3);
[l1, l2, l3]= size(Phi); orders(1, :)= [l1 l2 l3];
[l1, l2, l3]= size(Gam); orders(2, :)= [l1 l2 l3];
[l1, l2, l3]= size(E); orders(3, :)= [l1 l2 l3];
[l1, l2, l3]= size(H); orders(4, :)= [l1 l2 l3];
[l1, l2, l3]= size(D); orders(5, :)= [l1 l2 l3];
[l1, l2, l3]= size(C); orders(6, :)= [l1 l2 l3];
[l1, l2, l3]= size(Q); orders(7, :)= [l1 l2 l3];
[l1, l2, l3]= size(R); orders(8, :)= [l1 l2 l3];
[l1, l2, l3]= size(S); orders(9, :)= [l1 l2 l3];
[l1, l2, l3]= size(Phider); orders(10, :)= [l1 l2 l3];
[l1, l2, l3]= size(Hder); orders(11, :)= [l1 l2 l3];
timev= find(orders(:, 3)>1);

N= sizeszu(1);
Nz= sizeszu(2);
Nu= sizeszu(3);
Ns= size(Phi, 1);
% State system matrices
if orders(1, 2)~= Ns, errorSSpace('System matrix Phi not square', 'checkmodel'); end
if orders(3, 1)~= Ns, errorSSpace('Rows of system matrices Phi and E are not the same', 'checkmodel'); end
if orders(2, 1)~= 0
   if orders(2, 1)~= Ns, errorSSpace('Rows of system matrices Gam and Phi are not the same', 'checkmodel'); end
   if orders(2, 1)~= orders(3, 1), errorSSpace('Rows of system matrices Gam and E are not the same', 'checkmodel'); end
   if orders(2, 2)~= Nu, errorSSpace('Columns of system matrix Gam inconsistent with number of inputs', 'checkmodel'); end
end
if orders(3, 2)~= orders(7, 1), errorSSpace('Columns of system matrix E are not the same than rows of Q', 'checkmodel'); end
if orders(7, 2)~= orders(7, 1), errorSSpace('System matrix Q not square', 'checkmodel'); end
% Observation equation system matrices
if orders(4, 1)~= Nz, errorSSpace('Rows of system matrix H inconsistent with number of outputs', 'checkmodel'); end
if orders(4, 2)~= Ns, errorSSpace('Columns of system matrix H inconsistent with number of states', 'checkmodel'); end
if orders(6, 1)~= Nz, errorSSpace('Rows of system matrix C inconsistent with number of outputs', 'checkmodel'); end
if orders(6, 2)~= orders(8, 1), errorSSpace('Columns of system matrix C are not the same than rows of R', 'checkmodel'); end
if orders(5, 1)> 0
   if orders(5, 1)~= Nz, errorSSpace('Rows of system matrix D inconsistent with number of outputs', 'checkmodel'); end
   if orders(5, 2)~= Nu, errorSSpace('Columns of system matrix D inconsistent with number of inputs', 'checkmodel'); end
end
if orders(8, 2)~= orders(8, 1), errorSSpace('System matrix R not square', 'checkmodel'); end
if orders(9, 1)~= orders(3, 2), errorSSpace('Rows of system matrix S are not the same than columns of E', 'checkmodel'); end
if orders(9, 2)~= orders(8, 1), errorSSpace('Columns of system matrix S are not the same than rows of R', 'checkmodel'); end

% Phider and Hder
if orders(10, 1)>0
   if orders(10, 1)~= Ns, errorSSpace('Rows of matrices Phider and Phi are not the same', 'checkmodel'); end
   if orders(10, 2)~= Ns, errorSSpace('Columns of matrices Phider and Phi are not the same', 'checkmodel'); end
end
if orders(11, 1)>0
   if orders(11, 1)~= orders(4, 1), errorSSpace('Rows of matrices Hder and H are not the same', 'checkmodel'); end
   if orders(11, 2)~= orders(4, 2), errorSSpace('Columns of matrices Hder and H are not the same', 'checkmodel'); end
end

% Time varying matrices checks
for i=1:11
   if (orders(i, 3)>1 & orders(i, 3)~= N)
      errorSSpace(['Time varying system ' MAT(i, 1:lMAT(i)) ' matrix of different dimension than the data'], 'checkmodel');
   end
end

% Symmetry of covariance matrices
% if size(Q, 3)== 1
%   Qp= Q'; 
%   if (sum(Qp(:)==Q(:))~= (orders(7, 1)^2)), errorSSpace('System matrix Q is not symmetric', 'checkmodel'); end
% end
% if size(R, 3)== 1
%    Rp= R';
%    if (sum(Rp(:)==R(:))~= (orders(8, 1)^2)), errorSSpace('System matrix R is not symmetric', 'checkmodel'); end
% end

% Semidefinite positive co-variances matrices
if size(Q, 3)== 1
   eigQ= eig(Q); 
   if any(eigQ< 0), warningsspace('Non semidefinite positive Q system matrix', 'checkmodel'); end
end
if size(R, 3)== 1
   eigR= eig(R);
   if any(eigR< 0), warningsspace('Non semidefinite positive R system matrix', 'checkmodel'); end
end

% Variance intervention checks
lI= length(Inter); 
if lI>0, if any(Inter== 1), errorSSpace('Variance intervention point set at first sample', 'checkmodel'); end
   [rP, cP]= size(PInter);
   if any(Inter== N), warningsspace('Variance intervention point set at last sample', 'checkmodel'); end
   if (lI~=cP), errorSSpace('Vector ''Inter'' and matrix ''PInter'' with different number of columns', 'checkmodel'); end
   if (rP~=Ns), errorSSpace('Matrix ''PInter'' with rows different to the number of states', 'checkmodel'); end
% Reordering Inter and PInter
   [Inter, iInter]= sort(Inter);
   PInter= PInter(:, iInter);
end

