function weekly49_ets_uc
root = fileparts(mfilename('fullpath'));
toolboxPath = getenv('CONSUMPTION_ECOTOOL');
addpath(toolboxPath);
assert(strcmp(which('modelETS'), fullfile(toolboxPath, 'modelETS.m')));
assert(strcmp(which('modelUC'), fullfile(toolboxPath, 'modelUC.m')));
set(groot, 'DefaultFigureVisible', 'off');
data = readtable(fullfile(root, 'weekly49_input.csv'), 'TextType', 'string');
origins = unique(data.Origin, 'stable');
output = table;
for index = 1:numel(origins)
    origin = origins(index);
    history = data.Spending(data.Origin == origin);
    steps = 4;
    if index > 49
        steps = 6;
    end
    for name = ["ETS", "UC"]
        status = "OK";
        try
            if name == "ETS"
                evalc('fitted = modelETS(history, ''model'', ''AN'', ''nofs'', steps);');
            else
                evalc('fitted = modelUC(history, ''model'', ''LLT'', ''nofs'', steps);');
            end
            forecast = fitted.py(:);
            assert(numel(forecast) == steps && isreal(forecast) && all(isfinite(forecast)));
        catch failure
            forecast = nan(steps, 1);
            status = string(failure.message);
            fprintf(2, '%s | %s | %s\n', char(origin), char(name), char(status));
        end
        output = [output; table(repmat(origin, steps, 1), repmat(name, steps, 1), (1:steps)', ...
            forecast, repmat(status, steps, 1), 'VariableNames', {'Origin','Model','Step','Forecast','Status'})];
    end
    if mod(index, 10) == 0 || index == numel(origins)
        fprintf('Completed %d/%d\n', index, numel(origins));
    end
    close all;
end
writetable(output, fullfile(root, 'weekly49_ets_uc.csv'));
end
