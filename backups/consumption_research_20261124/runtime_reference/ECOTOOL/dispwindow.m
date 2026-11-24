function dispwindow(table, TITLE)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 2, TITLE= []; end
if isempty(TITLE)
   position= [0 0 1 1];
else
   position= [0 0 1 0.95; 0 0.95 1 0.05];
end

% Print title (if any)
Hlistbox= findall(gcf, 'style', 'listbox');
Htitle= findall(gcf, 'style', 'text');
if isempty(Hlistbox)
   if ~isempty(TITLE)
      uicontrol(gcf, 'style', 'text', ...
         'units', 'normalized', ...
         'position', position(2, :), ...
         'string', TITLE, ...
         'fontweight', 'bold', ...
         'fontsize', 12, ...
         'HorizontalAlignment', 'center');
   end

% Print table in figure
   uicontrol(gcf, 'style', 'listbox', ...
      'units', 'normalized', ...
      'position', position(1, :), ...
      'background', 'w', ...
      'fontname', 'courier', ...
      'fontsize', 12, ...
      'HorizontalAlignment','left', ...
      'Tag', 'Listbox', ...
      'Value', 1, ...
      'string', table);
else
    set(Hlistbox, 'Value', 1, 'string', table);
    if ~isempty(Htitle)
        set(Htitle, 'string', TITLE);
    end
end

% Add 'Copy Text' and 'Send to Command Window' to Edit menu
H= findall(gcf, 'label', '&Edit');
if ~isempty(H)
   H1 = findobj(H, 'label', 'Copy Te&xt to Clipboard');
   H2 = findobj(H, 'label', 'Send to Command &Window');
   if isempty(H1)
      uimenu(H, 'label', 'Copy Te&xt to Clipboard', ...
         'separator', 'on', ...
         'callback', 'copyTEXT');
      uimenu(H, 'label', 'Send to Command &Window', ...
         'callback', ['disp('' ''); disp(get(findall(gcf, ''style'', ''text''), ''string''));' ...
         'disp(get(findall(gcf, ''style'', ''listbox''), ''string''));']);
   end
end
