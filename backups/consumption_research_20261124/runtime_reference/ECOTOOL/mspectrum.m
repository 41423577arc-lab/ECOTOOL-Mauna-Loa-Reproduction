function [I, w]= mspectrum(z)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[T, m]= size(z);
% z= z-repmat(nanmean(z), T, 1);
nw= floor(T/2)+1;
if isempty(nw)
   w= 2*pi*(0 : nw-1)'/T;
else
   if nw== 0
      w= 2*pi*(0 : nw-1)'/T;
   else
      if nw< 10, nw= floor(T/2); end
      w= (0 : pi/nw : pi-pi/nw)';
   end
end
%     w= w(:);
%     nw= size(w, 1)-1;

miss= 0;
if any(isnan(sum(z')))
    miss= 1;
end
    t=(1:T);
%     nw= fix(T/2)+1;
%     w= (2*pi*(t(1:nw)-1))/T;
I= nan(m, m, nw);
if miss
    wwaitfor(fix((nw+1)/40));
    for j=1:nw
        if rem(j, 40)== 0, if wwaitfor; break; end, end
        I1= sum(z.*repmat(exp(-sqrt(-1)*w(j)*t),m ,1), 2);
        I(:, :, j)= I1'*I1;   % I1'= conj(I1')
    end
    wwaitfor(0);
else
    y= fft(z)';
    if m== 1
        y= fft(z); I(1, 1, :)= y(1:nw).*conj(y(1:nw)); 
    else
        for j=1:nw
            I(:, :, j)= y(:, j)*y(:, j)';
        end
    end
end
for i= 1:m
    I(i, i, :)= real(I(i, i, :));
end
I= I/(2*pi*T);   %(1:nw);
w= w/pi/2;
