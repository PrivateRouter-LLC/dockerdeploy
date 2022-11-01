# PrivateRouter DockerDeploy Script

This script is to help with the deployment of docker-compose templates on OpenWRT routers but can be ported to multiple platforms that use bash.

## You must set "TEMPLATE_DIR" and "OUTPUT_DIR" for this script to work!

Your TEMPLATE_DIR is where you store your docker-compose templates that will be deployed.

Your OUTPUT_DIR is the directory the docker-compose template will be copied to and ran from.

### Example Layout:
In this example we use [PrivateRouter FRPC](https://hub.docker.com/r/privaterouterllc/frpc).
```
  /root
    /docker-compose
      /frpc
        - docker-compose.yml
```

In this example you see that we are using /root/docker-compose as our TEMPLATE_DIR which means that you can easily type
<br />`dockerdeploy frpc`<br />
to launch the container.

The script copies the template folder (taken from the name in the command) and copies it to the OUTPUT_DIR and spins it up.

***NOTE: Once a template has been copied over, it will not duplicate itself so running the command again for that template just restarts the existing one.***

# Generating the .env

There are two ways to actually generate the .env that can be used in your templates.

1) The default way is to just use what the script generates into the .env like GEN_PASS which lets you dynamically generate passwords for security.

2) Use `construct.sh`:
  This method allows you to handle any more sophisticated tasks like creating a manual file for your docker-compose.yml or downloading specific templates from other sources.

If you have a file named construct.sh inside your template directory, it will be executed as a bash script. It also must generate a .env before it exits or else the dockerdeploy will not bring up the container.

# Construct Information

As mentioned above, the construct.sh can be actually anything you want, but it is only needed for more complicated templates.

If you are just using a generic template we suggest not worrying about the construct.sh and use GEN_PASS and GEN_PASS2 if you need a password in the template.