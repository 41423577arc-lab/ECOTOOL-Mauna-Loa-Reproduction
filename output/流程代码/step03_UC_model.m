
%% 第3步：使用ECOTOOL拟合UC模型（RW与LLT）
% 研究目标：用截至2026年9月的完整周期拟合并保留后续周期
% 本步只估计模型，不使用保留测试周期的真实值
%
% 运行前：
% 先运行 step01_data_preparation.m
% 本脚本不需要重复运行第二步检验
%
% 注意：不要在开头使用clear，以免清除训练变量


%% 3.1 检查ECOTOOL环境与训练变量

projectDir = personDir;
outputDir = projectDir;
trainingFile = fullfile(outputDir, 'step01_training_data.mat');
assert(isfile(trainingFile), '请先运行第一步，生成训练数据MAT文件。');
training = load(trainingFile);
tTrain = training.tTrain; yTrain = training.yTrain;

% 仅在尚未配置时添加用户指定的工具箱路径。
if exist('modelUC', 'file') ~= 2
    configure_ecotool();
end
% 检查ECOTOOL函数是否存在
if exist('modelUC', 'file') ~= 2
    error(['未找到ECOTOOL的modelUC函数。', ...
           '请先安装ECOTOOL并添加MATLAB路径。']);
end

fprintf('\n========== ECOTOOL环境检查 ==========\n');

% 查看当前调用的modelUC所在位置
which modelUC


%% 3.2 核验训练数据

% 训练期应为2024年9月2日起至2026年9月末前的完整周期
% 共108个连续七天周期
expectedMonths = datetime(2024,9,2) ...
    + caldays(7*(0:107)');

assert(isequal(tTrain(:), expectedMonths(:)), ...
    '训练日期不正确，请检查第一步。');

% 转换成列向量
yTotalTrain = double(yTrain(:));


% 检查总支付序列长度
assert(length(yTotalTrain) == 108, ...
    '总支付训练集不是108个周期。');



% 检查是否存在NaN或Inf
assert(all(isfinite(yTotalTrain)), ...
    '总支付训练数据存在无效值。');


fprintf('\n========== 训练数据检查 ==========\n');

fprintf('训练周期起始日：%s 至 %s\n', ...
    datestr(tTrain(1), 'yyyy-mm-dd'), ...
    datestr(tTrain(end), 'yyyy-mm-dd'));

fprintf('训练样本数：%d\n', length(yTotalTrain));

fprintf('总支付平均值：%.2f元\n', mean(yTotalTrain));



modelFile = fullfile(outputDir, 'step03_UC_models.mat');
sourceSignature = {fileread([mfilename('fullpath') '.m']),fileread(which('modelUC')),fileread(which('auxmodelUC')),fileread(which('clliket'))};
%% 3.3 个人总支付UC模型拟合

fprintf('\n========== 个人总支付UC模型 ==========\n');

% modelUC函数参数：
% 参数1：训练序列
% 参数2：外生变量，暂不使用，设为[]
% 参数3：模型结构
% 参数4：预测步数，这里设为1个七天周期


% 模型一：RW随机游走趋势
% 假定基础消费水平随时间随机变化

fprintf('\n正在估计：总支付RW模型\n');

ucTotal_RW = modelUC(yTotalTrain, [], 'RW', 1);

fprintf('总支付RW模型估计完成。\n');


% 模型二：LLT局部线性趋势
% 同时允许基础消费水平及趋势斜率随机变化

fprintf('\n正在估计：总支付LLT模型\n');

ucTotal_LLT = modelUC(yTotalTrain, [], 'LLT', 1);

fprintf('总支付LLT模型估计完成。\n');


%% 3.5 估计表、参数与含义明确的样本内指标
% 核验依据：modelUC.m、auxmodelUC.m、clliket.m、SSestimET.m及官方手册。
% 手册第21/26/52页说明comp顺序、方差的log10 score及输出定义。
% 当前四个实参位置调用实际采用CML，结构体method保留包装器默认EML，不能据此判断。
% e为原单位的一步创新，当前版本删去前两个初始化观测；py仅含nofs个样本外预测。
% comp前三列为平滑趋势、季节、不规则；comps第三列是输出标准差，非不规则项标准差。
% RW/LLT无季节且不返回独立斜率成分，不强行绘制季节或斜率。
% outlier是输入设置，不是异常周期起始日清单；当前默认不启用自动异常值调整，y0为空。
modelNames = {'总支付-RW', '总支付-LLT'};
modelResults = {ucTotal_RW, ucTotal_LLT};
modelDetails = cell(2,1);
modelSummary = table;
parameterTables = cell(2,1);
for i = 1:2
    m = modelResults{i};
    fprintf('\n========== %s：ECOTOOL原始估计表 ==========\n', modelNames{i});
    disp(m.table);
    assert(any(contains(string(m.table), 'CONDITIONAL SUM OF SQUARES')), ...
        '实际估计方法变化，请重新核验字段与初始化处理。');
    observed = yTotalTrain;
    if mod(i,2)==1
        labels = ["水平扰动方差"; "观测噪声方差"];
    else
        labels = ["水平扰动方差"; "斜率扰动方差"; "观测噪声方差"];
    end
    assert(numel(m.par)==numel(labels), '参数结构发生变化，需要重新核验。');
    scoreSE = sqrt(diag(m.covpar));
    scoreSE(~isfinite(scoreSE) | imag(scoreSE)~=0) = NaN;
    scoreSE = real(scoreSE);
    % auxmodelUC明确使用10.^par构造Q和R；covpar在score尺度上。
    parameterTables{i} = table(labels, m.par(:), scoreSE(:), 10.^m.par(:), ...
        'VariableNames', {'Parameter','Log10Variance','SE_Log10Variance','Variance'});
    disp(parameterTables{i});
    fprintf('参数标准误处于log10方差尺度，近边界/小样本时不据此作方差显著性结论。\n');
    % 由工具箱实际状态矩阵重建一步滤波，并与e逐期比对后确认定义及日期。
    detail = verifyInnovations(m, observed);
    modelDetails{i} = detail;
    e = detail.error(detail.valid);
    aic = readMetric(m.table, 'AIC'); sbc = readMetric(m.table, 'SBC');
    modelSummary = [modelSummary; table(string(modelNames{i}), "CML", ...
        sum(detail.valid), detail.initialCount, mean(abs(e)), sqrt(mean(e.^2)), aic, sbc, ...
        'VariableNames', {'Model','ActualMethod','NResidual','NInitialization', ...
        'InSampleMAE','InSampleRMSE','ECOTOOL_AIC','ECOTOOL_SBC'})]; %#ok<AGROW>
    fprintf('py仅含%d个样本外预测，本步不作为拟合值或最终预测展示。\n', numel(m.py));
    fprintf('stdpy为工具箱条件预测标准差；当前噪声尺度与经验残差相差较大，不能直接用作可靠最终区间。\n');
    fprintf('残差经验标准差=%.2f元；有效期一步条件标准差范围=%.2f至%.2f元。\n', ...
        std(e), min(detail.predictionSD(detail.valid)), max(detail.predictionSD(detail.valid)));
end
disp('样本内一步拟合误差（参数由完整训练期估计，不是滚动预测成绩）：');
disp(modelSummary);

%% 3.6 观测与一步拟合对比，以及工具箱确实返回的平滑成分
for i = 1:2
    m = modelResults{i}; detail = modelDetails{i};
    observed = yTotalTrain;
    f = figure('Color','w','Position',[100 100 1000 500]);
    plot(tTrain, observed, '-o', 'LineWidth',1.2); hold on;
    plot(tTrain, detail.fitted, '-s', 'LineWidth',1.2); hold off;
    title([modelNames{i} '观测与样本内一步预测拟合对比']);
    xlabel('周期起始日'); ylabel('支付金额（元）'); grid on;
    legend('观测值','一步预测拟合值（训练期估参）','Location','best');
    xtickformat('yyyy-MM-dd'); xtickangle(45);
    exportFigureByTitle(f, outputDir);
    assert(isequal(size(m.comp), [numel(tTrain) 3]) && ...
        max(abs(sum(m.comp,2)-observed)) < 1e-6 && all(abs(m.comp(:,2))<1e-10), ...
        '成分结构或重构关系改变，不能沿用当前成分解释。');
    f = figure('Color','w','Position',[100 100 1000 650]);
    subplot(2,1,1);
    plot(tTrain, m.comp(:,1), '-o', 'LineWidth',1.2);
    title('平滑趋势水平（利用整个训练期）'); xlabel('周期起始日'); ylabel('趋势金额（元）');
    xtickformat('yyyy-MM-dd'); grid on;
    subplot(2,1,2);
    plot(tTrain, m.comp(:,3), '-o', 'LineWidth',1.2); yline(0, ':');
    title('平滑不规则成分（与一步预测误差不同）'); xlabel('周期起始日'); ylabel('金额（元）');
    xtickformat('yyyy-MM-dd'); grid on;
    sgtitle([modelNames{i} '未观测成分分解']);
    exportFigureByTitle(f, outputDir);
end
save(modelFile, 'training','tTrain','yTotalTrain', ...
    'ucTotal_RW','ucTotal_LLT', ...
    'modelNames','modelDetails','modelSummary','parameterTables','sourceSignature');
writetable(modelSummary,fullfile(outputDir,'UC模型样本内拟合指标.csv'),'Encoding','UTF-8');
parameterSummary = table;
for i = 1:2
    rows = parameterTables{i};
    rows = addvars(rows,repmat(string(modelNames{i}),height(rows),1),'Before',1,'NewVariableNames','Model');
    parameterSummary = [parameterSummary;rows]; %#ok<AGROW>
end
writetable(parameterSummary,fullfile(outputDir,'UC模型参数估计.csv'),'Encoding','UTF-8');
fprintf('\n第三步完成；模型和提取结果已保存，第四步无需重新估计。\n');

function detail = verifyInnovations(m, observed)
% 与可读clliket.m相同的Kalman递推；仅支持本项目无季节、无外生输入的RW/LLT。
if strcmp(m.model,'RW'), phi = eye(2); else, phi = [1 1;0 1]; end
[x,P,Phi,~,E,H,~,C,Q,R,S] = auxmodelUC(m.par, phi, eye(2), ...
    [1 0], 1, zeros(2,1), m.model, observed(1));
if isempty(P), P = 1e5*eye(numel(x)); end
n = numel(observed); raw = nan(n,1); sd = raw;
for t = 1:n
    F = H*P*H' + C*R*C';
    assert(isfinite(F) && F>0, '一步预测方差无效。');
    K = (Phi*P*H' + E*S*C')/F;
    raw(t) = observed(t)-H*x;
    sd(t) = sqrt(F);
    A = Phi-K*H; cross = K*(E*S*C')';
    x = Phi*x+K*raw(t);
    P = A*P*A' + E*Q*E' + K*C*R*C'*K' - cross-cross';
end
% SSestimET按状态数排除初始化期；实测e与第3至108期原始创新一致。
initialCount = numel(x);
assert(numel(m.e)==n-initialCount && ...
    max(abs(m.e(:)-raw(initialCount+1:end))) < 1e-6*max(1,max(abs(raw))), ...
    '工具箱e不再匹配原单位一步创新，禁止猜测残差类型或周期起始日。');
assert(numel(m.py)==1 && abs(m.py-H*x)<1e-6*max(1,abs(m.py)), ...
    'py不匹配第109个周期的条件预测，需重新核验。');
assert(abs(m.stdpy-sqrt(H*P*H'+C*R*C')) < 1e-6*max(1,abs(m.stdpy)), ...
    'stdpy定义发生变化，需重新核验。');
valid = isfinite(raw) & isfinite(observed);
valid(1:initialCount) = false;
% 保留周期起始日位置，不把缺失处两侧残差拼接成相邻周期起始日。
assert(all(valid(initialCount+1:end)), '有效期存在内部缺失，需要另定缺失感知诊断。');
raw(~valid) = NaN;
detail = struct('error',raw,'predictionSD',sd,'valid',valid, ...
    'initialCount',initialCount,'fitted',observed-raw, ...
    'standardizedInnovation',raw./sd);
end

function value = readMetric(textTable, name)
rows = cellstr(textTable);
token = regexp(strjoin(rows,newline), [name ':\s*([-+0-9.eE]+)'], 'tokens', 'once');
value = NaN;
if ~isempty(token), value = str2double(token{1}); end
end


