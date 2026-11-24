function newbill_rolling(dataset)
if nargin<1
    dataset="new";
end
root=fileparts(mfilename('fullpath'));
toolbox=getenv('CONSUMPTION_ECOTOOL');
addpath(toolbox);
assert(strcmp(which('modelAUTO'),fullfile(toolbox,'modelAUTO.m')));
set(groot,'DefaultFigureVisible','off');
if dataset=="original"
    trainFile='holdout_daily_train.csv';
    testFile='holdout_daily_actual.csv';
    outputFile='originalbill_rolling_output.csv';
else
    assert(dataset=="new");
    trainFile='newbill_train.csv';
    testFile='newbill_test.csv';
    outputFile='newbill_rolling_output.csv';
end
train=readtable(fullfile(root,trainFile));
actual=readtable(fullfile(root,testFile));
assert(height(train)==730 && height(actual)==61);
output=table;
for index=1:height(actual)
    y=[train.Spending; actual.Actual(1:index-1)];
    assert(numel(y)==729+index);
    captured=evalc('fitted=modelAUTO(y,''s'',1,''boxcox'',0,''nofs'',1);');
    prediction=fitted.py(1);
    deviation=fitted.stdpy(1);
    assert(isreal(prediction) && isfinite(prediction) && isfinite(deviation) && deviation>=0);
    spec=strjoin(strtrim(string(fitted.model))',' | ');
    target=actual.Date(index);
    output=[output;table(index,target,target-caldays(1),numel(y),actual.Actual(index),prediction,deviation, ...
        mean(y),spec,'VariableNames',{'Round','Date','TrainingEnd','TrainingDays','Actual', ...
        'Forecast','StdForecast','MeanBaseline','Model'})];
    writetable(output,fullfile(root,outputFile));
    close all;
    if mod(index,10)==0 || index==height(actual)
        fprintf('COMPLETED %d/61 | %s | prediction %.4f\n',index,char(target),prediction);
    end
end
end
