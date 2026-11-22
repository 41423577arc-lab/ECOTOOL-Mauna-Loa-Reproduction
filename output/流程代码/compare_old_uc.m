function compare_old_uc(projectRoot)
% 同数据逐项复现检查；跨人、跨粒度仅比较结论，不要求金额一致。
if exist('modelUC','file')~=2
    configure_ecotool();
end
out=fullfile(projectRoot,'output');
old=projectRoot+"_整理前备份_20261123";
people=["cyx","tg","yyl"];
summary=table; conclusion=table;
inputDates=cell(3,1);inputValues=cell(3,1);
oldDirs=[fullfile(old,'output'),fullfile(old,'自然周分析','output'),fullfile(old,'连续七天分析','output')];
labels=["旧yyl月度","旧yyl自然周","旧yyl连续七天"];
for person=people
    p=fullfile(out,person);
    r=load(fullfile(p,'step05_rolling.mat'));
    e=load(fullfile(p,'step06_evaluation.mat'));
    d=load(fullfile(p,'step04_UC_diagnostics.mat'));
    selected=r.selected(1);
    personIndex=find(people==person,1);
    inputDates{personIndex}=[r.tr.tTrain;r.tr.tTest];
    inputValues{personIndex}=[r.tr.yTrain;e.evaluation.Actual];
    row=r.summary(r.summary.Model==selected,:);
    best=sortrows(r.summary,{'MAE','RMSE'});
    rwPass=all(~d.diagnosticSummary.RejectH0(d.diagnosticSummary.Model=="总支付-RW"));
    lltPass=all(~d.diagnosticSummary.RejectH0(d.diagnosticSummary.Model=="总支付-LLT"));
    summary=[summary;table(person,selected,best.Model(1),row.MAE,row.RMSE,row.sMAPE,row.MASE,rwPass,lltPass, ...
        e.aggregate.MAE(1),e.aggregate.RMSE(1),e.aggregate.ForecastSum(1),e.aggregate.ActualSum(1), ...
        'VariableNames',{'Person','SelectedUC','LowestMAEAllModels','RollingMAE','RollingRMSE','RollingSMAPE','RollingMASE', ...
        'RWPassResidualLB','LLTPassResidualLB','TestMAE','TestRMSE','ForecastSum','ActualSum'})]; %#ok<AGROW>
    for j=1:3
        or=load(fullfile(oldDirs(j),'step05_rolling.mat'));
        if isfield(or,'selected'),oldSelected=string(or.selected(1));
        else,oldSelected=string(or.selectedModel);end
        od=readtable(fullfile(oldDirs(j),'UC模型残差诊断汇总.csv'),'TextType','string');
        oldRW=all(~od.RejectH0(od.Model=="总支付-RW"));
        oldLLT=all(~od.RejectH0(od.Model=="总支付-LLT"));
        relation="不同人员，仅作结论参照";
        if person=="yyl" && j==2,relation="同人同数据同流程，可直接复现";
        elseif person=="yyl",relation="同人不同时间聚合，仅作结论参照";end
        conclusion=[conclusion;table(person,labels(j),relation,selected,oldSelected,selected==oldSelected, ...
            rwPass,oldRW,rwPass==oldRW,lltPass,oldLLT,lltPass==oldLLT, ...
            'VariableNames',{'Person','Baseline','ComparisonScope','NewSelectedUC','OldSelectedUC','SameSelection', ...
            'NewRWPass','OldRWPass','SameRWConclusion','NewLLTPass','OldLLTPass','SameLLTConclusion'})]; %#ok<AGROW>
    end
end
writetable(summary,fullfile(out,'三人UC结果汇总.csv'),'Encoding','UTF-8');
writetable(conclusion,fullfile(out,'与旧结果结论对照.csv'),'Encoding','UTF-8');
inputDifference=table;
for i=1:2
 for j=i+1:3
    assert(isequal(inputDates{i},inputDates{j}));
    difference=inputValues{i}-inputValues{j};
    changed=abs(difference)>1e-8;
    inputDifference=[inputDifference;table(people(i),people(j),sum(~changed),sum(changed),sum(difference), ...
        'VariableNames',{'FileA','FileB','EqualWeeks','DifferentWeeks','SumAminusB'})]; %#ok<AGROW>
 end
end
writetable(inputDifference,fullfile(out,'三份输入差异核对.csv'),'Encoding','UTF-8');

% 旧自然周输入由旧训练MAT+旧独立测试MAT拼合，避免仅凭文件名认定同数据。
oldWeek=oldDirs(2); newWeek=fullfile(out,'yyl');
oldModel=load(fullfile(oldWeek,'step03_UC_models.mat'),'sourceSignature');
toolboxFunctions=["modelUC","auxmodelUC","clliket"];
sameImplementation=false(3,1);
for k=1:3
    sameImplementation(k)=isequal(oldModel.sourceSignature{k+1},fileread(which(toolboxFunctions(k))));
end
toolboxCheck=table(toolboxFunctions',sameImplementation,'VariableNames',{'Function','SourceExactlyEqual'});
writetable(toolboxCheck,fullfile(out,'ECOTOOL实现核对.csv'),'Encoding','UTF-8');
assert(all(sameImplementation),'ECOTOOL可读实现与旧运行时不同，不能声称同实现复现。');
ot=load(fullfile(oldWeek,'step01_training_data.mat'));
nt=load(fullfile(newWeek,'step01_training_data.mat'));
oe=load(fullfile(oldWeek,'step06_evaluation.mat'));
ne=load(fullfile(newWeek,'step06_evaluation.mat'));
otest=oe.evaluation(oe.evaluation.Target=="总支付",:);
assert(isequal(nt.tTrain,ot.tTrain) && isequal(nt.tTest,ot.tTest));
assert(isequal(nt.yTrain,ot.yTrain) && isequal(ne.evaluation.Actual,otest.Actual), ...
    '新yyl与旧自然周输入并非完全一致，不可声称同数据复现。');
inputCheck=table(["训练日期";"训练金额";"测试日期";"测试金额"],[108;108;4;4],true(4,1), ...
    'VariableNames',{'Item','N','ExactlyEqual'});
writetable(inputCheck,fullfile(out,'yyl输入逐项核对.csv'),'Encoding','UTF-8');

files=["UC模型样本内拟合指标.csv","UC模型参数估计.csv","UC模型残差诊断汇总.csv", ...
    "UC模型残差分布统计.csv","UC模型异常残差候选.csv","UC最终模型比较.csv", ...
    "UC滚动预测明细.csv","UC滚动估计稳定性.csv","UC异常月份敏感性.csv", ...
    "UC最终模型参数.csv","UC最终预测结果.csv","UC独立测试汇总.csv"];
checks=table;
for file=files
    a=readtable(fullfile(newWeek,file),'TextType','string');
    b=readtable(fullfile(oldWeek,file),'TextType','string');
    if ismember('Target',b.Properties.VariableNames),b=b(b.Target=="总支付",:);
    else,b=b(contains(b.Model,"总支付"),:);end
    assert(isequal(a.Properties.VariableNames,b.Properties.VariableNames) && height(a)==height(b), ...
        '新旧比较表结构不同：%s',file);
    for field=string(a.Properties.VariableNames)
        av=a.(field); bv=b.(field);
        difference=NaN; tolerance=NaN;
        if field=="Failure"
            av=string(av);bv=string(bv);
            av(ismissing(a.(field)))="";bv(ismissing(b.(field)))="";
            same=isequaln(av,bv);
        elseif (isnumeric(av) || islogical(av)) && (isnumeric(bv) || islogical(bv))
            av=double(av);bv=double(bv);
            sameMissing=isequal(isnan(av),isnan(bv)) && isequal(isinf(av),isinf(bv));
            finite=isfinite(av)&isfinite(bv);
            if any(finite)
                difference=max(abs(av(finite)-bv(finite)));
                tolerance=1e-6+1e-8*max(abs(bv(finite)));
            else,difference=0;tolerance=1e-6;end
            same=sameMissing && difference<=tolerance;
        else
            same=isequaln(av,bv);
        end
        checks=[checks;table(file,field,height(a),difference,tolerance,same, ...
            'VariableNames',{'File','Column','N','MaxAbsDifference','Tolerance','Match'})]; %#ok<AGROW>
    end
end
writetable(checks,fullfile(out,'yyl新旧数值逐项核对.csv'),'Encoding','UTF-8');

% 用新旧同一模型的全部滚动预测、残差检验与保留测试预测来核验结论。
reproduced=all(checks.Match);
coreReproduced=all(checks.Match(checks.File~="UC滚动估计稳定性.csv"));
oldStability=readtable(fullfile(oldWeek,'UC滚动估计稳定性.csv'),'TextType','string');
oldStability=oldStability(oldStability.Target=="总支付",:);
newStability=readtable(fullfile(newWeek,'UC滚动估计稳定性.csv'),'TextType','string');
oldStability=oldStability(ismember(oldStability.Model,["RW","LLT"]),:);
newStability=newStability(ismember(newStability.Model,["RW","LLT"]),:);
oldFailures=sum(~ismissing(oldStability.Failure) & strlength(string(oldStability.Failure))>0);
newFailures=sum(~ismissing(newStability.Failure) & strlength(string(newStability.Failure))>0);
stabilityDifference=table(["旧yyl自然周";"新yyl自然周"],[oldFailures;newFailures], ...
    [sum(isnan(oldStability.MaxScoreSE));sum(isnan(newStability.MaxScoreSE))], ...
    'VariableNames',{'Run','LoggedFailureRows','MissingScoreSERows'});
writetable(stabilityDifference,fullfile(out,'旧稳定性日志差异.csv'),'Encoding','UTF-8');
fprintf('YYL_REPRODUCED=%d；检查%d个列项目。\n',reproduced,height(checks));
disp(summary);disp(conclusion);
save(fullfile(out,'新旧比较.mat'),'summary','conclusion','checks','inputCheck','reproduced','coreReproduced','stabilityDifference');
write_uc_report(projectRoot);
end
