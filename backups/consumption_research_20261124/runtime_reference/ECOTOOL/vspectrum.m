function [I, w]= vspectrum(z, smooth, nw, xlog, Names, win, seriesval)
% vspectrum   Spectrum
%
%    vspectrum(y, smooth, nfreq, xlog)
%
% INPUTS:
%   y:      (*) Vector time series data (m x T or T x m)
%   smooth: Length of smoothing truncating window (1 x 1, default is 1)
%   nfreq:  Number of frequencies to estimate the spectrum 
%           (1 x 1, use 0 or T/2 for periodogram frequencies)
%   xlog:   Frequency and Power axis log on/off (1 x 2)
%           [0 0]: linear scale for both axes
%           [1 0]: log scale for frequency axis
%           [0 1]: log scale for power axis
%           [1 1]: log scale for both axes
% 
% See Also: vcumperiod, varspectrum

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
    [z, Names, opts, seriesval]= auxtestGUI;
    if size(opts, 2)== 1, indx= 1; else, indx= 24; end
    smooth= opts{indx}{1}; nw= opts{indx}{2}; xlog= opts{indx}{3};
end    

[T, m]= size(z);
if T< m, z= z'; [T, m]= size(z); end
seriesval= min(seriesval, m);

defNames= char([char(abs('#')*ones(m, 1)) int2str((1 : m)')], 'All');
if nargin< 5, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m+1, Names= Names(1 : m+1, :); end
if sNames< m+1, Names= char(Names, defNames(sNames + 1 : end, :)); end

if nargin< 4, xlog= [0 1]; end
if isempty(xlog), xlog= [0 1]; end

if nargin<2, smooth= 1; end
if isempty(smooth), smooth= 1; end
smooth= min(floor(T/2), smooth);
smooth= max(smooth, 1);

if win== 0
   if strcmp(get(gcf,'name'), 'Text Output Window')
       figs= findobj(0, 'type', 'figure');
       fig= size(figs, 1);
       if strcmp(get(fig,'name'), 'Text Output Window') && fig> 1
           fig= fig-1;
       end
       if fig== 1, figure, else, figure(fig); end
   end
%    if strcmp(get(gcf,'name'), 'Text Output Window')
%        fig= get(0, 'CurrentFigure')-1;
%        if fig== 0, figure, else, figure(fig); end
%    end
   clf;
   set(gcf, 'number', 'off', 'name', 'Vector Spectrum tool', 'userdata', {z, {{smooth, nw, xlog}}, Names}, 'toolbar', 'figure');
end

% Calculations
Hopt= findall(gcf, 'label', 'Spect&rum');
if win< 2, set(Hopt, 'userdata', []); end
data= get(Hopt, 'userdata');
if ~isempty(data)
    win= 2;
    I= data{1};
    w= data{2};
end
% WIN= win;
% if (size(data, 1)< ncoef*m | type1~= type), win= 1; end
if win< 2
%     [I, w]= mspectrum(z-repmat(nanmean(z), T, 1));
    [I, w]= mspectrum(z);
    w= w*2*pi;
    set(findall(gcf, 'label', 'Spect&rum'), 'userdata', {I, w});
%     nw= floor(T/2)+1;
%     if nargin<3, nw= []; end
%     if isempty(nw)
%        w= 2*pi*(0 : nw-1)'/T;
%     else
%        if nw== 0
%           w= 2*pi*(0 : nw-1)'/T;
%        else
%           if nw< 10, nw= floor(T/2); end
%           w= (0 : pi/nw : pi-pi/nw)';
%        end
%     end
% %     w= w(:);
% %     nw= size(w, 1)-1;
% 
%     miss= 0;
%     if any(isnan(sum(z')))
%         miss= 1;
%     end
% %     t=(1:T);
% %     nw= fix(T/2)+1;
% %     w= (2*pi*(t(1:nw)-1))/T;
%     I= nan(m, m, nw);
%     if miss
%         wwaitfor(fix((nw+1)/40));
%         for j=1:nw
%             if rem(j, 40)== 0, if wwaitfor; break; end, end
%             I1= sum(x.*repmat(exp(-sqrt(-1)*w(j)*t),m ,1), 2);
%             I(:, :, j)= I1*I1';   % I1'= conj(I1')
%         end
%         wwaitfor(0);
%     else
%         y= fft(z)';
%         if m== 1
%             y= fft(x); I= y(1:nw).*conj(y(1:nw)); 
%         else
%             for j=1:nw
%                 I(:, :, j)= y(:, j)*y(:, j)';
%             end
%         end
%     end
%     for i= 1:m
%         I(i, i, :)= real(I(i, i, :));
%     end
% % %     cumP= nan*ones(T2+1, 1);
% % %     t= (1 : T)'; Td2= 2/T;
% % %     Miss= isnan(z(:, seriesval));
% % %     if sum(Miss)
% % %        wwaitfor(fix((T2+1)/40));
% % %        for j= 1 : T2+1
% % %           if rem(j, 40)== 0, if wwaitfor; break; end, end
% % %           aj= nansum(z(:, seriesval).*cos(freq(j)*t));
% % %           bj= nansum(z(:, seriesval).*sin(freq(j)*t));
% % %           cumP(j)= Td2*(aj.^2 + bj.^2);
% % %        end
% % %        wwaitfor(0);
% % %     else
% % %        fftz= fft(z(:, seriesval), 2*T2+2); cumP= fftz.*conj(fftz)/T*2;
% % %        cumP= cumP(1 : T2+1);
% % %     end
% % % 
% % %     if smooth> 0
% % %        if rem(smooth, 2)== 0, smooth= smooth + 1; end
% % %        inc= 2/(smooth+1);
% % %        bpoly= [(inc : inc : 1-inc) 1 (1-inc : -inc : inc)];
% % %        bpoly= bpoly./sum(bpoly);
% % %        lb= fix(size(bpoly, 2)/2);
% % %        cumP= filter(bpoly, 1, [cumP; repmat(cumP(end), lb, 1)]);
% % %        cumP= cumP(lb + 1 : end);
% % %     end
end

% Plotting figure
clearscreen;
if size(seriesval, 2)> 1
    i= seriesval(1); j= seriesval(2);
else
    i= seriesval; j= i;
end
% strlabel= strrep(Names(seriesval, :), ' ', '');
if i== j
    Namesi= strrep(Names(i, :), ' ', '');
    plotw= plotspectrum(w, permute(I(i, i, :), [3 1 2]), i, j, xlog, smooth, Namesi, Namesi);
else
    Namesi= strrep(Names(i, :), ' ', '');
    Namesj= strrep(Names(j, :), ' ', '');
    plotw= plotspectrum(w, [permute(I(i, j, :), [3 1 2]) ...
                     permute(I(i, i, :), [3 1 2]) ...
                     permute(I(j, j, :), [3 1 2])], i, j, xlog, smooth, Namesi, Namesj);
end
% if all(xlog== [0 0])
%     plot(w, I, 'k');
%     v= axis; axis([0 pi v(3 : 4)]);
%     xlabel('Period'), ylabel('Power')
%     periodaxis;
% elseif all(xlog== [0 1])
%     plot(w, log10(I), 'k');
%     v= axis; axis([0 pi v(3 : 4)]);
%     xlabel('Period'), ylabel('Log10(Power)')
%     periodaxis;
% elseif all(xlog== [1 0])
%     indx= find(w== 0); w(indx)= 1;
%     w= log10(w); w(indx)= Inf;
%     plot(w, I, 'k');
%     v= axis; axis([v(1) log10(pi) v(3 : 4)]);
%     xlabel('log10(Period)'), ylabel('Power')
%     periodaxis(v(1));
% elseif all(xlog== [1 1])
%     indx= find(w== 0); w(indx)= 1;
%     w= log10(w); w(indx)= Inf;
%     plot(w, log10(I), 'k');
%     v= axis; axis([v(1) log10(pi) v(3 : 4)]);
%     xlabel('log10(Period)'), ylabel('log10(Power)')
%     periodaxis(v(1));
% end
% str0= ''; str1= ' Spectrum '; str2= ' (No smoothing)';
% if nw== 0, str1= ' Periodogram '; end
% if smooth> 1, str0= 'Smoothed'; str2= [' (Triangular window of length ' int2str(smooth) ')']; end
% title(['Series ' strlabel ': ' str0 str1 str2]);
% plotw= gcf;
    
% Setting up Menu Series and Options
if win< 2
	if m>1
       MENU_H= findall(plotw, 'label', 'Se&ries');
       if isempty(MENU_H), MENU_H= uimenu(plotw, 'label', 'Se&ries'); end
       delete(get(MENU_H, 'children'));
%        for i= 1:m
%           uimenu(MENU_H, 'label', Names(i, :), ...
%                'callback', 'vspectrum([], [], [], [], [], 1);');
%        end
       for i= 1:m
          Hmenu= uimenu(MENU_H, 'label', Names(i, :));
          for j= i : m
              uimenu(Hmenu, 'label', [Names(i, :) ' - ' Names(j, :)], ...
                  'callback', 'vspectrum([], [], [], [], [], 2);');
          end
       end      
	end
end
MENUopt= findall(plotw, 'label', '&Options');
if win== 1
     if isempty(MENUopt), MENUopt= uimenu(plotw, 'label', '&Options', 'userdata', []); end
     set(MENUopt, 'callback', ['if optionsET({''Truncation for Triangular spectral window [1, N/4):'',' ...
       '''Number of divisions in frequency axis (0 or N/2 for Periodogram):'', ' ...
       '''Logaritmic or Linear Period and Power axis ([1/0 1/0]):''}, ' ...
       '[0; 0; 0], [24 1;24 2; 24 3]);' ...
       'vspectrum([], [], [], [], [], 3); end']);
end


% % Auxiliary function
% function periodaxis(logon)
% 
% if nargin< 1, logon= 0; end
% 
% if logon== 0
%     set(gca, 'xtick', [0 2*pi./[12 6 4 3 2.4 2]]);
%     set(gca, 'xticklabel', char('Inf', ' 12', ' 6 ', ' 4 ', ' 3 ', '2.4', ' 2 '));
% else
%     set(gca, 'xtick', [logon log10(2*pi./[12 6 4 3 2.4 2])]);
%     set(gca, 'xticklabel', char('Inf', ' 12', ' 6 ', ' 4 ', ' 3 ', '2.4', ' 2 '));
% end
