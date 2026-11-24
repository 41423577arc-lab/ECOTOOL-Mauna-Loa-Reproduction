function textoutputWINDOW(table, TITLE, Wposition, TextFontSize)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 3, load testguiSETTINGS; end
if nargin< 4, load testguiSETTINGS; end

if isempty(TextFontSize), TextFontSize=12; end

if nargin< 2, TITLE= []; end
if isempty(table)
    TITLE= 'This will be the title'; 
    table= 'Here is the panel where all the text output will appear';
end

Hfigure= findall(0, 'Name', 'Text Output Window');

if isempty(Hfigure)
    figure('Name', 'Text Output Window', 'units', 'normal');
    if ~isnan(Wposition(2, 1)), set(gcf, 'position', Wposition(2, :)); end
    dispwindow(table, TITLE);
    set(findall(gcf, 'style', 'listbox'), 'fontsize', TextFontSize);
    
    H= findall(gcf, 'label', '&File');
    if ~isempty(H)
       H1 = findobj(H, 'label', 'E&xit Text Output Window');
       if isempty(H1)
          uimenu(H, 'label', 'E&xit Text Output Window', ...
             'separator', 'on', ...
             'callback', 'close(gcf)');
       end
    end
    
    H= findall(gcf, 'label', '&Edit');
	if ~isempty(H)
       H1 = findobj(H, 'label', '&Increase Font Size');
       H2 = findobj(H, 'label', '&Decrease Font Size');
       if isempty(H1)
          uimenu(H, 'label', '&Increase Font Size', ...
             'separator', 'on', ...
             'callback', ['HH= findall(gcf, ''style'', ''listbox'');' ...
                 'FS= get(HH, ''fontsize''); set(HH, ''fontsize'', min(FS+2, 24));']);
          uimenu(H, 'label', '&Decrease Font Size', ...
             'callback', ['HH= findall(gcf, ''style'', ''listbox'');' ...
                 'FS= get(HH, ''fontsize''); set(HH, ''fontsize'', max(FS-2, 10));']);
       end
	end

    H= findall(gcf, 'label', '&Help');
    if ~isempty(H)
       H1 = findobj(H, 'label', 'A&bout Text Output Window...');
       H2 = findobj(H, 'label', 'Text &Output Window Help');
       if isempty(H1)
          uimenu(H, 'label', 'A&bout Text Output Window...', ...
             'separator', 'on', ...
             'callback', 'aboutWINDOW');
          uimenu(H, 'label', 'Text &Output Window Help', ...
             'callback', 'disp(''Reset settings'')');
       end
    end
else
    figure(Hfigure);
    dispwindow(table, TITLE);
end
drawnow

