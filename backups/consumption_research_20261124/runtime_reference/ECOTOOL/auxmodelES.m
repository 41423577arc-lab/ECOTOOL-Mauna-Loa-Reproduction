function [e, py, stdpy, comp, comps]= auxmodelES(z, u, model, nofs, estimate, p0)
%     model= {Trend, Periods, Rho, seasonal, irregular, D};

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

z= z(:);
[N, m]= size(z);
ind= nan(2, m);
for i= 1 : m
    if isnan(z(1, i))
        ind1= min(find(diff(~isnan(z(:, i)))> 0))+1;
    else
        ind1= 1;
    end
    if isnan(z(N, i))
        ind2= max(find(diff(~isnan(z(:, i)))< 0));
    else
        ind2= N;
    end
    ind(:, i)= [ind1; ind2];
end
ind1= max(ind(1, :));
ind2= min(ind(2, :));

if nargin< 2, u= []; end
[NNN, Nu]= size(u);
if NNN< Nu, u= u'; [NNN, Nu]= size(u); end
Nuini= Nu;

if (NNN~= N & Nu> 0), error('Output and Inputs must have the same time lenght'); end

if nargin< 4, nofs= 12; end
if isempty(nofs), nofs= 12; end

if nargin< 5, estimate= 1; end
if isempty(estimate), estimate= 1; end

if nargin< 3, model= 'AA12'; end
if isempty(model), model= 'AA12'; end
if (~strcmp(model(1), 'D') & ~strcmp(model(1), 'N')), model(1)= 'A'; end
if (~strcmp(model(2), 'N')), model(2)= 'A'; end
lm= length(model);
s= 12;
if lm> 2, s= str2num(model(3 : end)); end
model= upper(model(1 : 2));

npar= 2 + Nu;
coefs= 'Var(e) Alpha';
if strcmp(model(1), 'A'), npar= npar+1; coefs= [coefs ' Beta']; end
if strcmp(model(1), 'D'), npar= npar+2; coefs= [coefs ' Beta Damp']; end
if strcmp(model(2), 'A'), npar= npar+1; coefs= [coefs ' Gamma']; end
if Nu
    ccc= [repmat(' D_', Nu, 1) num2str((1:Nu)')]';
    coefs= [coefs ccc(:)'];
end

% Initial conditions
if nargin< 6,   p0= []; end
nalfas= npar-Nu;
if isempty(p0), p0= [0.01; ones(nalfas-1, 1); zeros(Nu, 1)]; end
p0= p0(:);
lp0= length(p0);
if lp0< npar, p0= [p0; repmat(p0(end), npar(end)-lp0, 1)]; end
if Nu
    p0= [log10(p0(1 : nalfas)); p0(nalfas+1 : end)];
else
    p0= log10(p0);
end

% Building system matrices
Gam= [];
if strcmp(model, 'NN')
    Phi= [1 0; 1 0];
    if Nu, Gam= zeros(2, Nu); end
%     E= [PP(2); 1];
    E= [0; 1];
    H= [0 1];
elseif strcmp(model, 'AN')
    Phi= [1 1 0; 0 1 0;1 1 0];
    if Nu, Gam= zeros(3, Nu); end
%     E= [PP(2); PP(3); 1];
    E= [0; 0; 1];
    H= [0 0 1];
elseif strcmp(model, 'DN')
%     Phi= [1 PP(4) 0; 0 PP(4) 0;1 PP(4) 0];
    Phi= [1 0 0; 0 0 0;1 0 0];
    if Nu, Gam= zeros(3, Nu); end
%     E= [PP(2); PP(3); 1];
    E= [0; 0; 1];
    H= [0 0 1];
elseif strcmp(model, 'NA')
    Phi= zeros(s+2);
    Phi(1, 1)= 1; Phi(end, 1)= 1;
    Phi(3 : s+2, 2 : s+1)= diag(ones(s, 1));
    Phi(2, end-1)= 1;
    if Nu, Gam= zeros(s+2, Nu); end
%     E= [PP(2); PP(3); PP(4); zeros(s-2, 1); 1];
    E= [0; 0; zeros(s-1, 1); 1];
    H= [zeros(1, s+1) 1];
elseif strcmp(model, 'AA')
    Phi= zeros(s+3);
    Phi(1 : 2, 1 : 2)= [1 1;0 1]; Phi(end, 1 : 2)= 1;
    Phi(4 : s+3, 3 : s+2)= diag(ones(s, 1));
    Phi(3, end-1)= 1;
    if Nu, Gam= zeros(s+3, Nu); end
%     E= [PP(2); PP(3); PP(4); zeros(s-1, 1); 1];
    E= [0; 0; 0; zeros(s-1, 1); 1];
    H= [zeros(1, s+2) 1];
elseif strcmp(model, 'DA')
    Phi= zeros(s+3);
    Phi(1 : 2, 1 : 2)= [1 1;0 1]; Phi(end, 1 : 2)= 1;
    Phi(4 : s+3, 3 : s+2)= diag(ones(s, 1));
    Phi(3, end-1)= 1;
%     Phi([1 2 s+3], 2)= PP(4);
    Phi([1 2 s+3], 2)= 0;
    if Nu, Gam= zeros(s+3, Nu); end
%     E= [PP(2); PP(3); PP(5); zeros(s-1, 1); 1];
    E= [0; 0; 0; zeros(s-1, 1); 1];
    H= [zeros(1, s+2) 1];
end    
C= 1;
R= 0;
S= zeros(size(E, 2), size(R, 1));


if (estimate & npar> 1)
    if Nu
        [par, covpar, inn, stats]= SSestimET(z(ind1 : ind2, :), u(ind1 : ind2, :), 'auxmodelESSS', p0, ...
            model, s, Nu, z(1), Phi, Gam, E, H, C, R, S, npar);
    else
        [par, covpar, inn, stats]= SSestimET(z(ind1 : ind2, :), [], 'auxmodelESSS', p0, ...
            model, s, Nu, z(1), Phi, Gam, E, H, C, R, S, npar);
    end
else
    par= p0;
end

comp= zeros(N, 3+Nu); comps= []; Px= [];
if Nu
    Nofs= size(nofs, 2);
    if (Nofs== Nu)
        if nargout< 5
            [inn, zhat, xhat, Pz]= fisET([z; nan(size(nofs, 1), 1)], [u; nofs], 'auxmodelESSS', par, 1, ...
                model, s, Nu, z(1), Phi, Gam, E, H, C, R, S, npar);
        else
            [inn, zhat, xhat, Pz, Px]= fisET([z; nan(size(nofs, 1), 1)], [u; nofs], 'auxmodelESSS', par, 1, ...
                model, s, Nu, z(1), Phi, Gam, E, H, C, R, S, npar);
        end
        D= u.*repmat(par(nalfas+1 : npar)', N, 1);
    else
        error('Check ''nofs'' input. Forecasts and components not estimated.');
    end
else
    Nofs= nofs;
    if nargout< 5
        [inn, zhat, xhat, Pz]= fisET([z; nan(nofs, 1)], [], 'auxmodelESSS', par, 1, ...
                model, s, Nu, z(1), Phi, Gam, E, H, C, R, S, npar);
    else
        [inn, zhat, xhat, Pz, Px]= fisET([z; nan(nofs, 1)], [], 'auxmodelESSS', par, 1, ...
                model, s, Nu, z(1), Phi, Gam, E, H, C, R, S, npar);
    end        
    D= [];
end
if ~isempty(Px)
    comps= zeros(N, 3);
    for i= 1 : N
        pzi= Pz(1, 1, i);
        pxi= diag(Px(:, :, i));
        comps(i, :)= real(sqrt(([pxi([1 3])' pzi])));
    end
end

e= inn(size(xhat, 1)+2 : end)'; % e(1 : size(xhat, 1)+2)= nan;
comp(:, 1)= xhat(1, 1:N)';
% if (~strcmp(model(1), 'N')), comp(:, 2)= xhat(2, 1:N)'; end
if strcmp(model(2), 'A')
    if strcmp(model(1), 'N'), st= 2; else, st= 3; end
    comp(:, 2)= xhat(st, 1:N)';
end
comp(:, 3 : end)= [z-sum(comp(1:N, 1:3), 2) D]; comp(1, 3)= comp(2, 3);
py= zhat(N+1 : N+Nofs)';
stdpy= sqrt(Pz(1, N+1 : N+Nofs)');


if estimate
   NPAR= npar;
   [SIGMA, Nnan]= nanprod(e', e);  %/(N-Ns);
   SIGMA= SIGMA./Nnan;
   ldsigma= log(SIGMA);
   AIC= ldsigma + 2*NPAR/Nnan;
   SBC= ldsigma + NPAR*log(Nnan)/Nnan;
   HQC= (ldsigma + 2*NPAR*log(log(Nnan))/Nnan);
   R2= 1-SIGMA./(nancov(z(:,1)));
   R2c= 1-(Nnan-1)./(Nnan-NPAR).*(1-R2);
   sterr= sqrt(diag(covpar));

    table= [];
    sec=etime(clock, t1);
	if npar(end)> 0
        hora= fix(clock); 
        if hora(5)< 10
            hora= [int2str(hora(4)) ':0' int2str(hora(5))];
        else
            hora= [int2str(hora(4)) ':' int2str(hora(5))];
        end
        testt= abs(par./sterr);
        if isempty(covpar), pvalue= testt; else, pvalue= 1-tcdf(testt, N-npar(end)); end
        PP= par; PP(1 : nalfas)= 10.^par(1 : nalfas);
        table= [PP par sterr testt pvalue];
        table= printwf(table, 5, 'PARAM Score STERR T-TEST P-value', coefs);
        table= charcat(' ', '-', 'Exponential Smoothing Model Estimation Results ', ...
            ['Date: ' date '   /  Time: ' hora ' '], '-', ...
            ['Missing values: ' int2str(sum(isnan(z))) ' '], ...
            ['Time: ' int2str(fix(sec)) ' seconds '], ...
            '-', table(1, :), '-', table(2 : end, :), '-', ...
            ['               AIC: ' num2str(AIC) ' '], ...
            ['               SBC: ' num2str(SBC) ' '], ...
            ['               HQC: ' num2str(HQC) ' '], ...
            ['Objective Function: ' num2str(stats(1)) ' '], ...
            ['      Corrected R2: ' num2str(R2c) ' '], ...
            [' Residual Variance: ' num2str(SIGMA) ' '], '-');
        if isempty(covpar)
            textoutputWINDOW(table, 'Exponential Smoothing Model Estimation Results');
        else
            corrpar= printwf(corrmatrix(covpar)+triu(nan*ones(npar(end)),1), 4, coefs, coefs);
            textoutputWINDOW(charcat(table, ' ', ' ', '-', ...
                '           Correlation matrix of estimates ', '-', corrpar(1, :), ...
                '-', corrpar(2 : end, :), '-'), ...
                'Exponential Smoothing Model Estimation Results');
        end
    end
end

