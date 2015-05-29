# mu-dispatcher

Core microservice for dispatching requests to the preferred microservice.

The mu-dispatcher is one of the core elements in the mu.semte.ch architecture.  This service will dispatch requests to other microservices based on the incoming request path.  You can run the service through docker, but you probably want to configure it using [mu-project](http://github.com/mu-semtech/mu-project) so it uses your own configuration.
