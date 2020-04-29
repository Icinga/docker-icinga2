# Icinga 2 Docker Container

Our goal for this project is to provide official containers for Icinga components such as Icinga 2, Icinga Web 2 and Icinga DB. The images provided are officially supported by the Icinga company. Containers resulting from the development must be capable of running in production environments.

The following notes are the result of an initial discussion regarding the topic in general. They serve as a first impression of what we plan to do and give a view on how we intend to build the images.

## Use Cases and Motivarion
The decision to work on official Icinga containers is driven by the requirements various Icinga users and customers are having. There are environment where administrators don't have another choice than deploying software through containers. Additionally, we think that for new users containers can be a good alternative to get started with a standard Icinga setup quickly.

## First Steps
The first milestone includes a simple, but rock solid Icinga 2 container. Once this is achived we move forward by adding an Icinga Web 2 container, features such as certificate handling, configuration switches and other things.

## Technical Aspects
There are some technical aspects that have been discussed. This list serves as starting point for more discussions as many decision need to be made during the development process.


### Versioning
We agreed that we want to provide the following version schema for images. The version numbers are examples and the same principle applies to other Icinga containers as well.

* At least two major releases of the main software within the container should be made available.
	* For Icinga 2 this would be `2.11` and `2.12` right now.
* All minor versions of the available major versions must be made available
	* eg. `2.11.1`, `2.11.2`, `2.11.3`
* When using only the major version tag, the latest minor version is pulled automatically.
	* eg. `imagename:2.11` pulls `imagename:2.11.3`
* The `latest` tag points to the latest stable release.
	* For Icinga 2, this would be `2.11` as of now.
* Additionally the `snapshot` tag is available to use snapshot builds.

### Separation of Containers
Each service, respectively Icinga 2 and Icinga Web 2, are available through separate containers.

We will verify whether it makes sense to separate PHP FPM from the Icinga Web 2 container. This also includes the evaluation if it makes sense use the same container but start it with different parameters to allow separation.

### Base Images
We aim to provide as small images as possible containing only required software.

We do not set any requirements regarding base images yet, since this needs some further investigation. There are opposing votes against using a CentOS base image because other distributions seem to provide bug and security fixes faster.

For Icinga Web 2 we will verify the usage of Alpine Linux as base image.

### Installation
Icinga 2 should be installed through official packages. For Icinga Web there may be some advantages of cloning directly from GitHub, this has to be evaluated.

### Configuration
For Icinga 2 the whole `/etc/icinga2` and `/var/lib/icinga2` directories should be documented to be used as volumes. The default files should contain sane defaults. Additionally, we want to have environment variable in order to run the container without mounting `/etc/icinga2`. This will result in bunch of variable that need to be documented well.

For Icinga Web 2 we will have to figure out a way of providing environment variables for some of the configurations as well (where it makes sense). The whole `/etc/icingaweb2` directory should be documented to be used as a volume.

### Init System
For Icinga 2 we do not need an init system, since Icinga 2 is capable of reloading its configuration without stopping the main process.

For Icinga Web 2 we have to figure out if a system like `systemctl` is required, if a simple script can handle it, or if we don't need an init system at all.

### Plugins
We will make at least the official monitorig plugins available in the Icinga 2 containers. Users can extend the plugin set by using our Icinga 2 image as a base image and installing additional plugins on top. Additionally plugins can be made available through mount points.

Another option that can be evaluated in the future is the possibility of having a separate image only for plugins. In this case Icinga 2 must be able to call those plugins remotely somehow. This is an early stage idea and would require furhter research.

### Database Schema
Our containers take care that the initial database schema is applied. On each start the container should check if an update is available and apply that as well.

### Logs
To make the logs available through the container engine we need to make sure to change the default logging output to stdout, respectively stderr.

### Testing
Testing must be implemented from the beginning. We'll have to research if there's any framework available that we can use. Otherwise we can use custom Makefiles in combination with docker-compose to test our images in different scenarios.

### Build Platform
This needs some further research to figure out what would work best for us. Available options include GitHub Actions, GitHub + TravisCI and GitLab CI/CD, but there may be other options as well.

### Other Concerns
Some other condcerns have been brought up that we should keep in mind. One is that long running containers (> 2 Weeks) may become stale and need a restart. It is unclear whether this is an Icinga issue or something else.

Another concern is that networking can be a challenge when separating services into separate containers.

### Development
For easier development and changes of earlier stages the containers will contain lots of `RUN` blocks which is very "not best-practice" in Docker. This will be changed before the first release.

### Influences
There are many Docker containers for Icinga 2 out in the wild. Most were built to serve a special purpose and might not be fit for what this project is aiming for. Nonetheless the first commits rely heavily on the work of following users:
* [lazyfrosch](https://github.com/lazyfrosch/docker-icinga2)
* [bodsch](https://github.com/bodsch/docker-icinga2)
* [jjethwa](https://github.com/jjethwa/icinga2)
