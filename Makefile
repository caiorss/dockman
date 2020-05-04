
# Build app using system-installed 'dmd' D-lang compiler 
dockman.bin: dockman.d
	dmd dockman.d -of=dockman.bin

