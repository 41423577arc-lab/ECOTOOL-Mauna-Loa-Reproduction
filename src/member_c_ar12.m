function [forecast,beta] = member_c_ar12(y,H)
% AR(12) with intercept, OLS on original ppm; recursive forecasts only.
y=y(:); p=12; n=numel(y);
assert(n>p && all(isfinite(y)));
X=ones(n-p,p+1);
for lag=1:p, X(:,lag+1)=y(p+1-lag:n-lag); end
assert(rank(X)==p+1,'AR12 design matrix is rank deficient');
beta=X\y(p+1:n);
history=[y;nan(H,1)];
for h=1:H
    history(n+h)=[1 history(n+h-(1:p))']*beta;
end
forecast=history(n+1:end);
end
