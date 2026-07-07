# reference for cert generation - Tanzu CF
https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/10-2/eart/security_config.html 

## OpenSSL commands (RSA 2048, SANs for wildcard cert for *.apps.<domain>, *.sys.<domain>, and opsmgr.<domain>):

for production environments, you should submit the CSR to your CA instead of self-signing. 

1) Review the cert config file (wildcard-cert-req-prod.cnf):

2) Generate private key and CSR:
```bash
openssl req -new -nodes -config wildcard-cert-req-prod.cnf -out wildcard-cert-prod.csr -keyout wildcard-cert-prod.key -sha256
```

3) Self-sign (testing) or generate a CA-signed certificate. Self-signed (valid 365 days):
```bash
openssl x509 -req -in wildcard-cert-prod.csr -signkey wildcard-cert-prod.key -out wildcard-cert-prod.crt -days 365 -extensions v3_req -extfile wildcard-cert-req-prod.cnf -sha256
```

4) Combine cert and key to pks file
```
openssl pkcs12 -export -out wildcard-cert-prod.pfx -inkey wildcard-cert-prod.key -in wildcard-cert-prod.crt
```


