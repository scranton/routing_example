# Example REST Service

## Building and Running

```shell
make clean all
```

## Client test

```shell
curl --silent 'http://localhost:3000/hello?name=Scott'
```

Should result in the following output. Note prefix should match `--version` flag used to start REST service, and suffix name should match `name=` query param.

```shell
V2: Hello, Scott!
```

## Releated article

* <https://goswagger.io/tutorial/custom-server.html>
