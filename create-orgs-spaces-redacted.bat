@echo off
cf login -a API-ENDPOINT -u USERNAME -p PASSWORD --skip-ssl-validation

REM  recreate orgs, spaces, users, service accounts, isolation segments, application security groups, domains, routes, and A records in F5 for each foundation.
REM org / space / user mgmt

REM service account for jenkins
cf create-user jenkins-sa REDACTED-PASSWORD

REM create unprotected orgs
cf create-org dev-org
cf create-org prod-org

REM create spaces for apps 
cf create-space weeklybriefings -o dev-org
cf create-space weeklybriefings -o prod-org
cf create-space eHandbook -o dev-org
cf create-space eHandbook -o prod-org

cf create-org dev-secure-org
cf create-org prod-secure-org

cf create-space www -o dev-secure-org
cf create-space www -o prod-secure-org

cf set-space-role jenkins-sa  dev-org weeklybriefings SpaceDeveloper
cf set-space-role jenkins-sa  prod-org weeklybriefings SpaceDeveloper
cf set-space-role jenkins-sa  dev-org ehandbook SpaceDeveloper
cf set-space-role jenkins-sa  prod-org ehandbook SpaceDeveloper
cf set-space-role jenkins-sa  dev-secure-org www SpaceDeveloper
cf set-space-role jenkins-sa  prod-secure-org www SpaceDeveloper

cf enable-org-isolation dev-secure-org sql-secured-segment
cf enable-org-isolation prod-secure-org sql-secured-segment

cf create-space www –o dev-secure-org
cf target –s www –o dev-secure-org
cf set-space-isolation-segment www sql-secured-segment

cf create-space www –o prod-secure-org
cf target –s www –o prod-secure-org
cf set-space-isolation-segment www sql-secured-segment


REM after deploying apps, map to vanity domain
cf map-route weeklybriefings YOUR-DOMAIN --hostname weeklybriefings
cf map-route ehandbook YOUR-DOMAIN --hostname ehandbook 
cf map-route www YOUR-DOMAIN --hostname www

REM create A records in F5 to point to the router in each foundation according to what what part of the SDLC the app is in.

REM Application Security Groups



