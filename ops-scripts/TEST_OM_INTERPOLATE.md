# example exercise to interpolate variables into a config file using om interpolate

A configuration file (config.yml) might have a placeholder:

# config.yml
```yaml
app_domain: ((domain_name))
instances: 3
```
A variables file (vars.yml) contains the actual value: 

# vars.yml
```yaml
domain_name: example.com
```

Running the om interpolate command (similar to the BOSH CLI bosh interpolate command) would produce the final configuration: 
```bash
om interpolate -c config.yml -l vars.yml
```

Result:
yaml
```
app_domain: example.com
instances: 3
```