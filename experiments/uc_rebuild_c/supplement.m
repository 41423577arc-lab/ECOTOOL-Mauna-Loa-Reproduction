function supplement()
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(fullfile(root,'output','流程代码'));configure_ecotool();diary(fullfile(here,'supplement.log'));tr=load(fullfile(root,'output','C','step01_training_data.mat'));y=tr.yTrain(:);tab=table;objs={};
% Actual ECOTOOL stochastic seasonal and additional trend API verification.
for group=["Raw","Winsor"]
 for model=["RW4","LLT4","IRW","SRW"]
 for n=78:108
 z=y(1:n);if group=="Winsor",q=quantile(z,[.25 .75]);z=min(max(z,max(0,q(1)-1.5*diff(q))),q(2)+1.5*diff(q));end
 try
 m=modelUC(z,[],char(model),4);p=m.py(:);assert(numel(p)==4&&all(isfinite(p)));
 for h=1:4
 if (h==1&&n<=107)||(n<=104),tab=[tab;table(group,model,n,h,p(h),y(n+h),mean(abs(diff(y(1:n)))),"",'VariableNames',{'Group','Model','Origin','Horizon','Forecast','Actual','Scale','Failure'})];end
 end
 if n==108,objs{end+1}=m;end
 catch ex,tab=[tab;table(group,model,n,0,NaN,NaN,NaN,string(ex.message),'VariableNames',{'Group','Model','Origin','Horizon','Forecast','Actual','Scale','Failure'})];end
 end
 fprintf('Completed %s %s\n',group,model);
 end
end
writetable(tab,fullfile(here,'actual_ecotool_extensions.csv'));save(fullfile(here,'actual_ecotool_extensions.mat'),'objs','tab');
% Native MATLAB ssm EML crosscheck: initialization differs, compare not equate IC.
native=table;
for kind=["RW","LLT"]
 try
 z=(y-mean(y))/std(y);sys=ssm(@(p) nativeMatrices(p,kind));[est,p,cov,logL,info]=estimate(sys,z,[-3;0; -5],'Display','off');
 native=[native;table(kind,string(mat2str(p')),logL,string(evalc('disp(info)')),"",'VariableNames',{'Model','Par','LogL','Optimizer','Failure'})];save(fullfile(here,'native_'+kind+'.mat'),'est','p','cov','logL','info');
 catch ex,native=[native;table(kind,"",NaN,"",string(ex.message),'VariableNames',{'Model','Par','LogL','Optimizer','Failure'})];end
end
writetable(native,fullfile(here,'native_ssm.csv'));diary off
end
function [A,B,C,D,Mean0,Cov0,StateType]=nativeMatrices(p,kind)
A=[1 0;0 1];B=diag([exp(p(1)/2),0]);if kind=="LLT",A=[1 1;0 1];B=diag(exp(p([1 3])/2));end
C=[1 0];D=exp(p(2)/2);Mean0=[0;0];Cov0=eye(2)*1e5;StateType=[0;0];
end
