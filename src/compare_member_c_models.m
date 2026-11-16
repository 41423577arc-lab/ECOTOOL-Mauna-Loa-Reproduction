function compare_member_c_models(bRevision,dataPath,out)
% Read B results directly from a pinned Git object; never check out B's files.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1, bRevision='9225da80af22d5bbb2ddf6d727cc9db51a82968c'; end
if nargin<2 || isempty(dataPath), dataPath=fullfile(root,'data','dataPLOSpaper.mat'); end
if nargin<3 || isempty(out), out=fullfile(root,'results','rolling_c'); end
assert(~isempty(regexp(bRevision,'^[0-9a-f]{40}$','once')),'Use a full Git commit SHA');
audit_member_c_rolling(220,dataPath,out);
T=gitTable('results/rolling_b/predictions.csv');
M=gitTable('results/rolling_b/metrics_by_horizon.csv');
S=load(dataPath,'CO2'); y=S.CO2(:); tol=1e-9;
assert(height(T)==10560 && height(M)==48);
assert(isequal(sort(unique(string(T.model))),["Airline";"AutoARIMA"]));
assert(height(unique(T(:,{'model','round','horizon'})))==height(T));
assert(height(unique(M(:,{'model','horizon'})))==48);
dates=datetime(1958,3,1)+calmonths((0:722)');
assert(all(T.round==fix(T.round) & T.round>=1 & T.round<=220));
assert(all(T.horizon==fix(T.horizon) & T.horizon>=1 & T.horizon<=24));
assert(all(abs(T.actual-y(479+T.round+T.horizon))<tol));
assert(all(datetime(string(T.forecast_origin),'InputFormat','yyyy-MM-dd')==dates(479+T.round)));
assert(all(datetime(string(T.target_month),'InputFormat','yyyy-MM-dd')==dates(479+T.round+T.horizon)));
assert(all(isfinite(T.predicted) & T.predicted>200 & T.predicted<600));
scales=zeros(220,1);
for r=1:220, z=y(1:479+r); scales(r)=mean(abs(z(13:end)-z(1:end-12))); end
for k=1:height(M)
    rows=string(T.model)==string(M.model(k)) & T.horizon==M.horizon(k);
    assert(isequal(sort(T.round(rows)),(1:220)') && M.rounds(k)==220);
    a=T.actual(rows); p=T.predicted(rows); e=abs(a-p);
    assert(abs(mean(200*e./(abs(a)+abs(p)))-M.sMAPE_percent(k))<tol);
    assert(abs(mean(e./scales(T.round(rows)))-M.MASE(k))<tol);
end
C=readtable(fullfile(out,'predictions.csv'),'TextType','string');
fields={'round','forecast_origin','target_month','horizon','actual'};
B=sortrows(T(string(T.model)=="Airline",fields),{'round','horizon'});
U=sortrows(C(C.model=="UC",fields),{'round','horizon'});
assert(isequal(string(B.forecast_origin),string(U.forecast_origin)) && ...
    isequal(string(B.target_month),string(U.target_month)) && ...
    isequal(B.round,U.round) && isequal(B.horizon,U.horizon) && ...
    max(abs(B.actual-U.actual))<tol);
N=readtable(fullfile(out,'metrics_by_horizon.csv'),'TextType','string');
M.model=string(M.model); N=[M;N];
writetable(N,fullfile(out,'model_comparison.csv'));
names=unique(N.model,'stable');
for metric=["sMAPE_percent" "MASE"]
    f=figure('Visible','off','Color','w'); cleaner=onCleanup(@()close(f));
    ax=axes(f,'Color','w','XColor','k','YColor','k'); hold(ax,'on');
    for name=names'
        Q=sortrows(N(N.model==name,:),'horizon');
        plot(ax,Q.horizon,Q.(metric),'LineWidth',1.6,'DisplayName',name);
    end
    xlabel(ax,'Forecast horizon (months)'); ylabel(ax,strrep(metric,'_',' '));
    title(ax,'220 expanding-window origins','Color','k'); grid(ax,'on');
    legend(ax,'Location','best','TextColor','k','Color','w');
    exportgraphics(f,fullfile(out,metric+'.png'),'Resolution',180); clear cleaner;
end
fid=fopen(fullfile(out,'comparison_audit.txt'),'w'); assert(fid>=0);
fprintf(fid,'PASS: B vs C common raw actuals, origins, targets; B 10560 predictions, 48 metrics independently recomputed in MATLAB.\n');
fprintf(fid,'B source commit: %s\nTolerance: %.1e\n',bRevision,tol);
fprintf(fid,'C audit: audit.txt (220 rounds). No B code or result files modified.\n');
fprintf(fid,'Comparison contains Airline, AutoARIMA, UC, AR12.\n');
fprintf(fid,'Ariel f8dabd8778ac9f277cbdd99cd7cfd9f94e513cf6 excluded: A6 uses a fixed 480-month sliding window and fixed lambda=0.2461; its summary is cumulative over horizons. B/C use expanding windows.\n');
fclose(fid);
disp(N(ismember(N.horizon,[1 12 24]),:));

    function V=gitTable(path)
        [code,txt]=system(sprintf('git -C "%s" show %s:%s',root,bRevision,path));
        assert(code==0,'Cannot read B Git object: %s',txt);
        tmp=[tempname '.csv']; fid=fopen(tmp,'w','n','UTF-8'); assert(fid>=0);
        fprintf(fid,'%s',txt); fclose(fid);
        cleanup=onCleanup(@()delete(tmp)); %#ok<NASGU>
        V=readtable(tmp,'TextType','string');
    end
end
