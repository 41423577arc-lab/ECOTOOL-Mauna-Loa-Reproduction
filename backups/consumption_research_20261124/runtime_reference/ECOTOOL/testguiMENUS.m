function testguiMENUS(whattodo)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% whattodo= 1:  Save Windows Positions and Options
% whattodo= 2:  Load Options
% whattodo= 3:  Reset Windows Positions
% whattodo= 4:  Exit tests GUI tool

H1= findall(0, 'Name', 'Test Tool');
H2= findall(0, 'Name', 'Text Output Window');
N= max(size(H1));
Wposition= nan*ones(2, 4);
TextFontSize= [];
Options= [];

if whattodo== 1   % Save Windows positions and Options (window positions for testGUI and Text Output Window)
    Wposition(1, :)= get(gcf, 'position');
    Options= get(gcf, 'userdata'); Options= Options{2};
    if ~isempty(H2)
        Wposition(2, :)= get(H2, 'position');
        H3= findall(H2, 'style', 'listbox');
        TextFontSize= get(H3, 'fontsize');
    end
    curdir= cd;
    savedir= which('testguiMENUS');
    savedir= savedir(1 : findstr(savedir, 'testguiMENUS')-1);
    cd(savedir);
    save -V6 testguiSETTINGS Wposition TextFontSize Options
    cd(curdir);
elseif whattodo== 2   % Load Options
    load testguiSETTINGS
    userdata= get(gcf, 'userdata');
    userdata{2}= Options;
    set(gcf, 'userdata', userdata);    
elseif whattodo== 3   % Reset Windows positions (window positions for testGUI and Text Output Window)
    curdir= cd;
    savedir= which('testguiMENUS');
    savedir= savedir(1 : findstr(savedir, 'testguiMENUS')-1);
    cd(savedir);
    save -V6 testguiSETTINGS Wposition TextFontSize Options
    cd(curdir);
else    % Exit Tests GUI Window and Text Output Window
    close(gcf);
    if (~isempty(H2) & N== 1), close(H2); end
end
    


