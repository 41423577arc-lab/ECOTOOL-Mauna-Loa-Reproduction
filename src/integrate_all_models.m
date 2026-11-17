function integrate_all_models(dataPath,out)
% 直接读取B/C成果和A统一检查点，重算六模型指标，不重新拟合B/C。
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1 || isempty(dataPath), dataPath=fullfile(root,'data','dataPLOSpaper.mat'); end
if nargin<2 || isempty(out), out=fullfile(root,'results','comparison'); end
bSHA='9225da80af22d5bbb2ddf6d727cc9db51a82968c';
S=load(dataPath,'CO2'); y=S.CO2(:); assert(numel(y)==723);
D=load(fullfile(out,'a_checkpoint.mat'),'A'); A=D.A;
D=load(fullfile(root,'results','rolling_c','checkpoint.mat'),'C'); C=D.C;
assert(all(A.done) && all(C.done,'all') && isequal(A.yall,y) && isequal(C.yall,y));
dates=datetime(1958,3,1)+calmonths((0:722)'); dates.Format='yyyy-MM-dd';
scales=zeros(220,1);
for r=1:220, z=y(1:479+r); scales(r)=mean(abs(z(13:end)-z(1:end-12))); end
T=readGitCSV(root,bSHA,'results/rolling_b/predictions.csv');
T.forecast_origin=string(T.forecast_origin); T.target_month=string(T.target_month);
T.scale=scales(T.round);
U=readtable(fullfile(root,'results','rolling_c','predictions.csv'),'TextType','string');
U.forecast_origin=string(U.forecast_origin); U.target_month=string(U.target_month);
T=[T;U];
for j=1:2
    rounds=repelem((1:220)',24); h=repmat((1:24)',220,1); n=479+rounds;
    p=reshape(A.pred(:,j,:),[],1); a=y(n+h);
    Q=table(repmat(A.config.names(j),5280,1),rounds,string(dates(n)),string(dates(n+h)), ...
        h,a,p,scales(rounds),'VariableNames', ...
        {'model','round','forecast_origin','target_month','horizon','actual','predicted','scale'});
    T=[T;Q]; %#ok<AGROW>
end
T=sortrows(T,{'model','round','horizon'});
names=["Airline" "AutoARIMA" "ETS" "SeasonalNaive" "UC" "AR12"];
M=table;
for name=names
    Q=T(T.model==name,:); assert(height(Q)==5280);
    e=abs(Q.actual-Q.predicted); sm=200*e./(abs(Q.actual)+abs(Q.predicted)); ma=e./Q.scale;
    row=table(repmat(name,24,1),(1:24)',repmat(220,24,1), ...
        accumarray(Q.horizon,sm,[24 1],@mean),accumarray(Q.horizon,ma,[24 1],@mean), ...
        'VariableNames',{'model','horizon','rounds','sMAPE_percent','MASE'});
    M=[M;row]; %#ok<AGROW>
end
fid=fopen(fullfile(out,'audit.txt'),'w'); assert(fid>=0);
fprintf(fid,'NOT RUN：整合文件更新，等待独立核验。\n'); fclose(fid);
atomicTable(T,fullfile(out,'all_models_predictions.csv'));
atomicTable(M,fullfile(out,'all_models_metrics.csv'));

% 从原论文第13页Table 4人工转录；列为Airline、Auto、AR、UC、ETS、Naive。
paperS=[.065 .067 .072 .068 .067 .549; .072 .074 .077 .077 .075 .549; ...
    .078 .079 .083 .084 .081 .549; .082 .083 .088 .090 .086 .550; ...
    .086 .087 .092 .095 .091 .550; .089 .091 .095 .099 .094 .550; ...
    .107 .107 .112 .114 .118 .547; .139 .137 .144 .145 .168 .818];
paperM=[.166 .170 .181 .171 .170 1.386; .182 .187 .196 .194 .189 1.386; ...
    .197 .199 .210 .213 .205 1.387; .209 .212 .224 .227 .218 1.388; ...
    .218 .222 .234 .240 .229 1.388; .226 .231 .242 .250 .238 1.388; ...
    .273 .274 .287 .290 .299 1.381; .355 .351 .370 .371 .426 2.068];
hs=[1:6 12 24]'; labels=["1";"2";"3";"4";"5";"6";"1 year";"2 years"];
paperColumns=[1 2 5 6 4 0]; V=table;
for j=1:6
    Q=sortrows(M(M.model==names(j),:),'horizon');
    cs=cumsum(Q.sMAPE_percent)./(1:24)'; cm=cumsum(Q.MASE)./(1:24)';
    ps=nan(8,1); pm=ps;
    if paperColumns(j)>0
        ps=paperS(:,paperColumns(j)); pm=paperM(:,paperColumns(j));
    end
    diagnostic=nan(8,1);
    if names(j)=="SeasonalNaive"
        % 仅作论文口径诊断：不改变统一实验，另算固定480月窗口的分母。
        N=T(T.model==names(j),:); sliding=zeros(220,1);
        for r=1:220, z=y(r:r+479); sliding(r)=mean(abs(z(13:end)-z(1:end-12))); end
        v=accumarray(N.horizon,abs(N.actual-N.predicted)./sliding(N.round),[24 1],@mean);
        v=cumsum(v)./(1:24)'; diagnostic=v(hs);
    end
    row=table(repmat(names(j),8,1),labels,hs,repmat(220,8,1), ...
        Q.sMAPE_percent(hs),Q.MASE(hs),cs(hs),cm(hs),ps,pm,cs(hs)-ps,cm(hs)-pm, ...
        repmat("前1至h步累计平均；论文式(8)(9)",8,1), ...
        repmat(paperColumns(j)>0,8,1),diagnostic, ...
        'VariableNames',{'model','table4_row','horizon','rounds','point_sMAPE_percent', ...
        'point_MASE','cumulative_sMAPE_percent','cumulative_MASE','paper_sMAPE_percent', ...
        'paper_MASE','delta_cumulative_sMAPE','delta_cumulative_MASE','paper_aggregation', ...
        'has_matching_paper_model','diagnostic_naive_sliding_scale_cumulative_MASE'});
    V=[V;row]; %#ok<AGROW>
end
atomicTable(V,fullfile(out,'table4_comparison.csv'));

% 上排保留全部六模型，下排放大五种拟合模型，均采用普通线性坐标轴。
f=figure('Visible','off','Color','w','Position',[50 50 1600 900]);
cleaner=onCleanup(@()close(f)); %#ok<NASGU>
layout=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
colors=lines(6); styles={'-','--','-.',':','-','--'};
displayNames=["Airline" "AutoARIMA" "ETS（AA12）" "季节朴素" "UC（LLT12）" "AR12（补充）"];
for panel=1:4
    ax=nexttile(layout); hold(ax,'on');
    set(ax,'FontName','Microsoft YaHei','FontSize',12,'Color','w','XColor','k','YColor','k');
    metric="sMAPE_percent"; ylabelText="sMAPE（%）";
    if mod(panel,2)==0, metric="MASE"; ylabelText="MASE"; end
    for j=1:6
        if panel>2 && j==4, continue; end
        Q=M(M.model==names(j),:);
        plot(ax,Q.horizon,Q.(metric),'Color',colors(j,:),'LineStyle',styles{j}, ...
            'LineWidth',2,'DisplayName',displayNames(j));
    end
    xlabel(ax,'预测步长（月）'); ylabel(ax,ylabelText); xlim(ax,[1 24]); xticks(ax,[1 6 12 18 24]); grid(ax,'on');
    if panel<=2, textTitle="全部六模型"; else, textTitle="五种拟合模型细节（季节朴素见上排）"; end
    title(ax,textTitle,'Color','k');
    legend(ax,'Location','northwest','NumColumns',2,'FontSize',10,'TextColor','k','Color','w');
end
title(layout,'六模型220轮滚动预测：第h步跨轮平均（扩展窗口）', ...
    'FontName','Microsoft YaHei','FontSize',19,'Color','k');
exportgraphics(f,fullfile(out,'model_comparison.png'),'Resolution',180);
audit_all_models(dataPath,out);
disp(M(ismember(M.horizon,[1 12 24]),:));
end

function T=readGitCSV(root,sha,path)
% 固定提交只读，不切换分支或改动组员成果。
[code,txt]=system(sprintf('git -C "%s" show %s:%s',root,sha,path)); assert(code==0,'%s',txt);
tmp=[tempname '.csv']; fid=fopen(tmp,'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',txt); fclose(fid); cleaner=onCleanup(@()delete(tmp)); %#ok<NASGU>
T=readtable(tmp,'TextType','string');
end

function atomicTable(T,path)
% 在同目录完成临时导出后替换，避免中断时留下半个CSV。
tmp=[path '.tmp']; writetable(T,tmp,'FileType','text','Delimiter',',','Encoding','UTF-8');
[ok,msg]=movefile(tmp,path,'f'); assert(ok,'%s',msg);
end
