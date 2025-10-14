package library

import "core:os"
import "core:fmt"
import "core:strings"
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


validMethods:[]HttpMethod={.OPTIONS, .GET, .POST, .PUT, .DELETE, .HEAD}

API_VERSION :: "v1"
BIND_ADDRESS :: "127.0.0.1"
HOST:: "localhost"
DEFAULT_ADDRESS :: "http://localhost:8080"
SERVER_VERSION :: "v0.1.0"
MAX_CONNECTIONS :: 1
BACKLOG_SIZE :: 3
MAX_REQUEST_BODY_SIZE_MB :: 5
SERVER_PORT :: 8080
MAX_AGE_SECONDS :: 86400

get_input :: proc() -> string {
	buf := new([1024]byte)
	defer free(buf)
	n, err := os.read(os.stdin, buf[:])
	result := strings.trim_right(string(buf[:n]), "\r\n")
	return strings.clone(result)
}