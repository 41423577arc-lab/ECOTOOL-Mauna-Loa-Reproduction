function newbill_arima
root=fileparts(mfilename('fullpath'));
toolbox=getenv('CONSUMPTION_ECOTOOL');
addpath(toolbox);
assert(strcmp(which('modelAUTO'),fullfile(toolbox,'modelAUTO.m')));
set(groot,'DefaultFigureVisible','off');
data=readtable(fullfile(root,'newbill_train.csv'));
assert(height(data)==730 && all(isfinite(data.Spending)));
captured=evalc('fitted=modelAUTO(data.Spending,''s'',1,''boxcox'',0,''nofs'',61);');
forecast=fitted.py(:);
standard=fitted.stdpy(:);
assert(numel(forecast)==61 && numel(standard)==61 && isreal(forecast) && all(isfinite(forecast)) && all(isfinite(standard)));
spec=strjoin(strtrim(string(fitted.model))',' | ');
fprintf('MODEL %s\n%s\n',char(spec),captured);
result=table((1:61)',forecast,standard,repmat(spec,61,1), ...
    'VariableNames',{'Step','Forecast','StdForecast','Model'});
writetable(result,fullfile(root,'newbill_model_output.csv'));
save(fullfile(root,'newbill_model.mat'),'fitted');
end
