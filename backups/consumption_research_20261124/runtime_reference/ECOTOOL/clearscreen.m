function clearscreen(handle)

if nargin< 1, handle= gcf; end

handles= findall(handle, 'type', 'axes');
handles= [handles; findall(handle, 'style', 'edit')];
handles= [handles; findall(handle, 'style', 'push')];
delete(handles);
