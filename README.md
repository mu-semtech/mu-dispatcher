# mu-dispatcher

Core microservice for dispatching requests to the preferred microservice.

The mu-dispatcher is one of the core elements in the mu.semte.ch architecture.  This service will dispatch requests to other microservices based on the incoming request path.  You can run the service through docker, but you probably want to extend it so it uses your own configuration.

## How to

Setting up your environment is done in three easy steps:  First you configure the running microservices and their names in `docker-compose.yml`, then you configure how requests are dispatched in `lib/dispatcher.ex`, and lastly you start everything.

### Hooking things up with docker-compose

Alter the `docker-compose.yml` file so it contains all microservices you need.  The example content should be clear, but you can find more information in the (https://docs.docker.com/compose/)[Docker Compose documentation].  Don't remove the `mu-identifier` and `virtuoso` container, they are respectively the entry-point and the database of your application.  Don't forget to link the necessary microservices to the dispatcher and the database to the microservices.

### Configure the dispatcher

Next, alter the file `lib/dispatcher.ex` based on the example that is there by default.  Dispatch requests to the necessary microservices based on the names you used for the microservice.

### Boot up the system

Boot your microservices-enabled system using docker-compose.

    cd /path/to/mu-dispatcher
    docker-compose up

You can shut down using `docker-compose stop` and remove everything using `docker-compose rm`.
