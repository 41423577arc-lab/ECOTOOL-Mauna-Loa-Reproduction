function holdout_arima
root = fileparts(mfilename('fullpath'));
toolbox = getenv('CONSUMPTION_ECOTOOL');
addpath(toolbox);
assert(strcmp(which('modelAUTO'), fullfile(toolbox,'modelAUTO.m')));
set(groot,'DefaultFigureVisible','off');
daily = readtable(fullfile(root,'holdout_daily_train.csv'));
weekly = readtable(fullfile(root,'weekly49_input.csv'));
weekTraining = weekly.Spending(weekly.Origin == datetime(2026,8,30));
assert(height(daily)==730 && numel(weekTraining)==104);
for frequency=["daily","weekly"]
    if frequency=="daily"
        y=daily.Spending;
        steps=91;
    else
        y=weekTraining;
        steps=14;
    end
    captured=evalc('fitted=modelAUTO(y,''s'',1,''boxcox'',0,''nofs'',steps);');
    prediction=fitted.py(:);
    assert(numel(prediction)==steps && all(isfinite(prediction)) && isreal(prediction));
    spec=strjoin(strtrim(string(fitted.model))', ' | ');
    fprintf('%s %s\n%s\n',char(frequency),char(spec),captured);
    results=table((1:steps)',prediction,repmat(spec,steps,1),'VariableNames',{'Step','Forecast','Model'});
    writetable(results,fullfile(root,"holdout_"+frequency+"_forecast.csv"));
end
end
