package library

import "base:runtime"


ErrorType :: enum {
   NONE = 0,
   UNKOWN,
   WARNING,
   ERROR,
   CRITICAL
}

SourceCodeLocation::runtime.Source_Code_Location
#assert(SourceCodeLocation == runtime.Source_Code_Location)

Error :: struct {
    type: ErrorType,
	message:   string,
	location:  SourceCodeLocation
}

get_caller_location :: proc(location:= #caller_location) -> SourceCodeLocation {
    return location
}


make_error ::proc(msg:string= "No Error", type:ErrorType=.NONE, loc:= #caller_location) -> Error{
    return Error{ message = msg, type = type, location = loc}
}


