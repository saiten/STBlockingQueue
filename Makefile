WORKSPACE=STBlockingQueue.xcworkspace
SCHEME=STBlockingQueue

clean:
	xctool -workspace ${WORKSPACE} -scheme ${SCHEME} clean

build:
	xctool -workspace ${WORKSPACE} -scheme ${SCHEME} build -sdk iphonesimulator7.0

test:
	xctool -workspace ${WORKSPACE} -scheme ${SCHEME} test -test-sdk iphonesimulator7.0 -parallelize

