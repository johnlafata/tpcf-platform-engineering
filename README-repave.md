REM This script is intended to be used as a guide for re-installing cf on a sandbox environment. It is not intended to be run as-is, but rather to be edited and customized as necessary for your specific environment and requirements.

REM backup the installation
ops-scripts\backup-foundation.bat sandbox 

REM Remove the old installation (if necessary)
ops-scripts\om-command.bat sandbox delete-installation

REM after edit and remove guids for resource groups in the director-config.yml, reconfigure the director
ops-scripts\configure-director.bat sandbox config-backup\sandbox-20260528-143944\director-config.yml

REM upload and stage cf tile
REM upload cf product
ops-scripts\upload-product.bat sandbox downloaded-products\srt-10.4.2-build.2.pivotal

REM stage cf product (it was already uploaded)
ops-scripts\stage-product.bat sandbox cf 10.4.2

REM configure cf
ops-scripts\om-command.bat sandbox configure-product /c config-backup\sandbox-20260525-111410\cf-config.yml

REM restore foundation services and domain
cp foundation-setup-redacted.bat foundation-setup.bat

REM edit the foundation-setup.bat file to set add the api endppoint, admin password, and other necessary variables, then execute it to complete the installation.
REM then execute foundation-setup.bat to complete the installation

REM execute orgs and spaces setup
cp create-orgs-spaces-redacted.bat create-orgs-spaces.bat

REM edit the create-orgs-spaces.bat file to set add the api endppoint, admin password, and other necessary variables, then execute it to complete the installation.
REM then execute create-orgs-spaces.bat to complete the installation

REM stage and configure any other tiles