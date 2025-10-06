package server

import "core:fmt"
import "core:net"
import "core:os"
import "core:time"
import "core:c/libc"
import "core:thread"
import "core:strings"
import "core:strconv"
import lib "../library"
/********************************************************
Author: Marshall A Burns
GitHub: @SchoolyB

Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
All Rights Reserved.

This software is proprietary and confidential. Unauthorized copying,
distribution, modification, or use of this software, in whole or in part,
is strictly prohibited without the express written permission of
Archetype Dynamics, Inc.


File Description:
            Contains logic for server session information tracking
*********************************************************/
@(private)
serverIsRunning:= false

@(private)
router := make_new_router()

serve :: proc(server: ^lib.Server) -> lib.Error {
    using lib
    using fmt

    serverIsRunning = true

    { //START OF TEMP CONTEXT ALLOCATION SCOPE
            context.allocator = context.temp_allocator

            //Example of making several static CORS preflight endpoints
            make_several_static_cors_endpoints :: proc(server: ^lib.Server){
                staticEndpoints:= []string{"ping", "health"} //Change these if you want or modify the logic :)

                for e in staticEndpoints{
                    newRoute:= make_new_route(.OPTIONS, tprintf("/%s/%s", server.apiBase, e), handle_options_request)
                    add_route_to_router(router, newRoute)
                }
            }

            //Example of making a dynamic CORS preflight endpoint.
            dynamicOptionsRoute:= make_new_route(.OPTIONS,tprintf("/%s/*", server.apiBase), handle_options_request)
            add_route_to_router(router, dynamicOptionsRoute)


            //OPTIONS '/*' dynamic route. CORS preflight related shit. Need these otherwise shit breaks
            // add_route_to_router(router, tprintf("/%s/*", server.apiBase), handle_options_request)
            // add_route_to_router(router, .OPTIONS, "/api/v1/ping", handle_options_request)
            // add_route_to_router(router, .OPTIONS, "/api/v1/health", handle_options_request)


            //Example of making several static GET request endpoints
            make_several_get_endpoints :: proc(server: ^lib.Server){
                staticEndpoints:= []string{"ping", "health"} //Change these if you want or modify the logic :)

                for e in staticEndpoints{
                    newRoute:= make_new_route(.GET, tprintf("/%s/%s", server.apiBase, e), handle_options_request)
                    add_route_to_router(router, newRoute)
                }
            }

            //Example of making a single static GET request endpoint
            dynamicRoute:= make_new_route(.GET,tprintf("/%s/*", server.apiBase), handle_options_request)
            add_route_to_router(router, dynamicRoute)

    } //END OF TEMP CONTEXT ALLOCATION SCOPE


    bindIP := parse_ip_address("127.0.0.1") //Pass is whatever address you are binding to
    endpoint := net.Endpoint{bindIP, server.config.port}

    listenSocket, listenError := net.listen_tcp(endpoint)
    if listenError != nil {
        printf("Error listening on socket: %v\n", listenError)
        return make_error( "Server Failed To Listen On TCP Socket", .ERROR, get_caller_location())
    }

    defer net.close(net.TCP_Socket(listenSocket))

    printf(
        "Odin HTTP server listening on %s:%d (bind: %s)\n",
        server.config.host,
        server.config.port,
        server.config.bindAddress,
    )

    printf("API Base URL: http://%s:%d%s\n", server.config.host, server.config.port, server.apiBase)

    // Main server loop
    for serverIsRunning {
        fmt.println("Waiting for new connection...")
        clientSocket, remoteEndpoint, acceptError := net.accept_tcp(listenSocket)
        if acceptError != nil {
            fmt.println("Error accepting connection: ", acceptError)
            return make_error("Server Failed To Accept Client TCP Socket Connection", .ERROR, get_caller_location())
        }

        handle_connection(clientSocket, server, router)
    }

    fmt.println("Server stopped successfully")
    return make_error()
}

@(cold)
handle_connection :: proc(socket: net.TCP_Socket, server: ^lib.Server, router: ^lib.Router) -> lib.Error{
    using lib
    using fmt

    defer net.close(socket)

    maxBufferSize := server.config.security.maxRequestBodySizeMb * 1024 * 1024
    buf := make([]byte, min(maxBufferSize, 4096))
    defer delete(buf)

    for {
        println("Waiting to receive data...")
        println("To safely kill the server enter: 'kill' or 'exit' then hit your 'enter' key")

        bytesRead, readTCPSocketError := net.recv(socket, buf[:])

        if bytesRead == 0 {
            println("Connection closed by client")
            return make_error()
        }

        // Parse incoming request
        method, path, headers := parse_http_request(buf[:bytesRead])


        // Extract request body for POST/PUT requests
        request_body := extract_request_body(buf[:bytesRead])
        args := []string{request_body} if len(request_body) > 0 else []string{""}

        // Handle the request using router
        httpStatus, responseBody := handle_http_request(server.config, router, method, path, headers, args)



        // Build and send response
        responseHeaders := make(map[string]string)
        responseHeaders["Content-Type"] = "application/json"
        responseHeaders["Server"] = tprintf("Odin HTTP Server:%s", server.version)
        responseHeaders["X-API-Version"] = "v1"

        // Apply CORS headers to response
        apply_cors_headers(server.config, &responseHeaders, headers, method)

        response := build_http_response(httpStatus, responseHeaders, responseBody)

        // Write response to socket
        _, writeError := net.send(socket, response)
        defer delete(response) //TODO: If a memory leak ye seek come here and take a peek - Marshall
        if writeError != nil {
            printf("ERROR: Failed to write response to socket: %v\n", writeError)
            return make_error("Server Failed To Write Response", .ERROR, get_caller_location())
        }
    }
}

// Extract request body from HTTP request
@(require_results)
extract_request_body :: proc(data: []byte) -> string {
    using strings

    lines := split(string(data), "\r\n")
    defer delete(lines)

    // Find empty line that separates headers from body
    bodyStart := -1
    for line, i in lines {
        if len(line) == 0 {
            bodyStart = i + 1
            break
        }
    }

    if bodyStart == -1 || bodyStart >= len(lines) {
        return ""
    }

    // Join remaining lines as body
    bodyLines := lines[bodyStart:]
    body := join(bodyLines, "\r\n")
    return clone(trim_space(body))
}

// // Helper proc to parse IP address strings
@(require_results)
parse_ip_address :: proc(ipString: string) -> net.IP4_Address {
    if ipString == "0.0.0.0" {
        return net.IP4_Address{0, 0, 0, 0}
    }
    if ipString == "127.0.0.1" || ipString == "localhost" {
        return net.IP4_Address{127, 0, 0, 1}
    }

    return net.IP4_Address{0, 0, 0, 0}
}

//Simply waits for a user input to kill server
HANDLE_SERVER_KILL_SWITCH :: proc() {
    using lib
    using fmt
    using strings


	for serverIsRunning {
		input := get_input()
		if input == "kill" || input == "exit" {
			serverIsRunning = false

			//Be sure to change the port number if you use a different server.config.port in main.odin
			portCString := clone_to_cstring("nc -zv localhost 8080")
			libc.system(portCString)

			return
		} else do continue
	}
}