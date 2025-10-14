package main

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:time"
import "../src/server"
import "core:slice"
import lib"../src/library"
/*
Copyright (c) 2025-Present Marshall A. Burns

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

main ::proc(){
    using lib
    using fmt
    using server

    config:= create_custom_config()
    server:= create_custom_server(config)

    // Run the server
    result := serve(server)
}

@(cold)
create_custom_config :: proc() -> lib.Config {
    using lib

    //General config setup. Modify at own discretion
    config :Config

    //Modify these values in src/library/common.odin if you so choose
    config.port = SERVER_PORT
    config.host = HOST
    config.bindAddress =  BIND_ADDRESS
    config.apiVersion = API_VERSION
    config.backlogSize  = BACKLOG_SIZE
    config.maxConnections = MAX_CONNECTIONS
    //Security config information
    config.security.maxRequestBodySizeMb = MAX_REQUEST_BODY_SIZE_MB
    //CORS config information
    allowedOrigins:[]string={DEFAULT_ADDRESS}
    config.cors.allowedOrigins = slice.clone(allowedOrigins)

    allowedMethods:[]lib.HttpMethod = slice.clone(validMethods)
    config.cors.allowedMethods =  allowedMethods

    allowedHeaders :[]string= {"Content-Type","Authorization", "authorization", "X-Requested-With", "X-API-Key"}
    config.cors.allowedHeaders = slice.clone(allowedHeaders)
    config.cors.exposeHeaders = slice.clone([]string{"X-Project-Id", "X-Resource-Count"})
    config.cors.maxAgeSeconds = MAX_AGE_SECONDS
    config.cors.allowCredentials = true

    return config
}

@(cold)
create_custom_server :: proc(config: lib.Config) -> ^lib.Server{
    using fmt
    using lib

    //Make a new server
    server := new(lib.Server)
    apiBase:= tprintf("/api/%s", config.apiVersion)

    server.startTimestamp = time.now()
    server.version = SERVER_VERSION
    server.apiBase = strings.clone(apiBase)
    server.config = config

    return server
}