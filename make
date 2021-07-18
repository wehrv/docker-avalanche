#!/bin/bash

NETW=mainnet
COMM=master

vars () {
read -r -d '' DOCKFILE <<-EOF
        FROM     golang:latest
        WORKDIR  /root/avax
        ARG      COMM
#	      ADD      https://api.github.com/repos/ava-labs/avalanchego/commits?per_page=1 /tmp/commits
        RUN      git clone https://github.com/ava-labs/avalanchego.git .
        RUN      git checkout ${COMM}
        RUN      ./scripts/build.sh
        FROM     debian:latest
#        FROM     archlinux:latest
        WORKDIR  /root/build
        COPY     --from=0 /root/avax/build/ .
        WORKDIR  /root
        CMD      ./build/avalanchego             \
                 --http-host=0.0.0.0             \
                 --network-id=\${NETW}           \
                 --dynamic-public-ip=ifconfigme  \
                 --dynamic-update-duration=60m 
EOF
}

base () {
        vars
        docker pull debian:latest
#        docker pull archlinux:latest
        docker pull golang:latest
        echo "${DOCKFILE}" | docker build --build-arg COMM="${COMM}" -t avax:${COMM} -
}

drop () {
	while [ "$(docker service inspect avax-${NAME})" != "[]" ] ; do
		docker service rm avax-${NAME}
	done
}

dock () {
        docker service create                                    \
                --env BOOT=${BOOT}                               \
                --env NODE=${NODE}                               \
                --env NETW=${NETW}                               \
								--name avax-${NAME}                              \
                --mount src=avax-${NAME},dst=/root/.avalanchego  \
                --publish ${HTTP}:9650                           \
                --publish ${STAK}:9651                           \
                avax:${COMM}
}

mainnet () {
        NAME=main
        HTTP=9650
        STAK=9651
				NETW=mainnet
				base
        drop
        dock
}

fujinet () {
        NAME=fuji
        HTTP=9750
        STAK=9751
        NETW=fuji
				base
        drop
        dock
}

if [ $# -eq 0 ] ; then
        echo "app main: make mainnet"
        echo "    fuji: make fuji"
        exit
fi

while (( "$#" )) ; do
  if [ "$1" == "main" ] ; then
    NETW="main"
	elif [ "$1" == "fuji" ] ; then
    NETW="fuji"
	else
		COMM="$1"
	fi
  shift
  if [ $$ -eq 0 ] ; then
     break
  fi
done

if [ "${NETW}" == "main" ] ; then
	mainnet
elif [ "${NETW}" == "fuji" ] ; then
	fujinet
fi
