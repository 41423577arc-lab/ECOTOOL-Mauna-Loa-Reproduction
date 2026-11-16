function passed = audit_member_c_rolling(expectedRounds,dataPath,out)
% Independent CSV/raw-data audit; default requires the complete 220 rounds.
% audit_member_c_rolling(3) audits a pilot explicitly, never a full-run PASS.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1, expectedRounds=220; end
if nargin<2 || isempty(dataPath), dataPath=fullfile(root,'data','dataPLOSpaper.mat'); end
if nargin<3 || isempty(out), out=fullfile(root,'results','rolling_c'); end
validateattributes(expectedRounds,{'numeric'},{'scalar','integer','>=',1,'<=',220});
checks=strings(0,1); passed=false; tol=1e-9;
try
    D=load(dataPath,'CO2'); y=D.CO2(:);
    must(numel(y)==723 && all(isfinite(y)) && all(y>0),'Raw CO2: 723 positive finite months');
    T=readtable(fullfile(out,'predictions.csv'),'TextType','string');
    M=readtable(fullfile(out,'metrics_by_horizon.csv'),'TextType','string');
    D=load(fullfile(out,'checkpoint.mat'),'C'); C=D.C;
    must(isequal(C.yall,y),'Checkpoint data equals independent raw CO2');
    must(height(T)==2*24*expectedRounds && height(M)==48,'Prediction and metric row counts');
    must(isequal(sort(unique(T.model)),["AR12";"UC"]) && ...
        isequal(sort(unique(M.model)),["AR12";"UC"]),'Exactly UC and AR12');
    must(all(T.round==fix(T.round) & T.round>=1 & T.round<=expectedRounds) && ...
        all(T.horizon==fix(T.horizon) & T.horizon>=1 & T.horizon<=24),'Round and horizon domains');
    must(height(unique(T(:,{'model','round','horizon'})))==height(T),'Unique model/round/horizon keys');
    must(height(unique(M(:,{'model','horizon'})))==48,'Unique metric keys');
    must(all(isfinite(T.predicted) & T.predicted>200 & T.predicted<600),'Finite predictions in 200--600 ppm');
    dates=datetime(1958,3,1)+calmonths((0:722)');
    origin=479+T.round; target=origin+T.horizon;
    must(all(datetime(string(T.forecast_origin),'InputFormat','yyyy-MM-dd')==dates(origin)) && ...
        all(datetime(string(T.target_month),'InputFormat','yyyy-MM-dd')==dates(target)), ...
        'Origins and targets match raw-data calendar and horizons');
    must(all(abs(T.actual-y(target))<tol),'Actuals match independent raw observations');
    scales=zeros(220,1);
    for r=1:220
        train=y(1:479+r); scales(r)=mean(abs(train(13:end)-train(1:end-12)));
    end
    must(all(abs(T.scale-scales(T.round))<tol),'CSV scales use training-only seasonal differences');
    must(isequal(size(C.done),[220 2]) && isequal(C.done, ...
        repmat((1:220)'<=expectedRounds,1,2)),'Checkpoint done flags exactly match requested coverage');
    must(isequal(C.config.origins,(480:699)') && C.config.H==24 && C.config.R==220, ...
        'Checkpoint protocol matches independent specification');
    must(all(abs(C.scales(1:expectedRounds)-scales(1:expectedRounds))<tol), ...
        'Checkpoint training-only scales');
    must(all(isfinite(C.lambdas(1:expectedRounds))) && ...
        all(isfinite(C.seconds(C.done))) && all(C.seconds(C.done)>=0),'Lambda and runtime records');
    for j=1:2
        name=["UC" "AR12"]; Q=T(T.model==name(j),:); Q=sortrows(Q,{'round','horizon'});
        must(isequal(Q.round,repelem((1:expectedRounds)',24)) && ...
            isequal(Q.horizon,repmat((1:24)',expectedRounds,1)),name(j)+" complete coverage");
        for r=1:expectedRounds
            rows=Q.round==r;
            must(all(abs(Q.predicted(rows)-C.pred(:,j,r))<tol) && ...
                all(abs(Q.actual(rows)-C.actual(:,r))<tol),'Checkpoint predictions/actuals equal CSV');
            if j==2
                % Independent fit and recursion: no call to the producer's AR helper.
                z=y(1:479+r); X=ones(numel(z)-12,13);
                for lag=1:12, X(:,1+lag)=z(13-lag:end-lag); end
                b=X\z(13:end); history=z;
                for h=1:24, history(end+1,1)=b(1)+b(2:end)'*history(end:-1:end-11); end %#ok<AGROW>
                must(max(abs(history(end-23:end)-Q.predicted(rows)))<1e-7, ...
                    'Independent AR12 OLS and prediction-only recursion');
                must(max(abs(C.models{r,2}.beta-b))<tol,'Saved AR coefficients');
            else
                % Independent algebra verifies inverse transform without ECOTOOL.
                lambda=C.lambdas(r); z=C.models{r,1}.transformedForecast;
                if lambda==0, p=exp(z); else
                    must(all(1+lambda*z>0),'Inverse Box-Cox domain');
                    p=(1+lambda*z).^(1/lambda);
                end
                must(max(abs(p-Q.predicted(rows)))<tol,'UC inverse Box-Cox to raw ppm');
                must(all(isfinite(C.models{r,1}.par)),'Saved finite UC parameters');
            end
        end
        for h=1:24
            rows=Q.horizon==h; a=Q.actual(rows); p=Q.predicted(rows); e=abs(a-p);
            sm=mean(200*e./(abs(a)+abs(p))); ma=mean(e./scales(Q.round(rows)));
            row=M.model==name(j) & M.horizon==h;
            must(nnz(row)==1 && M.rounds(row)==expectedRounds && ...
                abs(sm-M.sMAPE_percent(row))<tol && abs(ma-M.MASE(row))<tol, ...
                'Independently recomputed per-horizon sMAPE and MASE');
        end
    end
    U=sortrows(T(T.model=="UC",:),{'round','horizon'});
    A=sortrows(T(T.model=="AR12",:),{'round','horizon'});
    fields={'round','forecast_origin','target_month','horizon','actual','scale'};
    must(isequal(U(:,fields),A(:,fields)),'UC and AR12 share every target, actual, origin and scale');
    S=readtable(fullfile(out,'ar12_single_predictions.csv'),'TextType','string');
    must(height(S)==24 && all(S.actual==y(505:528)) && all(S.horizon==(1:24)'), ...
        'AR12 separate single-origin sample');
    must(all(string(S.model)=="AR12") && ...
        all(datetime(string(S.forecast_origin),'InputFormat','yyyy-MM-dd')==dates(504)) && ...
        all(datetime(string(S.target_month),'InputFormat','yyyy-MM-dd')==dates(505:528)), ...
        'Single-origin dates and model identity');
    z=y(25:504); X=ones(468,13);
    for lag=1:12, X(:,lag+1)=z(13-lag:end-lag); end
    b=X\z(13:end);
    for h=1:24, z(end+1,1)=b(1)+b(2:end)'*z(end:-1:end-11); end %#ok<AGROW>
    e=abs(y(505:528)-z(end-23:end)); sc=mean(abs(y(37:504)-y(25:492)));
    must(max(abs(S.predicted-z(end-23:end)))<1e-7 && ...
        max(abs(C.single.pred-S.predicted))<tol && abs(C.single.scale-sc)<tol && ...
        max(abs(S.MASE-e/sc))<tol && ...
        max(abs(S.sMAPE_percent-200*e./(abs(y(505:528))+abs(S.predicted))))<tol, ...
        'Single-origin independent AR recursion and error metrics');
    passed=true;
catch ME
    checks(end+1)="FAIL: "+string(ME.message);
end
fid=fopen(fullfile(out,'audit.txt'),'w'); assert(fid>=0);
if passed, label='PASS'; else, label='FAIL'; end
fprintf(fid,'%s: UC and AR12 | requested rounds per model: %d/220 | horizon: 24\n',label,expectedRounds);
fprintf(fid,'Numeric tolerance: %.1e (independent AR recursion: 1e-7 ppm)\n',tol);
fprintf(fid,'Timestamp: %s\n',char(datetime('now')));
fprintf(fid,'%s\n',unique(checks,'stable'));
fprintf(fid,'Scope: saved-data integrity and calculations; does not certify optimizer convergence or exact Table 4 replication.\n');
fclose(fid); fprintf('%s\n',fileread(fullfile(out,'audit.txt')));
if ~passed, error('memberC:AuditFailed','Member C independent audit FAILED; see audit.txt'); end

    function must(ok,label)
        assert(isscalar(ok) && ok,'%s',label);
        checks(end+1)="PASS: "+string(label);
    end
end
