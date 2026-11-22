%% 与原第二步相同的总支付检验，新增CSV留存原先仅打印的数值
projectDir=personDir; outputDir=personDir;
training=load(fullfile(outputDir,'step01_training_data.mat')); yTrain=training.yTrain;
alpha=0.05;
[hLB,pLB,Q]=lbqtest(yTrain,'Lags',[3,6,8],'Alpha',alpha);
lb=table(repmat("个人总支付",3,1),[3;6;8],Q(:),pLB(:),logical(hLB(:)), ...
    'VariableNames',{'Series','Lag','Q','PValue','RejectH0'});
[hADF,pADF,statADF]=adftest(yTrain,'Model','ARD','Lags',[0,1],'Alpha',alpha);
adf=table(repmat("个人总支付",2,1),[0;1],statADF(:),pADF(:),logical(hADF(:)), ...
    'VariableNames',{'Series','Lag','Statistic','PValue','RejectUnitRoot'});
writetable(lb,fullfile(outputDir,'原始序列LjungBox检验.csv'),'Encoding','UTF-8');
writetable(adf,fullfile(outputDir,'原始序列ADF检验.csv'),'Encoding','UTF-8');
save(fullfile(outputDir,'step02_stationarity.mat'),'lb','adf','alpha');
f=figure('Visible','off','Color','w','Position',[80 80 1000 450]);
subplot(1,2,1); autocorr(yTrain,'NumLags',8,'NumSTD',1.96);
title('个人总支付：ACF'); xlabel('滞后（周）'); ylabel('自相关系数');
subplot(1,2,2); parcorr(yTrain,'NumLags',8,'NumSTD',1.96);
title('个人总支付：PACF'); xlabel('滞后（周）'); ylabel('偏自相关系数');
sgtitle('个人自然周总支付的ACF与PACF分析'); exportFigureByTitle(f,outputDir); close(f);
f=figure('Visible','off','Color','w');
parcorr(yTrain,'NumLags',8,'Method','yule-walker');
title('总支付：Yule-Walker PACF'); xlabel('滞后（周）'); ylabel('偏自相关系数');
exportFigureByTitle(f,outputDir); close(f);
disp(lb); disp(adf);
