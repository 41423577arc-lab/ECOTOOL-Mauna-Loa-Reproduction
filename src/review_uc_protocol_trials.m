function review_uc_protocol_trials(roundLimit)
% 独立核对训练边界、变换和逐条误差；完整轮次才输出论文对照报告。
if nargin<1, roundLimit=220; end
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results','comparison','uc_protocol_trials');
D=load(fullfile(out,'checkpoint.mat')); P=D.P;
D=load(fullfile(root,'results','comparison','sliding_480','checkpoint.mat')); old=D.C;
S=load(fullfile(root,'data','dataPLOSpaper.mat'),'CO2'); y=S.CO2(:); assert(isequal(P.y,y)&&isequal(y,old.y));
assert(all(P.done(1:roundLimit,:),'all')&&~any(P.done(roundLimit+1:end,:),'all')&&isempty(P.error));
T=readtable(fullfile(out,'predictions.csv'),'TextType','string'); M=readtable(fullfile(out,'metrics_by_horizon.csv'),'TextType','string');
assert(height(T)==4*roundLimit*24 && height(unique(T(:,{'protocol','round','horizon'})))==height(T));
assert(height(M)==96&&height(unique(M(:,{'protocol','horizon'})))==96);
dates=datetime(1958,3,1)+calmonths((0:722)');
for j=1:4
 Q=sortrows(T(T.protocol==P.config.names(j),:),{'round','horizon'});
 assert(isequal(Q.round,repelem((1:roundLimit)',24))&&isequal(Q.horizon,repmat((1:24)',roundLimit,1)));
 assert(max(abs(Q.actual-y(Q.round+479+Q.horizon)))<1e-9);
 assert(all(datetime(Q.forecast_origin,'InputFormat','yyyy-MM-dd')==dates(Q.round+479))&&all(datetime(Q.target_month,'InputFormat','yyyy-MM-dd')==dates(Q.round+479+Q.horizon)));
 assert(max(abs(Q.predicted-reshape(P.pred(:,j,1:roundLimit),[],1)))<1e-9);
 for r=1:roundLimit
  first=r; if j==2, first=1; end
  train=y(first:r+479); rows=Q.round==r;
  assert(all(Q.train_start(rows)==first)&&all(Q.train_end(rows)==r+479));
  scale=sum(abs(train(13:end)-train(1:end-12)))/(numel(train)-12);
  assert(all(abs(Q.scale(rows)-scale)<1e-10)&&abs(P.scales(r,j)-scale)<1e-10);
  lambda=P.config.lambdaFirst; if j==1, lambda=fminsearch('auxvboxcoxllik',1,optimset('Display','off'),train,12,0); elseif j==4, lambda=.2461; end
  assert(abs(P.lambda(r,j)-lambda)<1e-12&&all(abs(Q.lambda(rows)-lambda)<1e-12));
  if lambda==0, ty=log(train); else, ty=expm1(lambda*log(train))/lambda; end
  c=0; s=1; if j>=3, c=mean(ty); s=std(ty,0); end
  assert(abs(c-P.centers(r,j))<1e-10&&abs(s-P.spreads(r,j))<1e-10);
  fit=P.models{r,j}.fit; assert(max(abs(fit.y(:)-(ty-c)/s))<1e-9&&numel(fit.y)==numel(train));
  assert(isequal(string(fit.model),"LLT12")&&numel(fit.py)==24&&all(isfinite(fit.par)));
  z=fit.py(:)*s+c; assert(all(1+lambda*z>0));
  if lambda==0, p=exp(z); else, p=exp(log1p(lambda*z)/lambda); end
  assert(max(abs(p-P.pred(:,j,r)))<1e-8&&all(isfinite(p)&p>200&p<600));
  assert(all(abs(Q.center(rows)-c)<1e-10)&&all(abs(Q.spread(rows)-s)<1e-10));
 end
 W=sortrows(M(M.protocol==P.config.names(j),:),'horizon'); assert(all(W.rounds==roundLimit));
 for h=1:24
  R=Q(Q.horizon==h,:); e=abs(R.actual-R.predicted); sm=sum(200*e./(abs(R.actual)+abs(R.predicted)))/roundLimit; ma=sum(e./R.scale)/roundLimit;
  assert(abs(W.sMAPE(h)-sm)<1e-9&&abs(W.MASE(h)-ma)<1e-9);
 end
end
fprintf('UC新协议%d轮独立核验PASS，共%d条预测。\n',roundLimit,height(T));
if roundLimit==220
 % 从旧检查点及新CSV独立计算年度指标，不按论文差值搜索参数。
 B=readtable(fullfile(root,'results','comparison','uc_diagnostics','diagnostic_summary.csv'),'TextType','string'); V=table;
 names=["论文UC" "旧扩展逐轮lambda" "旧滑动固定A_lambda" "旧滑动首轮lambda" P.config.names];
 for n=1:numel(names)
  for h=[12 24]
   ps=.114; pm=.290; if h==24, ps=.145; pm=.371; end
   sm=ps; ma=pm; diagnostic=NaN;
   if n>=2 && n<=4
    protocols=["扩展逐轮lambda" "滑动固定A_lambda" "滑动首轮训练lambda"];
    row=B.protocol==protocols(n-1)&B.horizon==h; assert(nnz(row)==1); sm=B.sMAPE(row); ma=B.MASE(row);
   elseif n>=5
    Q=T(T.protocol==names(n)&T.horizon<=h,:); e=abs(Q.actual-Q.predicted);
    sm=mean(200*e./(abs(Q.actual)+abs(Q.predicted))); ma=mean(e./Q.scale);
    diagnostic=mean(e./old.scales(Q.round));
   end
   V=[V;table(names(n),h,sm,ma,sm-ps,ma-pm,diagnostic, ...
    'VariableNames',{'protocol','horizon','sMAPE','MASE','delta_sMAPE','delta_MASE','same_predictions_sliding_scale_MASE'})]; %#ok<AGROW>
  end
 end
 writetable(V,fullfile(out,'comparison.csv'),'Encoding','UTF-8');
 % 同时保留论文全部八行，而非只按年度行判断接近程度。
 paper=readtable(fullfile(root,'results','comparison','table4_comparison.csv'),'TextType','string');
 paper=sortrows(paper(paper.model=="UC",:),'horizon'); F=table;
 for j=1:4
  for k=1:height(paper)
   h=paper.horizon(k); Q=T(T.protocol==P.config.names(j)&T.horizon<=h,:); e=abs(Q.actual-Q.predicted);
   sm=mean(200*e./(abs(Q.actual)+abs(Q.predicted))); ma=mean(e./Q.scale);
   F=[F;table(P.config.names(j),h,sm,ma,paper.paper_sMAPE_percent(k),paper.paper_MASE(k), ...
    sm-paper.paper_sMAPE_percent(k),ma-paper.paper_MASE(k),'VariableNames', ...
    {'protocol','horizon','cumulative_sMAPE','cumulative_MASE','paper_sMAPE','paper_MASE','delta_sMAPE','delta_MASE'})]; %#ok<AGROW>
  end
 end
 writetable(F,fullfile(out,'table4_comparison.csv'),'Encoding','UTF-8');
 fid=fopen(fullfile(out,'report.md'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
 fprintf(fid,'# UC协议及数值稳定性补充实验\n\n');
 fprintf(fid,'本次预先限定四组方案，均使用作者原有modelUC(x, [], ''LLT12'',24)，不改变结构、阶数、估计方法或异常值阈值，不手工指定初值。不根据论文误差搜索lambda。四组各220轮，合计21120条预测；旧结果完整保留。\n\n');
 fprintf(fid,'1. 滑动480月，每轮只用训练集估计Box-Cox lambda。\n2. 扩展窗口，固定首轮训练lambda。\n3. 滑动480月，固定首轮训练lambda，并对变换后的训练序列中心化、除以当轮样本标准差。\n4. 滑动480月，固定A的0.2461，并做同样标准化；该组保留A参数前视风险，仅作协议诊断。\n\n');
 fprintf(fid,'标准化只用训练数据：x=(ty-mean(ty))/std(ty)，UC预测先乘回标准差、加回均值，再逆Box-Cox到ppm。仿射缩放在理论上不改变线性高斯UC模型族，但有限精度实现、默认初始化和优化路径未必具有严格尺度不变性；若预测变化，应视为数值实现敏感性的证据，不等于更换了新阶数模型。\n\n');
 fprintf(fid,'所有指标均为220轮、前12或24步累计平均；sMAPE单位为百分数。扩展窗口MASE使用当轮全部训练数据的分母，比较表另列相同预测改用480月分母的诊断列，不能将两种尺度混为同一正式结果。\n\n');
 fprintf(fid,'|协议|1年sMAPE|2年sMAPE|1年MASE|2年MASE|\n|---|---:|---:|---:|---:|\n');
 for n=1:numel(names)
  R=sortrows(V(V.protocol==names(n),:),'horizon'); fprintf(fid,'|%s|%.6f|%.6f|%.6f|%.6f|\n',names(n),R.sMAPE(1),R.sMAPE(2),R.MASE(1),R.MASE(2));
 end
 fprintf(fid,'\n## 与论文的差异\n\n');
 for j=1:4
  R=sortrows(V(V.protocol==P.config.names(j),:),'horizon');
  fprintf(fid,'- %s：1年/2年sMAPE差值为%+.6f / %+.6f个百分点，MASE差值为%+.6f / %+.6f。\n',P.config.names(j),R.delta_sMAPE(1),R.delta_sMAPE(2),R.delta_MASE(1),R.delta_MASE(2));
 end
 fprintf(fid,'\n标准化对照：\n\n');
 for j=3:4
  oldj=6; if j==4, oldj=3; end
  oldpred=reshape(old.pred(:,oldj,:),24,220); p=reshape(P.pred(:,j,:),24,220);
  fprintf(fid,'- %s与同窗口同lambda未标准化结果相比，最大预测差异%.9f ppm，平均绝对预测差异%.9f ppm。\n',P.config.names(j),max(abs(p-oldpred),[],'all'),mean(abs(p-oldpred),'all'));
 end
 fprintf(fid,'\n论文全部八种期限（1至6、12、24步）的对照见table4_comparison.csv。以下统计仅说明按论文三位小数精度重现了多少个单元格，不作为参数搜索目标。\n\n');
 for j=1:4
  R=F(F.protocol==P.config.names(j),:);
  matched=sum(round(R.cumulative_sMAPE,3)==round(R.paper_sMAPE,3))+sum(round(R.cumulative_MASE,3)==round(R.paper_MASE,3));
  fprintf(fid,'- %s：16个论文数值中有%d个按三位小数一致。\n',P.config.names(j),matched);
 end
 fprintf(fid,'\n## 结论\n\n');
 fprintf(fid,'在预先限定的四个补充方案中，滑动480月、固定首轮训练lambda并标准化，是无前视方案中四个年度指标都最接近论文的一组。它相对旧无前视固定lambda结果有所改善，但1年、2年均未达到论文三位小数精度。含A参数的标准化组四项指标更接近论文，仍有前视风险，不能因此优先作为正式无前视复现协议。\n\n');
 fprintf(fid,'尺度对照只改变训练期的可逆仿射重标度，恢复ppm后预测仍明显变化，因此当前UC实现的默认估计或初始化对数值尺度敏感。此试验不能区分有限精度、优化停止准则、初值及状态初始化各自的贡献，也不能据此直接断定软件存在某一个已定位的缺陷。\n\n');
 fprintf(fid,'逐轮lambda和扩展窗口固定lambda未填平论文差距；前者两年结果与旧滑动固定首轮lambda接近，后者的MASE还受到扩展训练分母影响。由此，没有证据支持仅调整左边界、重估lambda或改方法标签就能精确重现Table 4。剩余差异需作者完整滚动设置及2019年实际计算环境进一步核对，不应继续针对Table 4目标搜索lambda或手工修改预测。\n\n');
 fprintf(fid,'\n本次先做3轮检查并通过独立核验，再从有效检查点续跑；所有既有预测不重估。记录的MATLAB为%s、ECOTOOL为%s；依赖指纹、实际模型输入、参数、完整估计表、恢复尺度参数及耗时均在checkpoint.mat。\n\n',P.env.matlab,strjoin(P.env.ecotool.Version,','));
 fprintf(fid,'本次指标是对同一历史样本的补充探索；不能因为某组最接近Table 4就断言其等同原作者协议，也不能将探索后选出的方案当作独立测试集验证。论文未公开完整220轮滚动程序，UC后端是加密P代码，初值和内部优化的剩余差异尚不能唯一定位。\n\n');
 fprintf(fid,'作者版本核对：2020、2021及2023工具箱包中的modelUC.m与modelUC0.p指纹一致，也与本机一致。2020包和当前核对包各144个代码文件，逐文件哈希比较仅vscatter.m和mmVAR.p不同，UC入口、后端及已识别的UC辅助代码没有变化。详见author_versions.txt；这削弱了“换一个已公开历史UC后端就能改善”的解释，但加密代码不能完整追踪依赖，不能证明整个调用链等效，也不确认2019年实际MATLAB优化器及完整滚动环境。未替换本机工具箱。\n\n');
 fprintf(fid,'复跑：在项目根目录执行`addpath(''src''); run_uc_protocol_trials(220,2); review_uc_protocol_trials(220);`。仅核验时直接调用review_uc_protocol_trials，不会拟合。核验PASS覆盖预测覆盖、日期、训练边界、变换和原尺度恢复及评价公式，不证明优化器收敛。\n');
 disp(V);
end
fid=fopen(fullfile(out,'audit.txt'),'w','n','UTF-8'); fprintf(fid,'PASS：%d轮、%d条预测，四组逐轮训练边界、日期、真实值、lambda、标准化与逆变换、每步sMAPE及MASE已独立核验。\n时间：%s\n',roundLimit,height(T),char(datetime('now'))); fclose(fid);
end
