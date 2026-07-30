REM This script is intended to be used as a guide for re-installing cf on a sandbox environment. It is not intended to be run as-is, but rather to be edited and customized as necessary for your specific environment and requirements.

REM Remove the old installation (if necessary)
ops-scripts\om-command.bat production delete-installation

REM after remove guids for resource groups in the director-config.yml, reconfigure the director
ops-scripts\configure-director.bat production config-backup\sandbox-20260528-143944\director-config.yml

REM upload and stage cf tile
REM upload cf product
ops-scripts\upload-product.bat sandbox downloaded-products\srt-10.0.5-build.2.pivotal

REM stage cf product (it was already uploaded)
ops-scripts\stage-product.bat sandbox cf 10.0.5

REM configure cf
ops-scripts\om-command.bat sandbox configure-product /c config-backup\sandbox-20260525-111410\cf-config.yml

REM  edit as necessary to configure nsx-t for networking, instead of standard networking

REM REFERENCE THIS DOCUMENT FOR CONFIGURING NSX-T: https://docs.pivotal.io/platform/3-2/operations-guide/nsx-t.html

REM reference word document

REM  upload ncp
ops-scripts\upload-product.bat production downloaded-products\VMware-NSX-T-9.0.0.0.24869255.pivotal

REM state ncp tile
ops-scripts\stage-product.bat production VMware-NSX-T 9.0.0.0.24869255

REM execute foundation setup
cp foundation-setup-redacted.bat foundation-setup.bat
REM edit the foundation-setup.bat file to set add the api endppoint, admin password, and other necessary variables, then execute it to complete the installation.
REM then exeucte foundation-setup.bat to complete the installation

REM execute orgs and spaces setup
cp create-orgs-spaces-redacted.bat create-orgs-spaces.bat
REM edit the create-orgs-spaces.bat file to set add the api endppoint, admin password, and other necessary variables, then execute it to complete the installation.
REM then exeucte create-orgs-spaces.bat to complete the installation
