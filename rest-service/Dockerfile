FROM golang:1-alpine as builder

# Install the Certificate-Authority certificates for the app to be able to make
# calls to HTTPS endpoints.
# Git is required for fetching the dependencies.
RUN apk add --no-cache ca-certificates git curl jq

# Set the working directory outside $GOPATH to enable the support for modules.
WORKDIR /src

# Fetch dependencies first; they are less susceptible to change on every build
# and will therefore be cached for speeding up the next build
COPY ./go.mod ./go.sum ./
RUN go mod download

RUN download_url=$(curl -s https://api.github.com/repos/go-swagger/go-swagger/releases/latest | \
    jq -r '.assets[] | select(.name | contains("'"$(uname | tr '[:upper:]' '[:lower:]')"'_amd64")) | .browser_download_url') && \
    curl -o /tmp/swagger -L'#' "${download_url}" && \
    chmod +x /tmp/swagger

# Import the code from the context.
COPY . ./

RUN mkdir -p gen && \
    /tmp/swagger generate server -t gen -f ./swagger_spec/swagger.yml --exclude-main -A greeter

# Build the executable to `/app`. Mark the build as statically linked.
RUN CGO_ENABLED=0 go build \
    -gcflags "-N -l" \
    -o /app cmd/greeter/main.go

# Final stage: the running container.
FROM alpine as final

ENV version V1

# Import the Certificate-Authority certificates for enabling HTTPS.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Import the compiled executable from the first stage.
COPY --from=builder /app /app

# Declare the port on which the webserver will be exposed.
# As we're going to run the executable as an unprivileged user, we can't bind
# to ports below 1024.
EXPOSE 3000

# Create a group and user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Perform any further action as an unprivileged user.
USER appuser

# Run the compiled binary.
ENTRYPOINT /app --port 3000 --version ${version}
