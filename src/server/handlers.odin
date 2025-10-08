package server

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:strconv"
import "core:encoding/json"
import "core:encoding/base64"
import lib "../library"



//Example of GET request procedure depending on the arguments in the path. In this case '/health' and '/ping'
//You can add logic for GET(ting) other paths if you so choose.
handle_get_request :: proc(server: ^lib.Server, method: lib.HttpMethod, path: string, headers: map[string]string, args: []string = {""}) -> (^lib.HttpStatus, string){
    using lib
    using fmt
    using strings


    if method != .GET{
        newHTTPStatus := make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST])
        return newHTTPStatus, "Request Failed: Method not allowed\n"
    }


    segments:= split_path_into_segments(path)
    numberOfSegments:= len(segments)

    //Handle logic for: "/api/v1/health"
    if numberOfSegments == 3 && segments[2] == "health"{

        //If sending back a JSON response format your data
        healthData:= fmt.tprintf(`
            %s
            "status": "healthy",
            "server_version": "%s",
            "api_version": "v1",
            "timestamp": "%v",
            %s`,
            "{", server.version, time.now(), "}")

        response := healthData
        return make_new_http_status(.OK, HttpStatusText[.OK]), response
    }

    //Handle logic for: "/api/v1/ping"
    if numberOfSegments == 3 && segments[2] == "ping"{
        response := fmt.tprintf(`Odin HTTP Server sent sending back : pong`)
        return make_new_http_status(.OK, HttpStatusText[.OK]), response
    }

    newHTTPStatus := make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND])
    return newHTTPStatus, "Not Found\n"
}



//Helper used to parse a query parameter string into a map.
// Note: The query parameter string must already be split off from the path. Find an example of this in the above handle_post_request() proc
parse_query_string :: proc(query: string) -> map[string]string {
    using strings

	params := make(map[string]string)
	pairs := split(query, "&")
	for pair in pairs {
		keyValue := split(pair, "=")
		if len(keyValue) == 2 {
			params[keyValue[0]] = keyValue[1]
		}
	}
	return params
}

//Helper proc to verify a path has a valid query param
@(require_results)
has_valid_query_parameters :: proc(path: string) -> bool {
    using strings

    if !contains(path, "?") {
        return false
    }

    queryString := extract_query_from_path(path)
    trimmedQuery := trim_space(queryString)

    // Check if there's actual content after the "?"
    if len(trimmedQuery) == 0 {
        return false
    }

    // Check if there are actual key=value pairs
    pairs := split(trimmedQuery, "&")
    // defer delete(pairs)

    for pair in pairs {
        if contains(pair, "=") && len(trim_space(pair)) > 1 {
            return true
        }
    }

    return false
}


// Helper to extract query string from path
@(require_results)
extract_query_from_path :: proc(path: string) -> string {
    using strings

    if queryStart := index(path, "?"); queryStart != -1 {
        return path[queryStart + 1:]
    }
    return ""
}

//Helper to split a path by the '/' character
@(require_results)
split_path_into_segments :: proc(path: string) -> []string {
    using strings

    // First, remove query parameters from the path
    cleanPath := path
    if queryPos := index(path, "?"); queryPos != -1 {
        cleanPath = path[:queryPos]
    }

    // Then split normally
    return split(trim_prefix(cleanPath, "/"), "/")
}


//Shoutout to ClaudeAI by Anthropic for this shit
@(require_results)
clean_metadata_field :: proc(input: string, defaultValue: string) -> string {
    using strings

    if len(input) == 0 {
        return clone(defaultValue)
    }

    trimmed := trim_space(input)
    if len(trimmed) == 0 {
        return clone(defaultValue)
    }

    // Remove any non-printable characters and escape quotes
    cleaned := make([dynamic]u8)
    // defer delete(cleaned)

    for char in transmute([]u8)trimmed {
        // Only include printable ASCII characters
        if char >= 32 && char <= 126 {
            if char == '"' {
                // Escape quotes
                append(&cleaned, '\\')
                append(&cleaned, '"')
            } else {
                append(&cleaned, char)
            }
        } else if char == ' ' {
            // Keep spaces
            append(&cleaned, char)
        }
        // Skip all other characters (control characters, etc.)
    }

    cleanedStr := string(cleaned[:])
    if len(trim_space(cleanedStr)) == 0 {
        return clone(defaultValue)
    }

    return clone(cleanedStr)
}
