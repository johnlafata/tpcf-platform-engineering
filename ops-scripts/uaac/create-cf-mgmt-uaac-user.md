# Create cf-mgmt UAA Client

`uaac` command reference for provisioning the `cf-mgmt` UAA client. 

```cmd
uaac target https://uaa.<sys-domain> --skip-ssl-validation

uaac token client get admin -s ADMIN-CLIENT-SECRET

uaac client add cf-mgmt --secret YOUR-SECRET --authorized_grant_type client_credentials --authorities cloud_controller.admin,scim.read,scim.write,clients.read,clients.write,clients.secret,clients.admin,uaa.admin,routing.router_groups.read
```

Pick your own `cf-mgmt` client secret and save it somewhere durable, e.g. `env-creds\<foundation>\cf-mgmt-env.yml` (gitignored).
