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
4. When you have the image built, start a new container and mount the directory on your machine to the code location in the docker container:
```
docker run -i -t rfam-local:latest /bin/bash
```
5. In the container, create a working directory and start [building families](https://docs.google.com/document/d/1sEwBRxZZjUiCV4fim9kLuiKQyyJXLLn0hXKd1qWC_Uw/edit?pli=1)

## For Developers:
To easily test any changes your make to the code, mount your local directory to the rfam-family-pipeline directory in the docker container.
```
docker run -i -t rfam-local:latest -v /path/to/local/rfam-family-pipeline:/Rfam/rfam-family-pipeline /bin/bash
```
