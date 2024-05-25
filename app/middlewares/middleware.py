from fastapi import Request, HTTPException

def get_accept_header(request: Request):
    accept = request.headers.get("accept", "")
    if "text/html" in accept:
        return "html"
    elif "application/json" in accept:
        return "json"
    else:
        raise HTTPException(status_code=406, detail="Not Acceptable: Only 'text/html' and 'application/json' are supported.")