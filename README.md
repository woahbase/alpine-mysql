[![Build Status](https://travis-ci.org/woahbase/alpine-mysql.svg?branch=master)](https://travis-ci.org/woahbase/alpine-mysql)

[![](https://images.microbadger.com/badges/image/woahbase/alpine-mysql.svg)](https://microbadger.com/images/woahbase/alpine-mysql)

[![](https://images.microbadger.com/badges/commit/woahbase/alpine-mysql.svg)](https://microbadger.com/images/woahsbase/alpine-mysql)

[![](https://images.microbadger.com/badges/version/woahbase/alpine-mysql.svg)](https://microbadger.com/images/woahbase/alpine-mysql)

## Alpine-MySQL
#### Container for Alpine Linux + S6 + MySQL

---

This [image][8] serves as the database container for
applications/services tht require a [MySQL][12] database running.

If it is required to run in the same container as the app is
running, use this container as the source. Can create the database
specified in the command line if not exists, has handy **backup** and
**restore** commands available inside the image.

Built from my [alpine-s6][9] image with the [s6][10] init system
[overlayed][11] in it.

The image is tagged respectively for the following architectures,
* **armhf**
* **x86_64**

**armhf** builds have embedded binfmt_misc support and contain the
[qemu-user-static][5] binary that allows for running it also inside
an x64 environment that has it.

---
#### Get the Image
---

Pull the image for your architecture it's already available from
Docker Hub.

```
# make pull
docker pull woahbase/alpine-mysql:x86_64

```

---
#### Run
---

If you want to run images for other architectures, you will need
to have binfmt support configured for your machine. [**multiarch**][4],
has made it easy for us containing that into a docker container.

```
# make regbinfmt
docker run --rm --privileged multiarch/qemu-user-static:register --reset

```
Without the above, you can still run the image that is made for your
architecture, e.g for an x86_64 machine..

```
# make
docker run --rm -it \
  --name docker_mysql --hostname mysql \
  -c 512 -m 512m \
  -e PGID=100 -e PUID=1000 \
  -e MYSQL_ROOT_PWD=insecurebydefault \
  -e MYSQL_USER=mysql \
  -e MYSQL_USER_PWD=insecurebydefault \
  -e MYSQL_USER_DB=test \
  -p 3306:3306 \
  -v data:/var/lib/mysql \
  -v /etc/hosts:/etc/hosts:ro \
  -v /etc/localtime:/etc/localtime:ro \
  woahbase/alpine-mysql:x86_64


# make stop
docker stop -t 2 docker_mysql

# make rm
# stop first
docker rm -f docker_mysql

# make restart
docker restart docker_mysql

# make backup DBNAME=<databasename>
# backup databases
# the backup should be named <databasename>.sql and is dropped
  inside /var/lib/mysql/backups (local: data/backups)
docker exec -it docker_mysql /scripts/run.sh backup <databasename>

# make restore DBNAME=<databasename>
# restore a single databases
# restores the <databasename> database from the file
# /var/lib/mysql/backups/<databasename>.sql (local: data/backups/<databasename>.sql)
docker exec -it docker_mysql /scripts/run.sh restore <databasename>


```

---
#### Shell access
---

```
# make rshell
docker exec -u root -it docker_mysql /bin/bash

# make shell
docker exec -it docker_mysql /bin/bash

# make logs
docker logs -f docker_mysql

```

---
## Development
---

If you have the repository access, you can clone and
build the image yourself for your own system, and can push after.

---
#### Setup
---

Before you clone the [repo][7], you must have [Git][1], [GNU make][2],
and [Docker][3] setup on the machine.

```
git clone https://github.com/woahbase/alpine-mysql
cd alpine-mysql

```
You can always skip installing **make** but you will have to
type the whole docker commands then instead of using the sweet
make targets.

---
#### Build
---

You need to have binfmt_misc configured in your system to be able
to build images for other architectures.

Otherwise to locally build the image for your system.

```
# make ARCH=x86_64 build
# sets up binfmt if not x86_64
docker build --rm --compress --force-rm \
  --no-cache=true --pull \
  -f ./Dockerfile_x86_64 \
  -t woahbase/alpine-mysql:x86_64 \
  --build-arg ARCH=x86_64 \
  --build-arg DOCKERSRC=alpine-s6 \
  --build-arg USERNAME=woahbase \
  --build-arg PUID=1000 \
  --build-arg PGID=1000

# make ARCH=x86_64 test
docker run --rm -it \
  --name docker_mysql --hostname mysql \
  woahbase/alpine-mysql:x86_64 \
  mysql --version

# make ARCH=x86_64 push
docker push woahbase/alpine-mysql:x86_64

```

---
## Maintenance
---

Built daily at Travis.CI (armhf / x64 builds). Docker hub builds maintained by [woahbase][6].

[1]: https://git-scm.com
[2]: https://www.gnu.org/software/make/
[3]: https://www.docker.com
[4]: https://hub.docker.com/r/multiarch/qemu-user-static/
[5]: https://github.com/multiarch/qemu-user-static/releases/
[6]: https://hub.docker.com/u/woahbase

[7]: https://github.com/woahbase/alpine-mysql
[8]: https://hub.docker.com/r/woahbase/alpine-mysql
[9]: https://hub.docker.com/r/woahbase/alpine-s6

[10]: https://skarnet.org/software/s6/
[11]: https://github.com/just-containers/s6-overlay
[12]: https://www.mysql.com/
