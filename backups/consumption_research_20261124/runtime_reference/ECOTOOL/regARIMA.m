function [e, py, stdpy, polysnum, par, covpar, y0, tfout, u, model,SBC, obj]=regARIMA(y,u,model,nofs,back,outlier,par0,out,out2)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

out2= 0;
WARNING_MESSAGE= ['Optimiser: FMINUNC '];

[ly, Ny]= size(y);
if ly< Ny, y= y'; [ly, Ny]= size(y); end

if nargin< 2, u= []; end
[NNN, Nu]= size(u);
if NNN< Nu, u= u'; [NNN, Nu]= size(u); end
Nuini= Nu;

if (NNN~= ly & Nu> 0), error('Output and Inputs must have the same time lenght'); end
if Nu, if sum(isnan(u(:))), error('Missing values in inputs not allowed'); end, end

if nargin< 3, model= []; end
if isempty(model), model= {'(1+p1*B)(1+p2*B12)/(1-B)(1-B12)'}; end
if isstr(model), model= {model}; end
Nmodel= size(model, 2);
if Nmodel> 1, nombres= model{2}; model= {model{1}}; end
% if Nmodel~= (Nu + 1), error('Model and number of inputs are incompatible'); end

if nargin< 4, nofs= []; end
%if isempty(nofs), nofs= max([max(s) 12]); end
if (Nu== 0 & ~isempty(nofs))
    if size(nofs, 1)> 1, error('Input ''nofs'' should be scalar for ARIMA models'); end
end
if (Nu>0 & ~isempty(nofs))
    if ~iscell(nofs)
        if (Nu~= size(nofs, 2)), error('Input ''nofs'' should be the inputs into the future horizon'); end
    end
end
if ~isempty(nofs)
    if (iscell(nofs) & size(nofs, 2)<= 2*Nu)
        error('Input ''nofs'' should include the number of forecasts as the last element in the vector');
    end
end
snofs= size(nofs);
if (sum(snofs)> 2 & snofs(2)~= Nu), nofs= nofs'; end

ooutlier= [0 1 1 1 1 0.7 3];
if nargin< 6, outlier= ooutlier; end
if isempty(outlier), outlier= ooutlier; end
sout= size(outlier, 2);
if sout< 7, outlier= [outlier ooutlier(sout+1 : end)]; end

% [coefs, strucnumerical, DIFFoper, nARIMA]= polypar(model);
[coefs, strucnumerical, DIFFoper]= polypar(model);
coeffs= [];
if ~isempty(coefs), coeffs= divstring(coefs); end
npar= size(coeffs, 1)+Nu;
% Añadiendo parámetros de regresión
if Nmodel> 1
    for i= 1:Nu
        coefs= [coefs ' ' deblank(nombres(i, :))];
    end
else
    for i= 1:Nu
        coefs= [coefs ' p' num2str(i)];
    end
end

% OPTS= optimset('disp','none');
OPTS= optimset('disp','iter', 'MaxFunEvals', npar*1e4, 'MaxIter', npar*1e5, ...
    'Tolfun', 1e-6, 'tolx', 1e-6);

if nargin< 7, par0= []; end

inicondU= [];
if nargin< 5, back= 0; end
if iscell(back)
    if size(back, 2)> 1
        inicondU= [back{2} zeros(size(back{2}, 1), Nu-size(back{2}, 2))];
        back= back{1};
    else
        back= back{1};
    end
end
if isempty(back),back= 0; end
if ischar(back)
    if strcmp(lower(back), 'eml')
        back= -1;      % Exact ML
    else
        back= 0;       % Conditional ML
    end
end
if (back== -1 & isempty(par0))
    back= -2;       % CML and EML
end
if (back== -2 & ~isempty(par0))
    back= -1;       % EML
end

if isempty(par0), par0= -0.1*ones(npar, 1); end
par0= par0(:);
spar0= size(par0, 1);
if spar0~=npar, par0= [par0; repmat(par0(end), npar-spar0, 1)]; end
covpar= [];

% if nargin< 8, opts= optimset('Display', 'off', 'MaxFunEvals', max(1000, npar*1000)); end

if nargin< 8, out= 1; end

if nargin< 9, out2= 0; end

Miss= find(isnan(y(:, 1)));
NM= size(Miss, 1);
if ~isempty(Miss)
   NMiss= diff([1; find(diff(Miss)> 1)+1; size(Miss, 1)+1]);
   ind= Miss([1; find(diff(Miss)> 1)+1]);
   rind= size(ind, 1);
   nans= cell(1, rind);
   for i= 1 : rind
      nans{i}= (ind(i) : ind(i) + NMiss(i)-1)';
   end
else
   nans= [];
end

% ESTIMATION
par= par0; lost= 0; iH= nan(npar);
y0= y;
t0=clock;
warning('off');
if out
   if npar> 0
       if back~= -1       % Conditional ML or back-forecasting
           if back== 0
               METHOD= 'CONDITIONAL SUM OF SQUARES';
           else
               METHOD= ['BACK-FORECASTING (' int2str(back) ')'];
           end
           if back== -2, back1= 0; else, back1= back; end
           try
               [par, obj, ee, oo, gr, H]= fminunc(@auxregfun, par, OPTS, y, u, strucnumerical, model, 0, nans, [], DIFFoper, inicondU);
           catch
%                WARNING_MESSAGE= 'ABNORMAL OPTIMISATION EXIT. RESULTS MAY NOT BE ACCURATE!! ';
%                par=get(0, 'userdata');
%                disp('Unstable solution with  
               WARNING_MESSAGE= ['Optimiser: FMINSEARCH '];
               [par, obj]= fminsearch(@auxregfun, par, OPTS, y, u, strucnumerical, model, 0, nans, [], DIFFoper, inicondU);
               H= hessian(par, y, u, strucnumerical, model, back1, nans, [], DIFFoper, inicondU);
           end
%            iH= pinv(H);
%            y0= interpTF(y, u, model, nans, par);
%            [obj, e]= auxregfun(par, y, u, strucnumerical, model, 0, nans, [], DIFFoper);
%           [par, obj, e, iH, y0]= minimize(par, model, nARIMA, y, u, strucnumerical, model, back1, nans, [], DIFFoper);
       end
       if back< 0         % Exact ML
           METHOD= 'EXACT MAXIMUM LIKELIHOOD';
           par0= par;
           polys= convert2poly(strucnumerical, par0);
           if size(polys{1, 1}, 2)== 1
               ini= size(polys{1, 2}, 2)-size(DIFFoper, 2);
           else
               ini= ly-size(DIFFoper, 2)+1;
           end
           V= [[0.5; (2 : ini)'] zeros(ini, ini-1)];
           for i= 2 : ini
               V(i : ini, i)= V(1 : ini-i+1, 1);
           end
           V= V+V';
% %            [par, obj, ee, oo, gr, H]= fminunc('auxregfun', par, [], y, u, strucnumerical, model, -1, (1:ly)', V, DIFFoper);
% %            iH= pinv(H);
% %            y0= interpTF(y, u, model, nans, par);
% %            [obj, e]= auxregfun(par, y, u, strucnumerical, model, back, (1:ly)', V, DIFFoper);
           try           
               [par, obj, ee, oo, gr, H]= fminunc(@auxregfun, par, OPTS, y, u, strucnumerical, model, -1, nans, V, DIFFoper, inicondU);
           catch
%                par=get(0, 'userdata');
               WARNING_MESSAGE= ['Optimiser: FMINSEARCH '];
               [par, obj]= fminsearch(@auxregfun, par, OPTS, y, u, strucnumerical, model, -1, nans, V, DIFFoper, inicondU);
               H= hessian(par, y, u, strucnumerical, model, 0, nans, [], DIFFoper, inicondU);
%            [par, obj, e, iH, y0]= minimize(par, model, nARIMA, y, u, strucnumerical, model, back, nans, V, DIFFoper);
%            obj= -0.5*obj;
%            diH= diag(iH); iH= iH-diag(diH); iH= iH+abs(diag(diH));
%            e= e(size(DIFFoper, 2) : end);
           end
       end
       iH= pinv(H);
       y0= interpTF(y, u, model, nans, par);
       [obj, e]= auxregfun(par, y, u, strucnumerical, model, 0, nans, [], DIFFoper, inicondU);
   else
       [obj, e]= auxregfun(par, y, u, strucnumerical, model, 0, nans, [], [], inicondU);
       y0= interpTF(y, u, model, nans, par);
   end
   [SIGMA, Nnan]= nanprod(e', e);  %/(N-Ns);
   SIGMA= SIGMA./Nnan;
   ldsigma= log(SIGMA);
   AIC= ldsigma + 2*npar/Nnan;
   SBC= ldsigma + npar*log(Nnan)/Nnan;
   HQC= (ldsigma + 2*npar*log(log(Nnan))/Nnan);
   R2= 1-SIGMA./(nancov(y(:,1)));
   R2c= 1-(Nnan-1)./(Nnan-npar).*(1-R2);
   if back< 0
       covpar= 2*iH;
   else
       covpar= 2*SIGMA*iH;
   end
   sterr= sqrt(diag(covpar));
   iii= find(imag(sterr));
   sterr(iii)= sqrt(imag(sterr(iii)));

% RESULTS
    table= [];
    sec=etime(clock,t0);
	if npar> 0
        hora= fix(clock); 
        if hora(5)< 10
            hora= [int2str(hora(4)) ':0' int2str(hora(5))];
        else
            hora= [int2str(hora(4)) ':' int2str(hora(5))];
        end
        testt= abs(par./sterr);
        if isempty(covpar), pvalue= testt; else, pvalue= 2*(1-tcdf(testt, ly-npar)); end
        table= [par sterr testt pvalue];
        table= printwf(table, 5, 'PARAM STERR T-TEST P-value', coefs);
        table= charcat(' ', '-', 'Transfer Function Estimation Results ', ...
            ['Date: ' date '   /  Time: ' hora ' '], '-', ...
            ['Estimation method: ' METHOD ' '], ['Missing values: ' int2str(NM) ' '], ...
            WARNING_MESSAGE, ...
            ['Time: ' int2str(fix(sec)) ' seconds '], ...
            '-', table(1, :), '-', table(2 : end, :), '-', ...
            ['               AIC: ' num2str(AIC) ' '], ...
            ['               SBC: ' num2str(SBC) ' '], ...
            ['               HQC: ' num2str(HQC) ' '], ...
            ['Objective Function: ' num2str(obj) ' '], ...
            ['      Corrected R2: ' num2str(R2c) ' '], ...
            [' Residual Variance: ' num2str(SIGMA) ' '], '-');
        load testguiSETTINGS
        if (isempty(covpar) | outlier(1)== -1)
            textoutputWINDOW(table, 'Transfer Function Estimation Results', Wposition, TextFontSize);
        else
            corrpar= printwf(corrmatrix(covpar)+triu(nan*ones(npar),1), 4, coefs, coefs);
            textoutputWINDOW(charcat(table, ' ', ' ', '-', ...
                '           Correlation matrix of estimates ', '-', corrpar(1, :), ...
                '-', corrpar(2 : end, :), '-'), ...
                'Transfer Function Estimation Results', Wposition, TextFontSize);
        end
    end
else
   if back< 0         % Exact ML
       polys= convert2poly(strucnumerical, par);
       if size(polys{1, 1}, 2)== 1
           ini= size(polys{1, 2}, 2)-size(DIFFoper, 2);
       else
           ini= ly-size(DIFFoper, 2)+1;
       end
       V= [[0.5; (2 : ini)'] zeros(ini, ini-1)];
       for i= 2 : ini
           V(i : ini, i)= V(1 : ini-i+1, 1);
       end
       V= V+V';
   else
       V= [];
   end
%    [obj, e]= auxregfun(par, y, u, strucnumerical, model, back, (1 : ly)', V, DIFFoper);
    [obj, e]= auxregfun(par, y, u, strucnumerical, model, back, [], V, DIFFoper, inicondU);
   y0= interpTF(y, u, model, nans, par);
end
polys= convert2poly(strucnumerical, par);
warning('on');

% OUTLIER AUTOMATIC DETECTION
C= outlier(1); uoutliers= []; noutliers= 0;
if (C>0 & C< 2), C= 2; end
if C> 0
    maxlambdaA= 0; maxlambdaI= 0; maxlambdaL= 0; maxlambdaT= 0;
    c07= num2str(outlier(3));
    T= size(e, 1); iter= 1; numout= 1;
    tableout= []; OUTTYPE= 'TYPE'; tableoutstr= charcat(' ', ' ', '-', ['OUTLIER AUTOMATIC DETECTION (C= ' sprintf('%0.1f', C) '): '], '-');
    while (iter<= outlier(2) & numout> 0)
        maxlambda= C + 2; numout= 0;
        PI= arma2tsi(polys{1, 1}, polys{1, 2}, T);
        lB= arma2tsi([1 -1], PI, T);
        bB= arma2tsi([1 -outlier(3)], PI, T);
        while (maxlambda> C & numout< ly/4)
           sigma= nanmedian(abs(e))/0.675;
% 	        sigma= nanstd(e);
%            sigma= nanmedian(abs(e));
	% AO outliers
            if outlier(2)
                w= zeros(T, 1); rho2= 1./flipud(cumsum(PI.*PI));
                for i= 1 : T
                    w(i)= e(i)+nansum(PI(2 : T-i+1).*e(i+1 : end));
                end
                w= rho2.*w;
                [maxlambdaA, iA]= nanmax(abs(w)./(sqrt(rho2)*sigma));
                wA= w(iA);
            end
	% IO outliers
            if outlier(3)
                w= e;
                [maxlambdaI, iI]= nanmax(abs(e)/sigma);
                wI= e(iI);
            end
	% LS outliers
            if outlier(4)
                w= zeros(T, 1); rho2= 1./flipud(cumsum(lB.*lB));
                for i= 1 : T
                    w(i)= e(i)+nansum(lB(2 : T-i+1).*e(i+1 : end));
                end
                w= rho2.*w;
                [maxlambdaL, iL]= nanmax(abs(w)./(sqrt(rho2)*sigma));
                wL= w(iL);
            end
	% TC outliers
            if outlier(5)
                w= zeros(T, 1); rho2= 1./flipud(cumsum(bB.*bB));
                for i= 1 : T
                    w(i)= e(i)+nansum(bB(2 : T-i+1).*e(i+1 : end));
                end
                w= rho2.*w;
                [maxlambdaT, iT]= nanmax(abs(w)./(sqrt(rho2)*sigma));
                wT= w(iT);
            end
	
            [maxlambda, outtype]= nanmax([maxlambdaA maxlambdaI maxlambdaL maxlambdaT]);
            if maxlambda> C
                numout= numout + 1;
                if outtype== 1
%	disp([int2str(iA+ly-T) '  AO' printwf([wA maxlambda])])
                    e(iA : end)= e(iA : end) - wA*PI(1 : end-iA+1);
                    tableout= [tableout; iA+ly-T wA maxlambda iter outtype];
                    OUTTYPE= charcat(OUTTYPE, 'AO ');
                elseif outtype== 2
%	disp([int2str(iI+ly-T) '  IO' printwf([e(iI) maxlambda])])
                    e(iI)= 0;
                    tableout= [tableout; iI+ly-T wI maxlambda iter outtype];
                    OUTTYPE= charcat(OUTTYPE, 'IO ');
                elseif outtype== 3
%	disp([int2str(iL+ly-T) '  LS' printwf([e(iL) maxlambda])])
                    e(iL : end)= e(iL : end) - wL*lB(1 : end-iL+1);
                    tableout= [tableout; iL+ly-T wL maxlambda iter outtype];
                    OUTTYPE= charcat(OUTTYPE, 'LS ');
                else
%	disp([int2str(iT+ly-T) '  TC' printwf([e(iT) maxlambda])])
                    e(iT : end)= e(iT : end) - wT*bB(1 : end-iT+1);
                    tableout= [tableout; iT+ly-T wT maxlambda iter outtype];
                    OUTTYPE= charcat(OUTTYPE, 'TC ');
                end
                tableoutstr= charcat(' ', ' ', '-', ['OUTLIER AUTOMATIC DETECTION (C= ' sprintf('%0.1f', C) '): '], '-', ...
                    [OUTTYPE printwf(tableout(:, 1 : 4), [0 4 4 0], 'Sample Estimate T-Test Iteration')]);
                if out, textoutputWINDOW(charcat(table, tableoutstr)); drawnow; end
            end
        end
        iter= iter + 1;
        noutliers= size(tableout, 1);
        uoutliers= zeros(ly, noutliers);
        for ii= 1 : noutliers
            uoutliers(tableout(ii, 1), ii)= 1;
            namecoef= [strrep(OUTTYPE(ii+1, :), ' ', '') int2str(tableout(ii, 1))];
            if tableout(ii, 5)== 1
                model{Nu+ii+1}= namecoef;
            elseif tableout(ii, 5)== 2
                model1= strrep(model{1}, ' ', '');
                if strcmp(model1(1), '('), joint= ')'; else, joint= ')('; end
                model{Nu+ii+1}= ['(' namecoef joint model{1}];
            elseif tableout(ii, 5)== 3
                model{Nu+ii+1}= ['(' namecoef ')/(1-B)'];
            elseif tableout(ii, 5)== 4
                model{Nu+ii+1}= ['(' namecoef ')/(1-' c07 '*B)'];
            end
        end
        if numout> 0
            if nargout> 5
                [e, aa1, aa2, aa3, par, covpar]= regARIMA(y0, [u uoutliers], model, [], back, -1, [par; tableout(end-numout+1 : end, 2)], 1, 0);
            else
                [e, aa1, aa2, aa3, par]= regARIMA(y0, [u uoutliers], model, [], back, -1, [par; tableout(end-numout+1 : end, 2)], 1, 0);
            end
            if out
                figh= findall(gcf, 'name', 'Text Output Window');
                figh= findall(figh, 'style', 'listbox');
                table= get(figh, 'string');
            end
        end
    end
    if out, textoutputWINDOW(charcat(table, tableoutstr, '-', ...
            ['Estimation Time: ' num2str(etime(clock, t0)) ' seconds '], '-')); drawnow; end
     u= [u uoutliers]; Nu= size(u, 2);
end
if noutliers> 0    % With outliers
    [coefs, strucnumerical]= polypar(model);
    polys= convert2poly(strucnumerical, par);
    [A, B, C]= poly2armax(polys);
end

% FORECASTING
py= []; stdpy= 0; covs= 0;
if ~isempty(nofs)
    if iscell(nofs)
        nfor= nofs{end};
    elseif (sum(size(nofs))== 2 & Nuini< 1)
            nfor= nofs;
    else
        nfor= size(nofs, 1);
    end
    if noutliers> 0    % With outliers
%         [coefs, strucnumerical]= polypar(model);
%         polys= convert2poly(strucnumerical, par);
%         [A, B, C]= poly2armax(polys);
%        Nuini= size(nofs, 2);
        nofsu= [];
        if iscell(nofs)
            nofsu= zeros(nfor, Nu-Nuini);
        else
            if (sum(size(nofs))== 2 & Nuini< 1)
                nofs= zeros(nofs, Nu);
            else
                nofs= [nofs zeros(nfor, Nu-Nuini)];
            end
        end
    else
        [A, B, C]= poly2armax(polys);
        nofsu= [];
    end
	if iscell(nofs)   % Stochastic inputs
        NOFS= zeros(nfor, Nuini);
        covs= zeros(nfor, 1);
        for i= 1 : Nuini   % Forecasts for stochastic inputs
            polynum= nofs{(i-1)*2+1};
            polyden= nofs{(i-1)*2+2};
            ei= filter(polyden, polynum, u(:, i));
            NOFS(:, i)= parma(u(:, i), polynum, polyden, nfor, ei);
            covi= nancov(ei(max(size(polynum, 2), size(polyden, 2))+1 : end));
            covs= covs+covi*cumsum((arma2tsi(conv(polyden, polys{i, 2}), conv(polynum, polys{i, 1}), nfor)).^2);
        end
        if isempty(nofsu)
            py= parmax([y u], B, A, C, NOFS, e);
        else
            py= parmax([y u], B, A, C, [NOFS nofsu], e);
        end
        stdpy= covs;
	elseif (sum(size(nofs))== 2 & Nu== 0)  % Just the number of forecasts supplied (univariate models)
        py= parma(y0, C, A, nofs, e);
	else              % Deterministic inputs
        py= parmax([y0 u], B, A, C, nofs, e);
	end
    stdpy= sqrt(covs + nancov(e)*cumsum((arma2tsi(polys{1, 2}, polys{1, 1}, nfor)).^2));
end

tfout= []; polysnum= [];
if out2> 0
   if Nu> 0
      tfout= zeros(ly+size(nofs, 1), Nu);
      for i= 1 : Nu
         inicond= max(length(polys{i+1, 1}), length(polys{i+1, 2}))-1;
         if isempty(nofs)
             tfouti= filter(polys{i+1, 1}, polys{i+1, 2}, [repmat(u(1,i), inicond,1); u(:, i)]);
             tfout(:, i)= tfouti(inicond+1 : end);
         else
             tfouti= filter(polys{i+1, 1}, polys{i+1, 2}, [repmat(u(1,i), inicond,1); u(:, i); nofs(:, i)]);
             tfout(:, i)= tfouti(inicond+1 : end);
%              tfout(:, i)= filter(polys{i+1, 1}, polys{i+1, 2}, [u(:, i); nofs(:, i)]);
         end
      end
   end
   Nout= Nu-Nuini;
   if (Nout== 1)
       y0= y0-tfout(1:ly, Nuini+1);
   elseif (Nout> 1)
       y0= y0-sum(tfout(1:ly, Nuini+1 : end)')';
   end
   polysnum= convert2poly(strucnumerical, par);
   e(Miss - lost +1)= nan*ones(size(NM));
end
% End function regARIMA

% AUXILIARY FUNCTION
function yh= interpTF(y, u, model, nans, p)

Nu= size(u, 2); yh= y;
for i= 1 : size(nans, 2)
   nansi= nans{i};
%    if Nu> 0
%       [e, pyi]= regARIMA(yh(1 : nansi(1)-1), u(1 : nansi(1)-1, :), model, u(nansi, :), 0, [], p, 0);
%    else
      [e, pyi]= regARIMA(yh(1 : nansi(1)-1), [], model, size(nansi, 1), 0, [], p, 0);
%    end
   yh(nans{i}, 1)= pyi;
end
% End of interpTF function

% AUXILIARY FUNCTION
function [A, B, C]= poly2armax(polysnum)
% Conversion from structure to ARMAX model
%    A(B) y(t)= B1(B) u1(t) + B2 (B) u2(t)  + ... + C(B) a(t)
%    {A, C, B1, B2, ...}

N= size(polysnum, 1);
polys= num2cell(ones(1, N + 1));
for i= 1 : N
   polys{i + 1}= polysnum{i, 1};
   polys{1}= conv(polys{1}, polysnum{i, 2});
end
for i= 2 : N+1
    for j= 1 : N
        if j~= i-1; polys{i}= conv(polys{i}, polysnum{j, 2}); end
    end
end

A= polys{1};
C= polys{2};
B= [];
N= size(polys, 2);
if N> 2
   orderB= zeros(N - 2, 1);
   for i= 3 : N, orderB(i - 2)= size(polys{i}, 2); end
   B= zeros(N-2, max(orderB));
   for i= 3 : N, B(i - 2, 1:orderB(i - 2))= polys{i}; end
end
% End function poly2armax

% AUXILIARY FUNCTION
function tsi=arma2tsi(ar, ma, n)
% tsi=arma2tsi(ar, ma, n)

% Copyright (c) 2003 by Diego J. Pedregal
% Universidad Castilla-La Mancha

if nargin<3, n= 100; end

tsi= filter(ma, ar, [1;zeros(n-1, 1)]);
% End of arma2tsi function

%%%% AUXILIARY function
function H= hessian(x, varargin)
% Hessian of objective function auxregfun

npar= length(x);
H= zeros(npar); 
inc= max(1e-5, 1e-5*abs(x));
for i= 1:npar
  for j= i:npar
    bb= x; bb(i)= x(i)+inc(i); bb(j)= bb(j)+inc(j); obj1= auxregfun(bb, varargin{:});
    bb= x; bb(i)= x(i)-inc(i); bb(j)= bb(j)+inc(j); obj2= auxregfun(bb, varargin{:});
    bb= x; bb(i)= x(i)+inc(i); bb(j)= bb(j)-inc(j); obj3= auxregfun(bb, varargin{:});
    bb= x; bb(i)= x(i)-inc(i); bb(j)= bb(j)-inc(j); obj4= auxregfun(bb, varargin{:});
    if length(obj1)>1, obj1=obj1'*obj1;obj2=obj2'*obj2;
                    obj3= obj3'*obj3;obj4=obj4'*obj4;end
    H(i, j)= (obj1-obj2-obj3+obj4)/(4*inc(i)*inc(j));
  end
end
H= H+H'; H(1:npar+1:npar*npar)= H(1:npar+1:npar*npar)/2;
% End of hessian function
