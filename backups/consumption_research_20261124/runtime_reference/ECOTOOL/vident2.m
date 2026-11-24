function vident2(z, ncoef, s, Npar, type, Names, win, seriesval)
% vident2   Multivariate sample autocorrelation functions
%
%    vident2(y, ncoef, s, Npar)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   ncoef: Number of autocorrelation coefficients (1 x 1)
%   s:     Seasonal period for plots (1 x 1)
%   Npar:  Number of estimated parameters (if z is a set of residuals,  1 x 1)
% 
% See Also: vident, varsbc, vgranger

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


% win= 0: running independently
% win= 1: running from testtool
% win= 2: running from Series menu

if nargin< 8, seriesval= 1; end

if nargin< 7, win= 0; end

if win> 0
    [z, Names, ncoef, seriesval]= auxtestGUI;
    if size(ncoef, 2)== 1, indx= 1; s= ncoef{1}{2}; else, indx= 9; s= ncoef{1}{1}; end
    Npar= ncoef{indx}{3}; type= ncoef{indx}{4}; ncoef= ncoef{indx}{1};
    out= 1;
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end

if size(seriesval, 2)== 1, seriesval= min(m, seriesval); end

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 6, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 5, type= 0; end   % Partial autorregression
if nargin< 4, Npar= 0; end
if isempty(Npar), Npar= 0; end

if nargin<3, s= 12; end
if isempty(s), s= 12; end

if nargin<2, ncoef= min([38 ceil(T/4/m*2)]); end
if isempty(ncoef), ncoef=min([38 ceil(T/4/m*2)]); end
ncoef= min(ncoef, T-5);

if win== 0
   if strcmp(get(gcf,'name'), 'Text Output Window')
       figs= findobj(0, 'type', 'figure');
       fig= size(figs, 1);
       if strcmp(get(fig,'name'), 'Text Output Window') && fig> 1
           fig= fig-1;
       end
       if fig== 1, figure, else, figure(fig); end
   end
%   if strcmp(get(gcf,'name'), 'Text Output Window')
%       fig= get(0, 'CurrentFigure')-1;
%       if fig== 0, figure, else, figure(fig); end
%   end
   clf;
   set(gcf, 'name', 'Vector Identification Tool', 'userdata', {z, {{ncoef, s, Npar, type}}, Names}, 'toolbar', 'figure');
end

% Calculations
Hopt= findall(gcf, 'label', '&Options');
if isempty(Hopt), Hopt= uimenu(gcf, 'label', '&Options'); end
if win< 2, set(Hopt, 'userdata', []); end
data= get(Hopt, 'userdata');
Npar1= Npar; type1= type;
if ~isempty(data)
    Npar1= data{2}; stats= data{3}; type1= data{4}; data= data{1};
    set(Hopt, 'userdata', {data, Npar, stats, type});
end
WIN= win;
if (size(data, 1)< ncoef*m | type1~= type), win= 1; end
if win< 2
	ncoef= min([ncoef T-3]); 
	sacf= zeros(ncoef*m, m);    % Autocorrelation matrices
	seacf= sacf;                % Standard error of autocorrelation matrices
	spacf= nan*ones(ncoef*m, m); % Partial autorregression matrices
	sepacf= spacf;              % Standard error of spacf
	Miss= 0; nmiss= sum(isnan(z));
	if sum(nmiss), Miss= 1;  end

    if Miss, numinc= ncoef/5+(2-type)*ncoef-1; else, numinc= (2-type)*ncoef; end
    wwaitfor(numinc);
    
    zs= transform(z);
	z= z-ones(T, 1)*nanmean(z);
	detSa= det(z'*z/T);
	Q= 0; cumtr= 0; cancel= 0;
	AICS= nan*ones(ncoef, 1); SBCS= AICS; CHIS= AICS; SIGMA= AICS; PQ= AICS;
	seacf(1:m, :)= 1/sqrt(T)*ones(m);
	sacf0= nancov(zs); seacf0= seacf(1:m, 1:m);
	
   if Miss
      for i= 1:ncoef
         indx = (i-1)*m+1:i*m;
         [sacfi, nnans]= nanprod(zs(i+1:T, :)', zs(1:T-i, :));
         sacf(indx, :)= sacfi./(nnans);
         if rem(i, 5)== 0, if wwaitfor; break; end, end
      end
   else
      Nw= 2.^ceil(log(2*T)/log(2)); ls= size(sacf, 1);
      for i= 1:m
         for j= i:m
            specx= fft([z(:, i); zeros(Nw-T, 1)], Nw);
            specy= fft([z(:, j); zeros(Nw-T, 1)], Nw);
            specxy= specy.*conj(specx);
            covxy= real(fft(specxy, Nw))/length(specy);
            den= sqrt(z(:, i)'*z(: ,i))*sqrt(z(:, j)'*z(:, j));
            sacf(j : m : ls, i)= covxy(Nw:-1:Nw-ncoef+1)./den;
            sacf(i : m : ls, j)= covxy(2:ncoef+1)./den;
        end
      end
   end
   t= 1./sqrt(T-abs((1 : ncoef)'));
   seacf= kron(t, ones(m));
	
   cumtr= 0; Cancel= 1;
   if type== 0
       sepacf= repmat(1./sqrt(T), ncoef*m, m);
       spacf(1 : m, :)= sacf(1 : m, :);
   end
   for i= 1 : ncoef
       if Cancel
           [P, seP, Sigma, AIC, SBC, u]= mVAR(z, (1:i), 1);
           if type== 1
% Partial Autorregression matrices for any m
               indx = (i-1)*m+1 : i*m;
               spacf(indx, :)= P(indx, :)';
               sepacf(indx, :)= seP(indx, :)';
           elseif i< ncoef
% Partial Lag Correlation matrices
               indx = i*m+1 : (i+1)*m;
               if wwaitfor; Cancel= 0; end
               [a, aa, b, bb, bbb, v]= mVAR(z, (1:i), 1, 1);
               CORR= nancorr([u(size(u, 1)-size(v, 1)+1 : end, :) v]);
               spacf(indx, :)= CORR(1 : m, m+1 : end);
           end
% Diagnostics
           AICS(i)= AIC;
           SBCS(i)= SBC;
           detS= det(Sigma);
           CHIS(i)= -(T-i-1-0.5-m*i)*log(detS/detSa);
           SIGMA(i)= det(Sigma);
           detSa= detS;
           if wwaitfor; Cancel= 0; end
       end
       indx = (i-1)*m+1 : i*m;
       cumtr= cumtr + trace(sacf(indx, :)'*sacf(indx, :));
       Q= T*cumtr+m*m*i*(i+1)/2/T;
       if i> Npar, PQ(i)= 1-chi2cdf(Q, m*m*(i-Npar)); end
    end
	PCHIS= 1-chi2cdf(CHIS, m*m);
    wwaitfor(0);
    data= [[sacf0 sacf0 seacf0 seacf0]; [sacf spacf seacf sepacf]];
    stats= [AICS SBCS CHIS PCHIS PQ SIGMA];
    set(findall(gcf, 'label', '&Options'), 'userdata', {data, Npar, stats, type});
end    % Calculations

if (win== 3 & Npar~= Npar1)
   cumtr= 0; PQ= repmat(nan, ncoef, 1);
   for i= 1 : ncoef
      indx = i*m+1:(i+1)*m;
      cumtr= cumtr + trace(data(indx, 1 : m)'*data(indx, 1 : m));
      Q= T*cumtr+m*m*i*(i+1)/2/T;
     if i> Npar, PQ(i)= 1-chi2cdf(Q, m*m*(i-Npar)); end
   end
   data= get(Hopt, 'userdata');
   stats= data{3}; stats(1:ncoef, 5)= PQ;
   set(Hopt, 'userdata', {data{1}, data{2}, stats, type});
end

% Plotting figure
clearscreen;
if type== 1, STR= 'Partial Autoregression'; else, STR= 'Partial Lag Autocorrelation'; end
%menuopt= findall(gcf, 'label', '&Options');
if ~isempty(Hopt), data= get(Hopt, 'userdata'); stats= data{3}; Npar= data{2}; type= data{4}; data= data{1}; end
if size(seriesval, 2)> 1
    i= seriesval(1); j= seriesval(2);
else
    i= seriesval; j= i;
end
if i== j   % SACF
    Namesi= strrep(Names(i, :), ' ', '');
    auxvident((1 : ncoef)', data(i+m : m : m*ncoef+m, [i i+m]), data(i+m : m : m*ncoef+m, [i+2*m i+3*m]), s, ...
            char(['Series ' Namesi ': Multivariate Sample Autocorrelation Function'], ...
            ['Series ' Namesi ': Multivariate Sample ' STR ' Function']));
else       % SCCF
    Namesi= strrep(Names(i, :), ' ', '');
    Namesj= strrep(Names(j, :), ' ', '');
    lab1= ['  CCF between ' Namesi '(t) and ' Namesj '(t-k)                                  CCF between ' Namesi '(t-k) and ' Namesj '(t)'];
    lab2= [' PCCF between ' Namesi '(t) and ' Namesj '(t-k)                                 PCCF between ' Namesi '(t-k) and ' Namesj '(t)'];
    auxvident((-ncoef : ncoef)', [flipud(data(i+m : m : m*ncoef+m, [j j+m])); repmat(data(i, j), 1, 2); data(j+m : m : m*ncoef+m, [i i+m])], ...
            [flipud(data(i+m : m : m*ncoef+m, [j+2*m j+3*m])); repmat(data(i, 2*m+j), 1, 2); data(j+m : m : m*ncoef+m, [i+2*m i+3*m])], ...
            s, char(lab1, lab2));
end
plotw= gcf;

% Text output
if (win< 2 | Npar~= Npar1)
    tt= (m+1 : ncoef*m+m)';
    divacf = data(tt, 1 : m)./data(tt, m*2+1 : 3*m);
	divpacf = data(tt, m+1 : 2*m)./data(tt, 3*m+1 : 4*m);
    ind= find(isnan(divpacf)); divpacf(ind)= zeros(size(ind));
	divacfC = signif(divacf);
	divpacfC = signif(divpacf);
    
    dec= max(2, 7-m);
    spc= char(repmat(abs(' | '), m*ncoef, 1));
    table1= charcat('k= 0 ', [signif(data(1 : m, 1 : m)./data(1 : m, 2*m+1 : 3*m)) spc(1 : m, :) signif(zeros(m)) spc(1 : m, :) printwf(data(1 : m, 1 : m), dec)], ' ', ...
        [divacfC spc divpacfC spc printwf(data(m+1 : ncoef*m+m, 1 : m), dec) spc printwf(data(m+1 : ncoef*m+m, m+1 : 2*m), dec)]);
    table= table1(1 : m+2, :);
    header= printwf([(1:ncoef)' stats(1 : ncoef, :)], [0 4]);
    indx= findstr(header(1, :),' ');
    indx= [2 indx(find(diff(indx)>1)+1) size(header, 2)];
    header1= [repmat('k=', ncoef, 1) header(:, indx(1):indx(2)) repmat(' AIC=', ncoef, 1) header(:, indx(2)+1:indx(3)) ...
        repmat(' SBC=', ncoef, 1) header(:, indx(3)+1:indx(4)) repmat(' Chi=', ncoef, 1) header(:, indx(4)+1:indx(5)) ...
        repmat(' P-Chi=', ncoef, 1) header(:, indx(5)+1:indx(6))];
    header2= [repmat('       P-QTest=', ncoef, 1) header(:, indx(6)+1:indx(7)) ...
        repmat(' |Sigma|=', ncoef, 1) header(:, indx(7)+1:indx(8))];
    for j= 1 : ncoef
        indx= (j*m+3 : j*m+m+2)';
        table= charcat(table, header1(j, :), header2(j, :), table1(indx, :), ' ');
    end
    textoutputWINDOW(charcat(' ', '-' , [' Multivariate Sample Autocorrelation and ' STR ' Functions '], ...
        '-', table), ['Multivariate Sample Autocorrelation and ' STR ' Functions']);
    figure(plotw);
end

% Setting up Menu Series and Options
if win< 2
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu(plotw, 'label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          Hmenu= uimenu(MENU_H, 'label', Names(i, :));
          for j= i : m
              uimenu(Hmenu, 'label', [Names(i, :) ' - ' Names(j, :)], ...
                  'callback', 'vident2([], [], [], [], [], [], 2);');
          end
       end      
	end
end
MENUopt= findall(plotw, 'label', '&Options');
if WIN< 2
    if isempty(MENUopt), MENUopt= uimenu(plotw, 'label', '&Options', 'userdata', []); end
    set(MENUopt, 'callback', ['if optionsET({''Number of lags for plot [4, Inf):'',' ...
      '''Enter seasonal period [2, Inf):'', ''Number of model parameters: [0, Inf):'',' ...
      '''Partial Autorregressions or Partial Lag Autocorrelations (1/0):''}, ' ...
      '[4; 2; 0; 0], [9 1; 1 1; 9 3; 9 4]);' ...
      'vident2([], [], [], [], [], [], 3); end']);
   if WIN== 0, set(MENUopt, 'visible', 'off'); end
end

