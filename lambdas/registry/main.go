package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/distribution/distribution/v3/configuration"
	"github.com/distribution/distribution/v3/registry"
	"github.com/distribution/distribution/v3/registry/handlers"
	_ "github.com/distribution/distribution/v3/registry/storage/driver/filesystem"
	_ "github.com/distribution/distribution/v3/registry/storage/driver/inmemory"
	_ "github.com/distribution/distribution/v3/registry/storage/driver/s3-aws"
	"golang.org/x/sys/unix"
	"golang.org/x/term"
)

type ResponseWriter struct {
	header     http.Header
	statusCode int
	body       *bytes.Buffer
}

func (w *ResponseWriter) Header() http.Header {
	if w.header == nil {
		w.header = http.Header{}
	}
	return w.header
}

func (w *ResponseWriter) Write(b []byte) (int, error) {
	if w.body == nil {
		w.body = &bytes.Buffer{}
	}
	return w.body.Write(b)
}

func (w *ResponseWriter) WriteHeader(statusCode int) {
	w.statusCode = statusCode
}

func (w *ResponseWriter) ALBTargetGroupResponse() (*events.ALBTargetGroupResponse, error) {
	ret := &events.ALBTargetGroupResponse{}
	if w.statusCode != 0 {
		ret.StatusCode = w.statusCode
	} else {
		ret.StatusCode = http.StatusOK
	}
	for key, values := range w.header {
		if len(values) > 1 {
			return nil, fmt.Errorf("header has multiple values: " + key)
		} else if len(values) == 1 {
			if ret.Headers == nil {
				ret.Headers = map[string]string{}
			}
			ret.Headers[key] = values[0]
		}
	}
	if w.body != nil {
		ret.Body = base64.StdEncoding.EncodeToString(w.body.Bytes())
		ret.IsBase64Encoded = true
	}
	return ret, nil
}

func NewRequest(request *events.ALBTargetGroupRequest) (*http.Request, error) {
	resource, err := url.ParseRequestURI(request.Path)
	if err != nil {
		return nil, errors.Wrap(err, "unable to parse request URI")
	}
	if len(request.QueryStringParameters) > 0 {
		query := url.Values{}
		for key, value := range request.QueryStringParameters {
			query.Set(key, value)
		}
		resource.RawQuery = query.Encode()
	}
	req, err := http.ReadRequest(bufio.NewReader(strings.NewReader(request.HTTPMethod + " " + resource.RequestURI() + " HTTP/1.0\r\n\r\n")))
	if err != nil {
		return nil, errors.Wrap(err, "unable to create request")
	}

	req.Proto = "HTTP/1.1"
	req.ProtoMinor = 1

	if request.Body != "" {
		var body []byte
		if request.IsBase64Encoded {
			body, err = base64.StdEncoding.DecodeString(request.Body)
			if err != nil {
				return nil, errors.Wrap(err, "unable to decode base64 body")
			}
		} else {
			body = []byte(request.Body)
		}
		req.ContentLength = int64(len(body))
		req.Body = io.NopCloser(bytes.NewReader(body))
	}

	for key, value := range request.Headers {
		req.Header.Set(key, value)
	}
	req.Host = req.Header.Get("Host")

	return req, nil
}

func Handler(handler http.Handler) func(*events.ALBTargetGroupRequest) (*events.ALBTargetGroupResponse, error) {
	return func(request *events.ALBTargetGroupRequest) (*events.ALBTargetGroupResponse, error) {
		req, err := NewRequest(request)
		if err != nil {
			return nil, err
		}
		resp := &ResponseWriter{}
		handler.ServeHTTP(resp, req)
		return resp.ALBTargetGroupResponse()
	}
}

func StartHTTPHandler() {
	config, err := configuration.Parse(strings.NewReader(os.Getenv("REGISTRY")))
	if err != nil {
		logrus.Fatal(err)
	}
	if os.Getenv("LAMBDA_TASK_ROOT") != "" {
		app := handlers.NewApp(context.Background(), config)
		lambda.Start(Handler(app))
	} else {
		reg, err := registry.NewRegistry(context.Background(), config)
		if err != nil {
			logrus.Fatal(err)
		}
		if err = reg.ListenAndServe(); err != nil {
			logrus.Fatalln(err)
		}
	}
}

func main() {
	if !term.IsTerminal(unix.Stdout) {
		logrus.SetFormatter(&logrus.JSONFormatter{})
	}

	flags := flag.NewFlagSet(os.Args[0], flag.ContinueOnError)
	if err := flags.Parse(os.Args[1:]); err != nil {
		if err == flag.ErrHelp {
			// Exit with no error if --help was given. This is used to test the build.
			os.Exit(0)
		}
		logrus.Fatal(err)
	}

	StartHTTPHandler()
}
