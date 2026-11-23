function passed=audit_bc_sliding480(rounds)
% 独立从原始数据和导出CSV重算，不复用运行或汇总程序的误差实现。
if nargin<1, rounds=220; end
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results','comparison','sliding_480');
passed=false; checks=strings(0,1); tol=1e-9;
try
 % 核验作者固定版本的完整文件，避免仅凭观测数接受其他数据版本。
 fid=fopen(fullfile(root,'data','dataPLOSpaper.mat'),'rb'); assert(fid>=0);
 bytes=fread(fid,Inf,'*uint8'); fclose(fid);
 md=java.security.MessageDigest.getInstance('SHA-256'); md.update(typecast(bytes,'int8'));
 digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
 assert(strcmp(digest,'4227a1d932b5765418957df172b767e5a9db3422979be01e5e56eb4ad7d25092'));
 checks(end+1)="作者固定MAT数据的完整文件SHA-256通过。";
 S=load(fullfile(root,'data','dataPLOSpaper.mat'),'CO2'); y=S.CO2(:);
 D=load(fullfile(out,'checkpoint.mat'),'C'); C=D.C;
 assert(isequal(C.y,y)&&numel(y)==723 && isequal(size(C.done),[220 6]));
 assert(all(C.done(1:rounds,:),'all') && ~any(C.done(rounds+1:end,:),'all'));
 assert(isempty(C.error) && all(isfinite(C.seconds(C.done))) && all(C.seconds(C.done)>=0));
 first=fminsearch('auxvboxcoxllik',1,optimset('Display','off'),y(1:480),12,0);
 single=fminsearch('auxvboxcoxllik',1,optimset('Display','off'),y(25:504),12,0);
 assert(C.config.lambdaA==.2461 && abs(C.config.lambdaFirst-first)<1e-12 && abs(C.config.lambdaSingle-single)<1e-12);
 assert(abs(round(single,4)-.2461)<1e-12 && abs(first-.2461)>.1);
 checks(end+1)=sprintf('lambda来源：首轮训练%.12f；单次25:504为%.12f；照A主实验存在前视风险，补充实验单独保存。',first,single);
 dates=datetime(1958,3,1)+calmonths((0:722)');
 for group=1:2
  prefix=''; js=1:4; if group==2, prefix='first_train_lambda_'; js=5:6; end
  T=readtable(fullfile(out,[prefix 'predictions.csv']),'TextType','string');
  M=readtable(fullfile(out,[prefix 'metrics_by_horizon.csv']),'TextType','string');
  assert(height(T)==numel(js)*rounds*24 && height(M)==numel(js)*24);
  assert(height(unique(T(:,{'model','round','horizon'})))==height(T));
  assert(height(unique(M(:,{'model','horizon'})))==height(M));
  assert(isequal(sort(unique(T.model)),sort(C.config.names(js)')));
  for j=js
   name=C.config.names(j); Q=sortrows(T(T.model==name,:),{'round','horizon'});
   assert(isequal(Q.round,repelem((1:rounds)',24)) && isequal(Q.horizon,repmat((1:24)',rounds,1)));
   assert(all(Q.train_start==Q.round & Q.train_end==Q.round+479 & Q.train_end-Q.train_start+1==480));
   assert(all(datetime(Q.forecast_origin,'InputFormat','yyyy-MM-dd')==dates(Q.round+479)));
   assert(all(datetime(Q.target_month,'InputFormat','yyyy-MM-dd')==dates(Q.round+479+Q.horizon)));
   assert(max(abs(Q.actual-y(Q.round+479+Q.horizon)))<tol);
   assert(all(isfinite(Q.predicted)&Q.predicted>200&Q.predicted<600) && isreal(Q.predicted));
   assert(max(abs(Q.predicted-reshape(C.pred(:,j,1:rounds),[],1)))<tol);
   for r=1:rounds
    train=y(r:r+479); scale=sum(abs(train(13:480)-train(1:468)))/468;
    assert(abs(C.scales(r)-scale)<tol && all(abs(Q.scale(Q.round==r)-scale)<tol));
    assert(isequal(C.actual(:,r),y(r+480:r+503)));
    p=C.pred(:,j,r); meta=C.models{r,j}; assert(~isempty(meta));
    if j~=4
     assert(~isempty(meta.table) && all(isfinite(meta.par)));
     if r==1
      lines=string(cellstr(meta.table)); methods=strtrim(lines(contains(lines,'Estimation method:')));
      checks(end+1)=prefix+name+"实际估计表："+strjoin(methods,'；');
     end
    end
    if j==4
     % 检查已保存OLS参数的正规方程与逐步递推，不再次估计。
     X=ones(468,13); for lag=1:12, X(:,lag+1)=train(13-lag:480-lag); end
     residual=train(13:480)-X*meta.beta;
     assert(norm(X'*residual,inf)/(norm(X,'fro')*norm(train(13:480)))<1e-10);
     hist=[train;p]; for h=1:24, assert(abs(p(h)-[1 hist(480+h-(1:12))']*meta.beta)<tol); end
    elseif j==2
     assert(isequal(meta.input,train) && meta.boxcox==1 && isnan(meta.lambdaExternal));
     assert(max(abs(p-meta.rawForecast))<tol);
    else
     lambda=.2461; if j>4, lambda=first; end
     assert(meta.lambdaExternal==lambda);
     transformed=expm1(lambda*log(train))/lambda;
     assert(max(abs(meta.input-transformed))<1e-10);
     assert(all(1+lambda*meta.rawForecast>0));
     inverse=exp(log1p(lambda*meta.rawForecast)/lambda);
     assert(max(abs(p-inverse))<tol);
    end
   end
   W=sortrows(M(M.model==name,:),'horizon'); assert(isequal(W.horizon,(1:24)') && all(W.rounds==rounds));
   % 按步逐条求和，再除轮数，与运行程序的矩阵均值实现相互独立。
   for h=1:24
    U=Q(Q.horizon==h,:); err=abs(U.actual-U.predicted);
    sm=sum(200*err./(abs(U.actual)+abs(U.predicted)))/rounds;
    ma=sum(err./U.scale)/rounds;
    assert(abs(W.sMAPE_percent(h)-sm)<tol && abs(W.MASE(h)-ma)<tol);
   end
   checks(end+1)=sprintf('%s%s：%d条；480月边界、日期、真实值、ppm、参数、逆变换和24步误差全部通过。',prefix,name,height(Q)); %#ok<AGROW>
  end
 end
 if rounds==220
  V=readtable(fullfile(out,'table4_comparison.csv'),'TextType','string');
  J=readtable(fullfile(out,'mase_decomposition.csv'),'TextType','string');
  O=readtable(fullfile(root,'results','comparison','all_models_predictions.csv'),'TextType','string');
  P=readtable(fullfile(root,'results','comparison','table4_comparison.csv'),'TextType','string');
  assert(height(V)==112 && height(unique(V(:,{'model','protocol','horizon'})))==112 && height(J)==8);
  for k=1:height(V)
   name=V.model(k); protocol=V.protocol(k); h=V.horizon(k);
   if startsWith(protocol,'原A'), continue; end
   if startsWith(protocol,'此前'), T=O;
   elseif protocol=="本次滑动480照A", T=readtable(fullfile(out,'predictions.csv'),'TextType','string');
   else, T=readtable(fullfile(out,'first_train_lambda_predictions.csv'),'TextType','string'); end
   Q=T(T.model==name & T.horizon<=h,:); assert(height(Q)==220*h);
   e=abs(Q.actual-Q.predicted); s=200*e./(abs(Q.actual)+abs(Q.predicted)); m=e./Q.scale;
   assert(abs(V.cumulative_sMAPE_percent(k)-sum(s)/height(Q))<tol && abs(V.cumulative_MASE(k)-sum(m)/height(Q))<tol);
   point=Q.horizon==h; assert(abs(V.point_sMAPE_percent(k)-mean(s(point)))<tol && abs(V.point_MASE(k)-mean(m(point)))<tol);
   paper=P(P.model==name & P.horizon==h,:);
   assert(isequaln(V.paper_sMAPE_percent(k),paper.paper_sMAPE_percent) && isequaln(V.paper_MASE(k),paper.paper_MASE));
   if name=="AR12", assert(isnan(V.delta_sMAPE(k)) && isnan(V.delta_MASE(k)));
   else, assert(abs(V.delta_sMAPE(k)-(V.cumulative_sMAPE_percent(k)-V.paper_sMAPE_percent(k)))<tol && abs(V.delta_MASE(k)-(V.cumulative_MASE(k)-V.paper_MASE(k)))<tol); end
  end
  % 原A结果直接读取固定提交的原始误差矩阵，独立复算而非信赖汇总CSV。
  tmp=[tempname '.mat']; cl=onCleanup(@()delete(tmp)); %#ok<NASGU>
  [status,msg]=system(sprintf('git -C "%s" show f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6:results/tables/A_rolling_full.mat > "%s"',root,tmp)); assert(status==0,'%s',msg);
  A=load(tmp); fields=fieldnames(A); disp(fields);
  for name=["ETS" "SeasonalNaive"]
   sm=A.SMA_E; ma=A.MAS_E; if name=="SeasonalNaive", sm=A.SMA_N; ma=A.MAS_N; end
   assert(isequal(size(sm),[220 24]) && isequal(size(ma),[220 24]) && all(isfinite(sm),'all'));
   W=V(V.model==name & startsWith(V.protocol,'原A'),:);
   for k=1:height(W)
    h=W.horizon(k); assert(abs(W.cumulative_sMAPE_percent(k)-mean(sm(:,1:h),'all'))<tol && abs(W.cumulative_MASE(k)-mean(ma(:,1:h),'all'))<tol);
   end
  end
  for k=1:height(J)
   name=J.model(k); h=J.horizon(k);
   Old=sortrows(O(O.model==name & O.horizon<=h,:),{'round','horizon'});
   N=readtable(fullfile(out,'predictions.csv'),'TextType','string'); N=sortrows(N(N.model==name & N.horizon<=h,:),{'round','horizon'});
   assert(isequal(Old.actual,N.actual) && isequal(Old.target_month,N.target_month));
   eo=abs(Old.actual-Old.predicted); en=abs(N.actual-N.predicted);
   denom=sum(eo./N.scale-eo./Old.scale)/height(N); pred=sum((en-eo)./N.scale)/height(N);
   assert(abs(J.denominator_contribution(k)-denom)<tol && abs(J.prediction_contribution(k)-pred)<tol);
   assert(abs(J.new_MASE(k)-J.old_MASE(k)-denom-pred)<tol);
  end
  assert(isfile(fullfile(out,'comparison.png')) && isfile(fullfile(out,'experiment_summary.md')));
  checks(end+1)="主实验21120条、补充10560条；112行协议与论文比较、原A误差矩阵、年度累计口径及8行MASE分解全部通过。";
 end
 checks(end+1)="核验范围：所有保存模型输入均只使用当轮480月；照A的外部lambda有前视风险已标明。没有检查加密后端内部算法或证明优化收敛。";
 passed=true;
catch ME
 checks(end+1)=string(getReport(ME,'extended','hyperlinks','off'));
end
fid=fopen(fullfile(out,'audit.txt'),'w','n','UTF-8'); assert(fid>=0);
if passed, fprintf(fid,'PASS：%d轮独立核验\n',rounds); else, fprintf(fid,'FAIL：%d轮独立核验\n',rounds); end
fprintf(fid,'时间：%s\nMATLAB：%s\n',char(datetime('now')),version);
for k=1:numel(checks), fprintf(fid,'%s\n',checks(k)); end
fclose(fid); disp(checks); assert(passed,'滑动窗口实验独立核验失败，详见audit.txt');
end
