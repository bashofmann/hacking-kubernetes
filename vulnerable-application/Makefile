
build:
	docker build -t bashofmann/hacking-kubernetes-vulnerable-application .

run: build
	docker run --rm -it -p 8080:8080 bashofmann/hacking-kubernetes-vulnerable-application

push: build
	docker push bashofmann/hacking-kubernetes-vulnerable-application
