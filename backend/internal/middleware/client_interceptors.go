package middleware

import (
	"context"
	"net/http"

	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

// gRPC Client Interceptor
func TracingUnaryClientInterceptor() grpc.UnaryClientInterceptor {
	return func(ctx context.Context, method string, req, reply interface{}, cc *grpc.ClientConn, invoker grpc.UnaryInvoker, opts ...grpc.CallOption) error {
		traceID, _ := ctx.Value("TraceID").(string)
		spanID, _ := ctx.Value("SpanID").(string)
		
		if traceID != "" {
			md := metadata.Pairs(
				"x-trace-id", traceID,
				"x-span-id", spanID,
				"x-b3-traceid", traceID,
				"x-b3-spanid", spanID,
				"traceparent", "00-"+traceID+"-"+spanID+"-01",
			)
			ctx = metadata.NewOutgoingContext(ctx, md)
		}
		return invoker(ctx, method, req, reply, cc, opts...)
	}
}

// REST: TracingRoundTripper injects trace headers into outgoing HTTP requests
type TracingRoundTripper struct {
	Proxied http.RoundTripper
}

func (t *TracingRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	ctx := req.Context()
	traceID, _ := ctx.Value("TraceID").(string)
	spanID, _ := ctx.Value("SpanID").(string)

	if traceID != "" {
		req.Header.Set("X-Trace-Id", traceID)
		req.Header.Set("X-Span-Id", spanID)
		req.Header.Set("X-B3-TraceId", traceID)
		req.Header.Set("X-B3-SpanId", spanID)
		req.Header.Set("traceparent", "00-"+traceID+"-"+spanID+"-01")
	}

	return t.Proxied.RoundTrip(req)
}


func NewTracingClient(client *http.Client) *http.Client {
	if client == nil {
		client = &http.Client{}
	}
	transport := client.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}
	client.Transport = &TracingRoundTripper{Proxied: transport}
	return client
}

// GraphQL: Since GraphQL usually runs over HTTP, the TracingRoundTripper often suffices.
// However, we can add a specific wrapper if using a library like gqlgen.

