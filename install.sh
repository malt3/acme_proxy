#!/bin/bash

# check if we are running as root
if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Load configuration
source ${SCRIPTPATH}/config

# check if nginx is actually installed in the specified location
if [ ! -d "${NGINX_CONF_DIR}" ]; then echo "nginx config dir \"${NGINX_CONF_DIR}\" doesn't exist!" ; exit 1 ; fi

# create the needed folders
mkdir -p ${NGINX_CONF_DIR}/acmeconf.d/
chown www-data:www-data ${NGINX_CONF_DIR}/acmeconf.d

# create user for acme_proxy
adduser \
	--gecos 'User for acme_proxy' \
	--disabled-password \
	${USER}

# create bin folder
mkdir -p ${INSTALL_PREFIX}/acme_proxy/
# install the binaries
install -o www-data -g www-data -m 755 ${SCRIPTPATH}/pre_challenge ${SCRIPTPATH}/post_challenge ${INSTALL_PREFIX}/acme_proxy/
install -o root -g root -m 755 ${SCRIPTPATH}/reload_nginx ${INSTALL_PREFIX}/acme_proxy/
# install text only files
install -o www-data -g www-data -m 600 ${SCRIPTPATH}/config ${SCRIPTPATH}/challenge.conf.template ${INSTALL_PREFIX}/acme_proxy/

# allow user acme_proxy to execute pre_challenge and post_challenge as root
/bin/cat <<EOM > /etc/sudoers.d/acme_proxy_rules
${USER} ALL=(ALL) NOPASSWD: ${INSTALL_PREFIX}/acme_proxy/pre_challenge
${USER} ALL=(ALL) NOPASSWD: ${INSTALL_PREFIX}/acme_proxy/post_challenge
${USER} ALL=(ALL) NOPASSWD: ${INSTALL_PREFIX}/acme_proxy/nginx_reload
EOM

chown root:root /etc/sudoers.d/acme_proxy_rules
chmod 0440 /etc/sudoers.d/acme_proxy_rules

echo "Include the following configuration inside the server block for your domain:"
echo "---------------------------------------------------------------------------"
echo "include ${NGINX_CONF_DIR}/acmeconf.d/*.conf"
echo "---------------------------------------------------------------------------"

echo "You can add and remove challenges like this:"
echo "---------------------------------------------------------------------------"
echo "# add a reverse proxy entry"
echo "${INSTALL_PREFIX}/acme_proxy/pre_challenge <CERTBOT_TOKEN> <host_requesting_the_cert>:<port>"
echo "# remove reverse proxy entry after certificate was aquired"
echo "${INSTALL_PREFIX}/acme_proxy/post_challenge <CERTBOT_TOKEN>"
echo "---------------------------------------------------------------------------"
