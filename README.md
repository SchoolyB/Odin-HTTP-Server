# Odin HTTP Server
A Simple HTTP server implementation in pure Odin
This server is similar to the HTTP server that powers [OstrichDB.com](https://ostrichdb.com/)


## Getting Started:

### Prerequisites
This program was written in an envrironment using the following:
- OS: macOS Sequoia 15.0.1
- Odin version: `dev-2024-11:764c32fd3`
- CPU: Apple M2
- RAM: 8GB

*** Results may vary based on your own dev environment setup ***

### Steps
1. Clone repo:
```bash
git clone https://github.com/SchoolyB/Odin-HTTP-Server.git
```

2. Navigate to root of project
```bash
cd path/to/Odin-HTTP-Server
```

3. Run
```bash
odin run main
```

## Things to note:

1. Server runs on port: `8080`
2. There is a basic API layer built into this project.
3. The API base is `/api/v1`
4. You can use the `GET` method on the `/ping` and `/health` endpoints
5. You can use the `POST` method on the `/user` endpoint
6. Example URL: `http://localhost:8080/api/v1/user`
7. The only request handlers that I built out are for `GET` and `POST`
8. There are tons of comments to help folks understand :)


