%% 第五步：仅训练期扩展窗口验证，所有模型使用相同目标月份
projectDir=fileparts(mfilename('fullpath')); out=fullfile(projectDir,'output');
s=load(fullfile(out,'step03_UC_models.mat')); tr=s.training;
addpath('C:\Users\86139\AppData\Roaming\MathWorks\MATLAB Add-Ons\Toolboxes\ECOTOOL');
assert(isequal(tr.tTrain(:),datetime(2024,9,1)+calmonths((0:24)')));
series={tr.yTrain(:),tr.regularTrain(:)}; targets=["总支付","常规支付"];
models=["RW","LLT","朴素","三月移动平均"]; initial=15;
rolling=table; comparison=table; stability=table; sensitivity=table;
for a=1:2
 y=series{a}; pred=nan(10,4); scales=nan(10,1);
 for k=16:25
  history=y(1:k-1); scales(k-15)=mean(abs(diff(history)));
  for b=1:4
   reason=""; maxSE=NaN; bound=false;
   try
    if b<=2
     m=modelUC(history,[],char(models(b)),1); pred(k-15,b)=m.py;
     assert(isscalar(m.py)&&isfinite(m.py)&&all(isfinite(m.par)),'参数或预测非有限');
     maxSE=max(sqrt(abs(diag(m.covpar)))); bound=any(abs(m.par)>12)||maxSE>10;
    elseif b==3, pred(k-15,b)=history(end);
    else, pred(k-15,b)=mean(history(end-2:end)); end
   catch err
    pred(k-15,b)=NaN; reason=string(err.message);
   end
   stability=[stability;table(targets(a),models(b),tr.tTrain(k),maxSE,bound,reason,'VariableNames',{'Target','Model','Month','MaxScoreSE','UnstableFlag','Failure'})];
  end
 end
 % 不允许静默删除失败月份，失败即禁止对不完整月份排名。
 writetable(stability,fullfile(out,'UC滚动估计稳定性.csv'),'Encoding','UTF-8');
 assert(all(isfinite(pred),'all'),'存在预测失败，请检查稳定性记录，不得用真实值填补');
 actual=y(16:25); error=pred-actual;
 for b=1:4
  e=error(:,b); den=abs(pred(:,b))+abs(actual); sm=200*abs(e)./den; sm(den==0)=0;
  comparison=[comparison;table(targets(a),models(b),10,mean(abs(e)),sqrt(mean(e.^2)),mean(sm),mean(abs(e)./scales),'VariableNames',{'Target','Model','N','MAE','RMSE','sMAPE','MASE'})];
  rolling=[rolling;table(repmat(targets(a),10,1),repmat(models(b),10,1),tr.tTrain(16:25),actual,pred(:,b),e,scales,'VariableNames',{'Target','Model','Month','Actual','Forecast','Error','MASEScale'})];
  jan=tr.tTrain(16:25)==datetime(2026,1,1); keep=~jan;
  sensitivity=[sensitivity;table(targets(a),models(b),sum(e(jan).^2)/sum(e.^2),sum(abs(e(jan)))/sum(abs(e)),mean(abs(e(keep))),sqrt(mean(e(keep).^2)),'VariableNames',{'Target','Model','JanuarySSEShare','JanuaryAEShare','MAE_WithoutJanuary','RMSE_WithoutJanuary'})];
 end
 f=figure('Visible','off','Color','w'); plot(tr.tTrain(16:25),[actual,pred],'-o'); title(targets(a)+'扩展窗口滚动预测对比'); xlabel('月份'); ylabel('金额（元）'); legend(["真实值",models],'Location','best'); grid on; exportIfMissing(f,out); close(f);
 f=figure('Visible','off','Color','w'); rows=comparison.Target==targets(a); bar([comparison.MAE(rows),comparison.RMSE(rows)]); xticks(1:4); xticklabels(models); title(targets(a)+'滚动预测误差指标比较'); xlabel('模型'); ylabel('金额（元）'); legend('MAE','RMSE'); exportIfMissing(f,out); close(f);
 if a==1
 f=figure('Visible','off','Color','w'); plot(tr.tTrain(16:25),error,'-o'); yline(0,':'); title('总支付各模型滚动预测误差'); xlabel('月份'); ylabel('预测值减真实值（元）'); legend(models,'Location','best'); grid on; exportIfMissing(f,out); close(f);
 end
end
% 事先固定选择规则：UC候选中按MAE优先、RMSE次优排序；基准优劣另行如实报告。
uc=comparison(comparison.Target=="总支付" & ismember(comparison.Model,["RW","LLT"]),:);
uc=sortrows(uc,{'MAE','RMSE'}); selectedModel=uc.Model(1);
save(fullfile(out,'step05_rolling.mat'),'rolling','comparison','stability','sensitivity','selectedModel','tr');
writetable(comparison,fullfile(out,'UC最终模型比较.csv'),'Encoding','UTF-8');
writetable(rolling,fullfile(out,'UC滚动预测明细.csv'),'Encoding','UTF-8');
writetable(sensitivity,fullfile(out,'UC异常月份敏感性.csv'),'Encoding','UTF-8');
writetable(stability,fullfile(out,'UC滚动估计稳定性.csv'),'Encoding','UTF-8');
disp(comparison); disp(sensitivity); fprintf('选定总支付UC模型：%s\n',selectedModel);

function exportIfMissing(fig,out)
% 已存在同标题成对导出时不重复生成；源数据变化后应另行管理旧结果。
ax=findall(fig,'Type','axes'); name=char(string(ax(1).Title.String));
if ~(isfile(fullfile(out,[name '.png']))&&isfile(fullfile(out,[name '.fig'])))
 exportFigureByTitle(fig,out);
end
end
