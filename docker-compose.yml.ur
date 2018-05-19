version: '2'

services:
  nodeapp:
    image: wnc:1.2-ur
    ports:
      - "8080:8080"

  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - /etc/nginx:/etc/nginx:ro

      