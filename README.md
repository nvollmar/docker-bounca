# Docker - BounCA

This project is used to build BounCA docker image.

Prebuilt images available on [Docker Hub](https://hub.docker.com/u/aluveitie)

## Available Architectures
- amd64
- arm64 (aarch64)

## Try it out
```
# Create dedicated docker network
docker network create net-bounca

# Start fresh postgres db
docker run --rm -d --name postgres --network=net-bounca --network-alias=postgres.net-bounca -e POSTGRES_USER=bounca -e POSTGRES_PASSWORD=bounca postgres:16.1-alpine

# Start BounCA
docker run -p 8080:8080 --rm -dit -e BOUNCA_FQDN=localhost --name bounca --network=net-bounca -e DB_PWD=bounca aluveitie/bounca:latest
```

### Using docker-compose

```
docker-compose up -d
```

Access it on http://localhost:8080 and sign up to create your admin user

### Using kubernetes

To deploy in Kubernetes see the [deployment.yml](deployment.yml) example.

## How to build yourself

```
# Multi platform to your prefered registry
docker buildx build --platform=linux/arm64,linux/amd64 --file Dockerfile --push .

# Single platform to run in local docker
docker buildx build --platform=linux/arm64 --file Dockerfile -t bounca:latest --load .
```

Publish with Podman
```
# Multi platform to your prefered registry
podman manifest create bounca:latest
podman buildx build --platform=linux/arm64,linux/amd64 --file Dockerfile --manifest bounca:latest .
podman manifest push bounca:latest docker://your-registry.io/bounca:latest
```

## Sources
- https://github.com/repleo/bounca/
- https://github.com/repleo/docker-bounca
- https://github.com/repleo/docker-compose-bounca
- https://www.bounca.org/getting_started.html#deploy-docker
- https://github.com/repleo/ansible-role-bounca

## Credits
This project was forked from [NoxInmortus](https://git.spartan.noxinmortus.fr/Docker/docker-bounca) and updated to build current versions of BounCA and multiple platforms.

## License
MIT view [LICENSE](LICENSE)
