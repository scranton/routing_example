SWAGGER := $(shell command -v swagger 2> /dev/null)

all: ./gen
	go run ./cmd/greeter/main.go --port 3000 --version V2

./gen:
ifndef SWAGGER
	$(shell mkdir -p bin)
	$(shell download_url=$(curl -s https://api.github.com/repos/go-swagger/go-swagger/releases/latest | \
		jq -r '.assets[] | select(.name | contains("'"$(uname | tr '[:upper:]' '[:lower:]')"'_amd64")) | .browser_download_url'))
	$(shell curl -o ./swagger -L'#' "${download_url}")
	$(shell chmod +x ./swagger)
endif
	mkdir -p gen
	swagger generate server -t gen -f ./swagger_spec/swagger.yml --exclude-main -A greeter

clean:
	rm -rf gen ./swagger
