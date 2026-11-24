function NLtests(z, ncoef, Names, win, seriesval)
% NLtests   Non Linear tests based on squares
%
%    nltests(y, ncoef)
%
% INPUTS:
%   y:    (*) Vector time series data (m x T or T x m)
%   ncoef: Number of autocorrelation coefficients (1 x 1)
% 
% See Also: vtsay, varsbc2, vbds
%   

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

if nargin< 5, seriesval= 1; end

if nargin< 4, win= 0; end

if win> 0
    [z, Names, ncoef, seriesval]= auxtestGUI;
    if size(ncoef, 2)== 1, indx= 1; else, indx= 19; end
    ncoef= ncoef{indx}{1};
    out= 1;
end    

z= z.^2;
[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end
Npar= 0; s= T+2;

seriesval= min(m, seriesval(1));

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 3, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin<2, ncoef= min([38 ceil(T/4/m*2)]); end
if isempty(ncoef), ncoef=min([38 ceil(T/4/m*2)]); end

if win== 0
   if strcmp(get(gcf,'name'), 'Text Output Window')
       fig= get(0, 'CurrentFigure')-1;
       if fig== 0, figure, else, figure(fig); end
   end
   clf;
   set(gcf, 'number', 'off', 'name', 'Non-Linearity Tests Tool', 'userdata', {z, {{ncoef}}, Names}, 'toolbar', 'figure');
end

% Calculations
data= get(findall(gcf, 'label', '&Options'), 'userdata');
WIN= win;
if size(data, 1)< ncoef, win= 1; end
if win< 3
    Miss= 0; nmiss= sum(isnan(z(:, seriesval)));
    if sum(nmiss), Miss= 1;  end

    if Miss, numinc= ncoef*3/5-2; else, numinc= ncoef*2/5-2; end
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
           sacf(i)= sum(prod(find(nnans)))/(sum(nnans)-i);
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

    % Peña and Rodriguez (2002) test
    ll= (1 : ncoef)';
    rk= sqrt((T+2)./(T- ll)).*sacf;
    Rm= eye(ncoef+1); detR= zeros(ncoef, 1);
    for i= 1 : ncoef
        Rm(i, i+1 : end)= rk(1 : ncoef - i + 1)';
        Rm(i+1 : end, i)= rk(1 : ncoef - i + 1);
        detR(i)= det(Rm(1 : i+1, 1 : i+1));
        if rem(i, 5)== 0, if wwaitfor; return; end, end
    end
    Dm= -(T./(ll + 1)).*log(detR);
    pDm= 1 - gamcdf(real(Dm), 3*ll.*(ll+1)./(8*ll+4), 3*ll./(4*ll+2));
    
	wwaitfor(0);
    data= [sacf spacf seacf sepacf];
    set(findall(gcf, 'label', '&Options'), 'userdata', data);
end    % Calculations

% Plotting figure
clearscreen;
menuopt= findall(gcf, 'label', '&Options');
if ~isempty(menuopt), data= get(menuopt, 'userdata'); end
Namesi= strrep(Names(seriesval, :), ' ', '');
auxvident((1 : ncoef)', data(1 : ncoef, 1 : 2), data(1 : ncoef, 3 : 4), s, ...
        char(['Series ' Namesi ': Sample Autocorrelation Function of Squared Data'], ...
        ['Series ' Namesi ': Sample Partial Autocorrelation Function of Squared Data']));
plotw= gcf;

% Text output
if win< 3
    table= printwf([(1:ncoef)' sacf Q PQ spacf Qmt PQmt Dm pDm], [0 4], 'Lag SACF MLL P-value SPACF MT P-value PR P-value');
    i1= findstr(table(1, :), 'F')+1; i2= i1(2); i1= i1(1);
    spc= char(abs(' ')*ones(size(table, 1), 1));
    table= [table(:, 1 : i1) spc [' '; signif(sacf./seacf)] table(:, i1+1:i2) spc [' '; signif(spacf./sepacf)] table(:, i2+1 : end)];
    textoutputWINDOW(charcat(' ', '-', ' Non-Linearity Tests ', '-', ...
        ' MLL: McLeod & Li (1983) Test ', ' MT:  Monti (1994) Test ', [' PR:  Pe' char(abs('ñ')) 'a & Rodriguez (2002) Test '], ...
        '-', ' H0:  Process is Linear ', '-', [' Series ' Namesi ' '], ...
        '-', table(1, :), '-', table(2 : end, :), '-'), ...
        'Non-Linearity Tests');
    figure(plotw);
end

% Setting up Menu Series and Options
if win< 2
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu('label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          uimenu(MENU_H, 'label', Names(i, :), ...
               'callback', 'NLtests([], [], [], 2);');
       end
	end
end
MENUopt= findall(plotw, 'label', '&Options');
if WIN== 1
    if isempty(MENUopt), MENUopt= uimenu(plotw, 'label', '&Options', 'userdata', []); end
    set(MENUopt, 'callback', ['if optionsET({''Number of lags for plot [4, Inf):''}, 4, 19);' ...
      'NLtests([], [], [], 3); end']);
end
