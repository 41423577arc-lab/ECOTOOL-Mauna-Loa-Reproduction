function finalize_checks()
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));s=load(fullfile(here,'results.mat'));locked=load(fullfile(here,'locked.mat'),'models');s.models=locked.models;models=s.models;save(fullfile(here,'results.mat'),'models','-append');tr=load(fullfile(root,'output','C','step01_training_data.mat'));file=fullfile(root,'data','C_个人总支付_自然周.xlsx');raw=readmatrix(file,'Sheet','UC数据','Range','B2:B113');assert(isequal(raw(1:108),tr.yTrain(:)));assert(all(isfinite(raw))&&all(raw>=0));
T=table;daily=table;multistart=table;
for b=1:numel(s.models)
 m=s.fits{b};if isempty(m)||~isfield(m,'Q'),continue,end
 T=[T;table(s.models(b),m.Q(1,1),m.Q(2,2),m.R,m.Q(1,1)/max(m.R,eps),m.flag,'VariableNames',{'Model','QLevel','QSlope','R','LevelRatio','ExitFlag'})];
 d=m.detail;daily=[daily;table(repmat(s.models(b),108,1),tr.tTrain,d.fitted,d.filtered,d.smooth,d.e,d.F,d.K(:,1),'VariableNames',{'Model','Date','InSampleOneStep','Filtered','Smoothed','Innovation','PredictionVariance','LevelGain'})];
 for k=1:size(m.trials,1),multistart=[multistart;table(s.models(b),k,string(mat2str(m.trials(k,1:end-2))),m.trials(k,end-1),m.trials(k,end),'VariableNames',{'Model','Start','Parameters','Objective','ExitFlag'})];end
end
writetable(T,fullfile(here,'final_variances.csv'));writetable(daily,fullfile(here,'state_innovation_detail.csv'));writetable(multistart,fullfile(here,'multistart.csv'));
% Block bootstrap of paired origin-level MAE differences; training only.
rng(20261123);ci=table;
for model=[s.selected,"ML_RW","W_RW"]
 a=s.pred(s.pred.Model==model & s.pred.Protocol=="four",:);b=s.pred(s.pred.Model=="EC_RW" & s.pred.Protocol=="four",:);assert(isequal(a.Origin,b.Origin)&&isequal(a.Horizon,b.Horizon));loss=reshape(abs(a.Forecast-a.Actual)-abs(b.Forecast-b.Actual),4,27);delta=mean(loss,1);boot=zeros(3000,1);
 for k=1:3000,idx=[];for j=1:9,start=randi(27);idx=[idx mod(start-1+(0:2),27)+1];end;boot(k)=mean(delta(idx));end
 q=quantile(boot,[.025 .975]);ci=[ci;table(model,mean(delta),q(1),q(2),'VariableNames',{'Model','MAEDifferenceFromOldRW','Block3Lower95','Block3Upper95'})];end
writetable(ci,fullfile(here,'paired_uncertainty.csv'));
f=figure('Visible','off');tiledlayout(2,1);nexttile;bar(categorical(T.Model),log10(max(T.LevelRatio,1e-12)));ylabel('log10(q/R)');title('方差比例（AR1无观测噪声单独解释）');nexttile;plot(tr.tTrain,raw(1:108));ylabel('消费金额/元');exportgraphics(f,fullfile(here,'04_variance_ratios.png'),'Resolution',130);savefig(f,fullfile(here,'04_variance_ratios.fig'));close(f);
% Re-export at readable size; preserve original figures.
figs=dir(fullfile(here,'*.fig'));for k=1:numel(figs),f=openfig(fullfile(here,figs(k).name),'invisible');set(f,'Position',[50 50 1500 850]);exportgraphics(f,fullfile(here,replace(figs(k).name,'.fig','.png')),'Resolution',130);close(f);end
fid=fopen(fullfile(here,'verification.txt'),'w');fprintf(fid,'Workbook training equals original MAT: PASS\n112 finite nonnegative amounts: PASS\nPredictions protocol counts: %d\nNo Python used\n',height(s.pred));fclose(fid);
end


