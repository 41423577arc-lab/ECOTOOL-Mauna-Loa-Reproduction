function verify_extra()
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(fullfile(root,'output','流程代码'));configure_ecotool();s=load(fullfile(here,'ecotool_audit.mat'));tr=load(fullfile(root,'output','C','step01_training_data.mat'));y=tr.yTrain(:);out=table;
for b=1:2
 m=s.objects{b,1,1};fid=fopen(fullfile(here,'ecotool_table_'+string(m.model)+'.txt'),'w');fprintf(fid,'%s\n',string(m.table));fclose(fid);
 for shift=[0 2 4]
 p=m.par+shift;phi=eye(2);if b==2,phi=[1 1;0 1];end
 [x,P,T,~,E,H,~,C,Q,R,S]=auxmodelUC(p,phi,eye(2),[1 0],1,zeros(2,1),m.model,y(1));if isempty(P),P=eye(2)*1e5;end
 e=zeros(108,1);F=e;g=e;
 for t=1:108
 F(t)=H*P*H'+R;K=(T*P*H')/F(t);e(t)=y(t)-H*x;g(t)=K(1);A=T-K*H;x=T*x+K*e(t);P=A*P*A'+E*Q*E'+K*R*K';end
 nll=.5*sum(log(2*pi*F(3:end))+e(3:end).^2./F(3:end));
 out=[out;table(string(m.model),shift,nll,sqrt(mean(e(3:end).^2)),var(e(3:end)./sqrt(F(3:end))),mean(g(3:end)),'VariableNames',{'Model','CommonLog10Shift','GaussianNLL','RMSE','ZVariance','MeanGain'})];
 end
end
writetable(out,fullfile(here,'common_scale_profile.csv'));
% Native scalar RW removes unused slope and unused optimization parameter.
z=(y-mean(y))/std(y);sys=ssm(@matrices);[est,p,cov,logL,info]=estimate(sys,z,[-3;0],'Display','off');save(fullfile(here,'native_scalar_rw.mat'),'est','p','cov','logL','info');
fid=fopen(fullfile(here,'native_scalar_rw.txt'),'w');fprintf(fid,'par(log variance)=%s\nlogL=%g\n%s',mat2str(p'),logL,evalc('disp(info)'));fclose(fid);
end
function [A,B,C,D,Mean0,Cov0,StateType]=matrices(p)
A=1;B=exp(p(1)/2);C=1;D=exp(p(2)/2);Mean0=0;Cov0=1e5;StateType=0;
end
