function [Z, Names, options, seriesval, h_series, e_handle, value, b_handles]= auxtestGUI
% Auxiliar function of testTOOL

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin== 0; s= []; end

figh= gcf;
if strcmp(get(figh, 'name'), 'Text Output Window')
    figs= get(0, 'children');
    figh= figs(2);  %get(0, 'CurrentFigure')-1;
end

hh= findall(0, 'name', 'Text Output Window');
if ~isempty(hh)
    delete(findall(hh, 'label', '&Options'));
end

seriesval= [];
h_series= findobj(figh, 'label', 'Se&ries');
if ~isempty(h_series), seriesval= get(h_series, 'userdata'); end
if isempty(seriesval), seriesval= 1; end

Menu= get(gcbo, 'parent');
if Menu~= figh
    if ~strcmp(get(Menu, 'type'), 'figure')
		if strcmp(get(Menu, 'label'), 'Se&ries')
            seriesval= get(gcbo, 'position');
            set(Menu, 'userdata', seriesval);
        elseif (strcmp(get(Menu, 'type'), 'uimenu') & ~strcmp(get(Menu, 'label'), 'Te&sts'))
            i= get(Menu, 'position');
            j= get(gcbo, 'position')+i-1;
            seriesval= [i j];
		end
    end
end

options= get(figh, 'userdata');
Z= options{1};
Names= options{3};
if size(options, 2)> 2
    options= options{2};
else
    options= [];
end

if ~isempty(h_series)
    set(h_series, 'userdata', seriesval);
end

% Handling additional uicontrols in testtool window
value= [];
e_handle= findall(figh, 'style', 'edit');
b_handles= [findall(figh, 'string', '<<<') findall(figh, 'string', '>>>')];
if ~isempty(e_handle)
    str= get(e_handle, 'string');
    fullsam= 'Full sample                  ';
    allsub= 'All subsamples                ';
    if strcmp(lower(str), lower(fullsam(1 : size(str, 2))))
        str= fullsam; value= 0;
    elseif strcmp(lower(str), lower(allsub(1 : size(str, 2))))
        str= allsub; value= -1;
    else
        str= [str ' '];
        ind= min(findstr(str, ' ')-1);
        str= str(1 : ind);
        value= str2num(str);
        if isempty(value), value= 0; end
    end
end

    