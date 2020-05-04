# Build app using system-installed 'dmd' D-lang compiler 
build1: dockman.d
	dmd dockman.d -of=dockman.bin

# Build using docker image from:
#  + https://github.com/dlangchina/docker-dlang
#
# The benefit of this option is that the user does not
# have to install D-language compiler as it already
# comes pre-installed in the Docker image.
build2:
	docker run --rm -it -v $(shell pwd):/work -w /work dlangchina/dlang-dmd dmd dockman.d -of=dockman.bin

clean:
	rm -rf -v *.bin *.o
