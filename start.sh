if [ ! -f boot2docker.iso ];
then
  wget https://github.com/boot2docker/boot2docker/releases/download/v1.9.1/boot2docker.iso
fi

read -p "Press [Enter] key to continue..."


iso="https://github.com/boot2docker/boot2docker/releases/download/v1.9.1/boot2docker.iso"
iso="file:///home/hoeghh/Development/docker-network/boot2docker.iso"

# Create a node to house the consul server
docker-machine create -d virtualbox --virtualbox-boot2docker-url $iso consul-keystore

# Run consul
docker $(docker-machine config consul-keystore) run -d \
    -p "8500:8500" \
    -h "consul" \
    progrium/consul -server -bootstrap


# Create swarm master
docker-machine create \
	-d virtualbox \
	--swarm --swarm-master \
	--swarm-discovery="consul://$(docker-machine ip consul-keystore):8500" \
        --virtualbox-boot2docker-url $iso \
	--engine-opt="cluster-store=consul://$(docker-machine ip consul-keystore):8500" \
	--engine-opt="cluster-advertise=eth1:2376" \
	dn-swarmmaster &

# Create swarm slave 1
docker-machine create -d virtualbox \
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip consul-keystore):8500" \
    --virtualbox-boot2docker-url $iso \
    --engine-opt="cluster-store=consul://$(docker-machine ip consul-keystore):8500" \
    --engine-opt="cluster-advertise=eth1:2376" \
    dn-swarmnode-01 &

# Create swarm slave 2
docker-machine create -d virtualbox \
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip consul-keystore):8500" \
    --virtualbox-boot2docker-url $iso \
    --engine-opt="cluster-store=consul://$(docker-machine ip consul-keystore):8500" \
    --engine-opt="cluster-advertise=eth1:2376" \
    dn-swarmnode-02 &

wait
sleep 5

eval $(docker-machine env --swarm dn-swarmmaster)
docker-machine ls
docker info

read -p "Press [Enter] key to continue..."

# Create overlay network
docker network create --driver overlay my-net

docker network ls
read -p "Press [Enter] key to continue..."

# Run nginx on a dn-swarmmaster
eval $(docker-machine env --swarm dn-swarmmaster)
docker run -itd --name=web -p 80:80 --net=my-net --env="constraint:node==dn-swarmnode-01" nginx

# Run busybox on dn-swarmnode-01 that pulls nginx webpage
docker run -it --rm --net=my-net --env="constraint:node==dn-swarmnode-01" busybox wget -O- http://web

# Run busybox on dn-swarmnode-02 that pulls nginx webpage
docker run -it --rm --net=my-net --env="constraint:node==dn-swarmnode-02" busybox wget -O- http://web

# Get if from local pc
curl $(docker-machine ip dn-swarmnode-01)
