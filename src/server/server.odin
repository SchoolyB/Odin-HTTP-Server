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

run_ostrich_server :: proc(server: ^lib.Server) -> ^lib.Error {
    using lib
    using fmt

    // Initialize dynamic path system
    pathConfig := config.init_dynamic_paths()
    defer config.cleanup_dynamic_paths()

    // Load application config
    appConfig := config.load_config_with_dotenv()

    serverIsRunning = true

    server.port = appConfig.server.port
    apiBase := fmt.tprintf("/api/%s", server.version)

    { //START OF TEMP CONTEXT ALLOCATION SCOPE
            context.allocator = context.temp_allocator

            //OPTIONS '/*' dynamic route. CORS preflight related shit. Need these otherwise shit breaks

            //Example CORS preflight for static endpoints
            add_route_to_router(router, .OPTIONS, "/api/v1/ping", handle_options_request)
            add_route_to_router(router, .OPTIONS, "/api/v1/health", handle_options_request)


            //Example CORS preflight for dynamic endpoint
            add_route_to_router(router, .OPTIONS, "/api/v1/*", handle_options_request)

            //Example requests on simple static endpoints
            add_route_to_router(router, .POST, "/ping", handle_get_request)
            add_route_to_router(router, .GET, "/health", handle_health_check)

            //Example requests on dynamic endpoint
            add_route_to_router(router, .GET, "/apy/v1/*", handle_get_request)

    } //END OF TEMP CONTEXT ALLOCATION SCOPE


    //Parse bind address from config
    bindIP := parse_ip_address(appConfig.server.bindAddress)
    endpoint := net.Endpoint{bindIP, server.port}

    // Use backlog size from config
    listenSocket, listen_err := net.listen_tcp(endpoint, appConfig.server.backlogSize)
    if listen_err != nil {
        printf("Error listening on socket: %v\n", listen_err)
        return make_new_err(.SERVER_CANNOT_LISTEN_ON_SOCKET, get_caller_location())
    }

    defer net.close(net.TCP_Socket(listenSocket))

    printf(
        "Odin HTTP server listening on %s:%d (bind: %s)\n",
        appConfig.server.host,
        server.port,
        appConfig.server.bindAddress,
    )
    printf("API Base URL: http://%s:%d%s\n", appConfig.server.host, server.port, apiBase)

    // Main server loop
    for serverIsRunning {
        if appConfig.logging.level == "DEBUG" {
            fmt.println("Waiting for new connection...")
        }

        clientSocket, remoteEndpoint, acceptError := net.accept_tcp(listenSocket)
        if acceptError != nil {
            fmt.println("Error accepting connection: ", acceptError)
            return make_new_err(.SERVER_CANNOT_ACCEPT_CONNECTION, get_caller_location())
        }

        handle_connection(clientSocket, appConfig, router)
    }

    fmt.println("Server stopped successfully")
    return no_error()
}

@(cold)
handle_connection :: proc(socket: net.TCP_Socket, appConfig: ^lib.AppConfig, router: ^lib.Router) -> ^lib.Error{
    using lib
    using fmt

    defer net.close(socket)

    maxBufferSize := appConfig.security.maxRequestBodySizeMb * 1024 * 1024
    buf := make([]byte, min(maxBufferSize, 4096))
    defer delete(buf)

    for {
        println("Waiting to receive data...")

        bytesRead, readTCPSocketError := net.recv(socket, buf[:])

        if bytesRead == 0 {
            println("Connection closed by client")
            return no_error()
        }

        // Parse incoming request
        method, path, headers := parse_http_request(buf[:bytesRead])


        // Extract request body for POST/PUT requests
        request_body := extract_request_body(buf[:bytesRead])
        args := []string{request_body} if len(request_body) > 0 else []string{""}

        // Handle the request using router
        httpStatus, responseBody := handle_http_request(router, method, path, headers, args)

        if appConfig.logging.consoleOutput || appConfig.logging.level == "DEBUG" {
        }

        // Build and send response
        version, versionLoaded := get_ost_version(); if !versionLoaded do continue
        responseHeaders := make(map[string]string)
        responseHeaders["Content-Type"] = "application/json"
        responseHeaders["Server"] = tprintf("OstrichDB:%s", string(version))
        responseHeaders["X-API-Version"] = "v1"

        // Apply CORS headers to response
        apply_cors_headers(&responseHeaders, headers, method)

        response := build_http_response(httpStatus, responseHeaders, responseBody)

        // Write response to socket
        _, writeError := net.send(socket, response)
        defer delete(response) //TODO: If a memory leak ye seek come here and take a peek - Marshall
        if writeError != nil {
            printf("ERROR: Failed to write response to socket: %v\n", writeError)
            return make_new_err(.SERVER_CANNOT_WRITE_RESPONSE_TO_SOCKET, get_caller_location())
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
		input := get_input(false)
		if input == "kill" || input == "exit" {
			// println("Stopping OstrichDB server...")
			serverIsRunning = false
			//ping the server to essentially refresh it to ensure it stops thus breaking the server main loop
			for port in ServerPorts{
				portCString := clone_to_cstring(tprintf("nc -zv localhost %d", port))
				libc.system(portCString)
			}
			return
		} else do continue
	}
}