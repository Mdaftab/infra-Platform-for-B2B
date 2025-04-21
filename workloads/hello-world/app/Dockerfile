FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY . .

RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -o hello-world .

FROM alpine:3.19

WORKDIR /app

COPY --from=builder /app/hello-world .

EXPOSE 8080

CMD ["/app/hello-world"]
