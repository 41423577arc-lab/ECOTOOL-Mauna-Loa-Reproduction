
%% 第2步：时间序列相关性、白噪声和平稳性检验

% 独立运行时读取明确保存的训练数据，避免依赖工作区或测试集。
projectDir = fileparts(mfilename('fullpath'));
trainingFile = fullfile(projectDir, 'output', 'step01_training_data.mat');
assert(isfile(trainingFile), '请先运行第一步。');
training = load(trainingFile);
yTrain = training.yTrain; regularTrain = training.regularTrain;

% 显著性水平设置为5%
alpha = 0.05;

% 两种研究序列
series = {yTrain(:), regularTrain(:)};
names = {'个人总支付', '个人常规支付'};

% 创建ACF和PACF图
figure('Color', 'w', 'Name', 'ACF与PACF分析');

for i = 1:2
    y = series{i};

    %% 2.1 绘制ACF（自相关函数）
    subplot(2,2,i);
    autocorr(y, 'NumLags', 8, 'NumSTD', 1.96);
    title([names{i}, '：ACF']); xlabel('滞后（月）'); ylabel('自相关系数');

    %% 2.2 绘制PACF（偏自相关函数）
    subplot(2,2,i+2);
    parcorr(y, 'NumLags', 8, 'NumSTD', 1.96);
    title([names{i}, '：PACF']); xlabel('滞后（月）'); ylabel('偏自相关系数');


    %% 2.3 Ljung-Box白噪声检验
    % 原假设H0：前m阶自相关系数均为0
    % 分别检查滞后3期、6期

    % 设置需要检验的滞后阶数
    LB_Lags = [3, 6];

    % 执行Ljung-Box检验
    [hLB, pLB, Q] = lbqtest(y, ...
        'Lags', LB_Lags, 'Alpha', alpha);

    fprintf('\n=== %s：白噪声检验 ===\n', names{i});

    % 逐个输出不同滞后阶数的检验结果
    for j = 1:length(LB_Lags)
        fprintf('滞后%d期：Q=%.4f，p=%.4f，h=%d\n', ...
            LB_Lags(j), Q(j), pLB(j), hLB(j));
    end

    %% 2.4 ADF单位根检验
    % 原假设H0：序列存在单位根
    % ARD表示考虑常数项
    % 分别采用0阶、1阶滞后观察结果是否稳定
    [hADF, pADF] = adftest(y, ...
        'Model', 'ARD', ...
        'Lags', [0,1], ...
        'Alpha', alpha);

    fprintf('=== %s：ADF单位根检验 ===\n', names{i});

    for j = 1:2
        fprintf('滞后%d阶：p=%.4f，h=%d\n', ...
            j-1, pADF(j), hADF(j));
    end
end


sgtitle('个人月度支付的ACF与PACF分析');
exportFigureByTitle(gcf);

%% 使用Yule-Walker方法重新估计PACF

figure('Color','w');

subplot(1,2,1);
parcorr(yTrain, ...
    'NumLags', 8, ...
    'Method', 'yule-walker');
title('总支付：Yule-Walker PACF'); xlabel('滞后（月）'); ylabel('偏自相关系数');

subplot(1,2,2);
parcorr(regularTrain, ...
    'NumLags', 8, ...
    'Method', 'yule-walker');
title('常规支付：Yule-Walker PACF'); xlabel('滞后（月）'); ylabel('偏自相关系数');

sgtitle('个人月度支付的Yule-Walker偏自相关分析');
exportFigureByTitle(gcf);

%% 第2步补充：第8阶Ljung-Box白噪声检验

% 检验前8阶自相关系数是否联合显著
% H0：前8阶自相关系数均为0
% h=1：p<0.05，拒绝H0
% h=0：p>=0.05，不能拒绝H0

% 个人总支付
[h1, p1, Q1] = lbqtest(yTrain, ...
    'Lags', 8, 'Alpha', 0.05);

% 个人常规支付
[h2, p2, Q2] = lbqtest(regularTrain, ...
    'Lags', 8, 'Alpha', 0.05);

fprintf('\n=== 第8阶Ljung-Box检验 ===\n');
fprintf('个人总支付：Q=%.4f，p=%.4f，h=%d\n', Q1, p1, h1);
fprintf('个人常规支付：Q=%.4f，p=%.4f，h=%d\n', Q2, p2, h2);
