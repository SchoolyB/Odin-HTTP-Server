package main

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:time"
import "../src/server"
import lib"../src/library"



main ::proc(){
    using lib
    using fmt
    using server

    config:= create_custom_config()
    fmt.println("DEBUG: config: ", config)
    // server:= create_custom_server(config)

    //Run the server
    // serve(server)
}



create_custom_config :: proc() -> lib.Config {
    using lib

    //Make a new config to be passed to the server
    // config := new(Config)

    //General config information. Modify discretion

    config : Config
    config.port = 8080 //If you modify this, update the port in HANDLE_SERVER_KILL_SWITCH() in server.odin
    config.host = strings.clone("localhost")
    config.bindAddress =  strings.clone("127.0.0.1")
    config.apiVersion = strings.clone("v1")
    config.backlogSize  = 3
    config.maxConnections = 1

    //Security config information. Modify discretion
    config.security.maxRequestBodySizeMb = 5

    //CORS config information. Modify discretion
    allowedOrigins:[]string={"http://localhost:8080"}
    config.cors.allowedOrigins = allowedOrigins

    fmt.println("HEY FUCKO: config.cors.allowedOrigins: ", config.cors.allowedOrigins)
    allowedMethods:[]lib.HttpMethod = {.GET, .DELETE, .HEAD, .OPTIONS, .POST, .PUT}
    config.cors.allowedMethods =  allowedMethods


    allowedHeaders :[]string= {"Content-Type","Authorization", "authorization", "X-Requested-With", "X-API-Key"}
    config.cors.allowedHeaders = allowedHeaders


    fmt.println("DEBUG: config.cors.allowedHeaders ", config.cors.allowedHeaders)
    config.cors.exposeHeaders = {strings.clone("X-Project-Id"), strings.clone("X-Resource-Count")}
    config.cors.maxAgeSeconds = 86400
    config.cors.allowCredentials = true


    return config
}


create_custom_server :: proc(config: ^lib.Config) -> ^lib.Server{
    using fmt
    using lib

    //Make a new server
    server := new(lib.Server)

    serverVersion:= "v0.1.0" //Modify this if you so choose
    apiBase:= tprintf("/api/%s", config.apiVersion)
    hostBaseVersion:= strings.clone(tprintf("%s:%d/%s", &server.config.host, &server.config.port, apiBase))

    fmt.println("fjadkfkjsf:  hostBaseVersion",  hostBaseVersion)


    server.startTimestamp = time.now()
    server.version = serverVersion
    server.apiBase = strings.clone(apiBase)

    // server.hostBaseVersion = strings.clone(tprintf("%s:%d/%s", server.config.host, server.config.port,server.apiBase))

    fmt.println(server)
    server.config = config

    return server
}