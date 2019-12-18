package main

import (
    "flag"
    "fmt"
    "log"

    "example.com/gen/restapi"
    "example.com/gen/restapi/operations"
    "github.com/go-openapi/loads"
    "github.com/go-openapi/runtime/middleware"
    "github.com/go-openapi/swag"
)

var portFlag = flag.Int("port", 3000, "Port to run this service on")
var versionFlag = flag.String("version", "V1", "Simulated implementation version")

func main() {
    // load embedded swagger file
    swaggerSpec, err := loads.Analyzed(restapi.SwaggerJSON, "")
    if err != nil {
        log.Fatalln(err)
    }

    // create new service API
    api := operations.NewGreeterAPI(swaggerSpec)
    server := restapi.NewServer(api)
    defer server.Shutdown()

    // parse flags
    flag.Parse()
    // set the port this service will be run on
    server.Port = *portFlag

    api.GetGreetingHandler = operations.GetGreetingHandlerFunc(
        func(params operations.GetGreetingParams) middleware.Responder {
            name := swag.StringValue(params.Name)
            if name == "" {
                name = "World"
            }

            greeting := fmt.Sprintf("%s: Hello, %s!", *versionFlag, name)
            return operations.NewGetGreetingOK().WithPayload(greeting)
        })

    // serve API
    if err := server.Serve(); err != nil {
        log.Fatalln(err)
    }
}
