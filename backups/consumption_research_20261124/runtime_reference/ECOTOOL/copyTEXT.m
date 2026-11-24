function copyTEXT
% Send text shown on a dispwindow to the clipboard
str= get(findall(gcbf, 'style', 'listbox'), 'string');
str= [str'; char(ones(1, size(str, 1))*10)];
clipboard('copy', str(:)');
