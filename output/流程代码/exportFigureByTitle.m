function files = exportFigureByTitle(fig, outputDir)
% 按中文总标题保存300 DPI PNG和可编辑FIG；同名文件自动编号。
if nargin < 1 || isempty(fig), fig = gcf; end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(fileparts(mfilename('fullpath')), 'output');
end
if ~isfolder(outputDir), mkdir(outputDir); end
% sgtitle使用此Tag；兼容tiledlayout的整体标题。
heading = findall(fig, 'Tag', 'suptitle');
if isempty(heading)
    heading = findall(fig, '-isa', 'matlab.graphics.illustration.subplot.Text');
end
name = "";
if ~isempty(heading), name = join(string(heading(1).String), " "); end
if strlength(name) == 0
    layouts = findall(fig, 'Type', 'tiledlayout');
    if ~isempty(layouts), name = join(string(layouts(1).Title.String), " "); end
end
if strlength(name) == 0
    ax = findall(fig, 'Type', 'axes');
    if numel(ax) == 1, name = join(string(ax.Title.String), " "); end
end
assert(strlength(strtrim(name)) > 0, ...
    '图表需要中文标题；多子图请先调用sgtitle添加总标题。');
name = regexprep(char(name), '[<>:"/\\|?*\x00-\x1F]', '_');
name = regexprep(strtrim(name), '[. ]+$', '');
if ~isempty(regexpi(name, '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])($|\.)', 'once'))
    name = ['图表_' name];
end
stem = fullfile(outputDir, name);
% 本次结果目录固定标题覆盖，便于完整重跑且不混入重复版本。
drawnow;
exportgraphics(fig, [stem '.png'], 'Resolution', 300);
savefig(fig, [stem '.fig']);
files = string({[stem '.png'], [stem '.fig']});
end
