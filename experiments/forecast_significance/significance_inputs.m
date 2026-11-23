function [pairs, validation, inputFiles] = significance_inputs()
% 仅只读既有预测结果；完整核验后返回九组预先指定的配对损失。
here=fileparts(mfilename('fullpath'));experiments=fileparts(here);
dirs=["multi_origin_4step","outlier_sensitivity"];
inputFiles=strings(0,1);tables=cell(2,1);summaries=cell(2,1);
required=["Person","Group","Model","Origin","Horizon","TargetIndex","PeriodStart","Forecast","Actual","Error"];
for j=1:2
 folder=fullfile(experiments,dirs(j),'results');
 files=[fullfile(folder,'多原点四步预测明细.csv');fullfile(folder,'多步预测误差对比.csv');fullfile(folder,'实验核验.json')];
 if j==2,files(end+1)=fullfile(folder,'原始与缩尾模型性能比较.csv');end %#ok<AGROW>
 assert(all(isfile(files)),'缺少已有实验输入');inputFiles=[inputFiles;files]; %#ok<AGROW>
 T=readtable(files(1),'TextType','string','VariableNamingRule','preserve');
 assert(all(ismember(required,string(T.Properties.VariableNames))),'字段不完整');
 assert(height(T)==1296,'已有实验行数不符');
 assert(all(ismember(T.Person,["A","B","C"])));
 numeric=[T.Origin T.Horizon T.TargetIndex T.Forecast T.Actual T.Error];
 assert(all(isfinite(numeric),'all')&&~any(ismissing(T),'all'),'存在缺失值或非有限值');
 assert(all(T.Origin>=78&T.Origin<=104&mod(T.Origin,1)==0));
 assert(all(T.Horizon>=1&T.Horizon<=4&mod(T.Horizon,1)==0));
 assert(all(T.TargetIndex==T.Origin+T.Horizon&T.TargetIndex<=108),'含保留测试周');
 if ~isdatetime(T.PeriodStart),T.PeriodStart=datetime(T.PeriodStart,'InputFormat','yyyy-MM-dd');end
 assert(all(T.PeriodStart==datetime(2024,9,2)+caldays(7*(T.TargetIndex-1))));
 closeEnough(T.Error,T.Forecast-T.Actual);
 key=T(:,{'Person','Group','Model','Origin','Horizon'});assert(height(unique(key))==height(T),'存在重复预测键');
 if j==1,expectedGroups="原始";expectedModels=["RW","LLT","朴素","三期移动平均"];
 else,expectedGroups=["原始","训练缩尾"];expectedModels=["RW","LLT"];end
 assert(isequal(sort(unique(T.Group)),sort(expectedGroups(:))));
 assert(isequal(sort(unique(T.Model)),sort(expectedModels(:))));
 summary=readtable(files(2),'TextType','string');
 for person=["A","B","C"]
  for group=expectedGroups
   for model=expectedModels
    z=sortrows(T(T.Person==person&T.Group==group&T.Model==model,:),{'Origin','Horizon'});
    assert(height(z)==108&&isequal(z.Origin,repelem((78:104)',4))&&isequal(z.Horizon,repmat((1:4)',27,1)));
    for h=0:4
     if h==0,mask=true(height(z),1);else,mask=z.Horizon==h;end
     row=summary(summary.Person==person&summary.Group==group&summary.Model==model&summary.Horizon==h,:);
     assert(height(row)==1&&row.N==sum(mask));closeEnough(row.MAE,mean(abs(z.Error(mask))));
    end
   end
  end
 end
 % 所有相同成员和目标周，无论原点/模型/处理组，实际金额均相同。
 [G,~,~]=findgroups(T.Person,T.TargetIndex);
 spread=splitapply(@(x) max(x)-min(x),T.Actual,G);assert(all(spread<1e-8));
 previous=jsondecode(fileread(files(3)));
 assert(previous.checks.multi_origin_4step.all_checks_passed&&previous.checks.outlier_sensitivity.all_checks_passed);
 tables{j}=T;summaries{j}=summary;
end
for person=["A","B","C"]
 for model=["RW","LLT"]
  x=sortrows(tables{1}(tables{1}.Person==person&tables{1}.Model==model,:),{'Origin','Horizon'});
  y=sortrows(tables{2}(tables{2}.Person==person&tables{2}.Model==model&tables{2}.Group=="原始",:),{'Origin','Horizon'});
  assert(isequal(x(:,{'Origin','Horizon','PeriodStart'}),y(:,{'Origin','Horizon','PeriodStart'})));
  closeEnough(x.Forecast,y.Forecast);closeEnough(x.Actual,y.Actual);
 end
end
% 固定顺序：A/B/C各两个基准比较，最后A/B/C各一个缩尾比较。
people=["A","A","B","B","C","C","A","B","C"];
uc=["LLT","LLT","RW","RW","RW","RW","LLT","RW","RW"];
control=["朴素","三期移动平均","朴素","三期移动平均","朴素","三期移动平均","LLT","RW","RW"];
pairs=cell(9,1);
for i=1:9
 if i<=6,source=1;g1="原始";g2="原始";question="UC与简单基准";
 else,source=2;g1="原始";g2="训练缩尾";question="缩尾与原选UC";end
 T=tables{source};
 x=sortrows(T(T.Person==people(i)&T.Group==g1&T.Model==control(i),:),{'Origin','Horizon'});
 y=sortrows(T(T.Person==people(i)&T.Group==g2&T.Model==uc(i),:),{'Origin','Horizon'});
 assert(height(x)==108&&height(y)==108);
 assert(isequal(x(:,{'Person','Origin','Horizon','PeriodStart'}),y(:,{'Person','Origin','Horizon','PeriodStart'})));
 closeEnough(x.Actual,y.Actual);
 l1=reshape(abs(x.Error),4,27)';l2=reshape(abs(y.Error),4,27)';
 p=struct('id',i,'person',people(i),'question',question,'model1',g1+" "+control(i),'model2',g2+" "+uc(i), ...
  'origins',(78:104)','targets',reshape(x.TargetIndex,4,27)', ...
  'dates',reshape(x.PeriodStart,4,27)','loss1',l1,'loss2',l2,'diff',l1-l2,'meanDiff',mean(l1-l2,2));
 if i>6
  old=readtable(fullfile(experiments,'outlier_sensitivity','results','原始与缩尾模型性能比较.csv'),'TextType','string');
  row=old(old.Person==people(i)&old.Model==uc(i)&old.Stage=="训练内四步回测",:);assert(height(row)==1);
  closeEnough(mean(l1,'all'),row.OriginalMAE);closeEnough(mean(l2,'all'),row.TreatedMAE);
 end
 pairs{i}=p;
end
validation=struct('all_inputs_passed',true,'source_rows',[height(tables{1}),height(tables{2})], ...
 'comparison_count',9,'origin_count',27,'horizon_count',4,'pairs_per_comparison',108, ...
 'origin_range',[78 104],'target_range',[79 108],'heldout_weeks_used',false, ...
 'duplicate_keys',false,'missing_or_nonfinite',false,'raw_uc_predictions_match',true, ...
 'actuals_match_all_pairs',true,'previous_mae_recomputed',true,'previous_receipts_passed',true);
end

function closeEnough(a,b)
assert(isequal(size(a),size(b))&&all(abs(a-b)<=1e-8*max(1,abs(b)),'all'),'输入数值核对失败');
end
