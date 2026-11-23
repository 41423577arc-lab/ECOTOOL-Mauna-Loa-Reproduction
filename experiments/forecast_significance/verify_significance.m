function verification=verify_significance()
% 独立重建配对；用矩阵二次型核验HAC，以另一实现核验Holm和Bootstrap。
here=string(fileparts(mfilename('fullpath')));out=fullfile(here,'results');root=fileparts(fileparts(here));
S=load(fullfile(out,'统计检验完整结果.mat'));T=readtable(fullfile(out,'预测损失差异检验.csv'),'TextType','string','VariableNamingRule','preserve');
O=readtable(fullfile(out,'原点级预测损失差.csv'),'TextType','string','VariableNamingRule','preserve');
D=readtable(fullfile(out,'不同预测步长损失差.csv'),'TextType','string','VariableNamingRule','preserve');
HS=readtable(fullfile(out,'HAC滞后稳健性.csv'),'TextType','string','VariableNamingRule','preserve');
BS=readtable(fullfile(out,'区块长度敏感性.csv'),'TextType','string','VariableNamingRule','preserve');
assert(height(T)==9&&height(O)==243&&height(D)==972&&height(HS)==36&&height(BS)==27);
assert(isequal(T.('比较编号'),(1:9)'));
assert(S.cfg.main_lag==3&&S.cfg.main_block==4&&S.cfg.bootstrap_repetitions==10000&&S.cfg.alpha==.05&&S.cfg.base_seed==20261123);
assert(isequal(S.cfg.lags,[2 3 4 6])&&isequal(S.cfg.blocks,[3 4 5]));
people=["A","A","B","B","C","C","A","B","C"];
models1=["朴素","三期移动平均","朴素","三期移动平均","朴素","三期移动平均","LLT","RW","RW"];
models2=["LLT","LLT","RW","RW","RW","RW","LLT","RW","RW"];
source1=readtable(fullfile(root,'experiments','multi_origin_4step','results','多原点四步预测明细.csv'),'TextType','string');
source2=readtable(fullfile(root,'experiments','outlier_sensitivity','results','多原点四步预测明细.csv'),'TextType','string');
originalRng=rng;restoreRng=onCleanup(@() rng(originalRng));
for i=1:9
 if i<=6,source=source1;g2="原始";else,source=source2;g2="训练缩尾";end
 x=sortrows(source(source.Person==people(i)&source.Group=="原始"&source.Model==models1(i),:),{'Origin','Horizon'});
 y=sortrows(source(source.Person==people(i)&source.Group==g2&source.Model==models2(i),:),{'Origin','Horizon'});
 assert(T.('成员')(i)==people(i)&&T.('对照模型')(i)=="原始 "+models1(i)&&T.('比较模型')(i)==g2+" "+models2(i));
 assert(height(x)==108&&height(y)==108&&isequal(x.Origin,y.Origin)&&isequal(x.Horizon,y.Horizon));
 assert(isequal(x.PeriodStart,y.PeriodStart));near(x.Actual,y.Actual);
 assert(all(x.TargetIndex<=108&y.TargetIndex<=108));
 l1=abs(x.Forecast-x.Actual);l2=abs(y.Forecast-y.Actual);dif=l1-l2;
 mu=zeros(27,1);
 for n=78:104
  rows=x.Origin==n;assert(sum(rows)==4&&isequal(x.Horizon(rows),(1:4)'));mu(n-77)=sum(dif(rows))/4;
 end
 oi=sortrows(O(O.('比较编号')==i,:),'预测原点');di=sortrows(D(D.('比较编号')==i,:),{'预测原点','预测步长'});
 assert(isequal(oi.('预测原点'),(78:104)'));near(oi.('四步平均损失差'),mu);
 near(di.('损失差'),dif);near(di.('对照绝对损失'),l1);near(di.('比较绝对损失'),l2);
 near(di.('目标周索引'),x.TargetIndex);
 targetDates=datetime(string(di.('目标周起始日')));expectedDates=datetime(string(x.PeriodStart));
 assert(isequal(targetDates,expectedDates));
 near(T.('平均损失差')(i),mean(mu));near(T.('对照MAE')(i),mean(l1));near(T.('比较MAE')(i),mean(l2));
 near(T.('MAE改善率百分比')(i),100*(mean(l1)-mean(l2))/mean(l1));
 assert(T.('原点数')(i)==27&&T.('逐项配对数')(i)==108);
 % 独立的Toeplitz Bartlett核矩阵，无调用主程序的自协方差循环。
 for lag=[2 3 4 6]
  u=mu-mean(mu);distance=abs((1:27)'-(1:27));W=max(0,1-distance/(lag+1));
  variance=u'*W*u/27^2;assert(variance>0);se=sqrt(variance);z=mean(mu)/se;
  p=2*normcdf(-abs(z));
  r=HS(HS.('比较编号')==i&HS.('HAC滞后')==lag,:);assert(height(r)==1);
  near(r.('HAC标准误'),se);near(r.('长期方差'),variance*27);near(r.('检验统计量'),z);near(r.('原始p值'),p);
  if lag==3,near(T.('HAC标准误')(i),se);near(T.('检验统计量')(i),z);near(T.('原始p值')(i),p);end
 end
 % 重建每个区块路径，以逐位置求和替代主程序的逐路径拼接。
 for j=1:3
  block=S.cfg.blocks(j);B=10000;seed=20261123+1000*i+block;
  rng(seed,'twister');start=randi(27-block+1,ceil(27/block),B);total=zeros(1,B);
  for position=1:27
   row=floor((position-1)/block)+1;offset=mod(position-1,block);
   values=mu(start(row,:)+offset);total=total+values(:)';
  end
  means=total(:)/27;near(means,S.bootstrapMeans{i,j});
  sorted=sort(means);ci=[manualPercentile(sorted,.025),manualPercentile(sorted,.975)];
  r=BS(BS.('比较编号')==i&BS.('区块长度')==block,:);assert(height(r)==1&&r.('随机种子')==seed&&r.('重复次数')==B);
  near(r.('区间下限'),ci(1));near(r.('区间上限'),ci(2));near(r.('Bootstrap均值'),mean(means));
  assert(r.('区间排除零')==(ci(1)>0||ci(2)<0));
  if block==4,near(T.('Bootstrap区间下限')(i),ci(1));near(T.('Bootstrap区间上限')(i),ci(2));end
 end
end
% 独立逐步Holm实现，并对每个预先固定滞后的九组家族分别复核。
for lag=[2 3 4 6]
 r=sortrows(HS(HS.('HAC滞后')==lag,:),'比较编号');
 adjusted=independentHolm(r.('原始p值'));near(adjusted,r.('Holm校正p值'));
 assert(isequal(r.('原始显著'),r.('原始p值')<.05)&&isequal(r.('Holm校正显著'),adjusted<.05));
 if lag==3,near(adjusted,T.('Holm校正p值'));end
end
assert(isequal(T.('原始显著'),T.('原始p值')<.05));
assert(isequal(T.('Holm校正显著'),T.('Holm校正p值')<.05));
assert(isequal(T.('Bootstrap区间排除零'),T.('Bootstrap区间下限')>0|T.('Bootstrap区间上限')<0));
assert(isequal(string(T.Properties.VariableNames),string(S.results.Properties.VariableNames)));
for name=string(T.Properties.VariableNames)
 if isnumeric(T.(name))||islogical(T.(name)),near(double(T.(name)),double(S.results.(name)));
 else,assert(isequal(string(T.(name)),string(S.results.(name))));end
end
expected=repmat("未达到Holm校正后显著",9,1);
expected(T.('Holm校正显著')&T.('平均损失差')>0)="模型2显著更优（探索性）";
expected(T.('Holm校正显著')&T.('平均损失差')<0)="模型1显著更优（探索性）";
assert(isequal(T.('显著性结论'),expected));
for k=1:numel(S.inputHashes)
 path=fullfile(root,S.inputHashes(k).relative_path);
 assert(isfile(path)&&file_sha256(path)==S.inputHashes(k).sha256,'统计输入指纹已变化');
end
% 简单已知例子用于防止Holm排序/回填方向错误，不依赖本轮数据。
near(independentHolm([.01;.04;.03]),[.03;.06;.06]);
near(independentHolm([0;1;1]),[0;1;1]);
report=string(fileread(fullfile(out,'预测性能显著性检验报告.md')));
assert(contains(report,'![预测损失差置信区间](预测损失差置信区间.png)'));
assert(isfile(fullfile(out,'预测损失差置信区间.png')));
pic=imfinfo(fullfile(out,'预测损失差置信区间.png'));assert(pic.Width>1000&&pic.Height>500);
required=["选择后","Ljung","27","Holm","108","未拒绝","不属于全新盲测","统计显著不自动","异方差","弱依赖"];
assert(all(contains(report,required)),'报告方法限制不完整');
verification=struct('all_checks_passed',true,'input_validation',S.validation,'parameters',S.cfg, ...
 'independent_checks',{{'独立重建972条有符号配对损失','243条原点均值与九组MAE复算','36组HAC矩阵二次型复核', ...
 'Holm排序回填与已知例子复核','27组Bootstrap独立逐位置重采样及百分位数复核', ...
 '全部输入SHA256未变化','未使用109至112周','中文报告限制项及图片链接检查'}}, ...
 'input_sha256',S.inputHashes,'run_time',string(datetime('now','TimeZone','Asia/Shanghai','Format','yyyy-MM-dd HH:mm:ss Z')), ...
 'matlab_version',string(version),'no_model_refit',true,'no_ecotool_call',true);
codeFiles=dir(fullfile(here,'*.m'));codeHashes=struct('file',{},'sha256',{});
for k=1:numel(codeFiles),codeHashes(k)=struct('file',string(codeFiles(k).name),'sha256',file_sha256(fullfile(here,codeFiles(k).name)));end
verification.code_sha256=codeHashes;
fid=fopen(fullfile(out,'实验核验.json'),'w','n','UTF-8');assert(fid>=0);done=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(verification,'PrettyPrint',true));
fprintf('VERIFY_SIGNIFICANCE_PASSED\n');
end

function near(a,b)
assert(isequal(size(a),size(b))&&all(isfinite(a),'all')&&all(abs(a-b)<=1e-8*max(1,abs(b)),'all'),'独立数值核验失败');
end

function adjusted=independentHolm(p)
[ordered,rank]=sort(p);adjusted=zeros(size(p));last=0;
for j=1:numel(p),last=max(last,min(1,(numel(p)-j+1)*ordered(j)));adjusted(rank(j))=last;end
end

function q=manualPercentile(sorted,p)
position=numel(sorted)*p+.5;low=floor(position);high=ceil(position);
low=max(1,min(numel(sorted),low));high=max(1,min(numel(sorted),high));
q=sorted(low)+(position-floor(position))*(sorted(high)-sorted(low));
end
