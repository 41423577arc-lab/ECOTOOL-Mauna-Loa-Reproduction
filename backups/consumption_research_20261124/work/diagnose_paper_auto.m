function diagnose_paper_auto
addpath(getenv('CONSUMPTION_ECOTOOL'));
set(groot, 'DefaultFigureVisible', 'off');
source = readtable(fullfile(fileparts(mfilename('fullpath')), 'paper_monthly_input.csv'));
y = source.Spending(1:24);
evalc('fitted = modelAUTO(y, ''s'', [1 12], ''nofs'', 24);');
evalc('[transformed, lambda] = vboxcox(y);');
fprintf('raw range %.8g %.8g | transformed range %.8g %.8g | lambda %.8g\n', ...
    min(y),max(y),min(transformed),max(transformed),lambda);
fprintf('model y0 range %.8g %.8g | stdpy first %.8g | res std %.8g\n', ...
    min(fitted.y0),max(fitted.y0),fitted.stdpy(1),std(fitted.e,'omitnan'));
assert(numel(fitted.y0) == numel(transformed) && max(abs(fitted.y0(:)-transformed(:))) < 1e-6);
yuan = vboxcoxinv(fitted.py(:), lambda);
writematrix([fitted.py(:), yuan], fullfile(fileparts(mfilename('fullpath')), 'paper_arima_inverse.csv'));
fprintf('Box-Cox inverse results %.8f %.8f %.8f\n', yuan(1:3));
end
