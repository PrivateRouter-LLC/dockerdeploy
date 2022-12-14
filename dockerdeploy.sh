#!/usr/bin/env bash
# version: 1.6
# contact: ops@torguard.net
# PrivateRouter DockerDeploy Script
# TIP: for global access, ln -s dockerdeploy.sh /usr/bin/dockerdeploy

# Check if we are running in another instance
if pgrep -x "docker-compose" > /dev/null
then
  echo "Another instance of this script is running, please wait a little bit before trying again."
  exit 1
fi

# This script accepts one input, the name of the folder it looks for in our template directory.
COMPOSE="${1}"

# This is where our templates are stored and searched for
TEMPLATE_DIR=/root/docker-compose

# This is the directory we copy our compose files to before we bring them up
OUTPUT_DIR=/opt/docker2/compose

# We set a variable for our from and final destination directories
# Note: These are not meant to be edited
FROM_DIR="${TEMPLATE_DIR}/${COMPOSE}"
FINAL_DIR="${OUTPUT_DIR}/${COMPOSE}"

# Get our local LAN IP Address
LAN_IP=$(uci get network.lan.ipaddr)
# Strip trailing network mask
LAN_IP="${LAN_IP%/*}"

# Generate the generic environment variables for the docker-compose
gen_env() {
  GEN_PASS=$(< /dev/urandom tr -dc A-Za-z0-9 2>/dev/null | head -c14; echo)
  GEN_PASS2=$(< /dev/urandom tr -dc A-Za-z0-9 2>/dev/null | head -c14; echo)

cat > ${FINAL_DIR}/.env <<-EOF
INSTANCE_NAME=${COMPOSE}
LAN_IP=${LAN_IP}
GEN_PASS=${GEN_PASS}
GEN_PASS2=${GEN_PASS2}
EOF
}

# Brings our docker-compose up
docker_up() {
  # We now check if the container is already up
  UP_CHECK=$(docker ps -a | grep ${COMPOSE} | awk '{ print $7 }')
  if [ "${UP_CHECK}" != "Up" ]; then
    # Switch to the proper directory
    pushd "${FINAL_DIR}" >/dev/null 2>&1
    # Bring docker-compose up and output to log
    docker-compose up -d >/tmp/dockerdeploy.log 2>&1 &
    # Error check to verify we came up ok
    if [ "$?" != 0 ]; then
      echo "There was a failure executing docker-compose up inside '${FINAL_DIR}'.";
      exit 1;
    else
      # Check if the container is running and if so get the ports it is running on
      if [ "$(docker ps | grep ${COMPOSE})" ]; then
        PORTS=($(docker ps | grep ${COMPOSE} | awk -v FS="(0.0.0.0:|->)" '{print $2,$5,$8,$11}'))
        echo "Your container has been brought up and you should be able to access it on port(s):"

        # Print our ports
        for p in "${PORTS[@]}"
        do
          echo "http://${LAN_IP}:${p}"
        done

      else
        # Tell that the container is starting and they need to wait for it to finish
        echo "Your container is starting in the background. Please wait a few moments and click button again to find out link to connect to it."
      fi
    fi
    # Get out of the work directory
    popd >/dev/null 2>&1
  elif [ "${UP_CHECK}" == "Up" ]; then
    # If we are already up then we change into the work directory and then restart
    pushd "${FINAL_DIR}" >/dev/null 2>&1
    echo "${COMPOSE} is restarting, this will take a few seconds"
    # Do a force-recreate on our docker-compose up since we are already running
    docker-compose up -d --force-recreate >/tmp/dockerdeploy.log 2>&1 &
    if [ "$?" != 0 ]; then
      echo "There was a failure executing docker-compose up inside '${FINAL_DIR}'.";
      exit 1;
    else
      # Give everything a chance to start up before printing ports
      sleep 5
      # If we came up ok we print our ports that we are using
      if [ "$(docker ps | grep ${COMPOSE})" ]; then
        PORTS=($(docker ps | grep ${COMPOSE} | awk -v FS="(0.0.0.0:|->)" '{print $2,$5,$8,$11}'))
        echo "Your container has been brought up and you should be able to access it on port(s):"

        # Print the ports
        for p in "${PORTS[@]}"
        do
          echo "http://${LAN_IP}:${p}"
        done
      fi
    fi
    popd >/dev/null 2>&1
  fi
}

# If we did not get anything passed into the script, we exit.
[ -z ${COMPOSE} ] && { echo "This script requires the name of a compose folder to look for."; exit 1; }

# Check if our template directory contains our folder, and if it also contains our docker-compose.yml
[[ -d "${FROM_DIR}" && -f "${FROM_DIR}/docker-compose.yml" ]] || { 
  echo "There was no docker-compose.yml found in '${FROM_DIR}', or this is an invalid directory."; 
  exit 1; 
}

# Create the directory if it does not exist.
[ -d "${OUTPUT_DIR}" ] || mkdir "${OUTPUT_DIR}"

# If we have already copied a template to run then we just use it
if [ -d "${FINAL_DIR}" ]; then
  # We verify if the .env and docker-compose.yml are there
  [[ -f "${FINAL_DIR}/docker-compose.yml" && -f "${FINAL_DIR}/.env" ]] || {
    echo "We did not find a 'docker-compose.yml' or '.env' inside '${FINAL_DIR}', so to be safe we are exiting.";
    exit 1;
  } 

  # Now we bring up our docker container
  docker_up

else
  # If this is the first time we are setting up this template, we copy it over
  echo "Copying template '${FROM_DIR}' to '${FINAL_DIR}'."
  cp -R "${FROM_DIR}" "${FINAL_DIR}"
  
  # Check if there is a construct.sh file inside of our template directory
  if [ -f "${FINAL_DIR}/construct.sh" ]; then
    # We have a construct.sh inside our template so we must write our stub to handle the rest of our execution
	echo "Executing our pre-requisit '${FINAL_DIR}/construct.sh' file"
	bash "${FINAL_DIR}/construct.sh"
	if [ "$?" != 0 ]; then
      echo "There was a failure executing '${FINAL_DIR}/construct.sh'.";
      exit 1;
	fi
  else
    # We did not find a construct.sh so we do our .env generation just like normal
	echo "Generating our .env file for secure variables."
    gen_env
  fi
  
  sleep 1
  
  # Once we have finished our .env generation tasks above, we now do our docker-compose up function
  [ -f "${FINAL_DIR}/.env" ] && docker_up || {
    echo "We are missing our required .env file! If you are using construct.sh to generate the .env please verify it worked correctly.";
	exit 1;
  }
fi

# Final output that displays the link to the docker panel in luci
echo -e "Find out more details about your container's status by visiting the Docker Containers page at:\nhttps://${LAN_IP}/cgi-bin/luci/admin/docker/containers"
