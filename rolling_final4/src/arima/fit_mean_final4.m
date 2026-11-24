function [p,mu,v] = fit_mean_final4(y,H)
% ARIMA(0,0,0) with estimated constant: training-window mean.
y=double(y(:)); mu=mean(y); v=mean((y-mu).^2); p=repmat(mu,H,1);
end
