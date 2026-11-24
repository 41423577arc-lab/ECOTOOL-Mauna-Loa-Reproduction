function out = acft(MAP, ARP, ncoef, s)
% acft Theoretical Autocorrelations for ARMA(p, q) processes
%
%   tab= acft(MApoly, ARpoly, ncoef, s)
%              Th(B)                                                     
%       y(t)= ------- a(t)                                               
%              Phi(B)                                                    
%                                                                        
%  INPUTS:                                                               
%    MApoly:  MA polynomial ([1 th1  th2 ...  thq]).                     
%    ARpoly:  AR polynomial ([1 phi1 phi2 ... phip]).                    
%    ncoef:   Number of ACF and PACF coefficients (38).                  
%    s:       Samples in the season (12).                                
%                                                                        
%  OUTPUT:                                                               
%    tab:     [lag, ACF, PACF].
%
%  Examples:
%    acft(1, [1 -0.8]);
%    acft(conv([1 0.8], [1 zeros(1, 11) -0.8]), [1 -0.8]);

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% Checking inputs
if nargin<4, s= 12; end
if isempty(s), s= 12; end

if nargin<3, ncoef= 38; end
if isempty(ncoef), ncoef= 38; end

if nargin<2, ARP= 1; end
if isempty(ARP), ARP= 1; end

if isempty(MAP), MAP= 1; end

if any(abs(roots(ARP))>=1), error('Modelo no estacionario'); end
if any(abs(roots(MAP))>=1), error('Modelo no invertible'); end

[rAR, cAR]= size(ARP);
[rMA, cMA]= size(MAP);
if rAR>cAR, ARP= ARP'; end
if rMA>cMA, MAP= MAP'; end
salida= ones(ncoef, 3); salida(:, 1)= (1:ncoef)';

% SACF coefficients estimation
q= 250; MAPi= ones(1, q);
if size(ARP, 2)>1
   while MAPi(q)> 1e-4
      q= q+100;
      MAPi= arma2tsi(ARP, MAP, q)';
   end
   MAP= MAPi;
end
if size(MAP, 2)<q, MAP= [MAP zeros(1, q-size(MAP, 2))]; end

gam0= MAP*MAP';
for i=1:ncoef
   salida(i, 2)= (MAP(1:q-i)*MAP(i+1:q)')/gam0;
end

% SPACF Coefficients  
fi= zeros(ncoef, 1); 	
fi(1)= salida(1, 2); salida(1, 3)= fi(1); 
for p= 1:ncoef-1
  fi(p+1)= (salida(p+1, 2)-(fi(1:p))'*(flipud(salida(1:p, 2))))/(1-fi'*salida(:, 2)); 
  salida(p+1, 3)= fi(p+1); 
  fi(1:p)= fi(1:p)-fi(p+1)*(flipud(fi(1:p)));
end

texto= printwf(salida, [0 3], 'k SACF SPACF');
textoutputWINDOW(texto, 'Theoretical ACF and PACF');
if strcmp(get(gcf,'name'), 'Text Output Window')
    figs= findobj('type', 'figure');
    if length(figs)> 1
        figure(figs(2))
    else
        figure
    end
end
auxuident((1:ncoef)', salida(:, 2:3), zeros(ncoef, 2), s, 2);

[amp, w]= freqz(MAP, ARP, 300);
subplot(212)
semilogy(w, amp.*conj(amp), 'k')
title('Theoretical power spectrum')
ylabel('logPower'); xlabel('Period');
v= axis; axis([0 pi v(3:4)]);
set(gca, 'xtick', [0 2*pi./[12./(1:6)]]);
axisx= get(gca, 'xtick');
set(gca, 'xticklabel', [Inf 2*pi./(axisx(2 : end))]);
out = salida;
