function passed=audit_all_models(dataPath,out)
% 独立读取原始CO2、整合CSV及三方检查点，不调用整合程序的指标计算代码。
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1 || isempty(dataPath), dataPath=fullfile(root,'data','dataPLOSpaper.mat'); end
if nargin<2 || isempty(out), out=fullfile(root,'results','comparison'); end
bSHA='9225da80af22d5bbb2ddf6d727cc9db51a82968c';
checks=strings(0,1); passed=false; tol=1e-9;
try
    S=load(dataPath,'CO2'); y=S.CO2(:);
    must(numel(y)==723 && all(isfinite(y) & y>0),'原始CO2为723个有限正数');
    T=readtable(fullfile(out,'all_models_predictions.csv'),'TextType','string');
    M=readtable(fullfile(out,'all_models_metrics.csv'),'TextType','string');
    V=readtable(fullfile(out,'table4_comparison.csv'),'TextType','string');
    D=load(fullfile(out,'a_checkpoint.mat'),'A'); A=D.A;
    D=load(fullfile(root,'results','rolling_c','checkpoint.mat'),'C'); C=D.C;
    B=gitRead('results/rolling_b/checkpoint.mat',true);
    names=["Airline" "AutoARIMA" "ETS" "SeasonalNaive" "UC" "AR12"];
    must(height(T)==31680 && height(M)==144 && height(V)==48,'31680条预测、144行逐步长指标、48行论文对照');
    must(isequal(sort(unique(T.model)),sort(names')) && ...
        isequal(sort(unique(M.model)),sort(names')),'恰好六个规定模型');
    must(height(unique(T(:,{'model','round','horizon'})))==31680,'预测组合唯一');
    must(height(unique(M(:,{'model','horizon'})))==144 && ...
        height(unique(V(:,{'model','horizon'})))==48,'两类指标表的键唯一');
    must(all(T.round==fix(T.round) & T.round>=1 & T.round<=220) && ...
        all(T.horizon==fix(T.horizon) & T.horizon>=1 & T.horizon<=24),'轮次与步长范围正确');
    must(all(isfinite(T.predicted) & T.predicted>200 & T.predicted<600),'预测有限且处于200至600 ppm');
    dates=datetime(1958,3,1)+calmonths((0:722)'); n=479+T.round;
    must(all(datetime(string(T.forecast_origin),'InputFormat','yyyy-MM-dd')==dates(n)) && ...
        all(datetime(string(T.target_month),'InputFormat','yyyy-MM-dd')==dates(n+T.horizon)), ...
        '所有模型的预测起点、目标月份与原始索引一致');
    must(max(abs(T.actual-y(n+T.horizon)))<tol,'真实值逐条对应原始CO2');
    scales=zeros(220,1); sliding=zeros(220,1); lambdas=zeros(220,1);
    for r=1:220
        train=y(1:479+r); scales(r)=mean(abs(train(13:end)-train(1:end-12)));
        z=y(r:r+479); sliding(r)=mean(abs(z(13:end)-z(1:end-12)));
        % 直接优化训练期的工具箱标量目标函数，避免绘图且不重估任何预测模型。
        lambdas(r)=fminsearch('auxvboxcoxllik',1,optimset('Display','off'),train,12,0);
    end
    must(max(abs(T.scale-scales(T.round)))<tol,'每条MASE分母仅由当前扩展训练集计算');
    must(isequal(A.yall,y) && isequal(B.yall,y) && isequal(C.yall,y),'三方检查点数据与原始数据完全一致');
    must(isequal(A.config.origins,(480:699)') && isequal(B.origins,(480:699)') && ...
        isequal(C.config.origins,(480:699)'),'三方初始训练480月、末轮699月');
    must(isequal(size(A.done),[220 1]) && all(A.done) && ...
        isequal(size(B.done),[220 1]) && all(B.done) && ...
        isequal(size(C.done),[220 2]) && all(C.done,'all'),'全部模型检查点均完成220轮');
    must(max(abs(A.scales-scales))<tol && max(abs(B.scales-scales))<tol && ...
        max(abs(C.scales-scales))<tol,'三方检查点训练期分母一致');
    must(max(abs(A.lambdas-lambdas))<1e-8 && max(abs(B.lambdas-lambdas))<1e-8 && ...
        max(abs(C.lambdas-lambdas))<1e-8,'A、Airline、UC的Box-Cox参数经训练期目标函数重算一致');
    predictions={B.pred(:,1,:),B.pred(:,2,:),A.pred(:,1,:),A.pred(:,2,:),C.pred(:,1,:),C.pred(:,2,:)};
    reference=[];
    for j=1:6
        Q=sortrows(T(T.model==names(j),:),{'round','horizon'});
        must(height(Q)==5280 && isequal(Q.round,repelem((1:220)',24)) && ...
            isequal(Q.horizon,repmat((1:24)',220,1)),names(j)+"具有220乘24完整覆盖");
        must(max(abs(Q.predicted-reshape(predictions{j},[],1)))<tol,names(j)+"与来源检查点预测逐值一致");
        fields={'round','forecast_origin','target_month','horizon','actual','scale'};
        if isempty(reference), reference=Q(:,fields); else
            must(isequal(reference,Q(:,fields)),names(j)+"共用相同真实值、月份、scale和测试范围");
        end
        for h=1:24
            rows=Q.horizon==h; a=Q.actual(rows); p=Q.predicted(rows); e=abs(a-p);
            row=M.model==names(j) & M.horizon==h;
            must(nnz(row)==1 && M.rounds(row)==220 && ...
                abs(M.sMAPE_percent(row)-mean(200*e./(abs(a)+abs(p))))<tol && ...
                abs(M.MASE(row)-mean(e./scales(Q.round(rows))))<tol, ...
                names(j)+"独立重算全部24步sMAPE和MASE");
        end
        errors=Q.predicted(Q.horizon==24)-Q.actual(Q.horizon==24);
        checks(end+1)=sprintf('%s第24步：平均有符号误差%.9f ppm；MAE %.9f ppm。', ...
            names(j),mean(errors),mean(abs(errors)));
        rows=V.model==names(j); W=sortrows(V(rows,:),'horizon');
        must(height(W)==8 && isequal(W.horizon,[1:6 12 24]') && all(W.rounds==220), ...
            names(j)+"论文对照的8种期限完整");
        for k=1:8
            h=W.horizon(k); point=Q.horizon==h; cumulative=Q.horizon<=h;
            e=abs(Q.actual-Q.predicted); sm=200*e./(abs(Q.actual)+abs(Q.predicted)); ma=e./Q.scale;
            must(abs(W.point_sMAPE_percent(k)-mean(sm(point)))<tol && ...
                abs(W.point_MASE(k)-mean(ma(point)))<tol && ...
                abs(W.cumulative_sMAPE_percent(k)-mean(sm(cumulative)))<tol && ...
                abs(W.cumulative_MASE(k)-mean(ma(cumulative)))<tol, ...
                names(j)+"逐步与累计口径分别从预测明细重算一致");
        end
    end
    % 检查原B/C预测CSV和指标，确保整合过程没有替换已核验结果。
    BT=gitRead('results/rolling_b/predictions.csv',false);
    BM=gitRead('results/rolling_b/metrics_by_horizon.csv',false);
    CT=readtable(fullfile(root,'results','rolling_c','predictions.csv'),'TextType','string');
    CM=readtable(fullfile(root,'results','rolling_c','metrics_by_horizon.csv'),'TextType','string');
    for group=1:2
        if group==1, P=BT; N=BM; else, P=CT; N=CM; end
        P=sortrows(P,{'model','round','horizon'}); Q=sortrows(T(ismember(T.model,unique(P.model)),:),{'model','round','horizon'});
        must(height(P)==10560 && max(abs(P.predicted-Q.predicted))<tol && ...
            max(abs(P.actual-Q.actual))<tol,'原B/C预测CSV保持原数值');
        for k=1:height(N)
            row=M.model==N.model(k) & M.horizon==N.horizon(k);
            must(nnz(row)==1 && abs(M.sMAPE_percent(row)-N.sMAPE_percent(k))<tol && ...
                abs(M.MASE(row)-N.MASE(k))<tol,'原B/C逐步长指标经新程序重算一致');
        end
    end
    for r=1:220
        train=y(1:479+r);
        for j=1:2
            z=A.transformed(:,j,r); lambda=A.lambdas(r);
            if lambda==0, p=exp(z); else
                must(all(1+lambda*z>0),'A逆Box-Cox定义域有效'); p=(1+lambda*z).^(1/lambda);
            end
            must(max(abs(p-A.pred(:,j,r)))<tol,'ETS与季节朴素逆变换为原始ppm');
        end
        must(max(abs(A.pred(:,2,r)-repmat(train(end-11:end),2,1)))<tol, ...
            '季节朴素等于训练期末12个月重复，不代入未来真实值');
        lambda=C.lambdas(r); z=C.models{r,1}.transformedForecast;
        if lambda==0, p=exp(z); else, p=(1+lambda*z).^(1/lambda); end
        must(max(abs(p-C.pred(:,1,r)))<tol,'UC原有逆变换逐轮核查');
        X=ones(numel(train)-12,13);
        for lag=1:12, X(:,lag+1)=train(13-lag:end-lag); end
        beta=X\train(13:end); history=train;
        for h=1:24, history(end+1,1)=beta(1)+beta(2:end)'*history(end:-1:end-11); end %#ok<AGROW>
        must(max(abs(history(end-23:end)-C.pred(:,2,r)))<1e-7,'独立AR12递推不使用测试真实值');
    end
    W=V(V.model=="SeasonalNaive",:); W=sortrows(W,'horizon');
    Q=T(T.model=="SeasonalNaive",:); sm=[]; dm=[];
    for h=W.horizon'
        rows=Q.horizon<=h; e=abs(Q.actual(rows)-Q.predicted(rows));
        value=mean(e./sliding(Q.round(rows)));
        k=find(W.horizon==h);
        must(abs(value-W.diagnostic_naive_sliding_scale_cumulative_MASE(k))<tol, ...
            '固定480月分母仅作为独立的论文诊断列');
        sm(end+1)=abs(W.cumulative_sMAPE_percent(k)-W.paper_sMAPE_percent(k)); %#ok<AGROW>
        dm(end+1)=abs(value-W.paper_MASE(k)); %#ok<AGROW>
    end
    must(max(sm)<0.0005 && max(dm)<0.0005,'季节朴素累计sMAPE及固定480月分母诊断均与论文三位小数吻合');
    checks(end+1)=sprintf('论文一致性误差：累计sMAPE最大%.9f；固定480月诊断MASE最大%.9f。',max(sm),max(dm));
    W=V(V.model=="AR12",:);
    must(all(~W.has_matching_paper_model & isnan(W.paper_sMAPE_percent) & isnan(W.paper_MASE)), ...
        'AR12未冒充论文自动AR模型');
    must(all(contains(V.paper_aggregation,'累计平均')),'论文式(8)(9)的累计口径已明确标注');
    passed=true;
catch ME
    checks(end+1)="FAIL："+string(ME.message);
end
fid=fopen(fullfile(out,'audit.txt'),'w','n','UTF-8'); assert(fid>=0);
label='FAIL'; if passed, label='PASS'; end
fprintf(fid,'%s：六模型统一协议与独立指标核验\n时间：%s\n',label,char(datetime('now')));
fprintf(fid,'容差：指标与数值1e-9；Box-Cox参数1e-8；独立AR递推1e-7 ppm。\n');
fprintf(fid,'%s\n',unique(checks,'stable'));
fprintf(fid,'来源：Ariel f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6（原实验不混用，已在C分支独立适配）。\n');
if exist('A','var')
    fprintf(fid,'本机MATLAB：%s；ECOTOOL为已安装1.0版；ETS/Naive入口与后端指纹保存在a_checkpoint.mat。\n',A.env.matlab);
end
fprintf(fid,'B %s；C既有成果1a260c5；原始B/C文件未重估、未覆盖。\n',bSHA);
fprintf(fid,'协议：训练CO2(1:479+r)，测试CO2(480+r:503+r)，220轮，各24步；原始ppm评价。\n');
fprintf(fid,'代码审查：A/B/C入口仅向模型传当前训练集；AutoARIMA内部处理Box-Cox并返回ppm，不重复逆变换。\n');
fprintf(fid,'统计口径：论文第9页式(8)(9)明确对前1至h步取平均；Table 4的1年/2年按h=12/24累计解读。\n');
fprintf(fid,'推断界限：朴素法诊断支持论文采用固定480月MASE分母，但不能据此证明其他模型的完整窗口、lambda与估计配置。\n');
fprintf(fid,'范围：PASS验证已保存数据、训练边界与计算一致性，不证明加密后端的优化收敛、统计显著性或论文数值完全复现。\n');
fclose(fid); fprintf('%s：六模型独立核验，详见%s\n',label,fullfile(out,'audit.txt'));
if ~passed, error('comparison:AuditFailed','六模型核验失败，详见audit.txt'); end

    function must(ok,label)
        assert(isscalar(ok) && ok,'%s',label); checks(end+1)="PASS："+string(label);
    end

    function value=gitRead(path,isMat)
        % MAT文件由系统命令直接二进制重定向，不经文本解码；只在系统临时目录保留。
        suffix='.csv'; if isMat, suffix='.mat'; end
        tmp=[tempname suffix]; cleaner=onCleanup(@()deleteIfPresent(tmp)); %#ok<NASGU>
        [code,msg]=system(sprintf('git -C "%s" show %s:%s > "%s"',root,bSHA,path,tmp));
        assert(code==0,'%s',msg);
        if isMat, value=load(tmp); else, value=readtable(tmp,'TextType','string'); end
    end
end

function deleteIfPresent(path)
% 仅删除本次调用明确创建的临时文件。
if isfile(path), delete(path); end
end
