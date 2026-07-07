# reference for cert generation - Tanzu CF
https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/10-2/eart/security_config.html 

## OpenSSL commands (RSA 2048, SANs for wildcard cert for *.apps.<domain>, *.sys.<domain>, and opsmgr.<domain>):

1) Review the cert config file (wildcard-cert-req-sbx.cnf):


2) Generate private key and CSR:
```bash
openssl req -new -nodes -config wildcard-cert-req-sbx.cnf -out wildcard-cert-sbx.csr -keyout wildcard-cert-sbx.key -sha256
```

3) Self-sign (testing) or generate a CA-signed certificate. Self-signed (valid 365 days):
```bash
openssl x509 -req -in wildcard-cert-sbx.csr -signkey wildcard-cert-sbx.key -out wildcard-cert-sbx.crt -days 365 -extensions v3_req -extfile wildcard-cert-req-sbx.cnf -sha256
```

4) Combine cert and key to pks file
```
openssl pkcs12 -export -out wildcard-cert-sbx.pfx -inkey wildcard-cert-sbx.key -in wildcard-cert-sbx.crt
```
