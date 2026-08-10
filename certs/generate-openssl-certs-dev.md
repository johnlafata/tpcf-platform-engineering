# reference for cert generation - Tanzu CF
https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/10-2/eart/security_config.html 

## OpenSSL commands (RSA 2048, SANs for wildcard cert for *.apps.<domain>, *.sys.<domain>, and opsmgr.<domain>):

for production environments, you should submit the CSR to your CA instead of self-signing. 

1) Review the cert config file (wildcard-cert-req-prod.cnf):

2) Generate private key and CSR:
```bash
openssl req -new -nodes -config 'DEV Wildcard Certs.cnf' -out wildcard-cert-dev.csr -keyout wildcard-cert-dev.key -sha256
```

3) Self-sign (testing) or generate a CA-signed certificate. Self-signed (valid 365 days):
```bash
openssl x509 -req -in wildcard-cert-dev.csr -signkey wildcard-cert-dev.key -out wildcard-cert-dev.crt -days 365 -extensions v3_req -extfile 'DEV Wildcard Certs.cnf' -sha256
```

4) Combine cert and key to pks file
```
openssl pkcs12 -export -out wildcard-cert-dev.pfx -inkey wildcard-cert-dev.key -in wildcard-cert-dev.crt
```


