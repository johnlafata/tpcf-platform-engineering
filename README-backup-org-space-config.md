#  backup the foundation setup
cf-mgmt export-config --config-dir cf-mgmt-config\production --system-domain <sys-domain> --user-id cf-mgmt --client-secret YOUR-SECRET

# verify the configuration restores properly
cf-mgmt apply --config-dir=cf-mgmt-config\production --system-domain <sys-domain> --user-id cf-mgmt --client-secret YOUR-SECRET --peek
