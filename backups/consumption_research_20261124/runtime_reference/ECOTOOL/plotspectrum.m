function plotw= plotspectrum(w, I, i, j, xlog, smooth, Namesi, Namesj)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


lw= w; lI= I;
period= 'Period'; power= 'Power';
raxis= [0 pi];
% if all(xlog== [0 0])
%     lw= w; lI= I;
%     period= 'Period'; power= 'Power';
%     raxis= [0 pi];
if xlog(1)== 1
    indx= find(w== 0); w(indx)= 1;
    lw= log10(w); lw(indx)= Inf;
    period= 'Log10(Period)';
    raxis= [-1 log10(pi)];
end
if xlog(2)== 1
    lI= log10(I);
    power= 'Log10(Power)';
end

% Smoothing the spectrum
if smooth> 0
   if rem(smooth, 2)== 0, smooth= smooth + 1; end
   inc= 2/(smooth+1);
   bpoly= [(inc : inc : 1-inc) 1 (1-inc : -inc : inc)];
   bpoly= bpoly./sum(bpoly);
   lb= fix(size(bpoly, 2)/2);
   I= filter(bpoly, 1, [I; repmat(I(end), lb, size(I, 2))]);
   I= I(lb + 1 : end, :);
end

% Pintando
nw= length(w);
if i== j % Espectro real
    plot(lw, lI, 'k');
    if raxis(1)== -1, raxis(1)= v(1); end
    v= axis; axis([raxis v(3 : 4)]);
    xlabel(period), ylabel(power)
    periodaxis(raxis(1));
    titles= ['Series ' Namesi ':'];
    if smooth> 1
        titles= [titles ' Smoothed Spectrum, Triangular window (' int2str(smooth) ')'];
    else
        titles= [titles ' Periodogram'];
    end
    title(titles)
else     % Gain and squared coherence
    A= sqrt(real(I(:, 1)).^2 + imag(I(:, 1)).^2);
    G1= A./I(:, 2); G2= A./I(:, 3);
    SC= (A.^2)./(I(:, 2).*I(:, 3));
    if xlog(2)
        G1= log10(G1);
        G2= log10(G2);
        pp= 'log(Gains)';
    else
        pp= 'Gains';
    end
    % Plot con dos axis
    subplot(211)
    line(lw, G1, 'color', 'k')
    ylabel(pp)
    ax1= gca;
    ax1_pos= ax1.Position;
    if raxis(1)== -1, raxis(1)= v(1); end
    v= axis; axis([raxis v(3 : 4)]);
    periodaxis(raxis(1));
    ax2 = axes('Position',ax1_pos,...
        'YAxisLocation','right',...
        'Color','none');
    line(w, G2, 'color', 'r', 'Parent', ax2);
    ax2.YColor= 'r';
    if raxis(1)== -1, raxis(1)= v(1); end
    v= axis; axis([raxis v(3 : 4)]);
    periodaxis(raxis(1));
    title(['Gains: ' Namesj ' <- ' Namesi ' (left - black) and ' Namesi ' <- ' Namesj ' (right - red)'])
    subplot(212), plot(w, SC, 'k')
    ylabel('Coherence')
    if raxis(1)== -1, raxis(1)= v(1); end
    v= axis; axis([raxis 0 1.1]);
    periodaxis(raxis(1));
    if smooth> 1
        titles= ['. Smoothed Spectrum, Triangular window (' int2str(smooth) ')'];
    else
        titles= [];
    end
    title(['Squared Coherence: ' Namesi ' - ' Namesj titles])
    xlabel(period)
end
plotw= gcf;

% str0= ''; str1= ' Spectrum '; str2= ' (No smoothing)';
% if smooth== 0, str1= ' Periodogram '; end
% if smooth> 1, str0= 'Smoothed'; str2= [' (Triangular window of length ' int2str(smooth) ')']; end
% title(['Series ' strlabel ': ' str0 str1 str2]);



% Auxiliary function
function periodaxis(logon)

if nargin< 1, logon= 0; end

if logon== 0
    set(gca, 'xtick', [0 2*pi./[12 6 4 3 2.4 2]]);
    set(gca, 'xticklabel', char('Inf', ' 12', ' 6 ', ' 4 ', ' 3 ', '2.4', ' 2 '));
else
    set(gca, 'xtick', [logon log10(2*pi./[12 6 4 3 2.4 2])]);
    set(gca, 'xticklabel', char('Inf', ' 12', ' 6 ', ' 4 ', ' 3 ', '2.4', ' 2 '));
end