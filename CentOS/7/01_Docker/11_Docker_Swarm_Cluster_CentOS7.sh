# Docker : Swarm Cluster
# What is Docker Swarm?
# Docker Swarm is an orchestration management tool that runs on Docker applications. It helps end-users in creating and deploying a cluster of Docker nodes.
# Each node of a Docker Swarm is a Docker daemon, and all Docker daemons interact using the Docker API. Each container within the Swarm can be deployed and accessed by nodes of the same cluster. 

#There are five critical elements within a doctor environment:
#1 Docker container 
#2 Docker daemon
#3 Docker images 
#4 Docker client 
#5 Docker registry 

# If one of the containers fails, we can use the Swarm to correct that failure.
# Docker Swarm can reschedule containers on node failures. Swarm node has a backup folder which we can use to restore the data onto a new Swarm. 

# Configure Docker Swarm to create Docker Cluster with multiple Docker nodes.
# On this example, Configure Swarm Cluster with 3 Docker nodes like follows.
# There are 2 roles on Swarm Cluster, those are [Manager nodes] and [Worker nodes].
# This example shows to set those roles like follows.

 -------------+----------------------------+----------------------------+----------
              |                            |                            |
          eth0|10.0.0.51               eth0|10.0.0.52               eth0|10.0.0.53
 +------------+-----------+   +------------+-----------+   +------------+-----------+
 | [node01.itstorage.net] |   | [node02.itstorage.net] |   | [node03.itstorage.net] |
 |       Manager          |   |        Worker          |   |        Worker          |
 +------------------------+   +------------------------+   +------------------------+

#1 Install and run Docker service on all nodes.
#2 Change settings for Swarm mode on all nodes.
root@node01:~# vi /etc/docker/daemon.json
# create new
# disable live-restore feature (impossible to use it on Swarm mode)
{
    "live-restore": false
}

[root@node01 ~]# systemctl restart docker
# if Firewalld is running, allow ports
[root@node01 ~]# firewall-cmd --add-port={2377/tcp,7946/tcp,7946/udp,4789/udp} --permanent
success
[root@node01 ~]# firewall-cmd --reload
success
[3]	Configure Swarm Cluster on Manager Node.
root@node01:~# docker swarm init
Swarm initialized: current node (bs01c7zj7r1bo8t7qx7nt4p34) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-1crqgsg3qoy8ocft9mpav8lgo3zsjf1th2s3n7wb9t9yry6tif-9ks9ex89nxnl89bg7jrzcwi6j 10.0.0.51:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
[4]	Join in Swarm Cluster on all Worker Nodes.
It's OK to run the command which was shown when running swarm init on Manager Node.
root@node02:~# docker swarm join \
--token SWMTKN-1-1crqgsg3qoy8ocft9mpav8lgo3zsjf1th2s3n7wb9t9yry6tif-9ks9ex89nxnl89bg7jrzcwi6j 10.0.0.51:2377
This node joined a swarm as a worker.
[5]	Verify with a command [node ls] that worker nodes could join in Cluster normally.
root@node01:~# docker node ls
ID                            HOSTNAME           STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
bs01c7zj7r1bo8t7qx7nt4p34 *   node01.itstorage.net   Ready     Active         Leader           20.10.5
pu0szo4f3fr9nn5zn87n77cyp     node02.itstorage.net   Ready     Active                          20.10.5
x0q143322alhmukkj94b9we7b     node03.itstorage.net   Ready     Active                          20.10.5
[6]	Verify Cluster works normally to create a test service.
For example, create a web service containers and configure Swarm service.
Generally, it is used a container image on a rgistry on all Nodes, but on this example, create container images on each Node to verify settings and accesses for Swarm Cluster.
root@node01:~# vi Dockerfile
FROM centos
MAINTAINER ServerWorld <admin.itstorage.net>

RUN yum -y install nginx
RUN echo "Nginx on node01" > /usr/share/nginx/html/index.html

EXPOSE 80
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

root@node01:~# docker build -t nginx-server:latest .
[7]	Configure service on Manager Node.
After successing to configure service, access to the Manager node's Hostname or IP address to verify it works normally. Access requests to worker nodes are load-balanced with round-robin like follows.
root@node01:~# docker images
REPOSITORY     TAG       IMAGE ID       CREATED              SIZE
nginx-server   latest    5185329f1a74   About a minute ago   289MB
centos         latest    300e315adb2f   3 months ago         209MB

# create a service with 2 repricas
root@node01:~# docker service create --name swarm_cluster --replicas=2 -p 80:80 nginx-server:latest
64pa21potpdbq1hmxbzuu3tam
overall progress: 0 out of 2 tasks
1/2: preparing
2/2: preparing
.....
.....

# show service list
root@node01:~# docker service ls
ID             NAME            MODE         REPLICAS   IMAGE                 PORTS
64pa21potpdb   swarm_cluster   replicated   2/2        nginx-server:latest   *:80->80/tcp

# inspect the service
root@node01:~# docker service inspect swarm_cluster --pretty

ID:             64pa21potpdbq1hmxbzuu3tam
Name:           swarm_cluster
Service Mode:   Replicated
 Replicas:      2
Placement:
UpdateConfig:
 Parallelism:   1
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Update order:      stop-first
RollbackConfig:
 Parallelism:   1
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Rollback order:    stop-first
ContainerSpec:
 Image:         nginx-server:latest
 Init:          false
Resources:
Endpoint Mode:  vip
Ports:
 PublishedPort = 80
  Protocol = tcp
  TargetPort = 80
  PublishMode = ingress

# show service state
root@node01:~# docker service ps swarm_cluster
ID             NAME              IMAGE                 NODE               DESIRED STATE   CURRENT STATE            ERROR     PORTS
pbjvpqru195w   swarm_cluster.1   nginx-server:latest   node02.itstorage.net   Running         Running 47 seconds ago
uwndpoduvpoy   swarm_cluster.2   nginx-server:latest   node01.itstorage.net   Running         Running 47 seconds ago

# verify it works normally
root@node01:~# curl node01.itstorage.net
Nginx on node02
root@node01:~# curl node01.itstorage.net
Nginx on node01
root@node01:~# curl node01.itstorage.net
Nginx on node02
root@node01:~# curl node01.itstorage.net
Nginx on node01
[8]	If you'd like to change the number of repricas, configure like follows.
# change repricas to 3
root@node01:~# docker service scale swarm_cluster=3
swarm_cluster scaled to 3
overall progress: 2 out of 3 tasks
1/3: running
2/3: running
3/3: preparing
.....
.....

root@node01:~# docker service ps swarm_cluster
ID             NAME              IMAGE                 NODE               DESIRED STATE   CURRENT STATE                ERROR     PORTS
pbjvpqru195w   swarm_cluster.1   nginx-server:latest   node02.itstorage.net   Running         Running about a minute ago            
uwndpoduvpoy   swarm_cluster.2   nginx-server:latest   node01.itstorage.net   Running         Running about a minute ago            
r7lmkav7hxpt   swarm_cluster.3   nginx-server:latest   node03.itstorage.net   Running         Running 15 seconds ago                

# verify accesses
root@node01:~# curl node01.itstorage.net
Nginx on node01
root@node01:~# curl node01.itstorage.net
Nginx on node03
root@node01:~# curl node01.itstorage.net
Nginx on node02



