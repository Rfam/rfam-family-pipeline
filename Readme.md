# Running the Rfam family-building-pipeline locally using Docker
1. Download and install [docker](https://docs.docker.com/install) for your favourite OS
2. Clone the rfam-cloud branch from GitHub: 
```
git clone -b rfam-cloud https://github.com/Rfam/rfam-family-pipeline.git
```
3. Go to the rfam-family-pipeline directory and build a docker image using the Dockerfile:
```
cd /path/to/rfam-family-pipeline
docker image build -t rfam-local .
```
4. When you have the image built and start a new container by calling: 
```
docker run -i -t rfam-local:latest /bin/bash
```
5. In the container, create a working directory and start [building families](https://docs.google.com/document/d/1sEwBRxZZjUiCV4fim9kLuiKQyyJXLLn0hXKd1qWC_Uw/edit?pli=1)


:warning: **Your work will be lost after killing the container. To prevent that from happening do one of the following:**

1. Copy all your hard work from within the container to your local machine:
```
docker container ls # use this to find the container id
docker container cp CONTAINER_ID:/workdir/within/container /path/to/local/dir
```

2. Mount a dedicated working directory on your local machine to the one in the docker container:
```
docker run -i -t rfam-local:latest -v /path/to/local/workdir:/workdir /bin/bash
```

## For Developers:
To easily test any changes your make to the code, mount your local directory to the rfam-family-pipeline directory in the docker container.
```
docker run -i -t rfam-local:latest -v /path/to/local/rfam-family-pipeline:/Rfam/rfam-family-pipeline /bin/bash
```

:exclamation: You can also mount a directory on your machine to the **/workdir** inside the container to have any testing output generated directly on your local machine:
```
docker run -i -t rfam-local:latest -v /path/to/local/rfam-family-pipeline:/Rfam/rfam-family-pipeline -v /path/to/local/dir:/workdir /bin/bash
``` 