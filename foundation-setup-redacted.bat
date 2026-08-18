@echo off

cf login -a API-ENDPOINT -u USERNAME -p PASSWORD --skip-ssl-validation

REM additional services
cf enable-service-access smb
cf enable-feature-flag diego_docker 

REM create vanity domain
cf create-shared-domain YOUR-DOMAIN
