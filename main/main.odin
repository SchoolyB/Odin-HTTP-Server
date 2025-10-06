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
    server:= create_custom_server(config)




    //Run the server
    serve(server)
}



create_custom_config :: proc() -> ^lib.Config {
    using lib

    //Make a new config to be passed to the server
    config := new(Config)


    //Here you can choose several ports to allow your server to run on
    //I made it this way because so many applications i.e Vite, node, etc
    // tend to  run on similar ports. Just modify the numbers
    serverPorts:= make([dynamic]int)



    //General config information. Modify discretion
    config.port = 8080
    config.host = "localhost"
    config.bindAddress =  "127.0.0.1"
    config.apiVersion = "v1"
    config.backlogSize  = 3
    config.maxConnections = 1

    //Security config information. Modify discretion
    config.security.maxRequestBodySizeMb = 5

    //CORS config information. Modify discretion
    config.cors.allowedOrigins = {"http://localhost:8080", } //Add more if needed
    config.cors.allowedMethods = {.GET, .DELETE, .HEAD, .OPTIONS, .POST, .PUT}
    config.cors.allowedHeaders = {"Content-Type", "Authorization", "authorization", "X-Requested-With", "X-API-Key"}
    config.cors.exposeHeaders = {"X-Project-Id", "X-Resource-Count"}
    config.cors.maxAgeSeconds = 86400
    config.cors.allowCredentials = true


    return config
}


create_custom_server :: proc(config: ^lib.Config) -> ^lib.Server{
    using fmt
    using lib

    //Make a new server
    server := new(lib.Server)

    server.startTimestamp = time.now()
    server.version = "v0.1.0" //Modify this if you so choose
    server.apiBase = tprintf("/api/%s", config.apiVersion)
    server.config = config

    return server
}