function errorSSpace(msg, fun, stop)
% Produces error messages
stop= 0;
if nargin< 3, stop= 1; end

if nargin< 2, fun= 'ECOTOOL Toolbox'; end

errordlg([msg repmat(' ', size(msg, 1), 1)], ['ERROR: ' fun ' ']);
if stop, error(' '); end
