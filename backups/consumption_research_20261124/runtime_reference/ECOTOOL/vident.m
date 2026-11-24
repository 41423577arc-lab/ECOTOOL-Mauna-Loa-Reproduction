function vident(z, ncoef, s, Npar, Names, win, seriesval)
% vident   Summary descriptive statistics
%
%    vident(y, ncoef, s, Npar)
%
% INPUTS:
%   y:     (*) Vector time series data (m x T or T x m)
%   ncoef: Number of autocorrelation coefficients (1 x 1)
%   s:     Seasonal period for plots (1 x 1)
%   Npar:  Number of estimated parameters 
%          (if z is a set of residuals, 1 x 1)
% 
% See Also: vident2, varsbc, vgranger

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
% win= 3: running from Options menu

if nargin< 7, seriesval= 1; end

if nargin< 6, win= 0; end

if win> 0
    [z, Names, ncoef, seriesval]= auxtestGUI;
    if size(ncoef, 2)== 1, indx= 1; s= ncoef{1}{2}; else, indx= 9; s= ncoef{1}{1}; end
    Npar= ncoef{indx}{3}; ncoef= ncoef{indx}{1};
    out= 1;
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end

seriesval= min(m, seriesval(1));

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 5, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

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
%       current_fig= get(0, 'CurrentFigure');
%       fig= current_fig.Number-1;
%       if fig== 0, figure, else, figure(fig); end
%   end
   clf;
   set(gcf, 'name', 'Vector Identification Tool', 'userdata', {z, {{ncoef, s, Npar}}, Names}, 'toolbar', 'figure');
end

% Calculations
Hopt= findall(gcf, 'label', '&Options');
if win< 2, set(Hopt, 'userdata', []); end
data= get(Hopt, 'userdata');
Npar1= Npar;
if ~isempty(data)
    Npar1= data{2}; data= data{1};
    set(Hopt, 'userdata', {data, Npar});
end
WIN= win;
if size(data, 1)< ncoef, win= 1; end
if win< 3
    Miss= 0; nmiss= sum(isnan(z(:, seriesval)));
    if sum(nmiss), Miss= 1;  end

    if Miss, numinc= ncoef*2/5-1; else, numinc= ncoef/5-1; end
    wwaitfor(numinc);
    
    sacf= zeros(ncoef, 1); seacf= sacf; spacf= sacf; sepacf= sacf; Q= sacf; PQ= sacf;
    zs= transform(z(:, seriesval));
	if ~Miss
       Nw= 2.^ceil(log(2*T)/log(2));
       spec= abs(fft([zs; zeros(Nw-T, 1)], Nw)).^2;
       fftspec= fft(spec, Nw);
       fftspec= real(fftspec(1: ncoef+1))/T/length(fftspec);
       sacf= fftspec(2:length(fftspec))/fftspec(1);
	else
       for i= 1 : ncoef
           prod= (zs(i+1:T).*zs(1:T-i));
           nnans= (~isnan(prod));
           sacf(i)= sum(prod(find(nnans)))/(sum(nnans));
           if rem(i, 5)== 0, if wwaitfor; return; end, end
       end
	end
    seacf(1)= 1/sqrt(T);
	seacf(2 : ncoef)= sqrt((1+2*cumsum(sacf(1:ncoef-1).^2))/T); 
	Q= T*(T+2)*cumsum((sacf.^2)./(T-(1:ncoef)')); 
	gl= (1 : ncoef)' - Npar; ind= find(gl<= 0); gl(ind)= ones(length(ind), 1); 
	PQ= 1-chi2cdf(Q, gl); 
	PQ(ind)= nan*ones(size(ind));
	
	spacf= sacf;
	fi= zeros(ncoef, 1);
	fi(1)= sacf(1);
	for i= 1 : ncoef-1
        fi(i+1)= (sacf(i+1)-(fi(1 : i))'*(flipud(sacf(1 : i))))/(1-fi'*sacf);
        spacf(i+1)= fi(i+1);
        fi(1 : i)= fi(1 : i)-fi(i+1)*(flipud(fi(1 : i)));
        if rem(i, 5)== 0, if wwaitfor; return; end, end
	end
    sepacf= ones(ncoef, 1)*seacf(1);

    % Monti (1994) test
	Qmt= T*(T+2)*cumsum((spacf.^2)./(T-(1:ncoef)')); 
	PQmt= 1-chi2cdf(Qmt, gl); 
	PQmt(ind)= nan*ones(size(ind));

	wwaitfor(0);
    data= [sacf spacf seacf sepacf];
    set(findall(gcf, 'label', '&Options'), 'userdata', {data, Npar});
end    % Calculations

if (win== 3 & Npar~= Npar1)
  	Q= T*(T+2)*cumsum((data(1:ncoef,1).^2)./(T-(1:ncoef)')); 
	gl= (1 : ncoef)' - Npar; ind= find(gl<= 0); gl(ind)= ones(length(ind), 1); 
	PQ= 1-chi2cdf(Q, gl); 
	PQ(ind)= nan*ones(size(ind));
	Qmt= T*(T+2)*cumsum((data(1:ncoef, 2).^2)./(T-(1:ncoef)')); 
	PQmt= 1-chi2cdf(Qmt, gl); 
	PQmt(ind)= nan*ones(size(ind));
end

% Plotting figure
clearscreen;
menuopt= findall(gcf, 'label', '&Options');
if ~isempty(menuopt), data= get(menuopt, 'userdata'); Npar= data{2}; data= data{1}; end
Namesi= strrep(Names(seriesval, :), ' ', '');
auxvident((1 : ncoef)', data(1 : ncoef, 1 : 2), data(1 : ncoef, 3 : 4), s, ...
        char(['Series ' Namesi ': Univariate Sample Autocorrelation Function'], ...
        ['Series ' Namesi ': Univariate Sample Partial Autocorrelation Function']));
plotw= gcf;
    
if (win< 3 | Npar~= Npar1)
    tt= (1 : ncoef)';
    table= printwf([tt data(tt, 1) Q PQ data(tt, 2) Qmt PQmt], [0 4], 'Lag SACF LB P-value SPACF MT P-value');
    i1= findstr(table(1, :), 'F')+1; i2= i1(2); i1= i1(1);
    spc= char(abs(' ')*ones(size(table, 1), 1));
    table= [table(:, 1 : i1) spc [' '; signif(data(tt, 1)./data(tt, 3))] table(:, i1+1:i2) spc [' '; signif(data(tt, 2)./data(tt, 4))] table(:, i2+1 : end)];
    textoutputWINDOW(charcat(' ', '-', ' Univariate Sample ACF and PACF ', '-', ...
        ' LB: Ljung-Box Test ', ' MT: Monti (1994) Test ', '-', ' H0: Process is white noise ', '-', [' Series ' Namesi ' '], ...
        '-', table(1, :), '-', table(2 : end, :), '-'), ...
        'Sample Autocorrelation and Partial Autocorrelation Functions');
    figure(plotw)
end

% Setting up Menu Series and Options
if win< 2
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu(plotw, 'label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
               'callback', 'vident([], [], [], [], [], 2);');
       end
	end
end
MENUopt= findall(plotw, 'label', '&Options');
if WIN== 1
     if isempty(MENUopt), MENUopt= uimenu(plotw, 'label', '&Options', 'userdata', []); end
     set(MENUopt, 'callback', ['if optionsET({''Number of lags for plot [4, Inf):'',' ...
       '''Enter seasonal period [2, Inf):'', ''Number of model parameters: [0, Inf):''}, ' ...
       '[4; 2; 0], [9 1; 1 1; 9 3]);' ...
       'vident([], [], [], [], [], 3); end']);
end

