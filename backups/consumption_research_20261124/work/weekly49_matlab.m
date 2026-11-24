function weekly49_matlab
root = fileparts(mfilename('fullpath'));
toolboxPath = getenv('CONSUMPTION_ECOTOOL');
addpath(toolboxPath);
assert(strcmp(which('modelAUTO'), fullfile(toolboxPath, 'modelAUTO.m')));
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
    status = "";
    spec = "";
    scale = "";
    predicted = nan(steps, 1);
    try
        evalc('fitted = modelAUTO(history, ''s'', 1, ''boxcox'', 0, ''nofs'', steps);');
        specLines = strtrim(string(fitted.model));
        spec = strjoin(specLines(:)', ' | ');
        predicted = fitted.py(:);
        assert(fitted.boxcox == 0);
        scale = "yuan";
        assert(numel(predicted) == steps && isreal(predicted) && all(isfinite(predicted)));
        status = "OK";
    catch exception
        predicted = nan(steps, 1);
        status = string(exception.message);
    end
    fprintf('%d/%d %s | %s | %s | %s\n', index, numel(origins), char(origin), char(spec), char(scale), char(status));
    output = [output; table(repmat(origin, steps, 1), (1:steps)', repmat(numel(history), steps, 1), ...
        repmat(spec, steps, 1), predicted, repmat(scale, steps, 1), repmat(status, steps, 1), ...
        'VariableNames', {'Origin','Step','TrainingWeeks','Specification','Forecast','OutputScale','Status'})];
    close all;
end
writetable(output, fullfile(root, 'weekly49_matlab_yuan.csv'));
end
