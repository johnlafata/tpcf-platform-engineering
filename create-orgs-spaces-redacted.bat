@echo off
cf login -a API-ENDPOINT -u USERNAME -p PASSWORD --skip-ssl-validation

REM recreate orgs, spaces, users, service accounts, isolation segments, application security groups, domains, routes, and A records in F5 for each foundation.
REM org / space / user mgmt

REM service account for jenkins
cf create-user jenkins-sa REDACTED-PASSWORD

REM create orgs -- internal (weeklybriefings, eHandbook) and external (www)
cf create-org internal
cf create-org external

REM create spaces -- each app gets a -ui space (public-facing) and a -api space (backend,
REM the only tier that needs SQL-ACCESS-ASG egress -- see the ASG section below)
cf create-space weeklybriefings-ui -o internal
cf create-space weeklybriefings-api -o internal
cf create-space eHandbook-ui -o internal
cf create-space eHandbook-api -o internal

cf create-space www-ui -o external
cf create-space www-api -o external

REM jenkins-sa needs SpaceDeveloper everywhere so the deploy pipeline can push to both
REM tiers of every app
cf set-space-role jenkins-sa internal weeklybriefings-ui SpaceDeveloper
cf set-space-role jenkins-sa internal weeklybriefings-api SpaceDeveloper
cf set-space-role jenkins-sa internal eHandbook-ui SpaceDeveloper
cf set-space-role jenkins-sa internal eHandbook-api SpaceDeveloper
cf set-space-role jenkins-sa external www-ui SpaceDeveloper
cf set-space-role jenkins-sa external www-api SpaceDeveloper

cf enable-org-isolation internal sql-secured-segment 
cf enable-org-isolation external sql-secured-segment 

cf target -o internal -s weeklybriefings-api 
cf set-space-isolation-segment weeklybriefings-api sql-secured-segment 
cf target -o internal -s eHandbook-api 
cf set-space-isolation-segment eHandbook-api sql-secured-segment 

cf target -o external -s www-api 
cf set-space-isolation-segment www-api sql-secured-segment 

REM Application Security Groups
REM SQL-ACCESS-ASG -- bound only to the -api spaces
cf create-security-group SQL-ACCESS-ASG sql-access-asg-prod.json
cf bind-security-group SQL-ACCESS-ASG internal --lifecycle running --space weeklybriefings-api 
cf bind-security-group SQL-ACCESS-ASG internal --lifecycle staging --space weeklybriefings-api  
cf bind-security-group SQL-ACCESS-ASG internal --lifecycle running --space eHandbook-api 
cf bind-security-group SQL-ACCESS-ASG internal --lifecycle staging --space eHandbook-api 
cf bind-security-group SQL-ACCESS-ASG external --lifecycle running --space www-api 
cf bind-security-group SQL-ACCESS-ASG external --lifecycle staging --space www-api 

REM default-deny-1433 is a platform-wide DEFAULT running/staging security group, not one bound
REM per space;
cf create-security-group default-deny-1433 default-deny-1433.json
cf bind-running-security-group default-deny-1433
cf bind-staging-security-group default-deny-1433

REM unbind default_security_group from running and staging, as it's wide open 
cf unbind-running-security-group default_security_group 
cf unbind-staging-security-group default_security_group 