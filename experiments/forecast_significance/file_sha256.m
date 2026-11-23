function value=file_sha256(path)
% 按原始字节计算指纹，便于确认所有统计输入未被更改。
fid=fopen(path,'rb');assert(fid>=0);done=onCleanup(@() fclose(fid));
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
value=lower(string(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[])));
end
