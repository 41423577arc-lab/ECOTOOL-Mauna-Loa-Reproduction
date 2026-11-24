function run_person_a_arima
root=fileparts(mfilename('fullpath'));out=fullfile(fileparts(root),'outputs','A_自然周_ARIMA');
if ~isfolder(out),mkdir(out);end
source='D:/电脑管家迁移文件/xwechat_files/wxid_a1rf8kib9lsh22_0945/msg/file/2026-11/C_个人总支付_自然周.csv';
input=fullfile(root,'A_个人总支付_自然周.csv');copyfile(source,input);
addpath(getenv('CONSUMPTION_ECOTOOL'));set(groot,'DefaultFigureVisible','off');
t=readtable(input,'VariableNamingRule','preserve','TextType','string');
dates=datetime(string(t{:,1}),'InputFormat','yyyy-MM-dd');values=double(t{:,2});
assert(height(t)==112&&isequal(dates,datetime(2024,9,2)+caldays(7*(0:111)')));
assert(all(isfinite(values))&&all(values>=0));
n=108;initial=78;y=values(1:n);assert(dates(n)+caldays(6)==datetime(2026,9,27));
detail=table;metrics=table;models=["AutoARIMA","朴素","三期移动平均"];
predictions=nan(30,3);scales=nan(30,1);foldModels=cell(30,1);
for k=initial:n-1
 history=y(1:k);scale=mean(abs(diff(history)));assert(scale>0);
 captured=evalc('m=modelAUTO(history,''s'',1,''diffs'',1,''boxcox'',0,''nofs'',1,''method'',''CML'');');
 assert(any(contains(upper(string(m.table)),'CONDITIONAL')));
 p=m.py(1);assert(isreal(p)&&isfinite(p));
 i=k-initial+1;predictions(i,:)=[p,history(end),mean(history(end-2:end))];scales(i)=scale;foldModels{i}=m;
 spec=strjoin(strtrim(string(m.model))',' | ');
 detail=[detail;table(k,dates(k),dates(k+1),y(k+1),p,p-y(k+1),scale,spec, ...
  'VariableNames',{'TrainingN','TrainingEnd','TargetDate','Actual','Forecast','Error','MASEScale','Model'})];
 if mod(i,10)==0,fprintf('A ROLLING %d/30\n',i);end
 close all;
end
for b=1:3,metrics=[metrics;score("训练期滚动验证",models(b),y(79:108),predictions(:,b),scales)];end
% Fit using only the first 108 values, then lock before evaluating holdout errors.
captured=evalc('finalModel=modelAUTO(y,''s'',1,''diffs'',1,''boxcox'',0,''nofs'',5,''method'',''CML'');');
forecast=finalModel.py(:);assert(numel(forecast)==5&&all(isfinite(forecast))&&isreal(forecast));
save(fullfile(root,'A_arima_forecast_locked.mat'),'finalModel','forecast','foldModels','detail','metrics','y');
actual=[values(109:112);NaN];futureDates=dates(n)+caldays(7*(1:5)');
weights=[4/7;1;1;1;6/7];
future=table((1:5)',futureDates,futureDates+caldays(6),forecast,actual,forecast-actual,weights, ...
 'VariableNames',{'Horizon','PeriodStart','PeriodEnd','Forecast','Actual','Error','OctoberWeight'});
testPred=[forecast(1:4),repmat(y(end),4,1),repmat(mean(y(end-2:end)),4,1)];
for b=1:3,metrics=[metrics;score("固定原点四期测试",models(b),actual(1:4),testPred(:,b),repmat(mean(abs(diff(y))),4,1))];end
spec=strjoin(strtrim(string(finalModel.model))',' | ');
testTotal=sum(actual(1:4));forecastTotal=sum(forecast(1:4));
testSummary=table(spec,forecastTotal,testTotal,forecastTotal-testTotal,100*(forecastTotal-testTotal)/testTotal, ...
 'VariableNames',{'Model','FourPeriodForecast','FourPeriodActual','Error','RelativeErrorPct'});
october=table(sum(weights.*forecast),"按预测周金额在周内均匀分摊；缺少完整十月实际值，未评价十月累计误差", ...
 'VariableNames',{'FullOctoberForecast','Status'});
writetable(detail,fullfile(out,'A_ARIMA逐折预测.csv'),'Encoding','UTF-8');
writetable(metrics,fullfile(out,'A_ARIMA及基准评价.csv'),'Encoding','UTF-8');
writetable(future,fullfile(out,'A_ARIMA固定原点预测.csv'),'Encoding','UTF-8');
writetable(testSummary,fullfile(out,'A_ARIMA四期累计测试.csv'),'Encoding','UTF-8');
writetable(october,fullfile(out,'A_ARIMA十月累计预测_无完整实际值.csv'),'Encoding','UTF-8');
save(fullfile(root,'A_arima_results.mat'),'metrics','detail','future','testSummary','october','finalModel','foldModels');
disp(metrics);disp(testSummary);disp(october);fprintf('A FINAL MODEL: %s\n',spec);
end
function row=score(phase,model,actual,prediction,scale)
e=prediction-actual;den=abs(prediction)+abs(actual);sm=200*abs(e)./den;sm(den==0)=0;
row=table(phase,model,numel(actual),mean(abs(e)),sqrt(mean(e.^2)),mean(sm),mean(abs(e)./scale), ...
 'VariableNames',{'Phase','Model','N','MAE','RMSE','sMAPE','MASE'});
end
