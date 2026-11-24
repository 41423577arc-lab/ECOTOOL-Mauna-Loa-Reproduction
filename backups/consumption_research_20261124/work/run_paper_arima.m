function run_paper_arima
root = fileparts(fileparts(mfilename('fullpath')));
toolboxPath = getenv('CONSUMPTION_ECOTOOL');
addpath(toolboxPath);
assert(strcmp(which('modelAUTO'), fullfile(toolboxPath, 'modelAUTO.m')));
fprintf('MATLAB %s\nECOTOOL %s\n', version, which('modelAUTO'));
set(groot, 'DefaultFigureVisible', 'off');
source = readtable(fullfile(root, 'work', 'paper_monthly_input.csv'), 'TextType', 'string');
origins = unique(source.Origin, 'stable');
steps = 24;
records = table;
for index = 1:numel(origins)
    cutoff = origins(index);
    y = source.Spending(source.Origin == cutoff);
    assert(numel(y) == 23 + index && all(isfinite(y)) && all(y > 0));
    targets = dateshift(cutoff, 'start', 'month') + calmonths((1:steps)');
    fprintf('ORIGIN %s | MONTHS %d\n', char(cutoff), numel(y));
    for modelName = ["Auto ARIMA", "Airline"]
        prediction = nan(steps, 1);
        modelSpec = "";
        status = "OK";
        try
            if modelName == "Auto ARIMA"
                logText = evalc('fitted = modelAUTO(y, ''s'', [1 12], ''nofs'', steps);');
                prediction = fitted.py(:);
            else
                logText = evalc('[transformed, lambda] = vboxcox(y); fitted = modelTF(transformed, ''model'', ''(1+ma1*B)(1+ma12*B12)/(1-B)(1-B12)'', ''nofs'', steps);');
                prediction = vboxcoxinv(fitted.py(:), lambda);
            end
            modelSpec = string(fitted.model);
            assert(isequal(size(prediction), [steps 1]) && isreal(prediction) && all(isfinite(prediction)), ...
                'ECOTOOL did not produce 24 real finite forecasts.');
            fprintf('%s | %s | first=%.8f\n%s\n', char(modelName), char(modelSpec), prediction(1), logText);
        catch failure
            fprintf(2, '%s | ERROR | %s\n', char(modelName), getReport(failure, 'extended'));
            prediction = nan(steps, 1);
            status = string(failure.message);
        end
        records = [records; table(repmat(cutoff, steps, 1), targets, (1:steps)', ...
            repmat(numel(y), steps, 1), repmat(modelName, steps, 1), repmat(modelSpec, steps, 1), ...
            prediction, repmat(status, steps, 1), 'VariableNames', ...
            {'TrainingEnd','TargetMonth','Horizon','TrainingMonths','Model','Specification','Forecast','Status'})];
    end
    close all;
end
writetable(records, fullfile(root, 'work', 'paper_arima_matlab.csv'));
end
