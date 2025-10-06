package library


import "core:os"
import "core:fmt"
import "core:strings"

validMethods:[]HttpMethod={.OPTIONS, .GET, .POST, .PUT, .DELETE, .HEAD}
serverPorts:[dynamic]int


get_input :: proc() -> string {
	buf := new([1024]byte)
	defer free(buf)
	n, err := os.read(os.stdin, buf[:])
	result := strings.trim_right(string(buf[:n]), "\r\n")
	return strings.clone(result)
}