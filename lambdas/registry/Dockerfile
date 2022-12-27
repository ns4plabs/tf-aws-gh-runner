FROM golang:1.19

WORKDIR /go/src/app

COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

ENTRYPOINT [ "./run" ]
