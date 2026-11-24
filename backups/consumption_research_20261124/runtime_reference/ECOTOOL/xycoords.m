function xycoords(input)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if input== 0
    delete(findall(gcf, 'tag', 'coordinates'));
    set(gcf, 'pointer', 'arrow');
else
    xy= get(gca, 'currentpoint');
    XTICK= get(gca, 'xtick');
    XTICKLABEL= get(gca, 'xticklabel');
    if isempty(XTICKLABEL), XTICKLABEL= num2str(XTICK(end)); end
    pp= log10(XTICK(end)/str2num(XTICKLABEL(end, :)));
    if (floor(pp)-pp== 0)
        changescale= 0;
    else
        if abs(XTICK(end)-str2num(XTICKLABEL(end, :)))> 0.01
            changescale= 1;
            if XTICK(1)== 0, islinear= 1; else, islinear= 0; end
        else
            changescale= 0;
        end
    end
    ejes= get(gca, 'position');
    lx= get(gca, 'XLim');
    ly= get(gca, 'Ylim');
    if (xy(1, 1)>= lx(1) & xy(1, 1)<= lx(2) & xy(1, 2)>= ly(1) & xy(1, 2)<= ly(2))
        limits= [lx(1) ly(1) lx(2)-lx(1) ly(2)-ly(1)];
        position= [ejes(1)+ejes(3)/limits(3)*(xy(1, 1)-lx(1))-0.1 0.01+ejes(2)+ejes(4)/limits(4)*(xy(1, 2)-ly(1)) 0.2 0.1];
        if changescale
            if islinear
                str= char(['x= ' num2str(2*pi./xy(1, 1))], ['y= ' num2str(xy(1, 2))]);
            else
                str= char(['x= ' num2str(2*pi./10^(xy(1, 1)))], ['y= ' num2str(xy(1, 2))]);
            end
        else
            str= char(['x= ' num2str(xy(1, 1))], ['y= ' num2str(xy(1, 2))]);
        end
        uicontrol('style', 'text', 'tag', 'coordinates', ...
            'units', 'normal', ...
            'background', 'w', ...
            'horizontal', 'center', ...
            'fontsize', 12, ...
            'position', position, ...
            'string', str);
        set(gcf, 'pointer', 'crosshair');
    end
end