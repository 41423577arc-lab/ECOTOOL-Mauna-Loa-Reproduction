function out= wwaitfor(numinc)
% numinc= number of divisions: Open a new window (with an increasing length bar)
% numinc= 0:                   Close window
% No input:                    Update existing window (any type)
% numinc= NaN:                 Open a constant length bar type window

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

out= 0;
set(0, 'units', 'pixels');

if nargin== 0; numinc= inf; end

if numinc== 0        % Close window
    delete(findall(0, 'name', 'Estimation in process. Please wait .....'));
elseif nargin> 0     % Open new window
    if isempty(get(0, 'currentfigure'))
        position= [0.3256    0.6081    0.3500    0.1300];
        currentf= [];
    else
        currentf= gcf;
        ucurrentf= get(gcf, 'units');
        set(gcf, 'units', 'normal');
        posgcf= get(gcf, 'position');
        position= [posgcf(1)+0.1 posgcf(2)+posgcf(4)/2 0.35 0.13];
    end
%     fhandle= figure('name', 'Estimation in process. Please wait .....', ...
%             'menubar', 'none', 'units', 'normal', 'resize', 'off', 'windowst', 'modal', ...
%             'DeleteFcn', 'cancelbutton;', 'position', position);
    fhandle= figure('name', 'Estimation in process. Please wait .....', ...
            'menubar', 'none', 'units', 'normal', 'resize', 'off', ...
            'DeleteFcn', 'cancelbutton;', 'position', position);
    set(gca, 'xticklabel', '', 'yticklabel', '', 'position', [0.1 0.6 0.8 0.2]);
    patch([0 0 1 1], [0 1 1 0], 'w');
    if isnan(numinc)
        hpatch= patch([0 0 0.2 0.2], [0 1 1 0], 'r', 'edgecolor', 'r'); %, 'erasemode', 'xor');
    else
        hpatch= patch([0 0 0 0], [0 1 0 1], 'r', 'edgecolor', 'r'); %,  'erasemode', 'none');
    end
    uicontrol('units', 'normal', 'string', 'CANCEL', 'position', [0.35 0.15 0.3 0.25], ...
        'callback', 'cancelbutton;');
	drawnow;
    set(fhandle, 'userdata', {[0 0 numinc], hpatch});  % [Cancel_on/off part_already_run increment]
    if ~isempty(currentf), set(currentf, 'units', ucurrentf); end
else                  % Update existing window
    fhandle= findall(0, 'name', 'Estimation in process. Please wait .....');
    if ~isempty(fhandle)
        data1= get(fhandle, 'userdata');
        data= data1{1}; data4= data1{2};
        if isnan(data(3))
            data(2)= data(2)+0.1;
            if data(2)> 0.8, data(2)= 0; end
            set(data4, 'xdata', [data(2) data(2) data(2)+0.2 data(2)+0.2], 'ydata', [0 1 1 0]);
        elseif data(2)<= 1
            data(2)= min(data(2)+1/data(3), 1);
            set(data4, 'xdata', [0 0 data(2) data(2)], 'ydata', [0 1 1 0]);
        end
        drawnow;
        dd= get(fhandle, 'userdata');
        data(1)= dd{1}(1);
        if data(1)
            out= 1; delete(fhandle);
        else
            set(fhandle, 'userdata', {data, data4});
        end
    end
end
