function [p, covpar, e, stats]= SSestimET(z, u, model_struc, p, varargin)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

t1= clock; 

% Starting 'global' variables
SSpaceiniET;

% Checking inputs
[Nz, N]= size(z);
if Nz > N, z= z'; [Nz N]= size(z); end

if nargin<2, u= []; end
[Nu, NNN]=size(u); 
if Nu>NNN, u= u'; [Nu NNN]= size(u); end
if (NNN> 0 & N~= NNN), errorSSpace('Output and input data of different sizes', 'SSestim'); end

if nargin<3 | isempty(model_struc), errorSSpace('No model defined for estimation!!!', 'SSestim'); end

% Missing values
% smiss= find(sum(isnan([z; u])));
% ini= 1;
% if any(smiss== 1)
%     ini= min(find(diff(smiss)~= 1))+1;
%     if isempty(ini), ini= 2; end
% end
% if any(smiss== N)
%     ind= smiss(max(find(diff(smiss)~= 1))+1)-1;
%     if isempty(ind), N= N-1; else, N= ind; end
% end
% z= z(:, ini : N);
% if ~isempty(u), u= u(:, ini : N); end
% N= size(z, 2);
smiss= find(sum(isnan([z; u])));
if ((any(smiss== 1) | any(smiss== N)) & SSpace_WARNINGS)
    warningsspace('Missing values at the end or beginning of data');
end
Miss= isnan(z);

% Evaluating the system matrices
if isempty(varargin)
   [Ns, charsys, timev, Inter, PInter, call_varargin]= checkmodelet([N Nz Nu], model_struc);
   npar= findnpar(model_struc);
   model_struc= ['[x0, P0, Phit, Gamt, Et, Ht, Dt, Ct, Qt, Rt, St, Phidert, Hdert, Inter, PInter]=' model_struc '(p);'];
else
   [Ns, charsys, timev, Inter, PInter, call_varargin]= checkmodelet([N Nz Nu], model_struc, varargin{:});
   npar= findnparet(model_struc, varargin{:});
   model_struc= ['[x0, P0, Phit, Gamt, Et, Ht, Dt, Ct, Qt, Rt, St, Phidert, Hdert, Inter, PInter]=' model_struc '(p, varargin{:});'];
end   

% Adjusting the number of parameters
if nargin< 4, p= -0.1*ones(npar, 1); end
if isempty(p), p= -0.1*ones(npar, 1); end
lp= length(p);
if npar>lp, p= p(:)'; p= [p p(lp)*ones(1, npar-lp)]; end
if npar<lp, p= p(1:npar) ;end
p= p(:);

eval(model_struc([1:7 79:end]));

% Checking for time varying or non-linear systems
nchar= sum(charsys);
OBJECTIVE_FUN_NEW= OBJECTIVE_FUN;
if sum(sum(Miss>0)) | ~isempty(timev), OBJECTIVE_FUN_NEW= [OBJECTIVE_FUN 'nan']; end
if nchar, OBJECTIVE_FUN_NEW= [OBJECTIVE_FUN 's']; end
if nargout> 1, cOBJF= ['c' OBJECTIVE_FUN_NEW]; end

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

if ((sum(charsys([1 3 7])) | ~isempty(timev)) & ischar(x0))   % Time variant or non-linear system
   errorSSpace('x0 input inconsistent with time varying or non linear systems.', 'SSestim')
%else, x0= zeros(Ns, 1); P0= eye(Ns)*1e5;    % Time varying system
end
if ischar(x0)
   x0= lower(x0); lx0= length(x0);
   noinp= 'noinputs'; stoch= 'stochastic'; deter= 'deterministic';
   if strcmp(x0, noinp(1:lx0)) & isempty(u)   %~all(u==0)
      errorSSpace('x0 implies no inputs, but there are inptus in the system.', 'SSestim');
   end
   if strcmp(x0, stoch(1:lx0)) & isempty(u)    %all(u==0)
      errorSSpace(['x0 implies ' stoch ' inputs, but there are not any in the system.'], 'SSestim');
   end
   if strcmp(x0, deter(1:lx0)) & isempty(u)    % all(u==0)
      errorSSpace(['x0 implies ' deter ' inputs, but there are not any in the system.'], 'SSestim');
   end
   if ~strcmp(x0, deter(1:lx0)) & ~strcmp(x0, stoch(1:lx0)) & ~strcmp(x0, noinp(1:lx0))
      errorSSpace('Unknown x0 option.', 'SSestim');
   end
end

% Model estimation
HANDLES= []; FUN_OPTIMUM= [];
if STOP_WINDOW, HANDLES= stop(OBJECTIVE_FUN_NEW, TABLE_OUTPUT); end
if ischar(OPTIMISER_OPTIONS) & ~isempty(OPTIMISER_OPTIONS)
   eval(OPTIMISER_OPTIONS);
end
OPTIMISER_COMMAND= strrep(OPTIMISER_COMMAND, OBJECTIVE_FUN, OBJECTIVE_FUN_NEW);
eval(OPTIMISER_COMMAND);
separ= nan*(ones(size(p))); corrpar= [];
AIC= []; SBC= []; HQC= []; SIGMA= []; R2= []; stats= [];
if nargout>1
   if ~isempty(HANDLES), set(HANDLES(3), 'string', 'Estimating covariance matrix'); end
   eval(['[covpar, e]= ' cOBJF '(p,z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,call_varargin,varargin{:});']);
   [SIGMA, Nnan]= nanprod(e(:, Ns+1:N), e(:, Ns+1:N)');  %/(N-Ns);
   SIGMA= SIGMA./Nnan;
   ldsigma= log(det(SIGMA));
   kk= npar*Nz*Nz+Nz; NNs= N-Ns;
   AIC= ldsigma + 2*kk/NNs;
   SBC= ldsigma + kk*log(NNs)/NNs;
   HQC= (ldsigma + 2*kk*log(log(NNs))/NNs);
   R2= 1-diag(SIGMA)./diag((nancov(z(:, Ns+1:N)')));
   R2c= 1-(diag(Nnan)-1)./(diag(Nnan)-npar).*(1-R2);
   corrpar= corrmatrix(covpar)+triu(nan*ones(npar),1);   
   ivariance= diag(covpar);
   separ= sqrt(ivariance);
   stats= [FUN_OPTIMUM AIC SBC HQC R2c' diag(SIGMA)'];
else
    stats= FUN_OPTIMUM;
end
if ~isempty(HANDLES), close(HANDLES(1)); end
tiempo= etime(clock, t1); 
% End of model estimation

if TABLE_OUTPUT
   showmodel(p, N, separ, corrpar, tiempo, OBJECTIVE_FUN_NEW, stats);
end
