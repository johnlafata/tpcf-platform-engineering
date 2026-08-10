@echo off
cf login -a API-ENDPOINT -u USERNAME -p PASSWORD --skip-ssl-validation

REM  recreate orgs, spaces, users, service accounts, isolation segments, application security groups, domains, routes, and A records in F5 for each foundation.
REM org / space / user mgmt
REM
REM This is the manual cf CLI equivalent of cf-mgmt-config\production\ (internal/external orgs,
REM UI/API space split, SQL-ACCESS-ASG scoped to -api spaces only -- see that folder's README.md
REM and docs\installation\CF-MGMT-INSTALLATION.md). Prefer cf-mgmt apply against that config for
REM anything beyond an initial repave/recovery -- it will keep reconciling to the same state
REM every run instead of drifting, and it's what these commands are kept in sync with.

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

REM Isolation segment -- applies to every space in both orgs (not just -api), matching
REM isolation-segment: isolated-segment in every spaceConfig.yml under cf-mgmt-config\production\
cf enable-org-isolation internal isolated-segment
cf enable-org-isolation external isolated-segment

cf target -o internal -s weeklybriefings-ui
cf set-space-isolation-segment weeklybriefings-ui isolated-segment
cf target -o internal -s weeklybriefings-api
cf set-space-isolation-segment weeklybriefings-api isolated-segment
cf target -o internal -s eHandbook-ui
cf set-space-isolation-segment eHandbook-ui isolated-segment
cf target -o internal -s eHandbook-api
cf set-space-isolation-segment eHandbook-api isolated-segment

cf target -o external -s www-ui
cf set-space-isolation-segment www-ui isolated-segment
cf target -o external -s www-api
cf set-space-isolation-segment www-api isolated-segment


REM after deploying apps, map the public-facing route to the -ui space of each app
cf target -o internal -s weeklybriefings-ui
cf map-route weeklybriefings-ui YOUR-DOMAIN --hostname weeklybriefings
cf target -o internal -s eHandbook-ui
cf map-route eHandbook-ui YOUR-DOMAIN --hostname ehandbook
cf target -o external -s www-ui
cf map-route www-ui YOUR-DOMAIN --hostname www

REM -api spaces are backend-only in this design -- no public route is mapped for them.
REM If a given app's API does need a public/callable route, map it the same way, e.g.:
REM   cf target -o internal -s weeklybriefings-api
REM   cf map-route weeklybriefings-api YOUR-DOMAIN --hostname api-weeklybriefings

REM create A records in F5 to point to the router in each foundation according to what what part of the SDLC the app is in.

REM Application Security Groups
REM SQL-ACCESS-ASG -- bound only to the -api spaces, matching asgs\sql-access-asg.json
REM under cf-mgmt-config\production\. Replace <ENTERPRISE-SQL-SERVER-IP> before running.
cf create-security-group SQL-ACCESS-ASG sql-access-asg.json
cf bind-security-group SQL-ACCESS-ASG internal weeklybriefings-api
cf bind-security-group SQL-ACCESS-ASG internal eHandbook-api
cf bind-security-group SQL-ACCESS-ASG external www-api

REM default-deny-1433 is a platform-wide DEFAULT running/staging security group, not one bound
REM per space -- see default_asgs\default-deny-1433.json under cf-mgmt-config\production\ and the
REM "ASGs are additive, not restrictive" caveat in that folder's README.md before applying this
REM platform-wide, since it replaces the existing default for every app on the foundation:
REM   cf create-security-group default-deny-1433 default-deny-1433.json
REM   cf bind-running-security-group default-deny-1433
REM   cf bind-staging-security-group default-deny-1433
