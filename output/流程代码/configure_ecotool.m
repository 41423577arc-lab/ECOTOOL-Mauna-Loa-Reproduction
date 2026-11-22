function configure_ecotool()
% 优先使用已添加的工具箱，再检查环境变量和常规用户安装目录。
if exist('modelUC','file')==2,return;end
toolboxPath=getenv('ECOTOOL_PATH');
if isempty(toolboxPath)
    toolboxPath=fullfile(getenv('APPDATA'),'MathWorks','MATLAB Add-Ons','Toolboxes','ECOTOOL');
end
if isfolder(toolboxPath),addpath(toolboxPath);end
assert(exist('modelUC','file')==2, ...
    '未找到ECOTOOL。请先addpath工具箱，或设置ECOTOOL_PATH环境变量。');
end
